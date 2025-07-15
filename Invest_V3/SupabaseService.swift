import Foundation
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    // 直接從 SupabaseManager 取得 client（移除 private(set) 因為計算屬性已經是只讀的）
    var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() { }
    
    // 獲取當前用戶
    public func getCurrentUser() -> UserProfile? {
        // 首先嘗試從 UserDefaults 獲取用戶資料
        if let data = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            
            // 驗證是否有對應的 session
            if let session = client.auth.currentSession,
               let userId = UUID(uuidString: session.user.id.uuidString),
               user.id == userId {
                return user
            }
        }
        
        // 如果 UserDefaults 中沒有資料，嘗試從 session 獲取基本信息
        if let session = client.auth.currentSession,
           let userId = UUID(uuidString: session.user.id.uuidString) {
            // 返回一個基本的用戶資料（這種情況下可能需要重新獲取完整資料）
            print("⚠️ Session exists but no UserProfile in UserDefaults. User ID: \(userId)")
        }
        
        return nil
    }
    
    // 獲取當前用戶的異步版本
    public func getCurrentUserAsync() async throws -> UserProfile {
        // 確保 Supabase 已初始化
        try SupabaseManager.shared.ensureInitialized()
        
        // 首先嘗試從 UserDefaults 獲取用戶資料
        if let data = UserDefaults.standard.data(forKey: "current_user"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            
            // 驗證 session 是否仍然有效
            if let session = client.auth.currentSession,
               session.user.id.uuidString == profile.id.uuidString {
                return profile
            }
        }
        
        // 如果 UserDefaults 中沒有資料或 session 無效，嘗試從 Auth 獲取
        do {
            let currentUser = try await client.auth.user()
            let userId = currentUser.id
            
            // 從資料庫獲取完整的用戶資料
            let profiles: [UserProfile] = try await client.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            guard let profile = profiles.first else {
                throw SupabaseError.userNotFound
            }
            
            // 將用戶資料保存到 UserDefaults 以便後續使用
            if let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: "current_user")
            }
            
            return profile
        } catch {
            // 如果所有方法都失敗，拋出認證錯誤
            throw SupabaseError.notAuthenticated
        }
    }
    
    // MARK: - Investment Groups
    func fetchInvestmentGroups() async throws -> [InvestmentGroup] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .select()
            .execute()
            .value
        return response
    }
    
    func fetchInvestmentGroup(id: UUID) async throws -> InvestmentGroup {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        
        guard let group = response.first else {
            throw SupabaseError.dataNotFound
        }
        
        return group
    }
    
    func createInvestmentGroup(name: String, description: String, category: String, isPrivate: Bool, maxMembers: Int) async throws -> InvestmentGroup {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        let inviteCode = isPrivate ? UUID().uuidString : nil
        
        struct GroupInsert: Codable {
            let name: String
            let host: String
            let returnRate: Double
            let entryFee: String?
            let memberCount: Int
            let category: String?
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case name
                case host
                case returnRate = "return_rate"
                case entryFee = "entry_fee"
                case memberCount = "member_count"
                case category
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let groupData = GroupInsert(
            name: name,
            host: currentUser.displayName,
            returnRate: 0.0,
                            entryFee: "10 代幣",
            memberCount: 1,
            category: category,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let response: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .insert(groupData)
            .select()
            .execute()
            .value
        
        guard let group = response.first else {
            throw SupabaseError.unknown("Failed to create group")
        }
        
        // 創建主持人的投資組合
        try await createPortfolio(groupId: group.id, userId: currentUser.id)
        
        return group
    }
    
    // MARK: - Chat Messages
    func fetchChatMessages(groupId: UUID) async throws -> [ChatMessage] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [ChatMessage] = try await client.database
            .from("chat_messages")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at")
            .execute()
            .value
        
        // 簡化版本：不在循環中調用 fetchUserRole，而是為所有訊息設置默認角色
        // 這避免了大量的數據庫查詢和潛在的解碼問題
        var messagesWithRoles: [ChatMessage] = []
        
        // 獲取群組主持人信息一次
        struct GroupHostInfo: Codable {
            let host: String
        }
        
        let groupInfo: [GroupHostInfo] = try await client.database
            .from("investment_groups")
            .select("host")
            .eq("id", value: groupId.uuidString)
            .limit(1)
            .execute()
            .value
        
        let hostName = groupInfo.first?.host ?? ""
        
        for message in response {
            // 簡單的角色判斷：如果發送者名稱與主持人名稱相同，則為主持人
            let userRole = (message.senderName == hostName) ? "host" : "member"
            
            let messageWithRole = ChatMessage(
                id: message.id,
                groupId: message.groupId,
                senderId: message.senderId,
                senderName: message.senderName,
                content: message.content,
                isInvestmentCommand: message.isInvestmentCommand,
                createdAt: message.createdAt,
                userRole: userRole
            )
            
            messagesWithRoles.append(messageWithRole)
        }
        
        return messagesWithRoles
    }
    
    func sendChatMessage(groupId: UUID, content: String, isCommand: Bool = false) async throws -> ChatMessage {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 首先檢查用戶是否已經是群組成員，如果不是則自動加入
        try await ensureGroupMembership(groupId: groupId, userId: currentUser.id)
        
        // 獲取用戶在群組中的角色
        let userRole = try await fetchUserRole(userId: currentUser.id, groupId: groupId)
        
        struct ChatMessageInsert: Encodable {
            let groupId: String
            let senderId: String
            let senderName: String
            let content: String
            let isInvestmentCommand: Bool
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case senderId = "sender_id"
                case senderName = "sender_name"
                case content
                case isInvestmentCommand = "is_investment_command"
                case createdAt = "created_at"
            }
        }
        
        let messageToInsert = ChatMessageInsert(
            groupId: groupId.uuidString,
            senderId: currentUser.id.uuidString,
            senderName: currentUser.displayName,
            content: content,
            isInvestmentCommand: isCommand,
            createdAt: Date()
        )
        
        let response: [ChatMessage] = try await client.database
            .from("chat_messages")
            .insert(messageToInsert)
            .select()
            .execute()
            .value
        
        guard let message = response.first else {
            throw SupabaseError.unknown("Failed to send message")
        }
        
        // 創建包含用戶角色的 ChatMessage
        let messageWithRole = ChatMessage(
            id: message.id,
            groupId: message.groupId,
            senderId: message.senderId,
            senderName: message.senderName,
            content: message.content,
            isInvestmentCommand: message.isInvestmentCommand,
            createdAt: message.createdAt,
            userRole: userRole
        )
        
        return messageWithRole
    }
    
    // MARK: - 簡化的發送訊息方法 (供 ChatViewModel 使用)
    func sendMessage(groupId: UUID, content: String, isCommand: Bool = false) async throws -> ChatMessage {
        try SupabaseManager.shared.ensureInitialized()
        
        // 1. 獲取當前認證的用戶
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        let userId = authUser.id

        // 2. 獲取用戶名，帶有備用機制
        var senderName: String
        do {
            struct UserDisplayName: Codable {
                let displayName: String
                
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                }
            }
            
            let profiles: [UserDisplayName] = try await client.database
                .from("user_profiles")
                .select("display_name")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if let displayName = profiles.first?.displayName, !displayName.isEmpty {
                senderName = displayName
            } else {
                // 如果資料庫中沒有名字，使用 email 或一個預設值
                senderName = authUser.email ?? "神秘用戶"
                print("⚠️ 無法從 'user_profiles' 獲取用戶名，使用備用名稱: \(senderName)")
            }
        } catch {
            senderName = authUser.email ?? "神秘用戶"
            print("⚠️ 查詢 'user_profiles' 失敗: \(error.localizedDescription)，使用備用名稱: \(senderName)")
        }

        // 3. 確保用戶是群組成員
        try await ensureGroupMembership(groupId: groupId, userId: userId)
        
        // 4. 獲取用戶角色
        let userRole = try await fetchUserRole(userId: userId, groupId: groupId)

        // 5. 準備要插入的訊息結構
        struct ChatMessageInsert: Encodable {
            let groupId: UUID
            let senderId: UUID
            let senderName: String
            let content: String
            let isInvestmentCommand: Bool
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case senderId = "sender_id"
                case senderName = "sender_name"
                case content
                case isInvestmentCommand = "is_investment_command"
            }
        }
        
        let messageToInsert = ChatMessageInsert(
            groupId: groupId,
            senderId: userId,
            senderName: senderName,
            content: content,
            isInvestmentCommand: isCommand
        )

        // 6. 插入訊息並取回插入的記錄
        let response: [ChatMessage] = try await client.database
            .from("chat_messages")
            .insert(messageToInsert, returning: .representation)
            .select()
            .execute()
            .value

        guard var message = response.first else {
            throw SupabaseError.serverError(500)
        }
        
        // 7. 將角色賦予返回的訊息對象
        message.userRole = userRole
        
        print("✅ 訊息發送成功: '\(content)' by \(senderName) in group \(groupId)")
        return message
    }
    
    // MARK: - 確保群組成員資格
    private func ensureGroupMembership(groupId: UUID, userId: UUID) async throws {
        // 使用簡單結構檢查用戶是否已經是群組成員
        struct MembershipCheck: Codable {
            let userId: UUID
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }
        
        let existingMembers: [MembershipCheck] = try await client.database
            .from("group_members")
            .select("user_id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        // 如果用戶不是群組成員，則自動加入
        if existingMembers.isEmpty {
            print("🔄 用戶 \(userId) 不是群組 \(groupId) 的成員，自動加入...")
            try await joinGroup(groupId: groupId, userId: userId)
            print("✅ 用戶已自動加入群組")
        }
    }
    
    // MARK: - Group Members
    
    /// 簡化的加入群組方法 (使用當前登入用戶)
    func joinGroup(_ groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 獲取當前用戶
        let authUser: User
        do {
            authUser = try await client.auth.user()
        } catch {
            throw SupabaseError.notAuthenticated
        }
        let userId = authUser.id
        
        // 檢查是否已經是成員
        struct GroupMemberCheck: Codable {
            let groupId: String
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
            }
        }
        
        let existingMembers: [GroupMemberCheck] = try await client.database
            .from("group_members")
            .select("group_id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        if !existingMembers.isEmpty {
            print("✅ 用戶已經是群組成員")
            return
        }
        
        // 加入群組
        struct GroupMemberInsert: Codable {
            let groupId: String
            let userId: String
            let joinedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
                case joinedAt = "joined_at"
            }
        }
        
        let memberData = GroupMemberInsert(
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            joinedAt: Date()
        )
        
        try await client.database
            .from("group_members")
            .insert(memberData)
            .execute()
        
        print("✅ 成功加入群組: \(groupId)")
    }
    
    /// 獲取用戶已加入的群組列表
    func fetchUserJoinedGroups() async throws -> [InvestmentGroup] {
        try SupabaseManager.shared.ensureInitialized()
        
        // 獲取當前用戶
        let authUser: User
        do {
            authUser = try await client.auth.user()
        } catch {
            throw SupabaseError.notAuthenticated
        }
        let userId = authUser.id
        
        // 獲取用戶加入的群組 ID
        struct GroupMemberBasic: Codable {
            let groupId: String
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
            }
        }
        
        let memberRecords: [GroupMemberBasic] = try await client.database
            .from("group_members")
            .select("group_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        let groupIds = memberRecords.compactMap { UUID(uuidString: $0.groupId) }
        
        if groupIds.isEmpty {
            return []
        }
        
        // 獲取群組詳細信息
        let groups: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .select()
            .in("id", values: groupIds.map { $0.uuidString })
            .execute()
            .value
        
        return groups
    }
    
    /// 退出群組
    func leaveGroup(groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 獲取當前用戶
        let authUser: User
        do {
            authUser = try await client.auth.user()
        } catch {
            throw SupabaseError.notAuthenticated
        }
        let userId = authUser.id
        
        // 檢查用戶是否為群組主持人
        let group = try await fetchInvestmentGroup(id: groupId)
        let currentUser = try await getCurrentUserAsync()
        
        if group.host == currentUser.displayName {
            throw SupabaseError.accessDenied
        }
        
        // 從群組成員表中刪除用戶記錄
        try await client.database
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // 刪除用戶在該群組的投資組合
        try await client.database
            .from("user_portfolios")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // 更新群組成員數量
        try await client.database
            .from("investment_groups")
            .update(["member_count": group.memberCount - 1])
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ 成功退出群組: \(groupId)")
    }
    
    func joinGroup(groupId: UUID, userId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct GroupMemberInsert: Codable {
            let groupId: String
            let userId: String
            let joinedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
                case joinedAt = "joined_at"
            }
        }
        
        let memberData = GroupMemberInsert(
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            joinedAt: Date()
        )
        
        try await client.database
            .from("group_members")
            .insert(memberData)
            .execute()
        
        // 使用 RPC 函數來安全地更新成員計數
        try await client.database.rpc("increment_member_count", params: ["group_id_param": groupId]).execute()
    }
    

    
    // MARK: - Articles (保留原有功能但簡化)
    func fetchArticles() async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [Article] = try await client.database
            .from("articles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    // 支持 Markdown 的文章創建函數
    public func createArticle(title: String, content: String, category: String, bodyMD: String, isFree: Bool = true) async throws -> Article {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        struct ArticleInsertWithMD: Codable {
            let title: String
            let author: String
            let authorId: String
            let summary: String
            let fullContent: String
            let bodyMD: String
            let category: String
            let isFree: Bool
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case title
                case author
                case authorId = "author_id"
                case summary
                case fullContent = "full_content"
                case bodyMD = "body_md"
                case category
                case isFree = "is_free"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        // 生成文章摘要（取前200字）
        let summary = String(content.prefix(200))
        
        let articleData = ArticleInsertWithMD(
            title: title,
            author: currentUser.displayName,
            authorId: currentUser.id.uuidString,
            summary: summary,
            fullContent: content,
            bodyMD: bodyMD,
            category: category,
            isFree: isFree,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let insertedArticle: Article = try await client.database
            .from("articles")
            .insert(articleData)
            .select()
            .single()
            .execute()
            .value
        
        return insertedArticle
    }
    
    // 支持關鍵字和圖片的文章創建函數
    public func publishArticle(from draft: ArticleDraft) async throws -> Article {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        struct ArticleInsertWithoutTags: Codable {
            let title: String
            let author: String
            let authorId: String
            let summary: String
            let fullContent: String
            let bodyMD: String
            let category: String
            let isFree: Bool
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case title
                case author
                case authorId = "author_id"
                case summary
                case fullContent = "full_content"
                case bodyMD = "body_md"
                case category
                case isFree = "is_free"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        // 生成文章摘要（取前200字）
        let summary = draft.summary.isEmpty ? String(draft.bodyMD.prefix(200)) : draft.summary
        
        let articleData = ArticleInsertWithoutTags(
            title: draft.title,
            author: currentUser.displayName,
            authorId: currentUser.id.uuidString,
            summary: summary,
            fullContent: draft.bodyMD,
            bodyMD: draft.bodyMD,
            category: draft.category,
            isFree: draft.isFree,
            createdAt: draft.createdAt,
            updatedAt: Date()
        )
        
        let insertedArticle: Article = try await client.database
            .from("articles")
            .insert(articleData)
            .select()
            .single()
            .execute()
            .value
        
        return insertedArticle
    }
    
    // 上傳圖片到 Supabase Storage
    public func uploadArticleImage(_ imageData: Data, fileName: String) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        let path = "article_images/\(fileName)"
        
        try await client.storage
            .from("article_images")
            .upload(path: path, file: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // 獲取公開 URL
        let publicURL = try client.storage
            .from("article_images")
            .getPublicURL(path: path)
        
        return publicURL.absoluteString
    }
    
    // 根據分類獲取文章
    public func fetchArticlesByCategory(_ category: String) async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        if category == "全部" {
            return try await fetchArticles()
        }
        
        let articles: [Article] = try await client.database
            .from("articles")
            .select()
            .eq("category", value: category)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return articles
    }
    
    func deleteArticle(id: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        try await client.database
            .from("articles")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    


    // MARK: - Group Management
    func createPortfolio(groupId: UUID, userId: UUID) async throws -> Portfolio {
        try SupabaseManager.shared.ensureInitialized()
        
        struct PortfolioInsert: Codable {
            let groupId: String
            let userId: String
            let totalValue: Double
            let cashBalance: Double
            let returnRate: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
                case totalValue = "total_value"
                case cashBalance = "cash_balance"
                case returnRate = "return_rate"
                case lastUpdated = "last_updated"
            }
        }
        
        let portfolioData = PortfolioInsert(
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            totalValue: 1000000, // 初始 100 萬虛擬資金
            cashBalance: 1000000,
            returnRate: 0.0,
            lastUpdated: Date()
        )
        
        let response: [Portfolio] = try await client.database
            .from("portfolios")
            .insert(portfolioData)
            .select()
            .execute()
            .value
        
        guard let portfolio = response.first else {
            throw SupabaseError.unknown("Failed to create portfolio")
        }
        
        return portfolio
    }
    
    func updatePortfolio(groupId: UUID, userId: UUID, totalValue: Double, cashBalance: Double, returnRate: Double) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct PortfolioUpdate: Codable {
            let totalValue: Double
            let cashBalance: Double
            let returnRate: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case totalValue = "total_value"
                case cashBalance = "cash_balance"
                case returnRate = "return_rate"
                case lastUpdated = "last_updated"
            }
        }
        
        let updateData = PortfolioUpdate(
            totalValue: totalValue,
            cashBalance: cashBalance,
            returnRate: returnRate,
            lastUpdated: Date()
        )
        
        try await client.database
            .from("portfolios")
            .update(updateData)
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
        
        // 更新群組排名
        try await updateGroupRankings(groupId: groupId)
    }
    
    private func updateGroupRankings(groupId: UUID) async throws {
        // 獲取群組內所有投資組合並按回報率排序
        let response: [Portfolio] = try await client.database
            .from("portfolios")
            .select()
            .eq("group_id", value: groupId)
            .order("return_rate", ascending: false)
            .execute()
            .value
        
        // 更新每個成員的排名
        for (index, portfolio) in response.enumerated() {
            try await client.database
                .from("group_members")
                .update(["ranking_position": index + 1])
                .eq("group_id", value: groupId)
                .eq("user_id", value: portfolio.userId)
                .execute()
        }
    }
    
    // MARK: - Group Invitations
    func createInvitation(groupId: UUID, inviteeEmail: String) async throws -> GroupInvitation {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        
        struct InvitationInsert: Codable {
            let groupId: String
            let inviterId: String
            let inviterName: String
            let inviteeEmail: String
            let status: String
            let expiresAt: Date
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case inviterId = "inviter_id"
                case inviterName = "inviter_name"
                case inviteeEmail = "invitee_email"
                case status
                case expiresAt = "expires_at"
                case createdAt = "created_at"
            }
        }
        
        let invitationData = InvitationInsert(
            groupId: groupId.uuidString,
            inviterId: currentUser.id.uuidString,
            inviterName: currentUser.displayName,
            inviteeEmail: inviteeEmail,
            status: InvitationStatus.pending.rawValue,
            expiresAt: expiresAt,
            createdAt: Date()
        )
        
        let response: [GroupInvitation] = try await client.database
            .from("group_invitations")
            .insert(invitationData)
            .select()
            .execute()
            .value
        
        guard let invitation = response.first else {
            throw SupabaseError.unknown("Failed to create invitation")
        }
        
        return invitation
    }
    
    func respondToInvitation(invitationId: UUID, accept: Bool) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let status = accept ? InvitationStatus.accepted.rawValue : InvitationStatus.rejected.rawValue
        
        try await client.database
            .from("group_invitations")
            .update(["status": status])
            .eq("id", value: invitationId)
            .execute()
        
        if accept {
            let response: [GroupInvitation] = try await client.database
                .from("group_invitations")
                .select()
                .eq("id", value: invitationId)
                .execute()
                .value
            
            guard let invitation = response.first else { return }
            
            // 獲取當前用戶（被邀請者）
            let currentUser = try await getCurrentUserAsync()
            
            // 讓當前用戶加入群組
            try await joinGroup(groupId: invitation.groupId, userId: currentUser.id)
        }
    }
    
    // MARK: - Portfolio Management
    func fetchPortfolioWithPositions(groupId: UUID, userId: UUID) async throws -> PortfolioWithPositions {
        try SupabaseManager.shared.ensureInitialized()
        
        let portfolios: [Portfolio] = try await client.database
            .from("portfolios")
            .select()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        guard let portfolio = portfolios.first else {
            throw SupabaseError.dataNotFound
        }
        
        let positions: [Position] = try await client.database
            .from("positions")
            .select()
            .eq("portfolio_id", value: portfolio.id)
            .execute()
            .value
        
        return PortfolioWithPositions(portfolio: portfolio, positions: positions)
    }
    
    func updatePosition(position: Position) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct PositionUpdate: Codable {
            let shares: Double
            let averageCost: Double
            let currentValue: Double
            let returnRate: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case shares
                case averageCost = "average_cost"
                case currentValue = "current_value"
                case returnRate = "return_rate"
                case lastUpdated = "last_updated"
            }
        }
        
        let updateData = PositionUpdate(
            shares: position.shares,
            averageCost: position.averageCost,
            currentValue: position.currentValue,
            returnRate: position.returnRate,
            lastUpdated: Date()
        )
        
        try await client.database
            .from("positions")
            .update(updateData)
            .eq("id", value: position.id)
            .execute()
    }
    
    func createPosition(portfolioId: UUID, symbol: String, shares: Double, price: Double) async throws -> Position {
        try SupabaseManager.shared.ensureInitialized()
        
        struct PositionInsert: Codable {
            let portfolioId: String
            let symbol: String
            let shares: Double
            let averageCost: Double
            let currentValue: Double
            let returnRate: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case portfolioId = "portfolio_id"
                case symbol
                case shares
                case averageCost = "average_cost"
                case currentValue = "current_value"
                case returnRate = "return_rate"
                case lastUpdated = "last_updated"
            }
        }
        
        let currentValue = shares * price
        
        let positionData = PositionInsert(
            portfolioId: portfolioId.uuidString,
            symbol: symbol,
            shares: shares,
            averageCost: price,
            currentValue: currentValue,
            returnRate: 0.0,
            lastUpdated: Date()
        )
        
        let response: [Position] = try await client.database
            .from("positions")
            .insert(positionData)
            .select()
            .execute()
            .value
        
        guard let position = response.first else {
            throw SupabaseError.unknown("Failed to create position")
        }
        
        return position
    }
    
    func updatePortfolioAndPositions(portfolioWithPositions: PortfolioWithPositions) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 安全地解開 groupId
        guard let groupId = portfolioWithPositions.portfolio.groupId else {
            throw SupabaseError.unknown("Portfolio is not associated with a group")
        }
        
        // 更新投資組合
        try await updatePortfolio(
            groupId: groupId,
            userId: portfolioWithPositions.portfolio.userId,
            totalValue: portfolioWithPositions.totalValue,
            cashBalance: portfolioWithPositions.portfolio.cashBalance,
            returnRate: portfolioWithPositions.returnRate
        )
        
        // 更新所有持倉
        for position in portfolioWithPositions.positions {
            try await updatePosition(position: position)
        }
        
        // 更新群組排名
        try await updateGroupRankings(groupId: groupId)
    }
    
    // MARK: - Wallet and Transactions (Legacy - for reference only)
    // 舊版方法：基於 wallet_transactions 表計算餘額
    // 現在使用 user_balances 表的新方法
    private func fetchWalletBalanceLegacy() async throws -> Double {
        try SupabaseManager.shared.ensureInitialized()
        
        // 使用異步方法獲取當前用戶
        let currentUser = try await getCurrentUserAsync()
        
        let response: [WalletTransaction] = try await client.database
            .from("wallet_transactions")
            .select()
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        // 計算餘額：收入為正，支出為負
        let balance = response.reduce(0.0) { result, transaction in
            return result + Double(transaction.amount)
        }
        
        print("✅ [SupabaseService] 錢包餘額: \(balance) 代幣 (基於 \(response.count) 筆交易)")
        return balance
    }
    
    // MARK: - Chat
    
    /// 清除指定群組的聊天記錄
    func clearChatHistory(for groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        // TODO: 這裡應該要加上權限檢查，只有群組主持人才可以刪除
        // For now, we allow the user to delete their own group's messages
        
        try await client.database
            .from("chat_messages")
            .delete()
            .eq("group_id", value: groupId)
            .execute()
        
        print("✅ [SupabaseService] 已清除群組 \(groupId) 的聊天記錄")
    }
    
    func createTipTransaction(recipientId: UUID, amount: Double, groupId: UUID) async throws -> WalletTransaction {
        try SupabaseManager.shared.ensureInitialized()
        
        // 使用異步方法獲取當前用戶
        let currentUser = try await getCurrentUserAsync()
        
        // 檢查餘額是否足夠
        let currentBalance = try await fetchWalletBalance()
        guard Double(currentBalance) >= amount else {
            throw SupabaseError.unknown("Insufficient balance")
        }
        
        struct TipTransactionInsert: Codable {
            let userId: String
            let transactionType: String
            let amount: Int
            let description: String
            let status: String
            let paymentMethod: String?
            let blockchainId: String?
            let recipientId: String?
            let groupId: String?
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case transactionType = "transaction_type"
                case amount
                case description
                case status
                case paymentMethod = "payment_method"
                case blockchainId = "blockchain_id"
                case recipientId = "recipient_id"
                case groupId = "group_id"
                case createdAt = "created_at"
            }
        }
        
        let transactionData = TipTransactionInsert(
            userId: currentUser.id.uuidString,
            transactionType: TransactionType.tip.rawValue,
            amount: -Int(amount), // 負數表示支出
            description: "抖內禮物",
            status: TransactionStatus.confirmed.rawValue,
            paymentMethod: "wallet",
            blockchainId: nil,
            recipientId: recipientId.uuidString,
            groupId: groupId.uuidString,
            createdAt: Date()
        )
        
        let response: [WalletTransaction] = try await client.database
            .from("wallet_transactions")
            .insert(transactionData)
            .select()
            .execute()
            .value
        
        guard let transaction = response.first else {
            throw SupabaseError.unknown("Failed to create tip transaction")
        }
        
        print("✅ [SupabaseService] 抖內交易創建成功: \(amount) 代幣")
        return transaction
    }
    
    // MARK: - Group Details and Members
    func fetchGroupDetails(groupId: UUID) async throws -> (group: InvestmentGroup, hostInfo: UserProfile?) {
        try SupabaseManager.shared.ensureInitialized()
        
        let group = try await fetchInvestmentGroup(id: groupId)
        
        // 獲取主持人資訊 (根據 displayName 查找，容錯處理)
        var hostInfo: UserProfile? = nil
        do {
            hostInfo = try await fetchUserProfileByDisplayName(group.host)
            print("✅ [群組詳情] 成功獲取主持人資訊: \(group.host)")
        } catch {
            print("⚠️ [群組詳情] 無法獲取主持人資訊: \(group.host), 錯誤: \(error.localizedDescription)")
            // 不拋出錯誤，只是記錄警告，繼續返回群組資訊
        }
        
        return (group: group, hostInfo: hostInfo)
    }
    
    func fetchUserProfileByDisplayName(_ displayName: String) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [UserProfile] = try await client.database
            .from("user_profiles")
            .select()
            .eq("display_name", value: displayName)
            .limit(1)
            .execute()
            .value
        
        guard let userProfile = response.first else {
            throw SupabaseError.userNotFound
        }
        
        return userProfile
    }
    

    
    // MARK: - 診斷與連線檢查
    
    /// 檢查資料庫連線狀態
    func checkDatabaseConnection() async -> (isConnected: Bool, message: String) {
        do {
            try SupabaseManager.shared.ensureInitialized()
            
            // 使用最簡單的方法 - 只檢查認證狀態和 session
            guard let session = client.auth.currentSession else {
                return (false, "❌ [連線檢查] 用戶未登入")
            }
            
            // 嘗試執行一個簡單的 RPC 呼叫來測試連線
            let _: PostgrestResponse<Void> = try await client.database
                .rpc("check_connection")
                .execute()
            
            logError(message: "✅ [連線檢查] 資料庫連線成功")
            return (true, "✅ [連線檢查] 資料庫連線正常")
            
        } catch {
            // 如果 RPC 不存在，嘗試一個更基本的查詢
            do {
                // 只查詢 id 欄位，並使用基本的字典解碼
                let response = try await client.database
                    .from("user_profiles")
                    .select("id")
                    .limit(1)
                    .execute()
                
                // 檢查是否有響應數據（不解碼為具體模型）
                logError(message: "✅ [連線檢查] 資料庫連線成功 (備用方法)")
                return (true, "✅ [連線檢查] 資料庫連線正常")
                
            } catch {
                let errorMessage = "❌ [連線檢查] 資料庫連線失敗: \(error.localizedDescription)"
                logError(message: errorMessage)
                return (false, errorMessage)
            }
        }
    }
    
    /// 檢查指定用戶的訊息記錄
    func checkUserMessages(userEmail: String) async -> (hasMessages: Bool, messageCount: Int, latestMessage: String?) {
        do {
            try SupabaseManager.shared.ensureInitialized()
            
            // 根據 email 查找用戶
            let userProfiles: [UserProfile] = try await client.database
                .from("user_profiles")
                .select()
                .eq("email", value: userEmail)
                .limit(1)
                .execute()
                .value
            
            guard let userProfile = userProfiles.first else {
                logError(message: "⚠️ [訊息檢查] 找不到用戶: \(userEmail)")
                return (false, 0, nil)
            }
            
            // 查找該用戶的所有訊息
            let messages: [ChatMessage] = try await client.database
                .from("chat_messages")
                .select()
                .eq("sender_id", value: userProfile.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let latestMessage = messages.first?.content
            
            logError(message: "✅ [訊息檢查] 用戶 \(userEmail) 共有 \(messages.count) 則訊息")
            return (messages.count > 0, messages.count, latestMessage)
            
        } catch {
            logError(message: "❌ [訊息檢查] 檢查用戶訊息失敗: \(error.localizedDescription)")
            return (false, 0, nil)
        }
    }
    
    /// 檢查用戶是否為群組成員
    func isUserInGroup(userId: UUID, groupId: UUID) async -> Bool {
        do {
            try SupabaseManager.shared.ensureInitialized()
            
            let members: [GroupMemberResponse] = try await client.database
                .from("group_members")
                .select("group_id")
                .eq("user_id", value: userId.uuidString)
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value
            
            let isMember = !members.isEmpty
            logError(message: "✅ [群組檢查] 用戶 \(userId) 是否為群組 \(groupId) 成員: \(isMember)")
            return isMember
            
        } catch {
            logError(message: "❌ [群組檢查] 檢查群組成員失敗: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 新增訊息發送函數，確保 group_id 和 sender_id 正確
    func sendMessage(groupId: UUID, content: String) async throws -> ChatMessage {
        try SupabaseManager.shared.ensureInitialized()
        
        // 檢查當前用戶認證狀態
        guard let session = client.auth.currentSession else {
            throw SupabaseError.notAuthenticated
        }
        
        let currentUser = try await getCurrentUserAsync()
        
        // 檢查用戶是否為群組成員
        let isMember = await isUserInGroup(userId: currentUser.id, groupId: groupId)
        guard isMember else {
            throw SupabaseError.accessDenied
        }
        
        // 確保 sender_id 與認證用戶一致（RLS 政策要求）
        guard currentUser.id.uuidString == session.user.id.uuidString else {
            throw SupabaseError.accessDenied
        }
        
        struct ChatMessageInsert: Encodable {
            let groupId: String
            let senderId: String
            let senderName: String
            let content: String
            let isInvestmentCommand: Bool
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case senderId = "sender_id"
                case senderName = "sender_name"
                case content
                case isInvestmentCommand = "is_investment_command"
                case createdAt = "created_at"
            }
        }
        
        let messageToInsert = ChatMessageInsert(
            groupId: groupId.uuidString,
            senderId: session.user.id.uuidString, // 使用認證用戶的 ID
            senderName: currentUser.displayName,
            content: content,
            isInvestmentCommand: false,
            createdAt: Date()
        )
        
        do {
            let response: [ChatMessage] = try await client.database
                .from("chat_messages")
                .insert(messageToInsert)
                .select()
                .execute()
                .value
            
            guard let message = response.first else {
                throw SupabaseError.unknown("Failed to send message")
            }
            
            logError(message: "✅ [訊息發送] 訊息發送成功: \(content)")
            return message
            
        } catch {
            // 提供更詳細的錯誤信息
            if error.localizedDescription.contains("row-level security policy") {
                logError(message: "❌ [RLS錯誤] 用戶 \(session.user.id) 嘗試發送訊息到群組 \(groupId) 失敗")
                logError(message: "❌ [RLS錯誤] 檢查用戶是否為群組成員: \(isMember)")
                throw SupabaseError.accessDenied
            }
            throw error
        }
    }
    
    /// 錯誤日誌記錄
    func logError(message: String) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        // 記錄到控制台
        print(logMessage)
        
        // 記錄到本地儲存 (UserDefaults)
        var logs = UserDefaults.standard.stringArray(forKey: "supabase_error_logs") ?? []
        logs.append(logMessage)
        
        // 只保留最近 100 條日誌
        if logs.count > 100 {
            logs = Array(logs.suffix(100))
        }
        
        UserDefaults.standard.set(logs, forKey: "supabase_error_logs")
    }
    
    /// 獲取錯誤日誌
    func getErrorLogs() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "supabase_error_logs") ?? []
    }
    
    /// 清除錯誤日誌
    func clearErrorLogs() {
        UserDefaults.standard.removeObject(forKey: "supabase_error_logs")
        logError(message: "✅ [日誌管理] 錯誤日誌已清除")
    }
    
    /// 訂閱聊天室實時更新 (使用定時器作為暫時方案)
    func subscribeToGroupMessages(groupId: UUID, onMessage: @escaping (ChatMessage) -> Void) -> RealtimeChannelV2? {
        logError(message: "⚠️ [實時更新] 使用定時器方式訂閱群組 \(groupId)")
        
        // 暫時使用定時器方式，每3秒檢查一次新訊息
        var lastMessageTime = Date()
        
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task {
                do {
                    let messages = try await self.fetchChatMessages(groupId: groupId)
                    let newMessages = messages.filter { $0.createdAt > lastMessageTime }
                    
                    await MainActor.run {
                        for message in newMessages {
                            onMessage(message)
                            lastMessageTime = max(lastMessageTime, message.createdAt)
                        }
                        
                        if !newMessages.isEmpty {
                            self.logError(message: "✅ [定時更新] 獲取到 \(newMessages.count) 則新訊息")
                        }
                    }
                    
                } catch {
                    await MainActor.run {
                        self.logError(message: "❌ [定時更新] 獲取訊息失敗: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 返回 nil 表示沒有真正的 Realtime 訂閱
        return nil
    }
    
    /// 取消訂閱
    nonisolated func unsubscribeFromGroupMessages(channel: RealtimeChannelV2?) {
        guard let channel = channel else { return }
        
        Task {
            await channel.unsubscribe()
            await MainActor.run {
                self.logError(message: "✅ [實時更新] 取消訂閱成功")
            }
        }
    }
    
    /// 測試用：模擬加入群組
    func simulateJoinGroup(userId: UUID, groupId: UUID, username: String, displayName: String) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct GroupMemberInsert: Codable {
            let groupId: String
            let userId: String
            let joinedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
                case joinedAt = "joined_at"
            }
        }
        
        let memberData = GroupMemberInsert(
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            joinedAt: Date()
        )
        
        try await client.database
            .from("group_members")
            .insert(memberData)
            .execute()
        
        logError(message: "✅ [測試] 模擬加入群組成功: 用戶 \(displayName) 加入群組 \(groupId)")
    }
    
    /// 獲取用戶在群組中的角色
    func fetchUserRole(userId: UUID, groupId: UUID) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        // 使用簡單的結構來只獲取需要的欄位
        struct GroupHostInfo: Codable {
            let id: UUID
            let host: String
        }
        
        // 首先檢查用戶是否為群組主持人
        let groupResponse: [GroupHostInfo] = try await client.database
            .from("investment_groups")
            .select("id, host")
            .eq("id", value: groupId.uuidString)
            .execute()
            .value
        
        if let group = groupResponse.first {
            // 使用簡單結構獲取用戶的顯示名稱
            struct UserDisplayName: Codable {
                let displayName: String
                
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                }
            }
            
            let userProfiles: [UserDisplayName] = try await client.database
                .from("user_profiles")
                .select("display_name")
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            
            if let userProfile = userProfiles.first,
               group.host == userProfile.displayName {
                return "host"
            }
        }
        
        // 檢查用戶是否為群組成員
        struct GroupMemberCheck: Codable {
            let groupId: UUID
            let userId: UUID
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
            }
        }
        
        let memberResponse: [GroupMemberCheck] = try await client.database
            .from("group_members")
            .select("group_id, user_id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        if !memberResponse.isEmpty {
            return "member"
        }
        
        return "none" // 用戶不是群組成員
    }
    
    /// 獲取群組實際成員數
    func fetchGroupMemberCount(groupId: UUID) async throws -> Int {
        try SupabaseManager.shared.ensureInitialized()
        
        struct GroupMemberCount: Codable {
            let userId: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }
        
        let memberResponse: [GroupMemberCount] = try await client.database
            .from("group_members")
            .select("user_id")
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        
        return memberResponse.count
    }
    
    /// 創建測試用戶和群組
    func createTestEnvironment() async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 創建測試群組「價值投資學院」
        let testGroupId = TestConstants.testGroupId
        
        // 檢查群組是否已存在
        let existingGroups: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .select()
            .eq("id", value: testGroupId.uuidString)
            .execute()
            .value
        
        if existingGroups.isEmpty {
            // 創建測試群組
            struct GroupInsert: Codable {
                let id: String
                let name: String
                let host: String
                let returnRate: Double
                let entryFee: String
                let memberCount: Int
                let category: String
                let rules: String
                let createdAt: Date
                let updatedAt: Date
                
                enum CodingKeys: String, CodingKey {
                    case id, name, host
                    case returnRate = "return_rate"
                    case entryFee = "entry_fee"
                    case memberCount = "member_count"
                    case category, rules
                    case createdAt = "created_at"
                    case updatedAt = "updated_at"
                }
            }
            
            let groupData = GroupInsert(
                id: testGroupId.uuidString,
                name: "價值投資學院",
                host: "主持人",
                returnRate: 12.3,
                entryFee: "20 代幣",
                memberCount: 2,
                category: "價值投資",
                rules: "長期持有策略，最少持股期間30天，重視基本面分析",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try await client.database
                .from("investment_groups")
                .insert(groupData)
                .execute()
            
            logError(message: "✅ [測試環境] 創建測試群組成功: 價值投資學院")
        }
    }
    
    /// 創建測試用戶
    func createTestUsers() async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 創建主持人用戶
        let hostUserId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let memberUserId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        
        struct UserProfileInsert: Codable {
            let id: String
            let email: String
            let username: String
            let displayName: String
            let avatarUrl: String?
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id, email, username
                case displayName = "display_name"
                case avatarUrl = "avatar_url"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let hostUser = UserProfileInsert(
            id: hostUserId.uuidString,
            email: TestConstants.testUserEmail,
            username: "host_user",
            displayName: "主持人",
            avatarUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let memberUser = UserProfileInsert(
            id: memberUserId.uuidString,
            email: TestConstants.yukaUserEmail,
            username: "yuka",
            displayName: "成員",
            avatarUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 檢查用戶是否已存在，如果不存在則創建
        let existingHostUsers: [UserProfile] = try await client.database
            .from("user_profiles")
            .select()
            .eq("email", value: TestConstants.testUserEmail)
            .execute()
            .value
        
        if existingHostUsers.isEmpty {
            try await client.database
                .from("user_profiles")
                .insert(hostUser)
                .execute()
            
            logError(message: "✅ [測試環境] 創建主持人用戶成功: \(TestConstants.testUserEmail)")
        }
        
        let existingMemberUsers: [UserProfile] = try await client.database
            .from("user_profiles")
            .select()
            .eq("email", value: TestConstants.yukaUserEmail)
            .execute()
            .value
        
        if existingMemberUsers.isEmpty {
            try await client.database
                .from("user_profiles")
                .insert(memberUser)
                .execute()
            
            logError(message: "✅ [測試環境] 創建成員用戶成功: \(TestConstants.yukaUserEmail)")
        }
        
        // 將兩個用戶加入測試群組
        try await simulateJoinGroup(userId: hostUserId, groupId: TestConstants.testGroupId, username: "host_user", displayName: "主持人")
        try await simulateJoinGroup(userId: memberUserId, groupId: TestConstants.testGroupId, username: "yuka", displayName: "成員")
    }
    
    /// 模擬切換用戶（用於測試）
    func simulateUserSwitch(toEmail: String) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 根據 email 獲取用戶資料
        let userResponse: [UserProfile] = try await client.database
            .from("user_profiles")
            .select()
            .eq("email", value: toEmail)
            .execute()
            .value
        
        guard let user = userResponse.first else {
            throw SupabaseError.userNotFound
        }
        
        // 將用戶資料保存到 UserDefaults
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "current_user")
            logError(message: "✅ [用戶切換] 已切換到用戶: \(user.displayName) (\(user.email))")
        }
    }
    
    /// 模擬發送測試訊息（指定用戶）
    func simulateTestMessage(fromEmail: String, groupId: UUID, content: String) async throws -> ChatMessage {
        // 先切換用戶
        try await simulateUserSwitch(toEmail: fromEmail)
        
        // 發送訊息
        let message = try await sendMessage(groupId: groupId, content: content)
        
        logError(message: "✅ [測試訊息] \(fromEmail) 發送訊息: \(content)")
        
        return message
    }
    
    /// 專門用於將 yuka 用戶加入測試群組
    func addYukaToTestGroup() async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 獲取 yuka 用戶的信息
        let yukaUsers: [UserProfile] = try await client.database
            .from("user_profiles")
            .select()
            .eq("email", value: TestConstants.yukaUserEmail)
            .execute()
            .value
        
        guard let yukaUser = yukaUsers.first else {
            // 如果 yuka 用戶不存在，先創建
            let yukaUserId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            
            struct UserProfileInsert: Codable {
                let id: String
                let email: String
                let username: String
                let displayName: String
                let avatarUrl: String?
                let createdAt: Date
                let updatedAt: Date
                
                enum CodingKeys: String, CodingKey {
                    case id, email, username
                    case displayName = "display_name"
                    case avatarUrl = "avatar_url"
                    case createdAt = "created_at"
                    case updatedAt = "updated_at"
                }
            }
            
            let yukaUserData = UserProfileInsert(
                id: yukaUserId.uuidString,
                email: TestConstants.yukaUserEmail,
                username: "yuka",
                displayName: "成員",
                avatarUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try await client.database
                .from("user_profiles")
                .insert(yukaUserData)
                .execute()
            
            logError(message: "✅ [添加 Yuka] 創建 yuka 用戶成功")
            
            // 使用新創建的用戶 ID
            try await simulateJoinGroup(userId: yukaUserId, groupId: TestConstants.testGroupId, username: "yuka", displayName: "成員")
            logError(message: "✅ [添加 Yuka] yuka 用戶已成功加入測試群組")
            return
        }
        
        // 檢查 yuka 是否已經是群組成員
        struct GroupMemberExistCheck: Codable {
            let groupId: String
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
            }
        }
        
        let existingMembers: [GroupMemberExistCheck] = try await client.database
            .from("group_members")
            .select("group_id")
            .eq("group_id", value: TestConstants.testGroupId.uuidString)
            .eq("user_id", value: yukaUser.id.uuidString)
            .execute()
            .value
        
        if existingMembers.isEmpty {
            // 如果不是成員，則加入群組
            try await simulateJoinGroup(userId: yukaUser.id, groupId: TestConstants.testGroupId, username: "yuka", displayName: "成員")
            logError(message: "✅ [添加 Yuka] yuka 用戶已成功加入測試群組")
        } else {
            logError(message: "ℹ️ [添加 Yuka] yuka 用戶已經是測試群組成員")
        }
    }
    
    // MARK: - Group Invitations (B線邀請功能)
    
    /// 創建群組邀請 (通過 Email)
    func createInvitation(groupId: UUID, email: String) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = try? await getCurrentUserAsync() else {
            throw SupabaseError.notAuthenticated
        }
        
        struct InvitationInsert: Codable {
            let groupId: String
            let inviterId: String
            let inviteeEmail: String
            let status: String
            let expiresAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case inviterId = "inviter_id"
                case inviteeEmail = "invitee_email"
                case status
                case expiresAt = "expires_at"
            }
        }
        
        let invitation = InvitationInsert(
            groupId: groupId.uuidString,
            inviterId: currentUser.id.uuidString,
            inviteeEmail: email,
            status: "pending",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
        
        try await client.database
            .from("group_invitations")
            .insert(invitation)
            .execute()
        
        logError(message: "✅ [邀請] 成功創建邀請: \(email) 加入群組 \(groupId)")
    }
    
    /// 接受群組邀請
    func acceptInvitation(invitationId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 更新邀請狀態為已接受
        struct InvitationUpdate: Codable {
            let status: String
        }
        
        let update = InvitationUpdate(status: "accepted")
        
        try await client.database
            .from("group_invitations")
            .update(update)
            .eq("id", value: invitationId.uuidString)
            .execute()
        
        // 獲取邀請詳情以便加入群組
        let invitations: [GroupInvitation] = try await client.database
            .from("group_invitations")
            .select()
            .eq("id", value: invitationId.uuidString)
            .execute()
            .value
        
        guard let invitation = invitations.first else {
            throw SupabaseError.dataNotFound
        }
        
        // 加入群組
        try await joinGroup(invitation.groupId)
        
        logError(message: "✅ [邀請] 成功接受邀請並加入群組: \(invitation.groupId)")
    }
    
    /// 獲取待處理的邀請 (支援 Email 和 user_id 兩種方式)
    func fetchPendingInvites() async throws -> [GroupInvitation] {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = try? await getCurrentUserAsync() else {
            return []
        }
        
        // 查詢通過 Email 或 user_id 的邀請
        let invitations: [GroupInvitation] = try await client.database
            .from("group_invitations")
            .select()
            .or("invitee_email.eq.\(currentUser.email),invitee_id.eq.\(currentUser.id.uuidString)")
            .eq("status", value: "pending")
            .execute()
            .value
        
        return invitations
    }
    
    // MARK: - Friends (B-10~B-13 好友功能)
    
    /// 獲取好友列表
    func fetchFriendList() async throws -> [UserProfile] {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let current = try? await getCurrentUserAsync() else { 
            return [] 
        }

        struct FriendRow: Decodable { 
            let friendId: String
            
            enum CodingKeys: String, CodingKey {
                case friendId = "friend_id"
            }
        }
        
        let rows: [FriendRow] = try await client.database
            .from("user_friends")
            .select("friend_id")
            .eq("user_id", value: current.id.uuidString)
            .execute()
            .value

        let ids = rows.map(\.friendId)
        if ids.isEmpty { return [] }

        let friends: [UserProfile] = try await client.database
            .from("user_profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
            
        return friends
    }

    /// 通過用戶 ID 創建邀請
    func createInvitationByUserId(groupId: UUID, inviteeId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let current = try? await getCurrentUserAsync() else { 
            throw SupabaseError.notAuthenticated
        }

        struct InvitationInsertById: Codable {
            let groupId: String
            let inviterId: String
            let inviteeId: String
            let status: String
            let expiresAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case inviterId = "inviter_id"
                case inviteeId = "invitee_id"
                case status
                case expiresAt = "expires_at"
            }
        }
        
        let invitation = InvitationInsertById(
            groupId: groupId.uuidString,
            inviterId: current.id.uuidString,
            inviteeId: inviteeId.uuidString,
            status: "pending",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
        
        try await client.database
            .from("group_invitations")
            .insert(invitation)
            .execute()
            
                    logError(message: "✅ [好友邀請] 成功創建邀請: 用戶 \(inviteeId) 加入群組 \(groupId)")
    }
    
    // MARK: - Wallet Management
    
    /// 獲取用戶錢包餘額
    func fetchWalletBalance() async throws -> Double {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        // 嘗試獲取現有餘額
        let balanceResponse: [UserBalance] = try await client.database
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let userBalance = balanceResponse.first {
            return Double(userBalance.balance)
        } else {
            // 如果沒有記錄，創建一個初始餘額為 10000 的記錄
            let newBalance = UserBalance(
                id: UUID(),
                userId: userId,
                balance: 10000,
                withdrawableAmount: 0,
                updatedAt: Date()
            )
            
            try await client.database
                .from("user_balances")
                .insert(newBalance)
                .execute()
            
            return 10000.0
        }
    }
    
    /// 更新用戶錢包餘額
    func updateWalletBalance(delta: Int) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        // 獲取當前餘額
        let currentBalance = try await fetchWalletBalance()
        let newBalance = currentBalance + Double(delta)
        
        // 確保餘額不會變成負數
        guard newBalance >= 0 else {
            throw SupabaseError.unknown("餘額不足")
        }
        
        // 更新餘額
        struct BalanceUpdate: Codable {
            let balance: Int
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case balance
                case updatedAt = "updated_at"
            }
        }
        
        let updateData = BalanceUpdate(
            balance: Int(newBalance),
            updatedAt: Date()
        )
        
        try await client.database
            .from("user_balances")
            .update(updateData)
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ 錢包餘額更新成功: \(currentBalance) → \(newBalance) (變化: \(delta))")
    }
    
    // MARK: - Subscription Management
    
    /// 檢查用戶是否已訂閱某作者
    func isUserSubscribed(authorId: UUID) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            return false
        }
        
        let userId = authUser.id
        
        // 查詢是否有有效的訂閱記錄
        let subscriptions: [Subscription] = try await client.database
            .from("subscriptions")
            .select()
            .eq("user_id", value: userId)
            .eq("author_id", value: authorId.uuidString)
            .eq("status", value: "active")
            .gte("expires_at", value: Date())
            .execute()
            .value
        
        return !subscriptions.isEmpty
    }
    
    /// 訂閱作者
    func subscribeToAuthor(authorId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        let subscriptionFee: Double = 300.0 // 300 代幣
        
        // 檢查餘額是否足夠
        let currentBalance = try await fetchWalletBalance()
        guard currentBalance >= subscriptionFee else {
            throw SupabaseError.unknown("餘額不足，需要 \(subscriptionFee) 代幣")
        }
        
        // 檢查是否已經訂閱
        let isAlreadySubscribed = try await isUserSubscribed(authorId: authorId)
        guard !isAlreadySubscribed else {
            throw SupabaseError.unknown("您已經訂閱了此作者")
        }
        
        // 扣除餘額
        let newBalance = currentBalance - subscriptionFee
        let delta = -Int(subscriptionFee) // 負數表示扣除
        try await updateWalletBalance(delta: delta)
        
        // 創建訂閱記錄
        struct SubscriptionInsert: Codable {
            let userId: String
            let authorId: String
            let startedAt: Date
            let expiresAt: Date
            let status: String
            let subscriptionType: String
            let amountPaid: Int
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case authorId = "author_id"
                case startedAt = "started_at"
                case expiresAt = "expires_at"
                case status
                case subscriptionType = "subscription_type"
                case amountPaid = "amount_paid"
            }
        }
        
        let now = Date()
        let expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
        
        let subscriptionData = SubscriptionInsert(
            userId: userId.uuidString,
            authorId: authorId.uuidString,
            startedAt: now,
            expiresAt: expiresAt,
            status: "active",
            subscriptionType: "monthly",
            amountPaid: Int(subscriptionFee)
        )
        
        try await client.database
            .from("subscriptions")
            .insert(subscriptionData)
            .execute()
        
        print("✅ 訂閱成功: 用戶 \(userId) 訂閱作者 \(authorId)，費用 \(subscriptionFee) 代幣")
    }
    
    /// 記錄付費文章閱讀
    func recordPaidView(articleId: UUID, readingTimeSeconds: Int = 0) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        // 檢查是否已經記錄過這篇文章的閱讀（同一用戶/文章只記錄一次）
        let existingViews: [ArticleView] = try await client.database
            .from("article_views")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // 如果已經記錄過，就不再重複記錄
        guard existingViews.isEmpty else {
            print("ℹ️ 文章 \(articleId) 已經記錄過閱讀，跳過重複記錄")
            return
        }
        
        // 創建文章閱讀記錄
        struct ArticleViewInsert: Codable {
            let articleId: String
            let userId: String
            let viewedAt: Date
            let isPaid: Bool
            let readingTimeSeconds: Int
            
            enum CodingKeys: String, CodingKey {
                case articleId = "article_id"
                case userId = "user_id"
                case viewedAt = "viewed_at"
                case isPaid = "is_paid"
                case readingTimeSeconds = "reading_time_seconds"
            }
        }
        
        let viewRecord = ArticleViewInsert(
            articleId: articleId.uuidString,
            userId: userId.uuidString,
            viewedAt: Date(),
            isPaid: true,
            readingTimeSeconds: readingTimeSeconds
        )
        
        try await client.database
            .from("article_views")
            .insert(viewRecord)
            .execute()
        
        print("✅ 付費文章閱讀記錄成功: 用戶 \(userId) 閱讀文章 \(articleId)")
    }
    
    /// 檢查今日免費文章閱讀數量
    func getTodayFreeArticleReadCount() async throws -> Int {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            return 0
        }
        
        let userId = authUser.id
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        // 查詢今日免費文章閱讀記錄
        let todayViews: [ArticleView] = try await client.database
            .from("article_views")
            .select()
            .eq("user_id", value: userId)
            .eq("is_paid", value: false)
            .gte("viewed_at", value: today)
            .lt("viewed_at", value: tomorrow)
            .execute()
            .value
        
        return todayViews.count
    }
    
    /// 記錄免費文章閱讀
    func recordFreeView(articleId: UUID, readingTimeSeconds: Int = 0) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        // 檢查是否已經記錄過這篇文章的閱讀
        let existingViews: [ArticleView] = try await client.database
            .from("article_views")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // 如果已經記錄過，就不再重複記錄
        guard existingViews.isEmpty else {
            print("ℹ️ 文章 \(articleId) 已經記錄過閱讀，跳過重複記錄")
            return
        }
        
        // 創建免費文章閱讀記錄
        struct FreeArticleViewInsert: Codable {
            let articleId: String
            let userId: String
            let viewedAt: Date
            let isPaid: Bool
            let readingTimeSeconds: Int
            
            enum CodingKeys: String, CodingKey {
                case articleId = "article_id"
                case userId = "user_id"
                case viewedAt = "viewed_at"
                case isPaid = "is_paid"
                case readingTimeSeconds = "reading_time_seconds"
            }
        }
        
        let viewRecord = FreeArticleViewInsert(
            articleId: articleId.uuidString,
            userId: userId.uuidString,
            viewedAt: Date(),
            isPaid: false,
            readingTimeSeconds: readingTimeSeconds
        )
        
        try await client.database
            .from("article_views")
            .insert(viewRecord)
            .execute()
        
        print("✅ 免費文章閱讀記錄成功: 用戶 \(userId) 閱讀文章 \(articleId)")
    }
    
    /// 檢查是否可以閱讀免費文章（每日限制3篇）
    func canReadFreeArticle() async throws -> (canRead: Bool, todayCount: Int, limit: Int) {
        let todayCount = try await getTodayFreeArticleReadCount()
        let dailyLimit = 3
        
        return (canRead: todayCount < dailyLimit, todayCount: todayCount, limit: dailyLimit)
    }
    
    /// 獲取有付費文章的作者列表
    func getAuthorsWithPaidArticles() async throws -> [(UUID, String)] {
        try SupabaseManager.shared.ensureInitialized()
        
        // 查詢有付費文章的作者
        struct AuthorInfo: Codable {
            let authorId: String?
            let author: String
            
            enum CodingKeys: String, CodingKey {
                case authorId = "author_id"
                case author
            }
        }
        
        let authors: [AuthorInfo] = try await client.database
            .from("articles")
            .select("author_id, author")
            .eq("is_free", value: false)
            .execute()
            .value
        
        // 去重並轉換為所需格式
        var uniqueAuthors: [String: String] = [:]
        for author in authors {
            if let authorId = author.authorId, !authorId.isEmpty {
                uniqueAuthors[authorId] = author.author
            }
        }
        
        return uniqueAuthors.compactMap { (authorIdString, authorName) in
            guard let authorId = UUID(uuidString: authorIdString) else { return nil }
            return (authorId, authorName)
        }
    }
    
    // MARK: - 平台會員制管理
    
    /// 檢查用戶是否為平台會員
    func isPlatformMember() async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        let subscriptions: [PlatformSubscription] = try await client.database
            .from("platform_subscriptions")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("is_active", value: true)
            .gte("end_date", value: ISO8601DateFormatter().string(from: Date()))
            .execute()
            .value
        
        return !subscriptions.isEmpty
    }
    
    /// 獲取用戶的平台會員信息
    func getPlatformSubscription() async throws -> PlatformSubscription? {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        let subscriptions: [PlatformSubscription] = try await client.database
            .from("platform_subscriptions")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("is_active", value: true)
            .gte("end_date", value: ISO8601DateFormatter().string(from: Date()))
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return subscriptions.first
    }
    
    /// 訂閱平台會員
    func subscribeToPlatform(subscriptionType: String = "monthly") async throws -> PlatformSubscription {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 檢查是否已經是會員
        if try await isPlatformMember() {
            throw SupabaseError.unknown("用戶已經是平台會員")
        }
        
        // 計算訂閱費用和期限
        let amount: Double
        let endDate: Date
        let calendar = Calendar.current
        
        switch subscriptionType {
        case "monthly":
            amount = 500.0 // 月費 500 代幣
            endDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case "yearly":
            amount = 5000.0 // 年費 5000 代幣（相當於 10 個月的價格）
            endDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        default:
            throw SupabaseError.unknown("無效的訂閱類型")
        }
        
        // 檢查餘額是否足夠
        let currentBalance = try await fetchWalletBalance()
        guard currentBalance >= amount else {
            throw SupabaseError.unknown("餘額不足，需要 \(amount) 代幣")
        }
        
        // 扣除餘額
        let newBalance = currentBalance - amount
        let delta = -Int(amount) // 負數表示扣除
        try await updateWalletBalance(delta: delta)
        
        // 創建平台訂閱記錄
        struct PlatformSubscriptionInsert: Encodable {
            let userId: String
            let subscriptionType: String
            let startDate: String
            let endDate: String
            let isActive: Bool
            let amount: Int
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case subscriptionType = "subscription_type"
                case startDate = "start_date"
                case endDate = "end_date"
                case isActive = "is_active"
                case amount
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        
        let subscriptionToInsert = PlatformSubscriptionInsert(
            userId: currentUser.id.uuidString,
            subscriptionType: subscriptionType,
            startDate: formatter.string(from: now),
            endDate: formatter.string(from: endDate),
            isActive: true,
            amount: Int(amount),
            createdAt: formatter.string(from: now),
            updatedAt: formatter.string(from: now)
        )
        
        let insertedSubscriptions: [PlatformSubscription] = try await client.database
            .from("platform_subscriptions")
            .insert(subscriptionToInsert)
            .select()
            .execute()
            .value
        
        guard let subscription = insertedSubscriptions.first else {
            throw SupabaseError.unknown("創建訂閱失敗")
        }
        
        // 創建錢包交易記錄
        try await createWalletTransaction(
            type: "subscription",
            amount: -amount,
            description: "平台會員訂閱 (\(subscriptionType))",
            paymentMethod: "wallet"
        )
        
        print("✅ 平台會員訂閱成功: 用戶 \(currentUser.id) 訂閱 \(subscriptionType)，費用 \(amount) 代幣")
        print("✅ 錢包餘額更新: \(currentBalance) → \(newBalance) (變化: -\(amount))")
        
        return subscription
    }
    
    /// 記錄平台會員的文章閱讀（用於分潤計算）
    func recordPlatformMemberRead(articleId: UUID, authorId: UUID, readingTimeSeconds: Int = 60) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 檢查是否為文章作者 - 作者看自己的文章不計入付費閱讀
        if currentUser.id == authorId {
            print("ℹ️ 作者看自己的文章，不記錄付費閱讀")
            return
        }
        
        // 檢查是否為平台會員
        guard let subscription = try await getPlatformSubscription() else {
            throw SupabaseError.accessDenied
        }
        
        // 檢查是否已經記錄過（同一用戶同一文章每天只記錄一次）
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let existingReads: [ArticleReadRecord] = try await client.database
            .from("article_read_records")
            .select("id")
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("article_id", value: articleId.uuidString)
            .gte("read_date", value: ISO8601DateFormatter().string(from: today))
            .lt("read_date", value: ISO8601DateFormatter().string(from: tomorrow))
            .execute()
            .value
        
        if !existingReads.isEmpty {
            print("ℹ️ 文章 \(articleId) 今日已經記錄過閱讀，跳過重複記錄")
            return
        }
        
        // 創建閱讀記錄
        struct ArticleReadRecordInsert: Encodable {
            let userId: String
            let articleId: String
            let authorId: String
            let readDate: String
            let readingTimeSeconds: Int
            let subscriptionId: String
            let createdAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case articleId = "article_id"
                case authorId = "author_id"
                case readDate = "read_date"
                case readingTimeSeconds = "reading_time_seconds"
                case subscriptionId = "subscription_id"
                case createdAt = "created_at"
            }
        }
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        
        let readRecord = ArticleReadRecordInsert(
            userId: currentUser.id.uuidString,
            articleId: articleId.uuidString,
            authorId: authorId.uuidString,
            readDate: formatter.string(from: now),
            readingTimeSeconds: readingTimeSeconds,
            subscriptionId: subscription.id.uuidString,
            createdAt: formatter.string(from: now)
        )
        
        let _: [ArticleReadRecord] = try await client.database
            .from("article_read_records")
            .insert(readRecord)
            .select()
            .execute()
            .value
        
        print("✅ 平台會員文章閱讀記錄成功: 用戶 \(currentUser.id) 閱讀文章 \(articleId)")
    }
    
    /// 創建錢包交易記錄
    func createWalletTransaction(
        type: String,
        amount: Double,
        description: String,
        paymentMethod: String
    ) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        struct WalletTransactionInsert: Encodable {
            let userId: String
            let transactionType: String
            let amount: Int
            let description: String
            let status: String
            let paymentMethod: String
            let createdAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case transactionType = "transaction_type"
                case amount
                case description
                case status
                case paymentMethod = "payment_method"
                case createdAt = "created_at"
            }
        }
        
        let transactionData = WalletTransactionInsert(
            userId: userId.uuidString,
            transactionType: type,
            amount: Int(amount),
            description: description,
            status: "completed",
            paymentMethod: paymentMethod,
            createdAt: DateFormatter.iso8601.string(from: Date())
        )
        
        let _ = try await client.database
            .from("wallet_transactions")
            .insert(transactionData)
            .execute()
        
        print("✅ [SupabaseService] 錢包交易記錄創建成功: \(type) \(amount) 代幣")
    }
    
    /// 驗證作者是否存在於數據庫中
    func validateAuthorExists(authorId: UUID) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        // 先打印調試信息
        let uuidString = authorId.uuidString.lowercased()
        print("🔍 開始驗證作者: 原始UUID=\(authorId), 小寫字符串=\(uuidString)")
        
        do {
            // 使用最簡單的查詢方式
            struct SimpleResult: Codable {
                let count: Int
            }
            
            // 直接使用 rpc 調用來檢查
            let result: [SimpleResult] = try await client.database
                .rpc("check_user_exists", params: ["user_id": uuidString])
                .execute()
                .value
            
            let exists = result.first?.count ?? 0 > 0
            print("🔍 RPC查詢結果: \(exists)")
            return exists
            
        } catch {
            print("❌ RPC查詢失敗，使用簡單查詢: \(error)")
            
            // 回退到最簡單的查詢
            do {
                struct UserProfile: Codable {
                    let id: String
                    let username: String?
                }
                
                let users: [UserProfile] = try await client.database
                    .from("user_profiles")
                    .select("id, username")
                    .eq("id", value: uuidString)
                    .limit(1)
                    .execute()
                    .value
                
                let exists = !users.isEmpty
                if let user = users.first {
                    print("🔍 找到用戶: id=\(user.id), username=\(user.username ?? "無")")
                } else {
                    print("🔍 未找到用戶")
                }
                
                return exists
            } catch {
                print("❌ 所有查詢方式都失敗: \(error)")
                // 如果所有查詢都失敗，暫時返回 true 以避免阻止功能
                return true
            }
        }
    }
    
    /// 上傳圖片到 Supabase Storage
    func uploadImage(data: Data, fileName: String) async throws -> URL {
        let bucket = "article_images"
        let filePath = "\(UUID().uuidString)/\(fileName)"
        
        try await client.storage
            .from(bucket)
            .upload(path: filePath, file: data, options: FileOptions(contentType: "image/jpeg"))
            
        let urlResponse = try await client.storage
            .from(bucket)
            .getPublicURL(path: filePath)
            
        return urlResponse
    }
}

// MARK: - 輔助資料結構
struct GroupMemberQuery: Codable {
    let groupId: String
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
    }
}

struct GroupMemberResponse: Codable {
    let groupId: String
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
    }
}

struct WalletTransactionQuery: Codable {
    let amount: Double
    let transactionType: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case transactionType = "transaction_type"
    }
}

// MARK: - DateFormatter 擴展
extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
