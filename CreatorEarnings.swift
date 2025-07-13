import Foundation

// MARK: - 創作者收益統計模型
struct CreatorEarnings: Identifiable, Codable {
    let id: UUID
    let authorId: UUID
    let totalEarnings: Int          // 累計收益（分）
    let currentMonthEarnings: Int   // 當月收益（分）
    let withdrawableBalance: Int    // 可提領餘額（分）
    let totalWithdrawn: Int         // 累計已提領（分）
    let articlesPublished: Int      // 發布文章數
    let paidSubscribers: Int        // 付費訂閱者數
    let totalFollowers: Int         // 總追蹤數
    let averageReadingTime: Double  // 平均閱讀時間（秒）
    let topArticleId: UUID?         // 最佳表現文章 ID
    let lastEarningsDate: Date?     // 最後收益日期
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case totalEarnings = "total_earnings"
        case currentMonthEarnings = "current_month_earnings"
        case withdrawableBalance = "withdrawable_balance"
        case totalWithdrawn = "total_withdrawn"
        case articlesPublished = "articles_published"
        case paidSubscribers = "paid_subscribers"
        case totalFollowers = "total_followers"
        case averageReadingTime = "average_reading_time"
        case topArticleId = "top_article_id"
        case lastEarningsDate = "last_earnings_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        authorId: UUID,
        totalEarnings: Int = 0,
        currentMonthEarnings: Int = 0,
        withdrawableBalance: Int = 0,
        totalWithdrawn: Int = 0,
        articlesPublished: Int = 0,
        paidSubscribers: Int = 0,
        totalFollowers: Int = 0,
        averageReadingTime: Double = 0.0,
        topArticleId: UUID? = nil,
        lastEarningsDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.totalEarnings = totalEarnings
        self.currentMonthEarnings = currentMonthEarnings
        self.withdrawableBalance = withdrawableBalance
        self.totalWithdrawn = totalWithdrawn
        self.articlesPublished = articlesPublished
        self.paidSubscribers = paidSubscribers
        self.totalFollowers = totalFollowers
        self.averageReadingTime = averageReadingTime
        self.topArticleId = topArticleId
        self.lastEarningsDate = lastEarningsDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 創作者收益擴展
extension CreatorEarnings {
    var formattedTotalEarnings: String {
        return "NT$\(totalEarnings)"
    }
    
    var formattedCurrentMonthEarnings: String {
        return "NT$\(currentMonthEarnings)"
    }
    
    var formattedWithdrawableBalance: String {
        return "NT$\(withdrawableBalance)"
    }
    
    var formattedTotalWithdrawn: String {
        return "NT$\(totalWithdrawn)"
    }
    
    var isEligibleForWithdrawal: Bool {
        return withdrawableBalance >= 100000  // NT$1,000 = 100000 分
    }
    
    var minimumWithdrawalAmount: Int {
        return 100000  // NT$1,000
    }
    
    var formattedAverageReadingTime: String {
        let minutes = Int(averageReadingTime / 60)
        let seconds = Int(averageReadingTime.truncatingRemainder(dividingBy: 60))
        return "\(minutes)分\(seconds)秒"
    }
    
    var engagementRate: Double {
        guard totalFollowers > 0 else { return 0.0 }
        return Double(paidSubscribers) / Double(totalFollowers)
    }
    
    var formattedEngagementRate: String {
        return String(format: "%.1f%%", engagementRate * 100)
    }
    
    var averageEarningsPerArticle: Int {
        guard articlesPublished > 0 else { return 0 }
        return totalEarnings / articlesPublished
    }
    
    var formattedAverageEarningsPerArticle: String {
        return "NT$\(averageEarningsPerArticle)"
    }
}

// MARK: - 文章表現統計
struct ArticlePerformance: Identifiable, Codable {
    let id: UUID
    let articleId: UUID
    let title: String
    let totalReads: Int
    let paidReads: Int
    let totalEarnings: Int
    let donationsReceived: Int
    let donationAmount: Int
    let averageReadingTime: Double
    let engagementScore: Double
    let publishedAt: Date
    let lastReadAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case title
        case totalReads = "total_reads"
        case paidReads = "paid_reads"
        case totalEarnings = "total_earnings"
        case donationsReceived = "donations_received"
        case donationAmount = "donation_amount"
        case averageReadingTime = "average_reading_time"
        case engagementScore = "engagement_score"
        case publishedAt = "published_at"
        case lastReadAt = "last_read_at"
    }
    
    var formattedTotalEarnings: String {
        return "NT$\(totalEarnings)"
    }
    
    var formattedDonationAmount: String {
        return "NT$\(donationAmount)"
    }
    
    var paidReadRate: Double {
        guard totalReads > 0 else { return 0.0 }
        return Double(paidReads) / Double(totalReads)
    }
    
    var formattedPaidReadRate: String {
        return String(format: "%.1f%%", paidReadRate * 100)
    }
    
    var earningsPerRead: Int {
        guard paidReads > 0 else { return 0 }
        return totalEarnings / paidReads
    }
    
    var formattedEarningsPerRead: String {
        return "NT$\(earningsPerRead)"
    }
}

// MARK: - 創作者儀表板數據
struct CreatorDashboardData: Codable {
    let earnings: CreatorEarnings
    let recentSettlements: [MonthlySettlement]
    let topPerformingArticles: [ArticlePerformance]
    let monthlyTrends: [MonthlyTrend]
    let fanStats: FanStatistics
}

// MARK: - 月度趨勢
struct MonthlyTrend: Identifiable, Codable {
    let id: UUID
    let month: Int
    let year: Int
    let earnings: Int
    let subscribers: Int
    let articlesPublished: Int
    let totalReads: Int
    
    var formattedEarnings: String {
        return "NT$\(earnings)"
    }
    
    var periodLabel: String {
        return "\(year)/\(month)"
    }
}

// MARK: - 粉絲統計
struct FanStatistics: Codable {
    let totalFollowers: Int
    let paidSubscribers: Int
    let newFollowersThisMonth: Int
    let newSubscribersThisMonth: Int
    let subscriptionRate: Double
    let averageSubscriptionDuration: Double  // 天數
    let topFanContributions: [FanContribution]
    
    var formattedSubscriptionRate: String {
        return String(format: "%.1f%%", subscriptionRate * 100)
    }
    
    var formattedAverageSubscriptionDuration: String {
        return String(format: "%.1f天", averageSubscriptionDuration)
    }
}

// MARK: - 粉絲貢獻
struct FanContribution: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let totalContribution: Int
    let subscriptionMonths: Int
    let donationCount: Int
    let lastActivityDate: Date
    
    var formattedTotalContribution: String {
        return "NT$\(totalContribution)"
    }
}