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
    @Published var selectedCategory = "全部"
    @Published var freeArticlesReadToday = 0
    
    private let maxFreeArticlesPerDay = 3
    
    func fetchArticles() async {
        isLoading = true
        do {
            articles = try await SupabaseService.shared.fetchArticles()
            filteredArticles = articles
            error = nil
        } catch {
            self.error = error
            print("❌ Fetch failed: \(error)")
        }
        isLoading = false
    }
    
    func publishArticle(from draft: ArticleDraft) async {
        isLoading = true
        do {
            // 使用新的 Supabase 服務發布文章
            let article = try await SupabaseService.shared.publishArticle(from: draft)
            
            // 保存到本地列表
            articles.insert(article, at: 0)
            // 重新篩選文章列表
            filteredArticles = articles
            
            print("✅ 文章發布成功: \(article.title)")
        } catch {
            self.error = error
            print("❌ 文章發布失敗: \(error)")
        }
        isLoading = false
    }
    
    private func calculateReadTime(content: String) -> String {
        // 計算中文字符數和英文單詞數
        let chineseCharacterCount = content.filter { character in
            let scalar = character.unicodeScalars.first!
            return CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}").contains(scalar)
        }.count
        
        let englishWordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !$0.allSatisfy { char in
                let scalar = char.unicodeScalars.first!
                return CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}").contains(scalar)
            }}.count
        
        // 中文按字計算，英文按詞計算，每分鐘 300 字/詞
        let totalWords = chineseCharacterCount + englishWordCount
        let minutes = max(1, totalWords / 300)
        return "\(minutes) 分鐘"
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
    
    func filterByCategory(_ category: String) {
        selectedCategory = category
        Task {
            await fetchArticlesByCategory(category)
        }
    }
    
    func fetchArticlesByCategory(_ category: String) async {
        isLoading = true
        do {
            let fetchedArticles = try await SupabaseService.shared.fetchArticlesByCategory(category)
            articles = fetchedArticles
            filteredArticles = fetchedArticles
        } catch {
            self.error = error
            print("❌ 獲取分類文章失敗: \(error)")
        }
        isLoading = false
    }
    
    private func applyFilter() {
        if selectedCategory != "全部" {
            filteredArticles = articles.filter { $0.category == selectedCategory }
        } else {
            filteredArticles = articles
        }
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




