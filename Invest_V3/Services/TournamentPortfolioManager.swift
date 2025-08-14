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

// MARK: - TournamentTradeAction 定義
/// 錦標賽交易動作類型
enum TournamentTradeAction: String, CaseIterable {
    case buy = "buy"
    case sell = "sell"
    
    var displayName: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
    
    /// 轉換為 TradeSide
    func toTradeSide() -> TradeSide {
        switch self {
        case .buy: return .buy
        case .sell: return .sell
        }
    }
    
    /// 轉換為 TradingType
    func toTradingType() -> TradingType {
        switch self {
        case .buy: return .buy
        case .sell: return .sell
        }
    }
    
    /// 轉換為 TradeAction
    func toTradeAction() -> TradeAction {
        switch self {
        case .buy: return .buy
        case .sell: return .sell
        }
    }
}

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

/// 錦標賽投資組合結構（已移至 TournamentModels.swift，使用 typealias）
/*
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
    var performanceMetrics: PerformanceMetrics
    var lastUpdated: Date
    // 添加歷史數據追蹤
    var dailyValueHistory: [DateValue] = []
    
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
    
    // 添加兼容性屬性
    var totalValue: Double {
        return totalPortfolioValue
    }
    
    var allocations: [AssetAllocation] {
        return holdings.map { holding in
            AssetAllocation(
                symbol: holding.symbol,
                name: holding.name,
                percentage: holding.allocationPercentage,
                value: holding.totalValue,
                investedAmount: holding.totalCost,
                color: StockColorPalette.colorForStock(symbol: holding.symbol).toHex()
            )
        }
    }
    
    // 添加 PortfolioData 兼容性屬性
    
    /// 日變化金額（基於歷史數據）
    var dailyChange: Double {
        return getPortfolioValueChange(daysAgo: 1)
    }
    
    /// 日變化百分比
    var dailyChangePercentage: Double {
        let yesterdayValue = getPortfolioValueDaysAgo(1)
        guard yesterdayValue > 0 else { return 0 }
        return ((totalPortfolioValue - yesterdayValue) / yesterdayValue) * 100
    }
    
    /// 週回報率
    var weeklyReturn: Double {
        let weekAgoValue = getPortfolioValueDaysAgo(7)
        guard weekAgoValue > 0 else { return 0 }
        return ((totalPortfolioValue - weekAgoValue) / weekAgoValue) * 100
    }
    
    /// 月回報率
    var monthlyReturn: Double {
        let monthAgoValue = getPortfolioValueDaysAgo(30)
        guard monthAgoValue > 0 else { return 0 }
        return ((totalPortfolioValue - monthAgoValue) / monthAgoValue) * 100
    }
    
    /// 季回報率
    var quarterlyReturn: Double {
        let quarterAgoValue = getPortfolioValueDaysAgo(90)
        guard quarterAgoValue > 0 else { return 0 }
        return ((totalPortfolioValue - quarterAgoValue) / quarterAgoValue) * 100
    }
    
    /// 投資金額（與PortfolioData兼容）
    var investedAmount: Double {
        return totalInvested
    }
    
    // MARK: - 歷史數據計算輔助方法
    
    /// 獲取指定天數前的投資組合價值
    private func getPortfolioValueDaysAgo(_ days: Int) -> Double {
        let targetDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // 找到最接近的歷史記錄
        let closestRecord = dailyValueHistory
            .sorted { abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate)) }
            .first
        
        return closestRecord?.value ?? initialBalance
    }
    
    /// 獲取指定天數前的價值變化
    private func getPortfolioValueChange(daysAgo: Int) -> Double {
        let pastValue = getPortfolioValueDaysAgo(daysAgo)
        return totalPortfolioValue - pastValue
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
        case dailyValueHistory = "daily_value_history"
    }
}
*/

// 使用統一的類型定義
typealias TournamentPortfolio = TournamentPortfolioV2

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

// TournamentPerformanceMetrics removed - using canonical PerformanceMetrics from TournamentModels.swift

/// 錦標賽投資組合管理器
@MainActor
class TournamentPortfolioManager: ObservableObject {
    static let shared = TournamentPortfolioManager()
    
    // MARK: - Published Properties
    @Published var tournamentPortfolios: [UUID: TournamentPortfolio] = [:]
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - V2.0 Dependencies - 使用新的專門化服務架構
    private let supabaseService = SupabaseService.shared
    private let tradeService = TournamentTradeService.shared
    private let walletService = TournamentWalletService.shared
    private let positionService = TournamentPositionService.shared
    private let rankingService = TournamentRankingService.shared
    private let tournamentService = TournamentService.shared
    private let feeCalculator = FeeCalculator.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTournamentPortfolios()
        setupServiceMonitoring()
    }
    
    /// 設置服務監聽 - 監聽新服務的狀態變化
    private func setupServiceMonitoring() {
        // 監聽錢包服務更新
        walletService.$wallets
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshPortfoliosFromServices()
                }
            }
            .store(in: &cancellables)
        
        // 監聽排名服務更新
        rankingService.$leaderboards
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateRankingsFromService()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 獲取特定錦標賽的投資組合
    func getPortfolio(for tournamentId: UUID) -> TournamentPortfolio? {
        return tournamentPortfolios[tournamentId]
    }
    
    /// 初始化錦標賽投資組合（V2.0 架構）
    func initializePortfolio(for tournament: Tournament, userId: UUID, userName: String) async -> Bool {
        print("🏆 [TournamentPortfolioManager] V2.0 初始化錦標賽投資組合: \(tournament.name)")
        
        // 檢查是否已存在
        if tournamentPortfolios[tournament.id] != nil {
            print("⚠️ 錦標賽投資組合已存在")
            return true
        }
        
        // 驗證錦標賽狀態
        guard tournament.status == .enrolling || tournament.status == .ongoing else {
            print("❌ 錦標賽狀態不允許加入: \(tournament.status)")
            return false
        }
        
        // 檢查參賽人數限制
        guard tournament.currentParticipants < tournament.maxParticipants else {
            print("❌ 錦標賽參賽人數已滿")
            return false
        }
        
        // 使用 TournamentWalletService 創建錢包
        let walletResult = await walletService.createWallet(
            tournamentId: tournament.id,
            userId: userId,
            initialBalance: tournament.initialBalance // 使用 initialBalance 屬性
        )
        
        guard case .success(let wallet) = walletResult else {
            if case .failure(let error) = walletResult {
                print("❌ 創建锦標賽錢包失敗: \(error)")
                self.error = error.localizedDescription
            }
            return false
        }
        
        // 創建本地投資組合記錄（為了維持向後相容）
        var newPortfolio = TournamentPortfolio(
            id: wallet.id,
            tournamentId: tournament.id,
            userId: userId,
            userName: userName,
            holdings: [],
            initialBalance: wallet.initialBalance,
            currentBalance: wallet.cashBalance,
            totalInvested: 0,
            tradingRecords: [],
            performanceMetrics: PerformanceMetrics(
                totalReturn: wallet.totalReturn,
                annualizedReturn: 0, // Will be calculated separately
                maxDrawdown: wallet.maxDrawdown,
                sharpeRatio: nil,
                winRate: wallet.winRate,
                avgHoldingDays: 0,
                diversificationScore: 0,
                riskScore: 0,
                totalTrades: wallet.totalTrades,
                profitableTrades: wallet.winningTrades,
                currentRank: 0,
                maxDrawdownPercentage: wallet.maxDrawdown
            ),
            lastUpdated: Date()
        )
        
        // 初始化歷史數據
        let today = Calendar.current.startOfDay(for: Date())
        newPortfolio.dailyValueHistory = [DateValue(date: today, value: wallet.totalAssets)]
        
        tournamentPortfolios[tournament.id] = newPortfolio
        saveTournamentPortfolios()
        
        print("✅ V2.0 錦標賽投資組合初始化成功 - 初始資金: \(wallet.initialBalance)")
        return true
    }
    
    /// 檢查錦標賽投資組合是否存在
    func hasPortfolio(for tournamentId: UUID) -> Bool {
        return tournamentPortfolios[tournamentId] != nil
    }
    
    /// 獲取所有錦標賽投資組合
    func getAllPortfolios() -> [TournamentPortfolio] {
        return Array(tournamentPortfolios.values)
    }
    
    /// 獲取用戶參與的所有錦標賽投資組合
    func getUserPortfolios(userId: UUID) -> [TournamentPortfolio] {
        return tournamentPortfolios.values.filter { $0.userId == userId }
    }
    
    /// 刪除錦標賽投資組合
    func removePortfolio(for tournamentId: UUID) {
        tournamentPortfolios.removeValue(forKey: tournamentId)
        saveTournamentPortfolios()
        print("🗑️ [TournamentPortfolioManager] 已刪除錦標賽投資組合: \(tournamentId)")
    }
    
    /// 執行錦標賽交易（使用 V2.0 架構）
    func executeTrade(
        tournamentId: UUID,
        userId: UUID? = nil, // 添加 userId 參數
        symbol: String,
        stockName: String,
        action: TradingType,
        shares: Double,
        price: Double
    ) async -> Bool {
        
        print("🔄 [TournamentPortfolioManager] V2.0 執行錦標賽交易: \(action), \(symbol), 股數: \(shares)")
        
        // 步驟1：基本驗證
        guard let portfolio = tournamentPortfolios[tournamentId] else {
            print("❌ 找不到錦標賽投資組合")
            return false
        }
        
        let actualUserId = userId ?? portfolio.userId
        
        // 步驟2：轉換為新的交易類型
        let tradeSide: TradeSide = action == .buy ? .buy : .sell
        
        // 步驟3：使用 TournamentTradeService 執行交易
        isLoading = true
        defer { isLoading = false }
        
        let result = await tradeService.executeTrade(
            tournamentId: tournamentId,
            userId: actualUserId,
            symbol: symbol,
            side: tradeSide,
            qty: shares,
            price: price
        )
        
        switch result {
        case .success(let trade):
            print("✅ [TournamentPortfolioManager] 交易執行成功: \(trade.id)")
            
            // 步驟4：更新本地投資組合快取
            await refreshPortfolioFromServices(tournamentId: tournamentId)
            
            // 步驟5：觸發排名更新（異步進行，不阻塞返回）
            Task {
                await updateRankingFromService(tournamentId: tournamentId)
            }
            
            return true
            
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 交易失敗: \(error.localizedDescription)")
            self.error = error.localizedDescription
            return false
        }
    }
    
    /// 使用新服務刷新特定投資組合
    private func refreshPortfolioFromServices(tournamentId: UUID) async {
        guard let portfolio = tournamentPortfolios[tournamentId] else { return }
        
        do {
            // 從 WalletService 獲取最新錢包狀態
            let wallet = try await walletService.getWallet(
                tournamentId: tournamentId,
                userId: portfolio.userId
            )
            
            // 從 PositionService 獲取最新持倉
            let positionsResult = await positionService.getUserPositions(
                tournamentId: tournamentId,
                userId: portfolio.userId
            )
            
            let positions = try positionsResult.get()
            
            // 更新本地投資組合數據
            var updatedPortfolio = portfolio
            updatedPortfolio.currentBalance = wallet.cashBalance
            
            // 將 TournamentPosition 轉換為 TournamentHolding
            updatedPortfolio.holdings = positions.map { position in
                TournamentHolding(
                    id: UUID(),
                    tournamentId: position.tournamentId,
                    userId: position.userId,
                    symbol: position.symbol,
                    name: position.symbol, // 需要股票名稱，暫時使用代碼
                    shares: position.qty,
                    averagePrice: position.avgCost,
                    currentPrice: position.currentPrice,
                    firstPurchaseDate: position.firstBuyAt ?? Date(),
                    lastUpdated: position.lastUpdated
                )
            }
            
            updatedPortfolio.lastUpdated = Date()
            
            // 更新績效指標 - Note: PerformanceMetrics properties may be immutable
            // Consider creating a new PerformanceMetrics instance if needed
            
            tournamentPortfolios[tournamentId] = updatedPortfolio
            saveTournamentPortfolios()
            
            print("✅ [TournamentPortfolioManager] 投資組合已從服務更新")
        } catch {
            print("❌ [TournamentPortfolioManager] 刷新投資組合失敗: \(error)")
        }
    }
    
    /// 使用新服務更新排名
    private func updateRankingFromService(tournamentId: UUID) async {
        let result = await rankingService.getUserRank(
            tournamentId: tournamentId,
            userId: tournamentPortfolios[tournamentId]?.userId ?? UUID()
        )
        
        switch result {
        case .success(let rankInfo):
            if let portfolio = tournamentPortfolios[tournamentId] {
                // Note: PerformanceMetrics is immutable, ranking info is maintained separately
                // Consider storing ranking info in a separate service or using a different approach
                
                print("📊 [TournamentPortfolioManager] 排名已更新: \(rankInfo.currentRank)")
                // Ranking data is now handled by TournamentRankingService
            }
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 獲取排名失敗: \(error)")
        }
    }
    
    /// 刷新所有投資組合（從新服務）
    private func refreshPortfoliosFromServices() async {
        for tournamentId in tournamentPortfolios.keys {
            await refreshPortfolioFromServices(tournamentId: tournamentId)
        }
    }
    
    /// 更新所有排名（從新服務）
    private func updateRankingsFromService() async {
        for tournamentId in tournamentPortfolios.keys {
            await updateRankingFromService(tournamentId: tournamentId)
        }
    }
    
    /// 更新投資組合績效（使用 V2.0 服務）
    func updatePerformanceMetrics(for tournamentId: UUID) async {
        guard let portfolio = tournamentPortfolios[tournamentId] else { return }
        
        print("📊 [TournamentPortfolioManager] V2.0 更新績效指標: \(tournamentId)")
        
        // 使用 WalletService 獲取最新數據
        do {
            let wallet = try await walletService.getWallet(
                tournamentId: tournamentId,
                userId: portfolio.userId
            )
            
            // 更新本地投資組合的績效指標 - Note: PerformanceMetrics properties may be immutable
            // Consider creating a new PerformanceMetrics instance if needed
            var updatedPortfolio = portfolio
            
            updatedPortfolio.lastUpdated = Date()
            tournamentPortfolios[tournamentId] = updatedPortfolio
            saveTournamentPortfolios()
            
            print("✅ [TournamentPortfolioManager] 績效指標已更新")
        } catch {
            print("❌ [TournamentPortfolioManager] 更新績效指標失敗: \(error)")
        }
    }
    
    /// 獲取錦標賽排名資訊（V2.0）
    func getTournamentRanking(for tournamentId: UUID) async -> [TournamentLeaderboardEntry] {
        let result = await rankingService.getLeaderboard(tournamentId: tournamentId)
        
        switch result {
        case .success(let leaderboard):
            return leaderboard
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 獲取排名失敗: \(error)")
            return []
        }
    }
    
    /// 獲取用戶在錦標賽中的排名（V2.0）
    func getUserRanking(for tournamentId: UUID, userId: UUID) async -> Int? {
        let result = await rankingService.getUserRank(
            tournamentId: tournamentId,
            userId: userId
        )
        
        switch result {
        case .success(let rankInfo):
            return rankInfo.currentRank
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 獲取用戶排名失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// 使用新服務計算投資組合統計資訊
    func getPortfolioStatistics(for tournamentId: UUID) async -> PortfolioStatistics? {
        guard let portfolio = tournamentPortfolios[tournamentId] else { return nil }
        
        do {
            let positionsResult = await positionService.getUserPositions(
                tournamentId: tournamentId,
                userId: portfolio.userId
            )
            
            let positions = try positionsResult.get()
            return positionService.calculatePortfolioStatistics(positions: positions)
        } catch {
            print("❌ [TournamentPortfolioManager] 獲取統計資訊失敗: \(error)")
            return nil
        }
    }
    
    /// 使用新服務獲取錢包分析
    func getWalletAnalysis(for tournamentId: UUID) async -> WalletAnalysis? {
        guard let portfolio = tournamentPortfolios[tournamentId] else { return nil }
        
        do {
            let wallet = try await walletService.getWallet(
                tournamentId: tournamentId,
                userId: portfolio.userId
            )
            return walletService.analyzeWallet(wallet: wallet)
        } catch {
            print("❌ [TournamentPortfolioManager] 獲取錢包分析失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - V2.0 Wallet History Management
    
    /// 使用新服務獲取錢包歷史
    func getWalletHistory(for tournamentId: UUID, days: Int = 30) async -> [WalletHistoryEntry] {
        guard let portfolio = tournamentPortfolios[tournamentId] else { return [] }
        
        let result = await walletService.getWalletHistory(
            tournamentId: tournamentId,
            userId: portfolio.userId,
            days: days
        )
        
        switch result {
        case .success(let history):
            return history
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 獲取錢包歷史失敗: \(error)")
            return []
        }
    }
    
    // MARK: - V2.0 Analytics Methods - 使用新服務的進階分析
    
    /// 獲取錦標賽統計資訊
    func getTournamentStatistics(for tournamentId: UUID) async -> TournamentStats? {
        let result = await rankingService.calculateAdvancedStats(tournamentId: tournamentId)
        
        switch result {
        case .success(let stats):
            return stats
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 獲取錦標賽統計失敗: \(error)")
            return nil
        }
    }
    
    /// 生成每日快照（使用排名服務）
    func generateDailySnapshot(for tournamentId: UUID) async -> Bool {
        let result = await rankingService.generateDailySnapshot(tournamentId: tournamentId)
        
        switch result {
        case .success(let count):
            print("✅ [TournamentPortfolioManager] 每日快照已生成: \(count) 個")
            return true
        case .failure(let error):
            print("❌ [TournamentPortfolioManager] 生成快照失敗: \(error)")
            return false
        }
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
    
    // MARK: - V2.0 Simplified Backend Sync - 使用新服務架構自動同步
    
    /// 強制刷新所有服務的排名計算
    func forceRefreshAllRankings() async {
        await rankingService.recalculateAllActiveRankings()
        await updateRankingsFromService()
        print("✅ [TournamentPortfolioManager] 所有排名已強制更新")
    }
    
    /// 獲取錦標賽成員（V2.0）
    func getTournamentMembers(for tournamentId: UUID) async -> [TournamentMember] {
        do {
            return try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
        } catch {
            print("❌ [TournamentPortfolioManager] 獲取錦標賽成員失敗: \(error)")
            return []
        }
    }
    
    /// 檢查交易能力（V2.0）
    func checkTradingCapability(
        tournamentId: UUID,
        side: TradeSide,
        amount: Double,
        fees: Double
    ) async -> TradingCapabilityCheck? {
        guard let portfolio = tournamentPortfolios[tournamentId] else { return nil }
        
        do {
            let wallet = try await walletService.getWallet(
                tournamentId: tournamentId,
                userId: portfolio.userId
            )
            return walletService.checkTradingCapability(
                wallet: wallet,
                side: side,
                amount: amount,
                fees: fees
            )
        } catch {
            print("❌ [TournamentPortfolioManager] 檢查交易能力失敗: \(error)")
            return nil
        }
    }
}

// MARK: - V2.0 Extensions - 適配新架構

extension TradingType {
    /// 轉換為 TradeSide
    func toTournamentTradeSide() -> TradeSide {
        switch self {
        case .buy:
            return .buy
        case .sell:
            return .sell
        }
    }
    
    /// 轉換為 TradeAction 類型（向後相容）
    func toTradeAction() -> TradeAction {
        switch self {
        case .buy:
            return TradeAction.buy
        case .sell:
            return TradeAction.sell
        }
    }
}

// MARK: - Supporting Types

// DateValue struct moved to TournamentModels.swift

// TradingHours struct moved to TournamentModels.swift

// TournamentRules struct moved to TournamentModels.swift

/// 股票類型枚舉
enum StockType: String, Codable, CaseIterable {
    case listed = "listed"
    case otc = "otc"
    case emerging = "emerging"
}

/// 錦標賽資產分配結構
struct TournamentAllocation: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let name: String
    let percentage: Double
    let value: Double
}

// MARK: - V2.0 Architecture Notes
//
// 這個 TournamentPortfolioManager 已經重構為使用 V2.0 架構：
// 
// 1. **數據分離**: 使用專門的錦標賽數據表，與日常交易完全隔離
// 2. **服務專業化**: 使用專門的服務類處理不同職責
//    - TournamentTradeService: 處理交易執行和驗證
//    - TournamentWalletService: 管理錢包和資金狀況
//    - TournamentPositionService: 管理持倉和價格更新
//    - TournamentRankingService: 計算排名和生成快照
// 3. **實時更新**: 通過服務監聽自動更新本地數據
// 4. **向後相容**: 保持原有介面，方便現有 UI 使用
// 5. **數據一致性**: 新架構確保數據在多個服務間保持同步
//
// V2.0 典型流程：
// 建賽事 → 參賽(initializePortfolio) → 下單(executeTrade) → 排行(getRanking) → 結算(generateSnapshot)

// Note: SupabaseService methods for tournament portfolio management 
// are implemented in the main SupabaseService.swift file