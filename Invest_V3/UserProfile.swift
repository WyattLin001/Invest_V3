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
