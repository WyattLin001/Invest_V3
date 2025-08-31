import Foundation
import Supabase

/// 文章管理服務
/// 負責處理所有與文章相關的操作，包括CRUD、草稿管理、AI文章生成、互動等
@MainActor
class ArticleService: ObservableObject {
    static let shared = ArticleService()
    
    private var client: SupabaseClient {
        SupabaseService.shared.client
    }
    
    private init() {}
    
    // MARK: - 文章基本操作
    
    /// 獲取文章列表
    func getArticles(limit: Int = 50, offset: Int = 0, category: String? = nil) async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("📰 獲取文章列表 - limit: \(limit), offset: \(offset)", category: .database)
        
        var query = client
            .from("articles")
            .select()
            .eq("status", value: "published")
            .order("created_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
        
        // TODO: Implement category filtering when PostgrestTransformBuilder methods are available
        
        let response = try await query.execute()
        let articles = try JSONDecoder().decode([Article].self, from: response.data)
        
        Logger.info("✅ 成功獲取 \(articles.count) 篇文章", category: .database)
        return articles
    }
    
    /// 根據ID獲取文章
    func getArticleById(_ id: UUID) async throws -> Article {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("📖 獲取文章詳情: \(id)", category: .database)
        
        let response = try await client
            .from("articles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
        
        let article = try JSONDecoder().decode(Article.self, from: response.data)
        
        Logger.info("✅ 成功獲取文章: \(article.title)", category: .database)
        return article
    }
    
    /// 發布文章
    func publishArticle(_ article: Article) async throws -> Article {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("📝 發布文章: \(article.title)", category: .database)
        
        let publishedArticle = Article(
            id: article.id,
            title: article.title,
            author: currentUser.displayName ?? "匿名用戶",
            authorId: currentUser.id,
            summary: article.summary,
            fullContent: article.fullContent,
            bodyMD: article.bodyMD,
            category: article.category,
            readTime: article.readTime,
            likesCount: 0,
            commentsCount: 0,
            sharesCount: 0,
            isFree: article.isFree,
            status: .published,
            source: article.source,
            coverImageUrl: article.coverImageUrl,
            createdAt: Date(),
            updatedAt: Date(),
            keywords: article.keywords
        )
        
        try await client
            .from("articles")
            .insert(publishedArticle)
            .execute()
        
        Logger.info("✅ 文章發布成功: \(article.title)", category: .database)
        return publishedArticle
    }
    
    /// 更新文章
    func updateArticle(_ article: Article) async throws -> Article {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("✏️ 更新文章: \(article.title)", category: .database)
        
        let updatedArticle = Article(
            id: article.id,
            title: article.title,
            author: article.author,
            authorId: article.authorId,
            summary: article.summary,
            fullContent: article.fullContent,
            bodyMD: article.bodyMD,
            category: article.category,
            readTime: article.readTime,
            likesCount: article.likesCount,
            commentsCount: article.commentsCount,
            sharesCount: article.sharesCount,
            isFree: article.isFree,
            status: article.status,
            source: article.source,
            coverImageUrl: article.coverImageUrl,
            createdAt: article.createdAt,
            updatedAt: Date(),
            keywords: article.keywords
        )
        
        try await client
            .from("articles")
            .update(updatedArticle)
            .eq("id", value: article.id)
            .execute()
        
        Logger.info("✅ 文章更新成功: \(article.title)", category: .database)
        return updatedArticle
    }
    
    /// 刪除文章
    func deleteArticle(_ articleId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        // 檢查權限：只有作者可以刪除
        let article = try await getArticleById(articleId)
        guard article.authorId == currentUser.id else {
            Logger.error("❌ 權限不足：只有文章作者可以刪除文章", category: .database)
            throw DatabaseError.unauthorized("只有文章作者可以刪除文章")
        }
        
        Logger.info("🗑️ 刪除文章: \(articleId)", category: .database)
        
        try await client
            .from("articles")
            .delete()
            .eq("id", value: articleId)
            .execute()
        
        Logger.info("✅ 文章刪除成功", category: .database)
    }
    
    // MARK: - 草稿管理
    
    /// 保存草稿
    func saveDraft(_ draft: ArticleDraft) async throws -> ArticleDraft {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("💾 保存文章草稿: \(draft.title)", category: .database)
        
        let draftToSave = ArticleDraft(
            id: draft.id,
            title: draft.title,
            summary: draft.summary,
            bodyMD: draft.bodyMD,
            category: draft.category,
            keywords: draft.keywords,
            isFree: draft.isFree,
            coverImageURL: draft.coverImageURL,
            createdAt: draft.createdAt,
            updatedAt: Date()
        )
        
        // 檢查草稿是否已存在
        let response = try await client
            .from("article_drafts")
            .select("id")
            .eq("id", value: draft.id)
            .execute()
        
        let existingDrafts = try JSONDecoder().decode([DraftIdOnly].self, from: response.data)
        
        if existingDrafts.isEmpty {
            // 創建新草稿
            try await client
                .from("article_drafts")
                .insert(draftToSave)
                .execute()
        } else {
            // 更新現有草稿
            try await client
                .from("article_drafts")
                .update(draftToSave)
                .eq("id", value: draft.id)
                .execute()
        }
        
        Logger.info("✅ 草稿保存成功", category: .database)
        return draftToSave
    }
    
    /// 獲取用戶的草稿列表
    func getUserDrafts() async throws -> [ArticleDraft] {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("📋 獲取用戶草稿列表", category: .database)
        
        let response = try await client
            .from("article_drafts")
            .select()
            .eq("author_id", value: currentUser.id)
            .order("updated_at", ascending: false)
            .execute()
        
        let drafts = try JSONDecoder().decode([ArticleDraft].self, from: response.data)
        
        Logger.info("✅ 成功獲取 \(drafts.count) 個草稿", category: .database)
        return drafts
    }
    
    /// 刪除草稿
    func deleteDraft(_ draftId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("🗑️ 刪除草稿: \(draftId)", category: .database)
        
        try await client
            .from("article_drafts")
            .delete()
            .eq("id", value: draftId)
            .eq("author_id", value: currentUser.id)
            .execute()
        
        Logger.info("✅ 草稿刪除成功", category: .database)
    }
    
    // MARK: - 文章互動
    
    /// 按讚文章
    func likeArticle(_ articleId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("👍 按讚文章: \(articleId)", category: .database)
        
        // 檢查是否已按讚
        let response = try await client
            .from("article_likes")
            .select("id")
            .eq("article_id", value: articleId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        let existingLikes = try JSONDecoder().decode([LikeRecord].self, from: response.data)
        
        if !existingLikes.isEmpty {
            Logger.warning("⚠️ 用戶已經按讚過此文章", category: .database)
            return
        }
        
        // 獲取用戶資料以取得用戶名稱
        let userProfile = try await ServiceCoordinator.shared.core.getUserProfile(userId: currentUser.id)
        
        // 記錄按讚
        let like = ArticleLike(
            id: UUID(),
            articleId: articleId,
            userId: currentUser.id,
            userName: userProfile.displayName,
            createdAt: Date()
        )
        
        try await client
            .from("article_likes")
            .insert(like)
            .execute()
        
        // 更新文章按讚數
        try await client
            .from("articles")
            .update(["likes_count": "likes_count + 1"])
            .eq("id", value: articleId)
            .execute()
        
        Logger.info("✅ 文章按讚成功", category: .database)
    }
    
    /// 取消按讚
    func unlikeArticle(_ articleId: UUID) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        Logger.info("👎 取消按讚文章: \(articleId)", category: .database)
        
        try await client
            .from("article_likes")
            .delete()
            .eq("article_id", value: articleId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        // 更新文章按讚數
        try await client
            .from("articles")
            .update(["likes_count": "GREATEST(likes_count - 1, 0)"])
            .eq("id", value: articleId)
            .execute()
        
        Logger.info("✅ 取消按讚成功", category: .database)
    }
    
    /// 檢查用戶是否已按讚文章
    func isArticleLikedByUser(_ articleId: UUID) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        let currentUser = try await SupabaseService.shared.getCurrentUserAsync()
        
        let response = try await client
            .from("article_likes")
            .select("id")
            .eq("article_id", value: articleId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        let likes = try JSONDecoder().decode([LikeRecord].self, from: response.data)
        
        return !likes.isEmpty
    }
    
    // MARK: - 搜尋和推薦
    
    /// 搜尋文章
    func searchArticles(query: String, category: String? = nil, limit: Int = 20) async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔍 搜尋文章: \(query)", category: .database)
        
        var searchQuery = client
            .from("articles")
            .select()
            .eq("status", value: "published")
            .or("title.ilike.%\(query)%,summary.ilike.%\(query)%,full_content.ilike.%\(query)%")
            .limit(limit)
            .order("created_at", ascending: false)
        
        // TODO: Implement category filtering when PostgrestTransformBuilder methods are available
        
        let response = try await searchQuery.execute()
        let articles = try JSONDecoder().decode([Article].self, from: response.data)
        
        Logger.info("✅ 搜尋完成，找到 \(articles.count) 篇文章", category: .database)
        return articles
    }
    
    /// 獲取熱門關鍵字
    func getTrendingKeywords(limit: Int = 10) async throws -> [String] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("🔥 獲取熱門關鍵字", category: .database)
        
        // 這裡需要實現更複雜的邏輯來分析關鍵字趨勢
        // 暫時返回預設關鍵字
        let trendingKeywords = [
            "股票分析", "投資策略", "市場趨勢", "財務規劃", "風險管理",
            "技術分析", "基本面分析", "投資組合", "被動投資", "價值投資"
        ]
        
        return Array(trendingKeywords.prefix(limit))
    }
    
    /// 獲取推薦文章
    func getRecommendedArticles(limit: Int = 10) async throws -> [Article] {
        try SupabaseManager.shared.ensureInitialized()
        
        Logger.info("💡 獲取推薦文章", category: .database)
        
        // 基於按讚數和創建時間的簡單推薦演算法
        let response = try await client
            .from("articles")
            .select()
            .eq("status", value: "published")
            .gte("created_at", value: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
            .order("likes_count", ascending: false)
            .limit(limit)
            .execute()
        
        let articles = try JSONDecoder().decode([Article].self, from: response.data)
        
        Logger.info("✅ 獲取 \(articles.count) 篇推薦文章", category: .database)
        return articles
    }
}

// MARK: - 輔助數據結構

private struct DraftIdOnly: Codable {
    let id: UUID
}

private struct LikeRecord: Codable {
    let id: UUID
}

// MARK: - Using ArticleLike from ArticleInteraction.swift to avoid duplication