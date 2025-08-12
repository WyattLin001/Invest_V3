//
//  TournamentTradeService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽交易服務 - 專門處理錦標賽內的買賣交易，完全隔離於日常交易
//

import Foundation
import Combine

// MARK: - 錦標賽交易服務
@MainActor
class TournamentTradeService: ObservableObject {
    static let shared = TournamentTradeService(shared: ())
    
    // MARK: - Published Properties
    @Published var isExecutingTrade = false
    @Published var recentTrades: [TournamentTrade] = []
    @Published var tradingError: String?
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let positionService = TournamentPositionService.shared
    private let walletService = TournamentWalletService.shared
    private let stockService = StockService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 公開初始化器（用於測試和依賴注入）
    init() {
        // 用於測試的公開初始化器
    }
    
    private init(shared: Void) {
        setupRealtimeUpdates()
    }
    
    // MARK: - Public Methods
    
    /// 執行錦標賽交易
    func executeTrade(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        side: TradeSide,
        qty: Double,
        price: Double
    ) async -> Result<TournamentTrade, TournamentTradeError> {
        
        guard !isExecutingTrade else {
            return .failure(.tradeInProgress)
        }
        
        isExecutingTrade = true
        defer { isExecutingTrade = false }
        
        print("🔄 [TournamentTradeService] 執行錦標賽交易: \(side.displayName) \(symbol) \(qty)股 @ NT$\(price)")
        
        do {
            // 1. 驗證交易基本參數
            try validateTradeParameters(symbol: symbol, qty: qty, price: price)
            
            // 2. 檢查錦標賽狀態
            let tournament = try await getTournament(id: tournamentId)
            try validateTournamentStatus(tournament)
            
            // 3. 檢查用戶錢包狀態
            let wallet = try await walletService.getWallet(tournamentId: tournamentId, userId: userId)
            
            // 4. 驗證交易規則
            try await validateTradeRules(
                tournament: tournament,
                wallet: wallet,
                symbol: symbol,
                side: side,
                qty: qty,
                price: price
            )
            
            // 5. 計算交易費用
            let fees = calculateTradingFees(amount: qty * price, side: side)
            
            // 6. 執行原子交易
            let trade = try await executeAtomicTrade(
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: side,
                qty: qty,
                price: price,
                fees: fees
            )
            
            // 7. 更新本地快取
            await updateLocalCache(trade: trade)
            
            print("✅ [TournamentTradeService] 交易執行成功: \(trade.id)")
            return .success(trade)
            
        } catch let error as TournamentTradeError {
            print("❌ [TournamentTradeService] 交易失敗: \(error.localizedDescription)")
            tradingError = error.localizedDescription
            return .failure(error)
        } catch {
            print("❌ [TournamentTradeService] 未預期錯誤: \(error)")
            let tradeError = TournamentTradeError.unknownError(error.localizedDescription)
            tradingError = tradeError.localizedDescription
            return .failure(tradeError)
        }
    }
    
    /// 獲取用戶交易歷史
    func getUserTrades(
        tournamentId: UUID,
        userId: UUID,
        limit: Int = 50,
        offset: Int = 0
    ) async -> Result<[TournamentTrade], Error> {
        do {
            let trades = try await supabaseService.fetchTournamentTrades(
                tournamentId: tournamentId,
                userId: userId,
                limit: limit,
                offset: offset
            )
            return .success(trades)
        } catch {
            print("❌ [TournamentTradeService] 獲取交易歷史失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取錦標賽所有交易（管理員功能）
    func getTournamentTrades(
        tournamentId: UUID,
        limit: Int = 100,
        offset: Int = 0
    ) async -> Result<[TournamentTrade], Error> {
        do {
            let trades = try await supabaseService.fetchAllTournamentTrades(
                tournamentId: tournamentId,
                limit: limit,
                offset: offset
            )
            return .success(trades)
        } catch {
            print("❌ [TournamentTradeService] 獲取錦標賽交易失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 取消交易（僅限待執行狀態）
    func cancelTrade(tradeId: UUID) async -> Result<Void, Error> {
        do {
            try await supabaseService.cancelTournamentTrade(tradeId: tradeId)
            
            // 更新本地快取
            if let index = recentTrades.firstIndex(where: { $0.id == tradeId }) {
                recentTrades[index] = TournamentTrade(
                    id: recentTrades[index].id,
                    tournamentId: recentTrades[index].tournamentId,
                    userId: recentTrades[index].userId,
                    symbol: recentTrades[index].symbol,
                    side: recentTrades[index].side,
                    qty: recentTrades[index].qty,
                    price: recentTrades[index].price,
                    amount: recentTrades[index].amount,
                    fees: recentTrades[index].fees,
                    netAmount: recentTrades[index].netAmount,
                    realizedPnl: recentTrades[index].realizedPnl,
                    realizedPnlPercentage: recentTrades[index].realizedPnlPercentage,
                    status: .cancelled,
                    executedAt: recentTrades[index].executedAt,
                    createdAt: recentTrades[index].createdAt
                )
            }
            
            print("✅ [TournamentTradeService] 交易已取消: \(tradeId)")
            return .success(())
        } catch {
            print("❌ [TournamentTradeService] 取消交易失敗: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Private Methods
    
    /// 驗證交易基本參數
    private func validateTradeParameters(symbol: String, qty: Double, price: Double) throws {
        guard !symbol.isEmpty else {
            throw TournamentTradeError.invalidSymbol
        }
        
        guard qty > 0 else {
            throw TournamentTradeError.invalidQuantity
        }
        
        guard price > 0 else {
            throw TournamentTradeError.invalidPrice
        }
        
        // 檢查是否為整股交易（台股通常要求1000股為一張）
        let shares = Int(qty)
        if shares % 1000 != 0 {
            throw TournamentTradeError.invalidQuantity
        }
    }
    
    /// 驗證錦標賽狀態
    private func validateTournamentStatus(_ tournament: Tournament) throws {
        guard tournament.status == .ongoing else {
            throw TournamentTradeError.tournamentNotActive
        }
        
        let now = Date()
        guard now >= tournament.startsAt && now <= tournament.endsAt else {
            throw TournamentTradeError.tournamentNotActive
        }
    }
    
    /// 驗證交易規則
    private func validateTradeRules(
        tournament: Tournament,
        wallet: TournamentPortfolioV2,
        symbol: String,
        side: TradeSide,
        qty: Double,
        price: Double
    ) async throws {
        
        let tradeAmount = qty * price
        
        if side == .buy {
            // 買入驗證
            let fees = calculateTradingFees(amount: tradeAmount, side: side)
            let totalCost = tradeAmount + fees
            
            // 檢查現金是否充足
            guard wallet.cashBalance >= totalCost else {
                throw TournamentTradeError.insufficientFunds
            }
            
            // 檢查單一股票配置限制
            let currentPositions = try await positionService.getUserPositions(
                tournamentId: tournament.id,
                userId: wallet.userId
            ).get()
            
            let currentHolding = currentPositions.first { $0.symbol == symbol }
            let currentValue = currentHolding?.marketValue ?? 0
            let newTotalValue = currentValue + tradeAmount
            let allocationPercentage = (newTotalValue / wallet.totalAssets) * 100
            
            guard allocationPercentage <= tournament.maxSingleStockRate else {
                throw TournamentTradeError.exceedsPositionLimit
            }
            
        } else {
            // 賣出驗證
            let positions = try await positionService.getUserPositions(
                tournamentId: tournament.id,
                userId: wallet.userId
            ).get()
            
            guard let position = positions.first(where: { $0.symbol == symbol }) else {
                throw TournamentTradeError.noPosition
            }
            
            guard position.qty >= qty else {
                throw TournamentTradeError.insufficientShares
            }
        }
    }
    
    /// 計算交易費用
    private func calculateTradingFees(amount: Double, side: TradeSide) -> Double {
        // 台股手續費：0.1425%，最低20元
        let brokerageFee = max(20, amount * 0.001425)
        
        // 證交稅：賣出時收取0.3%
        let transactionTax = side == .sell ? amount * 0.003 : 0
        
        return brokerageFee + transactionTax
    }
    
    /// 執行原子交易（確保所有相關表格同步更新）
    private func executeAtomicTrade(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        side: TradeSide,
        qty: Double,
        price: Double,
        fees: Double
    ) async throws -> TournamentTrade {
        
        // 創建交易記錄
        let trade = TournamentTrade(
            id: UUID(),
            tournamentId: tournamentId,
            userId: userId,
            symbol: symbol,
            side: side,
            qty: qty,
            price: price,
            amount: qty * price,
            fees: fees,
            netAmount: side == .buy ? (qty * price) + fees : (qty * price) - fees,
            realizedPnl: nil,
            realizedPnlPercentage: nil,
            status: .executed,
            executedAt: Date(),
            createdAt: Date()
        )
        
        // 使用數據庫事務執行原子操作
        try await supabaseService.executeTransactionBlock { client in
            // 1. 插入交易記錄
            try await client.insertTournamentTrade(trade)
            
            // 2. 更新持倉
            try await client.updateTournamentPosition(
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: side,
                qty: qty,
                price: price
            )
            
            // 3. 更新錢包
            try await client.updateTournamentWallet(
                tournamentId: tournamentId,
                userId: userId,
                side: side,
                amount: qty * price,
                fees: fees
            )
        }
        
        return trade
    }
    
    /// 獲取錦標賽資訊
    private func getTournament(id: UUID) async throws -> Tournament {
        guard let tournament = try await TournamentService.shared.fetchTournament(id: id) else {
            throw TournamentTradeError.tournamentNotFound
        }
        return tournament
    }
    
    /// 更新本地快取
    private func updateLocalCache(trade: TournamentTrade) async {
        recentTrades.insert(trade, at: 0)
        
        // 只保留最近100筆交易
        if recentTrades.count > 100 {
            recentTrades = Array(recentTrades.prefix(100))
        }
        
        // 清除錯誤狀態
        tradingError = nil
    }
    
    /// 設置即時更新
    private func setupRealtimeUpdates() {
        // 監聽錦標賽交易的即時更新
        // 這裡可以實現 Supabase Realtime 的監聽
        // 目前先使用定時刷新機制
    }
}

// MARK: - 錦標賽交易錯誤類型
enum TournamentTradeError: LocalizedError {
    case tradeInProgress
    case invalidSymbol
    case invalidQuantity
    case invalidPrice
    case tournamentNotFound
    case tournamentNotActive
    case insufficientFunds
    case insufficientShares
    case noPosition
    case exceedsPositionLimit
    case networkError(String)
    case databaseError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .tradeInProgress:
            return "交易進行中，請稍後再試"
        case .invalidSymbol:
            return "無效的股票代碼"
        case .invalidQuantity:
            return "交易數量必須為正整數且為完整股數（1000股的倍數）"
        case .invalidPrice:
            return "交易價格必須大於0"
        case .tournamentNotFound:
            return "找不到指定的錦標賽"
        case .tournamentNotActive:
            return "錦標賽尚未開始或已結束"
        case .insufficientFunds:
            return "資金不足"
        case .insufficientShares:
            return "持股數量不足"
        case .noPosition:
            return "未持有該股票"
        case .exceedsPositionLimit:
            return "超過單一股票持倉限制"
        case .networkError(let message):
            return "網路錯誤：\(message)"
        case .databaseError(let message):
            return "資料庫錯誤：\(message)"
        case .unknownError(let message):
            return "未知錯誤：\(message)"
        }
    }
}

// MARK: - 交易統計結構
struct TradingStatistics {
    let totalTrades: Int
    let totalVolume: Double
    let totalFees: Double
    let winningTrades: Int
    let losingTrades: Int
    let winRate: Double
    let averageProfit: Double
    let averageLoss: Double
    let profitFactor: Double
    
    init(trades: [TournamentTrade]) {
        self.totalTrades = trades.count
        self.totalVolume = trades.reduce(0) { $0 + $1.amount }
        self.totalFees = trades.reduce(0) { $0 + $1.fees }
        
        let sellTrades = trades.filter { $0.side == .sell && $0.realizedPnl != nil }
        let profits = sellTrades.compactMap { $0.realizedPnl }.filter { $0 > 0 }
        let losses = sellTrades.compactMap { $0.realizedPnl }.filter { $0 < 0 }
        
        self.winningTrades = profits.count
        self.losingTrades = losses.count
        self.winRate = sellTrades.isEmpty ? 0 : Double(profits.count) / Double(sellTrades.count)
        self.averageProfit = profits.isEmpty ? 0 : profits.reduce(0, +) / Double(profits.count)
        self.averageLoss = losses.isEmpty ? 0 : abs(losses.reduce(0, +) / Double(losses.count))
        
        let totalProfit = profits.reduce(0, +)
        let totalLoss = abs(losses.reduce(0, +))
        self.profitFactor = totalLoss == 0 ? (totalProfit > 0 ? Double.infinity : 0) : totalProfit / totalLoss
    }
}