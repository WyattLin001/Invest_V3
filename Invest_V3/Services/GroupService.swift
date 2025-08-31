import Foundation
import Supabase

/// 群組管理服務
/// 負責處理所有與投資群組相關的操作，包括創建、加入、管理、邀請等
@MainActor
class GroupService: ObservableObject {
    static let shared = GroupService()
    
    private var client: SupabaseClient {
        SupabaseService.shared.client
    }
    
    private init() {}
    
    // MARK: - 群組基本操作
    
    /// 創建投資群組
    func createGroup(
        name: String,
        category: String? = nil,
        entryFee: String? = nil,
        isPrivate: Bool = false
    ) async throws -> InvestmentGroup {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = try? await SupabaseService.shared.getCurrentUserAsync() else {
            Logger.error("❌ 用戶未登入，無法創建群組", category: .database)
            throw SupabaseError.notAuthenticated
        }
        
        let groupId = UUID()
        Logger.info("🏠 開始創建群組: \(name)", category: .database)
        
        // 簡化的群組資料結構
        struct DatabaseGroup: Codable {
            let id: String  
            let name: String
            let host: String
            let return_rate: Double
            let entry_fee: String?
            let member_count: Int
            let category: String?
            let created_at: String  
            let updated_at: String
        }
        
        // 獲取主持人的投資回報率
        let hostProfile = try await ServiceCoordinator.shared.core.getUserProfile(userId: currentUser.id)
        let returnRate = hostProfile.totalReturnRate ?? 0.0
        
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        
        let groupData = DatabaseGroup(
            id: groupId.uuidString,
            name: name,
            host: currentUser.displayName ?? "匿名主持人",
            return_rate: returnRate,
            entry_fee: entryFee,
            member_count: 1,
            category: category,
            created_at: isoFormatter.string(from: now),
            updated_at: isoFormatter.string(from: now)
        )
        
        Logger.debug("📝 準備插入群組資料: \(groupData)", category: .database)
        
        do {
            try await client
                .from("investment_groups")
                .insert(groupData)
                .execute()
            
            Logger.info("✅ 群組基本資料創建成功", category: .database)
            
            // 自動加入創建者為群組成員
            let memberData = GroupMemberInsert(
                groupId: groupId.uuidString,
                userId: currentUser.id.uuidString,
                role: "host",
                joinedAt: isoFormatter.string(from: now)
            )
            
            try await client
                .from("group_members")
                .insert(memberData)
                .execute()
            
            Logger.info("✅ 創建者已加入群組", category: .database)
            
            // 創建並返回InvestmentGroup對象
            let createdGroup = InvestmentGroup(
                id: groupId,
                name: name,
                host: currentUser.displayName ?? "匿名主持人",
                returnRate: returnRate,
                entryFee: entryFee,
                memberCount: 1,
                category: category,
                rules: nil,
                tokenCost: 0,
                createdAt: now,
                updatedAt: now
            )
            
            Logger.info("🎉 群組創建完成: \(name)", category: .database)
            return createdGroup
            
        } catch {
            Logger.error("❌ 群組創建失敗: \(error)", category: .database)
            throw error
        }
    }
    
    /// 加入群組
    func joinGroup(groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        Logger.info("🚪 用戶嘗試加入群組: \(groupId)", category: .database)
        
        // 檢查是否已是成員
        let response = try await client
            .from("group_members")
            .select("id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        let existingMembership = try JSONDecoder().decode([MembershipCheck].self, from: response.data)
        
        if !existingMembership.isEmpty {
            Logger.warning("⚠️ 用戶已是群組成員", category: .database)
            return
        }
        
        // 加入群組
        let memberData = GroupMemberInsert(
            groupId: groupId.uuidString,
            userId: currentUser.id.uuidString,
            role: "member",
            joinedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("group_members")
            .insert(memberData)
            .execute()
        
        // 更新群組成員數
        try await client
            .from("investment_groups")
            .update(["member_count": "member_count + 1"])
            .eq("id", value: groupId.uuidString)
            .execute()
        
        Logger.info("✅ 成功加入群組: \(groupId)", category: .database)
    }
    
    /// 離開群組
    func leaveGroup(groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        Logger.info("🚶‍♂️ 用戶離開群組: \(groupId)", category: .database)
        
        // 檢查用戶是否為群組主持人
        let group = try await getGroupDetails(groupId: groupId)
        if group.hostId == currentUser.id {
            Logger.error("❌ 群組主持人不能離開群組", category: .database)
            throw DatabaseError.unauthorized("群組主持人不能離開群組，請先轉移主持人權限或刪除群組")
        }
        
        // 離開群組
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        // 更新群組成員數
        try await client
            .from("investment_groups")
            .update(["member_count": "GREATEST(member_count - 1, 0)"])
            .eq("id", value: groupId.uuidString)
            .execute()
        
        Logger.info("✅ 成功離開群組: \(groupId)", category: .database)
    }
    
    /// 獲取群組詳細資訊
    func getGroupDetails(groupId: UUID) async throws -> InvestmentGroup {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("📋 獲取群組詳情: \(groupId)", category: .database)
        
        struct GroupDetailsResponse: Codable {
            let id: String
            let name: String
            let host: String
            let hostId: String?
            let returnRate: Double
            let entryFee: String?
            let memberCount: Int
            let category: String?
            let description: String?
            let isPrivate: Bool?
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case id, name, host
                case hostId = "host_id"
                case returnRate = "return_rate"
                case entryFee = "entry_fee"
                case memberCount = "member_count"
                case category, description
                case isPrivate = "is_private"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let response = try await client
            .from("investment_groups")
            .select()
            .eq("id", value: groupId.uuidString)
            .single()
            .execute()
        
        let groupData = try JSONDecoder().decode(GroupDetailsResponse.self, from: response.data)
        
        let formatter = ISO8601DateFormatter()
        let createdDate = formatter.date(from: groupData.createdAt) ?? Date()
        let lastActivityDate = formatter.date(from: groupData.updatedAt) ?? Date()
        
        let group = InvestmentGroup(
            id: groupId,
            name: groupData.name,
            host: groupData.host,
            returnRate: groupData.returnRate,
            entryFee: groupData.entryFee,
            memberCount: groupData.memberCount,
            category: groupData.category,
            rules: nil,
            tokenCost: 0,
            createdAt: createdDate,
            updatedAt: lastActivityDate
        )
        
        Logger.info("✅ 成功獲取群組詳情: \(groupData.name)", category: .database)
        return group
    }
    
    /// 獲取用戶的群組列表
    func getUserGroups() async throws -> [InvestmentGroup] {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        Logger.info("📋 獲取用戶群組列表", category: .database)
        
        let response: PostgrestResponse<Data> = try await client
            .from("group_members")
            .select("""
                group_id,
                investment_groups:group_id (
                    id, name, host, host_id, return_rate, entry_fee, 
                    token_cost, member_count, max_members, category, 
                    description, rules, is_private, invite_code,
                    portfolio_value, ranking_position, created_at, updated_at
                )
            """)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        // 解析響應並轉換為InvestmentGroup對象
        let groups = try parseGroupsFromResponse(response)
        
        Logger.info("✅ 獲取到 \(groups.count) 個群組", category: .database)
        return groups
    }
    
    /// 搜尋公開群組
    func searchPublicGroups(query: String? = nil, category: String? = nil, limit: Int = 20) async throws -> [InvestmentGroup] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔍 搜尋公開群組", category: .database)
        
        var searchQuery = client
            .from("investment_groups")
            .select()
            .eq("is_private", value: false)
            .limit(limit)
            .order("member_count", ascending: false)
        
        // TODO: Implement search filtering when PostgrestTransformBuilder methods are available
        
        let response: PostgrestResponse<Data> = try await searchQuery.execute()
        let groups = try parseGroupsFromResponse(response)
        
        Logger.info("✅ 搜尋完成，找到 \(groups.count) 個群組", category: .database)
        return groups
    }
    
    // MARK: - 群組成員管理
    
    /// 獲取群組成員列表
    func getGroupMembers(groupId: UUID) async throws -> [GroupMember] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("👥 獲取群組成員: \(groupId)", category: .database)
        
        let response: PostgrestResponse<Data> = try await client
            .from("group_members")
            .select("""
                id, user_id, role, joined_at,
                user_profiles:user_id (
                    username, display_name, avatar_url, bio
                )
            """)
            .eq("group_id", value: groupId.uuidString)
            .order("joined_at", ascending: true)
            .execute()
        
        let members = try parseGroupMembersFromResponse(response)
        
        Logger.info("✅ 獲取到 \(members.count) 個群組成員", category: .database)
        return members
    }
    
    /// 邀請用戶加入群組
    func inviteUserToGroup(groupId: UUID, userId: UUID, message: String? = nil) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 檢查邀請權限
        let isHost = try await isGroupHost(groupId: groupId, userId: currentUser.id)
        guard isHost else {
            Logger.error("❌ 只有群組主持人可以邀請成員", category: .database)
            throw DatabaseError.unauthorized("只有群組主持人可以邀請成員")
        }
        
        Logger.info("📧 邀請用戶加入群組: \(userId) -> \(groupId)", category: .database)
        
        let invitation = GroupInvitationData(
            id: UUID(),
            groupId: groupId,
            inviterId: currentUser.id,
            inviteeId: userId,
            message: message,
            status: .pending,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
        
        try await client
            .from("group_invitations")
            .insert(invitation)
            .execute()
        
        Logger.info("✅ 群組邀請發送成功", category: .database)
    }
    
    /// 處理群組邀請（接受或拒絕）
    func handleGroupInvitation(invitationId: UUID, accept: Bool) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        Logger.info("📬 處理群組邀請: \(invitationId), 接受: \(accept)", category: .database)
        
        // 獲取邀請詳情
        let invitation = try await getGroupInvitation(invitationId: invitationId)
        
        // 檢查邀請是否屬於當前用戶
        guard invitation.inviteeId == currentUser.id else {
            Logger.error("❌ 邀請不屬於當前用戶", category: .database)
            throw DatabaseError.unauthorized("無效的邀請")
        }
        
        // 檢查邀請是否仍然有效
        guard invitation.status == .pending && invitation.expiresAt > Date() else {
            Logger.error("❌ 邀請已過期或無效", category: .database)
            throw DatabaseError.invalidOperation("邀請已過期或無效")
        }
        
        if accept {
            // 接受邀請 - 加入群組
            try await joinGroup(groupId: invitation.groupId)
            
            // 更新邀請狀態
            try await client
                .from("group_invitations")
                .update(["status": GroupInvitationStatus.accepted.rawValue])
                .eq("id", value: invitationId)
                .execute()
            
            Logger.info("✅ 邀請已接受，成功加入群組", category: .database)
        } else {
            // 拒絕邀請
            try await client
                .from("group_invitations")
                .update(["status": GroupInvitationStatus.declined.rawValue])
                .eq("id", value: invitationId)
                .execute()
            
            Logger.info("✅ 邀請已拒絕", category: .database)
        }
    }
    
    // MARK: - 輔助方法
    
    private func isGroupHost(groupId: UUID, userId: UUID) async throws -> Bool {
        let group = try await getGroupDetails(groupId: groupId)
        return group.hostId == userId
    }
    
    private func getGroupInvitation(invitationId: UUID) async throws -> GroupInvitationData {
        let response = try await client
            .from("group_invitations")
            .select()
            .eq("id", value: invitationId)
            .single()
            .execute()
        
        return try JSONDecoder().decode(GroupInvitationData.self, from: response.data)
    }
    
    private func parseGroupsFromResponse(_ response: PostgrestResponse<Data>) throws -> [InvestmentGroup] {
        struct GroupMembershipResponse: Codable {
            let groupId: String
            let investmentGroups: InvestmentGroup?
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case investmentGroups = "investment_groups"
            }
        }
        
        let membershipResponses = try JSONDecoder().decode([GroupMembershipResponse].self, from: response.data)
        
        return membershipResponses.compactMap { membership in
            return membership.investmentGroups
        }
    }
    
    private func parseGroupMembersFromResponse(_ response: PostgrestResponse<Data>) throws -> [GroupMember] {
        // 這裡需要實現解析邏輯
        // 暫時返回空陣列，實際使用時需要根據響應格式進行解析
        return []
    }
}

// MARK: - 輔助數據結構

private struct GroupMemberInsert: Codable {
    let groupId: String
    let userId: String
    let role: String
    let joinedAt: String
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

private struct MembershipCheck: Codable {
    let id: UUID
}

/// 群組邀請狀態
enum GroupInvitationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
}

/// 群組邀請
struct GroupInvitationData: Codable {
    let id: UUID
    let groupId: UUID
    let inviterId: UUID
    let inviteeId: UUID
    let message: String?
    let status: GroupInvitationStatus
    let createdAt: Date
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case inviterId = "inviter_id"
        case inviteeId = "invitee_id"
        case message, status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}