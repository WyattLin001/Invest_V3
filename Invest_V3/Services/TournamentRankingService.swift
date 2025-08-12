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
    static let shared = TournamentRankingService()
    
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
    
    private init() {
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
                        cash: wallet.cashBalance,
                        positionValue: wallet.equityValue,
                        totalAssets: wallet.totalAssets,
                        returnRate: wallet.returnPercentage / 100, // 轉換為小數
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
        
        for participant in participants where participant.status == .active {
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
    private func calculateDistributionStats(_ returns: [Double]) -> DistributionStats {
        let positive = returns.filter { $0 > 0 }.count
        let negative = returns.filter { $0 < 0 }.count
        let neutral = returns.filter { $0 == 0 }.count
        
        return DistributionStats(
            positiveReturns: positive,
            negativeReturns: negative,
            neutralReturns: neutral,
            winnerPercentage: Double(positive) / Double(returns.count) * 100
        )
    }
}

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
struct TournamentStats {
    let totalParticipants: Int
    let averageReturn: Double
    let medianReturn: Double
    let standardDeviation: Double
    let topPerformers: [TournamentLeaderboardEntry]
    let worstPerformers: [TournamentLeaderboardEntry]
    let distributionStats: DistributionStats
    let lastUpdated: Date
}

/// 分佈統計
struct DistributionStats {
    let positiveReturns: Int
    let negativeReturns: Int
    let neutralReturns: Int
    let winnerPercentage: Double
}

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