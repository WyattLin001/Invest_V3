//
//  FriendsModels.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/27.
//  好友系統數據模型
//

import Foundation
import SwiftUI

// MARK: - 好友資料模型
struct Friend: Identifiable, Codable {
    let id: UUID
    let userId: String
    let userName: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let isOnline: Bool
    let lastActiveDate: Date
    let friendshipDate: Date
    let investmentStyle: InvestmentStyle?
    let performanceScore: Double
    let totalReturn: Double
    let riskLevel: RiskLevel
    
    // 格式化的績效顯示
    var formattedReturn: String {
        let prefix = totalReturn >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", prefix, totalReturn)
    }
    
    // 格式化的績效分數
    var formattedScore: String {
        return String(format: "%.1f", performanceScore)
    }
    
    // 在線狀態顏色
    var onlineStatusColor: Color {
        return isOnline ? .green : .gray
    }
    
    // 風險等級顏色
    var riskLevelColor: Color {
        switch riskLevel {
        case .conservative:
            return .blue
        case .moderate:
            return .orange
        case .aggressive:
            return .red
        }
    }
}

// MARK: - 好友請求模型
struct FriendRequest: Identifiable, Codable {
    let id: UUID
    let fromUserId: String
    let fromUserName: String
    let fromUserDisplayName: String
    let fromUserAvatarUrl: String?
    let toUserId: String
    let message: String?
    let requestDate: Date
    let status: FriendRequestStatus
    
    enum FriendRequestStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case cancelled = "cancelled"
        
        var displayName: String {
            switch self {
            case .pending: return "待回應"
            case .accepted: return "已接受"
            case .declined: return "已拒絕"
            case .cancelled: return "已取消"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .accepted: return .green
            case .declined: return .red
            case .cancelled: return .gray
            }
        }
    }
}

// MARK: - 投資風格枚舉
enum InvestmentStyle: String, Codable, CaseIterable {
    case growth = "growth"
    case value = "value"
    case dividend = "dividend"
    case momentum = "momentum"
    case balanced = "balanced"
    case tech = "tech"
    case healthcare = "healthcare"
    case finance = "finance"
    
    var displayName: String {
        switch self {
        case .growth: return "成長型"
        case .value: return "價值型"
        case .dividend: return "股息型"
        case .momentum: return "動能型"
        case .balanced: return "平衡型"
        case .tech: return "科技型"
        case .healthcare: return "醫療型"
        case .finance: return "金融型"
        }
    }
    
    var icon: String {
        switch self {
        case .growth: return "chart.line.uptrend.xyaxis"
        case .value: return "dollarsign.circle"
        case .dividend: return "banknote"
        case .momentum: return "speedometer"
        case .balanced: return "scale.3d"
        case .tech: return "laptopcomputer"
        case .healthcare: return "cross.circle"
        case .finance: return "building.columns"
        }
    }
    
    var color: Color {
        switch self {
        case .growth: return .green
        case .value: return .blue
        case .dividend: return .purple
        case .momentum: return .red
        case .balanced: return .orange
        case .tech: return .cyan
        case .healthcare: return .pink
        case .finance: return .indigo
        }
    }
}

// MARK: - 風險等級枚舉
enum RiskLevel: String, Codable, CaseIterable {
    case conservative = "conservative"
    case moderate = "moderate"
    case aggressive = "aggressive"
    
    var displayName: String {
        switch self {
        case .conservative: return "保守型"
        case .moderate: return "穩健型"
        case .aggressive: return "積極型"
        }
    }
    
    var icon: String {
        switch self {
        case .conservative: return "shield.fill"
        case .moderate: return "dial.min"
        case .aggressive: return "flame.fill"
        }
    }
}

// MARK: - 好友活動模型
struct FriendActivity: Identifiable, Codable {
    let id: UUID
    let friendId: String
    let friendName: String
    let activityType: ActivityType
    let description: String
    let timestamp: Date
    let data: ActivityData?
    
    enum ActivityType: String, Codable {
        case trade = "trade"
        case achievement = "achievement"
        case milestone = "milestone"
        case groupJoin = "group_join"
        
        var icon: String {
            switch self {
            case .trade: return "arrow.left.arrow.right"
            case .achievement: return "trophy.fill"
            case .milestone: return "flag.fill"
            case .groupJoin: return "person.2.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .trade: return .blue
            case .achievement: return .yellow
            case .milestone: return .purple
            case .groupJoin: return .green
            }
        }
    }
    
    struct ActivityData: Codable {
        let symbol: String?
        let amount: Double?
        let returnRate: Double?
        let achievementName: String?
        let milestoneValue: String?
        let groupName: String?
    }
}

// MARK: - 好友關係模型
struct Friendship: Identifiable, Codable {
    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    let status: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 好友搜尋結果模型
struct FriendSearchResult: Identifiable, Codable {
    let id: UUID
    let userId: String
    let userName: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let investmentStyle: InvestmentStyle?
    let performanceScore: Double
    let totalReturn: Double
    let mutualFriendsCount: Int
    let isAlreadyFriend: Bool
    let hasPendingRequest: Bool
    
    // 格式化的共同好友數量
    var mutualFriendsText: String {
        if mutualFriendsCount > 0 {
            return "\(mutualFriendsCount) 位共同好友"
        } else {
            return "沒有共同好友"
        }
    }
}

// MARK: - Supabase 模型擴展
extension Friend {
    init(from supabaseData: [String: Any]) throws {
        guard let idString = supabaseData["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = supabaseData["user_id"] as? String,
              let userName = supabaseData["user_name"] as? String,
              let displayName = supabaseData["display_name"] as? String,
              let isOnline = supabaseData["is_online"] as? Bool,
              let lastActiveDateString = supabaseData["last_active_date"] as? String,
              let friendshipDateString = supabaseData["friendship_date"] as? String,
              let performanceScore = supabaseData["performance_score"] as? Double,
              let totalReturn = supabaseData["total_return"] as? Double,
              let riskLevelString = supabaseData["risk_level"] as? String,
              let riskLevel = RiskLevel(rawValue: riskLevelString) else {
            throw NSError(domain: "FriendModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid friend data"])
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let lastActiveDate = dateFormatter.date(from: lastActiveDateString),
              let friendshipDate = dateFormatter.date(from: friendshipDateString) else {
            throw NSError(domain: "FriendModelError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
        }
        
        self.id = id
        self.userId = userId
        self.userName = userName
        self.displayName = displayName
        self.avatarUrl = supabaseData["avatar_url"] as? String
        self.bio = supabaseData["bio"] as? String
        self.isOnline = isOnline
        self.lastActiveDate = lastActiveDate
        self.friendshipDate = friendshipDate
        self.investmentStyle = (supabaseData["investment_style"] as? String).flatMap(InvestmentStyle.init(rawValue:))
        self.performanceScore = performanceScore
        self.totalReturn = totalReturn
        self.riskLevel = riskLevel
    }
}

extension FriendRequest {
    init(from supabaseData: [String: Any]) throws {
        guard let idString = supabaseData["id"] as? String,
              let id = UUID(uuidString: idString),
              let fromUserId = supabaseData["from_user_id"] as? String,
              let fromUserName = supabaseData["from_user_name"] as? String,
              let fromUserDisplayName = supabaseData["from_user_display_name"] as? String,
              let toUserId = supabaseData["to_user_id"] as? String,
              let requestDateString = supabaseData["request_date"] as? String,
              let statusString = supabaseData["status"] as? String,
              let status = FriendRequestStatus(rawValue: statusString) else {
            throw NSError(domain: "FriendRequestModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid friend request data"])
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let requestDate = dateFormatter.date(from: requestDateString) else {
            throw NSError(domain: "FriendRequestModelError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
        }
        
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserDisplayName = fromUserDisplayName
        self.fromUserAvatarUrl = supabaseData["from_user_avatar_url"] as? String
        self.toUserId = toUserId
        self.message = supabaseData["message"] as? String
        self.requestDate = requestDate
        self.status = status
    }
}

// MARK: - Debug 測試數據 (僅限開發模式)
#if DEBUG
extension Friend {
    static func mockFriends() -> [Friend] {
        [
            Friend(
                id: UUID(),
                userId: "user1",
                userName: "AliceInvestor",
                displayName: "Alice Chen",
                avatarUrl: nil,
                bio: "專注於科技股投資，喜歡長期持有成長型公司",
                isOnline: true,
                lastActiveDate: Date(),
                friendshipDate: Date().addingTimeInterval(-86400 * 30),
                investmentStyle: .tech,
                performanceScore: 8.5,
                totalReturn: 15.2,
                riskLevel: .moderate
            ),
            Friend(
                id: UUID(),
                userId: "user2",
                userName: "BobTrader",
                displayName: "Bob Wang",
                avatarUrl: nil,
                bio: "價值投資者，尋找被低估的優質股票",
                isOnline: false,
                lastActiveDate: Date().addingTimeInterval(-3600),
                friendshipDate: Date().addingTimeInterval(-86400 * 60),
                investmentStyle: .value,
                performanceScore: 7.8,
                totalReturn: 12.8,
                riskLevel: .conservative
            ),
            Friend(
                id: UUID(),
                userId: "user3",
                userName: "CarolDividend",
                displayName: "Carol Liu",
                avatarUrl: nil,
                bio: "專注於高股息股票，追求穩定的現金流",
                isOnline: true,
                lastActiveDate: Date().addingTimeInterval(-300),
                friendshipDate: Date().addingTimeInterval(-86400 * 90),
                investmentStyle: .dividend,
                performanceScore: 9.1,
                totalReturn: 18.5,
                riskLevel: .moderate
            )
        ]
    }
}
#endif