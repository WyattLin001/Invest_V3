import Foundation

// MARK: - 通知模型
struct AppNotification: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let type: NotificationType
    let isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case type
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - 通知類型
enum NotificationType: String, Codable, CaseIterable {
    case groupInvite = "group_invite"
    case tradingAlert = "trading_alert"
    case rankingUpdate = "ranking_update"
    case systemMessage = "system_message"
    
    var iconName: String {
        switch self {
        case .groupInvite:
            return "person.2.fill"
        case .tradingAlert:
            return "chart.line.uptrend.xyaxis"
        case .rankingUpdate:
            return "trophy.fill"
        case .systemMessage:
            return "info.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .groupInvite:
            return "#00B900" // brandGreen
        case .tradingAlert:
            return "#FD7E14" // brandOrange
        case .rankingUpdate:
            return "#FFD700" // gold
        case .systemMessage:
            return "#007BFF" // blue
        }
    }
} 