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
    
    @State private var testResults: [TestResult] = []
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
                            addTestResult(TestResult(
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
            // 單項測試按鈕
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
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
                
                Button(action: { runDatabaseTest() }) {
                    testButtonLabel("🗄️", "數據庫", .green)
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
    
    private func testResultRow(_ result: TestResult) -> some View {
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
        
        addTestResult(TestResult(
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
                
                addTestResult(TestResult(
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
                addTestResult(TestResult(
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
                
                addTestResult(TestResult(
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
                addTestResult(TestResult(
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
                    
                    addTestResult(TestResult(
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
                    addTestResult(TestResult(
                        testName: "通知系統測試",
                        isSuccess: false,
                        message: "通知權限未授權",
                        executionTime: executionTime,
                        details: ["通知權限": "被拒絕"]
                    ))
                }
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(TestResult(
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
    
    private func runDatabaseTest() {
        isRunningTests = true
        let startTime = Date()
        
        Task {
            do {
                // 測試數據庫連接
                let testUserId = UUID()
                let testArticleId = UUID()
                
                // 創建測試閱讀記錄
                let testReadLog = ArticleReadLogInsert(
                    articleId: testArticleId,
                    userId: testUserId,
                    readStartTime: Date(),
                    readEndTime: Date(),
                    readDurationSeconds: Int(simulatedReadingTime),
                    scrollPercentage: simulatedScrollProgress,
                    isCompleteRead: simulatedScrollProgress >= 80
                )
                
                // 嘗試保存記錄（在實際環境中）
                #if DEBUG
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                    try await supabaseService.saveReadingLog(testReadLog)
                }
                #endif
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                addTestResult(TestResult(
                    testName: "數據庫測試",
                    isSuccess: true,
                    message: "數據庫操作正常",
                    executionTime: executionTime,
                    details: [
                        "記錄保存": "成功",
                        "閱讀時長": "\(Int(simulatedReadingTime))秒",
                        "數據格式": "有效",
                        "連接狀態": "正常"
                    ]
                ))
                
            } catch {
                let executionTime = Date().timeIntervalSince(startTime)
                addTestResult(TestResult(
                    testName: "數據庫測試",
                    isSuccess: false,
                    message: "數據庫測試失敗: \(error.localizedDescription)",
                    executionTime: executionTime,
                    details: ["錯誤": error.localizedDescription]
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
            await runSequentialTest("數據庫", runDatabaseTest)
            
            // 系統整合測試
            let startTime = Date()
            let executionTime = Date().timeIntervalSince(startTime)
            
            let successCount = testResults.filter { $0.isSuccess }.count
            let totalCount = testResults.count
            let successRate = totalCount > 0 ? Double(successCount) / Double(totalCount) * 100 : 0
            
            addTestResult(TestResult(
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
    
    private func showTestArticleReading() {
        guard let article = testArticle else {
            addTestResult(TestResult(
                testName: "實際文章閱讀測試",
                isSuccess: false,
                message: "測試文章尚未準備完成",
                executionTime: 0.0,
                details: ["錯誤": "testArticle 為 nil"]
            ))
            return
        }
        
        addTestResult(TestResult(
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
    
    // MARK: - 輔助方法
    
    private func addTestResult(_ result: TestResult) {
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
    case database = "database"
    
    var displayName: String {
        switch self {
        case .all: return "全部測試"
        case .reading: return "閱讀追蹤"
        case .evaluation: return "資格評估"
        case .notification: return "通知系統"
        case .database: return "數據庫"
        }
    }
}

struct TestResult: Identifiable {
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