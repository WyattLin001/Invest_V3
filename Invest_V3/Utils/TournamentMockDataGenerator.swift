//
//  TournamentMockDataGenerator.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  錦標賽功能測試用模擬數據生成器

import Foundation
import SwiftUI

// MARK: - 模擬數據生成器
class TournamentMockDataGenerator {
    
    // MARK: - 預設值配置
    private struct MockConfig {
        static let defaultInitialBalance: Double = 1_000_000.0
        static let maxParticipants = [50, 100, 200, 500, 1000]
        static let entryFees = [0.0, 100.0, 500.0, 1000.0, 5000.0]
        static let prizePools = [10000.0, 50000.0, 100000.0, 500000.0, 1000000.0]
        static let riskLimits = [10.0, 15.0, 20.0, 25.0, 30.0]
        static let minHoldingRates = [50.0, 60.0, 70.0, 80.0, 90.0]
        static let maxSingleStockRates = [10.0, 15.0, 20.0, 25.0, 30.0]
    }
    
    private let tournamentNames = [
        "新手入門挑戰賽", "高手對決錦標賽", "月度投資冠軍賽", "季度策略競賽",
        "年度巔峰對決", "台股精英賽", "價值投資大賽", "成長股競技場",
        "配息股王爭霸", "科技股淘金賽", "ESG永續投資賽", "AI智能選股賽",
        "量化交易競賽", "波段操作大師賽", "長線投資挑戰", "短線交易王者賽"
    ]
    
    private let userNames = [
        "投資達人", "股市新手", "價值投資者", "成長股獵人", "配息收割者",
        "技術分析師", "基本面專家", "量化交易員", "波段操作手", "長線投資家",
        "風險控制者", "獲利機器", "穩健投資人", "積極交易者", "保守理財師"
    ]
    
    private let stockSymbols = [
        "2330.TW", "2317.TW", "2454.TW", "1301.TW", "2881.TW",
        "6505.TW", "2382.TW", "3711.TW", "2886.TW", "2884.TW",
        "0050.TW", "0056.TW", "2892.TW", "2891.TW", "2883.TW"
    ]
    
    private let stockNames = [
        "台積電", "鴻海", "聯發科", "台塑", "富邦金",
        "台達電", "廣達", "日月光投控", "兆豐金", "玉山金",
        "元大台灣50", "元大高股息", "第一金", "中信金", "開發金"
    ]
    
    // MARK: - 錦標賽生成方法
    
    /// 生成單個模擬錦標賽
    func generateMockTournament(type: TournamentType? = nil, status: TournamentStatus? = nil) -> Tournament {
        let selectedType = type ?? TournamentType.allCases.randomElement()!
        let selectedStatus = status ?? TournamentStatus.allCases.randomElement()!
        
        let name = tournamentNames.randomElement()! + " - " + selectedType.displayName
        let maxParticipants = MockConfig.maxParticipants.randomElement()!
        let currentParticipants = Int.random(in: 0...maxParticipants)
        
        let now = Date()
        let startDate: Date
        let endDate: Date
        
        switch selectedStatus {
        case .upcoming:
            startDate = now.addingTimeInterval(TimeInterval.random(in: 3600...604800)) // 1小時到7天後
            endDate = generateEndDate(from: startDate, type: selectedType)
        case .enrolling:
            startDate = now.addingTimeInterval(TimeInterval.random(in: 3600...172800)) // 1小時到2天後
            endDate = generateEndDate(from: startDate, type: selectedType)
        case .ongoing:
            startDate = now.addingTimeInterval(TimeInterval.random(in: -172800...0)) // 2天前到現在
            endDate = generateEndDate(from: startDate, type: selectedType)
        case .finished:
            endDate = now.addingTimeInterval(TimeInterval.random(in: -604800...0)) // 7天前到現在
            startDate = generateStartDate(from: endDate, type: selectedType)
        case .cancelled:
            startDate = now.addingTimeInterval(TimeInterval.random(in: -172800...172800))
            endDate = generateEndDate(from: startDate, type: selectedType)
        }
        
        return Tournament(
            id: UUID(),
            name: name,
            type: selectedType,
            status: selectedStatus,
            startDate: startDate,
            endDate: endDate,
            description: generateTournamentDescription(type: selectedType),
            shortDescription: generateShortDescription(type: selectedType),
            initialBalance: MockConfig.defaultInitialBalance,
            maxParticipants: maxParticipants,
            currentParticipants: currentParticipants,
            entryFee: MockConfig.entryFees.randomElement()!,
            prizePool: MockConfig.prizePools.randomElement()!,
            riskLimitPercentage: MockConfig.riskLimits.randomElement()!,
            minHoldingRate: MockConfig.minHoldingRates.randomElement()!,
            maxSingleStockRate: MockConfig.maxSingleStockRates.randomElement()!,
            rules: generateTournamentRules(),
            createdAt: now.addingTimeInterval(-TimeInterval.random(in: 0...2592000)), // 30天內
            updatedAt: now,
            isFeatured: Bool.random()
        )
    }
    
    /// 生成多個模擬錦標賽
    func generateMockTournaments(count: Int) -> [Tournament] {
        return (0..<count).map { _ in generateMockTournament() }
    }
    
    // MARK: - 參賽者生成方法
    
    /// 生成單個模擬參賽者
    func generateMockParticipant() -> TournamentParticipant {
        let initialBalance = MockConfig.defaultInitialBalance
        let currentBalance = initialBalance * Double.random(in: 0.7...1.8) // -30% to +80%
        let returnRate = (currentBalance - initialBalance) / initialBalance * 100
        
        let totalTrades = Int.random(in: 5...100)
        let winningTrades = Int.random(in: 0...totalTrades)
        let winRate = totalTrades > 0 ? Double(winningTrades) / Double(totalTrades) * 100 : 0
        
        let maxDrawdown = Double.random(in: 0...30)
        let sharpeRatio = Double.random(in: -2...3)
        
        return TournamentParticipant(
            id: UUID(),
            tournamentId: UUID(),
            userId: UUID(),
            userName: userNames.randomElement()! + String(Int.random(in: 1000...9999)),
            userAvatar: nil,
            currentRank: Int.random(in: 1...1000),
            previousRank: Int.random(in: 1...1000),
            virtualBalance: currentBalance,
            initialBalance: initialBalance,
            returnRate: returnRate,
            totalTrades: totalTrades,
            winRate: winRate,
            maxDrawdown: maxDrawdown,
            sharpeRatio: sharpeRatio,
            isEliminated: Bool.random() && returnRate < -50,
            eliminationReason: returnRate < -50 ? "超過最大回撤限制" : nil,
            joinedAt: Date().addingTimeInterval(-TimeInterval.random(in: 0...2592000)),
            lastUpdated: Date()
        )
    }
    
    /// 生成多個模擬參賽者
    func generateMockParticipants(count: Int) -> [TournamentParticipant] {
        return (0..<count).map { _ in generateMockParticipant() }
    }
    
    // MARK: - 投資組合生成方法
    
    /// 生成模擬投資組合
    func generateMockPortfolio() -> MockPortfolio {
        let totalValue = MockConfig.defaultInitialBalance * Double.random(in: 0.8...1.5)
        let cashBalance = totalValue * Double.random(in: 0.1...0.5) // 10%-50% 現金
        let investedValue = totalValue - cashBalance
        
        let holdingCount = Int.random(in: 3...10)
        var holdings: [MockHolding] = []
        
        for i in 0..<holdingCount {
            let symbol = stockSymbols[i % stockSymbols.count]
            let name = stockNames[i % stockNames.count]
            let quantity = Int.random(in: 100...5000)
            let averagePrice = Double.random(in: 50...500)
            let currentPrice = averagePrice * Double.random(in: 0.8...1.3)
            let marketValue = Double(quantity) * currentPrice
            
            let holding = MockHolding(
                symbol: symbol,
                name: name,
                quantity: quantity,
                averagePrice: averagePrice,
                currentPrice: currentPrice,
                marketValue: marketValue,
                unrealizedGainLoss: (currentPrice - averagePrice) * Double(quantity),
                unrealizedGainLossPercentage: (currentPrice - averagePrice) / averagePrice * 100
            )
            
            holdings.append(holding)
        }
        
        return MockPortfolio(
            totalValue: totalValue,
            cashBalance: cashBalance,
            investedValue: investedValue,
            holdings: holdings,
            cashPercentage: cashBalance / totalValue * 100
        )
    }
    
    // MARK: - 績效指標生成方法
    
    /// 生成模擬績效指標
    func generateMockPerformanceMetrics() -> MockPerformanceMetrics {
        let totalReturn = Double.random(in: -50...100) // -50% to +100%
        let annualizedReturn = totalReturn * Double.random(in: 0.5...2.0)
        let volatility = Double.random(in: 10...40)
        let sharpeRatio = (annualizedReturn - 2.0) / volatility // 假設無風險利率2%
        let maxDrawdown = Double.random(in: 0...30)
        let winRate = Double.random(in: 30...80)
        let averageGain = Double.random(in: 1...10)
        let averageLoss = Double.random(in: -10...0)
        
        return MockPerformanceMetrics(
            totalReturn: totalReturn,
            annualizedReturn: annualizedReturn,
            volatility: volatility,
            sharpeRatio: sharpeRatio,
            maxDrawdown: maxDrawdown,
            winRate: winRate,
            averageGain: averageGain,
            averageLoss: averageLoss,
            totalTrades: Int.random(in: 10...200),
            profitFactor: averageGain / abs(averageLoss)
        )
    }
    
    // MARK: - 交易生成方法
    
    /// 生成模擬交易
    func generateMockTrade(type: MockTradeType? = nil) -> MockTrade {
        let tradeType = type ?? MockTradeType.allCases.randomElement()!
        let symbol = stockSymbols.randomElement()!
        let name = stockNames[stockSymbols.firstIndex(of: symbol) ?? 0]
        let quantity = Int.random(in: 100...2000)
        let price = Double.random(in: 50...500)
        
        return MockTrade(
            id: UUID(),
            symbol: symbol,
            name: name,
            type: tradeType,
            quantity: quantity,
            price: price,
            amount: Double(quantity) * price,
            timestamp: Date(),
            fee: Double(quantity) * price * 0.001425 // 台股手續費約0.1425%
        )
    }
    
    // MARK: - 輔助方法
    
    private func generateEndDate(from startDate: Date, type: TournamentType) -> Date {
        let duration: TimeInterval
        
        switch type {
        case .daily:
            duration = 86400 // 1天
        case .weekly:
            duration = 604800 // 7天
        case .monthly:
            duration = 2592000 // 30天
        case .quarterly:
            duration = 7776000 // 90天
        case .yearly:
            duration = 31536000 // 365天
        case .special:
            duration = TimeInterval.random(in: 86400...604800) // 1-7天
        }
        
        return startDate.addingTimeInterval(duration)
    }
    
    private func generateStartDate(from endDate: Date, type: TournamentType) -> Date {
        let duration: TimeInterval
        
        switch type {
        case .daily:
            duration = -86400
        case .weekly:
            duration = -604800
        case .monthly:
            duration = -2592000
        case .quarterly:
            duration = -7776000
        case .yearly:
            duration = -31536000
        case .special:
            duration = -TimeInterval.random(in: 86400...604800)
        }
        
        return endDate.addingTimeInterval(duration)
    }
    
    private func generateTournamentDescription(type: TournamentType) -> String {
        let baseDescription = "歡迎參加這個激動人心的投資競賽！在這裡您可以展示您的投資技能，與其他投資者競技。"
        
        switch type {
        case .daily:
            return baseDescription + "這是一個快節奏的單日競賽，適合喜歡日內交易的投資者。"
        case .weekly:
            return baseDescription + "為期一週的競賽，讓您有充足時間制定和執行投資策略。"
        case .monthly:
            return baseDescription + "月度競賽提供更長的時間窗口，適合中期投資策略。"
        case .quarterly:
            return baseDescription + "季度競賽考驗您的長期投資眼光和策略執行能力。"
        case .yearly:
            return baseDescription + "年度冠軍賽是最高級別的競賽，展現真正的投資大師風範。"
        case .special:
            return baseDescription + "特別活動競賽，機會難得，獎品豐厚！"
        }
    }
    
    private func generateShortDescription(type: TournamentType) -> String {
        switch type {
        case .daily:
            return "單日快速競賽，展現日内交易技巧"
        case .weekly:
            return "週期競賽，波段操作的最佳舞台"
        case .monthly:
            return "月度挑戰，中期策略見真章"
        case .quarterly:
            return "季度對決，長線布局展實力"
        case .yearly:
            return "年度巔峰，投資大師的終極考驗"
        case .special:
            return "限時特賽，獨特機會不容錯過"
        }
    }
    
    private func generateTournamentRules() -> [String] {
        return [
            "初始資金：100萬元虛擬資金",
            "交易標的：台股上市櫃股票及ETF",
            "最低持股率：不得低於50%",
            "單一標的持股上限：不得超過20%",
            "交易手續費：買進0.1425%，賣出0.1425%+0.3%證交稅",
            "排名依據：總報酬率由高至低排序",
            "風險控制：最大虧損達30%時強制出局",
            "禁止行為：不得進行違法或操縱市場的行為",
            "獎勵發放：競賽結束後3個工作日內發放獎勵",
            "爭議處理：如有爭議以主辦方最終裁決為準"
        ]
    }
}

// MARK: - 模擬數據模型

/// 模擬投資組合
struct MockPortfolio {
    let totalValue: Double
    let cashBalance: Double
    let investedValue: Double
    let holdings: [MockHolding]
    let cashPercentage: Double
}

/// 模擬持股
struct MockHolding {
    let symbol: String
    let name: String
    let quantity: Int
    let averagePrice: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedGainLoss: Double
    let unrealizedGainLossPercentage: Double
}

/// 模擬績效指標
struct MockPerformanceMetrics {
    let totalReturn: Double
    let annualizedReturn: Double
    let volatility: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
    let winRate: Double
    let averageGain: Double
    let averageLoss: Double
    let totalTrades: Int
    let profitFactor: Double
}

/// 模擬交易
struct MockTrade {
    let id: UUID
    let symbol: String
    let name: String
    let type: MockTradeType
    let quantity: Int
    let price: Double
    let amount: Double
    let timestamp: Date
    let fee: Double
}

/// 模擬交易類型
enum MockTradeType: CaseIterable {
    case buy, sell
    
    var displayName: String {
        switch self {
        case .buy: return "買進"
        case .sell: return "賣出"
        }
    }
}