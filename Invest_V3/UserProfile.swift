//
//  Untitled.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String
    let username: String
    var displayName: String
    var avatarUrl: String?
    var bio: String?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 通知設定模型
struct NotificationSettings: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let pushNotificationsEnabled: Bool
    let marketUpdatesEnabled: Bool
    let chatNotificationsEnabled: Bool
    let investmentNotificationsEnabled: Bool
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pushNotificationsEnabled = "push_notifications_enabled"
        case marketUpdatesEnabled = "market_updates_enabled"
        case chatNotificationsEnabled = "chat_notifications_enabled"
        case investmentNotificationsEnabled = "investment_notifications_enabled"
        case updatedAt = "updated_at"
    }
    
    init(userId: UUID, pushNotificationsEnabled: Bool, marketUpdatesEnabled: Bool, chatNotificationsEnabled: Bool, investmentNotificationsEnabled: Bool, updatedAt: Date) {
        self.id = UUID()
        self.userId = userId
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.marketUpdatesEnabled = marketUpdatesEnabled
        self.chatNotificationsEnabled = chatNotificationsEnabled
        self.investmentNotificationsEnabled = investmentNotificationsEnabled
        self.updatedAt = updatedAt
    }
}
