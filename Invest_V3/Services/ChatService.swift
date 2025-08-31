import Foundation
import Supabase

/// 聊天管理服務
/// 負責處理所有與聊天相關的操作，包括發送消息、獲取聊天記錄、私人聊天等
@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()
    
    private var client: SupabaseClient {
        SupabaseService.shared.client
    }
    
    private init() {}
    
    // MARK: - 群組聊天
    
    /// 發送群組消息
    func sendGroupMessage(
        groupId: UUID,
        content: String,
        messageType: ChatMessageType = .text
    ) async throws -> ChatMessage {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 檢查用戶是否為群組成員
        guard try await isGroupMember(groupId: groupId, userId: currentUser.id) else {
            Logger.error("❌ 用戶不是群組成員，無法發送消息", category: .database)
            throw DatabaseError.unauthorized("只有群組成員可以發送消息")
        }
        
        Logger.info("💬 發送群組消息到: \(groupId)", category: .database)
        
        let messageId = UUID()
        let now = Date()
        
        let messageData = ChatMessageInsert(
            id: messageId.uuidString,
            groupId: groupId.uuidString,
            senderId: currentUser.id.uuidString,
            senderName: currentUser.displayName ?? "匿名用戶",
            content: content,
            messageType: messageType.rawValue,
            createdAt: ISO8601DateFormatter().string(from: now)
        )
        
        try await client
            .from("chat_messages")
            .insert(messageData)
            .execute()
        
        // 更新群組最後活動時間
        try await client
            .from("investment_groups")
            .update(["updated_at": ISO8601DateFormatter().string(from: now)])
            .eq("id", value: groupId.uuidString)
            .execute()
        
        Logger.info("✅ 群組消息發送成功", category: .database)
        
        return ChatMessage(
            id: messageId,
            groupId: groupId,
            senderId: currentUser.id,
            senderName: currentUser.displayName ?? "匿名用戶",
            content: content,
            isInvestmentCommand: messageType == .system,
            createdAt: now
        )
    }
    
    /// 獲取群組聊天記錄
    func getGroupMessages(
        groupId: UUID,
        limit: Int = 50,
        before: Date? = nil
    ) async throws -> [ChatMessage] {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 檢查用戶是否為群組成員
        guard try await isGroupMember(groupId: groupId, userId: currentUser.id) else {
            Logger.error("❌ 用戶不是群組成員，無法查看聊天記錄", category: .database)
            throw DatabaseError.unauthorized("只有群組成員可以查看聊天記錄")
        }
        
        Logger.info("📜 獲取群組聊天記錄: \(groupId)", category: .database)
        
        var query = client
            .from("chat_messages")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
        
        // TODO: Implement date filtering when PostgrestTransformBuilder supports .lte() method
        if let before = before {
            // query = query.lte("created_at", value: ISO8601DateFormatter().string(from: before))
        }
        
        let response = try await query.execute()
        let messageData = try JSONDecoder().decode([ChatMessageResponse].self, from: response.data)
        
        let messages = messageData.compactMap { data -> ChatMessage? in
            guard let messageId = UUID(uuidString: data.id),
                  let senderId = UUID(uuidString: data.senderId),
                  let messageType = ChatMessageType(rawValue: data.messageType),
                  let timestamp = ISO8601DateFormatter().date(from: data.createdAt) else {
                return nil
            }
            
            return ChatMessage(
                id: messageId,
                groupId: groupId,
                senderId: senderId,
                senderName: data.senderName,
                content: data.content,
                isInvestmentCommand: messageType == .system,
                createdAt: timestamp
            )
        }.reversed() // 恢復時間順序
        
        Logger.info("✅ 獲取到 \(messages.count) 條聊天記錄", category: .database)
        return Array(messages)
    }
    
    /// 清除群組聊天記錄
    func clearGroupChatHistory(groupId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 權限檢查：只有群組主持人才可以清除聊天記錄
        let groupDetails = try await GroupService.shared.getGroupDetails(groupId: groupId)
        guard groupDetails.hostId == currentUser.id else {
            Logger.error("❌ 權限不足：只有群組主持人才能清除聊天記錄", category: .database)
            throw DatabaseError.unauthorized("只有群組主持人才能執行此操作")
        }
        
        Logger.debug("🧹 群組主持人正在清除聊天記錄", category: .database)
        
        try await client
            .from("chat_messages")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .execute()
        
        Logger.info("✅ 聊天記錄清除成功", category: .database)
    }
    
    // MARK: - 私人聊天
    
    /// 創建或獲取私人聊天
    func getOrCreatePrivateChat(withUser userId: UUID) async throws -> PrivateChat {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 檢查是否已有私人聊天
        let response = try await client
            .from("private_chats")
            .select()
            .or("and(user1_id.eq.\(currentUser.id.uuidString),user2_id.eq.\(userId.uuidString)),and(user1_id.eq.\(userId.uuidString),user2_id.eq.\(currentUser.id.uuidString))")
            .execute()
        let existingChats = try JSONDecoder().decode([PrivateChatResponse].self, from: response.data)
        
        if let existingChat = existingChats.first,
           let chatId = UUID(uuidString: existingChat.id) {
            Logger.info("💬 找到現有私人聊天: \(chatId)", category: .database)
            return PrivateChat(
                id: chatId,
                user1Id: UUID(uuidString: existingChat.user1Id) ?? UUID(),
                user2Id: UUID(uuidString: existingChat.user2Id) ?? UUID(),
                createdAt: ISO8601DateFormatter().date(from: existingChat.createdAt) ?? Date(),
                lastMessageAt: ISO8601DateFormatter().date(from: existingChat.lastMessageAt ?? existingChat.createdAt) ?? Date()
            )
        }
        
        // 創建新的私人聊天
        Logger.info("🆕 創建新的私人聊天", category: .database)
        
        let chatId = UUID()
        let now = Date()
        
        let chatData = PrivateChatInsert(
            id: chatId.uuidString,
            user1Id: currentUser.id.uuidString,
            user2Id: userId.uuidString,
            createdAt: ISO8601DateFormatter().string(from: now),
            lastMessageAt: ISO8601DateFormatter().string(from: now)
        )
        
        try await client
            .from("private_chats")
            .insert(chatData)
            .execute()
        
        Logger.info("✅ 私人聊天創建成功: \(chatId)", category: .database)
        
        return PrivateChat(
            id: chatId,
            user1Id: currentUser.id,
            user2Id: userId,
            createdAt: now,
            lastMessageAt: now
        )
    }
    
    /// 發送私人消息
    func sendPrivateMessage(
        chatId: UUID,
        content: String,
        messageType: ChatMessageType = .text
    ) async throws -> PrivateMessage {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("💌 發送私人消息到聊天: \(chatId)", category: .database)
        
        let messageId = UUID()
        let now = Date()
        
        let messageData = PrivateMessageInsert(
            id: messageId.uuidString,
            chatId: chatId.uuidString,
            senderId: currentUser.id.uuidString,
            content: content,
            messageType: messageType.rawValue,
            createdAt: ISO8601DateFormatter().string(from: now)
        )
        
        try await client
            .from("private_messages")
            .insert(messageData)
            .execute()
        
        // 更新聊天的最後消息時間
        try await client
            .from("private_chats")
            .update(["last_message_at": ISO8601DateFormatter().string(from: now)])
            .eq("id", value: chatId.uuidString)
            .execute()
        
        Logger.info("✅ 私人消息發送成功", category: .database)
        
        return PrivateMessage(
            id: messageId,
            chatId: chatId,
            senderId: currentUser.id,
            content: content,
            messageType: messageType,
            timestamp: now,
            isRead: false
        )
    }
    
    /// 獲取私人聊天消息
    func getPrivateMessages(
        chatId: UUID,
        limit: Int = 50,
        before: Date? = nil
    ) async throws -> [PrivateMessage] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("📜 獲取私人聊天記錄: \(chatId)", category: .database)
        
        var query = client
            .from("private_messages")
            .select()
            .eq("chat_id", value: chatId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
        
        // TODO: Implement date filtering when PostgrestTransformBuilder supports .lte() method
        if let before = before {
            // query = query.lte("created_at", value: ISO8601DateFormatter().string(from: before))
        }
        
        let response = try await query.execute()
        let messageData = try JSONDecoder().decode([PrivateMessageResponse].self, from: response.data)
        
        let messages = messageData.compactMap { data -> PrivateMessage? in
            guard let messageId = UUID(uuidString: data.id),
                  let senderId = UUID(uuidString: data.senderId),
                  let messageType = ChatMessageType(rawValue: data.messageType),
                  let timestamp = ISO8601DateFormatter().date(from: data.createdAt) else {
                return nil
            }
            
            return PrivateMessage(
                id: messageId,
                chatId: chatId,
                senderId: senderId,
                content: data.content,
                messageType: messageType,
                timestamp: timestamp,
                isRead: data.isRead ?? false
            )
        }.reversed()
        
        Logger.info("✅ 獲取到 \(messages.count) 條私人消息", category: .database)
        return Array(messages)
    }
    
    /// 標記私人消息為已讀
    func markPrivateMessagesAsRead(chatId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("✓ 標記私人消息為已讀: \(chatId)", category: .database)
        
        try await client
            .from("private_messages")
            .update(["is_read": true])
            .eq("chat_id", value: chatId.uuidString)
            .neq("sender_id", value: currentUser.id.uuidString)
            .eq("is_read", value: false)
            .execute()
        
        Logger.info("✅ 私人消息已標記為已讀", category: .database)
    }
    
    // MARK: - 輔助方法
    
    private func isGroupMember(groupId: UUID, userId: UUID) async throws -> Bool {
        let response = try await client
            .from("group_members")
            .select("id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        let memberships = try JSONDecoder().decode([MembershipCheck].self, from: response.data)
        
        return !memberships.isEmpty
    }
}

// MARK: - 數據結構

/// 聊天消息類型
enum ChatMessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case file = "file"
    case system = "system"
}

// MARK: - Using ChatMessage from ChatMessage.swift to avoid duplication

/// 私人聊天
struct PrivateChat: Identifiable, Codable {
    let id: UUID
    let user1Id: UUID
    let user2Id: UUID
    let createdAt: Date
    let lastMessageAt: Date
}

/// 私人消息
struct PrivateMessage: Identifiable, Codable {
    let id: UUID
    let chatId: UUID
    let senderId: UUID
    let content: String
    let messageType: ChatMessageType
    let timestamp: Date
    let isRead: Bool
}

// MARK: - 內部數據結構

private struct ChatMessageInsert: Codable {
    let id: String
    let groupId: String
    let senderId: String
    let senderName: String
    let content: String
    let messageType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
    }
}

private struct ChatMessageResponse: Codable {
    let id: String
    let senderId: String
    let senderName: String
    let content: String
    let messageType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
    }
}

private struct PrivateChatInsert: Codable {
    let id: String
    let user1Id: String
    let user2Id: String
    let createdAt: String
    let lastMessageAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
    }
}

private struct PrivateChatResponse: Codable {
    let id: String
    let user1Id: String
    let user2Id: String
    let createdAt: String
    let lastMessageAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
    }
}

private struct PrivateMessageInsert: Codable {
    let id: String
    let chatId: String
    let senderId: String
    let content: String
    let messageType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
    }
}

private struct PrivateMessageResponse: Codable {
    let id: String
    let senderId: String
    let content: String
    let messageType: String
    let createdAt: String
    let isRead: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

private struct MembershipCheck: Codable {
    let id: UUID
}