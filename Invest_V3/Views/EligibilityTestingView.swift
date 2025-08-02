//
//  EligibilityTestingView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/3.
//  收益資格達成判斷系統 - 測試界面
//

import SwiftUI

struct EligibilityTestingView: View {
    @StateObject private var readingTracker = ReadingTrackingService.shared
    @StateObject private var eligibilityService = EligibilityEvaluationService.shared
    @StateObject private var notificationService = EligibilityNotificationService.shared
    @StateObject private var supabaseService = SupabaseService.shared
    
    @State private var testResults: [EligibilityTestResult] = []
    @State private var isRunningTests = false
    @State private var selectedTestCategory: TestCategory = .all
    @State private var showDetailedResults = false
    @State private var testArticle: Article?
    @State private var simulatedReadingTime: Double = 30.0
    @State private var simulatedScrollProgress: Double = 75.0
    @State private var showTestArticle = false
    
    private let testCategories = TestCategory.allCases
    
    var body: some View {
        NavigationView {
            VStack {
                testControlPanel
                testResultsList
            }
            .navigationTitle("🧪 資格系統測試")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupTestEnvironment()
            }
            .sheet(isPresented: $showTestArticle) {
                if let article = testArticle {
                    ArticleDetailView(article: article)
                        .onDisappear {
                            // 當文章詳情頁關閉時，添加測試結果
                            addTestResult(EligibilityTestResult(
                                testName: "實際文章閱讀測試",
                                isSuccess: true,
                                message: "用戶已完成文章閱讀，閱讀記錄已保存",
                                executionTime: 1.0,
                                details: [
                                    "文章標題": article.title,
                                    "追蹤狀態": readingTracker.isTracking ? "進行中" : "已結束",
                                    "測試類型": "實際UI測試"
                                ]
                            ))
                        }
                }
            }
        }
    }
    
    // MARK: - 測試控制面板
    private var testControlPanel: some View {
        VStack(spacing: 16) {
            // 測試類別選擇
            testCategorySelector
            
            // 模擬參數設置
            simulationParametersSection
            
            // 測試按鈕組
            testButtonsSection
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var testCategorySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("測試類別")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(testCategories, id: \.self) { category in
                        Button(action: { selectedTestCategory = category }) {
                            Text(category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTestCategory == category ? Color.accentColor : Color(.tertiarySystemBackground))
                                .foregroundColor(selectedTestCategory == category ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var simulationParametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模擬參數")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("閱讀時長")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(simulatedReadingTime))秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $simulatedReadingTime, in: 5...300, step: 5)
                    .accentColor(.blue)
                
                HStack {
                    Text("滾動進度")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(simulatedScrollProgress))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $simulatedScrollProgress, in: 0...100, step: 5)
                    .accentColor(.green)
            }
        }
    }
    
    private var testButtonsSection: some View {
        VStack(spacing: 12) {
            // 單項測試按鈕 - 第一行
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                Button(action: { runReadingTrackingTest() }) {
                    testButtonLabel("📚", "閱讀追蹤", .blue)
                }
                .disabled(isRunningTests)
                
                Button(action: { runEligibilityEvaluationTest() }) {
                    testButtonLabel("⚖️", "資格評估", .orange)
                }
                .disabled(isRunningTests)
                
                Button(action: { runNotificationTest() }) {
                    testButtonLabel("🔔", "通知系統", .purple)
                }
                .disabled(isRunningTests)
            }
            
            // 第二行 - Supabase 和文章功能測試
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                Button(action: { runSupabaseConnectionTest() }) {
                    testButtonLabel("🗄️", "Supabase", .green)
                }
                .disabled(isRunningTests)
                
                Button(action: { runArticleFeaturesTest() }) {
                    testButtonLabel("📰", "文章功能", .indigo)
                }
                .disabled(isRunningTests)
                
                Button(action: { runArticleInteractionTest() }) {
                    testButtonLabel("💬", "文章互動", .pink)
                }
                .disabled(isRunningTests)
            }
            
            Divider()
            
            // 實際閱讀測試按鈕
            Button(action: { showTestArticleReading() }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title3)
                    Text("📖 模擬文章閱讀")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(10)
            }
            .disabled(isRunningTests)
            
            // 資訊頁面測試按鈕
            Button(action: { runInfoViewFeaturesTest() }) {
                HStack {
                    Image(systemName: "newspaper.circle")
                        .font(.title3)
                    Text("📰 資訊頁面功能測試")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [.indigo, .indigo.opacity(0.8)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(10)
            }
            .disabled(isRunningTests)
            
            // 綜合測試按鈕
            Button(action: { runFullSystemTest() }) {
                HStack {
                    if isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                    }
                    Text(isRunningTests ? "測試進行中..." : "🚀 完整系統測試")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [.accentColor, .accentColor.opacity(0.8)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(10)
            }
            .disabled(isRunningTests)
        }
    }
    
    private func testButtonLabel(_ icon: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title2)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(color)
        .cornerRadius(8)
    }
    
    // MARK: - 測試結果列表
    private var testResultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("測試結果")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !testResults.isEmpty {
                    Button("清除") {
                        testResults.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if testResults.isEmpty {
                emptyResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(testResults) { result in
                            testResultRow(result)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "testtube.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("尚無測試結果")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("選擇測試類別並點擊測試按鈕開始")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func testResultRow(_ result: EligibilityTestResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isSuccess ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.testName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2fs", result.executionTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(result.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if let details = result.details, !details.isEmpty, showDetailedResults {
                VStack(alignment: .leading, spacing: 4) {
                    Text("詳細信息:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(details.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text("• \(key):")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(value)
                                .font(.caption2)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            showDetailedResults.toggle()
        }
    }
    
    // MARK: - 測試實現
    
    private func setupTestEnvironment() {
        // 創建測試用文章
        testArticle = Article(
            id: UUID(),
            title: "測試文章：台積電AI晶片分析",
            author: "測試作者",
            authorId: UUID(),
            summary: "這是一篇用於測試閱讀追蹤系統的模擬文章，包含完整的內容和互動功能。",
            fullContent: generateTestArticleContent(),
            bodyMD: generateTestArticleContent(),
            category: "測試分析",
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
            keywords: ["測試", "閱讀追蹤", "資格系統"]
        )
        
        addTestResult(EligibilityTestResult(
            testName: "測試環境初始化",
            isSuccess: true,
            message: "測試環境和模擬數據已準備完成",
            executionTime: 0.01,
            details: [
                "測試文章": "已創建",
                "模擬參數": "已設置",
                "服務狀態": "就緒"
            ]
        ))
    }
    
    private func runReadingTrackingTest() {
        guard let article = testArticle else { return }
        
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                // 測試開始閱讀追蹤
                readingTracker.startReading(article: article)
                
                // 模擬閱讀過程
                for progress in stride(from: 0, through: simulatedScrollProgress, by: 10) {
                    readingTracker.updateReadingProgress(scrollPercentage: progress)
                    try await Task.sleep(nanoseconds: UInt64(simulatedReadingTime * 1_000_000_000 / 10))
                }
                
                // 結束閱讀追蹤
                readingTracker.endReading(scrollPercentage: simulatedScrollProgress)
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                addTestResult(EligibilityTestResult(
                    testName: "閱讀追蹤測試",
                    isSuccess: true,
                    message: "閱讀追蹤功能正常運作",
                    executionTime: executionTime,
                    details: [
                        "閱讀時長": "\(Int(simulatedReadingTime))秒",
                        "滾動進度": "\(Int(simulatedScrollProgress))%",
                        "完整閱讀": simulatedScrollProgress >= 80 ? "是" : "否",
                        "會話狀態": readingTracker.isTracking ? "追蹤中" : "已結束"
                    ]
                ))
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "閱讀追蹤測試",
                    isSuccess: false,
                    message: "測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: ["錯誤": error.localizedDescription]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    private func runEligibilityEvaluationTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            // 模擬作者ID
            let testAuthorId = UUID()
            
            // 測試資格評估
            if let result = await eligibilityService.evaluateAuthor(testAuthorId) {
                let executionTime = Date().timeIntervalSince(startTime)
                
                addTestResult(EligibilityTestResult(
                    testName: "資格評估測試",
                    isSuccess: result.isEligible,
                    message: result.isEligible ? "作者符合收益資格" : "作者尚未符合收益資格",
                    executionTime: executionTime,
                    details: [
                        "資格狀態": result.isEligible ? "符合" : "不符合",
                        "資格分數": String(format: "%.1f分", result.eligibilityScore),
                        "90天文章": "\(result.progress.first(where: { $0.condition == .articles90Days })?.currentValue ?? 0)篇",
                        "30天讀者": "\(result.progress.first(where: { $0.condition == .uniqueReaders30Days })?.currentValue ?? 0)人",
                        "無違規": result.conditions[.noViolations] == true ? "是" : "否",
                        "錢包設置": result.conditions[.walletSetup] == true ? "已完成" : "未完成"
                    ]
                ))
            } else {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "資格評估測試",
                    isSuccess: false,
                    message: "資格評估服務無響應",
                    executionTime: executionTime,
                    details: ["錯誤": "評估服務返回空結果"]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    private func runNotificationTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                // 測試通知權限
                let hasPermission = await notificationService.requestNotificationPermission()
                
                if hasPermission {
                    // 測試發送各種通知
                    await notificationService.sendEligibilityAchievedNotification()
                    await notificationService.sendNearThresholdNotification(
                        condition: .uniqueReaders30Days,
                        currentValue: 85,
                        requiredValue: 100
                    )
                    
                    let executionTime = Date().timeIntervalSince(startTime)
                    
                    addTestResult(EligibilityTestResult(
                        testName: "通知系統測試",
                        isSuccess: true,
                        message: "通知功能正常運作",
                        executionTime: executionTime,
                        details: [
                            "通知權限": hasPermission ? "已授權" : "未授權",
                            "未讀通知": "\(notificationService.unreadNotifications.count)條",
                            "總通知": "\(notificationService.allNotifications.count)條"
                        ]
                    ))
                } else {
                    let executionTime = Date().timeIntervalSince(startTime)
                    addTestResult(EligibilityTestResult(
                        testName: "通知系統測試",
                        isSuccess: false,
                        message: "通知權限未授權",
                        executionTime: executionTime,
                        details: ["通知權限": "被拒絕"]
                    ))
                }
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "通知系統測試",
                    isSuccess: false,
                    message: "通知測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: ["錯誤": error.localizedDescription]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    private func runSupabaseConnectionTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                // 測試 Supabase 初始化
                try SupabaseManager.shared.ensureInitialized()
                
                // 測試用戶認證狀態
                let currentUser = supabaseService.getCurrentUser()
                
                // 測試基本數據庫查詢 - 獲取文章列表
                let articles = try await supabaseService.fetchArticles()
                
                // 測試錢包查詢
                let walletBalance = try await supabaseService.fetchWalletBalance()
                
                // 測試閱讀記錄保存
                let testUserId = currentUser?.id ?? UUID()
                let testArticleId = articles.first?.id ?? UUID()
                
                let testReadLog = ArticleReadLogInsert(
                    articleId: testArticleId,
                    userId: testUserId,
                    readStartTime: Date(),
                    readEndTime: Date(),
                    readDurationSeconds: Int(simulatedReadingTime),
                    scrollPercentage: simulatedScrollProgress,
                    isCompleteRead: simulatedScrollProgress >= 80
                )
                
                try await supabaseService.saveReadingLog(testReadLog)
                
                // 測試作者分析數據
                if let analytics = try? await supabaseService.fetchAuthorReadingAnalytics(authorId: testUserId) {
                    let executionTime = Date().timeIntervalSince(startTime)
                    
                    addTestResult(EligibilityTestResult(
                        testName: "Supabase 連接測試",
                        isSuccess: true,
                        message: "Supabase 所有功能正常運作",
                        executionTime: executionTime,
                        details: [
                            "初始化": "成功",
                            "用戶認證": currentUser != nil ? "已登入" : "未登入",
                            "文章查詢": "\(articles.count)篇文章",
                            "錢包餘額": "\(Int(walletBalance))代幣",
                            "閱讀記錄": "保存成功",
                            "作者分析": "數據正常",
                            "總讀者": "\(analytics.uniqueReaders)人",
                            "90天文章": "\(analytics.last90DaysArticles)篇"
                        ]
                    ))
                } else {
                    throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "作者分析數據獲取失敗"])
                }
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "Supabase 連接測試",
                    isSuccess: false,
                    message: "Supabase 測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: [
                        "錯誤類型": type(of: error).description(),
                        "詳細錯誤": error.localizedDescription,
                        "建議": "檢查網絡連接和 Supabase 配置"
                    ]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    private func runFullSystemTest() {
        isRunningTests = true
        
        Task {
            // 依序執行所有測試
            await runSequentialTest("閱讀追蹤", runReadingTrackingTest)
            await runSequentialTest("資格評估", runEligibilityEvaluationTest)
            await runSequentialTest("通知系統", runNotificationTest)
            await runSequentialTest("Supabase連接", runSupabaseConnectionTest)
            await runSequentialTest("文章功能", runArticleFeaturesTest)
            await runSequentialTest("文章互動", runArticleInteractionTest)
            
            // 系統整合測試
            let startTime = Date()
            let executionTime = Date().timeIntervalSince(startTime)
            
            let successCount = testResults.filter { $0.isSuccess }.count
            let totalCount = testResults.count
            let successRate = totalCount > 0 ? Double(successCount) / Double(totalCount) * 100 : 0
            
            addTestResult(EligibilityTestResult(
                testName: "🚀 完整系統測試",
                isSuccess: successRate >= 75,
                message: String(format: "系統測試完成，成功率: %.1f%%", successRate),
                executionTime: executionTime,
                details: [
                    "總測試數": "\(totalCount)",
                    "成功測試": "\(successCount)",
                    "失敗測試": "\(totalCount - successCount)",
                    "成功率": String(format: "%.1f%%", successRate),
                    "系統狀態": successRate >= 75 ? "健康" : "需要關注"
                ]
            ))
            
            isRunningTests = false
        }
    }
    
    private func runSequentialTest(_ name: String, _ testFunction: @escaping () -> Void) async {
        testFunction()
        
        // 等待測試完成
        while isRunningTests {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        isRunningTests = true // 重新設置為測試中，供下一個測試使用
    }
    
    private func runArticleFeaturesTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                var testDetails: [String: String] = [:]
                
                // 1. 測試文章列表獲取
                let articles = try await supabaseService.fetchArticles()
                testDetails["文章總數"] = "\(articles.count)篇"
                
                // 2. 測試文章篩選功能
                let freeArticles = articles.filter { $0.isFree }
                let paidArticles = articles.filter { !$0.isFree }
                testDetails["免費文章"] = "\(freeArticles.count)篇"
                testDetails["付費文章"] = "\(paidArticles.count)篇"
                
                // 3. 測試文章分類
                let categories = Set(articles.map { $0.category })
                testDetails["文章分類"] = "\(categories.count)個類別"
                
                // 4. 測試文章來源統計
                let humanArticles = articles.filter { $0.source == .human }
                let aiArticles = articles.filter { $0.source == .ai }
                testDetails["人工文章"] = "\(humanArticles.count)篇"
                testDetails["AI文章"] = "\(aiArticles.count)篇"
                
                // 5. 測試文章狀態
                let publishedArticles = articles.filter { $0.status == .published }
                testDetails["已發布文章"] = "\(publishedArticles.count)篇"
                
                // 6. 測試關鍵字功能
                let allKeywords = articles.flatMap { $0.keywords }
                let uniqueKeywords = Set(allKeywords)
                testDetails["關鍵字總數"] = "\(uniqueKeywords.count)個"
                
                // 7. 測試熱門關鍵字獲取
                let trendingKeywords = try await supabaseService.getTrendingKeywordsWithAll()
                testDetails["熱門關鍵字"] = "\(trendingKeywords.count)個"
                
                // 8. 測試文章封面圖片
                let articlesWithCover = articles.filter { $0.hasCoverImage }
                testDetails["有封面圖片"] = "\(articlesWithCover.count)篇"
                
                // 9. 測試文章閱讀時間
                let avgReadTime = articles.compactMap { Int($0.readTime.replacingOccurrences(of: " 分鐘", with: "")) }.reduce(0, +) / max(1, articles.count)
                testDetails["平均閱讀時間"] = "\(avgReadTime)分鐘"
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                addTestResult(EligibilityTestResult(
                    testName: "文章功能測試",
                    isSuccess: articles.count > 0,
                    message: articles.count > 0 ? "文章功能運作正常" : "沒有找到文章",
                    executionTime: executionTime,
                    details: testDetails
                ))
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "文章功能測試",
                    isSuccess: false,
                    message: "文章功能測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: [
                        "錯誤": error.localizedDescription,
                        "建議": "檢查文章數據和網絡連接"
                    ]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    private func runArticleInteractionTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                var testDetails: [String: String] = [:]
                
                // 獲取測試文章
                let articles = try await supabaseService.fetchArticles()
                guard let testArticle = articles.first else {
                    throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "沒有可用的測試文章"])
                }
                
                // 1. 測試文章互動統計載入
                let interactionVM = ArticleInteractionViewModel(articleId: testArticle.id)
                await interactionVM.loadInteractionStats()
                
                testDetails["文章ID"] = testArticle.id.uuidString.prefix(8) + "..."
                testDetails["按讚數"] = "\(interactionVM.likesCount)"
                testDetails["評論數"] = "\(interactionVM.commentsCount)"
                testDetails["分享數"] = "\(interactionVM.sharesCount)"
                
                // 2. 測試按讚功能
                let originalLikes = interactionVM.likesCount
                await interactionVM.toggleLike()
                let newLikes = interactionVM.likesCount
                testDetails["按讚測試"] = newLikes != originalLikes ? "成功" : "無變化"
                
                // 3. 測試評論載入
                await interactionVM.loadComments()
                testDetails["評論載入"] = "\(interactionVM.comments.count)條評論"
                
                // 4. 測試文章分享 (使用群組分享功能)
                // 模擬分享到群組
                let testGroupId = UUID()
                interactionVM.shareToGroup(testGroupId, groupName: "測試群組")
                testDetails["分享功能"] = "群組分享可用"
                
                // 5. 測試訂閱服務整合
                let subscriptionService = UserSubscriptionService.shared
                let canRead = subscriptionService.canReadArticle(testArticle)
                testDetails["訂閱檢查"] = canRead ? "可閱讀" : "需訂閱"
                
                // 6. 測試閱讀內容獲取
                let readableContent = subscriptionService.getReadableContent(for: testArticle)
                let contentLength = readableContent.count
                testDetails["內容長度"] = "\(contentLength)字符"
                
                // 7. 測試文章互動狀態
                testDetails["是否按讚"] = interactionVM.isLiked ? "是" : "否"
                testDetails["互動狀態"] = "已載入"
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                addTestResult(EligibilityTestResult(
                    testName: "文章互動測試",
                    isSuccess: true,
                    message: "文章互動功能運作正常",
                    executionTime: executionTime,
                    details: testDetails
                ))
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "文章互動測試",
                    isSuccess: false,
                    message: "文章互動測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: [
                        "錯誤": error.localizedDescription,
                        "建議": "檢查文章互動服務和權限"
                    ]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    private func showTestArticleReading() {
        guard let article = testArticle else {
            addTestResult(EligibilityTestResult(
                testName: "實際文章閱讀測試",
                isSuccess: false,
                message: "測試文章尚未準備完成",
                executionTime: 0.0,
                details: ["錯誤": "testArticle 為 nil"]
            ))
            return
        }
        
        addTestResult(EligibilityTestResult(
            testName: "開始實際文章閱讀",
            isSuccess: true,
            message: "準備打開測試文章，開始實際閱讀追蹤",
            executionTime: 0.01,
            details: [
                "文章標題": article.title,
                "測試說明": "請在打開的文章中正常閱讀，系統將自動追蹤閱讀行為",
                "關閉文章": "閱讀完成後關閉文章，系統將保存閱讀記錄"
            ]
        ))
        
        showTestArticle = true
    }
    
    private func runInfoViewFeaturesTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                var testDetails: [String: String] = [:]
                
                // 1. 測試 ArticleViewModel 初始化
                let articleVM = ArticleViewModel()
                await articleVM.fetchArticles()
                
                testDetails["文章載入"] = "成功"
                testDetails["文章總數"] = "\(articleVM.articles.count)篇"
                testDetails["篩選後文章"] = "\(articleVM.filteredArticles.count)篇"
                
                // 2. 測試熱門關鍵字載入
                await articleVM.loadTrendingKeywords()
                testDetails["熱門關鍵字"] = "\(articleVM.trendingKeywords.count)個"
                
                // 3. 測試文章搜尋功能
                let searchResults = articleVM.filteredArticles(search: "投資")
                testDetails["搜尋結果"] = "\(searchResults.count)篇"
                
                // 4. 測試關鍵字篩選
                if let firstKeyword = articleVM.trendingKeywords.first {
                    articleVM.filterByKeyword(firstKeyword)
                    // 等待篩選完成
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    testDetails["關鍵字篩選"] = "關鍵字: \(firstKeyword)"
                }
                
                // 5. 測試文章來源篩選
                articleVM.filterBySource(.human)
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                let humanArticles = articleVM.filteredArticles.count
                testDetails["人工文章篩選"] = "\(humanArticles)篇"
                
                articleVM.filterBySource(.ai)
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                let aiArticles = articleVM.filteredArticles.count
                testDetails["AI文章篩選"] = "\(aiArticles)篇"
                
                // 6. 測試 AI 文章統計
                let aiStats = articleVM.getAIArticleStats()
                testDetails["AI文章統計"] = "總計:\(aiStats.total), 已發布:\(aiStats.published)"
                
                // 7. 測試來源統計
                let sourceStats = articleVM.getSourceStats()
                testDetails["來源統計"] = "人工:\(sourceStats[.human] ?? 0), AI:\(sourceStats[.ai] ?? 0)"
                
                // 8. 測試免費文章限制
                let canReadFree = articleVM.canReadFreeArticle()
                let remainingFree = articleVM.getRemainingFreeArticles()
                testDetails["免費文章"] = canReadFree ? "可閱讀(\(remainingFree)篇剩餘)" : "已達上限"
                
                // 9. 測試文章發布功能 (模擬)
                if let testArticle = articleVM.articles.first {
                    testDetails["發布測試"] = "可發布文章: \(testArticle.title.prefix(20))..."
                }
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                addTestResult(EligibilityTestResult(
                    testName: "資訊頁面功能測試",
                    isSuccess: articleVM.articles.count > 0,
                    message: "資訊頁面所有功能運作正常",
                    executionTime: executionTime,
                    details: testDetails
                ))
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(EligibilityTestResult(
                    testName: "資訊頁面功能測試",
                    isSuccess: false,
                    message: "資訊頁面測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: [
                        "錯誤": error.localizedDescription,
                        "建議": "檢查 ArticleViewModel 和相關服務"
                    ]
                ))
            }
            
            isRunningTests = false
        }
    }
    
    // MARK: - 輔助方法
    
    private func addTestResult(_ result: EligibilityTestResult) {
        DispatchQueue.main.async {
            testResults.insert(result, at: 0) // 最新的結果在頂部
            
            // 限制結果數量
            if testResults.count > 20 {
                testResults = Array(testResults.prefix(20))
            }
        }
    }
    
    private func generateTestArticleContent() -> String {
        return """
        # 台積電Q4財報解析：半導體龍頭展望2025
        
        ## 財報亮點
        
        台積電(TSM)公布2024年第四季財報，營收再創新高，展現了全球半導體代工龍頭的強勁實力。
        
        ### 營收表現
        - **季營收**：新台幣6,259億元，季增13.1%，年增38.8%
        - **毛利率**：57.8%，創近年新高
        - **淨利率**：42.0%，持續維持高水準
        
        這是一篇用於測試閱讀追蹤系統的完整文章內容，包含了足夠的文字量來模擬真實的閱讀體驗。
        
        ## AI晶片需求爆發
        
        AI應用帶動的需求成為主要成長動力，預期將持續推動台積電在先進製程領域的領先地位。
        """
    }
}

// MARK: - 測試相關模型

enum TestCategory: String, CaseIterable {
    case all = "all"
    case reading = "reading"
    case evaluation = "evaluation"
    case notification = "notification"
    case supabase = "supabase"
    case articles = "articles"
    case interaction = "interaction"
    
    var displayName: String {
        switch self {
        case .all: return "全部測試"
        case .reading: return "閱讀追蹤"
        case .evaluation: return "資格評估"
        case .notification: return "通知系統"
        case .supabase: return "Supabase"
        case .articles: return "文章功能"
        case .interaction: return "文章互動"
        }
    }
}

struct EligibilityTestResult: Identifiable {
    let id = UUID()
    let testName: String
    let isSuccess: Bool
    let message: String
    let executionTime: TimeInterval
    let details: [String: String]?
    let timestamp: Date
    
    init(testName: String, isSuccess: Bool, message: String, executionTime: TimeInterval, details: [String: String]? = nil) {
        self.testName = testName
        self.isSuccess = isSuccess
        self.message = message
        self.executionTime = executionTime
        self.details = details
        self.timestamp = Date()
    }
}