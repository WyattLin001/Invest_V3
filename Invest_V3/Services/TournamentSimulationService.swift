//
//  TournamentSimulationService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  錦標賽投資模擬服務 - 統一管理投資模擬功能的入口點
//

import Foundation
import SwiftUI
import Combine

/// 投資模擬狀態
enum SimulationStatus: Equatable {
    case notStarted
    case initializing
    case ready
    case error(String)
    
    static func == (lhs: SimulationStatus, rhs: SimulationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted), (.initializing, .initializing), (.ready, .ready):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// 錦標賽投資模擬服務
@MainActor
class TournamentSimulationService: ObservableObject {
    static let shared = TournamentSimulationService()
    
    // MARK: - Published Properties
    @Published var simulationStatus: SimulationStatus = .notStarted
    @Published var currentTournaments: [Tournament] = []
    @Published var userTournamentStatus: [UUID: TournamentUserStatus] = [:]
    @Published var isLoading: Bool = false
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let portfolioManager = TournamentPortfolioManager.shared
    private let rankingSystem = TournamentRankingSystem.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadUserTournamentStatus()
        Task { @MainActor in
            await loadAvailableTournaments()
        }
    }
    
    // MARK: - Public Methods
    
    /// 開始投資模擬（主要入口點）
    func startInvestmentSimulation() async -> Bool {
        Logger.info("開始投資模擬", category: .tournament)
        
        isLoading = true
        simulationStatus = .initializing
        
        defer { isLoading = false }
        
        do {
            // Step 1: 驗證用戶身份
            guard let currentUser = await verifyUserIdentity() else {
                simulationStatus = .error("用戶身份驗證失敗")
                return false
            }
            
            Logger.debug("用戶身份驗證成功: \(currentUser.username)", category: .auth)
            
            // Step 2: 載入可用錦標賽
            let tournaments = await loadAvailableTournaments()
            Logger.info("找到 \(tournaments.count) 個可參加的錦標賽", category: .tournament)
            
            // Step 3: 初始化用戶的錦標賽投資組合
            let initializationResults = await initializeUserTournamentPortfolios(
                user: currentUser,
                tournaments: tournaments
            )
            
            // Step 4: 同步投資狀況到後端
            await syncInvestmentStatusToBackend(userId: currentUser.id)
            
            // Step 5: 更新排名和績效
            await updateAllTournamentsRankingsAndPerformance()
            
            // Step 6: 載入交易記錄和績效數據
            await loadUserTradingHistoryAndPerformance(userId: currentUser.id)
            
            simulationStatus = .ready
            
            Logger.info("投資模擬初始化完成", category: .tournament)
            Logger.debug("用戶參與錦標賽數量: \(initializationResults.successful)", category: .tournament)
            Logger.warning("初始化失敗數量: \(initializationResults.failed)", category: .tournament)
            
            return true
            
        } catch {
            Logger.error("投資模擬初始化失敗: \(error)", category: .tournament)
            simulationStatus = .error(error.localizedDescription)
            return false
        }
    }
    
    /// 獲取用戶在所有錦標賽中的狀況
    func getUserTournamentSummary() -> UserTournamentSummary {
        let participatingTournaments = userTournamentStatus.values.filter { $0.isParticipating }
        
        var totalPortfolioValue: Double = 0
        var totalReturn: Double = 0
        var averageRank: Double = 0
        var totalTrades: Int = 0
        
        for status in participatingTournaments {
            if let portfolio = portfolioManager.getPortfolio(for: status.tournamentId) {
                totalPortfolioValue += portfolio.totalPortfolioValue
                totalReturn += portfolio.totalReturn
                totalTrades += portfolio.performanceMetrics.totalTrades
            }
            
            if let ranking = rankingSystem.getUserRanking(tournamentId: status.tournamentId, userId: status.userId) {
                averageRank += Double(ranking.currentRank)
            }
        }
        
        let tournamentCount = participatingTournaments.count
        averageRank = tournamentCount > 0 ? averageRank / Double(tournamentCount) : 0
        
        return UserTournamentSummary(
            participatingTournaments: tournamentCount,
            totalPortfolioValue: totalPortfolioValue,
            totalReturn: totalReturn,
            totalReturnPercentage: totalPortfolioValue > 0 ? (totalReturn / (totalPortfolioValue - totalReturn)) * 100 : 0,
            averageRank: Int(averageRank),
            totalTrades: totalTrades,
            bestRank: participatingTournaments.compactMap { status in
                rankingSystem.getUserRanking(tournamentId: status.tournamentId, userId: status.userId)?.currentRank
            }.min() ?? 0
        )
    }
    
    /// 獲取特定錦標賽的詳細資訊
    func getTournamentDetails(tournamentId: UUID) async -> TournamentDetailInfo? {
        guard let tournament = currentTournaments.first(where: { $0.id == tournamentId }) else {
            return nil
        }
        
        let portfolio = portfolioManager.getPortfolio(for: tournamentId)
        let userRanking = rankingSystem.getUserRanking(tournamentId: tournamentId, userId: portfolio?.userId ?? UUID())
        let topRankings = rankingSystem.getTopParticipants(tournamentId: tournamentId, count: 10)
        
        return TournamentDetailInfo(
            tournament: tournament,
            userPortfolio: portfolio,
            userRanking: userRanking,
            topRankings: topRankings,
            totalParticipants: topRankings.count
        )
    }
    
    /// 執行錦標賽交易
    func executeTournamentTrade(
        tournamentId: UUID,
        symbol: String,
        stockName: String,
        action: TradingType,
        shares: Double,
        price: Double
    ) async -> Bool {
        
        Logger.info("執行錦標賽交易", category: .trading)
        
        // 執行交易
        let success = await portfolioManager.executeTrade(
            tournamentId: tournamentId,
            symbol: symbol,
            stockName: stockName,
            action: action,
            shares: shares,
            price: price
        )
        
        if success {
            // 更新排名
            await rankingSystem.calculateAndUpdateRankings(for: tournamentId)
            
            // 同步到後端
            await syncTradingRecordToBackend(tournamentId: tournamentId)
            
            Logger.info("錦標賽交易執行成功", category: .trading)
        } else {
            Logger.error("錦標賽交易執行失敗", category: .trading)
        }
        
        return success
    }
    
    // MARK: - Private Methods
    
    /// 驗證用戶身份
    private func verifyUserIdentity() async -> UserProfile? {
        do {
            let user = try await supabaseService.getCurrentUserAsync()
            Logger.debug("驗證用戶身份: \(user.username)", category: .auth)
            return user
        } catch {
            Logger.error("用戶身份驗證失敗: \(error)", category: .auth)
            return nil
        }
    }
    
    /// 載入可用錦標賽
    @discardableResult
    private func loadAvailableTournaments() async -> [Tournament] {
        do {
            // 從後端獲取錦標賽列表
            let tournaments = try await supabaseService.fetchAvailableTournaments()
            
            await MainActor.run {
                self.currentTournaments = tournaments
            }
            
            Logger.debug("載入錦標賽成功: \(tournaments.count) 個", category: .tournament)
            return tournaments
        } catch {
            Logger.error("載入錦標賽失敗: \(error)", category: .tournament)
            await MainActor.run {
                self.currentTournaments = []
            }
            return []
        }
    }
    
    /// 初始化用戶錦標賽投資組合
    private func initializeUserTournamentPortfolios(
        user: UserProfile,
        tournaments: [Tournament]
    ) async -> (successful: Int, failed: Int) {
        
        var successful = 0
        var failed = 0
        
        for tournament in tournaments {
            // 檢查用戶是否已參與此錦標賽
            if userTournamentStatus[tournament.id]?.isParticipating == true {
                Logger.warning("用戶已參與錦標賽: \(tournament.name)", category: .tournament)
                continue
            }
            
            // 初始化投資組合
            let success = await portfolioManager.initializePortfolio(
                for: tournament,
                userId: user.id,
                userName: user.username
            )
            
            if success {
                // 更新用戶錦標賽狀態
                userTournamentStatus[tournament.id] = TournamentUserStatus(
                    tournamentId: tournament.id,
                    userId: user.id,
                    isParticipating: true,
                    joinedAt: Date(),
                    lastActivityAt: Date()
                )
                successful += 1
                Logger.debug("錦標賽投資組合初始化成功: \(tournament.name)", category: .tournament)
            } else {
                failed += 1
                Logger.error("錦標賽投資組合初始化失敗: \(tournament.name)", category: .tournament)
            }
        }
        
        saveUserTournamentStatus()
        return (successful: successful, failed: failed)
    }
    
    /// 同步投資狀況到後端
    private func syncInvestmentStatusToBackend(userId: UUID) async {
        do {
            try await supabaseService.syncUserTournamentStatus(userId: userId, status: userTournamentStatus)
            Logger.debug("投資狀況同步到後端成功", category: .network)
        } catch {
            Logger.error("投資狀況同步失敗: \(error)", category: .network)
        }
    }
    
    /// 更新所有錦標賽排名和績效
    private func updateAllTournamentsRankingsAndPerformance() async {
        for tournament in currentTournaments {
            // 更新績效指標
            await portfolioManager.updatePerformanceMetrics(for: tournament.id)
            
            // 計算排名
            await rankingSystem.calculateAndUpdateRankings(for: tournament.id)
        }
        
        Logger.debug("所有錦標賽排名和績效更新完成", category: .performance)
    }
    
    /// 載入用戶交易歷史和績效數據
    private func loadUserTradingHistoryAndPerformance(userId: UUID) async {
        do {
            let tradingHistory = try await supabaseService.fetchUserTournamentTradingHistory(userId: userId)
            Logger.debug("載入交易歷史成功: \(tradingHistory.count) 筆記錄", category: .general)
        } catch {
            Logger.error("載入交易歷史失敗: \(error)", category: .general)
        }
    }
    
    /// 同步交易記錄到後端
    private func syncTradingRecordToBackend(tournamentId: UUID) async {
        do {
            try await supabaseService.syncTournamentTradingRecord(tournamentId: tournamentId)
            Logger.debug("交易記錄同步成功", category: .network)
        } catch {
            Logger.error("交易記錄同步失敗: \(error)", category: .network)
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveUserTournamentStatus() {
        do {
            let data = try JSONEncoder().encode(userTournamentStatus)
            UserDefaults.standard.set(data, forKey: "user_tournament_status")
        } catch {
            Logger.error("保存用戶錦標賽狀態失敗: \(error)", category: .general)
        }
    }
    
    private func loadUserTournamentStatus() {
        guard let data = UserDefaults.standard.data(forKey: "user_tournament_status") else { return }
        
        do {
            userTournamentStatus = try JSONDecoder().decode([UUID: TournamentUserStatus].self, from: data)
            Logger.debug("載入用戶錦標賽狀態: \(userTournamentStatus.count) 個", category: .general)
        } catch {
            Logger.error("載入用戶錦標賽狀態失敗: \(error)", category: .general)
        }
    }
}

// MARK: - Supporting Types

/// 用戶錦標賽狀態
struct TournamentUserStatus: Codable {
    let tournamentId: UUID
    let userId: UUID
    let isParticipating: Bool
    let joinedAt: Date
    var lastActivityAt: Date
    
    enum CodingKeys: String, CodingKey {
        case isParticipating = "is_participating"
        case joinedAt = "joined_at"
        case lastActivityAt = "last_activity_at"
        case tournamentId = "tournament_id"
        case userId = "user_id"
    }
}

/// 錦標賽摘要資訊
struct UserTournamentSummary {
    let participatingTournaments: Int
    let totalPortfolioValue: Double
    let totalReturn: Double
    let totalReturnPercentage: Double
    let averageRank: Int
    let totalTrades: Int
    let bestRank: Int
}

/// 錦標賽詳細資訊
struct TournamentDetailInfo {
    let tournament: Tournament
    let userPortfolio: TournamentPortfolio?
    let userRanking: TournamentParticipant?
    let topRankings: [TournamentParticipant]
    let totalParticipants: Int
}

// Note: SupabaseService methods for tournament simulation 
// are implemented in the main SupabaseService.swift file