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
struct PerformancePoint: Codable {
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
struct RankingPoint: Codable {
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

// MARK: - 擴展 - 示例數據
extension Tournament {
    static let sampleData: [Tournament] = [
        Tournament(
            id: UUID(),
            name: "11月月賽挑戰",
            type: .monthly,
            status: .ongoing,
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
            description: "月度模擬交易競賽，考驗短期波段操作能力",
            shortDescription: "月度模擬交易競賽，考驗短期波段操作能力",
            initialBalance: 1000000,
            maxParticipants: 500,
            currentParticipants: 387,
            entryFee: 0,
            prizePool: 50000,
            riskLimitPercentage: 0.20,
            minHoldingRate: 0.50,
            maxSingleStockRate: 0.30,
            rules: [
                "初始虛擬資金：100萬",
                "單日虧損超過10%將扣分",
                "最低持股率：50%",
                "單一股票持倉上限：30%"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: false
        ),
        Tournament(
            id: UUID(),
            name: "Q4季賽巔峰對決",
            type: .quarterly,
            status: .upcoming,
            startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 95, to: Date()) ?? Date(),
            description: "季度長期競賽，檢驗投資策略的持續性",
            shortDescription: "季度長期競賽，檢驗投資策略的持續性",
            initialBalance: 1000000,
            maxParticipants: 200,
            currentParticipants: 156,
            entryFee: 0,
            prizePool: 100000,
            riskLimitPercentage: 0.15,
            minHoldingRate: 0.60,
            maxSingleStockRate: 0.25,
            rules: [
                "初始虛擬資金：100萬",
                "季度分階段評估",
                "最低持股率：60%",
                "單一股票持倉上限：25%"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: true
        )
    ]
}

extension TournamentParticipant {
    static let sampleData: [TournamentParticipant] = [
        TournamentParticipant(
            id: UUID(),
            tournamentId: UUID(),
            userId: UUID(),
            userName: "投資大師",
            userAvatar: nil,
            currentRank: 1,
            previousRank: 2,
            virtualBalance: 1250000,
            initialBalance: 1000000,
            returnRate: 0.25,
            totalTrades: 45,
            winRate: 0.67,
            maxDrawdown: 0.08,
            sharpeRatio: 1.8,
            isEliminated: false,
            eliminationReason: nil,
            joinedAt: Date(),
            lastUpdated: Date()
        ),
        TournamentParticipant(
            id: UUID(),
            tournamentId: UUID(),
            userId: UUID(),
            userName: "穩健投資人",
            userAvatar: nil,
            currentRank: 2,
            previousRank: 1,
            virtualBalance: 1200000,
            initialBalance: 1000000,
            returnRate: 0.20,
            totalTrades: 32,
            winRate: 0.75,
            maxDrawdown: 0.05,
            sharpeRatio: 2.1,
            isEliminated: false,
            eliminationReason: nil,
            joinedAt: Date(),
            lastUpdated: Date()
        )
    ]
}

// MARK: - Mock Data for TournamentCardView

extension Tournament {
    static var mockEnrollingTournament: Tournament {
        Tournament(
            id: UUID(),
            name: "Monthly Masters Championship",
            type: .monthly,
            status: .enrolling,
            startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 35, to: Date()) ?? Date(),
            description: "The premier monthly trading competition featuring professional traders from across Taiwan. Test your strategies against the best and win substantial prizes.",
            shortDescription: "The premier monthly trading competition. Compete with the best traders!",
            initialBalance: 1000000,
            maxParticipants: 2000,
            currentParticipants: 1247,
            entryFee: 0,
            prizePool: 500000,
            riskLimitPercentage: 15.0,
            minHoldingRate: 70.0,
            maxSingleStockRate: 25.0,
            rules: [
                "30-day duration",
                "Max 25% single stock allocation", 
                "Min 70% position requirement",
                "Risk limit: 15% max drawdown"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: true
        )
    }
    
    static var mockOngoingTournament: Tournament {
        Tournament(
            id: UUID(),
            name: "Weekly Warriors",
            type: .weekly,
            status: .ongoing,
            startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            description: "One week to prove your trading strategy. Perfect for swing traders looking for quick action.",
            shortDescription: "One week to prove your trading strategy. Perfect for swing traders.",
            initialBalance: 1000000,
            maxParticipants: 300,
            currentParticipants: 156,
            entryFee: 0,
            prizePool: 100000,
            riskLimitPercentage: 20.0,
            minHoldingRate: 60.0,
            maxSingleStockRate: 30.0,
            rules: [
                "7-day duration",
                "Max 30% single stock allocation",
                "Min 60% position requirement"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: false
        )
    }
    
    static var mockFinishedTournament: Tournament {
        Tournament(
            id: UUID(),
            name: "Daily Lightning Challenge",
            type: .daily,
            status: .finished,
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            description: "Fast-paced single day trading competition designed for day traders who thrive under pressure.",
            shortDescription: "Fast-paced single day trading competition. Test your day trading skills!",
            initialBalance: 1000000,
            maxParticipants: 500,
            currentParticipants: 342,
            entryFee: 0,
            prizePool: 50000,
            riskLimitPercentage: 10.0,
            minHoldingRate: 0.0,
            maxSingleStockRate: 10.0,
            rules: [
                "Single day duration",
                "Max 10% single stock allocation",
                "No overnight positions"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: false
        )
    }
    
    static var mockSpecialTournament: Tournament {
        Tournament(
            id: UUID(),
            name: "Fed Decision Flash Tournament",
            type: .special,
            status: .enrolling,
            startDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date(),
            description: "Special 2-hour tournament during Fed interest rate announcement. High volatility, high rewards.",
            shortDescription: "Special 2-hour tournament during Fed interest rate announcement.",
            initialBalance: 1000000,
            maxParticipants: 1000,
            currentParticipants: 0,
            entryFee: 0,
            prizePool: 200000,
            riskLimitPercentage: 25.0,
            minHoldingRate: 0.0,
            maxSingleStockRate: 50.0,
            rules: [
                "2-hour duration only",
                "High volatility event",
                "No position limits",
                "All positions must close before end"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: true
        )
    }
    
    static var mockYearlyTournament: Tournament {
        Tournament(
            id: UUID(),
            name: "Annual Championship 2024",
            type: .yearly,
            status: .ongoing,
            startDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date(),
            description: "The ultimate year-long trading championship. Prove your long-term strategy and compete for the biggest prizes.",
            shortDescription: "The ultimate year-long trading championship. Prove your long-term strategy.",
            initialBalance: 1000000,
            maxParticipants: 5000,
            currentParticipants: 2156,
            entryFee: 0,
            prizePool: 5000000,
            riskLimitPercentage: 30.0,
            minHoldingRate: 80.0,
            maxSingleStockRate: 20.0,
            rules: [
                "Full year duration",
                "Quarterly checkpoint evaluations",
                "Progressive elimination system",
                "Max 20% single stock allocation"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: true
        )
    }
    
    /// 獲取所有模擬錦標賽
    static var allMockTournaments: [Tournament] {
        return [
            mockEnrollingTournament,
            mockOngoingTournament,
            mockFinishedTournament,
            mockSpecialTournament,
            mockYearlyTournament
        ]
    }
    
    /// 獲取精選錦標賽
    static var featuredMockTournaments: [Tournament] {
        return allMockTournaments.filter { $0.isFeatured }
    }
    
    /// 根據類型獲取模擬錦標賽
    static func mockTournaments(for type: TournamentType) -> [Tournament] {
        return allMockTournaments.filter { $0.type == type }
    }
    
    /// 根據狀態獲取模擬錦標賽
    static func mockTournaments(for status: TournamentStatus) -> [Tournament] {
        return allMockTournaments.filter { $0.status == status }
    }
}