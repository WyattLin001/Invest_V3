//
//  TournamentModels.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  錦標賽相關數據模型

import Foundation
import SwiftUI

// MARK: - 錦標賽過濾類型

/// 錦標賽過濾選項，包含所有類型和精選
enum TournamentFilter: String, CaseIterable, Identifiable {
    case featured = "featured"      // 精選錦標賽
    case all = "all"               // 所有錦標賽
    case daily = "daily"           // 日賽
    case weekly = "weekly"         // 週賽
    case monthly = "monthly"       // 月賽
    case quarterly = "quarterly"   // 季賽
    case yearly = "yearly"         // 年賽
    case special = "special"       // 特別賽事
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .featured:
            return "精選"
        case .all:
            return "所有錦標賽"
        case .daily:
            return "日賽"
        case .weekly:
            return "週賽"
        case .monthly:
            return "月賽"
        case .quarterly:
            return "季賽"
        case .yearly:
            return "年賽"
        case .special:
            return "特別賽事"
        }
    }
    
    var iconName: String {
        switch self {
        case .featured:
            return "star.fill"
        case .all:
            return "grid.circle.fill"
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.circle.fill"
        case .monthly:
            return "calendar.badge.clock"
        case .quarterly:
            return "chart.line.uptrend.xyaxis"
        case .yearly:
            return "crown.fill"
        case .special:
            return "bolt.fill"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .featured:
            return .orange
        case .all:
            return .blue
        case .daily:
            return .yellow
        case .weekly:
            return .green
        case .monthly:
            return .blue
        case .quarterly:
            return .purple
        case .yearly:
            return .red
        case .special:
            return .pink
        }
    }
}

// MARK: - 錦標賽類型
enum TournamentType: String, CaseIterable, Identifiable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case special = "special"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily:
            return "日賽"
        case .weekly:
            return "週賽"
        case .monthly:
            return "月賽"
        case .quarterly:
            return "季賽"
        case .yearly:
            return "年賽"
        case .special:
            return "限時賽"
        }
    }
    
    var description: String {
        switch self {
        case .daily:
            return "每日競賽，當日開盤至收盤結算"
        case .weekly:
            return "每週競賽，週一開始週末結算"
        case .monthly:
            return "月度競賽，鼓勵積極交易"
        case .quarterly:
            return "季度競賽，中期波段操作"
        case .yearly:
            return "年度競賽，長期策略考驗"
        case .special:
            return "特殊活動，限時快閃競賽"
        }
    }
    
    var iconName: String {
        switch self {
        case .daily:
            return "sun.max"
        case .weekly:
            return "calendar"
        case .monthly:
            return "calendar.badge.clock"
        case .quarterly:
            return "chart.line.uptrend.xyaxis"
        case .yearly:
            return "crown"
        case .special:
            return "bolt.fill"
        }
    }
    
    var duration: String {
        switch self {
        case .daily:
            return "1天"
        case .weekly:
            return "7天"
        case .monthly:
            return "30天"
        case .quarterly:
            return "90天"
        case .yearly:
            return "365天"
        case .special:
            return "變動"
        }
    }
}

// MARK: - 錦標賽狀態
enum TournamentStatus: String, CaseIterable, Codable {
    case upcoming = "upcoming"      // 即將開始
    case enrolling = "enrolling"    // 報名中
    case ongoing = "ongoing"        // 進行中
    case finished = "finished"      // 已結束
    case cancelled = "cancelled"    // 已取消
    
    var displayName: String {
        switch self {
        case .upcoming:
            return "即將開始"
        case .enrolling:
            return "報名中"
        case .ongoing:
            return "進行中"
        case .finished:
            return "已結束"
        case .cancelled:
            return "已取消"
        }
    }
    
    var color: Color {
        switch self {
        case .upcoming:
            return .blue
        case .enrolling:
            return .green
        case .ongoing:
            return .orange
        case .finished:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    var canEnroll: Bool {
        return self == .enrolling
    }
    
    var canParticipate: Bool {
        return self == .ongoing
    }
}

// MARK: - 錦標賽模型
struct Tournament: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: TournamentType
    let status: TournamentStatus
    let startDate: Date
    let endDate: Date
    let description: String
    let shortDescription: String     // 簡短描述，用於卡片顯示
    let initialBalance: Double       // 改名為 startingCapital 以保持一致性
    let maxParticipants: Int
    let currentParticipants: Int
    let entryFee: Double
    let prizePool: Double
    let riskLimitPercentage: Double
    let minHoldingRate: Double
    let maxSingleStockRate: Double
    let rules: [String]
    let createdAt: Date
    let updatedAt: Date
    let isFeatured: Bool             // 是否為精選錦標賽
    
    // 便利計算屬性
    var startingCapital: Double {
        return initialBalance
    }
    
    var participationPercentage: Double {
        guard maxParticipants > 0 else { return 0 }
        return min(100.0, Double(currentParticipants) / Double(maxParticipants) * 100.0)
    }
    
    var isEnrollmentFull: Bool {
        return currentParticipants >= maxParticipants
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        
        switch status {
        case .enrolling, .upcoming:
            return calendar.dateComponents([.day], from: now, to: startDate).day ?? 0
        case .ongoing:
            return calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
        case .finished, .cancelled:
            return 0
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, status, description, rules
        case shortDescription = "short_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case initialBalance = "initial_balance"
        case maxParticipants = "max_participants"
        case currentParticipants = "current_participants"
        case entryFee = "entry_fee"
        case prizePool = "prize_pool"
        case riskLimitPercentage = "risk_limit_percentage"
        case minHoldingRate = "min_holding_rate"
        case maxSingleStockRate = "max_single_stock_rate"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isFeatured = "is_featured"
    }
    
    // MARK: - 計算屬性
    var isJoinable: Bool {
        return status == .upcoming && currentParticipants < maxParticipants
    }
    
    var isActive: Bool {
        return status == .ongoing
    }
    
    var timeRemaining: String {
        let now = Date()
        let targetDate = status == .upcoming ? startDate : endDate
        let timeInterval = targetDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "已結束"
        }
        
        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if days > 0 {
            return "\(days)天\(hours)小時"
        } else if hours > 0 {
            return "\(hours)小時\(minutes)分鐘"
        } else {
            return "\(minutes)分鐘"
        }
    }
    
    var participantsFull: Bool {
        return currentParticipants >= maxParticipants
    }
    
    var participantsPercentage: Double {
        return maxParticipants > 0 ? Double(currentParticipants) / Double(maxParticipants) : 0
    }
    
    // MARK: - 狀態自動更新機制
    
    /// 根據當前時間自動計算應該的狀態
    var computedStatus: TournamentStatus {
        let now = Date()
        
        // 如果已經手動設置為取消，保持取消狀態
        if status == .cancelled {
            return .cancelled
        }
        
        // 基於時間的狀態判斷
        if now < startDate {
            // 當前時間在開始時間之前
            if status == .enrolling {
                return .enrolling  // 如果設置為報名中，保持報名中
            } else {
                return .upcoming   // 否則為即將開始
            }
        } else if now >= startDate && now <= endDate {
            // 當前時間在錦標賽進行期間
            return .ongoing
        } else {
            // 當前時間在結束時間之後
            return .finished
        }
    }
    
    /// 檢查當前狀態是否需要更新
    var needsStatusUpdate: Bool {
        return status != computedStatus
    }
    
    /// 獲取狀態更新後的錦標賽實例
    func withUpdatedStatus() -> Tournament {
        let newStatus = computedStatus
        
        return Tournament(
            id: id,
            name: name,
            type: type,
            status: newStatus,
            startDate: startDate,
            endDate: endDate,
            description: description,
            shortDescription: shortDescription,
            initialBalance: initialBalance,
            maxParticipants: maxParticipants,
            currentParticipants: currentParticipants,
            entryFee: entryFee,
            prizePool: prizePool,
            riskLimitPercentage: riskLimitPercentage,
            minHoldingRate: minHoldingRate,
            maxSingleStockRate: maxSingleStockRate,
            rules: rules,
            createdAt: createdAt,
            updatedAt: Date(), // 更新時間
            isFeatured: isFeatured
        )
    }
    
    // MARK: - 時區標準化處理
    
    /// 使用UTC時區的開始日期
    var startDateUTC: Date {
        return startDate.toUTC()
    }
    
    /// 使用UTC時區的結束日期
    var endDateUTC: Date {
        return endDate.toUTC()
    }
    
    /// 基於UTC時間的狀態計算
    var computedStatusUTC: TournamentStatus {
        let nowUTC = Date().toUTC()
        
        if status == .cancelled {
            return .cancelled
        }
        
        if nowUTC < startDateUTC {
            return status == .enrolling ? .enrolling : .upcoming
        } else if nowUTC >= startDateUTC && nowUTC <= endDateUTC {
            return .ongoing
        } else {
            return .finished
        }
    }
    
    // MARK: - 增強的時間計算
    
    /// 精確的剩餘時間（秒）
    var exactTimeRemaining: TimeInterval {
        let now = Date().toUTC()
        let targetDate = (computedStatusUTC == .upcoming || computedStatusUTC == .enrolling) ? startDateUTC : endDateUTC
        return max(0, targetDate.timeIntervalSince(now))
    }
    
    /// 格式化的時間顯示（包含秒）
    var preciseTimeRemaining: String {
        let timeInterval = exactTimeRemaining
        
        if timeInterval <= 0 {
            return "已結束"
        }
        
        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        
        if days > 0 {
            return "\(days)天\(hours)小時\(minutes)分鐘"
        } else if hours > 0 {
            return "\(hours)小時\(minutes)分鐘\(seconds)秒"
        } else if minutes > 0 {
            return "\(minutes)分鐘\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    // MARK: - 邊界條件處理
    
    /// 是否在狀態轉換的關鍵時刻（前後30秒）
    var isAtTransitionPoint: Bool {
        let now = Date().toUTC()
        let buffer: TimeInterval = 30 // 30秒緩衝
        
        // 檢查是否接近開始時間
        let timesToStart = startDateUTC.timeIntervalSince(now)
        if timesToStart > -buffer && timesToStart < buffer {
            return true
        }
        
        // 檢查是否接近結束時間
        let timeToEnd = endDateUTC.timeIntervalSince(now)
        if timeToEnd > -buffer && timeToEnd < buffer {
            return true
        }
        
        return false
    }
    
    /// 獲取狀態轉換的提醒信息
    var transitionReminder: String? {
        let now = Date().toUTC()
        let timesToStart = startDateUTC.timeIntervalSince(now)
        let timeToEnd = endDateUTC.timeIntervalSince(now)
        
        // 即將開始的提醒
        if timesToStart > 0 && timesToStart <= 300 { // 5分鐘內
            let minutes = Int(timesToStart / 60)
            return "錦標賽將在\(minutes)分鐘後開始"
        }
        
        // 即將結束的提醒
        if timeToEnd > 0 && timeToEnd <= 300 { // 5分鐘內
            let minutes = Int(timeToEnd / 60)
            return "錦標賽將在\(minutes)分鐘後結束"
        }
        
        return nil
    }
}

// MARK: - 錦標賽參賽者
struct TournamentParticipant: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let userAvatar: String?
    let currentRank: Int
    let previousRank: Int
    let virtualBalance: Double
    let initialBalance: Double
    let returnRate: Double
    let totalTrades: Int
    let winRate: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let isEliminated: Bool
    let eliminationReason: String?
    let joinedAt: Date
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userName, userAvatar, isEliminated, eliminationReason
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case currentRank = "current_rank"
        case previousRank = "previous_rank"
        case virtualBalance = "virtual_balance"
        case initialBalance = "initial_balance"
        case returnRate = "return_rate"
        case totalTrades = "total_trades"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case joinedAt = "joined_at"
        case lastUpdated = "last_updated"
    }
    
    // MARK: - 計算屬性
    var profit: Double {
        return virtualBalance - initialBalance
    }
    
    var rankChange: Int {
        return previousRank - currentRank
    }
    
    var rankChangeIcon: String {
        if rankChange > 0 {
            return "arrow.up"
        } else if rankChange < 0 {
            return "arrow.down"
        } else {
            return "minus"
        }
    }
    
    var rankChangeColor: Color {
        if rankChange > 0 {
            return .success
        } else if rankChange < 0 {
            return .danger
        } else {
            return .gray600
        }
    }
    
    var performanceLevel: PerformanceLevel {
        if returnRate >= 0.20 {
            return .excellent
        } else if returnRate >= 0.10 {
            return .good
        } else if returnRate >= 0.05 {
            return .average
        } else if returnRate >= 0 {
            return .below
        } else {
            return .poor
        }
    }
}

// MARK: - 績效等級
enum PerformanceLevel: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case below = "below"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "卓越"
        case .good:
            return "優秀"
        case .average:
            return "一般"
        case .below:
            return "待改進"
        case .poor:
            return "不佳"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent:
            return .success
        case .good:
            return .brandGreen
        case .average:
            return .warning
        case .below:
            return .brandOrange
        case .poor:
            return .danger
        }
    }
    
    var icon: String {
        switch self {
        case .excellent:
            return "star.fill"
        case .good:
            return "star.circle.fill"
        case .average:
            return "star.circle"
        case .below:
            return "star"
        case .poor:
            return "star.slash"
        }
    }
}

// MARK: - 活動記錄
struct TournamentActivity: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let activityType: ActivityType
    let description: String
    let amount: Double?
    let symbol: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount, symbol, timestamp
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case activityType = "activity_type"
    }
    
    enum ActivityType: String, CaseIterable, Codable {
        case trade = "trade"
        case rankChange = "rank_change"
        case elimination = "elimination"
        case milestone = "milestone"
        case violation = "violation"
        
        var icon: String {
            switch self {
            case .trade:
                return "arrow.left.arrow.right"
            case .rankChange:
                return "arrow.up.arrow.down"
            case .elimination:
                return "xmark.circle"
            case .milestone:
                return "flag.checkered"
            case .violation:
                return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .trade:
                return .brandBlue
            case .rankChange:
                return .brandGreen
            case .elimination:
                return .danger
            case .milestone:
                return .warning
            case .violation:
                return .brandOrange
            }
        }
    }
}

// MARK: - 公開投資組合
// 注意：此結構依賴於 PortfolioHolding（定義在 Stock.swift 中）
/*
struct PublicPortfolio: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let userName: String
    let tournamentId: UUID
    let holdings: [PortfolioHolding]
    let performance: PerformanceMetrics
    let lastUpdated: Date
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, holdings, performance, isPublic
        case userId = "user_id"
        case userName = "user_name"
        case tournamentId = "tournament_id"
        case lastUpdated = "last_updated"
    }
}
*/

// MARK: - 績效指標
struct PerformanceMetrics: Codable {
    let totalReturn: Double
    let annualizedReturn: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let winRate: Double
    let avgHoldingDays: Double
    let diversificationScore: Double
    let riskScore: Double
    let totalTrades: Int
    let profitableTrades: Int
    
    enum CodingKeys: String, CodingKey {
        case totalReturn = "total_return"
        case annualizedReturn = "annualized_return"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case winRate = "win_rate"
        case avgHoldingDays = "avg_holding_days"
        case diversificationScore = "diversification_score"
        case riskScore = "risk_score"
        case totalTrades = "total_trades"
        case profitableTrades = "profitable_trades"
    }
}

// MARK: - 個人績效
struct PersonalPerformance: Codable {
    let totalReturn: Double
    let annualizedReturn: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let winRate: Double
    let totalTrades: Int
    let profitableTrades: Int
    let avgHoldingDays: Double
    let riskScore: Double
    let performanceHistory: [PerformancePoint]
    let rankingHistory: [RankingPoint]
    let achievements: [Achievement]
    
    enum CodingKeys: String, CodingKey {
        case totalReturn = "total_return"
        case annualizedReturn = "annualized_return"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case winRate = "win_rate"
        case totalTrades = "total_trades"
        case profitableTrades = "profitable_trades"
        case avgHoldingDays = "avg_holding_days"
        case riskScore = "risk_score"
        case performanceHistory = "performance_history"
        case rankingHistory = "ranking_history"
        case achievements
    }
}

// MARK: - 績效歷史點
struct PerformancePoint: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let value: Double
    let returnRate: Double
    
    enum CodingKeys: String, CodingKey {
        case date
        case value
        case returnRate = "return_rate"
    }
}

// MARK: - 排名歷史點
struct RankingPoint: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let rank: Int
    let totalParticipants: Int
    let percentile: Double
    
    enum CodingKeys: String, CodingKey {
        case date
        case rank
        case totalParticipants = "total_participants"
        case percentile
    }
}

// MARK: - 成就
struct Achievement: Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let rarity: AchievementRarity
    let earnedAt: Date?
    let progress: Double
    let isUnlocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, progress, isUnlocked
        case earnedAt = "earned_at"
    }
    
    enum AchievementRarity: String, CaseIterable, Codable {
        case common = "common"
        case rare = "rare"
        case epic = "epic"
        case legendary = "legendary"
        case mythic = "mythic"
        
        var displayName: String {
            switch self {
            case .common:
                return "普通"
            case .rare:
                return "稀有"
            case .epic:
                return "史詩"
            case .legendary:
                return "傳奇"
            case .mythic:
                return "神話"
            }
        }
        
        var color: Color {
            switch self {
            case .common:
                return Color(hex: "#9E9E9E")
            case .rare:
                return Color(hex: "#2196F3")
            case .epic:
                return Color(hex: "#9C27B0")
            case .legendary:
                return Color(hex: "#FF9800")
            case .mythic:
                return Color(hex: "#F44336")
            }
        }
    }
}

// MARK: - 用戶稱號
struct UserTitle: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: String
    let rarity: TitleRarity
    let requirements: String
    let earnedAt: Date?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, color, rarity, requirements, isActive
        case earnedAt = "earned_at"
    }
    
    enum TitleRarity: String, CaseIterable, Codable {
        case bronze = "bronze"
        case silver = "silver"
        case gold = "gold"
        case platinum = "platinum"
        case diamond = "diamond"
        
        var displayName: String {
            switch self {
            case .bronze:
                return "銅牌"
            case .silver:
                return "銀牌"
            case .gold:
                return "金牌"
            case .platinum:
                return "白金"
            case .diamond:
                return "鑽石"
            }
        }
        
        var color: Color {
            switch self {
            case .bronze:
                return Color(hex: "#CD7F32")
            case .silver:
                return Color(hex: "#C0C0C0")
            case .gold:
                return Color(hex: "#FFD700")
            case .platinum:
                return Color(hex: "#E5E4E2")
            case .diamond:
                return Color(hex: "#B9F2FF")
            }
        }
    }
}

