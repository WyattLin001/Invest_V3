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
    
    // MARK: - 文章點讚排行榜相關屬性
    @Published var articlesLikesRanking: [ArticleLikesRanking] = []
    @Published var selectedLikesRankingPeriod: RankingPeriod = .weekly
    @Published var isLoadingLikesRanking = false
    @Published var likesRankingError: String?
    
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
                    title: "台積電Q4財報解析：半導體龍頭展望2025",
                    author: "專業投資分析師",
                    authorId: UUID(),
                    summary: "深度解析台積電最新財報數據，評估其在AI晶片領域的競爭優勢與未來成長潛力",
                    fullContent: """
                    # 台積電Q4財報解析：半導體龍頭展望2025
                    
                    ## 財報亮點
                    
                    台積電(TSM)公布2024年第四季財報，營收再創新高，展現了全球半導體代工龍頭的強勁實力。
                    
                    ### 營收表現
                    - **季營收**：新台幣6,259億元，季增13.1%，年增38.8%
                    - **毛利率**：57.8%，創近年新高
                    - **淨利率**：42.0%，持續維持高水準
                    
                    ### 技術節點表現
                    
                    **先進製程持續領先**
                    - 3奈米製程營收佔比達15%
                    - 5奈米製程營收佔比達32%
                    - 7奈米製程營收佔比達17%
                    
                    ## AI晶片需求爆發
                    
                    ### 高效能運算(HPC)平台
                    
                    AI應用帶動的需求成為主要成長動力：
                    
                    1. **資料中心需求**：ChatGPT、Claude等大型語言模型訓練需求
                    2. **邊緣AI晶片**：智慧手機、汽車、IoT設備AI功能
                    3. **客製化晶片**：大型科技公司自研AI晶片需求
                    
                    ### 主要客戶動態
                    
                    - **Apple**：iPhone 15系列A17 Pro晶片採用3奈米製程
                    - **NVIDIA**：H100、H200等AI訓練晶片主要供應商
                    - **AMD**：MI300系列AI晶片代工合作
                    
                    ## 2025年展望
                    
                    ### 成長動力
                    
                    **技術領先優勢**
                    - 2奈米製程預計2025年下半年量產
                    - CoWoS先進封裝產能持續擴充
                    - 與客戶共同開發下一代AI晶片架構
                    
                    **市場機會**
                    - 全球AI市場規模預計達$1.8兆
                    - 汽車電子化加速，車用晶片需求成長
                    - 5G基礎建設持續推進
                    
                    ### 挑戰與風險
                    
                    **競爭壓力**
                    - Samsung積極追趕先進製程技術
                    - Intel Foundry業務重新布局
                    - 中國大陸晶圓代工廠商快速發展
                    
                    **地緣政治風險**
                    - 中美科技戰持續影響
                    - 台海局勢對供應鏈影響
                    - 各國半導體自主化政策
                    
                    ## 投資建議
                    
                    ### 評價分析
                    - **目標價**：新台幣1,200元
                    - **本益比**：20.5倍(合理區間18-25倍)
                    - **投資評等**：買進
                    
                    ### 關鍵觀察指標
                    1. 先進製程營收佔比變化
                    2. HPC平台營收成長率
                    3. 毛利率維持水準
                    4. 資本支出與產能擴充計劃
                    
                    **風險提醒**：半導體產業具有週期性特徵，請留意景氣循環變化對股價的影響。
                    """,
                    bodyMD: """
                    # 台積電Q4財報解析：半導體龍頭展望2025
                    
                    ## 財報亮點
                    
                    台積電(TSM)公布2024年第四季財報，營收再創新高，展現了全球半導體代工龍頭的強勁實力。
                    
                    ### 營收表現
                    - **季營收**：新台幣6,259億元，季增13.1%，年增38.8%
                    - **毛利率**：57.8%，創近年新高
                    - **淨利率**：42.0%，持續維持高水準
                    
                    ### 技術節點表現
                    
                    **先進製程持續領先**
                    - 3奈米製程營收佔比達15%
                    - 5奈米製程營收佔比達32%
                    - 7奈米製程營收佔比達17%
                    
                    ## AI晶片需求爆發
                    
                    ### 高效能運算(HPC)平台
                    
                    AI應用帶動的需求成為主要成長動力：
                    
                    1. **資料中心需求**：ChatGPT、Claude等大型語言模型訓練需求
                    2. **邊緣AI晶片**：智慧手機、汽車、IoT設備AI功能
                    3. **客製化晶片**：大型科技公司自研AI晶片需求
                    
                    ### 主要客戶動態
                    
                    - **Apple**：iPhone 15系列A17 Pro晶片採用3奈米製程
                    - **NVIDIA**：H100、H200等AI訓練晶片主要供應商
                    - **AMD**：MI300系列AI晶片代工合作
                    
                    ## 2025年展望
                    
                    ### 成長動力
                    
                    **技術領先優勢**
                    - 2奈米製程預計2025年下半年量產
                    - CoWoS先進封裝產能持續擴充
                    - 與客戶共同開發下一代AI晶片架構
                    
                    **市場機會**
                    - 全球AI市場規模預計達$1.8兆
                    - 汽車電子化加速，車用晶片需求成長
                    - 5G基礎建設持續推進
                    
                    ### 挑戰與風險
                    
                    **競爭壓力**
                    - Samsung積極追趕先進製程技術
                    - Intel Foundry業務重新布局
                    - 中國大陸晶圓代工廠商快速發展
                    
                    **地緣政治風險**
                    - 中美科技戰持續影響
                    - 台海局勢對供應鏈影響
                    - 各國半導體自主化政策
                    
                    ## 投資建議
                    
                    ### 評價分析
                    - **目標價**：新台幣1,200元
                    - **本益比**：20.5倍(合理區間18-25倍)
                    - **投資評等**：買進
                    
                    ### 關鍵觀察指標
                    1. 先進製程營收佔比變化
                    2. HPC平台營收成長率
                    3. 毛利率維持水準
                    4. 資本支出與產能擴充計劃
                    
                    **風險提醒**：半導體產業具有週期性特徵，請留意景氣循環變化對股價的影響。
                    """,
                    category: "個股分析",
                    readTime: "5 分鐘",
                    likesCount: 156,
                    commentsCount: 42,
                    sharesCount: 28,
                    isFree: true,
                    status: .published,
                    source: .human,
                    coverImageUrl: "https://images.unsplash.com/photo-1518186285589-2f7649de83e0?w=400&h=250&fit=crop",
                    createdAt: Date(),
                    updatedAt: Date(),
                    keywords: ["台積電", "財報", "半導體", "AI晶片"]
                ),
                Article(
                    id: UUID(),
                    title: "AI 市場分析：今日焦點股票推薦",
                    author: "AI 投資分析師",
                    authorId: UUID(),
                    summary: "基於最新市場數據和技術指標，AI 為您分析今日值得關注的投資機會，包含科技股與傳統產業的投資建議",
                    fullContent: """
                    # AI 市場分析：今日焦點股票推薦
                    
                    ## 市場概況
                    
                    根據今日市場表現和技術指標分析，我們為您挑選出以下值得關注的投資機會。本次分析基於大數據演算法，結合基本面和技術面雙重篩選。
                    
                    ## 科技股推薦
                    
                    ### 1. 人工智慧概念股
                    
                    **NVIDIA (NVDA)**
                    - 目標價：$850
                    - 推薦理由：AI 晶片需求持續強勁，ChatGPT 等應用推動成長
                    - 風險評級：中等
                    
                    **Microsoft (MSFT)**
                    - 目標價：$420
                    - 推薦理由：Azure 雲端服務與 AI 整合，營收穩定成長
                    - 風險評級：低
                    
                    ### 2. 電動車產業鏈
                    
                    **Tesla (TSLA)**
                    - 目標價：$280
                    - 推薦理由：FSD 技術突破，中國市場表現強勁
                    - 風險評級：高
                    
                    ## 傳統產業機會
                    
                    ### 能源轉型概念
                    
                    綠能產業在政策支持下持續發展，建議關注：
                    
                    1. **太陽能設備製造商**
                    2. **風力發電相關企業**
                    3. **電池技術公司**
                    
                    ## 風險提醒
                    
                    請注意以下市場風險：
                    - 聯準會利率政策變化
                    - 地緣政治緊張局勢
                    - 通膨數據波動
                    
                    ## 投資建議
                    
                    建議採用分批進場策略，控制單一持股比重不超過總資產的10%。請根據個人風險承受能力調整投資組合。
                    
                    *本分析僅供參考，不構成投資建議。投資有風險，請謹慎評估。*
                    """,
                    bodyMD: """
                    # AI 市場分析：今日焦點股票推薦
                    
                    ## 市場概況
                    
                    根據今日市場表現和技術指標分析，我們為您挑選出以下值得關注的投資機會。本次分析基於大數據演算法，結合基本面和技術面雙重篩選。
                    
                    ## 科技股推薦
                    
                    ### 1. 人工智慧概念股
                    
                    **NVIDIA (NVDA)**
                    - 目標價：$850
                    - 推薦理由：AI 晶片需求持續強勁，ChatGPT 等應用推動成長
                    - 風險評級：中等
                    
                    **Microsoft (MSFT)**
                    - 目標價：$420
                    - 推薦理由：Azure 雲端服務與 AI 整合，營收穩定成長
                    - 風險評級：低
                    
                    ### 2. 電動車產業鏈
                    
                    **Tesla (TSLA)**
                    - 目標價：$280
                    - 推薦理由：FSD 技術突破，中國市場表現強勁
                    - 風險評級：高
                    
                    ## 傳統產業機會
                    
                    ### 能源轉型概念
                    
                    綠能產業在政策支持下持續發展，建議關注：
                    
                    1. **太陽能設備製造商**
                    2. **風力發電相關企業**
                    3. **電池技術公司**
                    
                    ## 風險提醒
                    
                    請注意以下市場風險：
                    - 聯準會利率政策變化
                    - 地緣政治緊張局勢
                    - 通膨數據波動
                    
                    ## 投資建議
                    
                    建議採用分批進場策略，控制單一持股比重不超過總資產的10%。請根據個人風險承受能力調整投資組合。
                    
                    *本分析僅供參考，不構成投資建議。投資有風險，請謹慎評估。*
                    """,
                    category: "每日市場分析",
                    readTime: "7 分鐘",
                    likesCount: 89,
                    commentsCount: 23,
                    sharesCount: 15,
                    isFree: false,
                    status: .published,
                    source: .ai,
                    coverImageUrl: "https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400&h=250&fit=crop",
                    createdAt: Date().addingTimeInterval(-3600),
                    updatedAt: Date().addingTimeInterval(-3600),
                    keywords: ["AI分析", "市場", "股票推薦", "科技股"]
                ),
                Article(
                    id: UUID(),
                    title: "2025年投資展望：掌握全球經濟新趨勢",
                    author: "資深市場分析師",
                    authorId: UUID(),
                    summary: "全面分析2025年投資環境，從地緣政治、利率政策到新興科技，為投資者提供策略指引",
                    fullContent: "# 2025年投資展望\n\n隨著全球經濟格局的變化...",
                    bodyMD: "# 2025年投資展望\n\n隨著全球經濟格局的變化...",
                    category: "市場展望",
                    readTime: "8 分鐘",
                    likesCount: 234,
                    commentsCount: 67,
                    sharesCount: 45,
                    isFree: true,
                    status: .published,
                    source: .human,
                    coverImageUrl: "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=400&h=250&fit=crop",
                    createdAt: Date().addingTimeInterval(-7200),
                    updatedAt: Date().addingTimeInterval(-7200),
                    keywords: ["投資展望", "2025", "經濟趨勢", "策略"]
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
            trendingKeywords = ["全部", "股票", "投資", "市場分析", "基金", "風險管理"]
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
    
    // MARK: - Article Likes Ranking
    
    /// 獲取文章點讚排行榜
    func fetchArticlesLikesRanking() async {
        isLoadingLikesRanking = true
        likesRankingError = nil
        
        do {
            let rankings = try await SupabaseService.shared.fetchArticleLikesRanking(
                period: selectedLikesRankingPeriod
            )
            articlesLikesRanking = rankings
            print("✅ [ArticleViewModel] 成功獲取 \(rankings.count) 篇文章的點讚排行榜")
        } catch {
            likesRankingError = error.localizedDescription
            articlesLikesRanking = []
            print("❌ [ArticleViewModel] 獲取點讚排行榜失敗: \(error)")
        }
        
        isLoadingLikesRanking = false
    }
    
    /// 切換點讚排行榜時間週期
    func switchLikesRankingPeriod(to period: RankingPeriod) {
        selectedLikesRankingPeriod = period
        Task {
            await fetchArticlesLikesRanking()
        }
    }
    
    /// 初始化時載入點讚排行榜
    func initializeLikesRanking() async {
        await fetchArticlesLikesRanking()
    }
    
    /// 根據 ID 獲取文章（用於排行榜點擊）
    func getArticleById(_ id: UUID) async -> Article? {
        do {
            return try await SupabaseService.shared.fetchArticleById(id)
        } catch {
            print("❌ [ArticleViewModel] 獲取文章失敗: \(error)")
            return nil
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




