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
    
    private func extractString(from value: Any?, key: String) -> String? {
        if let stringValue = value as? String {
            return stringValue.isEmpty ? nil : stringValue
        } else if let arrayValue = value as? [String], let firstValue = arrayValue.first {
            Logger.warning("⚠️ \(key) 字段返回數組，取第一個元素: \(firstValue)", category: .database)
            return firstValue.isEmpty ? nil : firstValue
        } else if let arrayValue = value as? [Any], let firstValue = arrayValue.first as? String {
            Logger.warning("⚠️ \(key) 字段返回混合數組，取第一個字符串: \(firstValue)", category: .database)
            return firstValue.isEmpty ? nil : firstValue
        }
        return nil
    }
    
    private func extractInt(from value: Any?, key: String) -> Int? {
        if let intValue = value as? Int {
            return intValue
        } else if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue
        } else if let doubleValue = value as? Double {
            return Int(doubleValue)
        } else if let arrayValue = value as? [Int], let firstValue = arrayValue.first {
            Logger.warning("⚠️ \(key) 字段返回數組，取第一個元素: \(firstValue)", category: .database)
            return firstValue
        }
        return nil
    }
    
    private func extractDouble(from value: Any?, key: String) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return doubleValue
        } else if let arrayValue = value as? [Double], let firstValue = arrayValue.first {
            Logger.warning("⚠️ \(key) 字段返回數組，取第一個元素: \(firstValue)", category: .database)
            return firstValue
        }
        return nil
    }
    
    private func extractStringArray(from value: Any?, key: String) -> [String] {
        if let arrayValue = value as? [String] {
            return arrayValue.filter { !$0.isEmpty }
        } else if let stringValue = value as? String, !stringValue.isEmpty {
            // Handle case where single string is expected to be converted to array
            return [stringValue]
        } else if let arrayValue = value as? [Any] {
            // Handle mixed array types including JSONB arrays
            return arrayValue.compactMap { element in
                if let stringElement = element as? String, !stringElement.isEmpty {
                    return stringElement
                } else if let numberElement = element as? NSNumber {
                    return numberElement.stringValue
                } else {
                    return nil
                }
            }
        } else if value is NSNull || value == nil {
            // Handle null/nil values
            return []
        }
        print("🔍 \(key) 字段返回意外類型: \(type(of: value))，使用默認值: []")
        return []
    }
    
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
                hostId: currentUser.id,
                returnRate: returnRate,
                entryFee: entryFee,
                tokenCost: 0,
                memberCount: 1,
                maxMembers: 100,
                category: category,
                description: nil,
                rules: [],
                isPrivate: false,
                inviteCode: nil,
                portfolioValue: 0.0,
                rankingPosition: 0,
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
        
        // Use defensive JSON parsing instead of JSONDecoder
        guard let jsonArray = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] else {
            Logger.warning("Unable to parse membership response, assuming no existing membership", category: .database)
            let existingMembership: [MembershipCheck] = []
            return // Continue with empty membership check
        }
        
        let existingMembership = jsonArray.compactMap { memberData -> MembershipCheck? in
            guard let idString = extractString(from: memberData["id"], key: "id"),
                  let id = UUID(uuidString: idString) else {
                Logger.warning("Invalid membership id in response: \(memberData)", category: .database)
                return nil
            }
            return MembershipCheck(id: id)
        }
        
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
        
        // Use defensive JSON parsing instead of JSONDecoder
        guard let jsonObject = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] else {
            Logger.error("❌ 無法解析群組詳情響應為JSON", category: .database)
            throw SupabaseError.dataCorrupted
        }
        
        // Parse the group details manually with defensive extraction
        guard let idString = extractString(from: jsonObject["id"], key: "id"),
              let name = extractString(from: jsonObject["name"], key: "name"),
              let host = extractString(from: jsonObject["host"], key: "host"),
              let memberCount = extractInt(from: jsonObject["member_count"], key: "member_count"),
              let returnRate = extractDouble(from: jsonObject["return_rate"], key: "return_rate"),
              let createdAtString = extractString(from: jsonObject["created_at"], key: "created_at"),
              let updatedAtString = extractString(from: jsonObject["updated_at"], key: "updated_at") else {
            Logger.error("❌ 群組詳情數據缺少必要字段", category: .database)
            throw SupabaseError.dataCorrupted
        }
        
        // Create the group details response manually
        let groupData = GroupDetailsResponse(
            id: idString,
            name: name,
            host: host,
            hostId: extractString(from: jsonObject["host_id"], key: "host_id"),
            returnRate: returnRate,
            entryFee: extractString(from: jsonObject["entry_fee"], key: "entry_fee"),
            memberCount: memberCount,
            category: extractString(from: jsonObject["category"], key: "category"),
            description: extractString(from: jsonObject["description"], key: "description"),
            isPrivate: jsonObject["is_private"] as? Bool,
            createdAt: createdAtString,
            updatedAt: updatedAtString
        )
        
        let formatter = ISO8601DateFormatter()
        let createdDate = formatter.date(from: groupData.createdAt) ?? Date()
        let lastActivityDate = formatter.date(from: groupData.updatedAt) ?? Date()
        
        let group = InvestmentGroup(
            id: groupId,
            name: groupData.name,
            host: groupData.host,
            hostId: groupData.hostId.flatMap { UUID(uuidString: $0) },
            returnRate: groupData.returnRate,
            entryFee: groupData.entryFee,
            tokenCost: 0,
            memberCount: groupData.memberCount,
            maxMembers: 100,
            category: groupData.category,
            description: groupData.description,
            rules: [],
            isPrivate: groupData.isPrivate ?? false,
            inviteCode: nil,
            portfolioValue: 0.0,
            rankingPosition: 0,
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
        Logger.info("📋 開始獲取用戶群組列表: \(currentUser.id)", category: .database)
        
        // First get the group IDs that the user is a member of
        let membershipResponse: PostgrestResponse<Data> = try await client
            .from("group_members")
            .select("group_id")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        // Debug: Log the raw membership response
        if let membershipString = String(data: membershipResponse.data, encoding: .utf8) {
            Logger.debug("Raw membership response: \(membershipString)", category: .database)
        }
        
        // Parse the group IDs
        guard let membershipJson = try? JSONSerialization.jsonObject(with: membershipResponse.data, options: []) as? [[String: Any]] else {
            Logger.warning("Unable to parse membership response", category: .database)
            return []
        }
        
        let groupIds = membershipJson.compactMap { membership in
            (membership["group_id"] as? String).flatMap { UUID(uuidString: $0) }
        }
        
        guard !groupIds.isEmpty else {
            Logger.info("用戶沒有加入任何群組", category: .database)
            return []
        }
        
        // Now fetch the actual group details
        let groupsResponse: PostgrestResponse<Data> = try await client
            .from("investment_groups")
            .select("*")
            .in("id", values: groupIds.map { $0.uuidString })
            .execute()
        
        // Debug: Log the raw groups response
        if let groupsString = String(data: groupsResponse.data, encoding: .utf8) {
            Logger.debug("Raw groups response: \(groupsString)", category: .database)
        }
        
        // Parse groups using manual JSON parsing - with error handling
        do {
            let groups = try parseGroupsDirectFromResponse(groupsResponse)
            Logger.info("✅ 獲取到 \(groups.count) 個群組", category: .database)
            return groups
        } catch {
            Logger.error("❌ 解析群組資料失敗: \(error)", category: .database)
            throw error
        }
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
        let groups = try parseGroupsDirectFromResponse(response)
        
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
        
        // Use defensive JSON parsing instead of JSONDecoder
        guard let jsonObject = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] else {
            Logger.error("❌ 無法解析群組邀請響應為JSON", category: .database)
            throw SupabaseError.dataCorrupted
        }
        
        // Parse the invitation manually with defensive extraction
        guard let idString = extractString(from: jsonObject["id"], key: "id"),
              let id = UUID(uuidString: idString),
              let groupIdString = extractString(from: jsonObject["group_id"], key: "group_id"),
              let groupId = UUID(uuidString: groupIdString),
              let inviterIdString = extractString(from: jsonObject["inviter_id"], key: "inviter_id"),
              let inviterId = UUID(uuidString: inviterIdString),
              let inviteeIdString = extractString(from: jsonObject["invitee_id"], key: "invitee_id"),
              let inviteeId = UUID(uuidString: inviteeIdString),
              let statusString = extractString(from: jsonObject["status"], key: "status"),
              let status = GroupInvitationStatus(rawValue: statusString),
              let createdAtString = extractString(from: jsonObject["created_at"], key: "created_at"),
              let createdAt = ISO8601DateFormatter().date(from: createdAtString),
              let expiresAtString = extractString(from: jsonObject["expires_at"], key: "expires_at"),
              let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) else {
            Logger.error("❌ 群組邀請數據缺少必要字段", category: .database)
            throw SupabaseError.dataCorrupted
        }
        
        return GroupInvitationData(
            id: id,
            groupId: groupId,
            inviterId: inviterId,
            inviteeId: inviteeId,
            message: extractString(from: jsonObject["message"], key: "message"),
            status: status,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }
    
    private func parseGroupsFromResponse(_ response: PostgrestResponse<Data>) throws -> [InvestmentGroup] {
        // First, let's log what we actually received to debug the issue
        if let jsonString = String(data: response.data, encoding: .utf8) {
            Logger.debug("Raw response data: \(jsonString)", category: .database)
        }
        
        // Parse the response as raw JSON to handle the nested structure
        guard let jsonObject = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] else {
            Logger.warning("Unable to parse groups response as JSON array", category: .database)
            return []
        }
        
        Logger.debug("Parsed \(jsonObject.count) membership records", category: .database)
        
        return jsonObject.compactMap { membershipData in
            Logger.debug("Processing membership data: \(membershipData.keys)", category: .database)
            
            // Handle different possible structures for investment_groups
            var groupData: [String: Any]?
            
            if let singleGroup = membershipData["investment_groups"] as? [String: Any] {
                // Single group object
                groupData = singleGroup
            } else if let groupArray = membershipData["investment_groups"] as? [[String: Any]], let firstGroup = groupArray.first {
                // Array of groups - take the first one
                groupData = firstGroup
                Logger.warning("Received array of groups, using first group", category: .database)
            } else {
                Logger.warning("Unable to extract group data from membership: \(membershipData)", category: .database)
                return nil
            }
            
            guard let validGroupData = groupData else {
                return nil
            }
            
            // Parse all required fields from the nested group data
            guard let idString = validGroupData["id"] as? String,
                  let groupId = UUID(uuidString: idString),
                  let name = validGroupData["name"] as? String,
                  let host = validGroupData["host"] as? String,
                  let memberCount = validGroupData["member_count"] as? Int,
                  let createdAtString = validGroupData["created_at"] as? String,
                  let updatedAtString = validGroupData["updated_at"] as? String,
                  let createdAt = ISO8601DateFormatter().date(from: createdAtString),
                  let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) else {
                Logger.warning("Missing required fields in group data: \(validGroupData.keys)", category: .database)
                return nil
            }
            
            // Parse optional fields with defaults
            let hostIdString = validGroupData["host_id"] as? String
            let hostId = hostIdString.flatMap { UUID(uuidString: $0) }
            let returnRate = validGroupData["return_rate"] as? Double ?? 0.0
            let entryFee = validGroupData["entry_fee"] as? String
            let tokenCost = validGroupData["token_cost"] as? Int ?? 0
            let maxMembers = validGroupData["max_members"] as? Int ?? 100
            let category = validGroupData["category"] as? String
            let description = validGroupData["description"] as? String
            let rules = extractStringArray(from: validGroupData["rules"], key: "rules")
            let isPrivate = validGroupData["is_private"] as? Bool ?? false
            let inviteCode = validGroupData["invite_code"] as? String
            let portfolioValue = validGroupData["portfolio_value"] as? Double ?? 0.0
            let rankingPosition = validGroupData["ranking_position"] as? Int ?? 0
            
            Logger.debug("Successfully parsed group: \(name)", category: .database)
            
            return InvestmentGroup(
                id: groupId,
                name: name,
                host: host,
                hostId: hostId,
                returnRate: returnRate,
                entryFee: entryFee,
                tokenCost: tokenCost,
                memberCount: memberCount,
                maxMembers: maxMembers,
                category: category,
                description: description,
                rules: rules,
                isPrivate: isPrivate,
                inviteCode: inviteCode,
                portfolioValue: portfolioValue,
                rankingPosition: rankingPosition,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
    
    private func parseGroupsDirectFromResponse(_ response: PostgrestResponse<Data>) throws -> [InvestmentGroup] {
        // Parse the direct investment_groups table response
        guard let jsonObject = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] else {
            Logger.warning("Unable to parse direct groups response as JSON array", category: .database)
            return []
        }
        
        Logger.debug("Parsing \(jsonObject.count) groups directly from investment_groups table", category: .database)
        
        return jsonObject.compactMap { groupData in
            // Parse all required fields
            guard let idString = groupData["id"] as? String,
                  let groupId = UUID(uuidString: idString),
                  let name = groupData["name"] as? String,
                  let host = groupData["host"] as? String,
                  let memberCount = groupData["member_count"] as? Int,
                  let createdAtString = groupData["created_at"] as? String,
                  let updatedAtString = groupData["updated_at"] as? String,
                  let createdAt = ISO8601DateFormatter().date(from: createdAtString),
                  let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) else {
                Logger.warning("Missing required fields in group data: \(groupData.keys)", category: .database)
                return nil
            }
            
            // Parse optional fields with defaults
            let hostIdString = groupData["host_id"] as? String
            let hostId = hostIdString.flatMap { UUID(uuidString: $0) }
            let returnRate = groupData["return_rate"] as? Double ?? 0.0
            let entryFee = groupData["entry_fee"] as? String
            let tokenCost = groupData["token_cost"] as? Int ?? 0
            let maxMembers = groupData["max_members"] as? Int ?? 100
            let category = groupData["category"] as? String
            let description = groupData["description"] as? String
            let rules = extractStringArray(from: groupData["rules"], key: "rules")
            let isPrivate = groupData["is_private"] as? Bool ?? false
            let inviteCode = groupData["invite_code"] as? String
            let portfolioValue = groupData["portfolio_value"] as? Double ?? 0.0
            let rankingPosition = groupData["ranking_position"] as? Int ?? 0
            
            return InvestmentGroup(
                id: groupId,
                name: name,
                host: host,
                hostId: hostId,
                returnRate: returnRate,
                entryFee: entryFee,
                tokenCost: tokenCost,
                memberCount: memberCount,
                maxMembers: maxMembers,
                category: category,
                description: description,
                rules: rules,
                isPrivate: isPrivate,
                inviteCode: inviteCode,
                portfolioValue: portfolioValue,
                rankingPosition: rankingPosition,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
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