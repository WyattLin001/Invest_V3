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
    var firstName: String?
    var lastName: String?
    var fullName: String?
    var phone: String?
    var website: String?
    var location: String?
    var socialLinks: [String: String]?
    var investmentPhilosophy: String?
    var specializations: [String]
    var yearsExperience: Int
    var followerCount: Int
    var followingCount: Int
    var articleCount: Int
    var totalReturnRate: Double
    var isVerified: Bool
    var status: String
    let userId: String
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case phone
        case website
        case location
        case socialLinks = "social_links"
        case investmentPhilosophy = "investment_philosophy"
        case specializations
        case yearsExperience = "years_experience"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case articleCount = "article_count"
        case totalReturnRate = "total_return_rate"
        case isVerified = "is_verified"
        case status
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 標準 init 方法
    init(id: UUID, email: String, username: String, displayName: String, avatarUrl: String? = nil, bio: String? = nil, firstName: String? = nil, lastName: String? = nil, fullName: String? = nil, phone: String? = nil, website: String? = nil, location: String? = nil, socialLinks: [String: String]? = nil, investmentPhilosophy: String? = nil, specializations: [String] = [], yearsExperience: Int = 0, followerCount: Int = 0, followingCount: Int = 0, articleCount: Int = 0, totalReturnRate: Double = 0.0, isVerified: Bool = false, status: String = "active", userId: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.phone = phone
        self.website = website
        self.location = location
        self.socialLinks = socialLinks
        self.investmentPhilosophy = investmentPhilosophy
        self.specializations = specializations
        self.yearsExperience = yearsExperience
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.articleCount = articleCount
        self.totalReturnRate = totalReturnRate
        self.isVerified = isVerified
        self.status = status
        self.userId = userId
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
        self.firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        self.lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.website = try container.decodeIfPresent(String.self, forKey: .website)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.socialLinks = try container.decodeIfPresent([String: String].self, forKey: .socialLinks)
        self.investmentPhilosophy = try container.decodeIfPresent(String.self, forKey: .investmentPhilosophy)
        self.specializations = try container.decodeIfPresent([String].self, forKey: .specializations) ?? []
        self.yearsExperience = try container.decodeIfPresent(Int.self, forKey: .yearsExperience) ?? 0
        self.followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? 0
        self.followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        self.articleCount = try container.decodeIfPresent(Int.self, forKey: .articleCount) ?? 0
        self.totalReturnRate = try container.decodeIfPresent(Double.self, forKey: .totalReturnRate) ?? 0.0
        self.isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        self.userId = try container.decode(String.self, forKey: .userId)
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
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(fullName, forKey: .fullName)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(socialLinks, forKey: .socialLinks)
        try container.encodeIfPresent(investmentPhilosophy, forKey: .investmentPhilosophy)
        try container.encode(specializations, forKey: .specializations)
        try container.encode(yearsExperience, forKey: .yearsExperience)
        try container.encode(followerCount, forKey: .followerCount)
        try container.encode(followingCount, forKey: .followingCount)
        try container.encode(articleCount, forKey: .articleCount)
        try container.encode(totalReturnRate, forKey: .totalReturnRate)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(status, forKey: .status)
        try container.encode(userId, forKey: .userId)
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
