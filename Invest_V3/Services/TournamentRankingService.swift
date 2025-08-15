//
//  TournamentRankingService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽排名服務 - 專門處理排名計算、快照生成和排行榜更新
//

import Foundation
import Combine

// MARK: - 錦標賽排名服務
@MainActor
class TournamentRankingService: ObservableObject {
    static let shared = TournamentRankingService(shared: ())
    
    // MARK: - Published Properties
    @Published var leaderboards: [UUID: [TournamentLeaderboardEntry]] = [:]
    @Published var isCalculating = false
    @Published var lastCalculated: [UUID: Date] = [:]
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let walletService = TournamentWalletService.shared
    private let tournamentService = TournamentService.shared
    private var calculationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 公開初始化器（用於測試和依賴注入）
    init() {
        // 用於測試的公開初始化器
    }
    
    private init(shared: Void) {
        setupRankingTimer()
    }
    
    deinit {
        calculationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// 獲取錦標賽排行榜
    func getLeaderboard(
        tournamentId: UUID,
        forceRefresh: Bool = false
    ) async -> Result<[TournamentLeaderboardEntry], Error> {
        
        // 檢查快取
        if !forceRefresh,
           let cachedLeaderboard = leaderboards[tournamentId],
           let lastCalculated = lastCalculated[tournamentId],
           Date().timeIntervalSince(lastCalculated) < 300 { // 5分鐘內快取有效
            return .success(cachedLeaderboard)
        }
        
        isCalculating = true
        defer { isCalculating = false }
        
        do {
            let leaderboard = try await calculateLeaderboard(tournamentId: tournamentId)
            
            // 更新快取
            leaderboards[tournamentId] = leaderboard
            lastCalculated[tournamentId] = Date()
            
            print("✅ [TournamentRankingService] 排行榜已更新: \(leaderboard.count) 位參賽者")
            return .success(leaderboard)
        } catch {
            print("❌ [TournamentRankingService] 計算排行榜失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 計算用戶排名
    func getUserRank(
        tournamentId: UUID,
        userId: UUID
    ) async -> Result<UserRankInfo, Error> {
        let leaderboardResult = await getLeaderboard(tournamentId: tournamentId)
        
        switch leaderboardResult {
        case .success(let leaderboard):
            guard let userEntry = leaderboard.first(where: { $0.userId == userId }) else {
                return .failure(RankingError.userNotFound)
            }
            
            let rankInfo = UserRankInfo(
                currentRank: userEntry.currentRank,
                totalParticipants: userEntry.totalParticipants,
                percentile: Double(userEntry.currentRank) / Double(userEntry.totalParticipants) * 100,
                returnPercentage: userEntry.returnPercentage,
                totalAssets: userEntry.totalAssets,
                rankingTier: userEntry.rankingTier
            )
            
            return .success(rankInfo)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// 生成每日快照
    func generateDailySnapshot(tournamentId: UUID) async -> Result<Int, Error> {
        do {
            print("📸 [TournamentRankingService] 開始生成每日快照: \(tournamentId)")
            
            // 獲取當前排行榜
            let leaderboard = try await calculateLeaderboard(tournamentId: tournamentId)
            
            // 為每位參賽者創建快照
            var snapshotCount = 0
            let today = Calendar.current.startOfDay(for: Date())
            
            for entry in leaderboard {
                do {
                    // 獲取詳細的錢包和持倉資訊
                    let wallet = try await walletService.getWallet(
                        tournamentId: tournamentId,
                        userId: entry.userId
                    )
                    
                    let snapshot = TournamentSnapshot(
                        tournamentId: tournamentId,
                        userId: entry.userId,
                        asOfDate: today,
                        snapshotDate: Date(), // 快照生成時間
                        cash: wallet.cashBalance,
                        positionValue: wallet.equityValue,
                        totalAssets: wallet.totalAssets,
                        portfolioValue: wallet.totalAssets, // 投資組合總價值
                        returnRate: wallet.returnPercentage / 100, // 轉換為小數
                        returnPercentage: wallet.returnPercentage, // 原始百分比
                        dailyReturn: nil, // 需要計算日變化
                        cumulativeReturn: wallet.totalReturn,
                        maxDD: wallet.maxDrawdown / 100,
                        volatility: nil, // 需要歷史數據計算
                        sharpe: nil, // 需要歷史數據計算
                        totalTrades: wallet.totalTrades,
                        winningTrades: wallet.winningTrades,
                        winRate: wallet.winRate,
                        rank: entry.currentRank,
                        totalParticipants: entry.totalParticipants,
                        percentile: Double(entry.currentRank) / Double(entry.totalParticipants) * 100,
                        createdAt: Date()
                    )
                    
                    try await supabaseService.upsertTournamentSnapshot(snapshot)
                    snapshotCount += 1
                    
                } catch {
                    print("❌ [TournamentRankingService] 為用戶 \(entry.userId) 生成快照失敗: \(error)")
                }
            }
            
            print("✅ [TournamentRankingService] 快照生成完成: \(snapshotCount) 個")
            return .success(snapshotCount)
            
        } catch {
            print("❌ [TournamentRankingService] 生成快照失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 計算進階排名統計
    func calculateAdvancedStats(
        tournamentId: UUID
    ) async -> Result<TournamentStats, Error> {
        do {
            let leaderboard = try await calculateLeaderboard(tournamentId: tournamentId)
            
            let returns = leaderboard.map { $0.returnPercentage }
            let totalAssets = leaderboard.map { $0.totalAssets }
            
            let avgReturn = returns.reduce(0, +) / Double(returns.count)
            let medianReturn = calculateMedian(returns)
            let stdDev = calculateStandardDeviation(returns)
            
            let topPerformers = leaderboard.prefix(3)
            let worstPerformers = Array(leaderboard.suffix(3).reversed())
            
            let stats = TournamentStats(
                totalParticipants: leaderboard.count,
                averageReturn: avgReturn,
                medianReturn: medianReturn,
                standardDeviation: stdDev,
                topPerformers: Array(topPerformers),
                worstPerformers: worstPerformers,
                distributionStats: calculateDistributionStats(returns),
                lastUpdated: Date()
            )
            
            return .success(stats)
        } catch {
            return .failure(error)
        }
    }
    
    /// 強制重新計算所有活躍錦標賽的排名
    func recalculateAllActiveRankings() async {
        print("🔄 [TournamentRankingService] 開始重新計算所有活躍錦標賽排名...")
        
        do {
            let activeTournaments = try await tournamentService.getActiveTournaments()
            
            for tournament in activeTournaments {
                await _ = getLeaderboard(tournamentId: tournament.id, forceRefresh: true)
                
                // 如果是新的一天，生成快照
                if shouldGenerateSnapshot(for: tournament.id) {
                    await _ = generateDailySnapshot(tournamentId: tournament.id)
                }
            }
            
            print("✅ [TournamentRankingService] 所有排名重新計算完成")
        } catch {
            print("❌ [TournamentRankingService] 重新計算排名失敗: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// 計算排行榜
    private func calculateLeaderboard(tournamentId: UUID) async throws -> [TournamentLeaderboardEntry] {
        // 獲取所有參賽者的錢包資訊
        let participants = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
        var entries: [TournamentLeaderboardEntry] = []
        
        for participant in participants where participant.status == TournamentMember.MemberStatus.active {
            do {
                let wallet = try await walletService.getWallet(
                    tournamentId: tournamentId,
                    userId: participant.userId
                )
                
                let entry = TournamentLeaderboardEntry(
                    tournamentId: tournamentId,
                    userId: participant.userId,
                    userName: nil, // 需要從用戶服務獲取
                    userAvatar: nil,
                    totalAssets: wallet.totalAssets,
                    returnPercentage: wallet.returnPercentage,
                    totalTrades: wallet.totalTrades,
                    lastUpdated: wallet.lastUpdated,
                    currentRank: 0, // 稍後計算
                    totalParticipants: participants.count
                )
                
                entries.append(entry)
            } catch {
                print("❌ [TournamentRankingService] 獲取參賽者 \(participant.userId) 資料失敗: \(error)")
            }
        }
        
        // 按報酬率排序並分配排名
        entries.sort { $0.returnPercentage > $1.returnPercentage }
        
        var rankedEntries: [TournamentLeaderboardEntry] = []
        for (index, entry) in entries.enumerated() {
            let rankedEntry = TournamentLeaderboardEntry(
                tournamentId: entry.tournamentId,
                userId: entry.userId,
                userName: entry.userName,
                userAvatar: entry.userAvatar,
                totalAssets: entry.totalAssets,
                returnPercentage: entry.returnPercentage,
                totalTrades: entry.totalTrades,
                lastUpdated: entry.lastUpdated,
                currentRank: index + 1,
                totalParticipants: entries.count
            )
            rankedEntries.append(rankedEntry)
        }
        
        return rankedEntries
    }
    
    /// 設置排名計算定時器
    private func setupRankingTimer() {
        // 每10分鐘重新計算一次排名
        calculationTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.recalculateAllActiveRankings()
            }
        }
        
        print("⏰ [TournamentRankingService] 排名計算定時器已啟動")
    }
    
    /// 檢查是否需要生成快照
    private func shouldGenerateSnapshot(for tournamentId: UUID) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 檢查今天是否已經生成過快照
        // 這裡可以查詢數據庫確認，暫時簡化為時間檢查
        let hour = calendar.component(.hour, from: now)
        return hour >= 15 && hour < 16 // 下午3點到4點之間生成快照
    }
    
    /// 計算中位數
    private func calculateMedian(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count/2 - 1] + sorted[count/2]) / 2
        } else {
            return sorted[count/2]
        }
    }
    
    /// 計算標準差
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    /// 計算分佈統計
    private func calculateDistributionStats(_ returns: [Double]) -> DistributionStatsModel {
        let positive = returns.filter { $0 > 0 }.count
        let negative = returns.filter { $0 < 0 }.count
        let neutral = returns.filter { $0 == 0 }.count
        
        return DistributionStatsModel(
            positiveReturns: positive,
            negativeReturns: negative,
            neutralReturns: neutral,
            winnerPercentage: Double(positive) / Double(returns.count) * 100
        )
    }
    
    // MARK: - Missing Methods Implementation
    
    /// 保存排名到數據庫
    func saveRankings(_ rankings: [TournamentRanking]) async throws {
        // TournamentRanking 沒有 tournamentId，需要從呼叫方提供
        // 這個方法的簽名需要改成包含 tournamentId
        print("⚠️ [TournamentRankingService] saveRankings 方法需要 tournamentId 參數")
        // 暫時不做任何處理，等修復呼叫方
    }
    
    /// 保存排名到數據庫（完整版本）
    func saveRankings(tournamentId: UUID, rankings: [TournamentLeaderboardEntry]) async -> Result<Void, Error> {
        do {
            // 批量保存排名到數據庫
            try await supabaseService.saveTournamentRankings(tournamentId: tournamentId, rankings: rankings)
            
            // 更新本地快取
            leaderboards[tournamentId] = rankings
            lastCalculated[tournamentId] = Date()
            
            print("✅ [TournamentRankingService] 排名已保存: \(rankings.count) 位參賽者")
            return .success(())
        } catch {
            print("❌ [TournamentRankingService] 保存排名失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 計算績效指標
    func calculatePerformanceMetrics(
        tournamentId: UUID,
        userId: UUID
    ) async -> Result<PerformanceMetrics, Error> {
        do {
            // 獲取用戶的錢包資訊
            let wallet = try await walletService.getWallet(tournamentId: tournamentId, userId: userId)
            
            // 獲取交易歷史來計算更詳細的指標
            let trades = try await supabaseService.fetchTournamentTrades(
                tournamentId: tournamentId,
                userId: userId,
                limit: 1000,
                offset: 0
            )
            
            // 計算績效指標
            let metrics = PerformanceMetrics(
                totalReturn: wallet.totalReturn,
                annualizedReturn: await calculateAnnualizedReturn(wallet: wallet, tournamentId: tournamentId),
                maxDrawdown: wallet.maxDrawdown,
                sharpeRatio: wallet.sharpeRatio,
                winRate: wallet.winRate,
                avgHoldingDays: calculateAverageHoldingDays(trades: trades),
                diversificationScore: calculateDiversificationScore(trades: trades),
                riskScore: calculateRiskScore(wallet: wallet, trades: trades),
                totalTrades: wallet.totalTrades,
                profitableTrades: wallet.winningTrades,
                currentRank: 0, // 會在排名計算後更新
                maxDrawdownPercentage: wallet.maxDrawdown,
                // 新增的缺失參數
                totalReturnPercentage: wallet.returnPercentage,
                dailyReturn: wallet.dailyReturn ?? 0.0,
                averageHoldingDays: calculateAverageHoldingDays(trades: trades),
                previousRank: 0, // 暫時為0
                percentile: 50.0, // 暫時為中位數
                lastUpdated: Date(),
                rankChange: 0 // 暫時為0，表示排名無變化
            )
            
            return .success(metrics)
        } catch {
            print("❌ [TournamentRankingService] 計算績效指標失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 更新排名快照
    func updateRankingSnapshot(tournamentId: UUID, userId: UUID, rank: Int) async -> Result<Void, Error> {
        do {
            try await supabaseService.updateTournamentRankSnapshot(
                tournamentId: tournamentId,
                userId: userId,
                rank: rank,
                snapshotDate: Date()
            )
            
            print("✅ [TournamentRankingService] 排名快照已更新: 第\(rank)名")
            return .success(())
        } catch {
            print("❌ [TournamentRankingService] 更新排名快照失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取排名歷史
    func getRankingHistory(
        tournamentId: UUID,
        userId: UUID,
        days: Int = 30
    ) async -> Result<[RankingHistoryEntry], Error> {
        do {
            let snapshots = try await supabaseService.fetchRankingHistory(
                tournamentId: tournamentId,
                userId: userId,
                days: days
            )
            
            let history = snapshots.map { snapshot in
                RankingHistoryEntry(
                    date: snapshot.snapshotDate,
                    rank: snapshot.rank ?? 0,
                    totalParticipants: snapshot.totalParticipants ?? 0,
                    returnPercentage: snapshot.returnPercentage,
                    portfolioValue: snapshot.portfolioValue
                )
            }.sorted { $0.date > $1.date }
            
            return .success(history)
        } catch {
            print("❌ [TournamentRankingService] 獲取排名歷史失敗: \(error)")
            return .failure(error)
        }
    }
    
    /// 獲取即時排名變化
    func getRealtimeRankingChanges(tournamentId: UUID) async -> Result<[RankingChange], Error> {
        do {
            let changes = try await supabaseService.fetchRealtimeRankingChanges(tournamentId: tournamentId)
            return .success(changes)
        } catch {
            print("❌ [TournamentRankingService] 獲取即時排名變化失敗: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Private Helper Methods for Performance Calculations
    
    private func calculateAnnualizedReturn(wallet: TournamentPortfolioV2, tournamentId: UUID) async -> Double {
        do {
            guard let tournament = try await TournamentService.shared.fetchTournament(id: tournamentId) else {
                return 0
            }
            let daysSinceStart = Date().timeIntervalSince(tournament.startDate) / (24 * 3600)
            
            guard daysSinceStart > 0 else { return 0 }
            
            let periodsPerYear = 365.25 / daysSinceStart
            let totalReturnRate = wallet.returnPercentage / 100
            
            return pow(1 + totalReturnRate, periodsPerYear) - 1
        } catch {
            return 0
        }
    }
    
    private func calculateVolatility(trades: [TournamentTrade]) -> Double {
        let returns = trades.compactMap { $0.realizedPnlPercentage }
        
        guard returns.count > 1 else { return 0 }
        
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { $0 + pow($1 - mean, 2) } / Double(returns.count - 1)
        
        return sqrt(variance)
    }
    
    private func calculateProfitFactor(trades: [TournamentTrade]) -> Double {
        let profits = trades.compactMap { $0.realizedPnl }.filter { $0 > 0 }
        let losses = trades.compactMap { $0.realizedPnl }.filter { $0 < 0 }
        
        let totalProfits = profits.reduce(0, +)
        let totalLosses = abs(losses.reduce(0, +))
        
        return totalLosses == 0 ? (totalProfits > 0 ? Double.infinity : 0) : totalProfits / totalLosses
    }
    
    private func calculateAverageReturn(trades: [TournamentTrade]) -> Double {
        let returns = trades.compactMap { $0.realizedPnl }
        return returns.isEmpty ? 0 : returns.reduce(0, +) / Double(returns.count)
    }
    
    private func findBestTrade(trades: [TournamentTrade]) -> TournamentTrade? {
        return trades.max { 
            ($0.realizedPnl ?? -Double.infinity) < ($1.realizedPnl ?? -Double.infinity)
        }
    }
    
    private func findWorstTrade(trades: [TournamentTrade]) -> TournamentTrade? {
        return trades.min { 
            ($0.realizedPnl ?? Double.infinity) < ($1.realizedPnl ?? Double.infinity)
        }
    }
    
    private func calculateConsecutiveWins(trades: [TournamentTrade]) -> Int {
        let sortedTrades = trades.sorted { $0.executedAt < $1.executedAt }
        var maxWins = 0
        var currentWins = 0
        
        for trade in sortedTrades {
            if let pnl = trade.realizedPnl, pnl > 0 {
                currentWins += 1
                maxWins = max(maxWins, currentWins)
            } else {
                currentWins = 0
            }
        }
        
        return maxWins
    }
    
    private func calculateConsecutiveLosses(trades: [TournamentTrade]) -> Int {
        let sortedTrades = trades.sorted { $0.executedAt < $1.executedAt }
        var maxLosses = 0
        var currentLosses = 0
        
        for trade in sortedTrades {
            if let pnl = trade.realizedPnl, pnl < 0 {
                currentLosses += 1
                maxLosses = max(maxLosses, currentLosses)
            } else {
                currentLosses = 0
            }
        }
        
        return maxLosses
    }
    
    // MARK: - Additional Performance Metrics Calculations
    
    private func calculateAverageHoldingDays(trades: [TournamentTrade]) -> Double {
        let completedTrades = trades.filter { $0.realizedPnl != nil }
        guard !completedTrades.isEmpty else { return 0 }
        
        let totalDays = completedTrades.reduce(0.0) { sum, trade in
            let holdingDays = Calendar.current.dateComponents([.day], from: trade.executedAt, to: Date()).day ?? 0
            return sum + Double(holdingDays)
        }
        
        return totalDays / Double(completedTrades.count)
    }
    
    private func calculateDiversificationScore(trades: [TournamentTrade]) -> Double {
        let symbols = Set(trades.map { $0.symbol })
        let totalSymbols = symbols.count
        
        // 簡單的多樣化評分：基於不同股票數量
        switch totalSymbols {
        case 0...1: return 1.0
        case 2...3: return 3.0
        case 4...6: return 5.0
        case 7...10: return 7.0
        default: return 10.0
        }
    }
    
    private func calculateRiskScore(wallet: TournamentPortfolioV2, trades: [TournamentTrade]) -> Double {
        // 基於最大回撤和交易頻率計算風險評分
        let drawdownScore = min(wallet.maxDrawdown * 10, 5.0) // 0-5分
        
        let tradingFrequency = Double(trades.count) / max(1.0, Date().timeIntervalSince(wallet.lastUpdated) / (24 * 3600 * 7)) // 每週交易次數
        let frequencyScore = min(tradingFrequency, 5.0) // 0-5分
        
        return drawdownScore + frequencyScore // 0-10分
    }
}

// MARK: - Additional Supporting Structures

/// 績效指標詳細資訊
// PerformanceMetrics is defined in TournamentModels.swift

/// 排名歷史記錄
struct RankingHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let rank: Int
    let totalParticipants: Int
    let returnPercentage: Double
    let portfolioValue: Double
}

/// 排名變化記錄
// RankingChange is defined in TournamentRankingSystem.swift

// MARK: - 支援結構

/// 用戶排名資訊
struct UserRankInfo {
    let currentRank: Int
    let totalParticipants: Int
    let percentile: Double
    let returnPercentage: Double
    let totalAssets: Double
    let rankingTier: TournamentLeaderboardEntry.RankingTier
}

/// 錦標賽統計
// TournamentStats 和 DistributionStats 已移至 TournamentModels.swift 統一管理
// 此處使用 typealias 保持兼容性
typealias TournamentStats = TournamentStatsModel
typealias DistributionStats = DistributionStatsModel

/// 排名錯誤類型
enum RankingError: LocalizedError {
    case userNotFound
    case calculationFailed
    case noParticipants
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "找不到用戶排名資訊"
        case .calculationFailed:
            return "排名計算失敗"
        case .noParticipants:
            return "錦標賽暫無參賽者"
        }
    }
}