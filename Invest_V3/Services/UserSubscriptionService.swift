//
//  UserSubscriptionService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/2.
//  用戶訂閱狀態管理服務
//

import Foundation
import Combine

@MainActor
class UserSubscriptionService: ObservableObject {
    static let shared = UserSubscriptionService()
    
    @Published var isSubscribed: Bool = false
    @Published var subscriptionExpiryDate: Date?
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseService = SupabaseService.shared
    
    private init() {
        loadSubscriptionStatus()
    }
    
    // MARK: - 公開方法
    
    /// 檢查用戶是否可以訪問付費內容
    func canAccessPaidContent() -> Bool {
        return isSubscribed && !isSubscriptionExpired()
    }
    
    /// 檢查用戶是否可以閱讀特定文章
    func canReadArticle(_ article: Article) -> Bool {
        // 免費文章總是可以閱讀
        if article.isFree {
            return true
        }
        
        // 付費文章需要有效訂閱
        return canAccessPaidContent()
    }
    
    /// 獲取文章的可讀內容（用於預覽截斷）
    func getReadableContent(for article: Article) -> String {
        // 免費文章返回完整內容
        if article.isFree {
            return article.bodyMD ?? article.fullContent
        }
        
        // 付費文章：已訂閱返回完整內容，未訂閱返回預覽
        if canAccessPaidContent() {
            return article.bodyMD ?? article.fullContent
        } else {
            return getContentPreview(article.bodyMD ?? article.fullContent)
        }
    }
    
    /// 刷新訂閱狀態
    func refreshSubscriptionStatus() async {
        isLoading = true
        
        // Preview 模式安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Preview 模式：模擬訂閱狀態
            try? await Task.sleep(nanoseconds: 500_000_000)
            isSubscribed = true
            subscriptionExpiryDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30天後過期
            isLoading = false
            return
        }
        #endif
        
        do {
            let subscription = try await supabaseService.fetchUserSubscription()
            isSubscribed = subscription?.isActive ?? false
            subscriptionExpiryDate = subscription?.expiryDate
            
            print("✅ [UserSubscriptionService] 訂閱狀態更新: \(isSubscribed ? "已訂閱" : "未訂閱")")
            if let expiry = subscriptionExpiryDate {
                print("📅 [UserSubscriptionService] 到期時間: \(expiry)")
            }
        } catch {
            print("❌ [UserSubscriptionService] 獲取訂閱狀態失敗: \(error)")
            // 發生錯誤時假設未訂閱
            isSubscribed = false
            subscriptionExpiryDate = nil
        }
        
        isLoading = false
    }
    
    /// 訂閱平台會員
    func subscribeToPlatform() async throws {
        isLoading = true
        
        do {
            try await supabaseService.subscribeToPlatform()
            await refreshSubscriptionStatus()
            print("✅ [UserSubscriptionService] 訂閱成功")
        } catch {
            isLoading = false
            throw error
        }
    }
    
    // MARK: - 私有方法
    
    /// 載入本地儲存的訂閱狀態
    private func loadSubscriptionStatus() {
        // 從 UserDefaults 載入上次的訂閱狀態（快速顯示）
        isSubscribed = UserDefaults.standard.bool(forKey: "user_subscription_active")
        
        if let expiryTimestamp = UserDefaults.standard.object(forKey: "user_subscription_expiry") as? Date {
            subscriptionExpiryDate = expiryTimestamp
        }
        
        // 異步刷新最新狀態
        Task {
            await refreshSubscriptionStatus()
        }
    }
    
    /// 檢查訂閱是否已過期
    private func isSubscriptionExpired() -> Bool {
        guard let expiry = subscriptionExpiryDate else { return true }
        return Date() > expiry
    }
    
    /// 獲取內容預覽（前200字 + "..."）
    private func getContentPreview(_ content: String) -> String {
        // 移除 Markdown 標記符號以獲得純文本預覽
        let cleanContent = content
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 截取前200個字符
        let previewLength = 200
        if cleanContent.count <= previewLength {
            return cleanContent
        }
        
        let previewText = String(cleanContent.prefix(previewLength))
        return previewText + "..."
    }
    
    /// 保存訂閱狀態到本地
    private func saveSubscriptionStatus() {
        UserDefaults.standard.set(isSubscribed, forKey: "user_subscription_active")
        UserDefaults.standard.set(subscriptionExpiryDate, forKey: "user_subscription_expiry")
    }
}

// MARK: - 訂閱狀態數據模型

struct UserSubscription: Codable {
    let id: UUID
    let userId: UUID
    let subscriptionType: String
    let isActive: Bool
    let startDate: Date
    let expiryDate: Date
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subscriptionType = "subscription_type"
        case isActive = "is_active"
        case startDate = "start_date"
        case expiryDate = "expiry_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - SupabaseService 擴展

extension SupabaseService {
    /// 獲取用戶訂閱狀態
    func fetchUserSubscription() async throws -> UserSubscription? {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        let subscriptions: [UserSubscription] = try await client
            .from("user_subscriptions")
            .select()
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return subscriptions.first
    }
    
    /// 訂閱平台會員
    func subscribeToPlatform() async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await getCurrentUserAsync()
        
        // 檢查錢包餘額
        let balance = try await fetchWalletBalance()
        let subscriptionCost = 300.0 // 300 代幣
        
        guard balance >= subscriptionCost else {
            throw SupabaseError.unknown("餘額不足，需要 \(Int(subscriptionCost)) 代幣")
        }
        
        // 創建訂閱記錄
        let subscription = UserSubscriptionInsert(
            userId: currentUser.id.uuidString,
            subscriptionType: "platform_monthly",
            isActive: true,
            startDate: Date(),
            expiryDate: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30天
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let _: [UserSubscription] = try await client
            .from("user_subscriptions")
            .insert(subscription)
            .select()
            .execute()
            .value
        
        // 扣除錢包餘額
        try await createWalletTransaction(
            type: "subscription",
            amount: -subscriptionCost,
            description: "平台會員訂閱 (30天)",
            paymentMethod: "wallet"
        )
        
        print("✅ [SupabaseService] 平台訂閱成功")
    }
}

// MARK: - 訂閱數據插入模型

struct UserSubscriptionInsert: Codable {
    let userId: String
    let subscriptionType: String
    let isActive: Bool
    let startDate: Date
    let expiryDate: Date
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case subscriptionType = "subscription_type"
        case isActive = "is_active"
        case startDate = "start_date"
        case expiryDate = "expiry_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}