import Foundation
import Supabase

// MARK: - 創作者收益管理服務
@MainActor
class CreatorRevenueService: ObservableObject {
    private let supabase = SupabaseManager.shared
    private let settlementService = MonthlySettlementService()
    
    @Published var isLoading = false
    @Published var error: Error?
    @Published var creatorEarnings: CreatorEarnings?
    @Published var withdrawalRequests: [WithdrawalRequest] = []
    
    // MARK: - 創作者收益統計
    func getCreatorEarnings(authorId: UUID) async throws -> CreatorEarnings {
        isLoading = true
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            throw NSError(domain: "CreatorRevenueService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        // 查詢現有收益統計
        let response: [CreatorEarnings] = try await client
            .from("creator_earnings")
            .select()
            .eq("author_id", value: authorId)
            .execute()
            .value
        
        if let earnings = response.first {
            // 更新統計資料
            let updatedEarnings = try await updateCreatorEarnings(earnings: earnings)
            creatorEarnings = updatedEarnings
            return updatedEarnings
        } else {
            // 創建新的收益統計
            let newEarnings = try await createCreatorEarnings(authorId: authorId)
            creatorEarnings = newEarnings
            return newEarnings
        }
    }
    
    // MARK: - 更新創作者收益統計
    private func updateCreatorEarnings(earnings: CreatorEarnings) async throws -> CreatorEarnings {
        guard let client = supabase.client else {
            throw NSError(domain: "CreatorRevenueService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        // 計算總收益
        let totalEarnings = try await calculateTotalEarnings(authorId: earnings.authorId)
        
        // 計算當月收益
        let currentMonthEarnings = try await calculateCurrentMonthEarnings(authorId: earnings.authorId)
        
        // 計算可提領餘額
        let withdrawableBalance = try await calculateWithdrawableBalance(authorId: earnings.authorId)
        
        // 計算已提領金額
        let totalWithdrawn = try await calculateTotalWithdrawn(authorId: earnings.authorId)
        
        // 獲取文章統計
        let articlesPublished = try await getArticlesPublished(authorId: earnings.authorId)
        
        // 獲取訂閱者統計
        let (paidSubscribers, totalFollowers) = try await getSubscriberStats(authorId: earnings.authorId)
        
        // 計算平均閱讀時間
        let averageReadingTime = try await calculateAverageReadingTime(authorId: earnings.authorId)
        
        // 獲取最佳文章
        let topArticleId = try await getTopPerformingArticle(authorId: earnings.authorId)
        
        let updatedEarnings = CreatorEarnings(
            id: earnings.id,
            authorId: earnings.authorId,
            totalEarnings: totalEarnings,
            currentMonthEarnings: currentMonthEarnings,
            withdrawableBalance: withdrawableBalance,
            totalWithdrawn: totalWithdrawn,
            articlesPublished: articlesPublished,
            paidSubscribers: paidSubscribers,
            totalFollowers: totalFollowers,
            averageReadingTime: averageReadingTime,
            topArticleId: topArticleId,
            lastEarningsDate: Date(),
            createdAt: earnings.createdAt,
            updatedAt: Date()
        )
        
        // 更新資料庫
        try await client
            .from("creator_earnings")
            .update(updatedEarnings)
            .eq("id", value: earnings.id)
            .execute()
        
        return updatedEarnings
    }
    
    // MARK: - 創建創作者收益統計
    private func createCreatorEarnings(authorId: UUID) async throws -> CreatorEarnings {
        guard let client = supabase.client else {
            throw NSError(domain: "CreatorRevenueService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let newEarnings = CreatorEarnings(
            authorId: authorId,
            totalEarnings: 0,
            currentMonthEarnings: 0,
            withdrawableBalance: 0,
            totalWithdrawn: 0,
            articlesPublished: 0,
            paidSubscribers: 0,
            totalFollowers: 0,
            averageReadingTime: 0.0,
            topArticleId: nil,
            lastEarningsDate: nil
        )
        
        try await client
            .from("creator_earnings")
            .insert(newEarnings)
            .execute()
        
        return newEarnings
    }
    
    // MARK: - 提領申請
    func submitWithdrawalRequest(
        userId: UUID,
        amount: Int,
        method: WithdrawalMethod,
        bankAccount: String? = nil,
        bankCode: String? = nil,
        accountHolder: String? = nil,
        phoneNumber: String? = nil,
        email: String? = nil,
        reason: String? = nil
    ) async throws -> WithdrawalRequest {
        isLoading = true
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            throw NSError(domain: "CreatorRevenueService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        // 檢查可提領餘額
        let earnings = try await getCreatorEarnings(authorId: userId)
        guard earnings.withdrawableBalance >= amount else {
            throw WithdrawalError.insufficientBalance
        }
        
        // 檢查最低提領金額
        guard amount >= method.minimumAmount else {
            throw WithdrawalError.belowMinimumAmount
        }
        
        // 檢查最高提領金額
        guard amount <= method.maximumAmount else {
            throw WithdrawalError.exceedsMaximumAmount
        }
        
        let withdrawalRequest = WithdrawalRequest(
            userId: userId,
            requestAmount: amount,
            paymentMethod: method,
            bankAccount: bankAccount,
            bankCode: bankCode,
            accountHolder: accountHolder,
            phoneNumber: phoneNumber,
            email: email,
            reason: reason
        )
        
        try await client
            .from("withdrawal_requests")
            .insert(withdrawalRequest)
            .execute()
        
        return withdrawalRequest
    }
    
    // MARK: - 獲取提領申請
    func getWithdrawalRequests(userId: UUID, limit: Int = 20) async throws -> [WithdrawalRequest] {
        guard let client = supabase.client else {
            throw NSError(domain: "CreatorRevenueService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let response: [WithdrawalRequest] = try await client
            .from("withdrawal_requests")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        withdrawalRequests = response
        return response
    }
    
    // MARK: - 取消提領申請
    func cancelWithdrawalRequest(requestId: UUID) async throws {
        guard let client = supabase.client else {
            throw NSError(domain: "CreatorRevenueService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Supabase 未初始化"])
        }
        
        let update = [
            "status": WithdrawalStatus.cancelled.rawValue,
            "updated_at": Date().ISO8601Format()
        ]
        
        try await client
            .from("withdrawal_requests")
            .update(update)
            .eq("id", value: requestId)
            .execute()
    }
    
    // MARK: - 獲取創作者儀表板數據
    func getCreatorDashboardData(authorId: UUID) async throws -> CreatorDashboardData {
        isLoading = true
        defer { isLoading = false }
        
        // 獲取收益統計
        let earnings = try await getCreatorEarnings(authorId: authorId)
        
        // 獲取最近的結算記錄
        let recentSettlements = try await settlementService.getAuthorSettlements(authorId: authorId, limit: 6)
        
        // 獲取最佳表現文章
        let topPerformingArticles = try await getTopPerformingArticles(authorId: authorId)
        
        // 獲取月度趨勢
        let monthlyTrends = try await getMonthlyTrends(authorId: authorId)
        
        // 獲取粉絲統計
        let fanStats = try await getFanStatistics(authorId: authorId)
        
        return CreatorDashboardData(
            earnings: earnings,
            recentSettlements: recentSettlements,
            topPerformingArticles: topPerformingArticles,
            monthlyTrends: monthlyTrends,
            fanStats: fanStats
        )
    }
    
    // MARK: - 私有計算方法
    private func calculateTotalEarnings(authorId: UUID) async throws -> Int {
        guard let client = supabase.client else { return 0 }
        
        let response: [MonthlySettlement] = try await client
            .from("monthly_settlements")
            .select("total_creator_earnings")
            .eq("author_id", value: authorId)
            .execute()
            .value
        
        return response.reduce(0) { $0 + $1.totalCreatorEarnings }
    }
    
    private func calculateCurrentMonthEarnings(authorId: UUID) async throws -> Int {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        if let settlement = try await settlementService.getSettlement(authorId: authorId, year: year, month: month) {
            return settlement.totalCreatorEarnings
        }
        
        return 0
    }
    
    private func calculateWithdrawableBalance(authorId: UUID) async throws -> Int {
        let totalEarnings = try await calculateTotalEarnings(authorId: authorId)
        let totalWithdrawn = try await calculateTotalWithdrawn(authorId: authorId)
        return totalEarnings - totalWithdrawn
    }
    
    private func calculateTotalWithdrawn(authorId: UUID) async throws -> Int {
        guard let client = supabase.client else { return 0 }
        
        let response: [WithdrawalRequest] = try await client
            .from("withdrawal_requests")
            .select("actual_amount")
            .eq("user_id", value: authorId)
            .eq("status", value: WithdrawalStatus.completed.rawValue)
            .execute()
            .value
        
        return response.reduce(0) { $0 + $1.actualAmount }
    }
    
    private func getArticlesPublished(authorId: UUID) async throws -> Int {
        guard let client = supabase.client else { return 0 }
        
        let response: [Article] = try await client
            .from("articles")
            .select("id")
            .eq("author_id", value: authorId)
            .execute()
            .value
        
        return response.count
    }
    
    private func getSubscriberStats(authorId: UUID) async throws -> (paidSubscribers: Int, totalFollowers: Int) {
        guard let client = supabase.client else { return (0, 0) }
        
        // 這裡應該實際查詢訂閱和關注數據
        // 暫時返回模擬數據
        return (123, 456)
    }
    
    private func calculateAverageReadingTime(authorId: UUID) async throws -> Double {
        guard let client = supabase.client else { return 0.0 }
        
        let response: [ReadingAnalytics] = try await client
            .from("reading_analytics")
            .select("reading_duration")
            .eq("author_id", value: authorId)
            .eq("is_valid_read", value: true)
            .execute()
            .value
        
        guard !response.isEmpty else { return 0.0 }
        
        let totalDuration = response.reduce(0.0) { $0 + $1.readingDuration }
        return totalDuration / Double(response.count)
    }
    
    private func getTopPerformingArticle(authorId: UUID) async throws -> UUID? {
        guard let client = supabase.client else { return nil }
        
        let response: [ArticlePerformance] = try await client
            .from("article_performances")
            .select()
            .eq("author_id", value: authorId)
            .order("total_earnings", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return response.first?.articleId
    }
    
    private func getTopPerformingArticles(authorId: UUID) async throws -> [ArticlePerformance] {
        guard let client = supabase.client else { return [] }
        
        let response: [ArticlePerformance] = try await client
            .from("article_performances")
            .select()
            .eq("author_id", value: authorId)
            .order("total_earnings", ascending: false)
            .limit(10)
            .execute()
            .value
        
        return response
    }
    
    private func getMonthlyTrends(authorId: UUID) async throws -> [MonthlyTrend] {
        // 根據月度結算生成趨勢數據
        let settlements = try await settlementService.getAuthorSettlements(authorId: authorId, limit: 12)
        
        return settlements.map { settlement in
            MonthlyTrend(
                month: settlement.settlementMonth,
                year: settlement.settlementYear,
                earnings: settlement.totalCreatorEarnings,
                subscribers: 0, // 需要實際訂閱數據
                articlesPublished: 0, // 需要實際文章數據
                totalReads: 0 // 需要實際閱讀數據
            )
        }
    }
    
    private func getFanStatistics(authorId: UUID) async throws -> FanStatistics {
        // 這裡應該實際查詢粉絲統計數據
        // 暫時返回模擬數據
        return FanStatistics(
            totalFollowers: 456,
            paidSubscribers: 123,
            newFollowersThisMonth: 23,
            newSubscribersThisMonth: 12,
            subscriptionRate: 0.27,
            averageSubscriptionDuration: 45.5,
            topFanContributions: []
        )
    }
}

// MARK: - 提領錯誤類型
enum WithdrawalError: LocalizedError {
    case insufficientBalance
    case belowMinimumAmount
    case exceedsMaximumAmount
    case tooManyRequests
    case accountNotVerified
    
    var errorDescription: String? {
        switch self {
        case .insufficientBalance:
            return "餘額不足"
        case .belowMinimumAmount:
            return "低於最低提領金額"
        case .exceedsMaximumAmount:
            return "超過最高提領金額"
        case .tooManyRequests:
            return "提領申請過於頻繁"
        case .accountNotVerified:
            return "帳戶尚未驗證"
        }
    }
}