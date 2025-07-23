//
//  ArticleViewModel.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import Foundation
import Supabase

@MainActor
class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var filteredArticles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedKeyword = "全部"
    @Published var trendingKeywords: [String] = ["全部"]
    @Published var freeArticlesReadToday = 0
    
    private let maxFreeArticlesPerDay = 3
    
    func fetchArticles() async {
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
    
    private func applyKeywordFilter() async {
        if selectedKeyword == "全部" {
            filteredArticles = articles
        } else {
            do {
                // 使用 SupabaseService 的關鍵字篩選功能
                filteredArticles = try await SupabaseService.shared.fetchArticlesByKeyword(selectedKeyword)
            } catch {
                print("❌ 關鍵字篩選失敗: \(error)")
                // 發生錯誤時使用本地篩選作為備選方案
                filteredArticles = articles.filter { article in
                    article.keywords.contains { $0.localizedCaseInsensitiveContains(selectedKeyword) } ||
                    article.title.localizedCaseInsensitiveContains(selectedKeyword) ||
                    article.summary.localizedCaseInsensitiveContains(selectedKeyword)
                }
            }
        }
        print("✅ 關鍵字篩選完成，篩選到 \(filteredArticles.count) 篇文章")
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




