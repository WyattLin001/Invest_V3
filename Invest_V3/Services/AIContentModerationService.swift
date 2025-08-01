//
//  AIContentModerationService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/1.
//  AI 內容審核服務 - 提供 AI 生成文章的安全性檢查和內容管制
//

import Foundation
import SwiftUI

// MARK: - 內容審核結果
struct ContentModerationResult {
    let isApproved: Bool
    let riskLevel: ContentRiskLevel
    let warnings: [ContentWarning]
    let suggestions: [String]
    let moderationScore: Double // 0-1，越高越安全
    
    var canAutoPublish: Bool {
        return isApproved && riskLevel == .low && moderationScore >= 0.85
    }
}

// MARK: - 內容風險等級
enum ContentRiskLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低風險"
        case .medium: return "中等風險"
        case .high: return "高風險"
        case .critical: return "嚴重風險"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - 內容警告
struct ContentWarning {
    let type: WarningType
    let message: String
    let severity: WarningSeverity
    let location: String? // 文章中的位置或段落
}

enum WarningType: String, CaseIterable {
    case inappropriateLanguage = "inappropriate_language"
    case financialAdvice = "financial_advice"
    case misleadingClaims = "misleading_claims"
    case copyrightIssue = "copyright_issue"
    case dataAccuracy = "data_accuracy"
    case regulatory = "regulatory"
    case spam = "spam"
    
    var displayName: String {
        switch self {
        case .inappropriateLanguage: return "不當用詞"
        case .financialAdvice: return "投資建議風險"
        case .misleadingClaims: return "誤導性聲明"
        case .copyrightIssue: return "版權問題"
        case .dataAccuracy: return "數據準確性"
        case .regulatory: return "法規合規"
        case .spam: return "垃圾內容"
        }
    }
}

enum WarningSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - AI 內容審核服務
@MainActor
class AIContentModerationService: ObservableObject {
    static let shared = AIContentModerationService()
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var moderationHistory: [ModerationRecord] = []
    
    // MARK: - Properties
    private let supabaseService = SupabaseService.shared
    
    // 內容審核配置
    private let riskKeywords = [
        "financial_advice": ["建議購買", "推薦買入", "必買", "必賺", "保證獲利"],
        "inappropriate": ["詐騙", "欺騙", "操縱", "內線", "非法"],
        "regulatory": ["證券", "金管會", "違法", "監管"]
    ]
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 審核 AI 生成的文章內容
    func moderateAIArticle(_ article: Article) async throws -> ContentModerationResult {
        print("🔍 [AIContentModerationService] 開始審核 AI 文章: \(article.title)")
        isProcessing = true
        
        defer {
            isProcessing = false
        }
        
        var warnings: [ContentWarning] = []
        var moderationScore: Double = 1.0
        
        // 1. 基礎內容檢查
        warnings.append(contentsOf: checkBasicContent(article))
        
        // 2. 金融建議風險檢查
        warnings.append(contentsOf: checkFinancialAdviceRisk(article))
        
        // 3. 關鍵字檢查
        warnings.append(contentsOf: checkRiskKeywords(article))
        
        // 4. 數據準確性檢查
        warnings.append(contentsOf: checkDataAccuracy(article))
        
        // 5. 法規合規檢查
        warnings.append(contentsOf: checkRegulatoryCompliance(article))
        
        // 計算風險等級和審核分數
        let riskLevel = calculateRiskLevel(warnings: warnings)
        moderationScore = calculateModerationScore(warnings: warnings, riskLevel: riskLevel)
        
        let result = ContentModerationResult(
            isApproved: moderationScore >= 0.6 && riskLevel != .critical,
            riskLevel: riskLevel,
            warnings: warnings,
            suggestions: generateSuggestions(warnings: warnings),
            moderationScore: moderationScore
        )
        
        // 記錄審核結果
        let record = ModerationRecord(
            articleId: article.id,
            articleTitle: article.title,
            result: result,
            moderatedAt: Date(),
            moderator: "AI System"
        )
        moderationHistory.append(record)
        
        // 保存審核記錄到資料庫
        try await saveModerationRecord(record)
        
        print("✅ [AIContentModerationService] 審核完成 - 風險等級: \(riskLevel.displayName), 分數: \(String(format: "%.2f", moderationScore))")
        
        return result
    }
    
    /// 批量審核待審核的 AI 文章
    func moderatePendingAIArticles() async throws -> [UUID: ContentModerationResult] {
        let pendingArticles = try await supabaseService.getPendingAIArticles()
        var results: [UUID: ContentModerationResult] = [:]
        
        for article in pendingArticles {
            do {
                let result = try await moderateAIArticle(article)
                results[article.id] = result
                
                // 如果可以自動發布，更新狀態
                if result.canAutoPublish {
                    try await supabaseService.updateArticleStatus(article.id, status: .published)
                    print("🚀 [AIContentModerationService] 文章自動發布: \(article.title)")
                }
                
            } catch {
                print("❌ [AIContentModerationService] 審核文章失敗: \(article.title) - \(error.localizedDescription)")
            }
        }
        
        return results
    }
    
    /// 獲取審核統計
    func getModerationStats() -> ModerationStats {
        let total = moderationHistory.count
        let approved = moderationHistory.filter { $0.result.isApproved }.count
        let autoPublished = moderationHistory.filter { $0.result.canAutoPublish }.count
        
        let riskDistribution = Dictionary(grouping: moderationHistory) { $0.result.riskLevel }
            .mapValues { $0.count }
        
        return ModerationStats(
            totalReviewed: total,
            approved: approved,
            autoPublished: autoPublished,
            riskDistribution: riskDistribution
        )
    }
    
    // MARK: - 私有方法
    
    /// 基礎內容檢查
    private func checkBasicContent(_ article: Article) -> [ContentWarning] {
        var warnings: [ContentWarning] = []
        
        // 檢查標題長度
        if article.title.count < 10 {
            warnings.append(ContentWarning(
                type: .spam,
                message: "標題過短，可能影響閱讀體驗",
                severity: .warning,
                location: "標題"
            ))
        }
        
        // 檢查內容長度
        if article.fullContent.count < 200 {
            warnings.append(ContentWarning(
                type: .spam,
                message: "內容過短，可能缺乏實質內容",
                severity: .warning,
                location: "正文"
            ))
        }
        
        // 檢查摘要是否合適
        if article.summary.isEmpty {
            warnings.append(ContentWarning(
                type: .dataAccuracy,
                message: "缺少文章摘要",
                severity: .info,
                location: "摘要"
            ))
        }
        
        return warnings
    }
    
    /// 金融建議風險檢查
    private func checkFinancialAdviceRisk(_ article: Article) -> [ContentWarning] {
        var warnings: [ContentWarning] = []
        let content = "\(article.title) \(article.summary) \(article.fullContent)".lowercased()
        
        let adviceKeywords = riskKeywords["financial_advice"] ?? []
        
        for keyword in adviceKeywords {
            if content.contains(keyword.lowercased()) {
                warnings.append(ContentWarning(
                    type: .financialAdvice,
                    message: "包含可能構成投資建議的內容：「\(keyword)」",
                    severity: .warning,
                    location: "內容檢查"
                ))
            }
        }
        
        return warnings
    }
    
    /// 關鍵字風險檢查
    private func checkRiskKeywords(_ article: Article) -> [ContentWarning] {
        var warnings: [ContentWarning] = []
        let content = "\(article.title) \(article.summary) \(article.fullContent)".lowercased()
        
        // 檢查不當內容
        let inappropriateKeywords = riskKeywords["inappropriate"] ?? []
        for keyword in inappropriateKeywords {
            if content.contains(keyword.lowercased()) {
                warnings.append(ContentWarning(
                    type: .inappropriateLanguage,
                    message: "包含敏感詞彙：「\(keyword)」",
                    severity: .error,
                    location: "內容檢查"
                ))
            }
        }
        
        return warnings
    }
    
    /// 數據準確性檢查
    private func checkDataAccuracy(_ article: Article) -> [ContentWarning] {
        var warnings: [ContentWarning] = []
        
        // 檢查是否包含具體數據但缺乏來源
        let content = article.fullContent
        let hasNumbers = content.range(of: #"\d+(\.\d+)?%"#, options: .regularExpression) != nil
        
        if hasNumbers && !content.lowercased().contains("資料來源") && !content.lowercased().contains("數據來源") {
            warnings.append(ContentWarning(
                type: .dataAccuracy,
                message: "包含數據但缺乏來源標註",
                severity: .warning,
                location: "數據引用"
            ))
        }
        
        return warnings
    }
    
    /// 法規合規檢查
    private func checkRegulatoryCompliance(_ article: Article) -> [ContentWarning] {
        var warnings: [ContentWarning] = []
        
        // 檢查是否需要風險警示
        let content = "\(article.title) \(article.summary) \(article.fullContent)".lowercased()
        
        if content.contains("股票") || content.contains("投資") || content.contains("基金") {
            if !content.contains("風險") && !content.contains("虧損") {
                warnings.append(ContentWarning(
                    type: .regulatory,
                    message: "投資相關內容建議加入風險警示",
                    severity: .info,
                    location: "法規合規"
                ))
            }
        }
        
        return warnings
    }
    
    /// 計算風險等級
    private func calculateRiskLevel(warnings: [ContentWarning]) -> ContentRiskLevel {
        let criticalCount = warnings.filter { $0.severity == .critical }.count
        let errorCount = warnings.filter { $0.severity == .error }.count
        let warningCount = warnings.filter { $0.severity == .warning }.count
        
        if criticalCount > 0 {
            return .critical
        } else if errorCount > 2 {
            return .high
        } else if errorCount > 0 || warningCount > 3 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 計算審核分數
    private func calculateModerationScore(warnings: [ContentWarning], riskLevel: ContentRiskLevel) -> Double {
        var score = 1.0
        
        for warning in warnings {
            switch warning.severity {
            case .critical:
                score -= 0.3
            case .error:
                score -= 0.2
            case .warning:
                score -= 0.1
            case .info:
                score -= 0.05
            }
        }
        
        // 根據風險等級調整
        switch riskLevel {
        case .critical:
            score *= 0.3
        case .high:
            score *= 0.6
        case .medium:
            score *= 0.8
        case .low:
            break
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// 生成改進建議
    private func generateSuggestions(warnings: [ContentWarning]) -> [String] {
        var suggestions: [String] = []
        
        let warningTypes = Set(warnings.map { $0.type })
        
        for type in warningTypes {
            switch type {
            case .financialAdvice:
                suggestions.append("建議使用更中性的語言，避免直接的投資建議")
            case .inappropriateLanguage:
                suggestions.append("請檢查並修改可能不當的用詞")
            case .dataAccuracy:
                suggestions.append("建議為引用的數據添加可靠來源")
            case .regulatory:
                suggestions.append("考慮添加適當的風險警示聲明")
            case .spam:
                suggestions.append("建議增加更多實質性內容以提升文章品質")
            default:
                break
            }
        }
        
        if suggestions.isEmpty {
            suggestions.append("內容整體良好，建議繼續保持專業性和客觀性")
        }
        
        return suggestions
    }
    
    /// 保存審核記錄
    private func saveModerationRecord(_ record: ModerationRecord) async throws {
        // 這裡可以實現將審核記錄保存到資料庫的邏輯
        print("📋 [AIContentModerationService] 保存審核記錄: \(record.articleTitle)")
    }
}

// MARK: - 審核記錄
struct ModerationRecord: Identifiable {
    let id = UUID()
    let articleId: UUID
    let articleTitle: String
    let result: ContentModerationResult
    let moderatedAt: Date
    let moderator: String
}

// MARK: - 審核統計
struct ModerationStats {
    let totalReviewed: Int
    let approved: Int
    let autoPublished: Int
    let riskDistribution: [ContentRiskLevel: Int]
    
    var approvalRate: Double {
        guard totalReviewed > 0 else { return 0 }
        return Double(approved) / Double(totalReviewed)
    }
    
    var autoPublishRate: Double {
        guard approved > 0 else { return 0 }
        return Double(autoPublished) / Double(approved)
    }
}