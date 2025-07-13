import Foundation
import BackgroundTasks

// MARK: - 自動結算排程服務
@MainActor
class AutoSettlementScheduler: ObservableObject {
    static let shared = AutoSettlementScheduler()
    
    private let settlementService = MonthlySettlementService()
    private let integrationService = WalletSettlementIntegrationService()
    private let notificationService = SettlementNotificationService.shared
    
    private let backgroundTaskIdentifier = "com.invest.v3.settlement"
    
    @Published var isSchedulerEnabled = true
    @Published var lastSettlementDate: Date?
    @Published var nextSettlementDate: Date?
    @Published var isProcessing = false
    
    private init() {
        registerBackgroundTask()
        calculateNextSettlementDate()
    }
    
    // MARK: - 註冊背景任務
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            Task {
                await self.handleBackgroundSettlement(task as! BGAppRefreshTask)
            }
        }
    }
    
    // MARK: - 排程背景任務
    func scheduleBackgroundSettlement() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = nextSettlementDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("背景結算任務已排程")
        } catch {
            print("排程背景結算任務失敗: \(error)")
        }
    }
    
    // MARK: - 處理背景結算
    private func handleBackgroundSettlement(_ task: BGAppRefreshTask) async {
        // 設置過期處理
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        do {
            await processScheduledSettlement()
            task.setTaskCompleted(success: true)
        } catch {
            print("背景結算處理失敗: \(error)")
            task.setTaskCompleted(success: false)
        }
        
        // 排程下次結算
        scheduleBackgroundSettlement()
    }
    
    // MARK: - 執行排程結算
    func processScheduledSettlement() async {
        guard isSchedulerEnabled else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 獲取需要結算的日期
            let (year, month) = getLastMonthDate()
            
            // 檢查是否已經處理過這個月份
            if let lastDate = lastSettlementDate,
               Calendar.current.component(.year, from: lastDate) == year,
               Calendar.current.component(.month, from: lastDate) == month {
                print("本月結算已處理")
                return
            }
            
            // 獲取所有需要結算的創作者
            let authorIds = try await getAuthorsForSettlement(year: year, month: month)
            
            print("開始處理 \(authorIds.count) 位創作者的月度結算")
            
            // 批量處理結算
            try await integrationService.processBatchMonthlySettlement(
                authorIds: authorIds,
                year: year,
                month: month
            )
            
            // 更新最後結算日期
            lastSettlementDate = Date()
            calculateNextSettlementDate()
            
            // 發送結算完成通知
            await sendSettlementCompletedNotifications(authorIds: authorIds, year: year, month: month)
            
            print("月度結算完成")
            
        } catch {
            print("處理排程結算失敗: \(error)")
        }
    }
    
    // MARK: - 手動觸發結算
    func triggerManualSettlement() async {
        await processScheduledSettlement()
    }
    
    // MARK: - 計算下次結算日期
    private func calculateNextSettlementDate() {
        let calendar = Calendar.current
        let now = Date()
        
        // 獲取下個月的第一天
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let components = calendar.dateComponents([.year, .month], from: nextMonth)
        
        var nextSettlementComponents = DateComponents()
        nextSettlementComponents.year = components.year
        nextSettlementComponents.month = components.month
        nextSettlementComponents.day = 1
        nextSettlementComponents.hour = 2  // 凌晨2點執行
        nextSettlementComponents.minute = 0
        
        nextSettlementDate = calendar.date(from: nextSettlementComponents)
    }
    
    // MARK: - 獲取上個月日期
    private func getLastMonthDate() -> (year: Int, month: Int) {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        
        let year = calendar.component(.year, from: lastMonth)
        let month = calendar.component(.month, from: lastMonth)
        
        return (year, month)
    }
    
    // MARK: - 獲取需要結算的創作者
    private func getAuthorsForSettlement(year: Int, month: Int) async throws -> [UUID] {
        guard let client = SupabaseManager.shared.client else {
            throw SchedulerError.supabaseNotInitialized
        }
        
        // 獲取指定月份的起始和結束日期
        let (startDate, endDate) = getMonthDateRange(year: year, month: month)
        
        // 查詢該月有收益計算的創作者
        let calculations: [RevenueCalculation] = try await client
            .from("revenue_calculations")
            .select("author_id")
            .gte("calculation_date", value: startDate.ISO8601Format())
            .lte("calculation_date", value: endDate.ISO8601Format())
            .execute()
            .value
        
        // 去重並返回創作者 ID 列表
        let uniqueAuthorIds = Array(Set(calculations.map { $0.authorId }))
        return uniqueAuthorIds
    }
    
    // MARK: - 獲取月份日期範圍
    private func getMonthDateRange(year: Int, month: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = 1
        startComponents.hour = 0
        startComponents.minute = 0
        startComponents.second = 0
        
        let startDate = calendar.date(from: startComponents) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? Date()
        
        return (startDate, endDate)
    }
    
    // MARK: - 發送結算完成通知
    private func sendSettlementCompletedNotifications(authorIds: [UUID], year: Int, month: Int) async {
        for authorId in authorIds {
            do {
                if let settlement = try await settlementService.getSettlement(authorId: authorId, year: year, month: month) {
                    await notificationService.sendSettlementCompletedNotification(settlement: settlement)
                }
            } catch {
                print("發送結算通知失敗 - 創作者: \(authorId), 錯誤: \(error)")
            }
        }
    }
    
    // MARK: - 啟用/禁用排程器
    func setSchedulerEnabled(_ enabled: Bool) {
        isSchedulerEnabled = enabled
        
        if enabled {
            scheduleBackgroundSettlement()
            // 設置月度結算提醒
            Task {
                await notificationService.scheduleMonthlySettlementReminder()
            }
        } else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
            notificationService.cancelNotification(identifier: "monthly_settlement_reminder")
        }
    }
    
    // MARK: - 獲取排程狀態
    func getSchedulerStatus() -> SchedulerStatus {
        return SchedulerStatus(
            isEnabled: isSchedulerEnabled,
            isProcessing: isProcessing,
            lastSettlementDate: lastSettlementDate,
            nextSettlementDate: nextSettlementDate
        )
    }
    
    // MARK: - 獲取結算統計
    func getSettlementStatistics() async throws -> SettlementStatistics {
        guard let client = SupabaseManager.shared.client else {
            throw SchedulerError.supabaseNotInitialized
        }
        
        // 獲取本月結算統計
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        let currentMonthSettlements: [MonthlySettlement] = try await client
            .from("monthly_settlements")
            .select()
            .eq("settlement_year", value: currentYear)
            .eq("settlement_month", value: currentMonth)
            .execute()
            .value
        
        // 獲取總結算統計
        let allSettlements: [MonthlySettlement] = try await client
            .from("monthly_settlements")
            .select()
            .execute()
            .value
        
        let totalSettlements = allSettlements.count
        let totalAmount = allSettlements.reduce(0) { $0 + $1.totalCreatorEarnings }
        let averageAmount = totalSettlements > 0 ? totalAmount / totalSettlements : 0
        
        let completedSettlements = allSettlements.filter { $0.settlementStatus == .completed || $0.settlementStatus == .paid }
        let completionRate = totalSettlements > 0 ? Double(completedSettlements.count) / Double(totalSettlements) : 0.0
        
        return SettlementStatistics(
            totalSettlements: totalSettlements,
            currentMonthSettlements: currentMonthSettlements.count,
            totalAmount: totalAmount,
            averageAmount: averageAmount,
            completionRate: completionRate,
            lastProcessedDate: lastSettlementDate
        )
    }
}

// MARK: - 排程器狀態
struct SchedulerStatus {
    let isEnabled: Bool
    let isProcessing: Bool
    let lastSettlementDate: Date?
    let nextSettlementDate: Date?
    
    var formattedLastSettlementDate: String {
        guard let date = lastSettlementDate else { return "尚未執行" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    var formattedNextSettlementDate: String {
        guard let date = nextSettlementDate else { return "未排程" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - 結算統計
struct SettlementStatistics {
    let totalSettlements: Int
    let currentMonthSettlements: Int
    let totalAmount: Int
    let averageAmount: Int
    let completionRate: Double
    let lastProcessedDate: Date?
    
    var formattedTotalAmount: String {
        return "NT$\(totalAmount / 100)"
    }
    
    var formattedAverageAmount: String {
        return "NT$\(averageAmount / 100)"
    }
    
    var formattedCompletionRate: String {
        return String(format: "%.1f%%", completionRate * 100)
    }
}

// MARK: - 排程器錯誤
enum SchedulerError: LocalizedError {
    case supabaseNotInitialized
    case backgroundTaskNotRegistered
    case schedulingFailed
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .supabaseNotInitialized:
            return "Supabase 未初始化"
        case .backgroundTaskNotRegistered:
            return "背景任務未註冊"
        case .schedulingFailed:
            return "排程失敗"
        case .unauthorizedAccess:
            return "無權限訪問"
        }
    }
}

// MARK: - 排程器設置
struct SchedulerSettings: Codable {
    var isEnabled: Bool = true
    var settlementHour: Int = 2  // 凌晨2點
    var settlementMinute: Int = 0
    var enableNotifications: Bool = true
    var autoWithdrawal: Bool = false
    var minimumAutoWithdrawalAmount: Int = 100000  // NT$1,000
    
    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case settlementHour = "settlement_hour"
        case settlementMinute = "settlement_minute"
        case enableNotifications = "enable_notifications"
        case autoWithdrawal = "auto_withdrawal"
        case minimumAutoWithdrawalAmount = "minimum_auto_withdrawal_amount"
    }
}