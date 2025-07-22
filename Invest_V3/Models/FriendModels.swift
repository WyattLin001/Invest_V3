//
//  FriendModels.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  好友系統數據模型
//

import Foundation

// MARK: - 好友搜尋結果模型

struct UserSearchResult: Identifiable, Codable {
    let id: UUID
    let userID: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let isFriend: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case isFriend = "is_friend"
    }
}

// MARK: - 好友關係模型

struct Friendship: Identifiable, Codable {
    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    let status: FriendshipStatus
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

// MARK: - 好友關係狀態

enum FriendshipStatus: String, CaseIterable, Codable {
    case pending = "pending"     // 待處理
    case accepted = "accepted"   // 已接受
    case declined = "declined"   // 已拒絕
    case blocked = "blocked"     // 已封鎖
    
    var displayName: String {
        switch self {
        case .pending: return "待處理"
        case .accepted: return "已接受"
        case .declined: return "已拒絕"  
        case .blocked: return "已封鎖"
        }
    }
}

// MARK: - 好友信息模型

struct FriendInfo: Identifiable, Codable {
    let id: UUID
    let friendUserID: UUID
    let userID: UUID
    let friendCustomID: String
    let friendDisplayName: String
    let friendAvatarUrl: String?
    let status: FriendshipStatus
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case friendUserID = "friend_user_id"
        case userID = "user_id"
        case friendCustomID = "friend_custom_id"
        case friendDisplayName = "friend_display_name"
        case friendAvatarUrl = "friend_avatar_url"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - API 響應模型

struct FriendRequestResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - 好友請求列表項目

struct FriendRequest: Identifiable, Codable {
    let id: UUID
    let requesterUserID: String
    let requesterDisplayName: String
    let requesterAvatarUrl: String?
    let status: FriendshipStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterUserID = "requester_user_id"
        case requesterDisplayName = "requester_display_name"
        case requesterAvatarUrl = "requester_avatar_url"
        case status
        case createdAt = "created_at"
    }
}