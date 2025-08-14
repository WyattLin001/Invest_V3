//
//  TournamentWalletService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽錢包服務 - 專門管理錦標賽內的資金狀況，包含現金、股票價值和總資產
//

import Foundation
import Combine

// MARK: - 錦標賽錢包服務
@MainActor
class TournamentWalletService: ObservableObject {
    static let shared =  TournamentWalletService(shared: ())
    
    // MARK: - Published Properties
    @Published var wallets: [String: TournamentPortfolioV2] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let positionService = TournamentPositionService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 公開初始化器（用於測試和依賴注入）
    init() {
        // 用於測試的公開初始化器
    }
    
    private init(shared: Void) {
        // 監聽持倉服務的更新
        positionService.$lastUpdated
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshWalletValues()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 獲取用戶在特定錦標賽的錢包
    func getWallet(tournamentId: UUID, userId: UUID) async throws -> TournamentPortfolioV2 {
        let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
        
        // 先檢查快取
        if let cachedWallet = wallets[cacheKey],
           let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 30 { // 30秒內的快取有效
            return cachedWallet
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let wallet = try await supabaseService.fetchTournamentPortfolio(
                tournamentId: tournamentId,
                userId: userId
            )
            
            // 更新快取
            wallets[cacheKey] = wallet
            lastUpdated = Date()
            
            print("✅ [TournamentWalletService] 錢包資料已更新: 總資產 NT$\(wallet.totalAssets)")
            return wallet
        } catch {
            print("❌ [TournamentWalletService] 獲取錢包失敗: \(error)")
            throw error
        }
    }
    
    /// 創建新錢包（用戶參賽時）
    func createWallet(
        tournamentId: UUID,
        userId: UUID,
        initialBalance: Double
    ) async -> Result<TournamentPortfolioV2, Error> {
        do {
            let wallet = TournamentPortfolioV2(
                id: UUID(),
                tournamentId: tournamentId,
                userId: userId,
                cashBalance: initialBalance,
                equityValue: 0,
                totalAssets: initialBalance,
                initialBalance: initialBalance,
                totalReturn: 0,
                returnPercentage: 0,
                totalTrades: 0,
                winningTrades: 0,
                maxDrawdown: 0,
                dailyReturn: 0.0,
                sharpeRatio: nil,
                lastUpdated: Date()
            )
            
            try await supabaseService.createTournamentPortfolio(wallet)
            
            // 更新快取
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            wallets[cacheKey] = wallet
            
            print("✅ [TournamentWalletService] 新錢包已創建: \(wallet.id)")
            return .success(wallet)
        } catch {
            print("❌ [TournamentWalletService] 創建錢包失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 更新錢包餘額（由交易服務調用）
    func updateBalance(
        tournamentId: UUID,
        userId: UUID,
        side: TradeSide,
        amount: Double,
        fees: Double
    ) async -> Result<TournamentPortfolioV2, Error> {
        do {
            let updatedWallet = try await supabaseService.updateTournamentWallet(
                tournamentId: tournamentId,
                userId: userId,
                side: side.rawValue,
                amount: amount,
                fees: fees
            )
            
            // 更新快取
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            wallets[cacheKey] = updatedWallet
            
            print("💰 [TournamentWalletService] 錢包餘額已更新: 現金 NT$\(updatedWallet.cashBalance)")
            return .success(updatedWallet)
        } catch {
            print("❌ [TournamentWalletService] 更新餘額失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取錢包歷史記錄
    func getWalletHistory(
        tournamentId: UUID,
        userId: UUID,
        days: Int = 30
    ) async -> Result<[WalletHistoryEntry], Error> {
        do {
            let snapshots = try await supabaseService.fetchTournamentSnapshots(
                tournamentId: tournamentId,
                userId: userId,
                limit: days
            )
            
            let history = snapshots.map { snapshot in
                WalletHistoryEntry(
                    date: snapshot.asOfDate,
                    cash: snapshot.cash,
                    equityValue: snapshot.positionValue,
                    totalAssets: snapshot.totalAssets,
                    returnPercentage: snapshot.returnRate * 100,
                    dailyChange: snapshot.dailyReturn
                )
            }.sorted { $0.date > $1.date }
            
            return .success(history)
        } catch {
            print("❌ [TournamentWalletService] 獲取錢包歷史失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 計算錢包分析資料
    func analyzeWallet(wallet: TournamentPortfolioV2) -> WalletAnalysis {
        let assetAllocation = WalletAssetAllocation(
            cashPercentage: wallet.cashPercentage,
            equityPercentage: wallet.equityPercentage
        )
        
        let performance = WalletPerformanceMetrics(
            totalReturn: wallet.totalReturn,
            returnPercentage: wallet.returnPercentage,
            winRate: wallet.winRate
        )
        
        let riskProfile = calculateRiskProfile(wallet: wallet)
        
        return WalletAnalysis(
            assetAllocation: assetAllocation,
            performance: performance,
            riskProfile: riskProfile,
            recommendations: generateRecommendations(wallet: wallet)
        )
    }
    
    /// 檢查交易能力
    func checkTradingCapability(
        wallet: TournamentPortfolioV2,
        side: TradeSide,
        amount: Double,
        fees: Double
    ) -> TradingCapabilityCheck {
        
        switch side {
        case .buy:
            let totalCost = amount + fees
            let canTrade = wallet.cashBalance >= totalCost
            let availableAmount = wallet.cashBalance - fees
            
            return TradingCapabilityCheck(
                canTrade: canTrade,
                maxAmount: max(0, availableAmount),
                reason: canTrade ? nil : "現金餘額不足"
            )
            
        case .sell:
            // 賣出的能力檢查需要結合持倉資訊
            return TradingCapabilityCheck(
                canTrade: true,
                maxAmount: wallet.equityValue,
                reason: nil
            )
        }
    }
    
    /// 強制刷新所有錢包數值
    func refreshAllWallets() async {
        guard !wallets.isEmpty else { return }
        
        print("🔄 [TournamentWalletService] 開始刷新所有錢包...")
        
        var refreshedWallets: [String: TournamentPortfolioV2] = [:]
        
        for (cacheKey, wallet) in wallets {
            do {
                let refreshedWallet = try await supabaseService.fetchTournamentPortfolio(
                    tournamentId: wallet.tournamentId,
                    userId: wallet.userId
                )
                refreshedWallets[cacheKey] = refreshedWallet
            } catch {
                print("❌ [TournamentWalletService] 刷新錢包失敗: \(error)")
                // 保留舊的錢包數據
                refreshedWallets[cacheKey] = wallet
            }
        }
        
        wallets = refreshedWallets
        lastUpdated = Date()
        
        print("✅ [TournamentWalletService] 錢包刷新完成")
    }
    
    // MARK: - Private Methods
    
    /// 生成快取鍵值
    private func generateCacheKey(tournamentId: UUID, userId: UUID) -> String {
        return "\(tournamentId.uuidString)-\(userId.uuidString)"
    }
    
    /// 刷新錢包價值（持倉變動時觸發）
    private func refreshWalletValues() async {
        // 重新計算所有錢包的股票價值
        for (cacheKey, wallet) in wallets {
            do {
                let positions = try await positionService.getUserPositions(
                    tournamentId: wallet.tournamentId,
                    userId: wallet.userId
                ).get()
                
                let newEquityValue = positions.reduce(0) { $0 + $1.marketValue }
                
                let updatedWallet = TournamentPortfolioV2(
                    id: wallet.id,
                    tournamentId: wallet.tournamentId,
                    userId: wallet.userId,
                    cashBalance: wallet.cashBalance,
                    equityValue: newEquityValue,
                    totalAssets: wallet.cashBalance + newEquityValue,
                    initialBalance: wallet.initialBalance,
                    totalReturn: (wallet.cashBalance + newEquityValue) - wallet.initialBalance,
                    returnPercentage: ((wallet.cashBalance + newEquityValue - wallet.initialBalance) / wallet.initialBalance) * 100,
                    totalTrades: wallet.totalTrades,
                    winningTrades: wallet.winningTrades,
                    maxDrawdown: wallet.maxDrawdown,
                    dailyReturn: wallet.dailyReturn,
                    sharpeRatio: wallet.sharpeRatio,
                    lastUpdated: Date()
                )
                
                wallets[cacheKey] = updatedWallet
            } catch {
                print("❌ [TournamentWalletService] 刷新錢包價值失敗: \(error)")
            }
        }
        
        lastUpdated = Date()
    }
    
    /// 計算風險概況
    private func calculateRiskProfile(wallet: TournamentPortfolioV2) -> RiskProfile {
        let drawdownRisk: RiskLevel
        if wallet.maxDrawdown < 5 {
            drawdownRisk = .low
        } else if wallet.maxDrawdown < 15 {
            drawdownRisk = .medium
        } else {
            drawdownRisk = .high
        }
        
        let allocationRisk: RiskLevel
        if wallet.cashPercentage > 70 {
            allocationRisk = .low
        } else if wallet.cashPercentage > 30 {
            allocationRisk = .medium
        } else {
            allocationRisk = .high
        }
        
        return RiskProfile(
            overall: combineRiskLevels([drawdownRisk, allocationRisk]),
            drawdownRisk: drawdownRisk,
            allocationRisk: allocationRisk
        )
    }
    
    /// 結合多個風險等級
    private func combineRiskLevels(_ risks: [RiskLevel]) -> RiskLevel {
        if risks.contains(.high) {
            return .high
        } else if risks.contains(.medium) {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 生成投資建議
    private func generateRecommendations(wallet: TournamentPortfolioV2) -> [String] {
        var recommendations: [String] = []
        
        if wallet.cashPercentage > 80 {
            recommendations.append("現金比例過高，可考慮適度投資以提升收益潛力")
        }
        
        if wallet.cashPercentage < 10 {
            recommendations.append("現金比例過低，建議保留一定現金以備不時之需")
        }
        
        if wallet.returnPercentage < -10 {
            recommendations.append("投資組合表現低於預期，建議重新評估投資策略")
        }
        
        if wallet.totalTrades == 0 {
            recommendations.append("尚未進行任何交易，可開始建立投資組合")
        }
        
        if wallet.winRate < 0.3 && wallet.totalTrades >= 5 {
            recommendations.append("交易勝率較低，建議檢討選股策略和時機掌握")
        }
        
        return recommendations
    }
    
    // MARK: - Missing Methods Implementation
    
    /// 扣除代幣（例如報名費）
    func deductTokens(
        tournamentId: UUID,
        userId: UUID,
        amount: Double
    ) async -> Result<TournamentPortfolioV2, Error> {
        do {
            let wallet = try await getWallet(tournamentId: tournamentId, userId: userId)
            
            // 檢查餘額是否足夠
            guard wallet.cashBalance >= amount else {
                return .failure(WalletError.insufficientFunds)
            }
            
            let updatedWallet = TournamentPortfolioV2(
                id: wallet.id,
                tournamentId: wallet.tournamentId,
                userId: wallet.userId,
                cashBalance: wallet.cashBalance - amount,
                equityValue: wallet.equityValue,
                totalAssets: wallet.totalAssets - amount,
                initialBalance: wallet.initialBalance,
                totalReturn: wallet.totalReturn - amount,
                returnPercentage: ((wallet.totalAssets - amount - wallet.initialBalance) / wallet.initialBalance) * 100,
                totalTrades: wallet.totalTrades,
                winningTrades: wallet.winningTrades,
                maxDrawdown: wallet.maxDrawdown,
                dailyReturn: wallet.dailyReturn,
                sharpeRatio: wallet.sharpeRatio,
                lastUpdated: Date()
            )
            
            try await supabaseService.updateTournamentPortfolio(updatedWallet)
            
            // 更新快取
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            wallets[cacheKey] = updatedWallet
            
            print("💰 [TournamentWalletService] 代幣已扣除: \(amount)")
            return .success(updatedWallet)
        } catch {
            print("❌ [TournamentWalletService] 扣除代幣失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 初始化投資組合（與 createWallet 相同但簡化版本）
    func initializePortfolio(
        tournamentId: UUID,
        userId: UUID,
        initialBalance: Double
    ) async -> Result<TournamentPortfolioV2, Error> {
        return await createWallet(
            tournamentId: tournamentId,
            userId: userId,
            initialBalance: initialBalance
        )
    }
    
    /// 添加資金到錢包
    func addFunds(
        tournamentId: UUID,
        userId: UUID,
        amount: Double
    ) async -> Result<TournamentPortfolioV2, Error> {
        do {
            let wallet = try await getWallet(tournamentId: tournamentId, userId: userId)
            
            let updatedWallet = TournamentPortfolioV2(
                id: wallet.id,
                tournamentId: wallet.tournamentId,
                userId: wallet.userId,
                cashBalance: wallet.cashBalance + amount,
                equityValue: wallet.equityValue,
                totalAssets: wallet.totalAssets + amount,
                initialBalance: wallet.initialBalance,
                totalReturn: wallet.totalReturn + amount,
                returnPercentage: ((wallet.totalAssets + amount - wallet.initialBalance) / wallet.initialBalance) * 100,
                totalTrades: wallet.totalTrades,
                winningTrades: wallet.winningTrades,
                maxDrawdown: wallet.maxDrawdown,
                dailyReturn: wallet.dailyReturn,
                sharpeRatio: wallet.sharpeRatio,
                lastUpdated: Date()
            )
            
            try await supabaseService.updateTournamentPortfolio(updatedWallet)
            
            // 更新快取
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            wallets[cacheKey] = updatedWallet
            
            print("💰 [TournamentWalletService] 資金已添加: \(amount)")
            return .success(updatedWallet)
        } catch {
            print("❌ [TournamentWalletService] 添加資金失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 檢查錢包是否存在
    func walletExists(tournamentId: UUID, userId: UUID) async -> Bool {
        do {
            _ = try await getWallet(tournamentId: tournamentId, userId: userId)
            return true
        } catch {
            return false
        }
    }
    
    /// 刪除錢包
    func deleteWallet(tournamentId: UUID, userId: UUID) async -> Result<Void, Error> {
        do {
            try await supabaseService.deleteTournamentPortfolio(
                tournamentId: tournamentId,
                userId: userId
            )
            
            // 從快取中移除
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            wallets.removeValue(forKey: cacheKey)
            
            print("🗑️ [TournamentWalletService] 錢包已刪除")
            return .success(())
        } catch {
            print("❌ [TournamentWalletService] 刪除錢包失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取錢包餘額（簡化版本）
    func getBalance(tournamentId: UUID, userId: UUID) async throws -> Double {
        let wallet = try await getWallet(tournamentId: tournamentId, userId: userId)
        return wallet.cashBalance
    }
    
    /// 獲取總資產（簡化版本）
    func getTotalAssets(tournamentId: UUID, userId: UUID) async throws -> Double {
        let wallet = try await getWallet(tournamentId: tournamentId, userId: userId)
        return wallet.totalAssets
    }
    
    /// 交易後更新投資組合
    func updatePortfolioAfterTrade(_ trade: TournamentTrade) async throws {
        let cacheKey = generateCacheKey(tournamentId: trade.tournamentId, userId: trade.userId)
        
        guard let currentWallet = wallets[cacheKey] else {
            // 如果緩存中沒有，先獲取錢包
            _ = try await getWallet(tournamentId: trade.tournamentId, userId: trade.userId)
            return
        }
        
        let totalAmount = trade.amount + trade.fees
        var newCashBalance = currentWallet.cashBalance
        var newEquityValue = currentWallet.equityValue
        
        switch trade.side {
        case .buy:
            newCashBalance -= totalAmount
            newEquityValue += trade.amount
        case .sell:
            newCashBalance += trade.netAmount
            newEquityValue -= trade.amount
        }
        
        let newTotalAssets = newCashBalance + newEquityValue
        let newTotalReturn = newTotalAssets - currentWallet.initialBalance
        let newReturnPercentage = (newTotalReturn / currentWallet.initialBalance) * 100
        
        let updatedWallet = TournamentPortfolioV2(
            id: currentWallet.id,
            tournamentId: currentWallet.tournamentId,
            userId: currentWallet.userId,
            cashBalance: newCashBalance,
            equityValue: newEquityValue,
            totalAssets: newTotalAssets,
            initialBalance: currentWallet.initialBalance,
            totalReturn: newTotalReturn,
            returnPercentage: newReturnPercentage,
            totalTrades: currentWallet.totalTrades + 1,
            winningTrades: currentWallet.winningTrades,
            maxDrawdown: currentWallet.maxDrawdown,
            dailyReturn: currentWallet.dailyReturn,
            sharpeRatio: currentWallet.sharpeRatio,
            lastUpdated: Date()
        )
        
        try await supabaseService.updateTournamentPortfolio(updatedWallet)
        wallets[cacheKey] = updatedWallet
        
        print("✅ [TournamentWalletService] 交易後投資組合已更新")
    }
    
    /// 更新持倉
    func updateHoldings(_ trade: TournamentTrade) async throws {
        // 持倉更新邏輯 - 簡化實現
        print("📈 [TournamentWalletService] 更新持倉: \(trade.symbol) \(trade.side.rawValue) \(trade.qty)")
        // 實際實現應該更新具體的股票持倉記錄
    }
    
    /// 添加代幣到用戶帳戶（獎勵分發）
    func addTokens(userId: UUID, amount: Int) async {
        print("🎁 [TournamentWalletService] 為用戶 \(userId) 添加 \(amount) 代幣")
        // 實際實現應該更新用戶的代幣餘額
        // 這裡可以調用用戶服務或代幣服務來處理
    }
}

// MARK: - Error Types

enum WalletError: LocalizedError {
    case insufficientFunds
    case walletNotFound
    case invalidAmount
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "餘額不足"
        case .walletNotFound:
            return "找不到錢包"
        case .invalidAmount:
            return "無效的金額"
        }
    }
}

// MARK: - 支援結構

/// 錢包歷史記錄條目
struct WalletHistoryEntry: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let cash: Double
    let equityValue: Double
    let totalAssets: Double
    let returnPercentage: Double
    let dailyChange: Double?
}

/// 資產配置（簡化版）
struct WalletAssetAllocation {
    let cashPercentage: Double
    let equityPercentage: Double
}

/// 錢包績效指標（簡化版）
struct WalletPerformanceMetrics {
    let totalReturn: Double
    let returnPercentage: Double
    let winRate: Double
}

/// 風險概況
struct RiskProfile {
    let overall: RiskLevel
    let drawdownRisk: RiskLevel
    let allocationRisk: RiskLevel
}

/// 錢包分析
struct WalletAnalysis {
    let assetAllocation: WalletAssetAllocation
    let performance: WalletPerformanceMetrics
    let riskProfile: RiskProfile
    let recommendations: [String]
}

/// 交易能力檢查結果
struct TradingCapabilityCheck {
    let canTrade: Bool
    let maxAmount: Double
    let reason: String?
}
