//
//  TournamentPositionService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽持倉服務 - 專門管理錦標賽內的持倉狀況，實時計算市值和損益
//

import Foundation
import Combine

// MARK: - 錦標賽持倉服務
@MainActor
class TournamentPositionService: ObservableObject {
    static let shared = TournamentPositionService()
    
    // MARK: - Published Properties
    @Published var userPositions: [UUID: [TournamentPosition]] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let stockService = StockService.shared
    private var cancellables = Set<AnyCancellable>()
    private var priceUpdateTimer: Timer?
    
    private init() {
        setupPriceUpdateTimer()
    }
    
    deinit {
        priceUpdateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// 獲取用戶在特定錦標賽的持倉
    func getUserPositions(
        tournamentId: UUID,
        userId: UUID
    ) async -> Result<[TournamentPosition], Error> {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let positions = try await supabaseService.fetchTournamentPositions(
                tournamentId: tournamentId,
                userId: userId
            )
            
            // 更新價格
            let updatedPositions = try await updatePositionPrices(positions)
            
            // 更新本地快取
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            userPositions[cacheKey] = updatedPositions
            lastUpdated = Date()
            
            return .success(updatedPositions)
        } catch {
            print("❌ [TournamentPositionService] 獲取持倉失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取錦標賽的所有持倉（管理員功能）
    func getTournamentPositions(tournamentId: UUID) async -> Result<[TournamentPosition], Error> {
        do {
            let positions = try await supabaseService.fetchAllTournamentPositions(tournamentId: tournamentId)
            return .success(positions)
        } catch {
            print("❌ [TournamentPositionService] 獲取錦標賽持倉失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取特定股票的持倉
    func getPositionBySymbol(
        tournamentId: UUID,
        userId: UUID,
        symbol: String
    ) async -> Result<TournamentPosition?, Error> {
        let result = await getUserPositions(tournamentId: tournamentId, userId: userId)
        
        switch result {
        case .success(let positions):
            let position = positions.first { $0.symbol == symbol }
            return .success(position)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// 更新持倉（由交易服務調用）
    func updatePosition(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        side: TradeSide,
        qty: Double,
        price: Double
    ) async -> Result<TournamentPosition, Error> {
        do {
            let updatedPosition = try await supabaseService.updateTournamentPosition(
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: side.rawValue,
                qty: qty,
                price: price
            )
            
            // 更新本地快取
            let cacheKey = generateCacheKey(tournamentId: tournamentId, userId: userId)
            if var positions = userPositions[cacheKey] {
                if let index = positions.firstIndex(where: { $0.symbol == symbol }) {
                    positions[index] = updatedPosition
                } else {
                    positions.append(updatedPosition)
                }
                userPositions[cacheKey] = positions.filter { $0.qty > 0 } // 移除已清倉的持倉
            }
            
            return .success(updatedPosition)
        } catch {
            print("❌ [TournamentPositionService] 更新持倉失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 強制更新所有持倉價格
    func refreshAllPositionPrices() async {
        guard !userPositions.isEmpty else { return }
        
        print("🔄 [TournamentPositionService] 開始更新持倉價格...")
        
        for (cacheKey, positions) in userPositions {
            do {
                let updatedPositions = try await updatePositionPrices(positions)
                userPositions[cacheKey] = updatedPositions
            } catch {
                print("❌ [TournamentPositionService] 更新持倉價格失敗: \(error)")
            }
        }
        
        lastUpdated = Date()
        print("✅ [TournamentPositionService] 持倉價格更新完成")
    }
    
    /// 計算投資組合統計資訊
    func calculatePortfolioStatistics(positions: [TournamentPosition]) -> PortfolioStatistics {
        let totalMarketValue = positions.reduce(0) { $0 + $1.marketValue }
        let totalCost = positions.reduce(0) { $0 + $1.totalCost }
        let totalPnl = positions.reduce(0) { $0 + $1.unrealizedPnl }
        
        let diversification = calculateDiversification(positions: positions)
        let riskLevel = calculateRiskLevel(positions: positions)
        
        return PortfolioStatistics(
            totalPositions: positions.count,
            totalMarketValue: totalMarketValue,
            totalCost: totalCost,
            totalUnrealizedPnl: totalPnl,
            totalReturnPercentage: totalCost > 0 ? (totalPnl / totalCost) * 100 : 0,
            diversificationScore: diversification,
            riskLevel: riskLevel,
            topHoldings: Array(positions.sorted { $0.marketValue > $1.marketValue }.prefix(5))
        )
    }
    
    // MARK: - Private Methods
    
    /// 生成快取鍵值
    private func generateCacheKey(tournamentId: UUID, userId: UUID) -> UUID {
        let combined = "\(tournamentId)-\(userId)"
        return UUID(uuidString: combined.md5) ?? UUID()
    }
    
    /// 更新持倉價格
    private func updatePositionPrices(_ positions: [TournamentPosition]) async throws -> [TournamentPosition] {
        guard !positions.isEmpty else { return positions }
        
        // 獲取所有股票的最新價格
        let symbols = positions.map { $0.symbol }
        let prices = try await stockService.batchGetStockPrices(symbols: symbols)
        
        // 更新每個持倉的價格
        var updatedPositions: [TournamentPosition] = []
        
        for position in positions {
            if let newPrice = prices[position.symbol] {
                let updatedPosition = TournamentPosition(
                    tournamentId: position.tournamentId,
                    userId: position.userId,
                    symbol: position.symbol,
                    qty: position.qty,
                    avgCost: position.avgCost,
                    totalCost: position.totalCost,
                    currentPrice: newPrice,
                    marketValue: position.qty * newPrice,
                    unrealizedPnl: (position.qty * newPrice) - position.totalCost,
                    unrealizedPnlPercentage: position.avgCost > 0 ? ((newPrice - position.avgCost) / position.avgCost) * 100 : 0,
                    firstBuyAt: position.firstBuyAt,
                    lastUpdated: Date()
                )
                updatedPositions.append(updatedPosition)
                
                // 更新數據庫中的價格
                try await supabaseService.updatePositionPrice(
                    tournamentId: position.tournamentId,
                    userId: position.userId,
                    symbol: position.symbol,
                    currentPrice: newPrice
                )
            } else {
                // 如果無法獲取最新價格，保持原有持倉
                updatedPositions.append(position)
            }
        }
        
        return updatedPositions
    }
    
    /// 設置價格更新定時器
    private func setupPriceUpdateTimer() {
        // 每5分鐘更新一次價格（市場開盤時間）
        priceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllPositionPrices()
            }
        }
        
        print("⏰ [TournamentPositionService] 價格更新定時器已啟動")
    }
    
    /// 計算多元化分數
    private func calculateDiversification(positions: [TournamentPosition]) -> Double {
        guard !positions.isEmpty else { return 0 }
        
        let totalValue = positions.reduce(0) { $0 + $1.marketValue }
        guard totalValue > 0 else { return 0 }
        
        // 計算赫芬達爾指數 (Herfindahl Index)
        let herfindahlIndex = positions.reduce(0) { result, position in
            let weight = position.marketValue / totalValue
            return result + (weight * weight)
        }
        
        // 轉換為多元化分數（0-100），分數越高表示越多元化
        let maxPossibleIndex = 1.0 / Double(positions.count) // 完全平均分配時的指數
        let diversificationScore = ((1.0 - herfindahlIndex) / (1.0 - maxPossibleIndex)) * 100
        
        return max(0, min(100, diversificationScore))
    }
    
    /// 計算風險等級
    private func calculateRiskLevel(positions: [TournamentPosition]) -> RiskLevel {
        guard !positions.isEmpty else { return .conservative }
        
        let totalValue = positions.reduce(0) { $0 + $1.marketValue }
        guard totalValue > 0 else { return .conservative }
        
        // 檢查單一股票集中度
        let maxSinglePosition = positions.max { $0.marketValue < $1.marketValue }?.marketValue ?? 0
        let concentration = maxSinglePosition / totalValue
        
        // 檢查整體波動性（基於未實現損益的標準差）
        let pnlPercentages = positions.map { $0.unrealizedPnlPercentage }
        let volatility = calculateStandardDeviation(pnlPercentages)
        
        if concentration > 0.5 || volatility > 20 {
            return .aggressive
        } else if concentration > 0.3 || volatility > 10 {
            return .moderate
        } else {
            return .conservative
        }
    }
    
    /// 計算標準差
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        
        return sqrt(variance)
    }
}

// MARK: - 支援結構

/// 投資組合統計資訊
struct PortfolioStatistics {
    let totalPositions: Int
    let totalMarketValue: Double
    let totalCost: Double
    let totalUnrealizedPnl: Double
    let totalReturnPercentage: Double
    let diversificationScore: Double
    let riskLevel: RiskLevel
    let topHoldings: [TournamentPosition]
}

// RiskLevel 枚舉已移至 FriendsModels.swift 以避免重複定義
// 這裡使用 FriendsModels 中的 RiskLevel

// MARK: - String MD5 Extension
extension String {
    var md5: String {
        guard let data = self.data(using: .utf8) else { return self }
        return data.md5
    }
}

extension Data {
    var md5: String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}