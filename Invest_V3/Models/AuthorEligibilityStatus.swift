//
//  AuthorEligibilityStatus.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/2.
//  作者收益資格狀態模型 - 用於收益資格達成判斷系統
//

import Foundation
import SwiftUI

// MARK: - 作者收益資格狀態
struct AuthorEligibilityStatus: Codable, Identifiable {
    let id: UUID
    let authorId: UUID
    let isEligible: Bool
    let last90DaysArticles: Int // 過去90天發表文章數
    let last30DaysUniqueReaders: Int // 過去30天獨立讀者數
    let hasViolations: Bool // 是否有重大違規
    let hasWalletSetup: Bool // 是否完成錢包設置
    let eligibilityScore: Double // 綜合資格分數 (0-100)
    let lastEvaluatedAt: Date // 最後評估時間
    let nextEvaluationAt: Date // 下次評估時間
    let notifications: [EligibilityNotification] // 通知記錄
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case isEligible = "is_eligible"
        case last90DaysArticles = "last_90_days_articles"
        case last30DaysUniqueReaders = "last_30_days_unique_readers"
        case hasViolations = "has_violations"
        case hasWalletSetup = "has_wallet_setup"
        case eligibilityScore = "eligibility_score"
        case lastEvaluatedAt = "last_evaluated_at"
        case nextEvaluationAt = "next_evaluation_at"
        case notifications
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 作者收益資格狀態插入模型
struct AuthorEligibilityStatusInsert: Codable {
    let authorId: String
    let isEligible: Bool
    let last90DaysArticles: Int
    let last30DaysUniqueReaders: Int
    let hasViolations: Bool
    let hasWalletSetup: Bool
    let eligibilityScore: Double
    let lastEvaluatedAt: Date
    let nextEvaluationAt: Date
    let notifications: [EligibilityNotification]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case isEligible = "is_eligible"
        case last90DaysArticles = "last_90_days_articles"
        case last30DaysUniqueReaders = "last_30_days_unique_readers"
        case hasViolations = "has_violations"
        case hasWalletSetup = "has_wallet_setup"
        case eligibilityScore = "eligibility_score"
        case lastEvaluatedAt = "last_evaluated_at"
        case nextEvaluationAt = "next_evaluation_at"
        case notifications
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(authorId: UUID, isEligible: Bool, last90DaysArticles: Int, last30DaysUniqueReaders: Int, hasViolations: Bool, hasWalletSetup: Bool, eligibilityScore: Double) {
        self.authorId = authorId.uuidString
        self.isEligible = isEligible
        self.last90DaysArticles = last90DaysArticles
        self.last30DaysUniqueReaders = last30DaysUniqueReaders
        self.hasViolations = hasViolations
        self.hasWalletSetup = hasWalletSetup
        self.eligibilityScore = eligibilityScore
        self.lastEvaluatedAt = Date()
        self.nextEvaluationAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        self.notifications = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - 資格條件枚舉
enum EligibilityCondition: String, CaseIterable, Codable {
    case articles90Days = "articles_90_days" // 過去90天至少1篇公開文章
    case uniqueReaders30Days = "unique_readers_30_days" // 過去30天至少100位獨立讀者
    case noViolations = "no_violations" // 無重大違規或檢舉
    case walletSetup = "wallet_setup" // 完成錢包設置
    
    var displayName: String {
        switch self {
        case .articles90Days:
            return "過去90天發表文章"
        case .uniqueReaders30Days:
            return "獨立讀者數量"
        case .noViolations:
            return "無違規記錄"
        case .walletSetup:
            return "錢包設置完成"
        }
    }
    
    var requirement: String {
        switch self {
        case .articles90Days:
            return "至少1篇公開文章"
        case .uniqueReaders30Days:
            return "至少100位獨立讀者"
        case .noViolations:
            return "無重大違規或檢舉"
        case .walletSetup:
            return "完成錢包設置"
        }
    }
    
    var icon: String {
        switch self {
        case .articles90Days:
            return "doc.text.fill"
        case .uniqueReaders30Days:
            return "person.3.fill"
        case .noViolations:
            return "checkmark.shield.fill"
        case .walletSetup:
            return "wallet.pass.fill"
        }
    }
}

// MARK: - 資格通知類型
enum EligibilityNotificationType: String, Codable {
    case qualified = "qualified" // 達成資格
    case disqualified = "disqualified" // 失去資格
    case nearThreshold = "near_threshold" // 接近門檻
    case warning = "warning" // 警告提醒
    
    var displayName: String {
        switch self {
        case .qualified:
            return "資格達成"
        case .disqualified:
            return "資格失效"
        case .nearThreshold:
            return "接近門檻"
        case .warning:
            return "警告提醒"
        }
    }
    
    var colorString: String {
        switch self {
        case .qualified:
            return "green"
        case .disqualified:
            return "red"
        case .nearThreshold:
            return "orange"
        case .warning:
            return "yellow"
        }
    }
    
    var icon: String {
        switch self {
        case .qualified:
            return "checkmark.circle.fill"
        case .disqualified:
            return "xmark.circle.fill"
        case .nearThreshold:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .qualified:
            return .green
        case .disqualified:
            return .red
        case .nearThreshold:
            return .orange
        case .warning:
            return .yellow
        }
    }
}

// MARK: - 資格通知模型
struct EligibilityNotification: Codable, Identifiable {
    let id: UUID
    let type: EligibilityNotificationType
    let title: String
    let message: String
    let condition: EligibilityCondition?
    let currentValue: Int?
    let requiredValue: Int?
    let isRead: Bool
    let createdAt: Date
    
    init(type: EligibilityNotificationType, title: String, message: String, condition: EligibilityCondition? = nil, currentValue: Int? = nil, requiredValue: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.message = message
        self.condition = condition
        self.currentValue = currentValue
        self.requiredValue = requiredValue
        self.isRead = false
        self.createdAt = Date()
    }
}

// MARK: - 資格進度追蹤
struct EligibilityProgress: Identifiable {
    let id = UUID()
    let condition: EligibilityCondition
    let isCompleted: Bool
    let currentValue: Int
    let requiredValue: Int
    let progressPercentage: Double
    
    init(condition: EligibilityCondition, currentValue: Int, requiredValue: Int) {
        self.condition = condition
        self.currentValue = currentValue
        self.requiredValue = requiredValue
        self.isCompleted = currentValue >= requiredValue
        self.progressPercentage = min(100.0, (Double(currentValue) / Double(requiredValue)) * 100.0)
    }
}

// MARK: - 資格評估結果
struct EligibilityEvaluationResult {
    let isEligible: Bool
    let conditions: [EligibilityCondition: Bool]
    let progress: [EligibilityProgress]
    let notifications: [EligibilityNotification]
    let eligibilityScore: Double
    let recommendedActions: [String]
    
    init(status: AuthorEligibilityStatus) {
        self.isEligible = status.isEligible
        
        // 條件檢查結果
        self.conditions = [
            .articles90Days: status.last90DaysArticles >= 1,
            .uniqueReaders30Days: status.last30DaysUniqueReaders >= 100,
            .noViolations: !status.hasViolations,
            .walletSetup: status.hasWalletSetup
        ]
        
        // 進度追蹤
        self.progress = [
            EligibilityProgress(condition: .articles90Days, currentValue: status.last90DaysArticles, requiredValue: 1),
            EligibilityProgress(condition: .uniqueReaders30Days, currentValue: status.last30DaysUniqueReaders, requiredValue: 100),
            EligibilityProgress(condition: .noViolations, currentValue: status.hasViolations ? 0 : 1, requiredValue: 1),
            EligibilityProgress(condition: .walletSetup, currentValue: status.hasWalletSetup ? 1 : 0, requiredValue: 1)
        ]
        
        self.notifications = status.notifications
        self.eligibilityScore = status.eligibilityScore
        
        // 建議行動
        var actions: [String] = []
        if status.last90DaysArticles < 1 {
            actions.append("發表至少1篇公開文章")
        }
        if status.last30DaysUniqueReaders < 100 {
            actions.append("提升文章品質以吸引更多讀者")
        }
        if status.hasViolations {
            actions.append("聯繫客服處理違規問題")
        }
        if !status.hasWalletSetup {
            actions.append("完成錢包設置")
        }
        self.recommendedActions = actions
    }
}