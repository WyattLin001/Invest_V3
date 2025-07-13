import Foundation
import Supabase

// MARK: - 月度結算服務
@MainActor
class MonthlySettlementService: ObservableObject {
    private let supabase = SupabaseManager.shared
    private let revenueService = RevenueCalculationService()
    
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentSettlement: MonthlySettlement?
    
    // MARK: - 月度結算處理
    func processMonthlySettlement(
        authorId: UUID,
        year: Int,
        month: Int
    ) async throws -> MonthlySettlement {
        isLoading = true
        defer { isLoading = false }
        
        // 檢查是否已存在該月結算
        if let existingSettlement = try await getSettlement(authorId: authorId, year: year, month: month) {
            if existingSettlement.settlementStatus == .completed || existingSettlement.settlementStatus == .paid {
                throw SettlementError.alreadySettled
            }
        }
        
        // 計算該月的收益
        let (startDate, endDate) = getMonthDateRange(year: year, month: month)
        
        let subscriptionRevenue = try await revenueService.getTotalRevenueByType(
            authorId: authorId,
            type: .subscription,
            from: startDate,
            to: endDate
        )
        
        let donationRevenue = try await revenueService.getTotalRevenueByType(
            authorId: authorId,
            type: .donation,
            from: startDate,
            to: endDate
        )
        
        let paidReadingRevenue = try await revenueService.getTotalRevenueByType(
            authorId: authorId,
            type: .paidReading,
            from: startDate,
            to: endDate
        )
        
        let bonusRevenue = try await revenueService.getTotalRevenueByType(
            authorId: authorId,
            type: .bonus,
            from: startDate,
            to: endDate
        )
        
        // 計算總收益和平台抽成
        let (totalGross, totalCreator, totalPlatform, _) = try await revenueService.getAuthorRevenueStats(
            authorId: authorId,
            from: startDate,
            to: endDate
        )
        
        // 創建結算記錄
        let settlement = MonthlySettlement(
            authorId: authorId,
            settlementYear: year,
            settlementMonth: month,
            totalGrossRevenue: totalGross,
            totalPlatformFee: totalPlatform,
            totalCreatorEarnings: totalCreator,
            subscriptionRevenue: subscriptionRevenue,
            donationRevenue: donationRevenue,
            paidReadingRevenue: paidReadingRevenue,
            bonusRevenue: bonusRevenue,
            status: .processing,
            processedAt: Date()
        )
        
        // 儲存結算記錄
        try await saveSettlement(settlement)
        
        // 更新相關收益計算的結算 ID
        try await updateRevenueCalculationsSettlementId(
            authorId: authorId,
            from: startDate,
            to: endDate,
            settlementId: settlement.id
        )
        
        // 發送結算通知
        await sendSettlementNotification(settlement: settlement)
        
        currentSettlement = settlement
        return settlement
    }
    
    // MARK: - 自動結算處理
    func processAutoSettlement() async throws {
        // 獲取上個月的日期
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let year = Calendar.current.component(.year, from: lastMonth)
        let month = Calendar.current.component(.month, from: lastMonth)
        
        // 獲取所有需要結算的創作者
        let authorIds = try await getAuthorsForSettlement(year: year, month: month)
        
        for authorId in authorIds {
            do {
                let settlement = try await processMonthlySettlement(
                    authorId: authorId,
                    year: year,
                    month: month
                )
                
                // 如果符合自動支付條件，則自動完成結算
                if settlement.isEligibleForWithdrawal {
                    try await completeSettlement(settlementId: settlement.id)
                }
                
            } catch {
                print("自動結算失敗 - 創作者: \(authorId), 錯誤: \(error)")
                continue
            }
        }
    }
    
    // MARK: - 結算完成
    func completeSettlement(settlementId: UUID) async throws {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let updatedSettlement = [
            "status": SettlementStatus.completed.rawValue,
            "processed_at": Date().ISO8601Format(),
            "updated_at": Date().ISO8601Format()
        ]
        
        try await client
            .from("monthly_settlements")
            .update(updatedSettlement)
            .eq("id", value: settlementId)
            .execute()
    }
    
    // MARK: - 結算支付
    func markSettlementAsPaid(settlementId: UUID) async throws {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let updatedSettlement = [
            "status": SettlementStatus.paid.rawValue,
            "paid_at": Date().ISO8601Format(),
            "updated_at": Date().ISO8601Format()
        ]
        
        try await client
            .from("monthly_settlements")
            .update(updatedSettlement)
            .eq("id", value: settlementId)
            .execute()
    }
    
    // MARK: - 查詢方法
    func getSettlement(authorId: UUID, year: Int, month: Int) async throws -> MonthlySettlement? {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let response: [MonthlySettlement] = try await client
            .from("monthly_settlements")
            .select()
            .eq("author_id", value: authorId)
            .eq("settlement_year", value: year)
            .eq("settlement_month", value: month)
            .execute()
            .value
        
        return response.first
    }
    
    func getAuthorSettlements(
        authorId: UUID,
        limit: Int = 12
    ) async throws -> [MonthlySettlement] {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let response: [MonthlySettlement] = try await client
            .from("monthly_settlements")
            .select()
            .eq("author_id", value: authorId)
            .order("settlement_year", ascending: false)
            .order("settlement_month", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response
    }
    
    func getSettlementById(settlementId: UUID) async throws -> MonthlySettlement? {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let response: [MonthlySettlement] = try await client
            .from("monthly_settlements")
            .select()
            .eq("id", value: settlementId)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - 統計方法
    func getSettlementSummary(authorId: UUID) async throws -> SettlementSummary {
        let settlements = try await getAuthorSettlements(authorId: authorId, limit: 100)
        
        let totalEarnings = settlements.reduce(0) { $0 + $1.totalCreatorEarnings }
        let totalSubscriptionRevenue = settlements.reduce(0) { $0 + $1.subscriptionRevenue }
        let totalDonationRevenue = settlements.reduce(0) { $0 + $1.donationRevenue }
        let totalPaidReadingRevenue = settlements.reduce(0) { $0 + $1.paidReadingRevenue }
        let totalBonusRevenue = settlements.reduce(0) { $0 + $1.bonusRevenue }
        
        let monthCount = settlements.count
        let averageMonthlyEarnings = monthCount > 0 ? totalEarnings / monthCount : 0
        let lastSettlementDate = settlements.first?.createdAt
        
        return SettlementSummary(
            totalEarnings: totalEarnings,
            averageMonthlyEarnings: averageMonthlyEarnings,
            totalSubscriptionRevenue: totalSubscriptionRevenue,
            totalDonationRevenue: totalDonationRevenue,
            totalPaidReadingRevenue: totalPaidReadingRevenue,
            totalBonusRevenue: totalBonusRevenue,
            monthCount: monthCount,
            lastSettlementDate: lastSettlementDate
        )
    }
    
    // MARK: - 私有方法
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
    
    private func saveSettlement(_ settlement: MonthlySettlement) async throws {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        try await client
            .from("monthly_settlements")
            .insert(settlement)
            .execute()
    }
    
    private func updateRevenueCalculationsSettlementId(
        authorId: UUID,
        from startDate: Date,
        to endDate: Date,
        settlementId: UUID
    ) async throws {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let update = [
            "settlement_id": settlementId.uuidString,
            "updated_at": Date().ISO8601Format()
        ]
        
        try await client
            .from("revenue_calculations")
            .update(update)
            .eq("author_id", value: authorId)
            .gte("calculation_date", value: startDate.ISO8601Format())
            .lte("calculation_date", value: endDate.ISO8601Format())
            .execute()
    }
    
    private func getAuthorsForSettlement(year: Int, month: Int) async throws -> [UUID] {
        guard let client = supabase.client else {
            throw NSError(domain: "MonthlySettlementService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let (startDate, endDate) = getMonthDateRange(year: year, month: month)
        
        // 查詢該月有收益的創作者
        let response: [RevenueCalculation] = try await client
            .from("revenue_calculations")
            .select("author_id")
            .gte("calculation_date", value: startDate.ISO8601Format())
            .lte("calculation_date", value: endDate.ISO8601Format())
            .execute()
            .value
        
        // 去重並返回創作者 ID 列表
        let uniqueAuthorIds = Array(Set(response.map { $0.authorId }))
        return uniqueAuthorIds
    }
    
    private func sendSettlementNotification(settlement: MonthlySettlement) async {
        // 這裡可以實現推送通知邏輯
        print("發送結算通知 - 創作者: \(settlement.authorId), 金額: \(settlement.formattedTotalEarnings)")
    }
}

// MARK: - 結算錯誤類型
enum SettlementError: LocalizedError {
    case alreadySettled
    case insufficientData
    case calculationError
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .alreadySettled:
            return "該月份已完成結算"
        case .insufficientData:
            return "結算資料不足"
        case .calculationError:
            return "收益計算錯誤"
        case .unauthorizedAccess:
            return "無權限訪問結算資料"
        }
    }
}