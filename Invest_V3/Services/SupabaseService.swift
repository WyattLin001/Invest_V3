//
//  SupabaseService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        guard let url = URL(string: "https://your-project.supabase.co"),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("Missing Supabase configuration")
        }
        
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Authentication
    func signInAnonymously() async throws {
        try await client.auth.signInAnonymously()
    }
    
    func getCurrentUser() -> User? {
        return client.auth.currentUser
    }
    
    // MARK: - Investment Groups
    func fetchInvestmentGroups() async throws -> [InvestmentGroup] {
        let response: [InvestmentGroup] = try await client.database
            .from("investment_groups")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    func createInvestmentGroup(_ group: InvestmentGroup) async throws {
        try await client.database
            .from("investment_groups")
            .insert(group)
            .execute()
    }
    
    func joinGroup(groupId: UUID, userId: UUID) async throws {
        let membership = GroupMembership(groupId: groupId, userId: userId)
        try await client.database
            .from("group_members")
            .insert(membership)
            .execute()
    }
    
    // MARK: - Articles
    func fetchArticles() async throws -> [Article] {
        let response: [Article] = try await client.database
            .from("articles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    func createArticle(_ article: Article) async throws {
        try await client.database
            .from("articles")
            .insert(article)
            .execute()
    }
    
    func likeArticle(articleId: UUID, userId: UUID) async throws {
        let like = ArticleLike(articleId: articleId, userId: userId)
        try await client.database
            .from("article_likes")
            .insert(like)
            .execute()
    }
    
    func unlikeArticle(articleId: UUID, userId: UUID) async throws {
        try await client.database
            .from("article_likes")
            .delete()
            .eq("article_id", value: articleId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    // MARK: - Chat Messages
    func fetchChatMessages(groupId: UUID) async throws -> [ChatMessage] {
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
        try await client.database
            .from("chat_messages")
            .insert(message)
            .execute()
    }
    
    // MARK: - Portfolio
    func fetchUserPortfolio(userId: UUID) async throws -> [Portfolio] {
        let response: [Portfolio] = try await client.database
            .from("user_portfolios")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response
    }
    
    func executeTransaction(_ transaction: PortfolioTransaction) async throws {
        try await client.database
            .from("portfolio_transactions")
            .insert(transaction)
            .execute()
    }
    
    // MARK: - Wallet & Payments
    func fetchUserBalance(userId: UUID) async throws -> UserBalance? {
        let response: [UserBalance] = try await client.database
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response.first
    }
    
    func createWalletTransaction(_ transaction: WalletTransaction) async throws {
        try await client.database
            .from("wallet_transactions")
            .insert(transaction)
            .execute()
    }
    
    func purchaseGift(userId: UUID, giftId: UUID, recipientGroupId: UUID, quantity: Int, totalCost: Int) async throws {
        let gift = UserGift(
            userId: userId,
            giftId: giftId,
            recipientGroupId: recipientGroupId,
            quantity: quantity,
            totalCost: totalCost
        )
        try await client.database
            .from("user_gifts")
            .insert(gift)
            .execute()
    }
    
    // MARK: - Subscriptions
    func createSubscription(userId: UUID, authorId: UUID) async throws {
        let subscription = Subscription(userId: userId, authorId: authorId)
        try await client.database
            .from("subscriptions")
            .insert(subscription)
            .execute()
    }
    
    func fetchUserSubscriptions(userId: UUID) async throws -> [Subscription] {
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
        let response: [WeeklyRanking] = try await client.database
            .from("weekly_rankings")
            .select()
            .order("return_rate", ascending: false)
            .limit(10)
            .execute()
            .value
        return response
    }
}

// MARK: - Supporting Models
struct GroupMembership: Codable {
    let groupId: UUID
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
    }
}

struct ArticleLike: Codable {
    let articleId: UUID
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case articleId = "article_id"
        case userId = "user_id"
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