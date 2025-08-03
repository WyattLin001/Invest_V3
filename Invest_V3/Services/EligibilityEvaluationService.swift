//
//  EligibilityEvaluationService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/2.
//  收益資格評估引擎 - 用於收益資格達成判斷系統
//

import Foundation
import Combine

@MainActor
class EligibilityEvaluationService: ObservableObject {
    static let shared = EligibilityEvaluationService()
    
    @Published var isEvaluating = false
    @Published var lastEvaluationDate: Date?
    @Published var nextEvaluationDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseService = SupabaseService.shared
    private var evaluationTimer: Timer?
    
    // 資格條件常數
    private struct EligibilityThresholds {
        static let minArticlesIn90Days = 1
        static let minUniqueReadersIn30Days = 100
        static let noViolationsRequired = true
        static let walletSetupRequired = true
    }
    
    private init() {
        setupDailyEvaluationTimer()
        loadLastEvaluationDate()
    }
    
    // MARK: - 公開方法
    
    /// 立即評估單個作者的資格狀態
    func evaluateAuthor(_ authorId: UUID) async throws -> EligibilityEvaluationResult? {
        isEvaluating = true
        
        do {
            // 獲取作者的閱讀分析數據
            let analytics = try await supabaseService.fetchAuthorReadingAnalytics(authorId: authorId)
            
            // 檢查錢包設置狀態
            let hasWalletSetup = try await supabaseService.checkAuthorWalletSetup(authorId: authorId)
            
            // 檢查違規記錄
            let hasViolations = try await supabaseService.checkAuthorViolations(authorId: authorId)
            
            // 評估每個條件
            let conditions = evaluateConditions(
                analytics: analytics,
                hasWalletSetup: hasWalletSetup,
                hasViolations: hasViolations
            )
            
            // 計算綜合分數
            let eligibilityScore = calculateEligibilityScore(conditions: conditions)
            
            // 判斷是否符合資格
            let isEligible = conditions.values.allSatisfy { $0 }
            
            // 生成通知
            let notifications = generateNotifications(
                isEligible: isEligible,
                analytics: analytics,
                hasWalletSetup: hasWalletSetup,
                hasViolations: hasViolations,
                conditions: conditions
            )
            
            // 創建或更新資格狀態
            let status = AuthorEligibilityStatusInsert(
                authorId: authorId,
                isEligible: isEligible,
                last90DaysArticles: analytics.last90DaysArticles,
                last30DaysUniqueReaders: analytics.last30DaysUniqueReaders,
                hasViolations: hasViolations,
                hasWalletSetup: hasWalletSetup,
                eligibilityScore: eligibilityScore
            )
            
            // 保存到數據庫
            try await supabaseService.saveAuthorEligibilityStatus(status)
            
            print("✅ [EligibilityEvaluationService] 作者資格評估完成: \(authorId), 符合資格: \(isEligible)")
            
            // 創建評估結果
            let fullStatus = AuthorEligibilityStatus(
                id: UUID(),
                authorId: authorId,
                isEligible: isEligible,
                last90DaysArticles: analytics.last90DaysArticles,
                last30DaysUniqueReaders: analytics.last30DaysUniqueReaders,
                hasViolations: hasViolations,
                hasWalletSetup: hasWalletSetup,
                eligibilityScore: eligibilityScore,
                lastEvaluatedAt: Date(),
                nextEvaluationAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                notifications: notifications,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            isEvaluating = false
            return EligibilityEvaluationResult(status: fullStatus)
            
        } catch {
            print("❌ [EligibilityEvaluationService] 評估作者資格失敗: \(error)")
            isEvaluating = false
            return nil
        }
    }
    
    /// 獲取作者當前的資格狀態
    func getAuthorEligibilityStatus(_ authorId: UUID) async -> AuthorEligibilityStatus? {
        do {
            return try await supabaseService.fetchAuthorEligibilityStatus(authorId: authorId)
        } catch {
            print("❌ [EligibilityEvaluationService] 獲取作者資格狀態失敗: \(error)")
            return nil
        }
    }
    
    /// 執行每日批量評估（所有作者）
    func performDailyEvaluation() async {
        print("🔄 [EligibilityEvaluationService] 開始每日批量評估")
        isEvaluating = true
        
        do {
            // 獲取所有需要評估的作者列表
            let authorIds = try await supabaseService.fetchAllAuthorIds()
            
            var successCount = 0
            var failureCount = 0
            
            // 批量評估每個作者
            for authorId in authorIds {
                do {
                    if let _ = try await evaluateAuthor(authorId) {
                        successCount += 1
                    } else {
                        failureCount += 1
                    }
                } catch {
                    failureCount += 1
                }
                
                // 短暫延遲，避免過於頻繁的數據庫操作
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            print("✅ [EligibilityEvaluationService] 每日評估完成: 成功 \(successCount), 失敗 \(failureCount)")
            
            // 更新最後評估時間
            lastEvaluationDate = Date()
            nextEvaluationDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            saveLastEvaluationDate()
            
        } catch {
            print("❌ [EligibilityEvaluationService] 每日評估失敗: \(error)")
        }
        
        isEvaluating = false
    }
    
    // MARK: - 私有方法
    
    /// 評估各項資格條件
    private func evaluateConditions(
        analytics: AuthorReadingAnalytics,
        hasWalletSetup: Bool,
        hasViolations: Bool
    ) -> [EligibilityCondition: Bool] {
        return [
            .articles90Days: analytics.last90DaysArticles >= EligibilityThresholds.minArticlesIn90Days,
            .uniqueReaders30Days: analytics.last30DaysUniqueReaders >= EligibilityThresholds.minUniqueReadersIn30Days,
            .noViolations: !hasViolations,
            .walletSetup: hasWalletSetup
        ]
    }
    
    /// 計算綜合資格分數 (0-100)
    private func calculateEligibilityScore(conditions: [EligibilityCondition: Bool]) -> Double {
        let completedConditions = conditions.values.filter { $0 }.count
        let totalConditions = conditions.count
        return (Double(completedConditions) / Double(totalConditions)) * 100.0
    }
    
    /// 生成相關通知
    private func generateNotifications(
        isEligible: Bool,
        analytics: AuthorReadingAnalytics,
        hasWalletSetup: Bool,
        hasViolations: Bool,
        conditions: [EligibilityCondition: Bool]
    ) -> [EligibilityNotification] {
        var notifications: [EligibilityNotification] = []
        
        // 資格達成或失效通知
        if isEligible {
            notifications.append(EligibilityNotification(
                type: .qualified,
                title: "恭喜！您已符合收益資格",
                message: "您已滿足所有條件，現在可以開始獲得收益分潤。"
            ))
        } else {
            notifications.append(EligibilityNotification(
                type: .disqualified,
                title: "收益資格暫未達成",
                message: "請完成剩餘條件以獲得收益資格。"
            ))
        }
        
        // 個別條件的提醒通知
        if analytics.last90DaysArticles == 0 {
            notifications.append(EligibilityNotification(
                type: .warning,
                title: "需要發表文章",
                message: "請在90天內發表至少1篇公開文章。",
                condition: .articles90Days,
                currentValue: analytics.last90DaysArticles,
                requiredValue: 1
            ))
        }
        
        if analytics.last30DaysUniqueReaders < EligibilityThresholds.minUniqueReadersIn30Days {
            let remaining = EligibilityThresholds.minUniqueReadersIn30Days - analytics.last30DaysUniqueReaders
            let notificationType: EligibilityNotificationType = remaining <= 20 ? .nearThreshold : .warning
            
            notifications.append(EligibilityNotification(
                type: notificationType,
                title: remaining <= 20 ? "接近讀者門檻" : "需要更多讀者",
                message: "還需要\(remaining)位獨立讀者才能達成條件。",
                condition: .uniqueReaders30Days,
                currentValue: analytics.last30DaysUniqueReaders,
                requiredValue: EligibilityThresholds.minUniqueReadersIn30Days
            ))
        }
        
        if hasViolations {
            notifications.append(EligibilityNotification(
                type: .warning,
                title: "存在違規記錄",
                message: "請聯繫客服處理違規問題。",
                condition: .noViolations,
                currentValue: 0,
                requiredValue: 1
            ))
        }
        
        if !hasWalletSetup {
            notifications.append(EligibilityNotification(
                type: .warning,
                title: "請完成錢包設置",
                message: "完成錢包設置以接收收益分潤。",
                condition: .walletSetup,
                currentValue: 0,
                requiredValue: 1
            ))
        }
        
        return notifications
    }
    
    // MARK: - 定時器管理
    
    /// 設置每日評估定時器
    private func setupDailyEvaluationTimer() {
        // 計算下次評估時間（每天凌晨2點）
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 2
        components.minute = 0
        components.second = 0
        
        guard let nextEvaluation = calendar.date(from: components) else { return }
        
        // 如果今天的2點已經過了，設置為明天的2點
        let finalEvaluationTime = nextEvaluation > now ? nextEvaluation : calendar.date(byAdding: .day, value: 1, to: nextEvaluation)!
        
        nextEvaluationDate = finalEvaluationTime
        
        // 計算距離下次評估的時間間隔
        let timeInterval = finalEvaluationTime.timeIntervalSince(now)
        
        // 設置定時器
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performDailyEvaluation()
                // 重新設置明天的定時器
                self?.setupDailyEvaluationTimer()
            }
        }
        
        print("⏰ [EligibilityEvaluationService] 下次評估時間: \(finalEvaluationTime)")
    }
    
    /// 保存最後評估時間
    private func saveLastEvaluationDate() {
        UserDefaults.standard.set(lastEvaluationDate, forKey: "last_eligibility_evaluation_date")
        UserDefaults.standard.set(nextEvaluationDate, forKey: "next_eligibility_evaluation_date")
    }
    
    /// 載入最後評估時間
    private func loadLastEvaluationDate() {
        lastEvaluationDate = UserDefaults.standard.object(forKey: "last_eligibility_evaluation_date") as? Date
        nextEvaluationDate = UserDefaults.standard.object(forKey: "next_eligibility_evaluation_date") as? Date
    }
    
    // MARK: - 清理方法
    
    deinit {
        evaluationTimer?.invalidate()
    }
}

