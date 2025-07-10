//
//  SupabaseService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private var client: SupabaseClient!
    private var isInitialized = false
    
    private init() {}
    
    func initialize() async {
        guard !isInitialized else { return }
        
        let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co")!
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"
        
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        
        // 設置認證狀態監聽
        await client.auth.onAuthStateChange { event, session in
            Task { @MainActor in
                if let session = session {
                    print("✅ Auth State Changed: \(event), User: \(session.user.id)")
                } else {
                    print("ℹ️ Auth State Changed: \(event), No session")
                }
            }
        }
        
        isInitialized = true
        print("✅ Supabase 初始化成功")
    }
    
    // MARK: - Authentication
    func signInAnonymously() async throws {
        await initialize()
        try await client.auth.signInAnonymously()
    }
    
    func getCurrentUser() -> User? {
        return client.auth.currentUser
    }
    
    // MARK: - Investment Groups
    func fetchInvestmentGroups() async throws -> [InvestmentGroup] {
        await initialize()
        try await signInAnonymously()
        
        let response: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    func createInvestmentGroup(_ group: InvestmentGroup) async throws {
        await initialize()
        try await signInAnonymously()
        
        try await client.database
            .from("investment_groups")
            .insert(group)
            .execute()
    }
    
    func joinGroup(groupId: UUID, userId: UUID) async throws {
        await initialize()
        try await signInAnonymously()
        
        let membership = GroupMembership(groupId: groupId, userId: userId)
        try await client.database
            .from("group_members")
            .insert(membership)
            .execute()
    }
    
    // MARK: - Articles
    func fetchArticles() async throws -> [Article] {
        await initialize()
        try await signInAnonymously()
        
        let response: [Article] = try await client.database
            .from("articles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    func createArticle(_ article: Article) async throws {
        await initialize()
        try await signInAnonymously()
        
        try await client.database
            .from("articles")
            .insert(article)
            .execute()
    }
    
    func likeArticle(articleId: UUID, userId: UUID) async throws {
        await initialize()
        try await signInAnonymously()
        
        let like = ArticleLike(articleId: articleId, userId: userId)
        try await client.database
            .from("article_likes")
            .insert(like)
            .execute()
    }
    
    func unlikeArticle(articleId: UUID, userId: UUID) async throws {
        await initialize()
        try await signInAnonymously()
        
        try await client.database
            .from("article_likes")
            .delete()
            .eq("article_id", value: articleId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    // MARK: - Chat Messages
    func fetchChatMessages(groupId: UUID) async throws -> [ChatMessage] {
        await initialize()
        try await signInAnonymously()
        
        let response: [ChatMessage] = try await client.database
            .from("chat_messages")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return response
    }
    
    func sendChatMessage(_ message: ChatMessage) async throws {
        await initialize()
        try await signInAnonymously()
        
        try await client.database
            .from("chat_messages")
            .insert(message)
            .execute()
    }
    
    // MARK: - Portfolio
    func fetchUserPortfolio(userId: UUID) async throws -> [Portfolio] {
        await initialize()
        try await signInAnonymously()
        
        let response: [Portfolio] = try await client.database
            .from("user_portfolios")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response
    }
    
    func executeTransaction(_ transaction: PortfolioTransaction) async throws {
        await initialize()
        try await signInAnonymously()
        
        try await client.database
            .from("portfolio_transactions")
            .insert(transaction)
            .execute()
    }
    
    // MARK: - Wallet & Payments
    func fetchUserBalance(userId: UUID) async throws -> UserBalance? {
        await initialize()
        try await signInAnonymously()
        
        let response: [UserBalance] = try await client.database
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response.first
    }
    
    func createWalletTransaction(_ transaction: WalletTransaction) async throws {
        await initialize()
        try await signInAnonymously()
        
        try await client.database
            .from("wallet_transactions")
            .insert(transaction)
            .execute()
    }
    
    func purchaseGift(userId: UUID, giftId: UUID, recipientGroupId: UUID, quantity: Int, totalCost: Int) async throws {
        await initialize()
        try await signInAnonymously()
        
        let gift = UserGift(
            id: UUID(),
            userId: userId,
            giftId: giftId,
            recipientGroupId: recipientGroupId,
            quantity: quantity,
            totalCost: totalCost,
            createdAt: Date()
        )
        try await client.database
            .from("user_gifts")
            .insert(gift)
            .execute()
    }
    
    // MARK: - Subscriptions
    func createSubscription(userId: UUID, authorId: UUID) async throws {
        await initialize()
        try await signInAnonymously()
        
        let subscription = Subscription(
            id: UUID(),
            userId: userId,
            authorId: authorId,
            startDate: Date()
        )
        try await client.database
            .from("subscriptions")
            .insert(subscription)
            .execute()
    }
    
    func fetchUserSubscriptions(userId: UUID) async throws -> [Subscription] {
        await initialize()
        try await signInAnonymously()
        
        let response: [Subscription] = try await client.database
            .from("subscriptions")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response
    }
    
    // MARK: - Weekly Rankings
    func fetchWeeklyRankings() async throws -> [WeeklyRanking] {
        await initialize()
        try await signInAnonymously()
        
        let response: [WeeklyRanking] = try await client.database
            .from("weekly_rankings")
            .select()
            .order("return_rate", ascending: false)
            .limit(10)
            .execute()
            .value
        return response
    }
    
    // MARK: - Investment Commands (模擬投資指令)
    func processInvestmentCommand(userId: UUID, groupId: UUID, command: String, symbol: String, amount: Double) async throws {
        await initialize()
        try await signInAnonymously()
        
        let transaction = PortfolioTransaction(
            id: UUID(),
            userId: userId,
            symbol: symbol,
            action: command == "買入" ? "buy" : "sell",
            amount: amount,
            price: nil, // 將由觸發器填入當前市價
            executedAt: Date()
        )
        
        try await executeTransaction(transaction)
        
        // 同時記錄為聊天訊息
        let chatMessage = ChatMessage(
            id: UUID(),
            groupId: groupId,
            senderId: userId,
            senderName: "投資者", // 實際應用中應該從用戶資料獲取
            content: "[\(command)] \(symbol) \(Int(amount/10000))萬",
            isInvestmentCommand: true,
            createdAt: Date()
        )
        
        try await sendChatMessage(chatMessage)
    }
}

// MARK: - Supporting Models
struct GroupMembership: Codable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let joinedAt: Date?
    
    init(groupId: UUID, userId: UUID) {
        self.id = UUID()
        self.groupId = groupId
        self.userId = userId
        self.joinedAt = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

struct ArticleLike: Codable {
    let id: UUID
    let articleId: UUID
    let userId: UUID
    let createdAt: Date?
    
    init(articleId: UUID, userId: UUID) {
        self.id = UUID()
        self.articleId = articleId
        self.userId = userId
        self.createdAt = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let groupId: UUID?
    let senderId: UUID?
    let senderName: String
    let content: String
    let isInvestmentCommand: Bool
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case isInvestmentCommand = "is_investment_command"
        case createdAt = "created_at"
    }
}

struct UserBalance: Codable {
    let id: UUID
    let userId: UUID
    let balance: Int
    let withdrawableAmount: Int
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case balance
        case withdrawableAmount = "withdrawable_amount"
        case updatedAt = "updated_at"
    }
}

struct WalletTransaction: Codable {
    let id: UUID
    let userId: UUID
    let transactionType: String
    let amount: Int
    let description: String
    let status: String
    let paymentMethod: String?
    let blockchainId: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case transactionType = "transaction_type"
        case amount
        case description
        case status
        case paymentMethod = "payment_method"
        case blockchainId = "blockchain_id"
        case createdAt = "created_at"
    }
}

struct UserGift: Codable {
    let id: UUID
    let userId: UUID
    let giftId: UUID?
    let recipientGroupId: UUID?
    let quantity: Int
    let totalCost: Int
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case giftId = "gift_id"
        case recipientGroupId = "recipient_group_id"
        case quantity
        case totalCost = "total_cost"
        case createdAt = "created_at"
    }
}

struct Subscription: Codable {
    let id: UUID
    let userId: UUID
    let authorId: UUID
    let startDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case authorId = "author_id"
        case startDate = "start_date"
    }
}

struct WeeklyRanking: Identifiable, Codable {
    let id: UUID
    let name: String
    let returnRate: Double
    let weekStart: Date
    let weekEnd: Date
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case returnRate = "return_rate"
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case createdAt = "created_at"
    }
}