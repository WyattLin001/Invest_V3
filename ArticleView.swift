import Foundation

struct ArticleView: Codable, Identifiable {
    let id: UUID
    let articleId: UUID
    let userId: UUID
    let viewedAt: Date
    let isPaid: Bool
    let readingTimeSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case viewedAt = "viewed_at"
        case isPaid = "is_paid"
        case readingTimeSeconds = "reading_time_seconds"
    }
    
    init(id: UUID = UUID(), articleId: UUID, userId: UUID, viewedAt: Date, isPaid: Bool, readingTimeSeconds: Int) {
        self.id = id
        self.articleId = articleId
        self.userId = userId
        self.viewedAt = viewedAt
        self.isPaid = isPaid
        self.readingTimeSeconds = readingTimeSeconds
    }
} 