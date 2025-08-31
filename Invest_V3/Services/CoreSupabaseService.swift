import Foundation
import UIKit
import Supabase
import Auth

/// 核心Supabase服務
/// 只保留核心功能：用戶認證、用戶資料管理、基礎連線
@MainActor
class CoreSupabaseService: ObservableObject {
    static let shared = CoreSupabaseService()
    
    // 直接從 SupabaseManager 取得 client
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
            
            return SupabaseClient(
                supabaseURL: url,
                supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY3ODM1NDcsImV4cCI6MjAyMjM1OTU0N30.zNE_RyqnIyIlGHNI_yGF_mFVBbqA5W4WrPKPJHdGCqA"
            )
        }
        
        return client
    }
    
    private init() {}
    
    // MARK: - 用戶認證
    
    /// 註冊新用戶
    func signUp(email: String, password: String, displayName: String) async throws -> User {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔐 用戶註冊: \(email)", category: .auth)
        
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
        
        let user = authResponse.user
        
        // 創建用戶資料
        try await createUserProfile(user: user, displayName: displayName)
        
        Logger.info("✅ 用戶註冊成功", category: .auth)
        return user
    }
    
    /// 用戶登入
    func signIn(email: String, password: String) async throws -> User {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔐 用戶登入: \(email)", category: .auth)
        
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        Logger.info("✅ 用戶登入成功", category: .auth)
        return session.user
    }
    
    /// 用戶登出
    func signOut() async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🚪 用戶登出", category: .auth)
        
        try await client.auth.signOut()
        
        Logger.info("✅ 用戶登出成功", category: .auth)
    }
    
    /// 獲取當前用戶
    func getCurrentUser() -> User? {
        return client.auth.currentUser
    }
    
    /// 獲取當前用戶（異步版本）
    func getCurrentUserAsync() async throws -> User {
        guard let user = getCurrentUser() else {
            Logger.error("❌ 用戶未登入", category: .auth)
            throw SupabaseError.notAuthenticated
        }
        return user
    }
    
    /// 重置密碼
    func resetPassword(email: String) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔄 重置密碼: \(email)", category: .auth)
        
        try await client.auth.resetPasswordForEmail(email)
        
        Logger.info("✅ 密碼重置郵件已發送", category: .auth)
    }
    
    // MARK: - 用戶資料管理
    
    /// 創建用戶資料
    private func createUserProfile(user: User, displayName: String) async throws {
        Logger.info("📝 創建用戶資料", category: .database)
        
        let profile = UserProfileInsert(
            id: user.id.uuidString,
            username: user.email ?? "",
            displayName: displayName,
            email: user.email ?? "",
            avatarUrl: nil,
            bio: nil,
            investmentStyle: nil,
            riskLevel: nil,
            totalReturn: 0.0,
            performanceScore: 0.0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            lastActiveAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_profiles")
            .insert(profile)
            .execute()
        
        Logger.info("✅ 用戶資料創建成功", category: .database)
    }
    
    /// 獲取用戶資料
    func getUserProfile(userId: UUID) async throws -> UserProfile {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("👤 獲取用戶資料: \(userId)", category: .database)
        
        let response = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
        
        let profile = try JSONDecoder().decode(UserProfile.self, from: response.data)
        
        Logger.info("✅ 用戶資料獲取成功", category: .database)
        return profile
    }
    
    /// 更新用戶資料
    func updateUserProfile(_ profile: UserProfile) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("✏️ 更新用戶資料: \(profile.id)", category: .database)
        
        struct UserProfileUpdate: Codable {
            let displayName: String
            let username: String
            let bio: String
            let avatarUrl: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case username
                case bio
                case avatarUrl = "avatar_url"
                case updatedAt = "updated_at"
            }
        }
        
        let updateData = UserProfileUpdate(
            displayName: profile.displayName,
            username: profile.username,
            bio: profile.bio ?? "",
            avatarUrl: profile.avatarUrl ?? "",
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_profiles")
            .update(updateData)
            .eq("id", value: profile.id.uuidString)
            .execute()
        
        Logger.info("✅ 用戶資料更新成功", category: .database)
    }
    
    /// 更新用戶最後活動時間
    func updateUserLastActive() async throws {
        guard let currentUser = getCurrentUser() else { return }
        
        try await client
            .from("user_profiles")
            .update(["last_active_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: currentUser.id.uuidString)
            .execute()
    }
    
    // MARK: - 系統工具方法
    
    /// 測試資料庫連線
    func testConnection() async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔍 測試資料庫連線", category: .database)
        
        do {
            // 執行簡單查詢測試連線
            _ = try await client
                .from("user_profiles")
                .select("id")
                .limit(1)
                .execute()
            
            Logger.info("✅ 資料庫連線正常", category: .database)
            return true
        } catch {
            Logger.error("❌ 資料庫連線失敗: \(error)", category: .database)
            throw error
        }
    }
    
    /// 獲取系統健康狀態
    func getSystemHealth() async throws -> SystemHealth {
        let startTime = Date()
        
        // 測試資料庫連線
        let isConnected = try await testConnection()
        
        let responseTime = Date().timeIntervalSince(startTime)
        
        return SystemHealth(
            isConnected: isConnected,
            responseTime: responseTime,
            timestamp: Date()
        )
    }
}

// MARK: - 輔助數據結構

/// 用戶資料插入結構
private struct UserProfileInsert: Codable {
    let id: String
    let username: String
    let displayName: String
    let email: String
    let avatarUrl: String?
    let bio: String?
    let investmentStyle: String?
    let riskLevel: String?
    let totalReturn: Double
    let performanceScore: Double
    let createdAt: String
    let updatedAt: String
    let lastActiveAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, bio
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case investmentStyle = "investment_style"
        case riskLevel = "risk_level"
        case totalReturn = "total_return"
        case performanceScore = "performance_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastActiveAt = "last_active_at"
    }
}

/// 系統健康狀態
struct SystemHealth {
    let isConnected: Bool
    let responseTime: TimeInterval
    let timestamp: Date
}

/// 認證錯誤
enum AuthError: LocalizedError {
    case registrationFailed
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "用戶註冊失敗"
        }
    }
}