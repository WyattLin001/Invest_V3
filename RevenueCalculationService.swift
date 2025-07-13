import Foundation
import Supabase

// MARK: - 收益計算服務
@MainActor
class RevenueCalculationService: ObservableObject {
    private let supabase = SupabaseManager.shared
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - 訂閱分潤計算
    func calculateSubscriptionRevenue(
        authorId: UUID,
        subscriptionAmount: Int,
        subscriberCount: Int,
        readingDistribution: [UUID: Int]  // 文章 ID -> 閱讀次數
    ) async throws -> [RevenueCalculation] {
        isLoading = true
        defer { isLoading = false }
        
        var calculations: [RevenueCalculation] = []
        
        // 計算每位訂閱者的分潤額
        let perSubscriberAmount = subscriptionAmount / subscriberCount
        
        // 根據閱讀分配計算每篇文章的收益
        let totalReads = readingDistribution.values.reduce(0, +)
        
        for (articleId, readCount) in readingDistribution {
            let articleRevenue = Int(Double(perSubscriberAmount * readCount) / Double(totalReads))
            
            let calculation = RevenueCalculation(
                authorId: authorId,
                articleId: articleId,
                calculationType: .subscription,
                grossAmount: articleRevenue,
                feeRate: RevenueCalculationType.subscription.platformFeeRate
            )
            
            calculations.append(calculation)
        }
        
        // 儲存計算結果到資料庫
        try await saveRevenueCalculations(calculations)
        
        return calculations
    }
    
    // MARK: - 抖內收益計算
    func calculateDonationRevenue(
        authorId: UUID,
        donationAmount: Int,
        articleId: UUID? = nil
    ) async throws -> RevenueCalculation {
        isLoading = true
        defer { isLoading = false }
        
        let calculation = RevenueCalculation(
            authorId: authorId,
            articleId: articleId,
            calculationType: .donation,
            grossAmount: donationAmount,
            feeRate: RevenueCalculationType.donation.platformFeeRate
        )
        
        // 儲存計算結果到資料庫
        try await saveRevenueCalculations([calculation])
        
        return calculation
    }
    
    // MARK: - 付費閱讀收益計算
    func calculatePaidReadingRevenue(
        authorId: UUID,
        articleId: UUID,
        readingFee: Int,
        readCount: Int
    ) async throws -> RevenueCalculation {
        isLoading = true
        defer { isLoading = false }
        
        let totalAmount = readingFee * readCount
        
        let calculation = RevenueCalculation(
            authorId: authorId,
            articleId: articleId,
            calculationType: .paidReading,
            grossAmount: totalAmount,
            feeRate: RevenueCalculationType.paidReading.platformFeeRate
        )
        
        // 儲存計算結果到資料庫
        try await saveRevenueCalculations([calculation])
        
        return calculation
    }
    
    // MARK: - 獎金收益計算
    func calculateBonusRevenue(
        authorId: UUID,
        bonusAmount: Int,
        articleId: UUID? = nil
    ) async throws -> RevenueCalculation {
        isLoading = true
        defer { isLoading = false }
        
        let calculation = RevenueCalculation(
            authorId: authorId,
            articleId: articleId,
            calculationType: .bonus,
            grossAmount: bonusAmount,
            feeRate: RevenueCalculationType.bonus.platformFeeRate
        )
        
        // 儲存計算結果到資料庫
        try await saveRevenueCalculations([calculation])
        
        return calculation
    }
    
    // MARK: - 反作弊檢查
    func validateRevenueCalculation(
        authorId: UUID,
        calculationType: RevenueCalculationType,
        amount: Int,
        metadata: [String: Any]? = nil
    ) async throws -> FraudDetectionResult {
        
        var fraudScore: Double = 0.0
        var reasons: [String] = []
        
        // 檢查異常大額交易
        if amount > 1000000 {  // 超過 NT$10,000
            fraudScore += 0.3
            reasons.append("異常大額交易")
        }
        
        // 檢查頻繁交易
        let recentCalculations = try await getRecentCalculations(authorId: authorId, hours: 24)
        if recentCalculations.count > 100 {
            fraudScore += 0.4
            reasons.append("頻繁交易")
        }
        
        // 檢查單一來源過多
        let sameTypeCount = recentCalculations.filter { $0.calculationType == calculationType.rawValue }.count
        if sameTypeCount > 50 {
            fraudScore += 0.2
            reasons.append("單一類型交易過多")
        }
        
        // 檢查時間模式異常
        let hourlyDistribution = Dictionary(grouping: recentCalculations) { calculation in
            Calendar.current.component(.hour, from: calculation.calculationDate)
        }
        
        if let maxHour = hourlyDistribution.max(by: { $0.value.count < $1.value.count }),
           maxHour.value.count > recentCalculations.count / 2 {
            fraudScore += 0.1
            reasons.append("時間分佈異常")
        }
        
        let isValid = fraudScore < 0.7
        let confidence = 1.0 - fraudScore
        
        let recommendedAction = fraudScore >= 0.8 ? "拒絕" : fraudScore >= 0.5 ? "人工審核" : "通過"
        
        return FraudDetectionResult(
            isValid: isValid,
            fraudScore: fraudScore,
            reasons: reasons,
            confidence: confidence,
            recommendedAction: recommendedAction
        )
    }
    
    // MARK: - 資料庫操作
    private func saveRevenueCalculations(_ calculations: [RevenueCalculation]) async throws {
        guard let client = supabase.client else {
            throw NSError(domain: "RevenueCalculationService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        for calculation in calculations {
            try await client
                .from("revenue_calculations")
                .insert(calculation)
                .execute()
        }
    }
    
    private func getRecentCalculations(authorId: UUID, hours: Int = 24) async throws -> [RevenueCalculation] {
        guard let client = supabase.client else {
            throw NSError(domain: "RevenueCalculationService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let startTime = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        
        let response: [RevenueCalculation] = try await client
            .from("revenue_calculations")
            .select()
            .eq("author_id", value: authorId)
            .gte("calculation_date", value: startTime.ISO8601Format())
            .order("calculation_date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - 查詢方法
    func getRevenueCalculations(
        authorId: UUID,
        from startDate: Date,
        to endDate: Date,
        type: RevenueCalculationType? = nil
    ) async throws -> [RevenueCalculation] {
        guard let client = supabase.client else {
            throw NSError(domain: "RevenueCalculationService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        var query = client
            .from("revenue_calculations")
            .select()
            .eq("author_id", value: authorId)
            .gte("calculation_date", value: startDate.ISO8601Format())
            .lte("calculation_date", value: endDate.ISO8601Format())
        
        if let type = type {
            query = query.eq("calculation_type", value: type.rawValue)
        }
        
        let response: [RevenueCalculation] = try await query
            .order("calculation_date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func getRevenueCalculationsByArticle(
        articleId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [RevenueCalculation] {
        guard let client = supabase.client else {
            throw NSError(domain: "RevenueCalculationService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let response: [RevenueCalculation] = try await client
            .from("revenue_calculations")
            .select()
            .eq("article_id", value: articleId)
            .gte("calculation_date", value: startDate.ISO8601Format())
            .lte("calculation_date", value: endDate.ISO8601Format())
            .order("calculation_date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func getTotalRevenueByType(
        authorId: UUID,
        type: RevenueCalculationType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Int {
        let calculations = try await getRevenueCalculations(
            authorId: authorId,
            from: startDate,
            to: endDate,
            type: type
        )
        
        return calculations.reduce(0) { $0 + $1.creatorAmount }
    }
    
    // MARK: - 統計方法
    func getAuthorRevenueStats(
        authorId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> (totalGross: Int, totalCreator: Int, totalPlatform: Int, breakdown: [RevenueCalculationType: Int]) {
        let calculations = try await getRevenueCalculations(
            authorId: authorId,
            from: startDate,
            to: endDate
        )
        
        let totalGross = calculations.reduce(0) { $0 + $1.grossAmount }
        let totalCreator = calculations.reduce(0) { $0 + $1.creatorAmount }
        let totalPlatform = calculations.reduce(0) { $0 + $1.platformFee }
        
        var breakdown: [RevenueCalculationType: Int] = [:]
        for type in RevenueCalculationType.allCases {
            breakdown[type] = calculations
                .filter { $0.type == type }
                .reduce(0) { $0 + $1.creatorAmount }
        }
        
        return (totalGross, totalCreator, totalPlatform, breakdown)
    }
}

// MARK: - 輔助擴展
extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}