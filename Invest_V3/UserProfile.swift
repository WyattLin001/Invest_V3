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
    
    // 標準 init 方法
    init(id: UUID, email: String, username: String, displayName: String, avatarUrl: String? = nil, bio: String? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // 自定義解碼，處理 String UUID 轉換
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 處理 ID：可能是 String 或 UUID
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = UUID(uuidString: idString) ?? UUID()
        } else {
            self.id = try container.decode(UUID.self, forKey: .id)
        }
        
        self.email = try container.decode(String.self, forKey: .email)
        self.username = try container.decode(String.self, forKey: .username)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    // 自定義編碼，輸出 String UUID 給 Supabase
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id.uuidString, forKey: .id) // 總是編碼為 String
        try container.encode(email, forKey: .email)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
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
