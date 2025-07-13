import Foundation

// MARK: - 平台會員訂閱模型
struct PlatformSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let subscriptionType: String // "monthly", "yearly"
    let startDate: Date
    let endDate: Date
    let isActive: Bool
    let amount: Int // 訂閱費用（代幣）
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subscriptionType = "subscription_type"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case amount
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 檢查訂閱是否有效
    var isValid: Bool {
        return isActive && endDate > Date()
    }
    
    // 剩餘天數
    var remainingDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }
}

// MARK: - 文章閱讀記錄（用於分潤計算）
struct ArticleReadRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let articleId: UUID
    let authorId: UUID
    let readDate: Date
    let readingTimeSeconds: Int
    let subscriptionId: UUID // 關聯的平台訂閱
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case articleId = "article_id"
        case authorId = "author_id"
        case readDate = "read_date"
        case readingTimeSeconds = "reading_time_seconds"
        case subscriptionId = "subscription_id"
        case createdAt = "created_at"
    }
}

// MARK: - 作者分潤記錄
struct AuthorRevenue: Codable, Identifiable {
    let id: UUID
    let authorId: UUID
    let subscriptionId: UUID
    let articleId: UUID
    let revenueAmount: Int // 分潤金額（代幣）
    let month: String // 格式: "2025-01"
    let readCount: Int // 該月該文章的閱讀次數
    let totalMonthlyReads: Int // 該月總閱讀次數（用於計算分潤比例）
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case subscriptionId = "subscription_id"
        case articleId = "article_id"
        case revenueAmount = "revenue_amount"
        case month
        case readCount = "read_count"
        case totalMonthlyReads = "total_monthly_reads"
        case createdAt = "created_at"
    }
} 