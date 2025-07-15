import Foundation

struct Subscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let authorId: UUID
    let startedAt: Date?
    let expiresAt: Date
    let status: String
    let subscriptionType: String
    let amountPaid: Int
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case authorId = "author_id"
        case startedAt = "started_at"
        case expiresAt = "expires_at"
        case status
        case subscriptionType = "subscription_type"
        case amountPaid = "amount_paid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), userId: UUID, authorId: UUID, startedAt: Date? = nil, expiresAt: Date, status: String, subscriptionType: String, amountPaid: Int, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.authorId = authorId
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.status = status
        self.subscriptionType = subscriptionType
        self.amountPaid = amountPaid
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 訂閱狀態枚舉
enum SubscriptionStatus: String, CaseIterable {
    case active = "active"
    case expired = "expired"
    case cancelled = "cancelled"
}

// MARK: - 訂閱類型枚舉
enum SubscriptionType: String, CaseIterable {
    case monthly = "monthly"
    case yearly = "yearly"
} 