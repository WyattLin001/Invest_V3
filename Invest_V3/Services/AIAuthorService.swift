//
//  AIAuthorService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/1.
//  AI 作者系統管理服務 - 管理 AI 生成文章的作者帳號和相關配置
//

import Foundation
import Supabase

// MARK: - AI 作者配置
struct AIAuthorConfig {
    static let systemEmail = "ai-analyst@invest.app"
    static let systemUsername = "ai_analyst"
    static let systemDisplayName = "AI 投資分析師"
    static let systemBio = "每日為您提供專業的投資市場分析和建議，基於最新市場數據和趨勢進行深度解讀。"
    static let systemAvatarURL = "https://ui-avatars.com/api/?name=AI&background=0D8ABC&color=fff&size=256"
    static let systemWebsite = "https://invest.app/ai-analyst"
    static let systemLocation = "台灣"
    static let systemSpecializations = ["市場分析", "技術分析", "風險評估", "投資策略", "經濟趨勢"]
    static let systemInvestmentPhilosophy = "基於數據驅動的投資分析，結合技術指標和基本面研究，為投資者提供客觀、及時的市場洞察。"
}

// MARK: - AI 作者管理服務
@MainActor
class AIAuthorService: ObservableObject {
    static let shared = AIAuthorService()
    
    // MARK: - Published Properties
    @Published var aiAuthorProfile: UserProfile?
    @Published var isInitialized = false
    @Published var initializationError: String?
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    
    private init() {
        Task {
            await initializeAIAuthor()
        }
    }
    
    // MARK: - 公共方法
    
    /// 初始化 AI 作者帳號
    func initializeAIAuthor() async {
        do {
            // 檢查 AI 作者是否已存在
            if let existingProfile = try await getAIAuthorProfile() {
                aiAuthorProfile = existingProfile
                print("✅ [AIAuthorService] AI 作者帳號已存在: \(existingProfile.displayName)")
            } else {
                // 創建 AI 作者帳號
                let newProfile = try await createAIAuthorProfile()
                aiAuthorProfile = newProfile
                print("✅ [AIAuthorService] 已創建 AI 作者帳號: \(newProfile.displayName)")
            }
            
            isInitialized = true
            initializationError = nil
            
        } catch {
            print("❌ [AIAuthorService] 初始化 AI 作者失敗: \(error.localizedDescription)")
            initializationError = error.localizedDescription
            isInitialized = false
        }
    }
    
    /// 獲取 AI 作者 ID
    func getAIAuthorId() -> UUID? {
        return aiAuthorProfile?.id
    }
    
    /// 獲取 AI 作者顯示名稱
    func getAIAuthorDisplayName() -> String {
        return aiAuthorProfile?.displayName ?? AIAuthorConfig.systemDisplayName
    }
    
    /// 檢查是否為 AI 作者
    func isAIAuthor(_ authorId: UUID?) -> Bool {
        guard let authorId = authorId,
              let aiAuthorId = aiAuthorProfile?.id else {
            return false
        }
        return authorId == aiAuthorId
    }
    
    /// 更新 AI 作者統計數據
    func updateAIAuthorStats() async throws {
        guard let aiAuthorId = aiAuthorProfile?.id else {
            throw AIAuthorError.profileNotFound
        }
        
        // 獲取 AI 作者的文章統計
        let articleCount = try await getAIArticleCount()
        
        // 更新作者檔案
        try await updateAIAuthorProfile(articleCount: articleCount)
        
        print("✅ [AIAuthorService] 已更新 AI 作者統計: \(articleCount) 篇文章")
    }
    
    // MARK: - 私有方法
    
    /// 獲取現有的 AI 作者檔案
    private func getAIAuthorProfile() async throws -> UserProfile? {
        let profiles: [UserProfile] = try await supabaseService.client
            .from("user_profiles")
            .select()
            .eq("email", value: AIAuthorConfig.systemEmail)
            .execute()
            .value
        
        return profiles.first
    }
    
    /// 創建 AI 作者檔案
    private func createAIAuthorProfile() async throws -> UserProfile {
        struct AIAuthorInsert: Codable {
            let email: String
            let username: String
            let displayName: String
            let bio: String
            let avatarUrl: String
            let website: String
            let location: String
            let specializations: [String]
            let investmentPhilosophy: String
            let isVerified: Bool
            let status: String
            let userId: String
            let createdAt: Date
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case email
                case username
                case displayName = "display_name"
                case bio
                case avatarUrl = "avatar_url"
                case website
                case location
                case specializations
                case investmentPhilosophy = "investment_philosophy"
                case isVerified = "is_verified"
                case status
                case userId = "user_id"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let aiAuthorData = AIAuthorInsert(
            email: AIAuthorConfig.systemEmail,
            username: AIAuthorConfig.systemUsername,
            displayName: AIAuthorConfig.systemDisplayName,
            bio: AIAuthorConfig.systemBio,
            avatarUrl: AIAuthorConfig.systemAvatarURL,
            website: AIAuthorConfig.systemWebsite,
            location: AIAuthorConfig.systemLocation,
            specializations: AIAuthorConfig.systemSpecializations,
            investmentPhilosophy: AIAuthorConfig.systemInvestmentPhilosophy,
            isVerified: true, // AI 作者預設為已驗證
            status: "active",
            userId: "ai-system-\(UUID().uuidString)", // 生成唯一的系統用戶 ID
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let insertedProfile: UserProfile = try await supabaseService.client
            .from("user_profiles")
            .insert(aiAuthorData)
            .select()
            .single()
            .execute()
            .value
        
        return insertedProfile
    }
    
    /// 獲取 AI 文章數量
    private func getAIArticleCount() async throws -> Int {
        guard let aiAuthorId = aiAuthorProfile?.id else { return 0 }
        
        struct ArticleCount: Codable {
            let count: Int
        }
        
        let result: [ArticleCount] = try await supabaseService.client
            .from("articles")
            .select("count", head: false, count: .exact)
            .eq("author_id", value: aiAuthorId.uuidString)
            .eq("source", value: "ai")
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    /// 更新 AI 作者檔案統計
    private func updateAIAuthorProfile(articleCount: Int) async throws {
        guard let aiAuthorId = aiAuthorProfile?.id else { return }
        
        struct ProfileUpdate: Codable {
            let article_count: Int
            let updated_at: String
        }
        
        let updateData = ProfileUpdate(
            article_count: articleCount,
            updated_at: Date().ISO8601Format()
        )
        
        try await supabaseService.client
            .from("user_profiles")
            .update(updateData)
            .eq("id", value: aiAuthorId.uuidString)
            .execute()
    }
}

// MARK: - AI 作者錯誤類型
enum AIAuthorError: LocalizedError {
    case profileNotFound
    case initializationFailed(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "找不到 AI 作者檔案"
        case .initializationFailed(let message):
            return "AI 作者初始化失敗: \(message)"
        case .updateFailed(let message):
            return "更新 AI 作者失敗: \(message)"
        }
    }
}

// MARK: - UserProfile 擴展
extension UserProfile {
    /// 是否為 AI 作者
    var isAIAuthor: Bool {
        return email == AIAuthorConfig.systemEmail
    }
    
    /// 是否為系統帳號
    var isSystemAccount: Bool {
        return username.hasPrefix("ai_") || userId.hasPrefix("ai-system-")
    }
}