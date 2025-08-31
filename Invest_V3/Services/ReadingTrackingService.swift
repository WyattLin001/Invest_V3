//
//  ReadingTrackingService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/2.
//  閱讀追蹤系統 - 用於收益資格達成判斷系統
//

import Foundation
import Combine

@MainActor
class ReadingTrackingService: ObservableObject {
    static let shared = ReadingTrackingService()
    
    @Published var isTracking = false
    @Published var currentReadingSession: ReadingSession?
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseService = SupabaseService.shared
    private var readingTimer: Timer?
    
    private init() {}
    
    // MARK: - 閱讀會話管理
    
    /// 開始追蹤文章閱讀
    func startReading(article: Article) {
        // Preview 模式安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("📚 [ReadingTrackingService] Preview模式 - 模擬開始閱讀追蹤")
            currentReadingSession = ReadingSession(
                articleId: article.id,
                articleTitle: article.title,
                authorId: article.authorId ?? UUID(), // 提供默認值
                startTime: Date()
            )
            isTracking = true
            return
        }
        #endif
        
        guard let currentUser = supabaseService.getCurrentUser() else {
            print("❌ [ReadingTrackingService] 用戶未登入，無法追蹤閱讀")
            return
        }
        
        // 結束之前的閱讀會話
        if let existingSession = currentReadingSession {
            Task {
                await endReading(session: existingSession, scrollPercentage: 0)
            }
        }
        
        // 創建新的閱讀會話
        currentReadingSession = ReadingSession(
            articleId: article.id,
            articleTitle: article.title,
            authorId: article.authorId ?? UUID(), // 提供默認值
            startTime: Date()
        )
        
        isTracking = true
        
        // 開始計時器，每30秒更新一次閱讀時間
        startReadingTimer()
        
        print("📚 [ReadingTrackingService] 開始追蹤閱讀: \\(article.title)")
    }
    
    /// 更新閱讀進度（滾動百分比）
    func updateReadingProgress(scrollPercentage: Double) {
        guard var session = currentReadingSession else { return }
        
        session.maxScrollPercentage = max(session.maxScrollPercentage, scrollPercentage)
        currentReadingSession = session
        
        // 如果滾動超過80%，標記為完整閱讀
        if scrollPercentage >= 80.0 {
            session.isCompleteRead = true
            currentReadingSession = session
        }
    }
    
    /// 結束閱讀追蹤
    func endReading(scrollPercentage: Double = 0) {
        guard let session = currentReadingSession else { return }
        
        Task {
            await endReading(session: session, scrollPercentage: scrollPercentage)
        }
    }
    
    private func endReading(session: ReadingSession, scrollPercentage: Double) async {
        // 更新最終的滾動百分比
        var finalSession = session
        finalSession.endTime = Date()
        finalSession.maxScrollPercentage = max(finalSession.maxScrollPercentage, scrollPercentage)
        
        // 計算閱讀時長
        let duration = finalSession.endTime!.timeIntervalSince(finalSession.startTime)
        finalSession.readDurationSeconds = Int(duration)
        
        // 判斷是否為完整閱讀
        if finalSession.maxScrollPercentage >= 80.0 {
            finalSession.isCompleteRead = true
        }
        
        // 保存閱讀記錄到數據庫
        await saveReadingLog(session: finalSession)
        
        // 清理會話狀態
        currentReadingSession = nil
        isTracking = false
        stopReadingTimer()
        
        print("📚 [ReadingTrackingService] 結束閱讀追蹤: \\(finalSession.articleTitle), 時長: \\(Int(duration))秒, 滾動: \\(Int(finalSession.maxScrollPercentage))%")
    }
    
    // MARK: - 計時器管理
    
    private func startReadingTimer() {
        stopReadingTimer() // 確保沒有重複的計時器
        
        readingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateReadingTime()
            }
        }
    }
    
    private func stopReadingTimer() {
        readingTimer?.invalidate()
        readingTimer = nil
    }
    
    private func updateReadingTime() {
        guard var session = currentReadingSession else { return }
        
        let currentDuration = Date().timeIntervalSince(session.startTime)
        session.readDurationSeconds = Int(currentDuration)
        currentReadingSession = session
    }
    
    // MARK: - 數據庫操作
    
    /// 保存閱讀記錄到數據庫
    private func saveReadingLog(session: ReadingSession) async {
        // Preview 模式安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("📚 [ReadingTrackingService] Preview模式 - 模擬保存閱讀記錄")
            return
        }
        #endif
        
        guard let currentUser = supabaseService.getCurrentUser() else {
            print("❌ [ReadingTrackingService] 用戶未登入，無法保存閱讀記錄")
            return
        }
        
        let readLog = ArticleReadLogInsert(
            userId: currentUser.id,
            articleId: session.articleId,
            authorId: session.authorId,
            readingDuration: session.readDurationSeconds,
            scrollPercentage: session.maxScrollPercentage,
            isCompleted: session.isCompleteRead,
            sessionStart: session.startTime,
            sessionEnd: session.endTime
        )
        
        do {
            try await supabaseService.saveReadingLog(readLog)
            print("✅ [ReadingTrackingService] 閱讀記錄保存成功")
            
            // 通知其他服務更新統計數據
            NotificationCenter.default.post(
                name: NSNotification.Name("ReadingLogSaved"),
                object: nil,
                userInfo: [
                    "articleId": session.articleId,
                    "authorId": session.authorId,
                    "readDuration": session.readDurationSeconds,
                    "isCompleteRead": session.isCompleteRead
                ]
            )
            
        } catch {
            print("❌ [ReadingTrackingService] 保存閱讀記錄失敗: \\(error)")
        }
    }
    
    /// 獲取文章的閱讀統計
    func getArticleReadingStats(articleId: UUID) async -> ReadingStats? {
        do {
            return try await supabaseService.fetchArticleReadingStats(articleId: articleId)
        } catch {
            print("❌ [ReadingTrackingService] 獲取閱讀統計失敗: \\(error)")
            return nil
        }
    }
    
    /// 獲取作者的閱讀分析數據
    func getAuthorReadingAnalytics(authorId: UUID) async -> AuthorReadingAnalytics? {
        do {
            return try await supabaseService.fetchAuthorReadingAnalytics(authorId: authorId)
        } catch {
            print("❌ [ReadingTrackingService] 獲取作者閱讀分析失敗: \\(error)")
            return nil
        }
    }
    
    /// 檢查用戶今日是否已閱讀過該文章
    func hasUserReadArticleToday(articleId: UUID) async -> Bool {
        guard let currentUser = supabaseService.getCurrentUser() else { return false }
        
        do {
            return try await supabaseService.checkUserReadArticleToday(
                userId: currentUser.id,
                articleId: articleId
            )
        } catch {
            print("❌ [ReadingTrackingService] 檢查今日閱讀記錄失敗: \\(error)")
            return false
        }
    }
    
    // MARK: - 清理方法
    
    deinit {
        // Timer cleanup will happen automatically when the object is deallocated
        readingTimer?.invalidate()
        readingTimer = nil
    }
}

// MARK: - 閱讀會話模型
struct ReadingSession {
    let articleId: UUID
    let articleTitle: String
    let authorId: UUID
    let startTime: Date
    var endTime: Date?
    var readDurationSeconds: Int = 0
    var maxScrollPercentage: Double = 0.0
    var isCompleteRead: Bool = false
    
    var formattedDuration: String {
        let minutes = readDurationSeconds / 60
        let seconds = readDurationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - SupabaseService 擴展
extension SupabaseService {
    /// 保存閱讀記錄
    func saveReadingLog(_ readLog: ArticleReadLogInsert) async throws {
        try SupabaseManager.shared.ensureInitialized()
        
        let _: [ArticleReadLog] = try await client
            .from("article_read_logs")
            .insert(readLog)
            .select()
            .execute()
            .value
        
        print("✅ [SupabaseService] 閱讀記錄保存成功")
    }
    
    /// 獲取文章閱讀統計
    func fetchArticleReadingStats(articleId: UUID) async throws -> ReadingStats {
        try SupabaseManager.shared.ensureInitialized()
        
        // 使用 RPC 函數獲取統計數據
        let response = try await client
            .rpc("get_article_reading_stats", params: ["article_id": articleId.uuidString])
            .execute()
        
        let stats = try JSONDecoder().decode(ReadingStats.self, from: response.data)
        return stats
    }
    
    
    /// 檢查用戶今日是否已閱讀過該文章
    func checkUserReadArticleToday(userId: UUID, articleId: UUID) async throws -> Bool {
        try SupabaseManager.shared.ensureInitialized()
        
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let logs: [ArticleReadLog] = try await client
            .from("article_read_logs")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("article_id", value: articleId.uuidString)
            .gte("created_at", value: today.toISOString())
            .lte("created_at", value: tomorrow.toISOString())
            .limit(1)
            .execute()
            .value
        
        return !logs.isEmpty
    }
}

// MARK: - Date 擴展
private extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}