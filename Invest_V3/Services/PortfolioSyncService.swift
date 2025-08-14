//
//  PortfolioSyncService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  投資組合數據同步服務 - 統一管理本地與數據庫的投資組合數據
//

import Foundation
import SwiftUI
import Combine

/// 投資組合數據同步服務
/// 負責統一管理本地 ChatPortfolioManager 和數據庫/錦標賽系統的數據同步
@MainActor
class PortfolioSyncService: ObservableObject {
    static let shared = PortfolioSyncService()
    
    // MARK: - Published Properties
    
    /// 同步狀態
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var hasPendingChanges: Bool = false
    
    // MARK: - Dependencies
    
    private let chatPortfolioManager = ChatPortfolioManager.shared
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    private let syncInterval: TimeInterval = 30.0 // 30秒同步一次
    private var syncTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        startPeriodicSync()
    }
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // 監聽 ChatPortfolioManager 的變化
        chatPortfolioManager.objectWillChange
            .sink { [weak self] _ in
                self?.hasPendingChanges = true
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.hasPendingChanges == true {
                    await self?.syncToDatabase()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 手動觸發同步
    func manualSync() async {
        await syncToDatabase()
        await syncFromDatabase()
    }
    
    /// 獲取錦標賽特定的投資組合數據
    func getPortfolioForTournament(_ tournamentId: UUID?) -> [PortfolioHolding] {
        if let tournamentId = tournamentId {
            // 根據交易記錄過濾出特定錦標賽的持股
            let tournamentRecords = chatPortfolioManager.tradingRecords.filter { 
                $0.tournamentId == tournamentId 
            }
            
            // 計算錦標賽相關的股票符號
            let tournamentSymbols = Set(tournamentRecords.map { $0.symbol })
            
            // 只返回該錦標賽相關的持股
            let filteredHoldings = chatPortfolioManager.holdings.filter { 
                tournamentSymbols.contains($0.symbol) 
            }
            
            print("🏆 [PortfolioSyncService] 錦標賽 \(tournamentId): 過濾出 \(filteredHoldings.count) 個持股")
            return filteredHoldings
        } else {
            // 一般模式：返回沒有錦標賽關聯的持股
            let generalRecords = chatPortfolioManager.tradingRecords.filter { 
                $0.tournamentId == nil 
            }
            let generalSymbols = Set(generalRecords.map { $0.symbol })
            
            let filteredHoldings = chatPortfolioManager.holdings.filter { 
                generalSymbols.contains($0.symbol) 
            }
            
            print("📊 [PortfolioSyncService] 一般模式: 過濾出 \(filteredHoldings.count) 個持股")
            return filteredHoldings
        }
    }
    
    /// 同步到數據庫
    func syncToDatabase() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // 同步投資組合數據
            try await syncPortfolioToDatabase()
            
            // 同步交易記錄
            try await syncTradingRecordsToDatabase()
            
            lastSyncTime = Date()
            hasPendingChanges = false
            
            print("✅ [PortfolioSyncService] 數據同步到數據庫成功")
            
        } catch {
            syncError = "同步失敗: \(error.localizedDescription)"
            print("❌ [PortfolioSyncService] 同步到數據庫失敗: \(error)")
        }
        
        isSyncing = false
    }
    
    /// 從數據庫同步
    func syncFromDatabase() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // 從數據庫獲取最新數據
            try await loadPortfolioFromDatabase()
            
            lastSyncTime = Date()
            
            print("✅ [PortfolioSyncService] 從數據庫同步數據成功")
            
        } catch {
            syncError = "載入失敗: \(error.localizedDescription)"
            print("❌ [PortfolioSyncService] 從數據庫同步失敗: \(error)")
        }
        
        isSyncing = false
    }
    
    /// 清除同步錯誤
    func clearSyncError() {
        syncError = nil
    }
    
    // MARK: - Private Sync Methods
    
    private func syncPortfolioToDatabase() async throws {
        // 獲取當前錦標賽上下文
        let tournamentStateManager = TournamentStateManager.shared
        let currentTournamentId = tournamentStateManager.getCurrentTournamentId()
        
        // 根據是否在錦標賽模式來決定同步範圍
        if let tournamentId = currentTournamentId {
            // 錦標賽模式：只同步有錦標賽 ID 的交易記錄相關的持股
            let tournamentRecords = chatPortfolioManager.tradingRecords.filter { 
                $0.tournamentId == tournamentId 
            }
            
            // 計算錦標賽相關的持股
            let tournamentSymbols = Set(tournamentRecords.map { $0.symbol })
            let tournamentHoldings = chatPortfolioManager.holdings.filter { 
                tournamentSymbols.contains($0.symbol) 
            }
            
            for holding in tournamentHoldings {
                print("📊 同步持股: \(holding.symbol) - \(holding.shares) shares")
            }
            
            print("🏆 [PortfolioSyncService] 錦標賽模式: 只同步 \(tournamentHoldings.count) 個錦標賽相關持股")
        } else {
            // 一般模式：同步所有持股
            let holdings = chatPortfolioManager.holdings
            
            for holding in holdings {
                print("📊 同步持股: \(holding.symbol) - \(holding.shares) shares")
            }
            
            print("📊 [PortfolioSyncService] 一般模式: 同步 \(holdings.count) 個持股")
        }
    }
    
    private func syncTradingRecordsToDatabase() async throws {
        // 獲取當前錦標賽上下文
        let tournamentStateManager = TournamentStateManager.shared
        let currentTournamentId = tournamentStateManager.getCurrentTournamentId()
        
        // 根據是否在錦標賽模式來過濾交易記錄
        let recordsToSync: [TradingRecord]
        
        if let tournamentId = currentTournamentId {
            // 錦標賽模式：只同步該錦標賽的交易記錄
            recordsToSync = chatPortfolioManager.tradingRecords.filter { 
                $0.tournamentId == tournamentId 
            }
            print("🏆 [PortfolioSyncService] 錦標賽模式: 過濾出 \(recordsToSync.count) 筆錦標賽交易記錄")
        } else {
            // 一般模式：只同步沒有錦標賽 ID 的交易記錄
            recordsToSync = chatPortfolioManager.tradingRecords.filter { 
                $0.tournamentId == nil 
            }
            print("📊 [PortfolioSyncService] 一般模式: 過濾出 \(recordsToSync.count) 筆一般交易記錄")
        }
        
        for record in recordsToSync {
            print("📝 同步交易記錄: \(record.symbol) - \(record.type) - \(record.shares)")
        }
    }
    
    private func loadPortfolioFromDatabase() async throws {
        // 這裡可以從 Supabase 載入投資組合數據
        // 然後更新 ChatPortfolioManager
        print("📥 從數據庫載入投資組合數據")
    }
    
    // MARK: - Tournament Integration
    
    /// 為特定錦標賽創建交易
    func executeTournamentTrade(
        tournamentId: UUID?,
        symbol: String,
        stockName: String,
        action: TradingType,
        shares: Double,
        price: Double
    ) async -> Bool {
        print("🔄 [PortfolioSyncService] executeTournamentTrade: \(action), \(symbol), 股數: \(shares), 價格: \(price)")
        
        let success: Bool
        
        if action == TradingType.buy {
            success = chatPortfolioManager.buyStock(
                symbol: symbol,
                shares: shares,
                price: price,
                stockName: stockName,
                tournamentId: tournamentId
            )
        } else {
            success = chatPortfolioManager.sellStock(
                symbol: symbol,
                shares: shares,
                price: price,
                tournamentId: tournamentId
            )
        }
        
        print("🔍 [PortfolioSyncService] executeTournamentTrade 結果: \(success ? "成功" : "失敗")")
        
        if success {
            // 如果有錦標賽 ID，更新交易記錄的錦標賽關聯
            if let tournamentId = tournamentId,
               let lastRecord = chatPortfolioManager.tradingRecords.last {
                // 創建包含錦標賽 ID 的新記錄
                let updatedRecord = TradingRecord(
                    id: lastRecord.id,
                    userId: lastRecord.userId,
                    tournamentId: tournamentId,
                    symbol: lastRecord.symbol,
                    stockName: lastRecord.stockName,
                    type: lastRecord.type,
                    shares: lastRecord.shares,
                    price: lastRecord.price,
                    timestamp: lastRecord.timestamp,
                    totalAmount: lastRecord.totalAmount,
                    fee: lastRecord.fee,
                    netAmount: lastRecord.netAmount,
                    averageCost: lastRecord.averageCost,
                    realizedGainLoss: lastRecord.realizedGainLoss,
                    realizedGainLossPercent: lastRecord.realizedGainLossPercent,
                    notes: lastRecord.notes
                )
                
                // 替換最後一筆記錄
                if let lastIndex = chatPortfolioManager.tradingRecords.lastIndex(where: { $0.id == lastRecord.id }) {
                    chatPortfolioManager.tradingRecords[lastIndex] = updatedRecord
                }
            }
            
            // 標記有待同步的變更
            hasPendingChanges = true
            
            // 立即同步到數據庫
            Task {
                await syncToDatabase()
            }
        }
        
        return success
    }
    
    /// 獲取錦標賽相關的統計數據
    func getTournamentStatistics(tournamentId: UUID?) -> TournamentTradingStatistics {
        let allRecords = chatPortfolioManager.tradingRecords
        let tournamentRecords = tournamentId != nil ? 
            allRecords.filter { $0.tournamentId == tournamentId } : allRecords
        
        let buyRecords = tournamentRecords.filter { $0.type == TradingType.buy }
        let sellRecords = tournamentRecords.filter { $0.type == TradingType.sell }
        
        let totalVolume = tournamentRecords.reduce(0) { $0 + $1.totalAmount }
        let totalRealizedGainLoss = sellRecords.compactMap { $0.realizedGainLoss }.reduce(0, +)
        let totalFees = tournamentRecords.reduce(0) { $0 + $1.fee }
        
        let profitableTrades = sellRecords.filter { ($0.realizedGainLoss ?? 0) > 0 }
        let winRate = sellRecords.isEmpty ? 0 : Double(profitableTrades.count) / Double(sellRecords.count) * 100
        
        return TournamentTradingStatistics(
            totalTrades: tournamentRecords.count,
            totalVolume: totalVolume,
            totalFees: totalFees,
            winRate: winRate,
            winningTrades: profitableTrades.count,
            losingTrades: sellRecords.count - profitableTrades.count
        )
    }
}

// MARK: - Supporting Types


/// 同步狀態
enum SyncStatus {
    case idle
    case syncing
    case success
    case error(String)
}
