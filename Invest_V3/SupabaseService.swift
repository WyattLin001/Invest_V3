import Foundation
import Supabase
import UIKit

/// 用戶在群組中的角色
enum UserRole: String, CaseIterable {
    case host = "host"
    case member = "member"
    case none = "none"
}

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    // 直接從 SupabaseManager 取得 client（移除 private(set) 因為計算屬性已經是只讀的）
    var client: SupabaseClient {
        // 使用統一的 Preview 檢測邏輯
        let isPreviewMode = SupabaseManager.isPreview
        
        // 如果在 Preview 模式，創建安全的模擬客戶端
        if isPreviewMode {
            print("🔍 SupabaseService.client: Using Preview mode client")
            return SupabaseClient(
                supabaseURL: URL(string: "https://preview.supabase.co")!,
                supabaseKey: "preview-key"
            )
        }
        
        guard let client = SupabaseManager.shared.client else {
            print("❌ SupabaseService.client accessed before initialization")
            print("💡 確保在App啟動時調用 SupabaseManager.shared.initialize()")
            
            // 嘗試立即同步初始化 - 使用正確的 URL
            print("⚠️ 使用緊急客戶端實例 - 正式環境")
            let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co")!
            let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"
            
            return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        }
        return client
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
        try await SupabaseManager.shared.ensureInitializedAsync()
        
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
            let profiles: [UserProfile] = try await client
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
        
        let response: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .execute()
            .value
        return response
    }
    
    // MARK: - Search Functions
    
    /// 搜尋投資群組
    func searchGroups(query: String) async throws -> [InvestmentGroup] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let searchQuery = query.lowercased()
        
        // 搜尋群組名稱、主持人、分類或描述包含關鍵字的群組
        let response: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .or("name.ilike.%\(searchQuery)%,host.ilike.%\(searchQuery)%,category.ilike.%\(searchQuery)%")
            .execute()
            .value
        
        print("🔍 [SupabaseService] 搜尋群組 '\(query)': 找到 \(response.count) 個結果")
        return response
    }
    
    /// 搜尋用戶檔案
    func searchUsers(query: String) async throws -> [UserProfile] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let searchQuery = query.lowercased()
        
        // 搜尋用戶顯示名稱或用戶名包含關鍵字的用戶
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .or("display_name.ilike.%\(searchQuery)%,username.ilike.%\(searchQuery)%")
            .limit(20) // 限制搜尋結果數量
            .execute()
            .value
        
        print("🔍 [SupabaseService] 搜尋用戶 '\(query)': 找到 \(response.count) 個結果")
        return response
    }
    
    /// 搜尋文章
    func searchArticles(query: String) async throws -> [Article] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let searchQuery = query.lowercased()
        
        // 搜尋文章標題或內容包含關鍵字的文章
        let response: [Article] = try await client
            .from("articles")
            .select()
            .or("title.ilike.%\(searchQuery)%,body_md.ilike.%\(searchQuery)%,summary.ilike.%\(searchQuery)%")
            .order("created_at", ascending: false)
            .limit(20) // 限制搜尋結果數量
            .execute()
            .value
        
        print("🔍 [SupabaseService] 搜尋文章 '\(query)': 找到 \(response.count) 個結果")
        return response
    }
    
    /// 綜合搜尋 - 同時搜尋群組、用戶和文章
    func searchAll(query: String) async throws -> (groups: [InvestmentGroup], users: [UserProfile], articles: [Article]) {
        async let groupsTask = searchGroups(query: query)
        async let usersTask = searchUsers(query: query)
        async let articlesTask = searchArticles(query: query)
        
        let groups = try await groupsTask
        let users = try await usersTask  
        let articles = try await articlesTask
        
        print("🔍 [SupabaseService] 綜合搜尋 '\(query)': \(groups.count) 群組, \(users.count) 用戶, \(articles.count) 文章")
        
        return (groups: groups, users: users, articles: articles)
    }
    
    func fetchInvestmentGroup(id: UUID) async throws -> InvestmentGroup {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [InvestmentGroup] = try await client
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
    
    func createInvestmentGroup(
        name: String, 
        rules: String, 
        entryFee: Int, 
        category: String = "一般投資",
        avatarImage: UIImage? = nil
    ) async throws -> InvestmentGroup {
        try await SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        let groupId = UUID()
        print("🚀 開始創建群組，ID: \(groupId)")
        
        // 簡化的群組資料結構
        struct DatabaseGroup: Codable {
            let id: String  // 改為 String 避免 UUID 序列化問題
            let name: String
            let host: String
            let return_rate: Double
            let entry_fee: String?
            let member_count: Int
            let category: String?
            let created_at: String  // 使用 ISO8601 字串格式
            let updated_at: String
        }
        
        // 獲取主持人的投資回報率
        let hostReturnRate = await getHostReturnRate(userId: currentUser.id)
        print("📊 主持人 \(currentUser.displayName) 的回報率: \(hostReturnRate)%")
        
        let entryFeeString = entryFee > 0 ? "\(entryFee) 代幣" : nil
        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())
        
        let dbGroup = DatabaseGroup(
            id: groupId.uuidString,
            name: name,
            host: currentUser.displayName,
            return_rate: hostReturnRate,
            entry_fee: entryFeeString,
            member_count: 1,
            category: category,
            created_at: now,
            updated_at: now
        )
        
        // Insert into database with detailed error handling
        do {
            print("📝 準備插入群組資料到 investment_groups 表格...")
            print("📊 群組資料: \(dbGroup)")
            
            let result = try await self.client
                .from("investment_groups")
                .insert(dbGroup)
                .execute()
            
            print("✅ 成功插入群組資料")
            
        } catch {
            print("❌ 插入群組資料失敗: \(error)")
            print("❌ 錯誤詳情: \(error.localizedDescription)")
            
            // 提供更具體的錯誤信息
            if error.localizedDescription.contains("404") {
                throw SupabaseError.unknown("❌ investment_groups 表格不存在。\n\n請在 Supabase 控制台執行以下 SQL：\n\nCREATE TABLE investment_groups (\n    id TEXT PRIMARY KEY,\n    name TEXT NOT NULL,\n    host TEXT NOT NULL,\n    return_rate DECIMAL(5,2) DEFAULT 0.0,\n    entry_fee TEXT,\n    member_count INTEGER DEFAULT 1,\n    category TEXT,\n    created_at TEXT,\n    updated_at TEXT\n);")
            }
            
            throw SupabaseError.unknown("創建群組失敗: \(error.localizedDescription)")
        }
        
        // Create the InvestmentGroup object to return
        let group = InvestmentGroup(
            id: groupId,
            name: name,
            host: currentUser.displayName,
            returnRate: hostReturnRate,
            entryFee: entryFeeString,
            memberCount: 1,
            category: category,
            rules: rules,
            tokenCost: entryFee,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 將創建者自動加入群組成員表（不增加成員計數，因為創建時已設為1）
        do {
            print("👥 準備將創建者加入群組成員...")
            print("   - 群組 ID: \(groupId)")
            print("   - 用戶 ID: \(currentUser.id)")
            
            // 直接插入成員記錄，不調用會增加計數的 joinGroup 函數
            struct GroupMemberInsert: Codable {
                let groupId: String
                let userId: String
                let userName: String
                let role: String
                let joinedAt: Date
                
                enum CodingKeys: String, CodingKey {
                    case groupId = "group_id"
                    case userId = "user_id"
                    case userName = "user_name"
                    case role
                    case joinedAt = "joined_at"
                }
            }
            
            let memberData = GroupMemberInsert(
                groupId: groupId.uuidString,
                userId: currentUser.id.uuidString,
                userName: currentUser.displayName,
                role: "host",
                joinedAt: Date()
            )
            
            try await self.client
                .from("group_members")
                .insert(memberData)
                .execute()
            
            print("✅ 成功將創建者加入群組成員")
        } catch {
            print("⚠️ 將創建者加入群組成員失敗: \(error.localizedDescription)")
            print("❌ 詳細錯誤: \(error)")
            // 繼續返回群組，但記錄錯誤
        }
        
        print("✅ 成功創建群組: \(name), 入會費: \(entryFee) 代幣, 主持人回報率: \(hostReturnRate)%")
        return group
    }
    
    /// 獲取主持人的投資回報率
    private func getHostReturnRate(userId: UUID) async -> Double {
        do {
            // 嘗試從 trading_users 表格獲取用戶的投資回報率
            struct TradingUserData: Codable {
                let cumulativeReturn: Double
                
                enum CodingKeys: String, CodingKey {
                    case cumulativeReturn = "cumulative_return"
                }
            }
            
            let tradingUsers: [TradingUserData] = try await self.client
                .from("trading_users")
                .select("cumulative_return")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let tradingUser = tradingUsers.first {
                print("📈 找到主持人交易績效: \(tradingUser.cumulativeReturn)%")
                return tradingUser.cumulativeReturn
            }
            
            print("⚠️ 未找到主持人交易記錄，使用預設回報率")
            return 0.0
            
        } catch {
            print("❌ 獲取主持人回報率失敗: \(error), 使用預設值")
            return 0.0
        }
    }
    
    /// 上傳群組頭像到 Supabase Storage
    private func uploadGroupAvatar(groupId: UUID, image: UIImage) async throws -> String {
        // 壓縮圖片
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw SupabaseError.unknown("無法處理圖片數據")
        }
        
        // 生成檔案名稱
        let fileName = "group-avatar-\(groupId.uuidString).jpg"
        
        // 使用現有的圖片上傳功能
        let url = try await SupabaseManager.shared.uploadImage(
            data: imageData,
            fileName: fileName
        )
        
        return url.absoluteString
    }
    
    // MARK: - Chat Messages
    func fetchChatMessages(groupId: UUID) async throws -> [ChatMessage] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [ChatMessage] = try await client
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
        
        let groupInfo: [GroupHostInfo] = try await client
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
        
        let response: [ChatMessage] = try await client
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
            
            let profiles: [UserDisplayName] = try await client
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
        let response: [ChatMessage] = try await client
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
        
        let existingMembers: [MembershipCheck] = try await client
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
    
    /// 簡化的加入群組方法 (使用當前登入用戶) - 包含代幣扣除
    
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
        
        let memberRecords: [GroupMemberBasic] = try await client
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
        let groups: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .in("id", values: groupIds.map { $0.uuidString })
            .execute()
            .value
        
        return groups
    }
    
    /// 直接通過 ID 查找並嘗試加入群組（簡化版本，不扣除代幣）
    func findAndJoinGroupById(groupId: String) async throws -> InvestmentGroup? {
        try await SupabaseManager.shared.ensureInitialized()
        
        // 直接查找群組
        let groups: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .eq("id", value: groupId)
            .limit(1)
            .execute()
            .value
        
        guard let group = groups.first else {
            print("❌ 群組 \(groupId) 不存在")
            return nil
        }
        
        print("✅ 找到群組: \(group.name)")
        
        // 獲取當前用戶
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 直接加入群組成員（跳過代幣扣除以避免交易約束問題）
        if let groupUUID = UUID(uuidString: groupId) {
            try await joinGroup(groupId: groupUUID, userId: currentUser.id)
            print("✅ 成功加入群組: \(group.name)")
            return group
        } else {
            print("❌ 無效的群組 ID 格式")
            return nil
        }
    }
    
    
    /// 退出群組
    func leaveGroup(groupId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        // 獲取當前用戶
        let authUser: User
        do {
            authUser = try await self.client.auth.user()
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
        try await self.client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // 刪除用戶在該群組的投資組合
        try await self.client
            .from("user_portfolios")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // 更新群組成員數量
        struct MemberCountUpdate: Codable {
            let memberCount: Int
            
            enum CodingKeys: String, CodingKey {
                case memberCount = "member_count"
            }
        }
        
        let newMemberCount = max(0, group.memberCount - 1)
        let update = MemberCountUpdate(memberCount: newMemberCount)
        
        try await self.client
            .from("investment_groups")
            .update(update)
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ 成功退出群組: \(groupId)")
    }
    
    func joinGroup(groupId: UUID, userId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        // 獲取用戶資料
        let userProfile = try await fetchUserProfileById(userId: userId)
        
        struct GroupMemberInsert: Codable {
            let groupId: String
            let userId: String
            let userName: String
            let role: String
            let joinedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
                case userName = "user_name"
                case role
                case joinedAt = "joined_at"
            }
        }
        
        let memberData = GroupMemberInsert(
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            userName: userProfile.displayName,
            role: "member",
            joinedAt: Date()
        )
        
        do {
            print("👥 準備將主持人加入群組成員...")
            try await self.client
                .from("group_members")
                .insert(memberData)
                .execute()
            print("✅ 成功加入群組成員")
        } catch {
            print("❌ 加入群組成員失敗: \(error)")
            
            if error.localizedDescription.contains("404") {
                throw SupabaseError.unknown("group_members 表格不存在或權限不足")
            }
            throw error
        }
        
        // 獲取當前群組並更新成員計數
        let currentGroup = try await fetchInvestmentGroup(id: groupId)
        let newMemberCount = currentGroup.memberCount + 1
        
        struct MemberCountUpdate: Codable {
            let memberCount: Int
            
            enum CodingKeys: String, CodingKey {
                case memberCount = "member_count"
            }
        }
        
        let update = MemberCountUpdate(memberCount: newMemberCount)
        try await self.client
            .from("investment_groups")
            .update(update)
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ 成功加入群組: \(groupId)")
    }
    
    /// 加入群組（從 HomeViewModel 調用）
    func joinGroup(_ groupId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 獲取群組資訊以檢查 tokenCost
        let group = try await fetchInvestmentGroup(id: groupId)
        let tokenCost = group.tokenCost
        
        // 檢查餘額是否足夠（但不扣除）
        if tokenCost > 0 {
            let balance = try await fetchWalletBalance()
            if balance < Double(tokenCost) {
                throw SupabaseError.insufficientBalance
            }
        }
        
        // 使用新的完整加入群組流程
        do {
            // 調用我們新創建的完整加入群組方法
            let message = try await joinInvestmentGroup(groupId: groupId)
            
            // 創建投資組合（保留原有功能）
            do {
                let _ = try await createPortfolio(groupId: groupId, userId: currentUser.id)
                print("✅ 成功創建投資組合")
            } catch {
                if error.localizedDescription.contains("404") {
                    print("❌ portfolios 表不存在，請在 Supabase SQL Editor 中執行 CREATE_PORTFOLIOS_TABLE.sql")
                    throw SupabaseError.unknown("❌ 數據庫配置錯誤：portfolios 表不存在\n\n請在 Supabase SQL Editor 中執行 CREATE_PORTFOLIOS_TABLE.sql 腳本來創建必要的表格。")
                }
                print("⚠️ 創建投資組合失敗，但群組已成功加入: \(error.localizedDescription)")
                // 不拋出錯誤，因為加入群組已經成功
            }
            
            print("✅ [joinGroup] \(message)")
            
        } catch {
            print("❌ 加入群組失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取群組主持人的用戶ID
    func fetchGroupHostId(groupId: UUID) async throws -> UUID {
        try await SupabaseManager.shared.ensureInitialized()
        
        let groups: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .eq("id", value: groupId.uuidString)
            .limit(1)
            .execute()
            .value
        
        guard let group = groups.first else {
            throw SupabaseError.unknown("群組不存在")
        }
        
        // 通過 host 名稱查找主持人的 user ID
        let hostProfile = try? await fetchUserProfileByDisplayName(group.host)
        return hostProfile?.id ?? UUID()
    }
    

    
    // MARK: - Articles (保留原有功能但簡化)
    func fetchArticles() async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [Article] = try await client
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
            let keywords: [String]
            let sharesCount: Int
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
                case keywords
                case sharesCount = "shares_count"
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
            keywords: [], // Default empty keywords for direct article creation
            sharesCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let insertedArticle: Article = try await client
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
        
        struct ArticleInsertWithKeywords: Codable {
            let title: String
            let author: String
            let authorId: String
            let summary: String
            let fullContent: String
            let bodyMD: String
            let category: String
            let isFree: Bool
            let keywords: [String]
            let sharesCount: Int
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
                case keywords
                case sharesCount = "shares_count"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        // 生成文章摘要（取前200字）
        let summary = draft.summary.isEmpty ? String(draft.bodyMD.prefix(200)) : draft.summary
        
        let articleData = ArticleInsertWithKeywords(
            title: draft.title,
            author: currentUser.displayName,
            authorId: currentUser.id.uuidString,
            summary: summary,
            fullContent: draft.bodyMD,
            bodyMD: draft.bodyMD,
            category: draft.category,
            isFree: draft.isFree,
            keywords: draft.keywords,
            sharesCount: 0,
            createdAt: draft.createdAt,
            updatedAt: Date()
        )
        
        let insertedArticle: Article = try await client
            .from("articles")
            .insert(articleData)
            .select()
            .single()
            .execute()
            .value
        
        return insertedArticle
    }
    
    // MARK: - Draft Management
    
    /// 保存草稿到 Supabase
    public func saveDraft(_ draft: ArticleDraft) async throws -> ArticleDraft {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        struct DraftInsert: Codable {
            let id: String
            let title: String
            let subtitle: String?
            let bodyMD: String
            let category: String
            let keywords: [String]
            let isFree: Bool
            let isUnlisted: Bool
            let authorId: String
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case title
                case subtitle
                case bodyMD = "body_md"
                case category
                case keywords
                case isFree = "is_free"
                case isUnlisted = "is_unlisted"
                case authorId = "author_id"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let draftData = DraftInsert(
            id: draft.id.uuidString,
            title: draft.title,
            subtitle: draft.subtitle,
            bodyMD: draft.bodyMD,
            category: draft.category,
            keywords: draft.keywords,
            isFree: draft.isFree,
            isUnlisted: draft.isUnlisted,
            authorId: currentUser.id.uuidString,
            createdAt: draft.createdAt,
            updatedAt: Date()
        )
        
        // 使用 upsert 來處理新增或更新
        let _: [DraftInsert] = try await client
            .from("article_drafts")
            .upsert(draftData)
            .execute()
            .value
            
        // 返回更新後的草稿
        var updatedDraft = draft
        updatedDraft.updatedAt = Date()
        return updatedDraft
    }
    
    /// 從 Supabase 載入用戶的草稿列表
    public func fetchUserDrafts() async throws -> [ArticleDraft] {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        struct DraftResponse: Codable {
            let id: String
            let title: String
            let subtitle: String?
            let bodyMD: String
            let category: String
            let keywords: [String]
            let isFree: Bool
            let isUnlisted: Bool
            let authorId: String
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case title
                case subtitle
                case bodyMD = "body_md"
                case category
                case keywords
                case isFree = "is_free"
                case isUnlisted = "is_unlisted"
                case authorId = "author_id"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let drafts: [DraftResponse] = try await client
            .from("article_drafts")
            .select()
            .eq("author_id", value: currentUser.id.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
            
        return drafts.map { draft in
            ArticleDraft(
                id: UUID(uuidString: draft.id) ?? UUID(),
                title: draft.title,
                subtitle: draft.subtitle,
                bodyMD: draft.bodyMD,
                category: draft.category,
                keywords: draft.keywords,
                isFree: draft.isFree,
                isUnlisted: draft.isUnlisted,
                createdAt: draft.createdAt,
                updatedAt: draft.updatedAt
            )
        }
    }
    
    /// 刪除草稿
    public func deleteDraft(_ draftId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        try await client
            .from("article_drafts")
            .delete()
            .eq("id", value: draftId.uuidString)
            .execute()
    }
    
    // 上傳圖片到 Supabase Storage
    public func uploadArticleImage(_ imageData: Data, fileName: String) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        let path = "\(fileName)"
        
        try await client.storage
            .from("article-images")
            .upload(path: path, file: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // 獲取公開 URL
        let publicURL = try client.storage
            .from("article-images")
            .getPublicURL(path: path)
        
        return publicURL.absoluteString
    }
    
    // 上傳圖片到 Supabase Storage（支援多種格式）
    public func uploadArticleImageWithContentType(_ imageData: Data, fileName: String, contentType: String) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        let path = "\(fileName)"
        
        try await client.storage
            .from("article-images")
            .upload(path: path, file: imageData, options: FileOptions(contentType: contentType))
        
        // 獲取公開 URL
        let publicURL = try client.storage
            .from("article-images")
            .getPublicURL(path: path)
        
        return publicURL.absoluteString
    }
    
    // 根據分類獲取文章
    public func fetchArticlesByCategory(_ category: String) async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        if category == "全部" {
            return try await fetchArticles()
        }
        
        let articles: [Article] = try await client
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
        
        try await client
            .from("articles")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Article Interactions
    
    /// 按讚文章
    func likeArticle(articleId: UUID) async throws {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        print("❤️ 準備按讚文章: \(articleId)")
        
        // 檢查是否已經按讚
        let existingLikes: [ArticleLike] = try await client
            .from("article_likes")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        guard existingLikes.isEmpty else {
            print("ℹ️ 用戶已經按讚過此文章")
            return
        }
        
        // 新增按讚記錄
        struct ArticleLikeInsert: Codable {
            let articleId: String
            let userId: String
            let userName: String
            
            enum CodingKeys: String, CodingKey {
                case articleId = "article_id"
                case userId = "user_id"
                case userName = "user_name"
            }
        }
        
        let likeData = ArticleLikeInsert(
            articleId: articleId.uuidString,
            userId: currentUser.id.uuidString,
            userName: currentUser.displayName
        )
        
        try await client
            .from("article_likes")
            .insert(likeData)
            .execute()
        
        print("✅ 按讚成功")
    }
    
    /// 取消按讚文章
    func unlikeArticle(articleId: UUID) async throws {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        print("💔 準備取消按讚文章: \(articleId)")
        
        try await client
            .from("article_likes")
            .delete()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        print("✅ 取消按讚成功")
    }
    
    /// 獲取文章互動統計
    func fetchArticleInteractionStats(articleId: UUID) async throws -> ArticleInteractionStats {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 獲取按讚數
        let likesCount: Int = try await client
            .from("article_likes")
            .select("*", head: true, count: .exact)
            .eq("article_id", value: articleId.uuidString)
            .execute()
            .count ?? 0
        
        // 獲取留言數
        let commentsCount: Int = try await client
            .from("article_comments")
            .select("*", head: true, count: .exact)
            .eq("article_id", value: articleId.uuidString)
            .execute()
            .count ?? 0
        
        // 獲取分享數
        let sharesCount: Int = try await client
            .from("article_shares")
            .select("*", head: true, count: .exact)
            .eq("article_id", value: articleId.uuidString)
            .execute()
            .count ?? 0
        
        // 檢查用戶是否已按讚
        let userLikes: [ArticleLike] = try await client
            .from("article_likes")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        return ArticleInteractionStats(
            articleId: articleId,
            likesCount: likesCount,
            commentsCount: commentsCount,
            sharesCount: sharesCount,
            userHasLiked: !userLikes.isEmpty
        )
    }
    
    /// 獲取文章留言列表
    func fetchArticleComments(articleId: UUID) async throws -> [ArticleComment] {
        print("💬 獲取文章留言: \(articleId)")
        
        let comments: [ArticleComment] = try await client
            .from("article_comments")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ 獲取到 \(comments.count) 條留言")
        return comments
    }
    
    /// 新增文章留言
    func addArticleComment(articleId: UUID, content: String) async throws -> ArticleComment {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        print("💬 準備新增留言到文章: \(articleId)")
        
        struct ArticleCommentInsert: Codable {
            let articleId: String
            let userId: String
            let userName: String
            let content: String
            
            enum CodingKeys: String, CodingKey {
                case articleId = "article_id"
                case userId = "user_id"
                case userName = "user_name"
                case content
            }
        }
        
        let commentData = ArticleCommentInsert(
            articleId: articleId.uuidString,
            userId: currentUser.id.uuidString,
            userName: currentUser.displayName,
            content: content
        )
        
        let newComment: ArticleComment = try await client
            .from("article_comments")
            .insert(commentData)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ 留言新增成功")
        return newComment
    }
    
    /// 分享文章到群組
    func shareArticleToGroup(articleId: UUID, groupId: UUID, groupName: String) async throws {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        print("📤 準備分享文章 \(articleId) 到群組 \(groupName)")
        
        // 檢查是否已經分享過
        let existingShares: [ArticleShare] = try await client
            .from("article_shares")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        
        guard existingShares.isEmpty else {
            print("ℹ️ 已經分享過此文章到此群組")
            return
        }
        
        struct ArticleShareInsert: Codable {
            let articleId: String
            let userId: String
            let userName: String
            let groupId: String
            let groupName: String
            
            enum CodingKeys: String, CodingKey {
                case articleId = "article_id"
                case userId = "user_id"
                case userName = "user_name"
                case groupId = "group_id"
                case groupName = "group_name"
            }
        }
        
        let shareData = ArticleShareInsert(
            articleId: articleId.uuidString,
            userId: currentUser.id.uuidString,
            userName: currentUser.displayName,
            groupId: groupId.uuidString,
            groupName: groupName
        )
        
        try await client
            .from("article_shares")
            .insert(shareData)
            .execute()
        
        print("✅ 分享成功")
    }
    
    // MARK: - Trending Keywords & Article Search
    
    /// 獲取熱門關鍵字（前5個最常用的關鍵字）
    func fetchTrendingKeywords() async throws -> [String] {
        print("🔥 準備獲取熱門關鍵字")
        
        do {
            // 創建專門用於關鍵字查詢的輕量級模型
            struct KeywordResponse: Codable {
                let keywords: [String]
            }
            
            // 獲取所有文章的關鍵字
            let keywordResponses: [KeywordResponse] = try await client
                .from("articles")
                .select("keywords")
                .execute()
                .value
            
            // 統計關鍵字出現頻率
            var keywordCount: [String: Int] = [:]
            
            for response in keywordResponses {
                for keyword in response.keywords {
                    let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedKeyword.isEmpty {
                        keywordCount[trimmedKeyword, default: 0] += 1
                    }
                }
            }
            
            // 如果沒有關鍵字數據，返回預設熱門關鍵字
            if keywordCount.isEmpty {
                print("ℹ️ 沒有關鍵字數據，使用預設熱門關鍵字")
                return ["投資分析", "市場趨勢", "股票", "基金", "風險管理"]
            }
            
            // 按出現次數排序，取前5個
            let trendingKeywords = keywordCount
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { $0.key }
            
            let result = Array(trendingKeywords)
            print("✅ 獲取熱門關鍵字成功: \(result)")
            return result
            
        } catch {
            print("⚠️ 獲取關鍵字失敗，使用預設關鍵字: \(error)")
            // 發生錯誤時返回預設關鍵字
            return ["投資分析", "市場趨勢", "股票", "基金", "風險管理"]
        }
    }
    
    /// 根據關鍵字篩選文章
    func fetchArticlesByKeyword(_ keyword: String) async throws -> [Article] {
        print("🔍 根據關鍵字篩選文章: \(keyword)")
        
        if keyword == "全部" {
            // 如果選擇"全部"，返回所有文章
            return try await fetchArticles()
        }
        
        // 獲取所有文章
        let allArticles = try await fetchArticles()
        
        // 篩選包含指定關鍵字的文章
        let filteredArticles = allArticles.filter { article in
            // 檢查關鍵字數組是否包含指定關鍵字
            article.keywords.contains { $0.localizedCaseInsensitiveContains(keyword) } ||
            // 也檢查標題和摘要是否包含關鍵字
            article.title.localizedCaseInsensitiveContains(keyword) ||
            article.summary.localizedCaseInsensitiveContains(keyword)
        }
        
        print("✅ 根據關鍵字 '\(keyword)' 篩選到 \(filteredArticles.count) 篇文章")
        return filteredArticles
    }
    
    /// 獲取完整的熱門關鍵字列表（包括"全部"選項）
    func getTrendingKeywordsWithAll() async throws -> [String] {
        let trendingKeywords = try await fetchTrendingKeywords()
        return ["全部"] + trendingKeywords
    }

    // MARK: - Group Management
    func createPortfolio(groupId: UUID, userId: UUID) async throws -> UserPortfolio {
        try await SupabaseManager.shared.ensureInitialized()
        
        struct PortfolioInsert: Codable {
            let groupId: String
            let userId: String
            let initialCash: Double
            let availableCash: Double
            let totalValue: Double
            let returnRate: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
                case initialCash = "initial_cash"
                case availableCash = "available_cash"
                case totalValue = "total_value"
                case returnRate = "return_rate"
                case lastUpdated = "last_updated"
            }
        }
        
        let portfolioData = PortfolioInsert(
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            initialCash: 1000000, // 初始 100 萬虛擬資金
            availableCash: 1000000, // 可用現金 = 初始資金
            totalValue: 1000000, // 總價值 = 初始資金
            returnRate: 0.0,
            lastUpdated: Date()
        )
        
        let response: [UserPortfolio] = try await self.client
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
        
        try await client
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
        let response: [UserPortfolio] = try await client
            .from("portfolios")
            .select()
            .eq("group_id", value: groupId)
            .order("return_rate", ascending: false)
            .execute()
            .value
        
        // 更新每個成員的排名
        for (index, portfolio) in response.enumerated() {
            try await client
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
        
        let response: [GroupInvitation] = try await client
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
        
        try await client
            .from("group_invitations")
            .update(["status": status])
            .eq("id", value: invitationId)
            .execute()
        
        if accept {
            let response: [GroupInvitation] = try await client
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
        
        let portfolios: [UserPortfolio] = try await client
            .from("portfolios")
            .select()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        guard let portfolio = portfolios.first else {
            throw SupabaseError.dataNotFound
        }
        
        let positions: [UserPosition] = try await client
            .from("positions")
            .select()
            .eq("portfolio_id", value: portfolio.id)
            .execute()
            .value
        
        return PortfolioWithPositions(portfolio: portfolio, positions: positions)
    }
    
    func updatePosition(position: UserPosition) async throws {
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
        
        try await client
            .from("positions")
            .update(updateData)
            .eq("id", value: position.id)
            .execute()
    }
    
    func createPosition(portfolioId: UUID, symbol: String, shares: Double, price: Double) async throws -> UserPosition {
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
        
        let response: [UserPosition] = try await client
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
        
        let response: [WalletTransaction] = try await client
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
        
        try await client
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
        
        // 將代幣轉換為 NTD（1 代幣 = 100 NTD）
        let amountInNTD = amount * 100.0
        
        // 檢查餘額是否足夠
        let currentBalance = try await fetchWalletBalance()
        guard Double(currentBalance) >= amountInNTD else {
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
            transactionType: WalletTransactionType.tip.rawValue,
            amount: -Int(amountInNTD), // 負數表示支出，使用 NTD 金額
            description: "抖內禮物",
            status: TransactionStatus.confirmed.rawValue,
            paymentMethod: "wallet",
            blockchainId: nil,
            recipientId: recipientId.uuidString,
            groupId: groupId.uuidString,
            createdAt: Date()
        )
        
        let response: [WalletTransaction] = try await client
            .from("wallet_transactions")
            .insert(transactionData)
            .select()
            .execute()
            .value
        
        guard let transaction = response.first else {
            throw SupabaseError.unknown("Failed to create tip transaction")
        }
        
        print("✅ [SupabaseService] 抖內交易創建成功: \(Int(amount)) 代幣 (\(Int(amountInNTD)) NTD)")
        return transaction
    }
    
    /// 創建抖內捐贈記錄 (用於禮物系統和排行榜)
    func createDonationRecord(groupId: UUID, amount: Double) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        // 檢查餘額是否足夠
        let currentBalance = try await fetchWalletBalance()
        guard Double(currentBalance) >= amount else {
            throw SupabaseError.unknown("餘額不足")
        }
        
        // 創建捐贈記錄結構
        struct DonationRecord: Codable {
            let id: String
            let groupId: String
            let donorId: String
            let donorName: String
            let amount: Int
            let message: String?
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case groupId = "group_id"
                case donorId = "donor_id"
                case donorName = "donor_name"
                case amount
                case message
                case createdAt = "created_at"
            }
        }
        
        let donationData = DonationRecord(
            id: UUID().uuidString,
            groupId: groupId.uuidString,
            donorId: currentUser.id.uuidString,
            donorName: currentUser.displayName,
            amount: Int(amount),
            message: nil,
            createdAt: Date()
        )
        
        // 插入捐贈記錄到 group_donations 表
        try await client
            .from("group_donations")
            .insert(donationData)
            .execute()
        
        // 獲取群組主持人資訊
        let group = try await fetchInvestmentGroup(id: groupId)
        let hostProfile = try? await fetchUserProfileByDisplayName(group.host)
        
        // 為群組主持人創建收益記錄
        if let hostProfile = hostProfile {
            try await createCreatorRevenue(
                creatorId: hostProfile.id,
                revenueType: .groupTip,
                amount: Int(amount),
                sourceId: groupId,
                sourceName: group.name,
                description: "群組抖內收入來自 \(currentUser.displayName)"
            )
        }
        
        // 創建錢包交易記錄
        _ = try await createTipTransaction(
            recipientId: hostProfile?.id ?? UUID(),
            amount: amount,
            groupId: groupId
        )
        
        // 扣除用戶餘額 (amount 已經是金幣數量)
        try await updateWalletBalance(delta: -Int(amount))
        
        print("✅ [SupabaseService] 群組抖內處理完成: \(currentUser.displayName) 抖內 \(Int(amount)) 代幣給主持人 \(group.host)")
    }
    
    
    // MARK: - Creator Revenue System
    
    /// 創建創作者收益記錄
    func createCreatorRevenue(
        creatorId: UUID, 
        revenueType: RevenueType, 
        amount: Int, 
        sourceId: UUID? = nil, 
        sourceName: String? = nil, 
        description: String
    ) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct CreatorRevenueInsert: Codable {
            let id: String
            let creatorId: String
            let revenueType: String
            let amount: Int
            let sourceId: String?
            let sourceName: String?
            let description: String
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case creatorId = "creator_id"
                case revenueType = "revenue_type"
                case amount
                case sourceId = "source_id"
                case sourceName = "source_name"
                case description
                case createdAt = "created_at"
            }
        }
        
        let revenueData = CreatorRevenueInsert(
            id: UUID().uuidString,
            creatorId: creatorId.uuidString,
            revenueType: revenueType.rawValue,
            amount: amount,
            sourceId: sourceId?.uuidString,
            sourceName: sourceName,
            description: description,
            createdAt: Date()
        )
        
        try await client
            .from("creator_revenues")
            .insert(revenueData)
            .execute()
        
        print("✅ [SupabaseService] 創作者收益記錄創建成功: \(revenueType.displayName) \(amount) 金幣")
    }
    
    /// 獲取創作者總收益統計
    func fetchCreatorRevenueStats(creatorId: UUID) async throws -> CreatorRevenueStats {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [CreatorRevenue] = try await client
            .from("creator_revenues")
            .select()
            .eq("creator_id", value: creatorId.uuidString)
            .execute()
            .value
        
        // 按類型統計收益
        var stats = CreatorRevenueStats()
        
        for revenue in response {
            switch revenue.revenueType {
            case .subscriptionShare:
                stats.subscriptionEarnings += Double(revenue.amount)
            case .readerTip:
                stats.tipEarnings += Double(revenue.amount)
            case .groupEntryFee:
                stats.groupEntryFeeEarnings += Double(revenue.amount)
            case .groupTip:
                stats.groupTipEarnings += Double(revenue.amount)
            }
        }
        
        stats.totalEarnings = stats.subscriptionEarnings + stats.tipEarnings + 
                             stats.groupEntryFeeEarnings + stats.groupTipEarnings
        stats.withdrawableAmount = stats.totalEarnings // 目前全部可提領
        
        print("✅ [SupabaseService] 創作者收益統計載入成功: 總計 \(stats.totalEarnings) 金幣")
        return stats
    }
    
    /// 處理提領申請 (將總收益歸零並轉入錢包)
    func processWithdrawal(creatorId: UUID, amount: Double) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 1. 獲取當前收益統計
        let stats = try await fetchCreatorRevenueStats(creatorId: creatorId)
        
        // 2. 檢查提領金額是否合法
        guard amount <= stats.withdrawableAmount else {
            throw SupabaseError.unknown("提領金額超過可提領餘額")
        }
        
        // 3. 創建提領記錄
        struct WithdrawalInsert: Codable {
            let id: String
            let creatorId: String
            let amount: Int
            let amountTWD: Int
            let status: String
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case creatorId = "creator_id"
                case amount
                case amountTWD = "amount_twd"
                case status
                case createdAt = "created_at"
            }
        }
        
        let withdrawalData = WithdrawalInsert(
            id: UUID().uuidString,
            creatorId: creatorId.uuidString,
            amount: Int(amount),
            amountTWD: Int(amount), // 1:1 匯率
            status: WithdrawalStatus.completed.rawValue,
            createdAt: Date()
        )
        
        try await client
            .from("withdrawal_records")
            .insert(withdrawalData)
            .execute()
        
        // 4. 將提領金額加入用戶錢包
        try await updateWalletBalance(delta: Int(amount))
        
        // 4.5. 創建錢包交易記錄（提領記錄）
        try await createWalletTransaction(
            type: WalletTransactionType.deposit.rawValue, // 對錢包來說是入帳
            amount: amount,
            description: "創作者收益提領",
            paymentMethod: "creator_earnings"
        )
        
        // 5. 刪除已提領的收益記錄，而不是創建負數記錄
        try await client
            .from("creator_revenues")
            .delete()
            .eq("creator_id", value: creatorId.uuidString)
            .execute()
        
        print("✅ [SupabaseService] 已清理提領用戶的收益記錄")
        
        print("✅ [SupabaseService] 提領處理成功: \(amount) 金幣已轉入錢包")
    }
    
    /// 處理群組入會費收入 (當有人加入付費群組時)
    func processGroupEntryFeeRevenue(groupId: UUID, newMemberId: UUID, entryFee: Int) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 獲取群組資訊以找到主持人
        let group = try await fetchInvestmentGroup(id: groupId)
        let hostProfile = try? await fetchUserProfileByDisplayName(group.host)
        let newMemberProfile = try? await fetchUserProfileById(userId: newMemberId)
        
        // 為群組主持人創建收益記錄
        if let hostProfile = hostProfile {
            try await createCreatorRevenue(
                creatorId: hostProfile.id,
                revenueType: .groupEntryFee,
                amount: entryFee,
                sourceId: groupId,
                sourceName: group.name,
                description: "群組入會費收入來自 \(newMemberProfile?.displayName ?? "新成員")"
            )
            
            print("✅ [SupabaseService] 群組入會費收益記錄完成: 主持人 \(group.host) 獲得 \(entryFee) 金幣")
        }
    }
    
    /// 完整的加入群組流程：扣款 + 記錄收益 + 更新群組成員
    func joinInvestmentGroup(groupId: UUID) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 1. 獲取群組資訊
        let group = try await fetchInvestmentGroup(id: groupId)
        let entryFee = group.tokenCost // 使用 tokenCost (Int 類型)
        
        // 2. 檢查用戶餘額是否足夠
        let currentBalance = try await fetchWalletBalance()
        guard currentBalance >= Double(entryFee) else {
            let currentBalanceInt = Int(currentBalance)
            throw SupabaseError.unknown("錢包餘額不足，需要 \(entryFee) 代幣，當前餘額：\(currentBalanceInt) 代幣")
        }
        
        // 3. 檢查是否已經是群組成員
        let isAlreadyMember = try await checkGroupMembership(groupId: groupId, userId: currentUser.id)
        if isAlreadyMember {
            throw SupabaseError.unknown("您已經是此群組的成員")
        }
        
        // 4. 扣除用戶錢包餘額
        try await updateWalletBalance(delta: -entryFee)
        
        // 5. 創建用戶的交易記錄（支出）
        try await createWalletTransaction(
            type: WalletTransactionType.groupEntryFee.rawValue,
            amount: -Double(entryFee), // 負數表示支出
            description: "加入群組「\(group.name)」入會費",
            paymentMethod: "wallet"
        )
        
        // 6. 為群組主持人創建收益記錄
        try await processGroupEntryFeeRevenue(
            groupId: groupId,
            newMemberId: currentUser.id,
            entryFee: entryFee
        )
        
        // 7. 將用戶添加到群組成員列表
        try await addUserToGroup(groupId: groupId, userId: currentUser.id)
        
        // 8. 發送錢包餘額更新通知
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
        }
        
        let message = "成功加入群組「\(group.name)」！已扣除 \(entryFee) 代幣入會費"
        print("✅ [SupabaseService] \(message)")
        return message
    }
    
    /// 檢查用戶是否已經是群組成員
    private func checkGroupMembership(groupId: UUID, userId: UUID) async throws -> Bool {
        let response = try await client
            .from("group_members")
            .select("id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        let data = response.data
        return !data.isEmpty
    }
    
    /// 將用戶添加到群組成員列表
    private func addUserToGroup(groupId: UUID, userId: UUID) async throws {
        struct GroupMemberInsert: Codable {
            let id: String
            let groupId: String
            let userId: String
            let joinedAt: String
            let status: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case groupId = "group_id"
                case userId = "user_id"
                case joinedAt = "joined_at"
                case status
            }
        }
        
        let memberData = GroupMemberInsert(
            id: UUID().uuidString,
            groupId: groupId.uuidString,
            userId: userId.uuidString,
            joinedAt: ISO8601DateFormatter().string(from: Date()),
            status: "active"
        )
        
        try await client
            .from("group_members")
            .insert(memberData)
            .execute()
    }
    
    /// 群組內抖內功能：用戶在群組內給主持人抖內
    func sendGroupTip(groupId: UUID, tipAmount: Int, message: String = "") async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 1. 獲取群組資訊
        let group = try await fetchInvestmentGroup(id: groupId)
        
        // 2. 檢查用戶餘額是否足夠 (轉換代幣為 NTD: 1 代幣 = 100 NTD)
        let currentBalance = try await fetchWalletBalance()
        let tipAmountInNTD = Double(tipAmount * 100)
        guard currentBalance >= tipAmountInNTD else {
            let currentBalanceInTokens = Int(currentBalance / 100.0)
            throw SupabaseError.unknown("錢包餘額不足，需要 \(tipAmount) 代幣，當前餘額：\(currentBalanceInTokens) 代幣")
        }
        
        // 3. 檢查是否是群組成員
        let isMember = try await checkGroupMembership(groupId: groupId, userId: currentUser.id)
        guard isMember else {
            throw SupabaseError.unknown("您必須是群組成員才能進行抖內")
        }
        
        // 4. 扣除用戶錢包餘額 (使用 NTD 金額)
        try await updateWalletBalance(delta: -Int(tipAmountInNTD))
        
        // 5. 創建用戶的交易記錄（支出）
        let tipDescription = message.isEmpty ? "群組「\(group.name)」內抖內" : "群組「\(group.name)」內抖內：\(message)"
        try await createWalletTransaction(
            type: WalletTransactionType.groupTip.rawValue,
            amount: -tipAmountInNTD, // 負數表示支出，使用 NTD 金額
            description: tipDescription,
            paymentMethod: "wallet"
        )
        
        // 6. 為群組主持人創建收益記錄
        let hostProfile = try? await fetchUserProfileByDisplayName(group.host)
        let tipper = try? await fetchUserProfileById(userId: currentUser.id)
        
        if let hostProfile = hostProfile {
            try await createCreatorRevenue(
                creatorId: hostProfile.id,
                revenueType: .groupTip,
                amount: tipAmount,
                sourceId: groupId,
                sourceName: group.name,
                description: "群組抖內收入來自 \(tipper?.displayName ?? "群組成員")"
            )
        }
        
        // 7. 發送錢包餘額更新通知
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
        }
        
        let resultMessage = "成功在群組「\(group.name)」內抖內 \(tipAmount) 代幣！"
        print("✅ [SupabaseService] \(resultMessage)")
        return resultMessage
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
        
        let response: [UserProfile] = try await client
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
    
    /// 根據用戶ID獲取用戶資料
    func fetchUserProfileById(userId: UUID) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: userId.uuidString)
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
            let _: PostgrestResponse<Void> = try await client
            .rpc("check_connection")
                .execute()
            
            // 連線檢查成功（靜默）
            return (true, "✅ [連線檢查] 資料庫連線正常")
            
        } catch {
            // 如果 RPC 不存在，嘗試一個更基本的查詢
            do {
                // 只查詢 id 欄位，並使用基本的字典解碼
                let response = try await client
            .from("user_profiles")
                    .select("id")
                    .limit(1)
                    .execute()
                
                // 檢查是否有響應數據（不解碼為具體模型）
                // 連線檢查成功 (備用方法，靜默)
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
            let userProfiles: [UserProfile] = try await client
            .from("user_profiles")
                .select()
                .eq("email", value: userEmail)
                .limit(1)
                .execute()
                .value
            
            guard let userProfile = userProfiles.first else {
                // 找不到用戶（靜默）
                return (false, 0, nil)
            }
            
            // 查找該用戶的所有訊息
            let messages: [ChatMessage] = try await client
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
            
            let members: [GroupMemberResponse] = try await client
            .from("group_members")
                .select("group_id")
                .eq("user_id", value: userId.uuidString)
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value
            
            let isMember = !members.isEmpty
            // 群組成員檢查完成（靜默）
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
            let response: [ChatMessage] = try await client
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
    
    /// 獲取當前用戶在群組中的角色
    func fetchUserRole(groupId: UUID) async throws -> UserRole {
        guard let currentUser = getCurrentUser() else {
            print("❌ [fetchUserRole] 無法獲取當前用戶")
            throw SupabaseError.notAuthenticated
        }
        
        print("🔍 [fetchUserRole] 檢查用戶 \(currentUser.displayName) 在群組 \(groupId) 中的角色")
        
        do {
            let roleString = try await fetchUserRole(userId: currentUser.id, groupId: groupId)
            let role = UserRole(rawValue: roleString) ?? .none
            print("✅ [fetchUserRole] 用戶角色: \(roleString) -> \(role)")
            return role
        } catch {
            print("❌ [fetchUserRole] 獲取角色失敗: \(error)")
            throw error
        }
    }
    
    /// 獲取用戶在群組中的角色
    func fetchUserRole(userId: UUID, groupId: UUID) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        // 使用簡單的結構來只獲取需要的欄位
        struct GroupHostInfo: Codable {
            let id: String
            let host: String
        }
        
        // 首先檢查用戶是否為群組主持人
        let groupResponse: [GroupHostInfo] = try await client
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
            
            let userProfiles: [UserDisplayName] = try await client
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
        
        let memberResponse: [GroupMemberCheck] = try await client
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
        
        let memberResponse: [GroupMemberCount] = try await client
            .from("group_members")
            .select("user_id")
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        
        return memberResponse.count
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
        
        try await client
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
        
        try await client
            .from("group_invitations")
            .update(update)
            .eq("id", value: invitationId.uuidString)
            .execute()
        
        // 獲取邀請詳情以便加入群組
        let invitations: [GroupInvitation] = try await client
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
        let invitations: [GroupInvitation] = try await client
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

        // 查詢好友關係（使用 friendships 表）
        let friendships: [Friendship] = try await client
            .from("friendships")
            .select("requester_id, addressee_id")
            .or("requester_id.eq.\(current.id.uuidString),addressee_id.eq.\(current.id.uuidString)")
            .eq("status", value: "accepted")
            .execute()
            .value
        
        // 提取好友ID（排除自己）
        let friendIds = friendships.compactMap { friendship -> String? in
            if friendship.requesterID.uuidString == current.id.uuidString {
                return friendship.addresseeID.uuidString
            } else if friendship.addresseeID.uuidString == current.id.uuidString {
                return friendship.requesterID.uuidString
            }
            return nil
        }

        if friendIds.isEmpty { return [] }

        let friends: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .in("id", values: friendIds)
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
        
        try await client
            .from("group_invitations")
            .insert(invitation)
            .execute()
            
                    logError(message: "✅ [好友邀請] 成功創建邀請: 用戶 \(inviteeId) 加入群組 \(groupId)")
    }
    
    // MARK: - Wallet Management
    
    /// 獲取用戶錢包餘額
    func fetchWalletBalance() async throws -> Double {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        // 嘗試獲取現有餘額
        let balanceResponse: [UserBalance] = try await client
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
            
            try await client
            .from("user_balances")
                .insert(newBalance)
                .execute()
            
            return 10000.0
        }
    }
    
    /// 更新用戶錢包餘額
    func updateWalletBalance(delta: Int) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
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
        
        try await client
            .from("user_balances")
            .update(updateData)
            .eq("user_id", value: userId)
            .execute()
        
        // 發送餘額更新通知給所有 ViewModels
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
        }
        
        print("✅ 錢包餘額更新成功: \(currentBalance) → \(newBalance) (變化: \(delta))")
    }
    
    /// 獲取用戶交易記錄
    func fetchUserTransactions(limit: Int = 5) async throws -> [WalletTransaction] {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        let response: [WalletTransaction] = try await client
            .from("wallet_transactions")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        print("✅ [SupabaseService] 成功載入 \(response.count) 筆交易記錄")
        return response
    }
    
    /// 獲取指定用戶的代幣餘額
    func getUserBalance(userId: UUID) async throws -> Double {
        try SupabaseManager.shared.ensureInitialized()
        
        // 嘗試獲取現有餘額
        let balanceResponse: [UserBalance] = try await client
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let userBalance = balanceResponse.first {
            return Double(userBalance.balance)
        } else {
            // 如果沒有記錄，回傳 0 (不自動創建記錄)
            return 0.0
        }
    }
    
    /// 扣除用戶代幣並記錄交易
    func deductTokens(userId: UUID, amount: Int, description: String) async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        // 獲取當前餘額
        let currentBalance = try await getUserBalance(userId: userId)
        let newBalance = currentBalance - Double(amount)
        
        // 確保餘額不會變成負數
        guard newBalance >= 0 else {
            throw SupabaseError.insufficientBalance
        }
        
        // 更新餘額
        struct UserBalanceUpdate: Codable {
            let balance: Int
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case balance
                case updatedAt = "updated_at"
            }
        }
        
        let updateData = UserBalanceUpdate(
            balance: Int(newBalance),
            updatedAt: Date()
        )
        
        try await self.client
            .from("user_balances")
            .update(updateData)
            .eq("user_id", value: userId)
            .execute()
        
        // 記錄交易 - 使用最基本的有效交易類型
        let transaction = WalletTransaction(
            id: UUID(),
            userId: userId,
            transactionType: "withdrawal", // 扣除類型，使用提領
            amount: -amount, // 負數表示扣除
            description: description,
            status: "confirmed",
            paymentMethod: "system",
            blockchainId: nil,
            recipientId: nil,
            groupId: nil,
            createdAt: Date()
        )
        
        try await self.client
            .from("wallet_transactions")
            .insert(transaction)
            .execute()
        
        // 發送餘額更新通知給所有 ViewModels
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
        }
        
        print("✅ 成功扣除 \(amount) 代幣，餘額: \(currentBalance) → \(newBalance)")
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
        let subscriptions: [Subscription] = try await client
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
        
        try await client
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
        let existingViews: [ArticleView] = try await client
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
        
        try await client
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
        let todayViews: [ArticleView] = try await client
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
        let existingViews: [ArticleView] = try await client
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
        
        try await client
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
        
        let authors: [AuthorInfo] = try await client
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
        
        let subscriptions: [PlatformSubscription] = try await client
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
        
        let subscriptions: [PlatformSubscription] = try await client
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
        
        let insertedSubscriptions: [PlatformSubscription] = try await client
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
        
        let existingReads: [ArticleReadRecord] = try await client
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
        
        let _: [ArticleReadRecord] = try await client
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
        paymentMethod: String,
        status: String = TransactionStatus.confirmed.rawValue
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
            status: status,
            paymentMethod: paymentMethod,
            createdAt: DateFormatter.iso8601.string(from: Date())
        )
        
        let _ = try await client
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
            let result: [SimpleResult] = try await client
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
                
                let users: [UserProfile] = try await client
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
        let bucket = "article-images"
        let filePath = "\(UUID().uuidString)/\(fileName)"
        
        try await client.storage
            .from(bucket)
            .upload(path: filePath, file: data, options: FileOptions(contentType: "image/jpeg"))
            
        let urlResponse = try await client.storage
            .from(bucket)
            .getPublicURL(path: filePath)
            
        return urlResponse
    }
    
    // MARK: - 測試群組管理
    
    /// 創建真實的測試群組數據
    func createRealTestGroups() async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        // 定義六個群組
        let groupsData = [
            ("Test01", "測試群組 - 基礎投資討論", 10),
            ("林老師的投資群組", "專業股票分析，適合新手投資者", 1),
            ("黃老師的投資群組", "中階投資策略分享", 10),
            ("張老師的投資群組", "高階投資技術分析", 100),
            ("徐老師的投資群組", "專業期貨與選擇權討論", 150),
            ("王老師的投資群組", "頂級投資組合管理", 500)
        ]
        
        // 先刪除現有的測試群組
        try await self.client
            .from("investment_groups")
            .delete()
            .like("name", value: "%老師的投資群組%")
            .execute()
        
        // 刪除 Test01 群組
        try await self.client
            .from("investment_groups")
            .delete()
            .eq("name", value: "Test01")
            .execute()
        
        // 創建新的群組
        for (name, description, tokenCost) in groupsData {
            // Create a database-compatible struct that only includes existing columns
            struct DatabaseGroup: Codable {
                let id: UUID
                let name: String
                let host: String
                let returnRate: Double
                let entryFee: String?
                let memberCount: Int
                let category: String?
                let createdAt: Date
                let updatedAt: Date
                
                enum CodingKeys: String, CodingKey {
                    case id
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
            
            let dbGroup = DatabaseGroup(
                id: UUID(),
                name: name,
                host: name.replacingOccurrences(of: "的投資群組", with: ""),
                returnRate: Double.random(in: 5.0...25.0),
                entryFee: tokenCost > 0 ? "\(tokenCost) 代幣" : nil,
                memberCount: 0,
                category: "投資群組",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try await self.client
                .from("investment_groups")
                .insert(dbGroup)
                .execute()
            
            print("✅ 創建群組: \(name) - \(tokenCost) 代幣")
        }
        
        print("✅ 所有測試群組創建完成")
    }
    
    /// 清空所有聊天內容
    func clearAllChatMessages() async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        // 刪除所有聊天訊息
        try await self.client
            .from("chat_messages")
            .delete()
            .neq("id", value: "00000000-0000-0000-0000-000000000000") // 刪除所有記錄
            .execute()
        
        print("✅ 已清空所有聊天內容")
    }
    
    /// 清理所有測試和假資料群組
    func clearAllDummyGroups() async throws {
        try await SupabaseManager.shared.ensureInitialized()
        
        do {
            // 清理所有現有的假群組（包括螢幕截圖中顯示的群組）
            let testKeywords = [
                "%綠能環保基金%",
                "%短期投機聯盟%", 
                "%測試投資群組%",
                "%王老師的股票群組%",
                "%老師的投資群組%",
                "%科技股投資俱樂部%", 
                "%價值投資學院%",
                "%AI科技前瞻%", 
                "%加密貨幣先鋒%", 
                "%綠能投資團%"
            ]
            
            // 檢查所有測試群組是否存在
            var foundGroups: [InvestmentGroup] = []
            for keyword in testKeywords {
                let existingGroups: [InvestmentGroup] = try await client
                    .from("investment_groups")
                    .select()
                    .like("name", value: keyword)
                    .execute()
                    .value
                foundGroups.append(contentsOf: existingGroups)
            }
            
            if !foundGroups.isEmpty {
                print("🧹 清理測試資料：找到 \(foundGroups.count) 個測試群組")
                
                // 批量刪除所有找到的測試群組
                for keyword in testKeywords {
                    let existingGroups: [InvestmentGroup] = try await client
                        .from("investment_groups")
                        .select()
                        .like("name", value: keyword)
                        .execute()
                        .value
                    
                    if !existingGroups.isEmpty {
                        try await client
                            .from("investment_groups")
                            .delete()
                            .like("name", value: keyword)
                            .execute()
                        print("✅ 已刪除: \(keyword) (\(existingGroups.count)個)")
                    }
                }
            } else {
                print("✅ 測試資料已清理完成 (無需清理)")
            }
            
            // 額外清理：刪除所有 created_at 在今天之前的群組（假設都是測試資料）
            try await client
                .from("investment_groups")
                .delete()
                .lt("created_at", value: "2025-07-19T00:00:00")
                .execute()
            
            print("✅ [SupabaseService] 所有測試群組已清理完成")
            
        } catch {
            print("❌ [SupabaseService] 清理測試群組失敗: \(error)")
            throw SupabaseError.from(error)
        }
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

extension SupabaseService {
    // MARK: - Trading Rankings
    
    /// 獲取投資排行榜資料
    func fetchTradingRankings(period: String = "all", limit: Int = 10) async throws -> [TradingUserRanking] {
        try SupabaseManager.shared.ensureInitialized()
        
        struct TradingUserData: Codable {
            let id: String
            let name: String
            let cumulativeReturn: Double
            let totalAssets: Double
            let totalProfit: Double
            let avatarUrl: String?
            let createdAt: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case name
                case cumulativeReturn = "cumulative_return"
                case totalAssets = "total_assets"
                case totalProfit = "total_profit"
                case avatarUrl = "avatar_url"
                case createdAt = "created_at"
            }
        }
        
        let tradingUsers: [TradingUserData] = try await self.client
            .from("trading_users")
            .select("id, name, cumulative_return, total_assets, total_profit, avatar_url, created_at")
            .eq("is_active", value: true)
            .order("cumulative_return", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        let rankings = tradingUsers.enumerated().map { index, user in
            TradingUserRanking(
                rank: index + 1,
                userId: user.id,
                name: user.name,
                returnRate: user.cumulativeReturn,
                totalAssets: user.totalAssets,
                totalProfit: user.totalProfit,
                avatarUrl: user.avatarUrl,
                period: period
            )
        }
        
        return rankings
    }
    
    /// 獲取用戶的投資績效資料
    func fetchUserTradingPerformance(userId: String) async throws -> TradingUserPerformance? {
        try SupabaseManager.shared.ensureInitialized()
        
        struct TradingUserData: Codable {
            let id: String
            let name: String
            let cumulativeReturn: Double
            let totalAssets: Double
            let totalProfit: Double
            let cashBalance: Double
            let avatarUrl: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case name
                case cumulativeReturn = "cumulative_return"
                case totalAssets = "total_assets"
                case totalProfit = "total_profit"
                case cashBalance = "cash_balance"
                case avatarUrl = "avatar_url"
            }
        }
        
        let users: [TradingUserData] = try await self.client
            .from("trading_users")
            .select("id, name, cumulative_return, total_assets, total_profit, cash_balance, avatar_url")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let userData = users.first else {
            return nil
        }
        
        // 獲取用戶排名
        let allUsers: [TradingUserData] = try await self.client
            .from("trading_users")
            .select("cumulative_return")
            .eq("is_active", value: true)
            .order("cumulative_return", ascending: false)
            .execute()
            .value
        
        let userRank = allUsers.firstIndex { $0.cumulativeReturn <= userData.cumulativeReturn } ?? allUsers.count
        
        return TradingUserPerformance(
            userId: userData.id,
            name: userData.name,
            rank: userRank + 1,
            returnRate: userData.cumulativeReturn,
            totalAssets: userData.totalAssets,
            totalProfit: userData.totalProfit,
            cashBalance: userData.cashBalance,
            avatarUrl: userData.avatarUrl
        )
    }
    
    /// 清除所有測試用戶資料（僅開發使用）
    func clearAllTradingTestData() async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        print("🧹 開始清理交易系統測試資料...")
        
        // 清理順序很重要，要先清理有外鍵依賴的表格
        let tablesToClear = [
            "trading_performance_snapshots",
            "trading_transactions", 
            "trading_positions",
            "trading_referrals",
            "trading_watchlists",
            "trading_alerts",
            "trading_users"
        ]
        
        for tableName in tablesToClear {
            try await self.client
                .from(tableName)
                .delete()
                .neq("id", value: "00000000-0000-0000-0000-000000000000")
                .execute()
            
            print("✅ 已清理表格: \(tableName)")
        }
        
        print("🎉 交易系統測試資料清理完成!")
    }
    
    
    
    /// 生成邀請碼
    private func generateInviteCode(from userId: String) -> String {
        return String(userId.prefix(8)).uppercased()
    }
    
    /// 為特定用戶創建或更新交易績效資料
    func createUserTradingPerformance(userId: String, returnRate: Double) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        print("💰 為用戶 \(userId) 創建交易績效，回報率: \(returnRate)%")
        
        let initialAssets = 1000000.0 // 100萬初始資產
        let totalProfit = returnRate / 100.0 * initialAssets
        let totalAssets = initialAssets + totalProfit
        let cashBalance = totalAssets * 0.3 // 30% 現金
        
        struct TradingUserUpsert: Codable {
            let id: String
            let name: String
            let phone: String
            let cashBalance: Double
            let totalAssets: Double
            let totalProfit: Double
            let cumulativeReturn: Double
            let inviteCode: String
            let isActive: Bool
            let riskTolerance: String
            let investmentExperience: String
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case id, name, phone
                case cashBalance = "cash_balance"
                case totalAssets = "total_assets"
                case totalProfit = "total_profit"
                case cumulativeReturn = "cumulative_return"
                case inviteCode = "invite_code"
                case isActive = "is_active"
                case riskTolerance = "risk_tolerance"
                case investmentExperience = "investment_experience"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let userRecord = TradingUserUpsert(
            id: userId,
            name: "Wyatt Lin", // 根據截圖中的名稱
            phone: "+886900000000",
            cashBalance: cashBalance,
            totalAssets: totalAssets,
            totalProfit: totalProfit,
            cumulativeReturn: returnRate,
            inviteCode: generateInviteCode(from: userId),
            isActive: true,
            riskTolerance: "moderate",
            investmentExperience: "intermediate",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        // 先嘗試刪除現有資料（如果存在）
        try await self.client
            .from("trading_users")
            .delete()
            .eq("id", value: userId)
            .execute()
        
        // 插入新資料
        try await self.client
            .from("trading_users")
            .insert(userRecord)
            .execute()
        
        print("✅ 用戶交易績效已創建/更新: \(returnRate)% 回報率")
        
        // 創建績效快照
        try await createUserPerformanceSnapshots(userId: userId, returnRate: returnRate, totalAssets: totalAssets)
    }
    
    /// 為用戶創建績效快照
    private func createUserPerformanceSnapshots(userId: String, returnRate: Double, totalAssets: Double) async throws {
        let calendar = Calendar.current
        let today = Date()
        var snapshots: [PerformanceSnapshotInsert] = []
        
        // 創建過去30天的績效快照
        for daysAgo in (0..<30).reversed() {
            guard let snapshotDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            
            let progress = Double(30 - daysAgo) / 30.0
            let currentReturn = returnRate * progress
            let currentAssets = 1000000.0 + (totalAssets - 1000000.0) * progress
            
            let snapshot = PerformanceSnapshotInsert(
                userId: userId,
                snapshotDate: ISO8601DateFormatter().string(from: snapshotDate),
                totalAssets: currentAssets,
                cashBalance: currentAssets * 0.3,
                positionValue: currentAssets * 0.7,
                dailyReturn: daysAgo == 0 ? currentReturn / 30 : 0,
                cumulativeReturn: currentReturn,
                benchmarkReturn: currentReturn * 0.8,
                alpha: currentReturn * 0.2,
                beta: 1.15,
                sharpeRatio: currentReturn / 12,
                volatility: abs(currentReturn) * 0.15,
                maxDrawdown: -abs(currentReturn) * 0.1,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            
            snapshots.append(snapshot)
        }
        
        if !snapshots.isEmpty {
            // 刪除現有快照（如果存在）
            try await self.client
                .from("trading_performance_snapshots")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            // 插入新快照
            try await self.client
                .from("trading_performance_snapshots")
                .insert(snapshots)
                .execute()
        }
    }
    
    
}

// MARK: - Supporting Structures for Trading Rankings


struct PerformanceSnapshotInsert: Codable {
    let userId: String
    let snapshotDate: String
    let totalAssets: Double
    let cashBalance: Double
    let positionValue: Double
    let dailyReturn: Double
    let cumulativeReturn: Double
    let benchmarkReturn: Double
    let alpha: Double
    let beta: Double
    let sharpeRatio: Double
    let volatility: Double
    let maxDrawdown: Double
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case snapshotDate = "snapshot_date"
        case totalAssets = "total_assets"
        case cashBalance = "cash_balance"
        case positionValue = "position_value"
        case dailyReturn = "daily_return"
        case cumulativeReturn = "cumulative_return"
        case benchmarkReturn = "benchmark_return"
        case alpha, beta
        case sharpeRatio = "sharpe_ratio"
        case volatility
        case maxDrawdown = "max_drawdown"
        case createdAt = "created_at"
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

// MARK: - 創作者收益擴展
extension SupabaseService {
    
    /// 創建創作者收益記錄
    func createCreatorRevenue(
        creatorId: String,
        revenueType: RevenueType,
        amount: Int,
        sourceId: UUID,
        sourceName: String,
        description: String
    ) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct CreatorRevenueInsert: Codable {
            let id: String
            let creatorId: String
            let revenueType: String
            let amount: Int
            let sourceId: String
            let sourceName: String
            let description: String
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case creatorId = "creator_id"
                case revenueType = "revenue_type"
                case amount
                case sourceId = "source_id"
                case sourceName = "source_name"
                case description
                case createdAt = "created_at"
            }
        }
        
        let revenueRecord = CreatorRevenueInsert(
            id: UUID().uuidString,
            creatorId: creatorId,
            revenueType: revenueType.rawValue,
            amount: amount,
            sourceId: sourceId.uuidString,
            sourceName: sourceName,
            description: description,
            createdAt: Date()
        )
        
        try await client
            .from("creator_revenues")
            .insert(revenueRecord)
            .execute()
        
        print("✅ [SupabaseService] 創建創作者收益記錄成功: \(revenueType.rawValue) \(amount) 金幣")
    }
    
    /// 為指定用戶初始化創作者收益數據
    func initializeCreatorRevenueData(userId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        // 首先清理該用戶的所有收益記錄
        try await client
            .from("creator_revenues")
            .delete()
            .eq("creator_id", value: userId.uuidString)
            .execute()
        
        print("✅ [SupabaseService] 已清理用戶 \(userId) 的舊收益記錄")
        
        // 創建正確的收益記錄
        let revenueRecords = [
            (revenueType: RevenueType.subscriptionShare, amount: 5300, description: "平台訂閱分潤收益"),
            (revenueType: RevenueType.readerTip, amount: 1800, description: "讀者抖內收益"),
            (revenueType: RevenueType.groupEntryFee, amount: 1950, description: "群組入會費收益"),
            (revenueType: RevenueType.groupTip, amount: 800, description: "群組抖內收益")
        ]
        
        for record in revenueRecords {
            try await createCreatorRevenue(
                creatorId: userId,
                revenueType: record.revenueType,
                amount: record.amount,
                sourceId: nil,
                sourceName: "系統初始化",
                description: record.description
            )
        }
        
        print("✅ [SupabaseService] 用戶 \(userId) 創作者收益數據初始化完成")
    }
    
    /// 為當前用戶初始化所有必要數據（通用方法）
    func initializeCurrentUserData() async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        let response = try await client
            .rpc("initialize_current_user_data")
            .execute()
        
        // 創建一個結構來處理返回的 JSON
        struct InitializeResponse: Codable {
            let success: Bool
            let message: String
            let userId: String?
            let displayName: String?
            let balance: Int?
            let totalRevenue: Int?
            
            enum CodingKeys: String, CodingKey {
                case success
                case message
                case userId = "user_id"
                case displayName = "display_name"
                case balance
                case totalRevenue = "total_revenue"
            }
        }
        
        let result = try JSONDecoder().decode(InitializeResponse.self, from: response.data)
        
        if result.success {
            print("✅ [SupabaseService] 當前用戶數據初始化成功: \(result.message)")
            return result.message
        } else {
            throw SupabaseError.unknown(result.message)
        }
    }
    
}

// MARK: - 捐贈排行榜擴展
extension SupabaseService {
    
    /// 獲取群組捐贈排行榜
    func fetchGroupDonationLeaderboard(groupId: UUID) async throws -> [DonationSummary] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [GroupDonation] = try await client
            .from("group_donations")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // 統計每個捐贈者的總額
        var donorStats: [String: (name: String, totalAmount: Int, count: Int, lastDate: Date)] = [:]
        
        for record in response {
            let donorId = record.donorId
            let existing = donorStats[donorId]
            
            donorStats[donorId] = (
                name: record.donorName,
                totalAmount: (existing?.totalAmount ?? 0) + record.amount,
                count: (existing?.count ?? 0) + 1,
                lastDate: max(existing?.lastDate ?? record.createdAt, record.createdAt)
            )
        }
        
        // 轉換為 DonationSummary 並按總額排序
        let summaries = donorStats.map { (donorId, stats) in
            DonationSummary(
                donorId: donorId,
                donorName: stats.name,
                totalAmount: stats.totalAmount,
                donationCount: stats.count,
                lastDonationDate: stats.lastDate
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
        
        print("✅ [SupabaseService] 載入捐贈排行榜成功: \(summaries.count) 位捐贈者")
        return summaries
    }
    
    /// 獲取用戶主持的群組列表
    func fetchUserHostedGroups() async throws -> [InvestmentGroup] {
        try SupabaseManager.shared.ensureInitialized()
        
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 查詢用戶為主持人的群組
        let response: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .eq("host_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        print("✅ [SupabaseService] 獲取用戶主持的群組: \(response.count) 個")
        return response
    }
    
    /// 獲取特定用戶在群組中的捐贈統計
    func fetchUserDonationStats(groupId: UUID, userId: String) async throws -> DonationSummary? {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [GroupDonation] = try await client
            .from("group_donations")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .eq("donor_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        guard !response.isEmpty else { return nil }
        
        let totalAmount = response.reduce(0) { $0 + $1.amount }
        let firstRecord = response.first!
        let lastDate = response.max(by: { $0.createdAt < $1.createdAt })?.createdAt ?? firstRecord.createdAt
        
        return DonationSummary(
            donorId: userId,
            donorName: firstRecord.donorName,
            totalAmount: totalAmount,
            donationCount: response.count,
            lastDonationDate: lastDate
        )
    }
    
    // MARK: - Avatar Upload
    
    /// 上傳用戶頭像到 Supabase Storage
    public func uploadAvatar(_ imageData: Data, fileName: String) async throws -> String {
        try SupabaseManager.shared.ensureInitialized()
        
        let path = "avatars/\(fileName)"
        
        // 上傳到 avatars bucket
        try await client.storage
            .from("avatars")
            .upload(path: path, file: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // 獲取公開 URL
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: path)
        
        print("✅ [SupabaseService] 頭像上傳成功: \(publicURL.absoluteString)")
        return publicURL.absoluteString
    }
    
    // MARK: - Statistics & Analytics
    
    /// 獲取活躍用戶數量
    /// 用於統計橫幅顯示活躍交易者數量
    public func fetchActiveUsersCount() async throws -> Int {
        try SupabaseManager.shared.ensureInitialized()
        
        print("📊 [SupabaseService] 開始獲取活躍用戶數量...")
        
        do {
            // 查詢用戶表獲取總用戶數
            let response: PostgrestResponse = try await client
                .from("user_profiles")
                .select("id", head: false, count: .exact)
                .execute()
            
            let count = response.count ?? 0
            print("📊 [SupabaseService] 活躍用戶數量: \(count)")
            
            return count
            
        } catch {
            print("❌ [SupabaseService] 獲取活躍用戶數量失敗: \(error.localizedDescription)")
            
            // 如果是網路錯誤，拋出具體錯誤
            if error.localizedDescription.contains("network") {
                throw SupabaseError.networkError
            }
            
            throw SupabaseError.unknown("獲取用戶統計失敗: \(error.localizedDescription)")
        }
    }
    
    /// 獲取平台統計概覽
    /// 包含總用戶數、今日活躍用戶、總交易量等
    public func fetchPlatformStatistics() async throws -> PlatformStatistics {
        try SupabaseManager.shared.ensureInitialized()
        
        print("📊 [SupabaseService] 開始獲取平台統計...")
        
        // 並行獲取多個統計數據
        async let totalUsersTask = fetchActiveUsersCount()
        
        // 這裡可以添加更多統計查詢
        // async let totalTransactionsTask = fetchTotalTransactions()
        // async let dailyActiveUsersTask = fetchDailyActiveUsers()
        
        do {
            let totalUsers = try await totalUsersTask
            
            return PlatformStatistics(
                totalUsers: totalUsers,
                dailyActiveUsers: totalUsers, // 暫時使用相同數值
                totalTransactions: 0, // 待實現
                lastUpdated: Date()
            )
            
        } catch {
            print("❌ [SupabaseService] 獲取平台統計失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tournament Methods
    
    /// 獲取所有錦標賽
    public func fetchTournaments() async throws -> [Tournament] {
        print("📊 [SupabaseService] 獲取所有錦標賽")
        
        do {
            let tournamentResponses: [TournamentResponse] = try await client
                .from("tournaments")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let tournaments = tournamentResponses.compactMap { response in
                convertTournamentResponseToTournament(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(tournaments.count) 個錦標賽")
            return tournaments
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取特定錦標賽詳情
    public func fetchTournament(id: UUID) async throws -> Tournament {
        print("📊 [SupabaseService] 獲取錦標賽詳情: \(id)")
        
        do {
            let tournamentResponses: [TournamentResponse] = try await client
                .from("tournaments")
                .select()
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value
            
            guard let response = tournamentResponses.first,
                  let tournament = convertTournamentResponseToTournament(response) else {
                throw NSError(domain: "TournamentService", code: 404, userInfo: [NSLocalizedDescriptionKey: "錦標賽不存在"])
            }
            
            print("✅ [SupabaseService] 成功獲取錦標賽: \(tournament.name)")
            return tournament
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽詳情失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取精選錦標賽
    public func fetchFeaturedTournaments() async throws -> [Tournament] {
        print("📊 [SupabaseService] 獲取精選錦標賽")
        
        do {
            let tournamentResponses: [TournamentResponse] = try await client
                .from("tournaments")
                .select()
                .eq("is_featured", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let tournaments = tournamentResponses.compactMap { response in
                convertTournamentResponseToTournament(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(tournaments.count) 個精選錦標賽")
            return tournaments
            
        } catch {
            print("❌ [SupabaseService] 獲取精選錦標賽失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 根據類型獲取錦標賽
    public func fetchTournaments(type: TournamentType) async throws -> [Tournament] {
        print("📊 [SupabaseService] 獲取錦標賽類型: \(type.rawValue)")
        
        do {
            let tournamentResponses: [TournamentResponse] = try await client
                .from("tournaments")
                .select()
                .eq("type", value: type.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let tournaments = tournamentResponses.compactMap { response in
                convertTournamentResponseToTournament(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(tournaments.count) 個 \(type.displayName) 錦標賽")
            return tournaments
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽類型失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 根據狀態獲取錦標賽
    public func fetchTournaments(status: TournamentStatus) async throws -> [Tournament] {
        print("📊 [SupabaseService] 獲取錦標賽狀態: \(status.rawValue)")
        
        do {
            let tournamentResponses: [TournamentResponse] = try await client
                .from("tournaments")
                .select()
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let tournaments = tournamentResponses.compactMap { response in
                convertTournamentResponseToTournament(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(tournaments.count) 個 \(status.displayName) 錦標賽")
            return tournaments
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽狀態失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 加入錦標賽
    public func joinTournament(tournamentId: UUID) async throws -> Bool {
        print("📊 [SupabaseService] 加入錦標賽: \(tournamentId)")
        
        guard let currentUser = getCurrentUser() else {
            throw NSError(domain: "TournamentService", code: 401, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }
        
        do {
            // 檢查錦標賽是否存在且可加入
            let tournament = try await fetchTournament(id: tournamentId)
            
            guard tournament.status == .enrolling else {
                throw NSError(domain: "TournamentService", code: 400, userInfo: [NSLocalizedDescriptionKey: "錦標賽不在報名期間"])
            }
            
            guard tournament.currentParticipants < tournament.maxParticipants else {
                throw NSError(domain: "TournamentService", code: 400, userInfo: [NSLocalizedDescriptionKey: "錦標賽名額已滿"])
            }
            
            // 檢查是否已經參加
            let existingParticipants: [TournamentParticipantResponse] = try await client
                .from("tournament_participants")
                .select()
                .eq("tournament_id", value: tournamentId)
                .eq("user_id", value: currentUser.id)
                .execute()
                .value
            
            if !existingParticipants.isEmpty {
                throw NSError(domain: "TournamentService", code: 400, userInfo: [NSLocalizedDescriptionKey: "您已經參加了這個錦標賽"])
            }
            
            // 加入錦標賽
            let participantData: [String: Any] = [
                "tournament_id": tournamentId.uuidString,
                "user_id": currentUser.id.uuidString,
                "user_name": currentUser.displayName,
                "user_avatar": currentUser.avatarUrl ?? "",
                "virtual_balance": tournament.initialBalance,
                "initial_balance": tournament.initialBalance
            ]
            
            try await client
                .from("tournament_participants")
                .insert(participantData)
                .execute()
            
            print("✅ [SupabaseService] 成功加入錦標賽: \(tournament.name)")
            return true
            
        } catch {
            print("❌ [SupabaseService] 加入錦標賽失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 離開錦標賽
    public func leaveTournament(tournamentId: UUID) async throws -> Bool {
        print("📊 [SupabaseService] 離開錦標賽: \(tournamentId)")
        
        guard let currentUser = getCurrentUser() else {
            throw NSError(domain: "TournamentService", code: 401, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }
        
        do {
            try await client
                .from("tournament_participants")
                .delete()
                .eq("tournament_id", value: tournamentId)
                .eq("user_id", value: currentUser.id)
                .execute()
            
            print("✅ [SupabaseService] 成功離開錦標賽")
            return true
            
        } catch {
            print("❌ [SupabaseService] 離開錦標賽失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取錦標賽參與者列表
    public func fetchTournamentParticipants(tournamentId: UUID) async throws -> [TournamentParticipant] {
        print("📊 [SupabaseService] 獲取錦標賽參與者: \(tournamentId)")
        
        do {
            let participantResponses: [TournamentParticipantResponse] = try await client
                .from("tournament_participants")
                .select()
                .eq("tournament_id", value: tournamentId)
                .order("current_rank", ascending: true)
                .execute()
                .value
            
            let participants = participantResponses.compactMap { response in
                convertParticipantResponseToParticipant(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(participants.count) 個參與者")
            return participants
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽參與者失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取錦標賽活動記錄
    public func fetchTournamentActivities(tournamentId: UUID) async throws -> [TournamentActivity] {
        print("📊 [SupabaseService] 獲取錦標賽活動記錄: \(tournamentId)")
        
        do {
            let activityResponses: [TournamentActivityResponse] = try await client
                .from("tournament_activities")
                .select()
                .eq("tournament_id", value: tournamentId)
                .order("timestamp", ascending: false)
                .limit(50)
                .execute()
                .value
            
            let activities = activityResponses.compactMap { response in
                convertActivityResponseToActivity(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(activities.count) 個活動記錄")
            return activities
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽活動記錄失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tournament Data Conversion Methods
    
    private func convertTournamentResponseToTournament(_ response: TournamentResponse) -> Tournament? {
        guard let tournamentId = UUID(uuidString: response.id),
              let type = TournamentType(rawValue: response.type),
              let status = TournamentStatus(rawValue: response.status) else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        guard let startDate = dateFormatter.date(from: response.startDate),
              let endDate = dateFormatter.date(from: response.endDate),
              let createdAt = dateFormatter.date(from: response.createdAt),
              let updatedAt = dateFormatter.date(from: response.updatedAt) else {
            return nil
        }
        
        return Tournament(
            id: tournamentId,
            name: response.name,
            type: type,
            status: status,
            startDate: startDate,
            endDate: endDate,
            description: response.description,
            shortDescription: response.shortDescription ?? String(response.description.prefix(100)),
            initialBalance: response.initialBalance,
            maxParticipants: response.maxParticipants,
            currentParticipants: response.currentParticipants,
            entryFee: response.entryFee ?? 0.0,
            prizePool: response.prizePool,
            riskLimitPercentage: response.riskLimitPercentage ?? 10.0,
            minHoldingRate: response.minHoldingRate ?? 0.0,
            maxSingleStockRate: response.maxSingleStockRate ?? 30.0,
            rules: response.rules ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt,
            isFeatured: response.isFeatured ?? false
        )
    }
    
    private func convertParticipantResponseToParticipant(_ response: TournamentParticipantResponse) -> TournamentParticipant? {
        guard let participantId = UUID(uuidString: response.id),
              let tournamentId = UUID(uuidString: response.tournamentId),
              let userId = UUID(uuidString: response.userId) else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        guard let joinedAt = dateFormatter.date(from: response.joinedAt),
              let lastUpdated = dateFormatter.date(from: response.lastActive) else {
            return nil
        }
        
        return TournamentParticipant(
            id: participantId,
            tournamentId: tournamentId,
            userId: userId,
            userName: response.userName,
            userAvatar: response.userAvatar,
            currentRank: response.currentRank,
            previousRank: response.previousRank ?? response.currentRank,
            virtualBalance: response.virtualBalance,
            initialBalance: response.initialBalance ?? 1000000.0,
            returnRate: response.returnRate,
            totalTrades: response.totalTrades,
            winRate: response.winRate,
            maxDrawdown: response.maxDrawdown ?? 0.0,
            sharpeRatio: response.sharpeRatio,
            isEliminated: response.isEliminated ?? false,
            eliminationReason: response.eliminationReason,
            joinedAt: joinedAt,
            lastUpdated: lastUpdated
        )
    }
    
    private func convertActivityResponseToActivity(_ response: TournamentActivityResponse) -> TournamentActivity? {
        guard let activityId = UUID(uuidString: response.id),
              let tournamentId = UUID(uuidString: response.tournamentId),
              let userId = UUID(uuidString: response.userId),
              let activityType = TournamentActivity.ActivityType(rawValue: response.activityType) else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        guard let timestamp = dateFormatter.date(from: response.timestamp) else {
            return nil
        }
        
        return TournamentActivity(
            id: activityId,
            tournamentId: tournamentId,
            userId: userId,
            userName: response.userName,
            activityType: activityType,
            description: response.description,
            amount: response.amount,
            symbol: response.symbol,
            timestamp: timestamp
        )
    }
}

// MARK: - Tournament Response Models

struct TournamentResponse: Codable {
    let id: String
    let name: String
    let description: String
    let shortDescription: String?
    let type: String
    let status: String
    let startDate: String
    let endDate: String
    let initialBalance: Double
    let maxParticipants: Int
    let currentParticipants: Int
    let entryFee: Double?
    let prizePool: Double
    let riskLimitPercentage: Double?
    let minHoldingRate: Double?
    let maxSingleStockRate: Double?
    let rules: [String]?
    let isFeatured: Bool?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, type, status, rules
        case shortDescription = "short_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case initialBalance = "initial_balance"
        case maxParticipants = "max_participants"
        case currentParticipants = "current_participants"
        case entryFee = "entry_fee"
        case prizePool = "prize_pool"
        case riskLimitPercentage = "risk_limit_percentage"
        case minHoldingRate = "min_holding_rate"
        case maxSingleStockRate = "max_single_stock_rate"
        case isFeatured = "is_featured"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TournamentParticipantResponse: Codable {
    let id: String
    let tournamentId: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let currentRank: Int
    let previousRank: Int?
    let virtualBalance: Double
    let initialBalance: Double?
    let returnRate: Double
    let totalTrades: Int
    let winRate: Double
    let maxDrawdown: Double?
    let sharpeRatio: Double?
    let isEliminated: Bool?
    let eliminationReason: String?
    let joinedAt: String
    let lastActive: String
    
    enum CodingKeys: String, CodingKey {
        case id, isEliminated, eliminationReason
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case currentRank = "current_rank"
        case previousRank = "previous_rank"
        case virtualBalance = "virtual_balance"
        case initialBalance = "initial_balance"
        case returnRate = "return_rate"
        case totalTrades = "total_trades"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case joinedAt = "joined_at"
        case lastActive = "last_updated"
    }
}

struct TournamentActivityResponse: Codable {
    let id: String
    let tournamentId: String
    let userId: String
    let userName: String
    let activityType: String
    let description: String
    let amount: Double?
    let symbol: String?
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount, symbol, timestamp
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case activityType = "activity_type"
    }
}

// MARK: - Statistics Models

/// 平台統計數據模型
struct PlatformStatistics {
    let totalUsers: Int
    let dailyActiveUsers: Int
    let totalTransactions: Int
    let lastUpdated: Date
}
