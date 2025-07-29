//
//  TournamentPortfolioManager.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  錦標賽專用投資組合管理器 - 管理每個錦標賽的獨立投資組合、排名和績效
//

import Foundation
import SwiftUI
import Combine

/// 錦標賽投資組合持股結構
struct TournamentHolding: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let symbol: String
    let name: String
    var shares: Double
    var averagePrice: Double
    var currentPrice: Double
    let firstPurchaseDate: Date
    var lastUpdated: Date
    
    // 計算屬性
    var totalValue: Double {
        return shares * currentPrice
    }
    
    var totalCost: Double {
        return shares * averagePrice
    }
    
    var unrealizedGainLoss: Double {
        return totalValue - totalCost
    }
    
    var unrealizedGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    var allocationPercentage: Double = 0 // 將在投資組合層級計算
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, shares, currentPrice
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case averagePrice = "average_price"
        case firstPurchaseDate = "first_purchase_date"
        case lastUpdated = "last_updated"
    }
}

/// 錦標賽投資組合結構
struct TournamentPortfolio: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    var holdings: [TournamentHolding]
    var initialBalance: Double
    var currentBalance: Double
    var totalInvested: Double
    var tradingRecords: [TournamentTradingRecord]
    var performanceMetrics: TournamentPerformanceMetrics
    var lastUpdated: Date
    
    // 計算屬性
    var totalPortfolioValue: Double {
        let holdingsValue = holdings.reduce(0) { $0 + $1.totalValue }
        return holdingsValue + currentBalance
    }
    
    var totalReturn: Double {
        return totalPortfolioValue - initialBalance
    }
    
    var totalReturnPercentage: Double {
        guard initialBalance > 0 else { return 0 }
        return (totalReturn / initialBalance) * 100
    }
    
    var holdingsValue: Double {
        return holdings.reduce(0) { $0 + $1.totalValue }
    }
    
    var cashPercentage: Double {
        guard totalPortfolioValue > 0 else { return 0 }
        return (currentBalance / totalPortfolioValue) * 100
    }
    
    var stocksPercentage: Double {
        guard totalPortfolioValue > 0 else { return 0 }
        return (holdingsValue / totalPortfolioValue) * 100
    }
    
    enum CodingKeys: String, CodingKey {
        case id, holdings, tradingRecords, performanceMetrics
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case initialBalance = "initial_balance"
        case currentBalance = "current_balance"
        case totalInvested = "total_invested"
        case lastUpdated = "last_updated"
    }
}

/// 錦標賽交易記錄
struct TournamentTradingRecord: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let symbol: String
    let stockName: String
    let type: TradingType
    let shares: Double
    let price: Double
    let totalAmount: Double
    let fee: Double
    let netAmount: Double
    let timestamp: Date
    var realizedGainLoss: Double?
    var realizedGainLossPercent: Double?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, type, shares, price, timestamp, notes
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case stockName = "stock_name"
        case totalAmount = "total_amount"
        case fee, netAmount = "net_amount"
        case realizedGainLoss = "realized_gain_loss"
        case realizedGainLossPercent = "realized_gain_loss_percent"
    }
}

/// 錦標賽績效指標
struct TournamentPerformanceMetrics: Codable {
    var totalReturn: Double
    var totalReturnPercentage: Double
    var dailyReturn: Double
    var maxDrawdown: Double
    var maxDrawdownPercentage: Double
    var sharpeRatio: Double?
    var winRate: Double
    var totalTrades: Int
    var profitableTrades: Int
    var averageHoldingDays: Double
    var riskScore: Double
    var diversificationScore: Double
    var currentRank: Int
    var previousRank: Int
    var percentile: Double
    var lastUpdated: Date
    
    // 計算屬性
    var rankChange: Int {
        return previousRank - currentRank
    }
    
    var isImproving: Bool {
        return rankChange > 0
    }
    
    enum CodingKeys: String, CodingKey {
        case totalReturn = "total_return"
        case totalReturnPercentage = "total_return_percentage"
        case dailyReturn = "daily_return"
        case maxDrawdown = "max_drawdown"
        case maxDrawdownPercentage = "max_drawdown_percentage"
        case sharpeRatio = "sharpe_ratio"
        case winRate = "win_rate"
        case totalTrades = "total_trades"
        case profitableTrades = "profitable_trades"
        case averageHoldingDays = "average_holding_days"
        case riskScore = "risk_score"
        case diversificationScore = "diversification_score"
        case currentRank = "current_rank"
        case previousRank = "previous_rank"
        case percentile, lastUpdated = "last_updated"
    }
}

/// 錦標賽投資組合管理器
@MainActor
class TournamentPortfolioManager: ObservableObject {
    static let shared = TournamentPortfolioManager()
    
    // MARK: - Published Properties
    @Published var tournamentPortfolios: [UUID: TournamentPortfolio] = [:]
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let feeCalculator = FeeCalculator.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTournamentPortfolios()
    }
    
    // MARK: - Public Methods
    
    /// 獲取特定錦標賽的投資組合
    func getPortfolio(for tournamentId: UUID) -> TournamentPortfolio? {
        return tournamentPortfolios[tournamentId]
    }
    
    /// 初始化錦標賽投資組合
    func initializePortfolio(for tournament: Tournament, userId: UUID, userName: String) async -> Bool {
        print("🏆 [TournamentPortfolioManager] 初始化錦標賽投資組合: \(tournament.name)")
        
        // 檢查是否已存在
        if tournamentPortfolios[tournament.id] != nil {
            print("⚠️ 錦標賽投資組合已存在")
            return true
        }
        
        let newPortfolio = TournamentPortfolio(
            id: UUID(),
            tournamentId: tournament.id,
            userId: userId,
            userName: userName,
            holdings: [],
            initialBalance: tournament.initialBalance,
            currentBalance: tournament.initialBalance,
            totalInvested: 0,
            tradingRecords: [],
            performanceMetrics: TournamentPerformanceMetrics(
                totalReturn: 0,
                totalReturnPercentage: 0,
                dailyReturn: 0,
                maxDrawdown: 0,
                maxDrawdownPercentage: 0,
                sharpeRatio: nil,
                winRate: 0,
                totalTrades: 0,
                profitableTrades: 0,
                averageHoldingDays: 0,
                riskScore: 0,
                diversificationScore: 0,
                currentRank: 0,
                previousRank: 0,
                percentile: 0,
                lastUpdated: Date()
            ),
            lastUpdated: Date()
        )
        
        tournamentPortfolios[tournament.id] = newPortfolio
        saveTournamentPortfolios()
        
        // 同步到後端
        await syncPortfolioToBackend(portfolio: newPortfolio)
        
        print("✅ 錦標賽投資組合初始化成功")
        return true
    }
    
    /// 執行錦標賽交易
    func executeTrade(
        tournamentId: UUID,
        symbol: String,
        stockName: String,
        action: TradingType,
        shares: Double,
        price: Double
    ) async -> Bool {
        
        print("🔄 [TournamentPortfolioManager] 執行錦標賽交易: \(action), \(symbol), 股數: \(shares)")
        
        guard var portfolio = tournamentPortfolios[tournamentId] else {
            print("❌ 找不到錦標賽投資組合")
            return false
        }
        
        let totalAmount = shares * price
        let fees = feeCalculator.calculateTradingFees(amount: totalAmount, action: action.toTradeAction())
        
        if action == .buy {
            return await executeBuyTrade(&portfolio, symbol: symbol, stockName: stockName, shares: shares, price: price, fees: fees)
        } else {
            return await executeSellTrade(&portfolio, symbol: symbol, stockName: stockName, shares: shares, price: price, fees: fees)
        }
    }
    
    /// 更新投資組合績效
    func updatePerformanceMetrics(for tournamentId: UUID) async {
        guard var portfolio = tournamentPortfolios[tournamentId] else { return }
        
        print("📊 [TournamentPortfolioManager] 更新績效指標: \(tournamentId)")
        
        // 計算績效指標
        let totalReturn = portfolio.totalReturn
        let totalReturnPercentage = portfolio.totalReturnPercentage
        
        // 計算其他指標
        let tradingStats = calculateTradingStatistics(portfolio: portfolio)
        let riskMetrics = calculateRiskMetrics(portfolio: portfolio)
        
        portfolio.performanceMetrics = TournamentPerformanceMetrics(
            totalReturn: totalReturn,
            totalReturnPercentage: totalReturnPercentage,
            dailyReturn: calculateDailyReturn(portfolio: portfolio),
            maxDrawdown: riskMetrics.maxDrawdown,
            maxDrawdownPercentage: riskMetrics.maxDrawdownPercentage,
            sharpeRatio: riskMetrics.sharpeRatio,
            winRate: tradingStats.winRate,
            totalTrades: tradingStats.totalTrades,
            profitableTrades: tradingStats.profitableTrades,
            averageHoldingDays: tradingStats.averageHoldingDays,
            riskScore: riskMetrics.riskScore,
            diversificationScore: calculateDiversificationScore(portfolio: portfolio),
            currentRank: portfolio.performanceMetrics.currentRank,
            previousRank: portfolio.performanceMetrics.previousRank,
            percentile: portfolio.performanceMetrics.percentile,
            lastUpdated: Date()
        )
        
        portfolio.lastUpdated = Date()
        tournamentPortfolios[tournamentId] = portfolio
        saveTournamentPortfolios()
        
        // 同步到後端
        await syncPortfolioToBackend(portfolio: portfolio)
    }
    
    /// 獲取錦標賽排名資訊
    func getTournamentRanking(for tournamentId: UUID) async -> [TournamentParticipant] {
        // 這裡會從後端獲取排名資訊
        do {
            let rankings = try await supabaseService.fetchTournamentRankings(tournamentId: tournamentId)
            return rankings
        } catch {
            print("❌ 獲取錦標賽排名失敗: \(error)")
            return []
        }
    }
    
    /// 獲取用戶在錦標賽中的排名
    func getUserRanking(for tournamentId: UUID, userId: UUID) async -> Int? {
        let rankings = await getTournamentRanking(for: tournamentId)
        return rankings.firstIndex { $0.userId == userId }.map { $0 + 1 }
    }
    
    // MARK: - Private Methods
    
    private func executeBuyTrade(
        _ portfolio: inout TournamentPortfolio,
        symbol: String,
        stockName: String,
        shares: Double,
        price: Double,
        fees: TradingFees
    ) async -> Bool {
        
        let totalCost = shares * price + fees.totalFees
        
        // 檢查資金是否足夠
        guard portfolio.currentBalance >= totalCost else {
            print("❌ 資金不足，需要: \(totalCost), 可用: \(portfolio.currentBalance)")
            return false
        }
        
        // 執行買入
        if let existingIndex = portfolio.holdings.firstIndex(where: { $0.symbol == symbol }) {
            // 更新現有持股
            var holding = portfolio.holdings[existingIndex]
            let newTotalShares = holding.shares + shares
            let newAveragePrice = ((holding.shares * holding.averagePrice) + (shares * price)) / newTotalShares
            
            holding.shares = newTotalShares
            holding.averagePrice = newAveragePrice
            holding.currentPrice = price
            holding.lastUpdated = Date()
            
            portfolio.holdings[existingIndex] = holding
        } else {
            // 新增持股
            let newHolding = TournamentHolding(
                id: UUID(),
                tournamentId: portfolio.tournamentId,
                userId: portfolio.userId,
                symbol: symbol,
                name: stockName,
                shares: shares,
                averagePrice: price,
                currentPrice: price,
                firstPurchaseDate: Date(),
                lastUpdated: Date()
            )
            portfolio.holdings.append(newHolding)
        }
        
        // 更新資金和記錄
        portfolio.currentBalance -= totalCost
        portfolio.totalInvested += shares * price
        
        // 創建交易記錄
        let tradingRecord = TournamentTradingRecord(
            id: UUID(),
            tournamentId: portfolio.tournamentId,
            userId: portfolio.userId,
            symbol: symbol,
            stockName: stockName,
            type: .buy,
            shares: shares,
            price: price,
            totalAmount: shares * price,
            fee: fees.totalFees,
            netAmount: totalCost,
            timestamp: Date(),
            realizedGainLoss: nil,
            realizedGainLossPercent: nil,
            notes: nil
        )
        
        portfolio.tradingRecords.append(tradingRecord)
        portfolio.lastUpdated = Date()
        
        // 更新投資組合
        tournamentPortfolios[portfolio.tournamentId] = portfolio
        saveTournamentPortfolios()
        
        // 更新績效
        await updatePerformanceMetrics(for: portfolio.tournamentId)
        
        print("✅ 買入交易執行成功: \(symbol), \(shares) 股")
        return true
    }
    
    private func executeSellTrade(
        _ portfolio: inout TournamentPortfolio,
        symbol: String,
        stockName: String,
        shares: Double,
        price: Double,
        fees: TradingFees
    ) async -> Bool {
        
        // 找到對應持股
        guard let holdingIndex = portfolio.holdings.firstIndex(where: { $0.symbol == symbol }) else {
            print("❌ 找不到持股: \(symbol)")
            return false
        }
        
        var holding = portfolio.holdings[holdingIndex]
        
        // 檢查持股數量
        guard holding.shares >= shares else {
            print("❌ 持股不足，要賣出: \(shares), 持有: \(holding.shares)")
            return false
        }
        
        // 計算收益
        let saleAmount = shares * price
        let costBasis = shares * holding.averagePrice
        let realizedGainLoss = saleAmount - costBasis
        let realizedGainLossPercent = (realizedGainLoss / costBasis) * 100
        let netAmount = saleAmount - fees.totalFees
        
        // 更新持股
        if holding.shares == shares {
            // 全部賣出
            portfolio.holdings.remove(at: holdingIndex)
        } else {
            // 部分賣出
            holding.shares -= shares
            holding.currentPrice = price
            holding.lastUpdated = Date()
            portfolio.holdings[holdingIndex] = holding
        }
        
        // 更新資金
        portfolio.currentBalance += netAmount
        portfolio.totalInvested -= costBasis
        
        // 創建交易記錄
        let tradingRecord = TournamentTradingRecord(
            id: UUID(),
            tournamentId: portfolio.tournamentId,
            userId: portfolio.userId,
            symbol: symbol,
            stockName: stockName,
            type: .sell,
            shares: shares,
            price: price,
            totalAmount: saleAmount,
            fee: fees.totalFees,
            netAmount: netAmount,
            timestamp: Date(),
            realizedGainLoss: realizedGainLoss,
            realizedGainLossPercent: realizedGainLossPercent,
            notes: nil
        )
        
        portfolio.tradingRecords.append(tradingRecord)
        portfolio.lastUpdated = Date()
        
        // 更新投資組合
        tournamentPortfolios[portfolio.tournamentId] = portfolio
        saveTournamentPortfolios()
        
        // 更新績效
        await updatePerformanceMetrics(for: portfolio.tournamentId)
        
        print("✅ 賣出交易執行成功: \(symbol), \(shares) 股，實現損益: \(realizedGainLoss)")
        return true
    }
    
    // MARK: - Analytics Methods
    
    private func calculateTradingStatistics(portfolio: TournamentPortfolio) -> (winRate: Double, totalTrades: Int, profitableTrades: Int, averageHoldingDays: Double) {
        let sellTrades = portfolio.tradingRecords.filter { $0.type == .sell }
        let totalTrades = portfolio.tradingRecords.count
        let profitableTrades = sellTrades.filter { ($0.realizedGainLoss ?? 0) > 0 }.count
        let winRate = sellTrades.isEmpty ? 0 : Double(profitableTrades) / Double(sellTrades.count)
        
        // 計算平均持股天數（簡化版本）
        let averageHoldingDays: Double = 7.0 // 暫時使用固定值，後續可以根據實際持股時間計算
        
        return (winRate: winRate, totalTrades: totalTrades, profitableTrades: profitableTrades, averageHoldingDays: averageHoldingDays)
    }
    
    private func calculateRiskMetrics(portfolio: TournamentPortfolio) -> (maxDrawdown: Double, maxDrawdownPercentage: Double, sharpeRatio: Double?, riskScore: Double) {
        // 簡化的風險指標計算
        let maxDrawdown = portfolio.initialBalance * 0.05 // 假設最大回撤
        let maxDrawdownPercentage = 5.0
        let sharpeRatio: Double? = portfolio.totalReturnPercentage > 0 ? 1.2 : nil
        let riskScore = min(100, max(0, 100 - abs(portfolio.totalReturnPercentage)))
        
        return (maxDrawdown: maxDrawdown, maxDrawdownPercentage: maxDrawdownPercentage, sharpeRatio: sharpeRatio, riskScore: riskScore)
    }
    
    private func calculateDailyReturn(portfolio: TournamentPortfolio) -> Double {
        // 簡化的日收益率計算
        return portfolio.totalReturnPercentage / 30.0 // 假設30天
    }
    
    private func calculateDiversificationScore(portfolio: TournamentPortfolio) -> Double {
        let holdingsCount = portfolio.holdings.count
        let maxDiversification = 10.0
        return min(100, (Double(holdingsCount) / maxDiversification) * 100)
    }
    
    // MARK: - Data Persistence
    
    private func saveTournamentPortfolios() {
        do {
            let data = try JSONEncoder().encode(tournamentPortfolios)
            UserDefaults.standard.set(data, forKey: "tournament_portfolios")
        } catch {
            print("❌ 保存錦標賽投資組合失敗: \(error)")
        }
    }
    
    private func loadTournamentPortfolios() {
        guard let data = UserDefaults.standard.data(forKey: "tournament_portfolios") else { return }
        
        do {
            tournamentPortfolios = try JSONDecoder().decode([UUID: TournamentPortfolio].self, from: data)
            print("✅ 載入錦標賽投資組合: \(tournamentPortfolios.count) 個")
        } catch {
            print("❌ 載入錦標賽投資組合失敗: \(error)")
        }
    }
    
    private func syncPortfolioToBackend(portfolio: TournamentPortfolio) async {
        // 同步到 Supabase 後端
        do {
            try await supabaseService.syncTournamentPortfolio(portfolio)
            print("✅ 錦標賽投資組合同步成功")
        } catch {
            print("❌ 錦標賽投資組合同步失敗: \(error)")
        }
    }
}

// MARK: - Extensions for SupabaseService

// MARK: - TradingType Extension
extension TradingType {
    /// 轉換為 TradeAction 類型
    func toTradeAction() -> TradeAction {
        switch self {
        case .buy:
            return .buy
        case .sell:
            return .sell
        }
    }
}

// Note: SupabaseService methods for tournament portfolio management 
// are implemented in the main SupabaseService.swift file