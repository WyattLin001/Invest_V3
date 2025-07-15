import Foundation

// MARK: - 好友模型
struct Friend: Identifiable, Codable {
    let id: UUID
    let name: String
    let userId: String
    let avatarUrl: String?
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case addedAt = "added_at"
    }
}

// MARK: - 好友狀態
enum FriendStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case blocked = "blocked"
} 