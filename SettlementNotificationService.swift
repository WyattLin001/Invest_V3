import Foundation
import UserNotifications

// MARK: - 結算通知服務
@MainActor
class SettlementNotificationService: ObservableObject {
    static let shared = SettlementNotificationService()
    
    @Published var isNotificationEnabled = false
    @Published var notificationSettings = NotificationSettings()
    
    private init() {
        requestNotificationPermission()
    }
    
    // MARK: - 請求通知權限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationEnabled = granted
                if let error = error {
                    print("通知權限請求失敗: \(error)")
                }
            }
        }
    }
    
    // MARK: - 發送結算完成通知
    func sendSettlementCompletedNotification(settlement: MonthlySettlement) async {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "結算完成"
        content.body = "\(settlement.settlementPeriod)結算已完成，您的收益為 \(settlement.formattedTotalEarnings)"
        content.sound = .default
        content.badge = 1
        
        // 添加用戶資訊
        content.userInfo = [
            "type": "settlement_completed",
            "settlement_id": settlement.id.uuidString,
            "amount": settlement.totalCreatorEarnings,
            "period": settlement.settlementPeriod
        ]
        
        // 設置通知觸發時間（立即）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "settlement_\(settlement.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("結算完成通知已發送")
        } catch {
            print("發送結算完成通知失敗: \(error)")
        }
    }
    
    // MARK: - 發送提領申請通知
    func sendWithdrawalRequestNotification(request: WithdrawalRequest) async {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "提領申請已提交"
        content.body = "您的提領申請 \(request.formattedRequestAmount) 已提交，請等待審核"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "withdrawal_request",
            "request_id": request.id.uuidString,
            "amount": request.requestAmount,
            "method": request.paymentMethod
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "withdrawal_\(request.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("提領申請通知已發送")
        } catch {
            print("發送提領申請通知失敗: \(error)")
        }
    }
    
    // MARK: - 發送提領完成通知
    func sendWithdrawalCompletedNotification(request: WithdrawalRequest) async {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "提領完成"
        content.body = "您的提領申請已完成，\(request.formattedActualAmount) 已轉入您的帳戶"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "withdrawal_completed",
            "request_id": request.id.uuidString,
            "amount": request.actualAmount,
            "method": request.paymentMethod
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "withdrawal_completed_\(request.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("提領完成通知已發送")
        } catch {
            print("發送提領完成通知失敗: \(error)")
        }
    }
    
    // MARK: - 發送月度結算提醒
    func scheduleMonthlySettlementReminder() async {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "月度結算提醒"
        content.body = "本月結算即將開始，請查看您的收益統計"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "monthly_settlement_reminder"
        ]
        
        // 設置在每月最後一天觸發
        var dateComponents = DateComponents()
        dateComponents.day = -1  // 每月最後一天
        dateComponents.hour = 20  // 晚上8點
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "monthly_settlement_reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("月度結算提醒已設置")
        } catch {
            print("設置月度結算提醒失敗: \(error)")
        }
    }
    
    // MARK: - 發送收益里程碑通知
    func sendRevenueMilestoneNotification(milestone: RevenueMilestone) async {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "收益里程碑達成！"
        content.body = milestone.message
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "revenue_milestone",
            "milestone": milestone.type.rawValue,
            "amount": milestone.amount
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "milestone_\(milestone.type.rawValue)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("收益里程碑通知已發送")
        } catch {
            print("發送收益里程碑通知失敗: \(error)")
        }
    }
    
    // MARK: - 取消通知
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - 取消所有通知
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - 獲取通知設置
    func getNotificationSettings() async -> UNNotificationSettings {
        return await UNUserNotificationCenter.current().notificationSettings()
    }
}

// MARK: - 通知設置
struct NotificationSettings: Codable {
    var settlementNotifications: Bool = true
    var withdrawalNotifications: Bool = true
    var milestoneNotifications: Bool = true
    var reminderNotifications: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case settlementNotifications = "settlement_notifications"
        case withdrawalNotifications = "withdrawal_notifications"
        case milestoneNotifications = "milestone_notifications"
        case reminderNotifications = "reminder_notifications"
        case soundEnabled = "sound_enabled"
        case badgeEnabled = "badge_enabled"
    }
}

// MARK: - 收益里程碑
struct RevenueMilestone {
    let type: MilestoneType
    let amount: Int
    let message: String
    
    enum MilestoneType: String, CaseIterable {
        case firstEarning = "first_earning"
        case thousand = "thousand"
        case tenThousand = "ten_thousand"
        case hundredThousand = "hundred_thousand"
        case million = "million"
        
        var displayName: String {
            switch self {
            case .firstEarning: return "首次收益"
            case .thousand: return "千元里程碑"
            case .tenThousand: return "萬元里程碑"
            case .hundredThousand: return "十萬元里程碑"
            case .million: return "百萬元里程碑"
            }
        }
        
        var threshold: Int {
            switch self {
            case .firstEarning: return 1
            case .thousand: return 100000  // NT$1,000
            case .tenThousand: return 1000000  // NT$10,000
            case .hundredThousand: return 10000000  // NT$100,000
            case .million: return 100000000  // NT$1,000,000
            }
        }
    }
    
    static func checkMilestones(currentAmount: Int, previousAmount: Int) -> [RevenueMilestone] {
        var milestones: [RevenueMilestone] = []
        
        for type in MilestoneType.allCases {
            if currentAmount >= type.threshold && previousAmount < type.threshold {
                let milestone = RevenueMilestone(
                    type: type,
                    amount: currentAmount,
                    message: "恭喜您達成\(type.displayName)！總收益已達 NT$\(currentAmount / 100)"
                )
                milestones.append(milestone)
            }
        }
        
        return milestones
    }
}

// MARK: - 通知處理協議
protocol NotificationHandlerProtocol {
    func handleNotification(_ userInfo: [AnyHashable: Any])
}

// MARK: - 通知處理器
class NotificationHandler: NotificationHandlerProtocol {
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "settlement_completed":
            handleSettlementCompletedNotification(userInfo)
        case "withdrawal_request":
            handleWithdrawalRequestNotification(userInfo)
        case "withdrawal_completed":
            handleWithdrawalCompletedNotification(userInfo)
        case "monthly_settlement_reminder":
            handleMonthlySettlementReminderNotification(userInfo)
        case "revenue_milestone":
            handleRevenueMilestoneNotification(userInfo)
        default:
            print("未知的通知類型: \(type)")
        }
    }
    
    private func handleSettlementCompletedNotification(_ userInfo: [AnyHashable: Any]) {
        print("處理結算完成通知")
        // 這裡可以添加導航到結算詳情頁面的邏輯
    }
    
    private func handleWithdrawalRequestNotification(_ userInfo: [AnyHashable: Any]) {
        print("處理提領申請通知")
        // 這裡可以添加導航到提領歷史頁面的邏輯
    }
    
    private func handleWithdrawalCompletedNotification(_ userInfo: [AnyHashable: Any]) {
        print("處理提領完成通知")
        // 這裡可以添加導航到提領歷史頁面的邏輯
    }
    
    private func handleMonthlySettlementReminderNotification(_ userInfo: [AnyHashable: Any]) {
        print("處理月度結算提醒通知")
        // 這裡可以添加導航到收益統計頁面的邏輯
    }
    
    private func handleRevenueMilestoneNotification(_ userInfo: [AnyHashable: Any]) {
        print("處理收益里程碑通知")
        // 這裡可以添加顯示慶祝動畫的邏輯
    }
}