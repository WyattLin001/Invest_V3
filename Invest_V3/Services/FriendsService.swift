import Foundation
import Supabase

/// 好友管理服務
/// 負責處理所有與好友相關的操作，包括添加好友、搜尋用戶、管理好友列表等
@MainActor
class FriendsService: ObservableObject {
    static let shared = FriendsService()
    
    private var client: SupabaseClient {
        SupabaseService.shared.client
    }
    
    private init() {}
    
    // MARK: - 好友基本操作
    
    /// 發送好友請求
    func sendFriendRequest(to userId: String, message: String? = nil) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        let currentUserProfile = try await ServiceCoordinator.shared.core.getUserProfile(userId: currentUser.id)
        
        Logger.info("🤝 發送好友請求到: \(userId)", category: .database)
        
        // 檢查是否已經是好友或已有待處理請求
        let existingRelationship = try await checkExistingRelationship(with: userId)
        
        switch existingRelationship {
        case .alreadyFriends:
            Logger.warning("⚠️ 已經是好友關係", category: .database)
            throw DatabaseError.invalidOperation("已經是好友")
        case .pendingRequest:
            Logger.warning("⚠️ 已有待處理的好友請求", category: .database)
            throw DatabaseError.invalidOperation("已有待處理的好友請求")
        case .none:
            break
        }
        
        let requestId = UUID()
        let friendRequest = FriendRequest(
            id: requestId,
            fromUserId: currentUser.id.uuidString,
            fromUserName: currentUserProfile.username,
            fromUserDisplayName: currentUserProfile.displayName,
            fromUserAvatarUrl: currentUserProfile.avatarUrl,
            toUserId: userId,
            message: message,
            requestDate: Date(),
            status: .pending
        )
        
        try await client
            .from("friend_requests")
            .insert(friendRequest)
            .execute()
        
        Logger.info("✅ 好友請求發送成功", category: .database)
    }
    
    /// 處理好友請求（接受或拒絕）
    func handleFriendRequest(requestId: UUID, accept: Bool) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("📬 處理好友請求: \(requestId), 接受: \(accept)", category: .database)
        
        // 獲取好友請求詳情
        let request = try await getFriendRequest(requestId: requestId)
        
        // 檢查請求是否屬於當前用戶
        guard request.toUserId == currentUser.id.uuidString else {
            Logger.error("❌ 好友請求不屬於當前用戶", category: .database)
            throw DatabaseError.unauthorized("無效的好友請求")
        }
        
        // 檢查請求狀態
        guard request.status == .pending else {
            Logger.error("❌ 好友請求已處理", category: .database)
            throw DatabaseError.invalidOperation("好友請求已處理")
        }
        
        if accept {
            // 接受好友請求
            try await acceptFriendRequest(request: request)
        } else {
            // 拒絕好友請求
            try await declineFriendRequest(requestId: requestId)
        }
    }
    
    /// 移除好友
    func removeFriend(friendId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("💔 移除好友: \(friendId)", category: .database)
        
        // 移除雙向好友關係
        try await client
            .from("friendships")
            .delete()
            .or("and(user_id.eq.\(currentUser.id.uuidString),friend_id.eq.\(friendId.uuidString)),and(user_id.eq.\(friendId.uuidString),friend_id.eq.\(currentUser.id.uuidString))")
            .execute()
        
        Logger.info("✅ 好友移除成功", category: .database)
    }
    
    /// 獲取好友列表
    func getFriends() async throws -> [Friend] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("👥 獲取好友列表", category: .database)
        
        let response = try await client
            .from("friendships")
            .select("""
                friend_id,
                user_profiles:friend_id (
                    id, username, display_name, avatar_url, bio,
                    investment_style, total_return, performance_score,
                    last_active_at
                )
            """)
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("status", value: "accepted")
            .execute()
        
        // TODO: Implement proper friend parsing
        let friends: [Friend] = []
        
        Logger.info("✅ 獲取到 \(friends.count) 個好友", category: .database)
        return friends
    }
    
    /// 獲取待處理的好友請求
    func getPendingFriendRequests() async throws -> [FriendRequestDisplay] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("📨 獲取待處理的好友請求", category: .database)
        
        let response = try await client
            .from("friend_requests")
            .select("""
                id, from_user_id, message, created_at,
                user_profiles:from_user_id (
                    username, display_name, avatar_url, bio
                )
            """)
            .eq("to_user_id", value: currentUser.id.uuidString)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
        
        // TODO: Implement proper friend request parsing
        let requests: [FriendRequestDisplay] = []
        
        Logger.info("✅ 獲取到 \(requests.count) 個待處理請求", category: .database)
        return requests
    }
    
    // MARK: - 用戶搜尋
    
    /// 搜尋用戶
    func searchUsers(
        query: String? = nil,
        investmentStyle: InvestmentStyle? = nil,
        riskLevel: RiskLevel? = nil,
        limit: Int = 20
    ) async throws -> [FriendSearchResult] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("🔍 搜尋用戶", category: .database)
        
        var queryBuilder = client
            .from("user_profiles")
            .select()
            .neq("id", value: currentUser.id.uuidString)
        
        if let query = query, !query.isEmpty {
            queryBuilder = queryBuilder.or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
        }
        
        if let style = investmentStyle {
            queryBuilder = queryBuilder.eq("investment_style", value: style.rawValue)
        }
        
        if let risk = riskLevel {
            queryBuilder = queryBuilder.eq("risk_level", value: risk.rawValue)
        }
        
        let response = try await queryBuilder
            .limit(limit)
            .execute()
        let profiles = try JSONDecoder().decode([UserProfileResponse].self, from: response.data)
        
        // 檢查哪些用戶已經是好友或有待處理的請求
        let friendIds = try await getFriendIds(userId: currentUser.id)
        let pendingRequestIds = try await getPendingRequestIds(userId: currentUser.id)
        
        let searchResults = await withTaskGroup(of: FriendSearchResult.self) { group in
            var results: [FriendSearchResult] = []
            
            for profile in profiles {
                group.addTask {
                    // 計算共同好友數量
                    let mutualCount = await self.calculateMutualFriendsCount(
                        currentUserId: currentUser.id.uuidString,
                        targetUserId: profile.id
                    )
                    
                    return FriendSearchResult(
                        id: UUID(uuidString: profile.id) ?? UUID(),
                        userId: profile.id,
                        userName: profile.username,
                        displayName: profile.displayName,
                        avatarUrl: profile.avatarUrl,
                        bio: profile.bio,
                        investmentStyle: InvestmentStyle(rawValue: profile.investmentStyle ?? ""),
                        performanceScore: profile.performanceScore ?? 0.0,
                        totalReturn: profile.totalReturn ?? 0.0,
                        mutualFriendsCount: mutualCount,
                        isAlreadyFriend: friendIds.contains(profile.id),
                        hasPendingRequest: pendingRequestIds.contains(profile.id)
                    )
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
        
        Logger.info("✅ 搜尋完成，找到 \(searchResults.count) 個用戶", category: .database)
        return searchResults
    }
    
    /// 獲取推薦的新好友
    func getRecommendedFriends(limit: Int = 10) async throws -> [FriendSearchResult] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        let currentProfile = try await ServiceCoordinator.shared.core.getUserProfile(userId: currentUser.id)
        
        Logger.info("💡 獲取推薦好友", category: .database)
        
        // 基於投資風格和績效的推薦
        var recommendationQuery = client
            .from("user_profiles")
            .select()
            .neq("id", value: currentUser.id.uuidString)
            .limit(limit * 2) // 獲取更多候選人以便篩選
        
        // TODO: Implement investment style filtering when PostgrestTransformBuilder methods are available
        
        let response = try await recommendationQuery.execute()
        let candidates = try JSONDecoder().decode([UserProfileResponse].self, from: response.data)
        
        // 過濾已經是好友的用戶
        let friendIds = try await getFriendIds(userId: currentUser.id)
        let pendingRequestIds = try await getPendingRequestIds(userId: currentUser.id)
        
        let filteredCandidates = candidates.filter { candidate in
            !friendIds.contains(candidate.id) && !pendingRequestIds.contains(candidate.id)
        }
        
        // 轉換為搜尋結果並添加推薦理由
        let recommendations = Array(filteredCandidates.prefix(limit)).map { (profile: UserProfileResponse) in
            FriendSearchResult(
                id: UUID(uuidString: profile.id) ?? UUID(),
                userId: profile.id,
                userName: profile.username,
                displayName: profile.displayName,
                avatarUrl: profile.avatarUrl,
                bio: profile.bio,
                investmentStyle: InvestmentStyle(rawValue: profile.investmentStyle ?? ""),
                performanceScore: profile.performanceScore ?? 0.0,
                totalReturn: profile.totalReturn ?? 0.0,
                mutualFriendsCount: 0, // 可以異步計算
                isAlreadyFriend: false,
                hasPendingRequest: false
            )
        }
        
        Logger.info("✅ 獲取到 \(recommendations.count) 個推薦好友", category: .database)
        return recommendations
    }
    
    /// 追蹤用戶投資
    func followUserInvestments(userId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("📈 開始追蹤用戶投資: \(userId)", category: .database)
        
        let followRecord = InvestmentFollow(
            id: UUID(),
            followerId: currentUser.id,
            followeeId: userId,
            createdAt: Date(),
            isActive: true
        )
        
        try await client
            .from("investment_follows")
            .insert(followRecord)
            .execute()
        
        Logger.info("✅ 投資追蹤設置成功", category: .database)
    }
    
    /// 停止追蹤用戶投資
    func unfollowUserInvestments(userId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("📉 停止追蹤用戶投資: \(userId)", category: .database)
        
        try await client
            .from("investment_follows")
            .update(["is_active": false])
            .eq("follower_id", value: currentUser.id.uuidString)
            .eq("followee_id", value: userId.uuidString)
            .execute()
        
        Logger.info("✅ 投資追蹤已停止", category: .database)
    }
    
    // MARK: - 輔助方法
    
    private func checkExistingRelationship(with userId: String) async throws -> RelationshipStatus {
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 檢查是否已是好友
        let response = try await client
            .from("friendships")
            .select("id")
            .or("and(user_id.eq.\(currentUser.id.uuidString),friend_id.eq.\(userId)),and(user_id.eq.\(userId),friend_id.eq.\(currentUser.id.uuidString))")
            .eq("status", value: "accepted")
            .execute()
        
        let friendships = try JSONDecoder().decode([RelationshipCheck].self, from: response.data)
        
        if !friendships.isEmpty {
            return .alreadyFriends
        }
        
        // 檢查待處理請求
        let response2 = try await client
            .from("friend_requests")
            .select("id")
            .or("and(from_user_id.eq.\(currentUser.id.uuidString),to_user_id.eq.\(userId)),and(from_user_id.eq.\(userId),to_user_id.eq.\(currentUser.id.uuidString))")
            .eq("status", value: "pending")
            .execute()
        
        let pendingRequests = try JSONDecoder().decode([RelationshipCheck].self, from: response2.data)
        
        if !pendingRequests.isEmpty {
            return .pendingRequest
        }
        
        return .none
    }
    
    private func acceptFriendRequest(request: FriendRequest) async throws {
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 創建雙向好友關係
        let now = Date()
        let friendship1 = Friendship(
            id: UUID(),
            requesterID: UUID(uuidString: request.fromUserId) ?? UUID(),
            addresseeID: currentUser.id,
            status: "accepted",
            createdAt: now,
            updatedAt: now
        )
        
        let friendship2 = Friendship(
            id: UUID(),
            requesterID: currentUser.id,
            addresseeID: UUID(uuidString: request.fromUserId) ?? UUID(),
            status: "accepted",
            createdAt: now,
            updatedAt: now
        )
        
        try await client
            .from("friendships")
            .insert([friendship1, friendship2])
            .execute()
        
        // 更新好友請求狀態
        try await client
            .from("friend_requests")
            .update(["status": FriendRequest.FriendRequestStatus.accepted.rawValue])
            .eq("id", value: request.id)
            .execute()
        
        Logger.info("✅ 好友請求已接受，建立好友關係", category: .database)
    }
    
    private func declineFriendRequest(requestId: UUID) async throws {
        try await client
            .from("friend_requests")
            .update(["status": FriendRequest.FriendRequestStatus.declined.rawValue])
            .eq("id", value: requestId)
            .execute()
        
        Logger.info("✅ 好友請求已拒絕", category: .database)
    }
    
    private func getFriendRequest(requestId: UUID) async throws -> FriendRequest {
        let response = try await client
            .from("friend_requests")
            .select()
            .eq("id", value: requestId)
            .single()
            .execute()
        
        return try JSONDecoder().decode(FriendRequest.self, from: response.data)
    }
    
    private func getFriendIds(userId: UUID) async throws -> Set<String> {
        let response = try await client
            .from("friendships")
            .select("friend_id")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "accepted")
            .execute()
        
        let friendships = try JSONDecoder().decode([FriendshipIdResponse].self, from: response.data)
        
        return Set(friendships.map { $0.friendId })
    }
    
    private func getPendingRequestIds(userId: UUID) async throws -> Set<String> {
        let response = try await client
            .from("friend_requests")
            .select("to_user_id")
            .eq("from_user_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
        
        let requests = try JSONDecoder().decode([PendingRequestResponse].self, from: response.data)
        
        return Set(requests.map { $0.toUserId })
    }
    
    /// 計算兩個用戶之間的共同好友數量
    private func calculateMutualFriendsCount(currentUserId: String, targetUserId: String) async -> Int {
        do {
            // 獲取當前用戶的好友列表
            let response1 = try await client
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: currentUserId)
                .eq("status", value: "accepted")
                .execute()
            
            let currentUserFriends = try JSONDecoder().decode([FriendshipIdResponse].self, from: response1.data)
            let currentFriendIds = Set(currentUserFriends.map { $0.friendId })
            
            // 獲取目標用戶的好友列表
            let response2 = try await client
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: targetUserId)
                .eq("status", value: "accepted")
                .execute()
            
            let targetUserFriends = try JSONDecoder().decode([FriendshipIdResponse].self, from: response2.data)
            let targetFriendIds = Set(targetUserFriends.map { $0.friendId })
            
            // 計算交集
            let mutualFriends = currentFriendIds.intersection(targetFriendIds)
            
            Logger.debug("🤝 計算共同好友: \(currentUserId) 和 \(targetUserId) 有 \(mutualFriends.count) 個共同好友", category: .database)
            
            return mutualFriends.count
            
        } catch {
            Logger.error("❌ 計算共同好友失敗: \(error.localizedDescription)", category: .database)
            return 0
        }
    }
    
}

// MARK: - 數據結構

/// 關係狀態
private enum RelationshipStatus {
    case none
    case alreadyFriends
    case pendingRequest
}

// MARK: - Using FriendRequestStatus from FriendsModels.swift

/// 好友狀態
enum FriendshipStatus: String, Codable {
    case accepted = "accepted"
    case blocked = "blocked"
}

// MARK: - Removed duplicate model definitions - using models from FriendsModels.swift

/// 投資追蹤
struct InvestmentFollow: Codable {
    let id: UUID
    let followerId: UUID
    let followeeId: UUID
    let createdAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followeeId = "followee_id"
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}

/// 好友請求顯示
struct FriendRequestDisplay: Identifiable {
    let id: UUID
    let fromUserId: String
    let senderName: String
    let senderAvatarUrl: String?
    let message: String?
    let createdAt: Date
}

// MARK: - 內部數據結構

private struct RelationshipCheck: Codable {
    let id: UUID
}

private struct FriendshipIdResponse: Codable {
    let friendId: String
    
    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
    }
}

private struct PendingRequestResponse: Codable {
    let toUserId: String
    
    enum CodingKeys: String, CodingKey {
        case toUserId = "to_user_id"
    }
}

