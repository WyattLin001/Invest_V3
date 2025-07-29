//
//  TournamentRankingSystem.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  錦標賽排名計算系統 - 負責計算和更新每個錦標賽的參賽者排名
//

import Foundation
import SwiftUI

/// 排名計算權重配置
struct RankingWeights {
    let totalReturn: Double = 0.4        // 總收益率權重 40%
    let riskAdjustedReturn: Double = 0.3 // 風險調整後收益權重 30%
    let consistency: Double = 0.2        // 穩定性權重 20%
    let activity: Double = 0.1           // 活躍度權重 10%
    
    var total: Double {
        return totalReturn + riskAdjustedReturn + consistency + activity
    }
}

/// 排名變動記錄
struct RankingChange: Identifiable, Codable {
    let id = UUID()
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let previousRank: Int
    let currentRank: Int
    let change: Int
    let changeType: RankingChangeType
    let timestamp: Date
    let reason: String
    
    enum RankingChangeType: String, CaseIterable, Codable {
        case improvement = "improvement"
        case decline = "decline"
        case stable = "stable"
        case newEntry = "new_entry"
        
        var icon: String {
            switch self {
            case .improvement:
                return "arrow.up.circle.fill"
            case .decline:
                return "arrow.down.circle.fill"
            case .stable:
                return "minus.circle.fill"
            case .newEntry:
                return "plus.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .improvement:
                return .success
            case .decline:
                return .danger
            case .stable:
                return .gray600
            case .newEntry:
                return .brandBlue
            }
        }
        
        var displayName: String {
            switch self {
            case .improvement:
                return "上升"
            case .decline:
                return "下降"
            case .stable:
                return "持平"
            case .newEntry:
                return "新進榜"
            }
        }
    }
}

/// 錦標賽排名系統
@MainActor
class TournamentRankingSystem: ObservableObject {
    static let shared = TournamentRankingSystem()
    
    // MARK: - Published Properties
    @Published var tournamentRankings: [UUID: [TournamentParticipant]] = [:]
    @Published var rankingHistory: [UUID: [RankingChange]] = [:]
    @Published var isCalculating: Bool = false
    @Published var lastUpdateTime: [UUID: Date] = [:]
    
    // MARK: - Constants
    private let weights = RankingWeights()
    private let supabaseService = SupabaseService.shared
    
    private init() {
        loadRankingData()
    }
    
    // MARK: - Public Methods
    
    /// 計算並更新錦標賽排名
    func calculateAndUpdateRankings(for tournamentId: UUID) async {
        print("📊 [TournamentRankingSystem] 開始計算錦標賽排名: \(tournamentId)")
        
        isCalculating = true
        defer { isCalculating = false }
        
        do {
            // 獲取所有參賽者的投資組合數據
            let portfolios = await getAllPortfolios(for: tournamentId)
            
            // 計算排名分數
            let participantsWithScores = calculateRankingScores(portfolios: portfolios)
            
            // 排序並分配排名
            let rankedParticipants = assignRankings(participants: participantsWithScores)
            
            // 檢測排名變動
            let rankingChanges = detectRankingChanges(
                tournamentId: tournamentId,
                newRankings: rankedParticipants
            )
            
            // 更新排名數據
            tournamentRankings[tournamentId] = rankedParticipants
            if !rankingChanges.isEmpty {
                rankingHistory[tournamentId, default: []].append(contentsOf: rankingChanges)
            }
            lastUpdateTime[tournamentId] = Date()
            
            // 保存到本地和後端
            saveRankingData()
            await syncRankingsToBackend(tournamentId: tournamentId, rankings: rankedParticipants)
            
            print("✅ 錦標賽排名計算完成，共 \(rankedParticipants.count) 位參賽者")
            
        } catch {
            print("❌ 計算錦標賽排名失敗: \(error)")
        }
    }
    
    /// 獲取錦標賽排名
    func getRankings(for tournamentId: UUID) -> [TournamentParticipant] {
        return tournamentRankings[tournamentId] ?? []
    }
    
    /// 獲取用戶排名
    func getUserRanking(tournamentId: UUID, userId: UUID) -> TournamentParticipant? {
        return getRankings(for: tournamentId).first { $0.userId == userId }
    }
    
    /// 獲取排名變動歷史
    func getRankingChanges(for tournamentId: UUID) -> [RankingChange] {
        return rankingHistory[tournamentId] ?? []
    }
    
    /// 獲取前N名參賽者
    func getTopParticipants(tournamentId: UUID, count: Int = 10) -> [TournamentParticipant] {
        let rankings = getRankings(for: tournamentId)
        return Array(rankings.prefix(count))
    }
    
    /// 獲取用戶周圍的排名（用戶前後各N名）
    func getSurroundingRankings(tournamentId: UUID, userId: UUID, range: Int = 5) -> [TournamentParticipant] {
        let rankings = getRankings(for: tournamentId)
        
        guard let userIndex = rankings.firstIndex(where: { $0.userId == userId }) else {
            return []
        }
        
        let startIndex = max(0, userIndex - range)
        let endIndex = min(rankings.count - 1, userIndex + range)
        
        return Array(rankings[startIndex...endIndex])
    }
    
    // MARK: - Private Methods
    
    /// 獲取所有投資組合數據
    private func getAllPortfolios(for tournamentId: UUID) async -> [(userId: UUID, userName: String, portfolio: TournamentPortfolio?)] {
        // 從 TournamentPortfolioManager 獲取數據
        let portfolioManager = TournamentPortfolioManager.shared
        
        // 這裡應該從後端獲取所有參賽者列表
        // 暫時使用模擬數據
        let mockParticipants = await getMockParticipants(for: tournamentId)
        
        return mockParticipants.map { participant in
            let portfolio = portfolioManager.getPortfolio(for: tournamentId)
            return (userId: participant.userId, userName: participant.userName, portfolio: portfolio)
        }
    }
    
    /// 計算排名分數
    private func calculateRankingScores(portfolios: [(userId: UUID, userName: String, portfolio: TournamentPortfolio?)]) -> [TournamentParticipant] {
        
        return portfolios.compactMap { item in
            guard let portfolio = item.portfolio else { return nil }
            
            // 計算各項分數
            let returnScore = calculateReturnScore(portfolio: portfolio)
            let riskAdjustedScore = calculateRiskAdjustedScore(portfolio: portfolio)
            let consistencyScore = calculateConsistencyScore(portfolio: portfolio)
            let activityScore = calculateActivityScore(portfolio: portfolio)
            
            // 計算總分
            let totalScore = 
                returnScore * weights.totalReturn +
                riskAdjustedScore * weights.riskAdjustedReturn +
                consistencyScore * weights.consistency +
                activityScore * weights.activity
            
            return TournamentParticipant(
                id: UUID(),
                tournamentId: portfolio.tournamentId,
                userId: portfolio.userId,
                userName: portfolio.userName,
                userAvatar: nil,
                currentRank: 0, // 將在後續分配
                previousRank: getCurrentRank(tournamentId: portfolio.tournamentId, userId: portfolio.userId),
                virtualBalance: portfolio.totalPortfolioValue,
                initialBalance: portfolio.initialBalance,
                returnRate: portfolio.totalReturnPercentage / 100.0,
                totalTrades: portfolio.performanceMetrics.totalTrades,
                winRate: portfolio.performanceMetrics.winRate,
                maxDrawdown: portfolio.performanceMetrics.maxDrawdownPercentage / 100.0,
                sharpeRatio: portfolio.performanceMetrics.sharpeRatio,
                isEliminated: false,
                eliminationReason: nil,
                joinedAt: Date(), // 應該從實際數據獲取
                lastUpdated: Date()
            )
        }
    }
    
    /// 計算收益率分數
    private func calculateReturnScore(portfolio: TournamentPortfolio) -> Double {
        let returnRate = portfolio.totalReturnPercentage
        // 將收益率轉換為 0-100 分數
        // 假設 50% 收益率為滿分
        return min(100, max(0, (returnRate / 50.0) * 100))
    }
    
    /// 計算風險調整收益分數
    private func calculateRiskAdjustedScore(portfolio: TournamentPortfolio) -> Double {
        guard let sharpeRatio = portfolio.performanceMetrics.sharpeRatio,
              sharpeRatio != 0 else { return 50 } // 無夏普比率時給予中等分數
        
        // 夏普比率 > 2 為優秀，給予滿分
        return min(100, max(0, (sharpeRatio / 2.0) * 100))
    }
    
    /// 計算穩定性分數
    private func calculateConsistencyScore(portfolio: TournamentPortfolio) -> Double {
        let maxDrawdown = portfolio.performanceMetrics.maxDrawdownPercentage
        // 最大回撤越小，穩定性分數越高
        // 假設 5% 回撤為滿分基準
        return min(100, max(0, 100 - (maxDrawdown / 5.0) * 100))
    }
    
    /// 計算活躍度分數
    private func calculateActivityScore(portfolio: TournamentPortfolio) -> Double {
        let totalTrades = portfolio.performanceMetrics.totalTrades
        // 假設 20 筆交易為滿分基準
        return min(100, max(0, (Double(totalTrades) / 20.0) * 100))
    }
    
    /// 分配排名
    private func assignRankings(participants: [TournamentParticipant]) -> [TournamentParticipant] {
        // 按收益率排序
        let sortedParticipants = participants.sorted { participant1, participant2 in
            participant1.returnRate > participant2.returnRate
        }
        
        // 分配排名
        return sortedParticipants.enumerated().map { index, participant in
            var updatedParticipant = participant
            updatedParticipant = TournamentParticipant(
                id: participant.id,
                tournamentId: participant.tournamentId,
                userId: participant.userId,
                userName: participant.userName,
                userAvatar: participant.userAvatar,
                currentRank: index + 1,
                previousRank: participant.previousRank,
                virtualBalance: participant.virtualBalance,
                initialBalance: participant.initialBalance,
                returnRate: participant.returnRate,
                totalTrades: participant.totalTrades,
                winRate: participant.winRate,
                maxDrawdown: participant.maxDrawdown,
                sharpeRatio: participant.sharpeRatio,
                isEliminated: participant.isEliminated,
                eliminationReason: participant.eliminationReason,
                joinedAt: participant.joinedAt,
                lastUpdated: Date()
            )
            return updatedParticipant
        }
    }
    
    /// 檢測排名變動
    private func detectRankingChanges(tournamentId: UUID, newRankings: [TournamentParticipant]) -> [RankingChange] {
        let previousRankings = tournamentRankings[tournamentId] ?? []
        var changes: [RankingChange] = []
        
        for participant in newRankings {
            let previousRank = previousRankings.first { $0.userId == participant.userId }?.currentRank ?? 0
            let currentRank = participant.currentRank
            let change = previousRank - currentRank
            
            let changeType: RankingChange.RankingChangeType
            let reason: String
            
            if previousRank == 0 {
                changeType = .newEntry
                reason = "首次進入排行榜"
            } else if change > 0 {
                changeType = .improvement
                reason = "上升 \(change) 名"
            } else if change < 0 {
                changeType = .decline
                reason = "下降 \(abs(change)) 名"
            } else {
                changeType = .stable
                reason = "排名保持不變"
            }
            
            if changeType != .stable || previousRank == 0 {
                let rankingChange = RankingChange(
                    tournamentId: tournamentId,
                    userId: participant.userId,
                    userName: participant.userName,
                    previousRank: previousRank,
                    currentRank: currentRank,
                    change: change,
                    changeType: changeType,
                    timestamp: Date(),
                    reason: reason
                )
                changes.append(rankingChange)
            }
        }
        
        return changes
    }
    
    /// 獲取當前排名
    private func getCurrentRank(tournamentId: UUID, userId: UUID) -> Int {
        return tournamentRankings[tournamentId]?.first { $0.userId == userId }?.currentRank ?? 0
    }
    
    /// 獲取模擬參賽者數據
    private func getMockParticipants(for tournamentId: UUID) async -> [(userId: UUID, userName: String)] {
        // 這裡應該從後端獲取實際參賽者列表
        return [
            (userId: UUID(), userName: "投資大師"),
            (userId: UUID(), userName: "穩健投資人"),
            (userId: UUID(), userName: "價值投資者"),
            (userId: UUID(), userName: "成長股獵人"),
            (userId: UUID(), userName: "量化交易員")
        ]
    }
    
    // MARK: - Data Persistence
    
    private func saveRankingData() {
        do {
            let rankingsData = try JSONEncoder().encode(tournamentRankings)
            UserDefaults.standard.set(rankingsData, forKey: "tournament_rankings")
            
            let historyData = try JSONEncoder().encode(rankingHistory)
            UserDefaults.standard.set(historyData, forKey: "ranking_history")
            
            let updateTimeData = try JSONEncoder().encode(lastUpdateTime)
            UserDefaults.standard.set(updateTimeData, forKey: "ranking_update_time")
            
        } catch {
            print("❌ 保存排名數據失敗: \(error)")
        }
    }
    
    private func loadRankingData() {
        // 載入排名數據
        if let rankingsData = UserDefaults.standard.data(forKey: "tournament_rankings") {
            do {
                tournamentRankings = try JSONDecoder().decode([UUID: [TournamentParticipant]].self, from: rankingsData)
            } catch {
                print("❌ 載入排名數據失敗: \(error)")
            }
        }
        
        // 載入歷史數據
        if let historyData = UserDefaults.standard.data(forKey: "ranking_history") {
            do {
                rankingHistory = try JSONDecoder().decode([UUID: [RankingChange]].self, from: historyData)
            } catch {
                print("❌ 載入排名歷史失敗: \(error)")
            }
        }
        
        // 載入更新時間
        if let updateTimeData = UserDefaults.standard.data(forKey: "ranking_update_time") {
            do {
                lastUpdateTime = try JSONDecoder().decode([UUID: Date].self, from: updateTimeData)
            } catch {
                print("❌ 載入更新時間失敗: \(error)")
            }
        }
    }
    
    private func syncRankingsToBackend(tournamentId: UUID, rankings: [TournamentParticipant]) async {
        do {
            try await supabaseService.syncTournamentRankings(tournamentId: tournamentId, rankings: rankings)
            print("✅ 排名數據同步到後端成功")
        } catch {
            print("❌ 排名數據同步失敗: \(error)")
        }
    }
}

// Note: SupabaseService methods for tournament rankings 
// are implemented in the main SupabaseService.swift file