//
//  PortfolioModels.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  投資組合相關數據模型

import Foundation
import SwiftUI

// MARK: - 投資組合數據
struct PortfolioData: Codable {
    let totalValue: Double
    let cashBalance: Double
    let investedAmount: Double
    let dailyChange: Double
    let dailyChangePercentage: Double
    let totalReturnPercentage: Double
    let weeklyReturn: Double
    let monthlyReturn: Double
    let quarterlyReturn: Double
    let holdings: [PortfolioHolding]
    let allocations: [AssetAllocation]
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case totalValue = "total_value"
        case cashBalance = "cash_balance"
        case investedAmount = "invested_amount"
        case dailyChange = "daily_change"
        case dailyChangePercentage = "daily_change_percentage"
        case totalReturnPercentage = "total_return_percentage"
        case weeklyReturn = "weekly_return"
        case monthlyReturn = "monthly_return"
        case quarterlyReturn = "quarterly_return"
        case holdings, allocations
        case lastUpdated = "last_updated"
    }
}

// MARK: - 資產配置
struct AssetAllocation: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let name: String
    let percentage: Double
    let value: Double
    let color: String
    
    enum CodingKeys: String, CodingKey {
        case symbol, name, percentage, value, color
    }
}

// MARK: - 交易記錄
struct TransactionRecord: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let stockName: String
    let type: TransactionType
    let shares: Int
    let price: Double
    let totalAmount: Double
    let fee: Double
    let timestamp: Date
    let status: TransactionStatus
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, type, shares, price, fee, timestamp, status
        case stockName = "stock_name"
        case totalAmount = "total_amount"
    }
    
    enum TransactionType: String, CaseIterable, Codable {
        case buy = "buy"
        case sell = "sell"
        
        var displayName: String {
            switch self {
            case .buy:
                return "買入"
            case .sell:
                return "賣出"
            }
        }
        
        var color: Color {
            switch self {
            case .buy:
                return .success
            case .sell:
                return .danger
            }
        }
        
        var icon: String {
            switch self {
            case .buy:
                return "plus.circle.fill"
            case .sell:
                return "minus.circle.fill"
            }
        }
    }
    
    enum TransactionStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case completed = "completed"
        case cancelled = "cancelled"
        case failed = "failed"
        
        var displayName: String {
            switch self {
            case .pending:
                return "待執行"
            case .completed:
                return "已完成"
            case .cancelled:
                return "已取消"
            case .failed:
                return "失敗"
            }
        }
        
        var color: Color {
            switch self {
            case .pending:
                return .warning
            case .completed:
                return .success
            case .cancelled:
                return .gray600
            case .failed:
                return .danger
            }
        }
    }
}

// MARK: - 個人績效分析
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
        case date, value
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
        case date, rank
        case totalParticipants = "total_participants"
        case percentile
    }
}

// MARK: - 成就系統
struct Achievement: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let rarity: AchievementRarity
    let earnedAt: Date?
    let progress: Double
    let isUnlocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, progress
        case earnedAt = "earned_at"
        case isUnlocked = "is_unlocked"
    }
    
    enum AchievementRarity: String, CaseIterable, Codable {
        case common = "common"
        case rare = "rare"
        case epic = "epic"
        case legendary = "legendary"
        
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
            }
        }
        
        var color: Color {
            switch self {
            case .common:
                return .gray600
            case .rare:
                return .brandBlue
            case .epic:
                return .brandPurple
            case .legendary:
                return .brandGold
            }
        }
    }
}

// MARK: - 模擬數據
struct MockPortfolioData {
    static let sampleData = PortfolioData(
        totalValue: 1250000,
        cashBalance: 150000,
        investedAmount: 1100000,
        dailyChange: 25000,
        dailyChangePercentage: 2.04,
        totalReturnPercentage: 25.0,
        weeklyReturn: 3.8,
        monthlyReturn: 12.5,
        quarterlyReturn: 18.7,
        holdings: sampleHoldings,
        allocations: sampleAllocations,
        lastUpdated: Date()
    )
    
    static let sampleHoldings: [PortfolioHolding] = [
        PortfolioHolding(
            symbol: "2330",
            name: "台積電",
            shares: 100,
            avgPrice: 580.0,
            currentPrice: 620.0,
            currentValue: 62000,
            returnPercentage: 6.90
        ),
        PortfolioHolding(
            symbol: "0050",
            name: "台灣50",
            shares: 200,
            avgPrice: 140.0,
            currentPrice: 145.0,
            currentValue: 29000,
            returnPercentage: 3.57
        ),
        PortfolioHolding(
            symbol: "2454",
            name: "聯發科",
            shares: 50,
            avgPrice: 800.0,
            currentPrice: 850.0,
            currentValue: 42500,
            returnPercentage: 6.25
        ),
        PortfolioHolding(
            symbol: "2317",
            name: "鴻海",
            shares: 300,
            avgPrice: 110.0,
            currentPrice: 115.0,
            currentValue: 34500,
            returnPercentage: 4.55
        ),
        PortfolioHolding(
            symbol: "2881",
            name: "富邦金",
            shares: 400,
            avgPrice: 70.0,
            currentPrice: 75.0,
            currentValue: 30000,
            returnPercentage: 7.14
        )
    ]
    
    static let sampleAllocations: [AssetAllocation] = [
        AssetAllocation(symbol: "2330", name: "台積電", percentage: 31.0, value: 620000, color: "#FF6B6B"),
        AssetAllocation(symbol: "0050", name: "台灣50", percentage: 14.5, value: 290000, color: "#4ECDC4"),
        AssetAllocation(symbol: "2454", name: "聯發科", percentage: 21.3, value: 425000, color: "#45B7D1"),
        AssetAllocation(symbol: "2317", name: "鴻海", percentage: 17.3, value: 345000, color: "#96CEB4"),
        AssetAllocation(symbol: "2881", name: "富邦金", percentage: 15.0, value: 300000, color: "#FFEAA7"),
        AssetAllocation(symbol: "CASH", name: "現金", percentage: 0.9, value: 18000, color: "#DDA0DD")
    ]
    
    static let sampleTransactions: [TransactionRecord] = [
        TransactionRecord(
            id: UUID(),
            symbol: "2330",
            stockName: "台積電",
            type: .buy,
            shares: 100,
            price: 580.0,
            totalAmount: 58000,
            fee: 58,
            timestamp: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            status: .completed
        ),
        TransactionRecord(
            id: UUID(),
            symbol: "0050",
            stockName: "台灣50",
            type: .buy,
            shares: 200,
            price: 140.0,
            totalAmount: 28000,
            fee: 28,
            timestamp: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            status: .completed
        ),
        TransactionRecord(
            id: UUID(),
            symbol: "2454",
            stockName: "聯發科",
            type: .sell,
            shares: 20,
            price: 850.0,
            totalAmount: 17000,
            fee: 51,
            timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            status: .completed
        )
    ]
    
    static let samplePerformance = PersonalPerformance(
        totalReturn: 0.25,
        annualizedReturn: 0.18,
        maxDrawdown: 0.08,
        sharpeRatio: 1.8,
        winRate: 0.67,
        totalTrades: 45,
        profitableTrades: 30,
        avgHoldingDays: 25.5,
        riskScore: 6.5,
        performanceHistory: samplePerformanceHistory,
        rankingHistory: sampleRankingHistory,
        achievements: sampleAchievements
    )
    
    static let samplePerformanceHistory: [PerformancePoint] = [
        PerformancePoint(date: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), value: 1000000, returnRate: 0.0),
        PerformancePoint(date: Calendar.current.date(byAdding: .day, value: -25, to: Date()) ?? Date(), value: 1050000, returnRate: 0.05),
        PerformancePoint(date: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date(), value: 1120000, returnRate: 0.12),
        PerformancePoint(date: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date(), value: 1080000, returnRate: 0.08),
        PerformancePoint(date: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(), value: 1180000, returnRate: 0.18),
        PerformancePoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), value: 1220000, returnRate: 0.22),
        PerformancePoint(date: Date(), value: 1250000, returnRate: 0.25)
    ]
    
    static let sampleRankingHistory: [RankingPoint] = [
        RankingPoint(date: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), rank: 150, totalParticipants: 500, percentile: 70.0),
        RankingPoint(date: Calendar.current.date(byAdding: .day, value: -25, to: Date()) ?? Date(), rank: 120, totalParticipants: 500, percentile: 76.0),
        RankingPoint(date: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date(), rank: 80, totalParticipants: 500, percentile: 84.0),
        RankingPoint(date: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date(), rank: 95, totalParticipants: 500, percentile: 81.0),
        RankingPoint(date: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(), rank: 45, totalParticipants: 500, percentile: 91.0),
        RankingPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), rank: 32, totalParticipants: 500, percentile: 93.6),
        RankingPoint(date: Date(), rank: 25, totalParticipants: 500, percentile: 95.0)
    ]
    
    static let sampleAchievements: [Achievement] = [
        Achievement(
            id: UUID(),
            name: "首次交易",
            description: "完成第一筆投資交易",
            icon: "star.fill",
            rarity: .common,
            earnedAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            progress: 1.0,
            isUnlocked: true
        ),
        Achievement(
            id: UUID(),
            name: "月度勝者",
            description: "單月報酬率超過 10%",
            icon: "trophy.fill",
            rarity: .rare,
            earnedAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()),
            progress: 1.0,
            isUnlocked: true
        ),
        Achievement(
            id: UUID(),
            name: "連勝紀錄",
            description: "連續 10 筆交易獲利",
            icon: "flame.fill",
            rarity: .epic,
            earnedAt: nil,
            progress: 0.7,
            isUnlocked: false
        ),
        Achievement(
            id: UUID(),
            name: "投資大師",
            description: "年化報酬率達到 20%",
            icon: "crown.fill",
            rarity: .legendary,
            earnedAt: nil,
            progress: 0.9,
            isUnlocked: false
        )
    ]
}