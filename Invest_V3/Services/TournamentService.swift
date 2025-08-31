//
//  TournamentService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//

import Foundation
import Combine

// Logger import is not needed since Logger.swift is in the same module

// MARK: - API Response Models (moved to SupabaseService.swift to avoid duplication)

// MARK: - API Error Types
enum TournamentAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的API網址"
        case .noData:
            return "沒有收到數據"
        case .decodingError(let error):
            return "數據解析錯誤: \(error.localizedDescription)"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .unauthorized:
            return "未授權的訪問"
        case .serverError(let code):
            return "服務器錯誤 (代碼: \(code))"
        case .unknown:
            return "未知錯誤"
        }
    }
}

// MARK: - Tournament Service Protocol
protocol TournamentServiceProtocol {
    func fetchTournaments() async throws -> [Tournament]
    func fetchTournament(id: UUID) async throws -> Tournament?
    func fetchTournamentParticipants(tournamentId: UUID) async throws -> [TournamentParticipant]
    func fetchTournamentActivities(tournamentId: UUID) async throws -> [TournamentActivity]
    func joinTournament(tournamentId: UUID) async throws -> Bool
    func leaveTournament(tournamentId: UUID) async throws -> Bool
    func fetchPersonalPerformance(userId: UUID) async throws -> PersonalPerformance
    func refreshTournamentData(tournamentId: UUID) async throws -> Tournament
}

// MARK: - Tournament Service Implementation
@MainActor
class TournamentService: ObservableObject, TournamentServiceProtocol {
    nonisolated static let shared = TournamentService()
    
    // MARK: - Properties
    private lazy var supabaseService = SupabaseService.shared
    private lazy var portfolioManager = TournamentPortfolioManager.shared
    private lazy var statusMonitor = TournamentStatusMonitor.shared
    
    // Published properties for UI binding
    @Published var tournaments: [Tournament] = []
    @Published var isLoading = false
    @Published var error: TournamentAPIError?
    @Published var realtimeConnected = false
    
    // 即時更新相關屬性
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30.0 // 30秒刷新一次
    
    // 公開初始化器 - nonisolated 允許靜態創建
    nonisolated init() {
        // 簡潔的初始化器，避免在靜態創建時觸發複雜任務
    }
    
    // 啟動服務的方法，需要手動調用
    func startService() async {
        await loadTournaments()
        await startRealtimeUpdates()
        // 啟動狀態監控
        await statusMonitor.startMonitoring()
    }
    
    // MARK: - Public API Methods
    
    /// 獲取所有錦標賽列表（UTC時區標準化）
    func fetchTournaments() async throws -> [Tournament] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rawTournaments = try await supabaseService.fetchTournaments()
            
            // 使用UTC時區標準化的狀態更新機制
            let tournaments = rawTournaments.map { tournament in
                tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
            }
            
            await MainActor.run {
                self.tournaments = tournaments
                self.error = nil
            }
            
            Logger.info("成功獲取並處理 \(tournaments.count) 個錦標賽（UTC標準化）", category: .tournament)
            return tournaments
        } catch {
            let apiError = handleError(error)
            await MainActor.run {
                self.error = apiError
            }
            Logger.error("獲取錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 獲取特定錦標賽詳情（UTC時區標準化）
    func fetchTournament(id: UUID) async throws -> Tournament? {
        do {
            let rawTournament = try await supabaseService.fetchTournament(id: id)
            
            // 應用UTC時區標準化和狀態更新
            let tournament = rawTournament.needsStatusUpdate ? rawTournament.withUpdatedStatus() : rawTournament
            
            Logger.info("成功獲取錦標賽詳情: \(tournament.name)（狀態：\(tournament.status.displayName)）", category: .tournament)
            return tournament
        } catch {
            Logger.error("獲取錦標賽詳情失敗: \(error.localizedDescription)", category: .tournament)
            // Return nil instead of throwing for not found cases
            if let nsError = error as NSError?, nsError.code == 404 {
                return nil
            }
            throw error
        }
    }
    
    /// 獲取錦標賽參與者列表（整合本地投資組合數據）
    func fetchTournamentParticipants(tournamentId: UUID) async throws -> [TournamentParticipant] {
        do {
            var participants = try await supabaseService.fetchTournamentParticipants(tournamentId: tournamentId)
            
            // 整合本地投資組合數據以獲得最新績效
            participants = await integratLocalPortfolioData(participants: participants, tournamentId: tournamentId)
            
            // 按回報率排序
            participants.sort { $0.returnRate > $1.returnRate }
            
            // 更新排名
            for (index, participant) in participants.enumerated() {
                participants[index] = updateParticipantRank(participant: participant, newRank: index + 1)
            }
            
            Logger.debug("成功獲取並排序 \(participants.count) 個參與者", category: .tournament)
            return participants
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取錦標賽參與者失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 整合本地投資組合數據
    private func integratLocalPortfolioData(participants: [TournamentParticipant], tournamentId: UUID) async -> [TournamentParticipant] {
        var updatedParticipants: [TournamentParticipant] = []
        
        for participant in participants {
            // 檢查是否有本地投資組合數據
            if let localPortfolio = portfolioManager.getPortfolio(for: tournamentId),
               localPortfolio.userId == participant.userId {
                
                // 使用本地數據更新參與者資訊
                let updatedParticipant = TournamentParticipant(
                    id: participant.id,
                    tournamentId: participant.tournamentId,
                    userId: participant.userId,
                    userName: participant.userName,
                    userAvatar: participant.userAvatar,
                    currentRank: participant.currentRank,
                    previousRank: participant.previousRank,
                    virtualBalance: localPortfolio.totalPortfolioValue,
                    initialBalance: localPortfolio.initialBalance,
                    returnRate: localPortfolio.totalReturnPercentage / 100.0,
                    totalTrades: localPortfolio.performanceMetrics.totalTrades,
                    winRate: localPortfolio.performanceMetrics.winRate,
                    maxDrawdown: localPortfolio.performanceMetrics.maxDrawdownPercentage,
                    sharpeRatio: localPortfolio.performanceMetrics.sharpeRatio,
                    isEliminated: participant.isEliminated,
                    eliminationReason: participant.eliminationReason,
                    joinedAt: participant.joinedAt,
                    lastUpdated: Date()
                )
                updatedParticipants.append(updatedParticipant)
            } else {
                updatedParticipants.append(participant)
            }
        }
        
        return updatedParticipants
    }
    
    /// 更新參與者排名
    private func updateParticipantRank(participant: TournamentParticipant, newRank: Int) -> TournamentParticipant {
        return TournamentParticipant(
            id: participant.id,
            tournamentId: participant.tournamentId,
            userId: participant.userId,
            userName: participant.userName,
            userAvatar: participant.userAvatar,
            currentRank: newRank,
            previousRank: participant.currentRank, // 當前排名變為上次排名
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
    }
    
    /// 獲取錦標賽活動列表
    func fetchTournamentActivities(tournamentId: UUID) async throws -> [TournamentActivity] {
        do {
            let activities = try await supabaseService.fetchTournamentActivities(tournamentId: tournamentId)
            Logger.debug("成功獲取 \(activities.count) 個活動記錄", category: .tournament)
            return activities
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取錦標賽活動失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 加入錦標賽（整合投資組合管理）
    func joinTournament(tournamentId: UUID) async throws -> Bool {
        do {
            // 步驟1：獲取錦標賽詳情
            guard let tournament = try await fetchTournament(id: tournamentId) else {
                throw TournamentAPIError.noData
            }
            
            // 步驟2：獲取當前用戶資訊
            guard let currentUser = supabaseService.getCurrentUser() else {
                throw TournamentAPIError.unauthorized
            }
            
            // 步驟3：初始化錦標賽專用投資組合
            let portfolioInitialized = await portfolioManager.initializePortfolio(
                for: tournament,
                userId: currentUser.id,
                userName: currentUser.username ?? "Unknown User"
            )
            
            guard portfolioInitialized else {
                Logger.error("初始化錦標賽投資組合失敗", category: .tournament)
                throw TournamentAPIError.unknown
            }
            
            // 步驟3.5：創建後端投資組合記錄（統一架構）
            do {
                let initialBalance = tournament.initialBalance
                let _ = try await PortfolioService.shared.createTournamentPortfolio(
                    userId: currentUser.id,
                    tournamentId: tournamentId,
                    initialBalance: initialBalance
                )
                Logger.debug("後端統一投資組合創建成功", category: .database)
            } catch {
                Logger.warning("後端投資組合創建失敗，但本地投資組合已創建: \(error)", category: .database)
                // 不拋出錯誤，因為本地投資組合已創建，可以繼續使用
            }
            
            // 步驟4：加入錦標賽（後端）
            let success = try await supabaseService.joinTournament(tournamentId: tournamentId)
            
            if success {
                Logger.info("成功加入錦標賽並初始化投資組合", category: .tournament)
                
                // 重新載入錦標賽數據以更新參與者數量
                await loadTournaments()
                
                // 同步投資組合到後端
                if let portfolio = portfolioManager.getPortfolio(for: tournamentId) {
                    // 觸發投資組合同步
                    await portfolioManager.updatePerformanceMetrics(for: tournamentId)
                }
                
                return true
            } else {
                // 如果後端加入失敗，清理本地投資組合
                portfolioManager.removePortfolio(for: tournamentId)
                return false
            }
            
        } catch {
            let apiError = handleError(error)
            Logger.error("加入錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 離開錦標賽（整合投資組合管理）
    func leaveTournament(tournamentId: UUID) async throws -> Bool {
        do {
            // 步驟1：檢查是否有投資組合
            guard portfolioManager.hasPortfolio(for: tournamentId) else {
                Logger.warning("沒有找到錦標賽投資組合", category: .tournament)
                // 仍然嘗試從後端離開
                return try await supabaseService.leaveTournament(tournamentId: tournamentId)
            }
            
            // 步驟2：先從後端離開錦標賽
            let success = try await supabaseService.leaveTournament(tournamentId: tournamentId)
            
            if success {
                // 步驟3：清理本地投資組合
                portfolioManager.removePortfolio(for: tournamentId)
                
                // 步驟3.5：清理後端統一投資組合
                if let currentUser = supabaseService.getCurrentUser() {
                    do {
                        try await PortfolioService.shared.deleteTournamentPortfolio(
                            userId: currentUser.id,
                            tournamentId: tournamentId
                        )
                        Logger.debug("後端統一投資組合清理成功", category: .database)
                    } catch {
                        Logger.warning("後端投資組合清理失敗: \(error)", category: .database)
                        // 不影響主要流程，因為錦標賽已離開
                    }
                }
                
                Logger.info("成功離開錦標賽並清理投資組合", category: .tournament)
                
                // 重新載入錦標賽數據以更新參與者數量
                await loadTournaments()
                
                return true
            } else {
                Logger.error("後端離開錦標賽失敗", category: .tournament)
                return false
            }
            
        } catch {
            let apiError = handleError(error)
            Logger.error("離開錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 獲取個人績效數據
    func fetchPersonalPerformance(userId: UUID) async throws -> PersonalPerformance {
        do {
            // 目前返回空的績效數據，實際應用中需要從 Supabase 實現此方法
            let performance = PersonalPerformance(
                totalReturn: 0.0,
                annualizedReturn: 0.0,
                maxDrawdown: 0.0,
                sharpeRatio: nil,
                winRate: 0.0,
                totalTrades: 0,
                profitableTrades: 0,
                avgHoldingDays: 0.0,
                riskScore: 0.0,
                performanceHistory: [],
                rankingHistory: [],
                achievements: []
            )
            Logger.debug("成功獲取個人績效數據", category: .tournament)
            return performance
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取個人績效數據失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 刷新錦標賽數據（UTC時區標準化）
    func refreshTournamentData(tournamentId: UUID) async throws -> Tournament {
        guard let rawTournament = try await fetchTournament(id: tournamentId) else {
            throw TournamentAPIError.noData
        }
        return rawTournament.needsStatusUpdate ? rawTournament.withUpdatedStatus() : rawTournament
    }
    
    // MARK: - Private Helper Methods
    
    /// 載入錦標賽數據（UTC時區標準化）
    func loadTournaments() async {
        do {
            let rawTournaments = try await supabaseService.fetchTournaments()
            
            // 應用UTC時區標準化和狀態更新
            let tournaments = rawTournaments.map { tournament in
                tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
            }
            
            await MainActor.run {
                self.tournaments = tournaments
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = handleError(error)
            }
        }
    }
    
    /// 獲取精選錦標賽（UTC時區標準化）
    func fetchFeaturedTournaments() async throws -> [Tournament] {
        do {
            let rawTournaments = try await supabaseService.fetchFeaturedTournaments()
            
            // 應用UTC時區標準化和狀態更新
            let tournaments = rawTournaments.map { tournament in
                tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
            }
            
            Logger.info("成功獲取 \(tournaments.count) 個精選錦標賽（UTC標準化）", category: .tournament)
            return tournaments
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取精選錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 根據類型獲取錦標賽（UTC時區標準化）
    func fetchTournaments(type: TournamentType) async throws -> [Tournament] {
        do {
            let rawTournaments = try await supabaseService.fetchTournaments(type: type)
            
            // 應用UTC時區標準化和狀態更新
            let tournaments = rawTournaments.map { tournament in
                tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
            }
            
            Logger.info("成功獲取 \(tournaments.count) 個 \(type.displayName) 錦標賽（UTC標準化）", category: .tournament)
            return tournaments
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取錦標賽類型失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 根據狀態獲取錦標賽（UTC時區標準化）
    func fetchTournaments(status: TournamentStatus) async throws -> [Tournament] {
        do {
            let rawTournaments = try await supabaseService.fetchTournaments(status: status)
            
            // 應用UTC時區標準化和狀態更新
            let tournaments = rawTournaments.map { tournament in
                tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
            }
            
            Logger.info("成功獲取 \(tournaments.count) 個 \(status.displayName) 錦標賽（UTC標準化）", category: .tournament)
            return tournaments
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取錦標賽狀態失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    /// 獲取活躍/進行中的錦標賽
    func getActiveTournaments() async throws -> [Tournament] {
        Logger.debug("開始獲取活躍錦標賽", category: .tournament)
        
        do {
            let rawTournaments = try await supabaseService.fetchTournaments()
            
            // 過濾出活躍（ongoing）狀態的錦標賽，並進行狀態自動更新
            let tournaments = rawTournaments.compactMap { tournament -> Tournament? in
                let updatedTournament = tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
                
                // 只返回進行中的錦標賽
                return updatedTournament.status == .ongoing ? updatedTournament : nil
            }
            
            Logger.info("成功獲取 \(tournaments.count) 個活躍錦標賽", category: .tournament)
            return tournaments
        } catch {
            let apiError = handleError(error)
            Logger.error("獲取活躍錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            throw apiError
        }
    }
    
    private func handleError(_ error: Error) -> TournamentAPIError {
        if let apiError = error as? TournamentAPIError {
            return apiError
        }
        
        if error is DecodingError {
            return .decodingError(error)
        }
        
        return .networkError(error)
    }
    
    // MARK: - Realtime Updates with UTC Timezone Handling
    
    /// 開始即時更新（包含UTC時區處理）
    private func startRealtimeUpdates() async {
        Logger.info("開始即時更新（UTC時區標準化）", category: .performance)
        
        // 停止現有的計時器
        stopRealtimeUpdates()
        
        // 啟動定期刷新計時器
        await MainActor.run {
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
                Task {
                    await self?.refreshTournamentData()
                    // 檢查是否有錦標賽處於狀態轉換點
                    await self?.checkForStatusTransitions()
                }
            }
            self.realtimeConnected = true
        }
        
        Logger.debug("即時更新已啟動，刷新間隔: \(refreshInterval)秒", category: .performance)
    }
    
    /// 停止即時更新
    private func stopRealtimeUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        realtimeConnected = false
        Logger.debug("即時更新已停止", category: .performance)
    }
    
    /// 刷新錦標賽數據（UTC時區標準化）
    private func refreshTournamentData() async {
        do {
            let rawTournaments = try await supabaseService.fetchTournaments()
            
            // 應用UTC時區標準化和狀態更新
            let tournaments = rawTournaments.map { tournament in
                tournament.needsStatusUpdate ? tournament.withUpdatedStatus() : tournament
            }
            
            await MainActor.run {
                self.tournaments = tournaments
                self.error = nil
            }
            Logger.debug("自動刷新錦標賽數據成功（UTC標準化）", category: .performance)
        } catch {
            await MainActor.run {
                self.error = handleError(error)
            }
            Logger.error("自動刷新錦標賽數據失敗: \(error.localizedDescription)", category: .performance)
        }
    }
    
    /// 手動刷新錦標賽數據
    func refreshTournaments() async {
        await refreshTournamentData()
        await checkForStatusTransitions()
    }
    
    /// 重新連接即時更新
    func reconnectRealtime() async {
        Logger.info("重新連接即時更新", category: .performance)
        await startRealtimeUpdates()
    }
    
    // MARK: - UTC Timezone Status Management
    
    /// 檢查錦標賽狀態轉換點
    private func checkForStatusTransitions() async {
        let now = Date().toUTC()
        let transitionTournaments = tournaments.filter { tournament in
            tournament.isAtTransitionPoint
        }
        
        if !transitionTournaments.isEmpty {
            Logger.info("發現 \(transitionTournaments.count) 個錦標賽處於狀態轉換點", category: .tournament)
            
            for tournament in transitionTournaments {
                if let reminder = tournament.transitionReminder {
                    Logger.debug("\(tournament.name): \(reminder)", category: .tournament)
                }
            }
        }
    }
    
    /// 獲取需要狀態更新的錦標賽列表
    func getTournamentsNeedingStatusUpdate() -> [Tournament] {
        return tournaments.filter { $0.needsStatusUpdate }
    }
    
    /// 強制更新所有錦標賽狀態（基於UTC時間）
    func forceUpdateAllTournamentStatuses() async {
        let updatedTournaments = tournaments.map { tournament in
            tournament.withUpdatedStatus()
        }
        
        await MainActor.run {
            self.tournaments = updatedTournaments
        }
        
        Logger.debug("強制更新了 \(updatedTournaments.count) 個錦標賽的狀態", category: .tournament)
    }
    
    // MARK: - 錦標賽投資組合整合方法
    
    /// 獲取用戶在特定錦標賽中的投資組合
    func getUserTournamentPortfolio(tournamentId: UUID) -> TournamentPortfolio? {
        return portfolioManager.getPortfolio(for: tournamentId)
    }
    
    /// 獲取用戶參與的所有錦標賽投資組合
    func getUserAllTournamentPortfolios(userId: UUID) -> [TournamentPortfolio] {
        return portfolioManager.getUserPortfolios(userId: userId)
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
        return await portfolioManager.executeTrade(
            tournamentId: tournamentId,
            symbol: symbol,
            stockName: stockName,
            action: action,
            shares: shares,
            price: price
        )
    }
    
    /// 檢查用戶是否已加入錦標賽
    func isUserJoinedTournament(tournamentId: UUID) -> Bool {
        return portfolioManager.hasPortfolio(for: tournamentId)
    }
    
    /// 獲取錦標賽排名（整合版本）
    func fetchIntegratedTournamentRanking(tournamentId: UUID) async throws -> [TournamentParticipant] {
        return try await fetchTournamentParticipants(tournamentId: tournamentId)
    }
    
    /// 刷新所有錦標賽投資組合績效
    func refreshAllTournamentPerformance() async {
        let allPortfolios = portfolioManager.getAllPortfolios()
        
        for portfolio in allPortfolios {
            await portfolioManager.updatePerformanceMetrics(for: portfolio.tournamentId)
        }
        
        Logger.debug("已刷新 \(allPortfolios.count) 個錦標賽投資組合績效", category: .performance)
    }
    
    deinit {
        // 在 deinit 中無法調用 @MainActor 方法，需要直接清理
        refreshTimer?.invalidate()
        refreshTimer = nil
        Logger.debug("服務已釋放，即時更新已停止", category: .performance)
    }
    
    // MARK: - Status Monitor Integration
    
    /// 獲取狀態監控器
    func getStatusMonitor() -> TournamentStatusMonitor {
        return statusMonitor
    }
    
    /// 手動觸發狀態檢查
    func triggerStatusCheck() async {
        await statusMonitor.checkStatusChanges()
    }
    
    // MARK: - Missing Methods Implementation
    
    /// 保存錦標賽到數據庫
    func saveTournament(_ tournament: Tournament) async throws {
        do {
            try await supabaseService.updateTournament(tournament)
            
            // 更新本地緩存
            if let index = tournaments.firstIndex(where: { $0.id == tournament.id }) {
                await MainActor.run {
                    self.tournaments[index] = tournament
                }
            } else {
                await MainActor.run {
                    self.tournaments.append(tournament)
                }
            }
            
            Logger.info("錦標賽保存成功: \(tournament.name)", category: .database)
        } catch {
            Logger.error("保存錦標賽失敗: \(error)", category: .database)
            throw error
        }
    }
    
    /// 獲取錦標賽（簡化版本，與 fetchTournament 相同）
    func getTournament(id: UUID) async throws -> Tournament {
        guard let tournament = try await fetchTournament(id: id) else {
            throw TournamentAPIError.noData
        }
        return tournament
    }
    
    /// 獲取用戶在錦標賽中的成員資格
    func getMembership(tournamentId: UUID, userId: UUID) async throws -> TournamentMember? {
        do {
            let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
            return members.first { $0.userId == userId }
        } catch {
            Logger.error("獲取成員資格失敗: \(error)", category: .tournament)
            throw error
        }
    }
    
    /// 增加錦標賽參與者數量
    func incrementParticipantCount(tournamentId: UUID) async throws {
        do {
            guard let tournament = try await fetchTournament(id: tournamentId) else {
                throw TournamentAPIError.noData
            }
            let updatedTournament = Tournament(
                id: tournament.id,
                name: tournament.name,
                type: tournament.type,
                status: tournament.status,
                startDate: tournament.startDate,
                endDate: tournament.endDate,
                description: tournament.description,
                shortDescription: tournament.shortDescription,
                initialBalance: tournament.initialBalance,
                entryFee: tournament.entryFee,
                prizePool: tournament.prizePool,
                maxParticipants: tournament.maxParticipants,
                currentParticipants: tournament.currentParticipants + 1,
                isFeatured: tournament.isFeatured,
                createdBy: tournament.createdBy,
                riskLimitPercentage: tournament.riskLimitPercentage,
                minHoldingRate: tournament.minHoldingRate,
                maxSingleStockRate: tournament.maxSingleStockRate,
                rules: tournament.rules,
                createdAt: tournament.createdAt,
                updatedAt: Date()
            )
            
            try await saveTournament(updatedTournament)
            Logger.debug("參與者數量已增加: \(updatedTournament.currentParticipants)", category: .tournament)
        } catch {
            Logger.error("增加參與者數量失敗: \(error)", category: .tournament)
            throw error
        }
    }
    
    /// 更新錦標賽狀態
    func updateTournamentStatus(tournamentId: UUID, status: TournamentStatus) async throws {
        do {
            guard let tournament = try await fetchTournament(id: tournamentId) else {
                throw TournamentAPIError.noData
            }
            let updatedTournament = Tournament(
                id: tournament.id,
                name: tournament.name,
                type: tournament.type,
                status: status,
                startDate: tournament.startDate,
                endDate: tournament.endDate,
                description: tournament.description,
                shortDescription: tournament.shortDescription,
                initialBalance: tournament.initialBalance,
                entryFee: tournament.entryFee,
                prizePool: tournament.prizePool,
                maxParticipants: tournament.maxParticipants,
                currentParticipants: tournament.currentParticipants,
                isFeatured: tournament.isFeatured,
                createdBy: tournament.createdBy,
                riskLimitPercentage: tournament.riskLimitPercentage,
                minHoldingRate: tournament.minHoldingRate,
                maxSingleStockRate: tournament.maxSingleStockRate,
                rules: tournament.rules,
                createdAt: tournament.createdAt,
                updatedAt: Date()
            )
            
            try await saveTournament(updatedTournament)
            Logger.info("錦標賽狀態已更新: \(status.displayName)", category: .tournament)
        } catch {
            Logger.error("更新錦標賽狀態失敗: \(error)", category: .tournament)
            throw error
        }
    }
    
    /// 獲取錦標賽成員列表（與 fetchTournamentParticipants 的成員版本）
    func getMembers(tournamentId: UUID) async throws -> [TournamentMember] {
        do {
            return try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
        } catch {
            Logger.error("獲取成員列表失敗: \(error)", category: .tournament)
            throw error
        }
    }
    
    /// 創建錦標賽成員
    func createMember(_ member: TournamentMember) async throws {
        do {
            try await supabaseService.createTournamentMember(member)
            Logger.debug("錦標賽成員創建成功", category: .tournament)
        } catch {
            Logger.error("創建錦標賽成員失敗: \(error)", category: .tournament)
            throw error
        }
    }
}

