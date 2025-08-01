import Foundation
import Supabase
import Auth

@MainActor
class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private init() {}
    
    // MARK: - User Profile Management
    
    /// 創建用戶資料
    func createUserProfile(email: String, username: String, displayName: String, avatarUrl: String? = nil) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        struct UserProfileInsert: Codable {
            let email: String
            let username: String
            let displayName: String
            let avatarUrl: String?
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case email, username
                case displayName = "display_name"
                case avatarUrl = "avatar_url"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let profileData = UserProfileInsert(
            email: email,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .insert(profileData)
            .select()
            .execute()
            .value
        
        guard let profile = response.first else {
            throw NSError(domain: "UserProfileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to create user profile"])
        }
        
        // 保存到本地存儲
        saveCurrentUser(profile)
        
        return profile
    }
    
    /// 獲取用戶資料
    func getUserProfile(id: UUID) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        
        guard let profile = response.first else {
            throw NSError(domain: "UserProfileService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        
        return profile
    }
    
    /// 根據 email 獲取用戶資料
    func getUserProfile(email: String) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("email", value: email)
            .execute()
            .value
        
        guard let profile = response.first else {
            throw NSError(domain: "UserProfileService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        
        return profile
    }
    
    /// 更新用戶資料
    func updateUserProfile(id: UUID, username: String? = nil, displayName: String? = nil, avatarUrl: String? = nil) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        struct UserProfileUpdate: Codable {
            let username: String?
            let displayName: String?
            let avatarUrl: String?
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case username
                case displayName = "display_name"
                case avatarUrl = "avatar_url"
                case updatedAt = "updated_at"
            }
        }
        
        let updateData = UserProfileUpdate(
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            updatedAt: Date()
        )
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .update(updateData)
            .eq("id", value: id)
            .select()
            .execute()
            .value
        
        guard let profile = response.first else {
            throw NSError(domain: "UserProfileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to update user profile"])
        }
        
        // 更新本地存儲
        saveCurrentUser(profile)
        
        return profile
    }
    
    /// 檢查用戶名是否可用
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select("id")
            .eq("username", value: username)
            .execute()
            .value
        
        return response.isEmpty
    }
    
    /// 檢查 email 是否已註冊
    func isEmailRegistered(_ email: String) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select("id")
            .eq("email", value: email)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    // MARK: - Local Storage
    
    /// 保存當前用戶到本地存儲
    func saveCurrentUser(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "current_user")
        }
    }
    
    /// 從本地存儲獲取當前用戶
    func getCurrentUser() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "current_user"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }
    
    /// 清除當前用戶
    func clearCurrentUser() {
        UserDefaults.standard.removeObject(forKey: "current_user")
    }
    
    // MARK: - User Statistics
    
    /// 獲取用戶統計資料
    func getUserStatistics(userId: UUID) async throws -> UserStatistics {
        try SupabaseManager.shared.ensureInitialized()
        
        // 獲取用戶加入的群組數量
        struct GroupMemberCount: Codable {
            let groupId: String
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
            }
        }
        
        let groupsResponse: [GroupMemberCount] = try await client
            .from("group_members")
            .select("group_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // 獲取用戶發表的文章數量
        let articlesResponse: [Article] = try await client
            .from("articles")
            .select("id")
            .eq("author_id", value: userId)
            .execute()
            .value
        
        // 獲取用戶錢包餘額
        let balanceResponse: [UserBalance] = try await client
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let balance = balanceResponse.first?.balance ?? 0
        let withdrawableAmount = balanceResponse.first?.withdrawableAmount ?? 0
        
        return UserStatistics(
            groupsJoined: groupsResponse.count,
            articlesPublished: articlesResponse.count,
            walletBalance: balance,
            withdrawableAmount: withdrawableAmount
        )
    }
}

// MARK: - Supporting Models

struct UserStatistics {
    let groupsJoined: Int
    let articlesPublished: Int
    let walletBalance: Int
    let withdrawableAmount: Int
}

