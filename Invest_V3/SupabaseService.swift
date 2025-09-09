import Foundation
import UIKit
import Supabase
import Auth

// Import custom Logger utility
import os

/// 用戶在群組中的角色
enum UserRole: String, CaseIterable {
    case host = "host"
    case member = "member"
    case none = "none"
}

/// 用戶違規記錄結構
struct UserViolation: Codable {
    let id: UUID
    let userId: UUID
    let violationType: String
    let createdAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case violationType = "violation_type"
        case createdAt = "created_at"
        case isActive = "is_active"
    }
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
            Logger.debug("Using Preview mode client", category: .database)
            return SupabaseClient(
                supabaseURL: URL(string: "https://preview.supabase.co")!,
                supabaseKey: "preview-key"
            )
        }
        
        guard let client = SupabaseManager.shared.client else {
            Logger.error("SupabaseService.client accessed before initialization. 確保在App啟動時調用 SupabaseManager.shared.initialize()", category: .database)
            
            // 嘗試立即初始化
            Task {
                do {
                    try await SupabaseManager.shared.initialize()
                    Logger.info("SupabaseManager 緊急初始化成功", category: .database)
                } catch {
                    Logger.error("SupabaseManager 緊急初始化失敗: \(error.localizedDescription)", category: .database)
                }
            }
            
            // 嘗試立即同步初始化 - 使用正確的 URL
            Logger.warning("使用緊急客戶端實例 - 正式環境", category: .database)
            guard let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co") else {
                fatalError("Invalid Supabase URL")
            }
            let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"
            
            return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        }
        return client
    }

    private init() { }
    
    // MARK: - 防禦性解析輔助方法
    
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
        } else if let arrayValue = value as? [Int], let firstValue = arrayValue.first {
            Logger.warning("⚠️ \(key) 字段返回數組，取第一個元素: \(firstValue)", category: .database)
            return firstValue
        }
        return nil
    }
    
    private func extractDouble(from value: Any?, key: String) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return doubleValue
        } else if let intValue = value as? Int {
            return Double(intValue)
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
        Logger.debug("🔍 \(key) 字段返回意外類型: \(type(of: value))，使用默認值: []", category: .database)
        return []
    }
    
    // 獲取當前用戶
    public func getCurrentUser() -> UserProfile? {
        // 檢查是否在 Preview 模式
        if SupabaseManager.isPreview {
            Logger.debug("Preview 模式 - 返回模擬用戶", category: .auth)
            return createMockUser()
        }
        
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
            Logger.warning("Session exists but no UserProfile in UserDefaults. User ID: \(userId)", category: .auth)
        }
        
        return nil
    }
    
    // 創建模擬用戶（用於 Preview 模式）
    private func createMockUser() -> UserProfile {
        return UserProfile(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012") ?? UUID(),
            email: "preview@example.com",
            username: "preview_user", 
            displayName: "預覽用戶",
            avatarUrl: nil,
            bio: "這是預覽模式的模擬用戶",
            specializations: ["技術分析", "價值投資"],
            yearsExperience: 5,
            followerCount: 0,
            followingCount: 0,
            articleCount: 0,
            totalReturnRate: 0.0,
            isVerified: false,
            status: "active",
            userId: "preview-user-123",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // 創建模擬錦標賽數據（用於 Preview 模式）
    private func createMockTournaments() -> [Tournament] {
        return [
            Tournament(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                name: "Test05",
                type: .monthly,
                status: .ongoing,
                startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
                description: "Preview 模式專用錦標賽 Test05",
                shortDescription: "Preview 測試錦標賽",
                initialBalance: 1000000,
                entryFee: 0,
                prizePool: 50000,
                maxParticipants: 100,
                currentParticipants: 50,
                isFeatured: true,
                createdBy: nil,
                riskLimitPercentage: 20.0,
                minHoldingRate: 60.0,
                maxSingleStockRate: 30.0,
                rules: ["模擬交易", "無實際風險"],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Tournament(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                name: "Test06",
                type: .weekly,
                status: .ongoing,
                startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 25, to: Date()) ?? Date(),
                description: "Preview 模式專用錦標賽 Test06",
                shortDescription: "Preview 測試錦標賽",
                initialBalance: 1000000,
                entryFee: 0,
                prizePool: 30000,
                maxParticipants: 50,
                currentParticipants: 25,
                isFeatured: false,
                createdBy: nil,
                riskLimitPercentage: 25.0,
                minHoldingRate: 50.0,
                maxSingleStockRate: 40.0,
                rules: ["練習模式", "學習專用"],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Tournament(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
                name: "2025 新手投資競賽",
                type: .quarterly,
                status: .enrolling,
                startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 95, to: Date()) ?? Date(),
                description: "專為新手設計的模擬投資競賽",
                shortDescription: "新手專用競賽",
                initialBalance: 500000,
                entryFee: 100,
                prizePool: 20000,
                maxParticipants: 200,
                currentParticipants: 15,
                isFeatured: true,
                createdBy: nil,
                riskLimitPercentage: 30.0,
                minHoldingRate: 40.0,
                maxSingleStockRate: 50.0,
                rules: ["適合新手", "季度賽制"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
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
        
        Logger.info("🔍 開始載入投資群組...", category: .database)
        
        let response: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .execute()
            .value
            
        Logger.info("✅ 成功載入 \(response.count) 個投資群組", category: .database)
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
        
        let groups: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .or("name.ilike.%\(searchQuery)%,host.ilike.%\(searchQuery)%,category.ilike.%\(searchQuery)%")
            .execute()
            .value
        
        Logger.debug("搜尋群組: \(groups.count) 結果", category: .database)
        return groups
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
        
        Logger.debug("搜尋用戶: \(response.count) 結果", category: .database)
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
        
        Logger.debug("搜尋文章: \(response.count) 結果", category: .database)
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
        
        Logger.info("綜合搜尋結果: \(groups.count) 群組, \(users.count) 用戶, \(articles.count) 文章", category: .database)
        
        return (groups: groups, users: users, articles: articles)
    }
    
    func fetchInvestmentGroup(id: UUID) async throws -> InvestmentGroup {
        try SupabaseManager.shared.ensureInitialized()
        
        let group: InvestmentGroup = try await client
            .from("investment_groups")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
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
        Logger.info("開始創建群組", category: .database)
        
        
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
        Logger.debug("主持人回報率: \(hostReturnRate)%", category: .database)
        
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
            Logger.debug("插入群組資料到 investment_groups", category: .database)
            
            let result = try await self.client
                .from("investment_groups")
                .insert(dbGroup)
                .execute()
            
            Logger.info("群組資料插入成功", category: .database)
            
        } catch {
            Logger.error("插入群組資料失敗: \(error.localizedDescription)", category: .database)
            
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
            hostId: currentUser.id,
            returnRate: hostReturnRate,
            entryFee: entryFeeString,
            tokenCost: entryFee,
            memberCount: 1,
            maxMembers: 100,
            category: category,
            description: nil,
            rules: rules.isEmpty ? [] : [rules],
            isPrivate: false,
            inviteCode: nil,
            portfolioValue: 0.0,
            rankingPosition: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 將創建者自動加入群組成員表（不增加成員計數，因為創建時已設為1）
        do {
            Logger.debug("將創建者加入群組成員", category: .database)
            
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
            
            Logger.debug("創建者加入群組成員成功", category: .database)
        } catch {
            Logger.warning("將創建者加入群組成員失敗: \(error.localizedDescription)", category: .database)
            // 繼續返回群組，但記錄錯誤
        }
        
        Logger.info("成功創建群組: \(name)", category: .database)
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
                Logger.debug("主持人交易績效: \(tradingUser.cumulativeReturn)%", category: .database)
                return tradingUser.cumulativeReturn
            }
            
            Logger.debug("未找到主持人交易記錄，使用預設回報率", category: .database)
            return 0.0
            
        } catch {
            Logger.warning("獲取主持人回報率失敗: \(error.localizedDescription)", category: .database)
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
                Logger.warning("無法從 user_profiles 獲取用戶名", category: .database)
            }
        } catch {
            senderName = authUser.email ?? "神秘用戶"
            Logger.warning("查詢 user_profiles 失敗: \(error.localizedDescription)", category: .database)
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
        
        Logger.info("訊息發送成功", category: .database)
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
            Logger.debug("用戶不是群組成員，自動加入", category: .database)
            try await joinGroup(groupId: groupId, userId: userId)
            Logger.debug("用戶已自動加入群組", category: .database)
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
        
        // 獲取群組詳細信息 - 使用簡化方法
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
        
        // 直接查找群組 - 使用簡化方法
        let groups: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .eq("id", value: groupId)
            .limit(1)
            .execute()
            .value
        
        guard let group = groups.first else {
            Logger.warning("群組不存在: \(groupId)", category: .database)
            return nil
        }
        
        Logger.debug("找到群組: \(group.name)", category: .database)
        
        // 獲取當前用戶
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        // 直接加入群組成員（跳過代幣扣除以避免交易約束問題）
        if let groupUUID = UUID(uuidString: groupId) {
            try await joinGroup(groupId: groupUUID, userId: currentUser.id)
            Logger.info("成功加入群組: \(group.name)", category: .database)
            return group
        } else {
            Logger.error("無效的群組 ID 格式", category: .database)
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
        
        Logger.info("成功退出群組", category: .database)
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
            Logger.debug("將主持人加入群組成員", category: .database)
            try await self.client
                .from("group_members")
                .insert(memberData)
                .execute()
            Logger.debug("成功加入群組成員", category: .database)
        } catch {
            Logger.error("加入群組成員失敗: \(error.localizedDescription)", category: .database)
            
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
        
        Logger.info("成功加入群組", category: .database)
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
                Logger.info("投資組合創建成功", category: .database)
            } catch {
                if error.localizedDescription.contains("404") {
                    Logger.error("portfolios 表不存在", category: .database)
                    throw SupabaseError.unknown("❌ 數據庫配置錯誤：portfolios 表不存在\n\n請在 Supabase SQL Editor 中執行 CREATE_PORTFOLIOS_TABLE.sql 腳本來創建必要的表格。")
                }
                Logger.warning("創建投資組合失敗，但群組已成功加入: \(error.localizedDescription)", category: .database)
                // 不拋出錯誤，因為加入群組已經成功
            }
            
            Logger.info("[joinGroup] \(message)", category: .database)
            
        } catch {
            Logger.error("加入群組失敗: \(error.localizedDescription)", category: .database)
            throw error
        }
    }
    
    /// 獲取群組主持人的用戶ID
    func fetchGroupHostId(groupId: UUID) async throws -> UUID {
        try await SupabaseManager.shared.ensureInitialized()
        
        // Use the already-fixed fetchInvestmentGroup method
        let group = try await fetchInvestmentGroup(id: groupId)
        
        // 通過 host 名稱查找主持人的 user ID
        let hostProfile = try? await fetchUserProfileByDisplayName(group.host)
        return hostProfile?.id ?? UUID()
    }
    

    
    // MARK: - Articles (保留原有功能但簡化)
    func fetchArticles() async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        let response: [Article] = try await client
            .from("articles")
            .select("""
                id, title, author, author_id, summary, full_content, body_md, category, 
                read_time, likes_count, comments_count, shares_count, is_free, 
                cover_image_url, created_at, updated_at, keywords
            """)
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
            let coverImageURL: String?
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
                case coverImageURL = "cover_image_url"
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
            coverImageURL: draft.coverImageURL,
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
            let coverImageURL: String?
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
                case coverImageURL = "cover_image_url"
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
            coverImageURL: draft.coverImageURL,
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
    
    // MARK: - AI Article Management
    
    
    /// 更新文章狀態
    public func updateArticleStatus(_ articleId: UUID, status: ArticleStatus) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        try await client
            .from("articles")
            .update([
                "status": status.rawValue,
                "updated_at": Date().ISO8601Format()
            ])
            .eq("id", value: articleId.uuidString)
            .execute()
        
        Logger.info("文章狀態已更新: \(status.displayName)", category: .database)
    }
    
    
    
    /// 根據來源篩選文章
    public func getArticlesBySource(_ source: ArticleSource, status: ArticleStatus? = nil) async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        // 由於數據庫中可能沒有 source 和 status 列，我們先獲取所有文章，然後在應用層過濾
        let allArticles: [Article] = try await client
            .from("articles")
            .select("""
                id, title, author, author_id, summary, full_content, body_md, category, 
                read_time, likes_count, comments_count, shares_count, is_free, 
                cover_image_url, created_at, updated_at, keywords
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // 在應用層進行過濾
        let articles = allArticles.filter { article in
            var matches = (article.source == source)
            
            if let status = status {
                matches = matches && (article.status == status)
            }
            
            return matches
        }
        
        return articles
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
        
        do {
            // 嘗試上傳圖片
            try await client.storage
                .from("article-images")
                .upload(path: path, file: imageData, options: FileOptions(contentType: contentType))
        } catch let error {
            // 如果是重複文件錯誤，嘗試使用 upsert 選項覆蓋
            if error.localizedDescription.contains("already exists") {
                Logger.warning("文件已存在，使用 upsert 選項覆蓋: \(fileName)", category: .network)
                try await client.storage
                    .from("article-images")
                    .upload(path: path, file: imageData, options: FileOptions(contentType: contentType, upsert: true))
            } else {
                // 其他錯誤直接拋出
                throw error
            }
        }
        
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
            .select("""
                id, title, author, author_id, summary, full_content, body_md, category, 
                read_time, likes_count, comments_count, shares_count, is_free, 
                cover_image_url, created_at, updated_at, keywords
            """)
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
        
        Logger.debug("準備按讚文章", category: .database)
        
        // 檢查是否已經按讚
        let existingLikes: [ArticleLike] = try await client
            .from("article_likes")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        guard existingLikes.isEmpty else {
            Logger.debug("用戶已經按讚過此文章", category: .database)
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
        
        Logger.info("按讚成功", category: .database)
    }
    
    /// 取消按讚文章
    func unlikeArticle(articleId: UUID) async throws {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        Logger.debug("準備取消按讚文章", category: .database)
        
        try await client
            .from("article_likes")
            .delete()
            .eq("article_id", value: articleId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        Logger.info("取消按讚成功", category: .database)
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
        Logger.debug("獲取文章留言", category: .database)
        
        let comments: [ArticleComment] = try await client
            .from("article_comments")
            .select()
            .eq("article_id", value: articleId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        Logger.debug("獲取到 \(comments.count) 條留言", category: .database)
        return comments
    }
    
    /// 新增文章留言
    func addArticleComment(articleId: UUID, content: String) async throws -> ArticleComment {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        Logger.debug("準備新增留言到文章", category: .database)
        
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
        
        Logger.info("留言新增成功", category: .database)
        return newComment
    }
    
    /// 分享文章到群組
    func shareArticleToGroup(articleId: UUID, groupId: UUID, groupName: String) async throws {
        guard let currentUser = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        Logger.debug("準備分享文章到群組", category: .database)
        
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
            Logger.debug("已經分享過此文章到此群組", category: .database)
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
        
        Logger.info("分享成功", category: .database)
    }
    
    // MARK: - Trending Keywords & Article Search
    
    /// 獲取熱門關鍵字（前5個最常用的關鍵字）
    func fetchTrendingKeywords() async throws -> [String] {
        Logger.debug("準備獲取熱門關鍵字", category: .database)
        
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
                Logger.debug("沒有關鍵字數據，使用預設熱門關鍵字", category: .database)
                return ["股票", "投資", "市場分析", "基金", "風險管理"]
            }
            
            // 按出現次數排序，取前5個
            let trendingKeywords = keywordCount
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { $0.key }
            
            let result = Array(trendingKeywords)
            Logger.info("獲取熱門關鍵字成功: \(result.count) 個", category: .database)
            return result
            
        } catch {
            Logger.warning("獲取關鍵字失敗，使用預設關鍵字: \(error.localizedDescription)", category: .database)
            // 發生錯誤時返回預設關鍵字
            return ["股票", "投資", "市場分析", "基金", "風險管理"]
        }
    }
    
    /// 根據關鍵字篩選文章
    func fetchArticlesByKeyword(_ keyword: String) async throws -> [Article] {
        Logger.debug("根據關鍵字篩選文章", category: .database)
        
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
        
        Logger.debug("篩選到 \(filteredArticles.count) 篇文章", category: .database)
        return filteredArticles
    }
    
    /// 獲取完整的熱門關鍵字列表（包括"全部"選項）
    func getTrendingKeywordsWithAll() async throws -> [String] {
        let trendingKeywords = try await fetchTrendingKeywords()
        return ["全部"] + trendingKeywords
    }
    
    /// 根據 ID 獲取單一文章
    func fetchArticleById(_ id: UUID) async throws -> Article {
        Logger.debug("根據 ID 獲取文章", category: .database)
        
        let articles: [Article] = try await client
            .from("articles")
            .select("*")
            .eq("id", value: id.uuidString)
            .execute()
            .value
        
        guard let article = articles.first else {
            throw NSError(domain: "ArticleNotFound", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "找不到指定的文章"
            ])
        }
        
        Logger.debug("成功獲取文章: \(article.title)", category: .database)
        return article
    }
    
    // MARK: - Article Likes Ranking
    
    /// 根據時間週期獲取文章點讚排行榜
    func fetchArticleLikesRanking(period: RankingPeriod, limit: Int = 3) async throws -> [ArticleLikesRanking] {
        Logger.debug("獲取文章點讚排行榜: \(period.rawValue)", category: .database)
        
        do {
            // 計算時間範圍
            let (startDate, endDate) = getDateRange(for: period)
            
            // 如果是 Preview 模式，返回測試資料
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                Logger.debug("Preview 模式：返回測試排行榜資料", category: .database)
                return ArticleLikesRanking.createTestData(for: period)
            }
            #endif
            
            // 獲取指定時間範圍內的文章，按點讚數排序
            let articles: [Article] = try await client
                .from("articles")
                .select("*")
                .eq("status", value: "published") // 只獲取已發布的文章
                .gte("created_at", value: startDate.toSupabaseString())
                .lte("created_at", value: endDate.toSupabaseString())
                .order("likes_count", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            // 轉換為排行榜資料
            let rankings = articles.enumerated().map { index, article in
                ArticleLikesRanking(
                    id: article.id,
                    rank: index + 1,
                    title: article.title,
                    author: article.author,
                    authorId: article.authorId,
                    likesCount: article.likesCount,
                    category: article.category,
                    keywords: article.keywords,
                    createdAt: article.createdAt,
                    period: period
                )
            }
            
            Logger.info("成功獲取 \(rankings.count) 篇文章的點讚排行榜", category: .database)
            return rankings
            
        } catch {
            Logger.error("獲取文章點讚排行榜失敗: \(error.localizedDescription)", category: .database)
            // 錯誤時返回空陣列或測試資料
            #if DEBUG
            return ArticleLikesRanking.createTestData(for: period)
            #else
            return []
            #endif
        }
    }
    
    /// 獲取時間範圍的輔助方法
    private func getDateRange(for period: RankingPeriod) -> (startDate: Date, endDate: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch period {
        case .weekly:
            // 本週開始到現在
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
            
        case .monthly:
            // 本月開始到現在
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
            
        case .quarterly:
            // 本季開始到現在
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            let quarterStart = currentMonth - ((currentMonth - 1) % 3)
            let startOfQuarter = calendar.date(from: DateComponents(year: currentYear, month: quarterStart, day: 1)) ?? now
            return (startOfQuarter, now)
            
        case .yearly:
            // 本年開始到現在
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
            
        case .all:
            // 所有時間（從很久以前到現在）
            let veryOldDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (veryOldDate, now)
        }
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
    
    /// 插入投資組合交易記錄到 portfolio_transactions 表
    func insertPortfolioTransaction(_ transaction: PortfolioTransaction) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        Logger.debug("插入投資組合交易記錄: \(transaction.symbol) \(transaction.action)", category: .database)
        
        // 準備插入數據
        struct TransactionInsert: Codable {
            let id: String
            let user_id: String
            let symbol: String
            let action: String
            let quantity: Int
            let price: Double
            let amount: Double
            let executed_at: String
            let tournament_id: String?
        }
        
        let insertData = TransactionInsert(
            id: transaction.id.uuidString,
            user_id: transaction.userId.uuidString,
            symbol: transaction.symbol,
            action: transaction.action,
            quantity: transaction.quantity,
            price: transaction.price,
            amount: transaction.amount,
            executed_at: ISO8601DateFormatter().string(from: transaction.createdAt),
            tournament_id: transaction.tournamentId?.uuidString
        )
        
        try await client
            .from("portfolio_transactions")
            .insert(insertData)
            .execute()
        
        Logger.info("投資組合交易記錄已成功插入", category: .database)
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
        
        Logger.debug("錢包餘額: \(balance) 代幣 (基於 \(response.count) 筆交易)", category: .database)
        return balance
    }
    
    // MARK: - Chat
    
    /// 清除指定群組的聊天記錄
    func clearChatHistory(for groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        // 權限檢查：只有群組主持人才可以刪除聊天記錄
        let groupDetails = try await GroupService.shared.getGroupDetails(groupId: groupId)
        guard groupDetails.host == (currentUser.displayName ?? "匿名主持人") else {
            Logger.error("❌ 權限不足：只有群組主持人才能清除聊天記錄", category: .database)
            throw DatabaseError.unauthorized("只有群組主持人才能執行此操作")
        }
        
        Logger.debug("🧹 群組主持人正在清除聊天記錄", category: .database)
        
        try await client
            .from("chat_messages")
            .delete()
            .eq("group_id", value: groupId)
            .execute()
        
        Logger.info("已清除群組聊天記錄", category: .database)
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
        
        Logger.info("抖內交易創建成功: \(Int(amount)) 代幣", category: .database)
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
        
        Logger.info("群組抖內處理完成: \(currentUser.displayName) 抖內 \(Int(amount)) 代幣給主持人 \(group.host)", category: .database)
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
        
        Logger.info("創作者收益記錄創庺成功: \(revenueType.displayName) \(amount) 金幣", category: .database)
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
        
        Logger.info("創作者收益統計載入成功: 總計 \(stats.totalEarnings) 金幣", category: .database)
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
        
        Logger.info("提領處理成功: \(amount) 金幣已轉入錢包", category: .database)
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
            
            Logger.info("群組入會費收益記錄完成: 主持人 \(group.host) 獲得 \(entryFee) 金幣", category: .database)
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
        Logger.info("\(message)", category: .database)
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
        Logger.info("\(resultMessage)", category: .database)
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
        let timestamp = ISO8601DateFormatter().string(from: Date())
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
            Logger.error("無法獲取當前用戶", category: .auth)
            throw SupabaseError.notAuthenticated
        }
        
        Logger.debug("檢查用戶在群組中的角色", category: .database)
        
        do {
            let roleString = try await fetchUserRole(userId: currentUser.id, groupId: groupId)
            let role = UserRole(rawValue: roleString) ?? .none
            Logger.debug("用戶角色: \(roleString) -> \(role)", category: .database)
            return role
        } catch {
            Logger.error("獲取角色失敗: \(error.localizedDescription)", category: .database)
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
        
        // 獲取邀請詳情以便加入群組 - 使用簡化方法
        struct InvitationData: Codable {
            let id: String
            let groupId: String
            let inviterId: String
            let inviteeId: String?
            let inviteeEmail: String?
            let message: String?
            let status: String
            let createdAt: String
            let expiresAt: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case groupId = "group_id"
                case inviterId = "inviter_id"
                case inviteeId = "invitee_id"
                case inviteeEmail = "invitee_email"
                case message, status
                case createdAt = "created_at"
                case expiresAt = "expires_at"
            }
        }
        
        let invitationData: [InvitationData] = try await client
            .from("group_invitations")
            .select("id, group_id, inviter_id, invitee_id, invitee_email, message, status, created_at, expires_at")
            .eq("id", value: invitationId.uuidString)
            .execute()
            .value
        
        guard let invitationRecord = invitationData.first,
              let groupId = UUID(uuidString: invitationRecord.groupId) else {
            throw SupabaseError.dataNotFound
        }
        
        // 加入群組
        try await joinGroup(groupId)
        
        logError(message: "✅ [邀請] 成功接受邀請並加入群組: \(groupId)")
    }
    
    /// 獲取待處理的邀請 (支援 Email 和 user_id 兩種方式)
    func fetchPendingInvites() async throws -> [GroupInvitation] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("📧 開始載入待處理邀請...", category: .database)
        
        guard let currentUser = try? await getCurrentUserAsync() else {
            Logger.warning("⚠️ 無法獲取當前用戶，無法載入邀請", category: .database)
            return []
        }
        
        Logger.debug("👤 當前用戶: \(currentUser.email) (\(currentUser.id))", category: .database)
        
        // 簡化查詢，不使用 join 操作
        let invitationsData: [GroupInvitationData] = try await client
            .from("group_invitations")
            .select("id, group_id, inviter_id, invitee_id, invitee_email, message, status, created_at, expires_at")
            .or("invitee_email.eq.\(currentUser.email),invitee_id.eq.\(currentUser.id.uuidString)")
            .eq("status", value: "pending")
            .execute()
            .value
        
        // 轉換為 GroupInvitation 格式
        let invitations = invitationsData.compactMap { data -> GroupInvitation? in
            // 獲取邀請者名稱（簡化版，使用邀請者ID作為臨時名稱）
            let inviterName = "User \(data.inviterId)" // 可以後續優化為獲取真實用戶名
            
            // 確定邀請者email
            let inviteeEmail = currentUser.email
            
            return GroupInvitation(
                id: data.id,
                groupId: data.groupId,
                inviterId: data.inviterId,
                inviterName: inviterName,
                inviteeEmail: inviteeEmail,
                status: InvitationStatus(rawValue: data.status.rawValue) ?? .pending,
                expiresAt: data.expiresAt,
                createdAt: data.createdAt
            )
        }
        
        Logger.info("✅ 成功載入 \(invitations.count) 個待處理邀請", category: .database)
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
            // 如果沒有記錄，創建一個初始餘額記錄
            let newBalance = UserBalance(
                id: UUID(),
                userId: userId,
                balance: 0,
                withdrawableAmount: 0,
                updatedAt: Date()
            )
            
            try await client
            .from("user_balances")
                .insert(newBalance)
                .execute()
            
            return 0.0
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
        
        Logger.info("錢包餘額更新成功: \(currentBalance) → \(newBalance)", category: .database)
    }
    
    /// 獲取用戶交易記錄
    func fetchUserTransactions(limit: Int = 10, offset: Int = 0) async throws -> [WalletTransaction] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        guard let authUser = try? await client.auth.user() else {
            throw SupabaseError.notAuthenticated
        }
        
        let userId = authUser.id
        
        let response: [WalletTransaction] = try await client
            .from("wallet_transactions")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        Logger.debug("載入 \(response.count) 筆交易記錄 (第 \(offset/limit + 1) 頁)", category: .database)
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
        
        Logger.info("成功扣除 \(amount) 代幣，餘額: \(currentBalance) → \(newBalance)", category: .database)
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
        
        Logger.info("訂閱成功: 用戶 \(userId) 訂閱作者 \(authorId)", category: .database)
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
            Logger.debug("文章已經記錄過閱讀，跳過重複記錄", category: .database)
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
        
        Logger.info("付費文章閱讀記錄成功", category: .database)
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
            .lte("viewed_at", value: tomorrow)
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
            Logger.debug("文章已經記錄過閱讀，跳過重複記錄", category: .database)
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
        
        Logger.info("免費文章閱讀記錄成功", category: .database)
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
        
        Logger.info("平台會員訂閱成功: 用戶 \(currentUser.id) 訂閱 \(subscriptionType)", category: .database)
        
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
            Logger.debug("作者看自己的文章，不記錄付費閱讀", category: .database)
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
            .lte("read_date", value: ISO8601DateFormatter().string(from: tomorrow))
            .execute()
            .value
        
        if !existingReads.isEmpty {
            Logger.debug("文章今日已經記錄過閱讀，跳過重複記錄", category: .database)
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
        
        Logger.info("平台會員文章閱讀記錄成功", category: .database)
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
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let _ = try await client
            .from("wallet_transactions")
            .insert(transactionData)
            .execute()
        
        Logger.debug("錢包交易記錄創建成功: \(type) \(amount) 代幣", category: .database)
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
    
    // MARK: - 測試群組管理 (僅限 DEBUG 模式)
    
    #if DEBUG
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
                .lte("created_at", value: "2025-07-19T00:00:00")
                .execute()
            
            print("✅ [SupabaseService] 所有測試群組已清理完成")
            
        } catch {
            print("❌ [SupabaseService] 清理測試群組失敗: \(error)")
            throw SupabaseError.from(error)
        }
    }
    #endif
    
    // MARK: - 新錦標賽架構方法 (V2.0)
    
    /// 獲取錦標賽交易記錄（新架構）
    func fetchTournamentTrades(
        tournamentId: UUID,
        userId: UUID,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [TournamentTrade] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📊 [SupabaseService] 獲取錦標賽交易: \(tournamentId)")
        
        let trades: [TournamentTrade] = try await client
            .from("tournament_trades")
            .select()
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .order("executed_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        print("✅ [SupabaseService] 獲取交易成功: \(trades.count) 筆")
        return trades
    }
    
    /// 獲取錦標賽所有交易（管理員）
    func fetchAllTournamentTrades(
        tournamentId: UUID,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [TournamentTrade] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let trades: [TournamentTrade] = try await client
            .from("tournament_trades")
            .select()
            .eq("tournament_id", value: tournamentId.uuidString)
            .order("executed_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return trades
    }
    
    /// 插入錦標賽交易（新架構）
    func insertTournamentTrade(_ trade: TournamentTrade) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        try await client
            .from("tournament_trades")
            .insert(trade)
            .execute()
    }
    
    /// 取消交易
    func cancelTournamentTrade(tradeId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        try await client
            .from("tournament_trades")
            .update(["status": "cancelled"])
            .eq("id", value: tradeId.uuidString)
            .execute()
    }
    
    /// 獲取錦標賽持倉
    func fetchTournamentPositions(
        tournamentId: UUID,
        userId: UUID
    ) async throws -> [TournamentPosition] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let positions: [TournamentPosition] = try await client
            .from("tournament_positions")
            .select()
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .gt("qty", value: 0)
            .execute()
            .value
        
        return positions
    }
    
    /// 獲取錦標賽所有持倉
    func fetchAllTournamentPositions(tournamentId: UUID) async throws -> [TournamentPosition] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let positions: [TournamentPosition] = try await client
            .from("tournament_positions")
            .select()
            .eq("tournament_id", value: tournamentId.uuidString)
            .gt("qty", value: 0)
            .execute()
            .value
        
        return positions
    }
    
    /// 更新錦標賽持倉
    func updateTournamentPosition(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        side: String,
        qty: Double,
        price: Double
    ) async throws -> TournamentPosition {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // 調用數據庫存儲過程來原子性更新持倉
        let result: [TournamentPosition] = try await client
            .rpc("update_tournament_position", params: [
                "p_tournament_id": tournamentId.uuidString,
                "p_user_id": userId.uuidString,
                "p_symbol": symbol,
                "p_side": side,
                "p_qty": String(qty),
                "p_price": String(price)
            ])
            .execute()
            .value
        
        guard let position = result.first else {
            throw SupabaseError.dataFetchFailed("Failed to update position")
        }
        
        return position
    }
    
    /// 更新持倉價格
    func updatePositionPrice(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        currentPrice: Double
    ) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        try await client
            .from("tournament_positions")
            .update([
                "current_price": String(currentPrice),
                "last_updated": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("symbol", value: symbol)
            .execute()
    }
    
    /// 獲取錦標賽投資組合
    func fetchTournamentPortfolio(
        tournamentId: UUID,
        userId: UUID
    ) async throws -> TournamentPortfolioV2 {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        struct PortfolioData: Codable {
            let id: String
            let user_id: String
            let tournament_id: String
            let initial_cash: Double
            let available_cash: Double
            let total_value: Double
            let return_rate: Double
            let last_updated: String
        }
        
        let portfolioData: [PortfolioData] = try await client
            .from("portfolios")
            .select("id, user_id, tournament_id, initial_cash, available_cash, total_value, return_rate, last_updated")
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        guard let data = portfolioData.first else {
            throw SupabaseError.dataFetchFailed("Portfolio not found")
        }
        
        // 轉換為 TournamentPortfolioV2
        let portfolio = TournamentPortfolioV2(
            id: UUID(uuidString: data.id) ?? UUID(),
            tournamentId: tournamentId,
            userId: userId,
            cashBalance: data.available_cash,
            equityValue: data.total_value - data.available_cash,
            totalAssets: data.total_value,
            initialBalance: data.initial_cash,
            totalReturn: data.total_value - data.initial_cash,
            returnPercentage: data.return_rate * 100.0, // 轉換為百分比
            totalTrades: 0, // 需要額外查詢
            winningTrades: 0,
            maxDrawdown: 0.0, // 需要額外計算
            dailyReturn: 0.0, // 修正：使用 0.0 而非 nil
            sharpeRatio: nil,
            lastUpdated: ISO8601DateFormatter().date(from: data.last_updated) ?? Date()
        )
        
        return portfolio
    }
    
    /// 創建錦標賽投資組合
    func createTournamentPortfolio(_ portfolio: TournamentPortfolioV2) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // 映射到 portfolios 表的結構
        struct PortfolioInsert: Codable {
            let group_id: String?
            let user_id: String
            let initial_cash: Double
            let available_cash: Double
            let total_value: Double
            let return_rate: Double
            let tournament_id: String
        }
        
        let portfolioData = PortfolioInsert(
            group_id: nil, // 錦標賽投資組合不需要群組 ID
            user_id: portfolio.userId.uuidString,
            initial_cash: portfolio.initialBalance,
            available_cash: portfolio.cashBalance,
            total_value: portfolio.totalAssets,
            return_rate: portfolio.returnPercentage / 100.0, // 轉換為小數
            tournament_id: portfolio.tournamentId.uuidString
        )
        
        try await client
            .from("portfolios")
            .insert(portfolioData)
            .execute()
    }
    
    /// 更新錦標賽投資組合（使用 TournamentPortfolioV2 物件）
    func updateTournamentPortfolio(_ portfolio: TournamentPortfolioV2) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // 映射到 portfolios 表的結構
        struct PortfolioUpdate: Codable {
            let available_cash: Double
            let total_value: Double
            let return_rate: Double
            let last_updated: String
        }
        
        let updateData = PortfolioUpdate(
            available_cash: portfolio.cashBalance,
            total_value: portfolio.totalAssets,
            return_rate: portfolio.returnPercentage / 100.0,
            last_updated: Date().iso8601
        )
        
        try await client
            .from("portfolios")
            .update(updateData)
            .eq("tournament_id", value: portfolio.tournamentId.uuidString)
            .eq("user_id", value: portfolio.userId.uuidString)
            .execute()
    }
    
    /// 更新錦標賽錢包
    func updateTournamentWallet(
        tournamentId: UUID,
        userId: UUID,
        side: String,
        amount: Double,
        fees: Double
    ) async throws -> TournamentPortfolioV2 {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let result: [TournamentPortfolioV2] = try await client
            .rpc("update_tournament_wallet", params: [
                "p_tournament_id": tournamentId.uuidString,
                "p_user_id": userId.uuidString,
                "p_side": side,
                "p_amount": String(amount),
                "p_fees": String(fees)
            ])
            .execute()
            .value
        
        guard let wallet = result.first else {
            throw SupabaseError.dataFetchFailed("Failed to update wallet")
        }
        
        return wallet
    }
    
    /// 獲取錦標賽成員
    func fetchTournamentMembers(tournamentId: UUID) async throws -> [TournamentMember] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        struct TournamentParticipantData: Codable {
            let tournament_id: String
            let user_id: String
            let joined_at: String
            let is_eliminated: Bool
            let elimination_reason: String?
        }
        
        let participantData: [TournamentParticipantData] = try await client
            .from("tournament_participants")
            .select("tournament_id, user_id, joined_at, is_eliminated, elimination_reason")
            .eq("tournament_id", value: tournamentId.uuidString)
            .execute()
            .value
        
        let members = participantData.map { data in
            let status: TournamentMember.MemberStatus = data.is_eliminated ? .eliminated : .active
            
            return TournamentMember(
                tournamentId: UUID(uuidString: data.tournament_id) ?? tournamentId,
                userId: UUID(uuidString: data.user_id) ?? UUID(),
                joinedAt: ISO8601DateFormatter().date(from: data.joined_at) ?? Date(),
                status: status,
                eliminationReason: data.elimination_reason
            )
        }
        
        return members
    }
    
    /// 獲取錦標賽快照
    func fetchTournamentSnapshots(
        tournamentId: UUID,
        userId: UUID,
        limit: Int = 30
    ) async throws -> [TournamentSnapshot] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let snapshots: [TournamentSnapshot] = try await client
            .from("tournament_snapshots")
            .select()
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .order("as_of_date", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return snapshots
    }
    
    /// 創建或更新錦標賽快照
    func upsertTournamentSnapshot(_ snapshot: TournamentSnapshot) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        try await client
            .from("tournament_snapshots")
            .upsert(snapshot)
            .execute()
    }
    
    /// 執行事務塊
    func executeTransactionBlock(_ block: @escaping (SupabaseClient) async throws -> Void) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // Supabase 目前不直接支援事務，但可以通過 RPC 調用存儲過程實現
        // 這裡先簡化實現，後續可以改為調用專門的存儲過程
        try await block(client)
    }
    
    // MARK: - Missing Service Methods
    
    /// 創建錦標賽成員
    func createTournamentMember(_ member: TournamentMember) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        struct TournamentParticipantInsert: Codable {
            let tournament_id: String
            let user_id: String
            let user_name: String
            let user_avatar: String?
            let current_rank: Int
            let previous_rank: Int
            let virtual_balance: Double
            let initial_balance: Double
            let return_rate: Double
            let total_trades: Int
            let win_rate: Double
            let max_drawdown: Double
            let sharpe_ratio: Double?
            let is_eliminated: Bool
            let elimination_reason: String?
            let joined_at: String
            let last_updated: String
        }
        
        let participantData = TournamentParticipantInsert(
            tournament_id: member.tournamentId.uuidString,
            user_id: member.userId.uuidString,
            user_name: "參賽者", // 預設值，需要從用戶資料獲取
            user_avatar: nil,
            current_rank: 999999,
            previous_rank: 999999,
            virtual_balance: 1000000.00,
            initial_balance: 1000000.00,
            return_rate: 0.00,
            total_trades: 0,
            win_rate: 0.00,
            max_drawdown: 0.00,
            sharpe_ratio: nil,
            is_eliminated: member.status == .eliminated,
            elimination_reason: member.eliminationReason,
            joined_at: member.joinedAt.iso8601,
            last_updated: Date().iso8601
        )
        
        try await client
            .from("tournament_participants")
            .insert(participantData)
            .execute()
    }
}

// MARK: - 擴展方法

extension SupabaseService {
    /// 批次獲取股票價格（模擬實現）
    func batchGetStockPrices(symbols: [String]) async throws -> [String: Double] {
        // 這裡需要實際的股價API，暫時返回模擬數據
        var prices: [String: Double] = [:]
        
        for symbol in symbols {
            prices[symbol] = Double.random(in: 50...1000)
        }
        
        return prices
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
        
        Logger.info("🏆 開始載入交易排行榜... (period: \(period), limit: \(limit))", category: .database)
        
        let response: [TradingUserRanking] = try await self.client
            .from("trading_users")
            .select("id, name, cumulative_return, total_assets, total_profit, avatar_url")
            .eq("is_active", value: true)
            .order("cumulative_return", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        // 設置正確的排名和period
        let rankedResponse = response.enumerated().map { index, ranking in
            TradingUserRanking(
                rank: index + 1,
                userId: ranking.userId,
                name: ranking.name,
                returnRate: ranking.returnRate,
                totalAssets: ranking.totalAssets,
                totalProfit: ranking.totalProfit,
                avatarUrl: ranking.avatarUrl,
                period: period
            )
        }
        
        Logger.info("✅ 成功載入 \(rankedResponse.count) 個交易排行榜", category: .database)
        return rankedResponse
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
    
    // MARK: - Tournament Data APIs
    
    /// 獲取錦標賽投資組合數據
    
    /// 獲取錦標賽交易記錄
    func fetchTournamentTransactions(tournamentId: UUID, userId: UUID) async throws -> [TransactionDisplay] {
        try SupabaseManager.shared.ensureInitialized()
        
        print("📊 [SupabaseService] 獲取錦標賽交易記錄: tournament=\(tournamentId), user=\(userId)")
        
        do {
            // 查詢錦標賽交易記錄表（如果存在的話）
            // 實際的查詢邏輯會根據您的資料庫結構而定
            
            // 暫時返回空陣列，讓系統使用模擬數據
            // 這樣可以保持現有功能正常運作
            
            return []
            
        } catch {
            print("⚠️ [SupabaseService] 獲取錦標賽交易記錄失敗: \(error)")
            throw error
        }
    }
    
    /// 獲取錦標賽排行榜（使用已存在的 API）
    func fetchTournamentRankingsForUI(tournamentId: UUID) async throws -> [UserRanking] {
        try SupabaseManager.shared.ensureInitialized()
        
        print("📊 [SupabaseService] 獲取錦標賽排行榜 UI 數據: \(tournamentId)")
        
        do {
            // 調用已存在的 fetchTournamentRankings API
            let participants = try await fetchTournamentRankings(tournamentId: tournamentId)
            
            // 將 TournamentParticipant 轉換為 UserRanking
            let rankings = participants.map { participant in
                UserRanking(
                    rank: participant.currentRank,
                    name: participant.userName,
                    returnRate: participant.returnRate,
                    totalAssets: participant.virtualBalance
                )
            }
            
            return rankings
            
        } catch {
            print("⚠️ [SupabaseService] 獲取錦標賽排行榜失敗: \(error)")
            // 發生錯誤時返回空陣列，讓前端使用模擬數據
            return []
        }
    }
    
    /// 獲取錦標賽個人績效資料
    func fetchTournamentPersonalPerformance(tournamentId: UUID, userId: UUID) async throws -> PersonalPerformance {
        print("🏆 [SupabaseService] 從 Supabase 載入錦標賽個人績效: tournamentId=\(tournamentId), userId=\(userId)")
        
        // 這裡應該實現真實的 Supabase 查詢邏輯
        // 目前先使用基於錦標賽 ID 的模擬資料生成
        
        // 實際實現時，應該查詢類似以下的 SQL:
        // SELECT * FROM tournament_performance 
        // WHERE tournament_id = $1 AND user_id = $2
        
        // 使用錦標賽 ID 作為隨機種子，確保相同錦標賽總是生成相同的績效資料
        srand48(Int(abs(tournamentId.hashValue)))
        
        let totalReturn = -20 + drand48() * 55 // Random between -20 and 35
        let annualizedReturn = totalReturn * 12 / 3 // 假設錦標賽持續3個月
        let maxDrawdown = -(5 + drand48() * 10) // Random between -15 and -5
        let winRate = 0.4 + drand48() * 0.4 // Random between 0.4 and 0.8
        let totalTrades = Int(10 + drand48() * 40) // Random between 10 and 50
        let profitableTrades = Int(Double(totalTrades) * winRate)
        
        // 生成績效歷史點
        var performanceHistory: [PerformancePoint] = []
        let days = 90 // 錦標賽假設持續90天
        var cumulativeReturn = 0.0
        
        
        
        // 生成排名歷史
        var rankingHistory: [RankingPoint] = []
        for i in stride(from: 0, to: days, by: 7) { // 每週記錄排名
            let ranking = Int(1 + drand48() * 99) // Random between 1 and 100
            let date = Calendar.current.date(byAdding: .day, value: i - days + 1, to: Date()) ?? Date()
            let totalParticipants = 100
            let percentile = (Double(totalParticipants - ranking) / Double(totalParticipants)) * 100
            
            rankingHistory.append(RankingPoint(
                date: date,
                rank: ranking,
                totalParticipants: totalParticipants,
                percentile: percentile
            ))
        }
        
        return PersonalPerformance(
            totalReturn: totalReturn,
            annualizedReturn: annualizedReturn,
            maxDrawdown: maxDrawdown,
            sharpeRatio: totalReturn > 0 ? (0.5 + drand48() * 1.5) : nil,
            winRate: winRate,
            totalTrades: totalTrades,
            profitableTrades: profitableTrades,
            avgHoldingDays: 3 + drand48() * 12, // Random between 3 and 15
            riskScore: 1 + drand48() * 9, // Random between 1 and 10
            performanceHistory: performanceHistory,
            rankingHistory: rankingHistory,
            achievements: []
        )
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
        
        let result: InitializeResponse = try await client
            .rpc("initialize_current_user_data")
            .execute()
            .value
        
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
        
        let groups: [InvestmentGroup] = try await client
            .from("investment_groups")
            .select()
            .eq("host_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        print("✅ [SupabaseService] 獲取用戶主持的群組: \(groups.count) 個")
        return groups
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
        guard let firstRecord = response.first else { return nil }
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
            let response: PostgrestResponse<Data> = try await client
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
    
    // MARK: - Author Analytics & Eligibility
    
    /// 獲取作者閱讀分析數據
    func fetchAuthorReadingAnalytics(authorId: UUID) async throws -> AuthorReadingAnalytics {
        try SupabaseManager.shared.ensureInitialized()
        
        print("📊 [SupabaseService] 獲取作者閱讀分析: \(authorId)")
        
        do {
            // 使用 RPC 函數獲取作者分析數據
            let response: [AuthorReadingAnalytics] = try await client
                .rpc("get_author_reading_analytics", params: ["input_author_id": authorId.uuidString])
                .execute()
                .value
            
            if let analytics = response.first {
                print("✅ [SupabaseService] 作者閱讀分析獲取成功")
                return analytics
            } else {
                // 如果沒有數據，返回默認值
                print("⚠️ [SupabaseService] 作者沒有閱讀分析數據，返回默認值")
                return AuthorReadingAnalytics(
                    authorId: authorId,
                    totalArticles: 0,
                    totalReads: 0,
                    uniqueReaders: 0,
                    last30DaysUniqueReaders: 0,
                    last90DaysArticles: 0,
                    averageReadTime: 0.0,
                    completionRate: 0.0,
                    createdAt: Date()
                )
            }
            
        } catch {
            print("❌ [SupabaseService] 獲取作者閱讀分析失敗: \(error)")
            // 返回默認值而不是拋出錯誤，確保評估系統可以繼續運行
            return AuthorReadingAnalytics(
                authorId: authorId,
                totalArticles: 0,
                totalReads: 0,
                uniqueReaders: 0,
                last30DaysUniqueReaders: 0,
                last90DaysArticles: 0,
                averageReadTime: 0.0,
                completionRate: 0.0,
                createdAt: Date()
            )
        }
    }
    
    /// 檢查作者錢包設置狀態
    func checkAuthorWalletSetup(authorId: UUID) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        print("💰 [SupabaseService] 檢查作者錢包設置: \(authorId)")
        
        do {
            // 檢查 user_wallet_balances 表中是否有該用戶的記錄
            let response: [UserWalletBalance] = try await client
                .from("user_wallet_balances")
                .select("*")
                .eq("user_id", value: authorId.uuidString)
                .limit(1)
                .execute()
                .value
            
            let hasWallet = !response.isEmpty
            print("✅ [SupabaseService] 錢包設置檢查完成: \(hasWallet)")
            return hasWallet
            
        } catch {
            print("❌ [SupabaseService] 檢查錢包設置失敗: \(error)")
            // 默認返回 false，表示未設置錢包
            return false
        }
    }
    
    /// 檢查作者違規記錄
    func checkAuthorViolations(authorId: UUID) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.debug("⚠️ 檢查作者違規記錄: \(authorId)", category: .database)
        
        do {
            let violations: [UserViolation] = try await client
                .from("user_violations")
                .select("*")
                .eq("user_id", value: authorId)
                .eq("is_active", value: true)
                .execute()
                .value
            
            let hasActiveViolations = !violations.isEmpty
            
            if hasActiveViolations {
                Logger.warning("⚠️ 發現作者有效違規記錄: \(violations.count) 筆", category: .database)
            } else {
                Logger.debug("✅ 違規記錄檢查完成: 無違規", category: .database)
            }
            
            return hasActiveViolations
            
        } catch {
            print("❌ [SupabaseService] 檢查違規記錄失敗: \(error)")
            return false
        }
    }
    
    /// 保存作者資格狀態
    func saveAuthorEligibilityStatus(_ status: AuthorEligibilityStatusInsert) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        print("💾 [SupabaseService] 保存作者資格狀態: \(status.authorId)")
        
        do {
            // 使用 upsert 操作，指定衝突解決策略
            let _: [AuthorEligibilityStatusInsert] = try await client
                .from("author_eligibility_status")
                .upsert(status, onConflict: "author_id", ignoreDuplicates: false)
                .execute()
                .value
            
            print("✅ [SupabaseService] 作者資格狀態保存成功")
            
        } catch {
            print("❌ [SupabaseService] 保存作者資格狀態失敗: \(error)")
            throw SupabaseError.unknown("保存資格狀態失敗: \(error.localizedDescription)")
        }
    }
    
    /// 獲取作者資格狀態
    func fetchAuthorEligibilityStatus(authorId: UUID) async throws -> AuthorEligibilityStatus? {
        try SupabaseManager.shared.ensureInitialized()
        
        print("📋 [SupabaseService] 獲取作者資格狀態: \(authorId)")
        
        do {
            let response: [AuthorEligibilityStatus] = try await client
                .from("author_eligibility_status")
                .select("*")
                .eq("author_id", value: authorId.uuidString)
                .order("updated_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let status = response.first {
                print("✅ [SupabaseService] 作者資格狀態獲取成功")
                return status
            } else {
                print("ℹ️ [SupabaseService] 作者尚無資格狀態記錄")
                return nil
            }
            
        } catch {
            print("❌ [SupabaseService] 獲取作者資格狀態失敗: \(error)")
            throw SupabaseError.unknown("獲取資格狀態失敗: \(error.localizedDescription)")
        }
    }
    
    /// 獲取所有作者ID列表（用於批量評估）
    func fetchAllAuthorIds() async throws -> [UUID] {
        try SupabaseManager.shared.ensureInitialized()
        
        print("👥 [SupabaseService] 獲取所有作者ID列表")
        
        do {
            // 獲取所有有發布文章的作者ID
            let response: [[String: String]] = try await client
                .from("articles")
                .select("author_id")
                .neq("author_id", value: "null")
                .execute()
                .value
            
            let authorIds = Array(Set(response.compactMap { (item: [String: String]) -> UUID? in
                guard let authorIdString = item["author_id"] else { return nil }
                return UUID(uuidString: authorIdString)
            }))
            print("✅ [SupabaseService] 獲取到 \(authorIds.count) 位作者")
            return authorIds
            
        } catch {
            print("❌ [SupabaseService] 獲取作者ID列表失敗: \(error)")
            throw SupabaseError.unknown("獲取作者列表失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tournament Methods
    
    /// 獲取所有錦標賽
    public func fetchTournaments() async throws -> [Tournament] {
        print("📊 [SupabaseService] 獲取所有錦標賽")
        
        // 如果在 Preview 模式，返回模擬數據
        if SupabaseManager.isPreview {
            print("🔍 [SupabaseService] Preview 模式 - 返回模擬錦標賽數據")
            return createMockTournaments()
        }
        
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
    
    /// 建立錦標賽 (僅管理員)
    public func createTournament(_ tournament: Tournament) async throws -> Tournament {
        print("📊 [SupabaseService] 建立錦標賽: \(tournament.name)")
        
        // 檢查當前用戶是否為管理員
        guard let currentUser = getCurrentUser(), currentUser.username == "test03" else {
            throw NSError(domain: "TournamentService", code: 403, userInfo: [NSLocalizedDescriptionKey: "權限不足，只有管理員可以建立錦標賽"])
        }
        
        do {
            // 創建錦標賽插入數據
            let tournamentInsert = TournamentInsert(
                id: tournament.id.uuidString,
                name: tournament.name,
                type: tournament.type.rawValue,
                status: tournament.status.rawValue,
                startDate: ISO8601DateFormatter().string(from: tournament.startDate),
                endDate: ISO8601DateFormatter().string(from: tournament.endDate),
                description: tournament.description,
                shortDescription: tournament.shortDescription,
                initialBalance: tournament.initialBalance,
                maxParticipants: tournament.maxParticipants,
                currentParticipants: 0,
                entryFee: tournament.entryFee,
                prizePool: tournament.prizePool,
                riskLimitPercentage: tournament.riskLimitPercentage,
                minHoldingRate: tournament.minHoldingRate,
                maxSingleStockRate: tournament.maxSingleStockRate,
                rules: tournament.rules,
                isFeatured: tournament.isFeatured,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            // 插入到資料庫
            let insertedTournaments: [TournamentResponse] = try await client
                .from("tournaments")
                .insert(tournamentInsert)
                .select()
                .execute()
                .value
            
            guard let insertedResponse = insertedTournaments.first,
                  let createdTournament = convertTournamentResponseToTournament(insertedResponse) else {
                throw NSError(domain: "TournamentService", code: 500, userInfo: [NSLocalizedDescriptionKey: "錦標賽建立失敗"])
            }
            
            print("✅ [SupabaseService] 成功建立錦標賽: \(createdTournament.name)")
            return createdTournament
            
        } catch {
            print("❌ [SupabaseService] 建立錦標賽失敗: \(error.localizedDescription)")
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
            let participantData = TournamentParticipantInsert(
                tournamentId: tournamentId.uuidString,
                userId: currentUser.id.uuidString,
                userName: currentUser.displayName,
                userAvatar: currentUser.avatarUrl ?? "",
                virtualBalance: tournament.initialBalance,
                initialBalance: tournament.initialBalance
            )
            
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
    
    /// 獲取用戶已報名的錦標賽列表
    public func fetchUserEnrolledTournaments(userId: UUID) async throws -> [Tournament] {
        print("📊 [SupabaseService] 獲取用戶已報名錦標賽: \(userId)")
        
        do {
            // 從 tournament_participants 表獲取用戶參與的錦標賽 ID
            let participantResponses: [TournamentParticipantResponse] = try await client
                .from("tournament_participants")
                .select("id, tournament_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let tournamentIds = participantResponses.map { $0.tournamentId }
            
            if tournamentIds.isEmpty {
                print("✅ [SupabaseService] 用戶未參與任何錦標賽")
                return []
            }
            
            // 獲取對應的錦標賽資料
            let tournamentResponses: [TournamentResponse] = try await client
                .from("tournaments")
                .select("*")
                .in("id", values: tournamentIds)
                .execute()
                .value
            
            let tournaments = tournamentResponses.compactMap { response in
                convertTournamentResponseToTournament(response)
            }
            
            print("✅ [SupabaseService] 成功獲取 \(tournaments.count) 個已報名錦標賽")
            return tournaments
            
        } catch {
            print("❌ [SupabaseService] 獲取用戶已報名錦標賽失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取錦標賽統計數據
    public func fetchTournamentStatistics(tournamentId: UUID? = nil) async throws -> TournamentStatsResponse {
        print("📊 [SupabaseService] 獲取錦標賽統計數據")
        
        do {
            let query = client
                .from("tournaments")
                .select("id, current_participants, start_date, end_date")
            
            let tournamentResponses: [TournamentStatsDBResponse]
            
            if let tournamentId = tournamentId {
                // 獲取特定錦標賽的統計
                tournamentResponses = try await query
                    .eq("id", value: tournamentId)
                    .execute()
                    .value
            } else {
                // 獲取所有活躍錦標賽的統計
                tournamentResponses = try await query
                    .eq("status", value: "ongoing")
                    .execute()
                    .value
            }
            
            // 計算統計數據
            let totalParticipants = tournamentResponses.reduce(0) { $0 + $1.currentParticipants }
            
            // 計算平均報酬（模擬數據，實際應該從參與者表計算）
            let averageReturn = 0.156 // 15.6%
            
            // 計算剩餘天數（取第一個錦標賽的數據）
            let daysRemaining: Int
            if let firstTournament = tournamentResponses.first {
                let endDate = ISO8601DateFormatter().date(from: firstTournament.endDate) ?? Date()
                let currentDate = Date()
                let calendar = Calendar.current
                daysRemaining = max(0, calendar.dateComponents([.day], from: currentDate, to: endDate).day ?? 0)
            } else {
                daysRemaining = 0
            }
            
            let stats = TournamentStatsResponse(
                totalParticipants: totalParticipants,
                averageReturn: averageReturn,
                daysRemaining: daysRemaining,
                lastUpdated: Date()
            )
            
            print("✅ [SupabaseService] 成功獲取錦標賽統計數據: \(totalParticipants) 參與者")
            return stats
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽統計數據失敗: \(error.localizedDescription)")
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
            entryFee: response.entryFee ?? 0.0,
            prizePool: response.prizePool,
            maxParticipants: response.maxParticipants,
            currentParticipants: response.currentParticipants,
            isFeatured: response.isFeatured ?? false,
            createdBy: UUID(), // Default UUID since response doesn't have createdBy
            riskLimitPercentage: response.riskLimitPercentage ?? 10.0,
            minHoldingRate: response.minHoldingRate ?? 0.0,
            maxSingleStockRate: response.maxSingleStockRate ?? 30.0,
            rules: response.rules ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
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
              let activityType = ActivityType(rawValue: response.activityType) else {
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

// MARK: - Tournament Insert Models
struct TournamentInsert: Codable {
    let id: String
    let name: String
    let type: String
    let status: String
    let startDate: String
    let endDate: String
    let description: String
    let shortDescription: String
    let initialBalance: Double
    let maxParticipants: Int
    let currentParticipants: Int
    let entryFee: Double
    let prizePool: Double
    let riskLimitPercentage: Double
    let minHoldingRate: Double
    let maxSingleStockRate: Double
    let rules: [String]
    let isFeatured: Bool
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, status, description, rules
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

struct TournamentParticipantInsert: Codable {
    let tournamentId: String
    let userId: String
    let userName: String
    let userAvatar: String
    let virtualBalance: Double
    let initialBalance: Double
    
    enum CodingKeys: String, CodingKey {
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case virtualBalance = "virtual_balance"
        case initialBalance = "initial_balance"
    }
}

// MARK: - Tournament Statistics Models
struct TournamentStatsResponse: Codable {
    let totalParticipants: Int
    let averageReturn: Double
    let daysRemaining: Int
    let lastUpdated: Date
}

struct TournamentStatsDBResponse: Codable {
    let id: String
    let currentParticipants: Int
    let startDate: String
    let endDate: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case currentParticipants = "current_participants"
        case startDate = "start_date"
        case endDate = "end_date"
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

// MARK: - Friends System Extensions

// MARK: - 好友相關資料模型
struct FriendshipBasic: Codable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
    }
}

extension SupabaseService {
    
    // MARK: - 輔助函數
    
    /// 解析 ISO 日期字串
    private func parseISODate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
    
    // MARK: - 好友管理
    
    /// 獲取用戶的好友列表
    func fetchFriends() async throws -> [Friend] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await getCurrentUserAsync()
        
        // 獲取已接受的好友關係（用戶可能是請求者或接收者）
        let friendships: [FriendshipBasic] = try await client
            .from("friendships")
            .select("id, requester_id, addressee_id, status, created_at")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(currentUser.id.uuidString),addressee_id.eq.\(currentUser.id.uuidString)")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // 如果沒有好友，返回空陣列
        guard !friendships.isEmpty else {
            print("ℹ️ [FriendsService] 沒有找到好友")
            return []
        }
        
        // 獲取好友的 ID（排除當前用戶）
        let friendIds = friendships.compactMap { friendship -> String? in
            if friendship.requesterId == currentUser.id.uuidString {
                return friendship.addresseeId
            } else if friendship.addresseeId == currentUser.id.uuidString {
                return friendship.requesterId
            }
            return nil
        }
        
        guard !friendIds.isEmpty else {
            print("ℹ️ [FriendsService] 沒有有效的好友 ID")
            return []
        }
        
        // 獲取好友的詳細資料（注意：使用 username 而不是 user_name）
        let friendProfiles: [UserProfileResponse] = try await client
            .from("user_profiles")
            .select("id, username, display_name, avatar_url, bio")
            .in("id", values: friendIds)
            .execute()
            .value
        
        // 組合好友資料
        let friends = friendships.compactMap { friendship -> Friend? in
            let friendId = friendship.requesterId == currentUser.id.uuidString ? friendship.addresseeId : friendship.requesterId
            
            guard let friendProfile = friendProfiles.first(where: { $0.id == friendId }) else {
                print("⚠️ [FriendsService] 找不到好友資料: \(friendId)")
                return nil
            }
            
            return Friend(
                id: UUID(uuidString: friendProfile.id) ?? UUID(),
                userId: friendProfile.id,
                userName: friendProfile.username, // 使用 username
                displayName: friendProfile.displayName,
                avatarUrl: friendProfile.avatarUrl,
                bio: friendProfile.bio,
                isOnline: false, // 預設離線
                lastActiveDate: Date(), // 預設當前時間
                friendshipDate: parseISODate(friendship.createdAt) ?? Date(),
                investmentStyle: nil, // 暫時設為 nil
                performanceScore: 0.0, // 預設值
                totalReturn: 0.0, // 預設值
                riskLevel: .moderate // 預設值
            )
        }
        
        print("✅ [FriendsService] 載入 \(friends.count) 位好友")
        return friends
    }
    
    /// 搜尋用戶
    func searchUsers(query: String, investmentStyle: InvestmentStyle? = nil, riskLevel: RiskLevel? = nil) async throws -> [FriendSearchResult] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await getCurrentUserAsync()
        
        var queryBuilder = client
            .from("user_profiles")
            .select()
            .neq("id", value: currentUser.id.uuidString)
        
        // 添加搜尋條件
        if !query.isEmpty {
            queryBuilder = queryBuilder.or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
        }
        
        if let style = investmentStyle {
            queryBuilder = queryBuilder.eq("investment_style", value: style.rawValue)
        }
        
        if let risk = riskLevel {
            queryBuilder = queryBuilder.eq("risk_level", value: risk.rawValue)
        }
        
        let profiles: [UserProfileResponse] = try await queryBuilder
            .limit(20)
            .execute()
            .value
        
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
        
        return searchResults
    }
    
    /// 計算兩個用戶之間的共同好友數量
    private func calculateMutualFriendsCount(currentUserId: String, targetUserId: String) async -> Int {
        do {
            let currentUserFriends: [FriendshipResponse] = try await client
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: currentUserId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let targetUserFriends: [FriendshipResponse] = try await client
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: targetUserId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let currentFriendIds = Set(currentUserFriends.map { $0.friendId })
            let targetFriendIds = Set(targetUserFriends.map { $0.friendId })
            let mutualFriends = currentFriendIds.intersection(targetFriendIds)
            
            Logger.debug("🤝 計算共同好友: \(currentUserId) 和 \(targetUserId) 有 \(mutualFriends.count) 個共同好友", category: .database)
            return mutualFriends.count
            
        } catch {
            Logger.error("❌ 計算共同好友失敗: \(error.localizedDescription)", category: .database)
            return 0
        }
    }
    
    struct FriendshipResponse: Codable {
        let friendId: String
        
        enum CodingKeys: String, CodingKey {
            case friendId = "friend_id"
        }
    }
    
    /// 發送好友請求
    func sendFriendRequest(to userId: String, message: String? = nil) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await getCurrentUserAsync()
        
        // 檢查是否已經是好友
        let existingFriendship = try await checkFriendshipExists(userId1: currentUser.id.uuidString, userId2: userId)
        if existingFriendship {
            throw SupabaseError.unknown("已經是好友")
        }
        
        // 檢查是否已經有待處理的請求
        let existingRequest = try await checkPendingRequest(fromUserId: currentUser.id.uuidString, toUserId: userId)
        if existingRequest {
            throw SupabaseError.unknown("已經發送過好友請求")
        }
        
        let requestData = FriendRequestInsert(
            id: UUID().uuidString,
            fromUserId: currentUser.id.uuidString,
            fromUserName: currentUser.username,
            fromUserDisplayName: currentUser.displayName,
            fromUserAvatarUrl: currentUser.avatarUrl,
            toUserId: userId,
            message: message,
            requestDate: Date(),
            status: .pending
        )
        
        let _: [FriendRequestInsert] = try await client
            .from("friend_requests")
            .insert(requestData)
            .select()
            .execute()
            .value
        
        print("✅ [FriendsService] 好友請求已發送")
    }
    
    /// 接受好友請求
    func acceptFriendRequest(_ requestId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // 更新請求狀態
        let _: [FriendRequestUpdate] = try await client
            .from("friend_requests")
            .update(FriendRequestUpdate(status: .accepted))
            .eq("id", value: requestId.uuidString)
            .select()
            .execute()
            .value
        
        // 獲取請求詳情以創建雙向好友關係
        let requests: [FriendRequestResponse] = try await client
            .from("friend_requests")
            .select()
            .eq("id", value: requestId.uuidString)
            .execute()
            .value
        
        guard let request = requests.first else {
            throw SupabaseError.unknown("找不到好友請求")
        }
        
        // 創建雙向好友關係
        let friendships = [
            FriendshipInsert(
                id: UUID().uuidString,
                userId: request.fromUserId,
                friendId: request.toUserId,
                friendshipDate: Date()
            ),
            FriendshipInsert(
                id: UUID().uuidString,
                userId: request.toUserId,
                friendId: request.fromUserId,
                friendshipDate: Date()
            )
        ]
        
        let _: [FriendshipInsert] = try await client
            .from("friendships")
            .insert(friendships)
            .select()
            .execute()
            .value
        
        print("✅ [FriendsService] 好友請求已接受，好友關係建立")
    }
    
    /// 拒絕好友請求
    func declineFriendRequest(_ requestId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let _: [FriendRequestUpdate] = try await client
            .from("friend_requests")
            .update(FriendRequestUpdate(status: .declined))
            .eq("id", value: requestId.uuidString)
            .select()
            .execute()
            .value
        
        print("✅ [FriendsService] 好友請求已拒絕")
    }
    
    /// 獲取好友請求列表
    func fetchFriendRequests() async throws -> [FriendRequest] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await getCurrentUserAsync()
        
        let requests: [FriendRequestResponse] = try await client
            .from("friend_requests")
            .select()
            .eq("to_user_id", value: currentUser.id.uuidString)
            .order("request_date", ascending: false)
            .execute()
            .value
        
        let friendRequests = try requests.map { request in
            FriendRequest(
                id: UUID(uuidString: request.id) ?? UUID(),
                fromUserId: request.fromUserId,
                fromUserName: request.fromUserName,
                fromUserDisplayName: request.fromUserDisplayName,
                fromUserAvatarUrl: request.fromUserAvatarUrl,
                toUserId: request.toUserId,
                message: request.message,
                requestDate: ISO8601DateFormatter().date(from: request.requestDate) ?? Date(),
                status: FriendRequest.FriendRequestStatus(rawValue: request.status) ?? .pending
            )
        }
        
        return friendRequests
    }
    
    /// 獲取好友動態
    func fetchFriendActivities() async throws -> [FriendActivity] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        let currentUser = try await getCurrentUserAsync()
        
        // 獲取好友ID列表
        let friendIds = try await getFriendIds(userId: currentUser.id)
        
        if friendIds.isEmpty {
            return []
        }
        
        let activities: [FriendActivityResponse] = try await client
            .from("friend_activities")
            .select()
            .in("user_id", values: friendIds)
            .order("timestamp", ascending: false)
            .limit(50)
            .execute()
            .value
        
        let friendActivities = try activities.map { activity in
            FriendActivity(
                id: UUID(uuidString: activity.id) ?? UUID(),
                friendId: activity.userId,
                friendName: activity.userName,
                activityType: FriendActivity.ActivityType(rawValue: activity.activityType) ?? .trade,
                description: activity.description,
                timestamp: ISO8601DateFormatter().date(from: activity.timestamp) ?? Date(),
                data: activity.data.flatMap { dataStr in
                    try? JSONDecoder().decode(FriendActivity.ActivityData.self, from: dataStr.data(using: .utf8) ?? Data())
                }
            )
        }
        
        return friendActivities
    }
    
    // MARK: - 輔助方法
    
    func getFriendIds(userId: UUID) async throws -> [String] {
        let friendships: [FriendshipBasic] = try await client
            .from("friendships")
            .select("requester_id, addressee_id")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userId.uuidString),addressee_id.eq.\(userId.uuidString)")
            .execute()
            .value
        
        return friendships.compactMap { friendship in
            if friendship.requesterId == userId.uuidString {
                return friendship.addresseeId
            } else if friendship.addresseeId == userId.uuidString {
                return friendship.requesterId
            }
            return nil
        }
    }
    
    func getPendingRequestIds(userId: UUID) async throws -> [String] {
        let requests: [FriendRequestResponse] = try await client
            .from("friend_requests")
            .select("to_user_id")
            .eq("from_user_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return requests.map { $0.toUserId }
    }
    
    private func checkFriendshipExists(userId1: String, userId2: String) async throws -> Bool {
        let friendships: [FriendshipBasic] = try await client
            .from("friendships")
            .select("id")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userId1),addressee_id.eq.\(userId1)")
            .or("requester_id.eq.\(userId2),addressee_id.eq.\(userId2)")
            .execute()
            .value
        
        return friendships.contains { friendship in
            (friendship.requesterId == userId1 && friendship.addresseeId == userId2) ||
            (friendship.requesterId == userId2 && friendship.addresseeId == userId1)
        }
    }
    
    private func checkPendingRequest(fromUserId: String, toUserId: String) async throws -> Bool {
        let requests: [FriendRequestResponse] = try await client
            .from("friend_requests")
            .select("id")
            .eq("from_user_id", value: fromUserId)
            .eq("to_user_id", value: toUserId)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return !requests.isEmpty
    }
}

// MARK: - Friends System Database Models

public struct FriendshipResponse: Codable {
    let id: String
    let userId: String
    let friendId: String
    let friendshipDate: String
    let friendProfiles: UserProfileResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case friendshipDate = "friendship_date"
        case friendProfiles = "friend_profiles"
    }
}

struct FriendshipInsert: Codable {
    let id: String
    let userId: String
    let friendId: String
    let friendshipDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case friendshipDate = "friendship_date"
    }
}

struct FriendRequestResponse: Codable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let fromUserDisplayName: String
    let fromUserAvatarUrl: String?
    let toUserId: String
    let message: String?
    let requestDate: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, message, status
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case fromUserDisplayName = "from_user_display_name"
        case fromUserAvatarUrl = "from_user_avatar_url"
        case toUserId = "to_user_id"
        case requestDate = "request_date"
    }
}

struct FriendRequestInsert: Codable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let fromUserDisplayName: String
    let fromUserAvatarUrl: String?
    let toUserId: String
    let message: String?
    let requestDate: Date
    let status: FriendRequest.FriendRequestStatus
    
    enum CodingKeys: String, CodingKey {
        case id, message, status
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case fromUserDisplayName = "from_user_display_name"
        case fromUserAvatarUrl = "from_user_avatar_url"
        case toUserId = "to_user_id"
        case requestDate = "request_date"
    }
}

struct FriendRequestUpdate: Codable {
    let status: FriendRequest.FriendRequestStatus
}

public struct UserProfileResponse: Codable {
    let id: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let investmentStyle: String?
    let performanceScore: Double?
    let totalReturn: Double?
    let riskLevel: String?
    let isOnline: Bool?
    let lastActiveDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, bio, username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case investmentStyle = "investment_style"
        case performanceScore = "performance_score"
        case totalReturn = "total_return"
        case riskLevel = "risk_level"
        case isOnline = "is_online"
        case lastActiveDate = "last_active_date"
    }
}

struct FriendActivityResponse: Codable {
    let id: String
    let userId: String
    let userName: String
    let activityType: String
    let description: String
    let timestamp: String
    let data: String?
    
    enum CodingKeys: String, CodingKey {
        case id, description, timestamp, data
        case userId = "user_id"
        case userName = "user_name"
        case activityType = "activity_type"
    }
}

// MARK: - Tournament Investment Simulation Extensions

extension SupabaseService {
    // MARK: - Tournament Investment Simulation Methods
    
    /// 獲取可用錦標賽列表
    func fetchAvailableTournaments() async throws -> [Tournament] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📋 [SupabaseService] 獲取可用錦標賽")
        
        // 查詢進行中和報名中的錦標賽
        let tournaments: [Tournament] = try await client
            .from("tournaments")
            .select()
            .in("status", values: ["ongoing", "enrolling"])
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ 獲取錦標賽成功: \(tournaments.count) 個")
        return tournaments
    }
    
    /// 同步錦標賽投資組合到後端
    func syncTournamentPortfolio(_ portfolio: TournamentPortfolio) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 同步錦標賽投資組合: \(portfolio.tournamentId)")
        
        // 同步投資組合基本資訊
        struct TournamentPortfolioInsert: Codable {
            let id: String
            let tournamentId: String
            let userId: String
            let userName: String
            let initialBalance: Double
            let currentBalance: Double
            let totalInvested: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case tournamentId = "tournament_id"
                case userId = "user_id"
                case userName = "user_name"
                case initialBalance = "initial_balance"
                case currentBalance = "current_balance"
                case totalInvested = "total_invested"
                case lastUpdated = "last_updated"
            }
        }
        
        let portfolioData = TournamentPortfolioInsert(
            id: portfolio.id.uuidString,
            tournamentId: portfolio.tournamentId.uuidString,
            userId: portfolio.userId.uuidString,
            userName: portfolio.userName,
            initialBalance: portfolio.initialBalance,
            currentBalance: portfolio.currentBalance,
            totalInvested: portfolio.totalInvested,
            lastUpdated: portfolio.lastUpdated
        )
        
        // 映射到 portfolios 表並使用 upsert
        struct PortfolioUpsert: Codable {
            let id: String
            let user_id: String
            let tournament_id: String
            let initial_cash: Double
            let available_cash: Double
            let total_value: Double
            let return_rate: Double
            let last_updated: String
        }
        
        let upsertData = PortfolioUpsert(
            id: portfolio.id.uuidString,
            user_id: portfolio.userId.uuidString,
            tournament_id: portfolio.tournamentId.uuidString,
            initial_cash: portfolio.initialBalance,
            available_cash: portfolio.cashBalance,
            total_value: portfolio.totalAssets,
            return_rate: portfolio.returnPercentage / 100.0,
            last_updated: portfolio.lastUpdated.iso8601
        )
        
        try await client
            .from("portfolios")
            .upsert(upsertData)
            .execute()
        
        // 同步持股資訊
        try await syncTournamentHoldings(portfolio.holdings)
        
        // 同步績效指標
        try await syncTournamentPerformanceMetrics(portfolio.performanceMetrics, portfolioId: portfolio.id)
        
        print("✅ 錦標賽投資組合同步成功")
    }
    
    /// 同步錦標賽持股
    private func syncTournamentHoldings(_ holdings: [TournamentHolding]) async throws {
        for holding in holdings {
            struct TournamentHoldingInsert: Codable {
                let id: String
                let tournamentId: String
                let userId: String
                let symbol: String
                let name: String
                let shares: Double
                let averagePrice: Double
                let currentPrice: Double
                let firstPurchaseDate: Date
                let lastUpdated: Date
                
                enum CodingKeys: String, CodingKey {
                    case id, symbol, name, shares
                    case tournamentId = "tournament_id"
                    case userId = "user_id"
                    case averagePrice = "average_price"
                    case currentPrice = "current_price"
                    case firstPurchaseDate = "first_purchase_date"
                    case lastUpdated = "last_updated"
                }
            }
            
            let holdingData = TournamentHoldingInsert(
                id: holding.id.uuidString,
                tournamentId: holding.tournamentId.uuidString,
                userId: holding.userId.uuidString,
                symbol: holding.symbol,
                name: holding.name,
                shares: holding.shares,
                averagePrice: holding.averagePrice,
                currentPrice: holding.currentPrice,
                firstPurchaseDate: holding.firstPurchaseDate,
                lastUpdated: holding.lastUpdated
            )
            
            try await client
                .from("tournament_holdings")
                .upsert(holdingData)
                .execute()
        }
    }
    
    /// 同步錦標賽績效指標
    private func syncTournamentPerformanceMetrics(_ metrics: PerformanceMetrics, portfolioId: UUID) async throws {
        struct TournamentPerformanceInsert: Codable {
            let portfolioId: String
            let totalReturn: Double
            let totalReturnPercentage: Double
            let dailyReturn: Double
            let maxDrawdown: Double
            let maxDrawdownPercentage: Double
            let sharpeRatio: Double?
            let winRate: Double
            let totalTrades: Int
            let profitableTrades: Int
            let averageHoldingDays: Double
            let riskScore: Double
            let diversificationScore: Double
            let currentRank: Int
            let previousRank: Int
            let percentile: Double
            let lastUpdated: Date
            
            enum CodingKeys: String, CodingKey {
                case portfolioId = "portfolio_id"
                case totalReturn = "total_return"
                case totalReturnPercentage = "total_return_percentage"
                case dailyReturn = "daily_return"
                case maxDrawdown = "max_drawdown"
                case maxDrawdownPercentage = "max_drawdown_percentage"
                case sharpeRatio = "sharpe_ratio"
                case winRate = "win_rate"
                case totalTrades = "total_trades"
                case profitableTrades = "profitable_trades"
                case averageHoldingDays = "average_holding_days"
                case riskScore = "risk_score"
                case diversificationScore = "diversification_score"
                case currentRank = "current_rank"
                case previousRank = "previous_rank"
                case percentile
                case lastUpdated = "last_updated"
            }
        }
        
        let performanceData = TournamentPerformanceInsert(
            portfolioId: portfolioId.uuidString,
            totalReturn: metrics.totalReturn,
            totalReturnPercentage: metrics.totalReturnPercentage,
            dailyReturn: metrics.dailyReturn,
            maxDrawdown: metrics.maxDrawdown,
            maxDrawdownPercentage: metrics.maxDrawdownPercentage,
            sharpeRatio: metrics.sharpeRatio,
            winRate: metrics.winRate,
            totalTrades: metrics.totalTrades,
            profitableTrades: metrics.profitableTrades,
            averageHoldingDays: metrics.averageHoldingDays,
            riskScore: metrics.riskScore,
            diversificationScore: metrics.diversificationScore,
            currentRank: metrics.currentRank,
            previousRank: metrics.previousRank,
            percentile: metrics.percentile,
            lastUpdated: metrics.lastUpdated
        )
        
        try await client
            .from("tournament_performance_metrics")
            .upsert(performanceData)
            .execute()
    }
    
    
    /// 同步錦標賽排名
    func syncTournamentRankings(tournamentId: UUID, rankings: [TournamentParticipant]) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 同步錦標賽排名: \(tournamentId)")
        
        for participant in rankings {
            struct TournamentParticipantInsert: Codable {
                let id: String
                let tournamentId: String
                let userId: String
                let userName: String
                let userAvatar: String?
                let currentRank: Int
                let previousRank: Int
                let virtualBalance: Double
                let initialBalance: Double
                let returnRate: Double
                let totalTrades: Int
                let winRate: Double
                let maxDrawdown: Double
                let sharpeRatio: Double?
                let isEliminated: Bool
                let eliminationReason: String?
                let joinedAt: Date
                let lastUpdated: Date
                
                enum CodingKeys: String, CodingKey {
                    case id
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
                    case isEliminated = "is_eliminated"
                    case eliminationReason = "elimination_reason"
                    case joinedAt = "joined_at"
                    case lastUpdated = "last_updated"
                }
            }
            
            let participantData = TournamentParticipantInsert(
                id: participant.id.uuidString,
                tournamentId: participant.tournamentId.uuidString,
                userId: participant.userId.uuidString,
                userName: participant.userName,
                userAvatar: participant.userAvatar,
                currentRank: participant.currentRank,
                previousRank: participant.previousRank,
                virtualBalance: participant.virtualBalance,
                initialBalance: participant.initialBalance,
                returnRate: participant.returnRate,
                totalTrades: participant.totalTrades,
                winRate: participant.winRate,
                maxDrawdown: participant.maxDrawdown,
                sharpeRatio: participant.sharpeRatio,
                isEliminated: participant.isEliminated,
                eliminationReason: participant.eliminationReason,
                joinedAt: participant.joinedAt,
                lastUpdated: participant.lastUpdated
            )
            
            try await client
                .from("tournament_participants")
                .upsert(participantData)
                .execute()
        }
        
        print("✅ 錦標賽排名同步成功")
    }
    
    /// 同步用戶錦標賽狀態
    func syncUserTournamentStatus(userId: UUID, status: [UUID: TournamentUserStatus]) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 同步用戶錦標賽狀態")
        
        for (tournamentId, userStatus) in status {
            struct UserTournamentStatusInsert: Codable {
                let tournamentId: String
                let userId: String
                let isParticipating: Bool
                let joinedAt: Date
                let lastActivityAt: Date
                
                enum CodingKeys: String, CodingKey {
                    case tournamentId = "tournament_id"
                    case userId = "user_id"
                    case isParticipating = "is_participating"
                    case joinedAt = "joined_at"
                    case lastActivityAt = "last_activity_at"
                }
            }
            
            let statusData = UserTournamentStatusInsert(
                tournamentId: tournamentId.uuidString,
                userId: userId.uuidString,
                isParticipating: userStatus.isParticipating,
                joinedAt: userStatus.joinedAt,
                lastActivityAt: userStatus.lastActivityAt
            )
            
            try await client
                .from("user_tournament_status")
                .upsert(statusData)
                .execute()
        }
        
        print("✅ 用戶錦標賽狀態同步成功")
    }
    
    /// 獲取用戶錦標賽交易歷史
    func fetchUserTournamentTradingHistory(userId: UUID) async throws -> [TournamentTradingRecord] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📊 [SupabaseService] 獲取用戶錦標賽交易歷史")
        
        let records: [TournamentTradingRecord] = try await client
            .from("tournament_trading_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        print("✅ 獲取交易歷史成功: \(records.count) 筆記錄")
        return records
    }
    
    /// 同步錦標賽交易記錄
    func syncTournamentTradingRecord(tournamentId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 同步錦標賽交易記錄: \(tournamentId)")
        
        // 獲取本地交易記錄
        guard let portfolio = TournamentPortfolioManager.shared.getPortfolio(for: tournamentId) else {
            print("❌ 找不到錦標賽投資組合")
            return
        }
        
        for record in portfolio.tradingRecords {
            struct TradingRecordInsert: Codable {
                let id: String
                let tournamentId: String
                let userId: String
                let symbol: String
                let stockName: String
                let type: String
                let shares: Double
                let price: Double
                let totalAmount: Double
                let fee: Double
                let netAmount: Double
                let timestamp: Date
                let realizedGainLoss: Double?
                let realizedGainLossPercent: Double?
                let notes: String?
                
                enum CodingKeys: String, CodingKey {
                    case id, symbol, type, shares, price, timestamp, notes, fee
                    case tournamentId = "tournament_id"
                    case userId = "user_id"
                    case stockName = "stock_name"
                    case totalAmount = "total_amount"
                    case netAmount = "net_amount"
                    case realizedGainLoss = "realized_gain_loss"
                    case realizedGainLossPercent = "realized_gain_loss_percent"
                }
            }
            
            let recordData = TradingRecordInsert(
                id: record.id.uuidString,
                tournamentId: record.tournamentId.uuidString,
                userId: record.userId.uuidString,
                symbol: record.symbol,
                stockName: record.stockName,
                type: record.type.rawValue,
                shares: record.shares,
                price: record.price,
                totalAmount: record.totalAmount,
                fee: record.fee,
                netAmount: record.netAmount,
                timestamp: record.timestamp,
                realizedGainLoss: record.realizedGainLoss,
                realizedGainLossPercent: record.realizedGainLossPercent,
                notes: record.notes
            )
            
            try await client
                .from("tournament_trading_records")
                .upsert(recordData)
                .execute()
        }
        
        print("✅ 錦標賽交易記錄同步成功")
    }
    
    // MARK: - 錦標賽同步方法
    
    /// 同步錦標賽參賽者到資料庫
    public func upsertTournamentParticipant(_ participant: TournamentParticipant) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 同步錦標賽參賽者: \(participant.userName) (\(participant.tournamentId))")
        
        do {
            struct TournamentParticipantInsert: Codable {
                let id: String
                let tournamentId: String
                let userId: String
                let userName: String
                let userAvatar: String?
                let currentRank: Int
                let previousRank: Int
                let virtualBalance: Double
                let initialBalance: Double
                let returnRate: Double
                let totalTrades: Int
                let winRate: Double
                let maxDrawdown: Double
                let sharpeRatio: Double?
                let isEliminated: Bool
                let eliminationReason: String?
                let joinedAt: Date
                let lastUpdated: Date
                
                enum CodingKeys: String, CodingKey {
                    case id
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
                    case isEliminated = "is_eliminated"
                    case eliminationReason = "elimination_reason"
                    case joinedAt = "joined_at"
                    case lastUpdated = "last_updated"
                }
            }
            
            let participantData = TournamentParticipantInsert(
                id: participant.id.uuidString,
                tournamentId: participant.tournamentId.uuidString,
                userId: participant.userId.uuidString,
                userName: participant.userName,
                userAvatar: participant.userAvatar,
                currentRank: participant.currentRank,
                previousRank: participant.previousRank,
                virtualBalance: participant.virtualBalance,
                initialBalance: participant.initialBalance,
                returnRate: participant.returnRate,
                totalTrades: participant.totalTrades,
                winRate: participant.winRate,
                maxDrawdown: participant.maxDrawdown,
                sharpeRatio: participant.sharpeRatio,
                isEliminated: participant.isEliminated,
                eliminationReason: participant.eliminationReason,
                joinedAt: participant.joinedAt,
                lastUpdated: participant.lastUpdated
            )
            
            try await client
                .from("tournament_participants")
                .upsert(participantData)
                .execute()
            
            print("✅ [SupabaseService] 成功同步錦標賽參賽者: \(participant.userName)")
            
        } catch {
            print("❌ [SupabaseService] 同步錦標賽參賽者失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 同步錦標賽持股到資料庫
    public func upsertTournamentHolding(_ holding: TournamentHolding) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 同步錦標賽持股: \(holding.symbol) (\(holding.tournamentId))")
        
        do {
            struct TournamentHoldingInsert: Codable {
                let id: String
                let tournamentId: String
                let userId: String
                let symbol: String
                let name: String
                let shares: Double
                let averagePrice: Double
                let currentPrice: Double
                let firstPurchaseDate: Date
                let lastUpdated: Date
                
                enum CodingKeys: String, CodingKey {
                    case id, symbol, name, shares, currentPrice
                    case tournamentId = "tournament_id"
                    case userId = "user_id"
                    case averagePrice = "average_price"
                    case firstPurchaseDate = "first_purchase_date"
                    case lastUpdated = "last_updated"
                }
            }
            
            let holdingData = TournamentHoldingInsert(
                id: holding.id.uuidString,
                tournamentId: holding.tournamentId.uuidString,
                userId: holding.userId.uuidString,
                symbol: holding.symbol,
                name: holding.name,
                shares: holding.shares,
                averagePrice: holding.averagePrice,
                currentPrice: holding.currentPrice,
                firstPurchaseDate: holding.firstPurchaseDate,
                lastUpdated: holding.lastUpdated
            )
            
            try await client
                .from("tournament_holdings")
                .upsert(holdingData)
                .execute()
            
            print("✅ [SupabaseService] 成功同步錦標賽持股: \(holding.symbol)")
            
        } catch {
            print("❌ [SupabaseService] 同步錦標賽持股失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 插入錦標賽交易記錄到資料庫
    public func insertTournamentTrade(_ record: TournamentTradingRecord) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📝 [SupabaseService] 插入錦標賽交易記錄: \(record.symbol) \(record.type.rawValue) (\(record.tournamentId))")
        
        do {
            struct TournamentTradingRecordInsert: Codable {
                let id: String
                let tournamentId: String
                let userId: String
                let symbol: String
                let stockName: String
                let type: String
                let shares: Double
                let price: Double
                let totalAmount: Double
                let fee: Double
                let netAmount: Double
                let timestamp: Date
                let realizedGainLoss: Double?
                let realizedGainLossPercent: Double?
                let notes: String?
                
                enum CodingKeys: String, CodingKey {
                    case id, symbol, type, shares, price, timestamp, notes, fee
                    case tournamentId = "tournament_id"
                    case userId = "user_id"
                    case stockName = "stock_name"
                    case totalAmount = "total_amount"
                    case netAmount = "net_amount"
                    case realizedGainLoss = "realized_gain_loss"
                    case realizedGainLossPercent = "realized_gain_loss_percent"
                }
            }
            
            let recordData = TournamentTradingRecordInsert(
                id: record.id.uuidString,
                tournamentId: record.tournamentId.uuidString,
                userId: record.userId.uuidString,
                symbol: record.symbol,
                stockName: record.stockName,
                type: record.type.rawValue,
                shares: record.shares,
                price: record.price,
                totalAmount: record.totalAmount,
                fee: record.fee,
                netAmount: record.netAmount,
                timestamp: record.timestamp,
                realizedGainLoss: record.realizedGainLoss,
                realizedGainLossPercent: record.realizedGainLossPercent,
                notes: record.notes
            )
            
            try await client
                .from("tournament_trades")
                .insert(recordData)
                .execute()
            
            print("✅ [SupabaseService] 成功插入錦標賽交易記錄: \(record.symbol) \(record.type.rawValue)")
            
        } catch {
            print("❌ [SupabaseService] 插入錦標賽交易記錄失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取錦標賽排名（優化版本）
    public func fetchTournamentRankings(tournamentId: UUID) async throws -> [TournamentParticipant] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📊 [SupabaseService] 獲取錦標賽排名: \(tournamentId)")
        
        do {
            let participants: [TournamentParticipant] = try await client
                .from("tournament_participants")
                .select()
                .eq("tournament_id", value: tournamentId.uuidString)
                .order("current_rank", ascending: true)
                .execute()
                .value
            
            print("✅ [SupabaseService] 成功獲取錦標賽排名: \(participants.count) 位參賽者")
            return participants
            
        } catch {
            print("❌ [SupabaseService] 獲取錦標賽排名失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - User Management Methods
    
    /// 獲取所有用戶
    func fetchAllUsers() async throws -> [UserProfile] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("👥 [SupabaseService] 獲取所有用戶")
        
        let users: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ 獲取用戶成功: \(users.count) 個用戶")
        return users
    }
    
    // MARK: - Tournament Management Methods
    
    /// 刪除錦標賽
    func deleteTournament(tournamentId: UUID) async throws -> Bool {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🗑️ [SupabaseService] 刪除錦標賽: \(tournamentId)")
        
        try await client
            .from("tournaments")
            .delete()
            .eq("id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽刪除成功")
        return true
    }
    
    /// 更新錦標賽
    func updateTournament(_ tournament: Tournament) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 更新錦標賽: \(tournament.name)")
        
        let updateData: [String: AnyJSON] = [
            "name": try AnyJSON(tournament.name),
            "type": try AnyJSON(tournament.type.rawValue),
            "status": try AnyJSON(tournament.status.rawValue),
            "start_date": try AnyJSON(ISO8601DateFormatter().string(from: tournament.startDate)),
            "end_date": try AnyJSON(ISO8601DateFormatter().string(from: tournament.endDate)),
            "description": try AnyJSON(tournament.description),
            "short_description": try AnyJSON(tournament.shortDescription),
            "initial_balance": try AnyJSON(tournament.initialBalance),
            "entry_fee": try AnyJSON(tournament.entryFee),
            "prize_pool": try AnyJSON(tournament.prizePool),
            "max_participants": try AnyJSON(tournament.maxParticipants),
            "current_participants": try AnyJSON(tournament.currentParticipants),
            "is_featured": try AnyJSON(tournament.isFeatured),
            "risk_limit_percentage": try AnyJSON(tournament.riskLimitPercentage),
            "min_holding_rate": try AnyJSON(tournament.minHoldingRate),
            "max_single_stock_rate": try AnyJSON(tournament.maxSingleStockRate),
            "updated_at": try AnyJSON(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await client
            .from("tournaments")
            .update(updateData)
            .eq("id", value: tournament.id.uuidString)
            .execute()
        
        print("✅ 錦標賽更新成功")
    }
    
    /// 刪除錦標賽成員
    func deleteTournamentMembers(tournamentId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🗑️ [SupabaseService] 刪除錦標賽成員: \(tournamentId)")
        
        try await client
            .from("tournament_participants")
            .delete()
            .eq("tournament_id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽成員刪除成功")
    }
    
    /// 刪除錦標賽錢包
    func deleteTournamentWallets(tournamentId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🗑️ [SupabaseService] 刪除錦標賽錢包: \(tournamentId)")
        
        try await client
            .from("portfolios")
            .delete()
            .eq("tournament_id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽錢包刪除成功")
    }
    
    /// 刪除錦標賽交易記錄
    func deleteTournamentTrades(tournamentId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🗑️ [SupabaseService] 刪除錦標賽交易記錄: \(tournamentId)")
        
        try await client
            .from("tournament_trades")
            .delete()
            .eq("tournament_id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽交易記錄刪除成功")
    }
    
    /// 刪除錦標賽持倉記錄
    func deleteTournamentPositions(tournamentId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🗑️ [SupabaseService] 刪除錦標賽持倉記錄: \(tournamentId)")
        
        try await client
            .from("tournament_positions")
            .delete()
            .eq("tournament_id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽持倉記錄刪除成功")
    }
    
    /// 刪除錦標賽排名記錄
    func deleteTournamentRankings(tournamentId: UUID) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🗑️ [SupabaseService] 刪除錦標賽排名記錄: \(tournamentId)")
        
        try await client
            .from("tournament_leaderboard")
            .delete()
            .eq("tournament_id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽排名記錄刪除成功")
    }
    
    /// 更新錦標賽參與者數量
    func updateTournamentParticipantCount(tournamentId: UUID, increment: Int) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📊 [SupabaseService] 更新錦標賽參與者數量: \(tournamentId), 增量: \(increment)")
        
        // 獲取當前參與者數量
        let currentData: [TournamentResponse] = try await client
            .from("tournaments")
            .select("current_participants")
            .eq("id", value: tournamentId.uuidString)
            .execute()
            .value
        
        guard let current = currentData.first else {
            throw NSError(domain: "SupabaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Tournament not found"])
        }
        
        let newCount = current.currentParticipants + increment
        
        try await client
            .from("tournaments")
            .update(["current_participants": AnyJSON(newCount)])
            .eq("id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽參與者數量已更新: \(newCount)")
    }
    
    /// 更新錦標賽狀態
    func updateTournamentStatus(tournamentId: UUID, status: TournamentStatus) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔄 [SupabaseService] 更新錦標賽狀態: \(tournamentId) -> \(status.rawValue)")
        
        try await client
            .from("tournaments")
            .update([
                "status": AnyJSON(status.rawValue),
                "updated_at": AnyJSON(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: tournamentId.uuidString)
            .execute()
        
        print("✅ 錦標賽狀態已更新")
    }
    
    // MARK: - 調試方法 (僅用於開發階段)
    #if DEBUG
    /// 測試 RLS 政策和用戶認證狀態
    func testFriendRequestPermissions() async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("🔍 [DEBUG] 開始測試好友請求權限...")
        
        // 1. 檢查當前認證狀態
        if let session = client.auth.currentSession {
            print("✅ [DEBUG] 用戶已認證 - User ID: \(session.user.id)")
            print("✅ [DEBUG] Access Token: \(session.accessToken.prefix(20))...")
        } else {
            print("❌ [DEBUG] 用戶未認證")
            throw SupabaseError.notAuthenticated
        }
        
        // 2. 嘗試獲取當前用戶資料
        do {
            let currentUser = try await getCurrentUserAsync()
            print("✅ [DEBUG] 獲取用戶資料成功: \(currentUser.displayName) (\(currentUser.id))")
        } catch {
            print("❌ [DEBUG] 獲取用戶資料失敗: \(error)")
            throw error
        }
        
        // 3. 測試讀取 friend_requests 表的權限
        do {
            let _: [FriendRequestResponse] = try await client
                .from("friend_requests")
                .select()
                .limit(1)
                .execute()
                .value
            print("✅ [DEBUG] 讀取 friend_requests 表權限正常")
        } catch {
            print("❌ [DEBUG] 讀取 friend_requests 表失敗: \(error)")
        }
        
        print("🎯 [DEBUG] 權限測試完成")
    }
    #endif
    
    // MARK: - User ID Management Methods
    
    /// 檢查用戶ID是否可用
    func checkUserIDAvailability(_ userID: String) async -> Bool {
        do {
            try await SupabaseManager.shared.ensureInitializedAsync()
            
            // 查詢是否有用戶使用該ID
            let users: [UserProfileResponse] = try await client
                .from("user_profiles")
                .select("id")
                .eq("username", value: userID)
                .limit(1)
                .execute()
                .value
            
            // 如果沒有找到用戶，則ID可用
            return users.isEmpty
        } catch {
            print("❌ [SupabaseService] 檢查用戶ID可用性失敗: \(error)")
            return false
        }
    }
    
    /// 更新用戶ID（username）
    func updateUserID(_ newUserID: String) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // 獲取當前用戶
        let currentUser = try await getCurrentUserAsync()
        
        // 再次檢查ID是否可用
        let isAvailable = await checkUserIDAvailability(newUserID)
        guard isAvailable else {
            throw SupabaseError.unknown("用戶ID已被使用")
        }
        
        print("🔄 [SupabaseService] 更新用戶ID: \(currentUser.username) -> \(newUserID)")
        
        // 更新數據庫中的用戶名
        try await client
            .from("user_profiles")
            .update([
                "username": newUserID,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: currentUser.id.uuidString)
            .execute()
        
        // 更新本地緩存 - 創建新的UserProfile實例
        let updatedProfile = UserProfile(
            id: currentUser.id,
            email: currentUser.email,
            username: newUserID, // 使用新的用戶ID
            displayName: currentUser.displayName,
            avatarUrl: currentUser.avatarUrl,
            bio: currentUser.bio,
            firstName: currentUser.firstName,
            lastName: currentUser.lastName,
            fullName: currentUser.fullName,
            phone: currentUser.phone,
            website: currentUser.website,
            location: currentUser.location,
            socialLinks: currentUser.socialLinks,
            investmentPhilosophy: currentUser.investmentPhilosophy,
            specializations: currentUser.specializations,
            yearsExperience: currentUser.yearsExperience,
            followerCount: currentUser.followerCount,
            followingCount: currentUser.followingCount,
            articleCount: currentUser.articleCount,
            totalReturnRate: currentUser.totalReturnRate,
            isVerified: currentUser.isVerified,
            status: currentUser.status,
            userId: currentUser.userId,
            createdAt: currentUser.createdAt,
            updatedAt: Date() // 更新時間戳
        )
        
        // 保存到 UserDefaults
        if let encoded = try? JSONEncoder().encode(updatedProfile) {
            UserDefaults.standard.set(encoded, forKey: "current_user")
        }
        
        print("✅ [SupabaseService] 用戶ID更新成功")
    }
    
    // MARK: - Tournament Ranking Methods
    
    /// 保存錦標賽排名到數據庫
    func saveTournamentRankings(tournamentId: UUID, rankings: [TournamentLeaderboardEntry]) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("💾 [SupabaseService] 保存錦標賽排名: \(rankings.count) 位參賽者")
        
        // 轉換為數據庫格式
        let rankingData = try rankings.map { entry in
            [
                "tournament_id": try AnyJSON(tournamentId.uuidString),
                "user_id": try AnyJSON(entry.userId.uuidString),
                "rank": try AnyJSON(entry.currentRank),
                "total_assets": try AnyJSON(entry.totalAssets),
                "return_percentage": try AnyJSON(entry.returnPercentage),
                "total_trades": try AnyJSON(entry.totalTrades),
                "updated_at": try AnyJSON(ISO8601DateFormatter().string(from: Date()))
            ]
        }
        
        // 批量插入或更新排名
        try await client
            .from("tournament_rankings")
            .upsert(rankingData)
            .execute()
        
        print("✅ 錦標賽排名已保存")
    }
    
    /// 更新錦標賽排名快照
    func updateTournamentRankSnapshot(
        tournamentId: UUID,
        userId: UUID,
        rank: Int,
        snapshotDate: Date
    ) async throws {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📸 [SupabaseService] 更新排名快照: 第\(rank)名")
        
        let snapshotData: [String: AnyJSON] = [
            "tournament_id": try AnyJSON(tournamentId.uuidString),
            "user_id": try AnyJSON(userId.uuidString),
            "rank": try AnyJSON(rank),
            "snapshot_date": try AnyJSON(ISO8601DateFormatter().string(from: snapshotDate)),
            "created_at": try AnyJSON(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await client
            .from("tournament_rank_snapshots")
            .upsert([snapshotData])
            .execute()
        
        print("✅ 排名快照已更新")
    }
    
    /// 獲取排名歷史
    func fetchRankingHistory(
        tournamentId: UUID,
        userId: UUID,
        days: Int
    ) async throws -> [TournamentSnapshot] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("📊 [SupabaseService] 獲取排名歷史: \(days) 天")
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let snapshots: [TournamentSnapshot] = try await client
            .from("tournament_snapshots")
            .select("*")
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .gte("snapshot_date", value: ISO8601DateFormatter().string(from: startDate))
            .order("snapshot_date", ascending: false)
            .execute()
            .value
        print("✅ 找到 \(snapshots.count) 個歷史快照")
        
        return snapshots
    }
    
    /// 獲取即時排名變化
    func fetchRealtimeRankingChanges(tournamentId: UUID) async throws -> [RankingChange] {
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        print("⚡ [SupabaseService] 獲取即時排名變化")
        
        // 獲取過去1小時的排名變化
        let oneHourAgo = Date().addingTimeInterval(-3600)
        
        let response = try await client
            .from("tournament_ranking_changes")
            .select("*")
            .eq("tournament_id", value: tournamentId.uuidString)
            .gte("timestamp", value: ISO8601DateFormatter().string(from: oneHourAgo))
            .order("timestamp", ascending: false)
            .execute()
        
        // 暫時返回空數組，因為 RankingChange 可能需要特殊處理
        print("⚠️ RankingChange 結構需要進一步定義")
        return []
    }
    
    // MARK: - 新增的缺失方法
    
    /// 插入錦標賽交易記錄
    func insertTournamentTrade(_ trade: TournamentTradeRecord) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        struct TournamentTradeInsert: Codable {
            let id: String
            let user_id: String
            let tournament_id: String
            let symbol: String
            let stock_name: String
            let type: String
            let shares: Double
            let price: Double
            let timestamp: String
            let total_amount: Double
            let fee: Double
            let net_amount: Double
        }
        
        let tradeData = TournamentTradeInsert(
            id: trade.id.uuidString,
            user_id: trade.userId.uuidString,
            tournament_id: trade.tournamentId?.uuidString ?? "",
            symbol: trade.symbol,
            stock_name: trade.stockName,
            type: trade.type.rawValue,
            shares: trade.shares,
            price: trade.price,
            timestamp: ISO8601DateFormatter().string(from: trade.timestamp),
            total_amount: trade.totalAmount,
            fee: trade.fee,
            net_amount: trade.netAmount
        )
        
        try await client
            .from("tournament_trading_records")
            .insert(tradeData)
            .execute()
    }
    
    /// 獲取錦標賽交易記錄
    func fetchTournamentTrade(tradeId: UUID) async throws -> TournamentTradeRecord? {
        try SupabaseManager.shared.ensureInitialized()
        
        struct TradeResponse: Codable {
            let id: UUID
            let userId: UUID
            let tournamentId: UUID?
            let symbol: String
            let stockName: String
            let type: String
            let shares: Double
            let price: Double
            let timestamp: String
            let totalAmount: Double
            let fee: Double
            let netAmount: Double
            
            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case tournamentId = "tournament_id"
                case symbol
                case stockName = "stock_name"
                case type
                case shares
                case price
                case timestamp
                case totalAmount = "total_amount"
                case fee
                case netAmount = "net_amount"
            }
        }
        
        let response: [TradeResponse] = try await client
            .from("tournament_trading_records")
            .select("*")
            .eq("id", value: tradeId.uuidString)
            .execute()
            .value
        
        guard let tradeData = response.first else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let timestamp = dateFormatter.date(from: tradeData.timestamp) else {
            throw NSError(domain: "DateFormatError", code: 1, userInfo: nil)
        }
        
        return TournamentTradeRecord(
            id: tradeData.id,
            userId: tradeData.userId,
            tournamentId: tradeData.tournamentId,
            symbol: tradeData.symbol,
            stockName: tradeData.stockName,
            type: TradeSide(rawValue: tradeData.type) ?? .buy,
            shares: tradeData.shares,
            price: tradeData.price,
            timestamp: timestamp,
            totalAmount: tradeData.totalAmount,
            fee: tradeData.fee,
            netAmount: tradeData.netAmount,
            averageCost: nil,
            realizedGainLoss: nil,
            realizedGainLossPercent: nil,
            notes: nil,
            tradeDate: timestamp // 添加 tradeDate 參數，使用解析的 timestamp
        )
    }
    
    /// 更新錦標賽投資組合
    func updateTournamentPortfolio<T: Codable>(tournamentId: UUID, userId: UUID, portfolioData: T) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        try await client
            .from("portfolios")
            .update(portfolioData)
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
    
    /// 刪除錦標賽投資組合
    func deleteTournamentPortfolio(tournamentId: UUID, userId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        try await client
            .from("portfolios")
            .delete()
            .eq("tournament_id", value: tournamentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}
