//
//  ArticleViewModel.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import Foundation
import Auth

@MainActor
class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var filteredArticles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedKeyword = "全部"
    @Published var selectedSource: ArticleSource? = nil
    @Published var showAIArticlesOnly = false
    @Published var trendingKeywords: [String] = ["全部"]
    @Published var freeArticlesReadToday = 0
    
    private let maxFreeArticlesPerDay = 3
    
    func fetchArticles() async {
        // Preview 安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Preview 模式：使用模擬數據
            isLoading = true
            
            // 模擬加載時間
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            articles = [
                Article(
                    id: UUID(),
                    title: "模擬文章 1",
                    author: "測試作者",
                    authorId: UUID(),
                    summary: "這是一個測試文章的摘要",
                    fullContent: "# 測試內容\n\n這是測試文章的內容。",
                    bodyMD: "# 測試內容\n\n這是測試文章的內容。",
                    category: "投資分析",
                    readTime: "3 分鐘",
                    likesCount: 15,
                    commentsCount: 5,
                    sharesCount: 2,
                    isFree: true,
                    status: .published,
                    source: .human,
                    createdAt: Date(),
                    updatedAt: Date(),
                    keywords: ["測試", "投資"]
                ),
                Article(
                    id: UUID(),
                    title: "AI 市場分析：今日焦點股票推薦",
                    author: "AI 投資分析師",
                    authorId: UUID(),
                    summary: "基於最新市場數據和技術指標，AI 為您分析今日值得關注的投資機會",
                    fullContent: "# AI 市場分析\n\n根據今日市場表現...",
                    bodyMD: "# AI 市場分析\n\n根據今日市場表現...",
                    category: "每日市場分析",
                    readTime: "5 分鐘",
                    likesCount: 28,
                    commentsCount: 12,
                    sharesCount: 7,
                    isFree: false,
                    status: .published,
                    source: .ai,
                    createdAt: Date().addingTimeInterval(-3600),
                    updatedAt: Date().addingTimeInterval(-3600),
                    keywords: ["AI分析", "市場", "股票推薦"]
                )
            ]
            filteredArticles = articles
            trendingKeywords = ["全部", "投資", "股票", "基金", "分析"]
            error = nil
            isLoading = false
            return
        }
        #endif
        
        isLoading = true
        do {
            articles = try await SupabaseService.shared.fetchArticles()
            filteredArticles = articles
            error = nil
            
            // 同時載入熱門關鍵字
            await loadTrendingKeywords()
        } catch {
            self.error = error
            print("❌ Fetch failed: \(error)")
        }
        isLoading = false
    }
    
    /// 載入熱門關鍵字
    func loadTrendingKeywords() async {
        do {
            let keywords = try await SupabaseService.shared.getTrendingKeywordsWithAll()
            trendingKeywords = keywords
            print("✅ 載入熱門關鍵字成功: \(keywords)")
        } catch {
            print("❌ 載入熱門關鍵字失敗: \(error)")
            // 使用預設關鍵字
            trendingKeywords = ["全部", "投資分析", "市場趨勢", "股票", "基金", "風險管理"]
        }
    }
    
    func filteredArticles(search: String) -> [Article] {
        var result = filteredArticles
        
        // 搜尋篩選
        if !search.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(search) ||
                $0.summary.localizedCaseInsensitiveContains(search) ||
                $0.author.localizedCaseInsensitiveContains(search)
            }
        }
        
        return result
    }
    
    func filterByKeyword(_ keyword: String) {
        selectedKeyword = keyword
        Task {
            await applyKeywordFilter()
        }
    }
    
    /// 按文章來源篩選
    func filterBySource(_ source: ArticleSource?) {
        selectedSource = source
        Task {
            await applySourceFilter()
        }
    }
    
    /// 切換顯示僅 AI 文章
    func toggleAIArticlesOnly() {
        showAIArticlesOnly.toggle()
        Task {
            await applyFilters()
        }
    }
    
    private func applyKeywordFilter() async {
        await applyFilters()
    }
    
    private func applySourceFilter() async {
        await applyFilters()
    }
    
    /// 統一應用所有篩選條件
    private func applyFilters() async {
        var result = articles
        
        // 按來源篩選
        if let selectedSource = selectedSource {
            result = result.filter { $0.source == selectedSource }
        }
        
        // 僅顯示 AI 文章
        if showAIArticlesOnly {
            result = result.filter { $0.isAIGenerated }
        }
        
        // 按關鍵字篩選
        if selectedKeyword != "全部" {
            result = result.filter { article in
                article.keywords.contains { $0.localizedCaseInsensitiveContains(selectedKeyword) } ||
                article.title.localizedCaseInsensitiveContains(selectedKeyword) ||
                article.summary.localizedCaseInsensitiveContains(selectedKeyword)
            }
        }
        
        // 只顯示已發布的文章（除非是管理員模式）
        result = result.filter { $0.status == .published }
        
        filteredArticles = result
        print("✅ 篩選完成，顯示 \(filteredArticles.count) 篇文章")
    }
    
    func canReadFreeArticle() -> Bool {
        return freeArticlesReadToday < maxFreeArticlesPerDay
    }
    
    func markFreeArticleAsRead() {
        freeArticlesReadToday += 1
    }
    
    func getRemainingFreeArticles() -> Int {
        return max(0, maxFreeArticlesPerDay - freeArticlesReadToday)
    }
    
    /// 獲取 AI 文章統計
    func getAIArticleStats() -> (total: Int, published: Int, draft: Int) {
        let aiArticles = articles.filter { $0.isAIGenerated }
        let published = aiArticles.filter { $0.status == .published }.count
        let draft = aiArticles.filter { $0.status == .draft }.count
        
        return (total: aiArticles.count, published: published, draft: draft)
    }
    
    /// 獲取文章來源統計
    func getSourceStats() -> [ArticleSource: Int] {
        var stats: [ArticleSource: Int] = [:]
        
        for source in ArticleSource.allCases {
            stats[source] = articles.filter { $0.source == source }.count
        }
        
        return stats
    }
    
    // MARK: - Article Publishing
    func publishArticle(from draft: ArticleDraft) async throws -> Article {
        isLoading = true
        do {
            let article = try await SupabaseService.shared.publishArticle(from: draft)
            // 發布成功後，重新獲取文章列表
            await fetchArticles()
            error = nil
            return article
        } catch {
            self.error = error
            throw error
        }
    }
}

struct ArticleData: Identifiable, Decodable {
    let id: UUID
    let category: String
    let title: String
    let summary: String
    let author: String
    let readTime: String
    let likes: Int
    let comments: Int
    let isFree: Bool
}




