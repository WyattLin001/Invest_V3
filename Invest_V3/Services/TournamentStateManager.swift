//
//  TournamentStateManager.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/1.
//  錦標賽狀態管理器 - 管理當前參與的錦標賽狀態和上下文
//

import Foundation
import Combine
import SwiftUI

// MARK: - 錦標賽參與狀態
enum TournamentParticipationState {
    case none           // 未參與任何錦標賽
    case joining        // 正在加入錦標賽
    case active         // 積極參與中
    case paused         // 暫停參與
    case eliminated     // 被淘汰
    case completed      // 錦標賽已完成
    
    var displayName: String {
        switch self {
        case .none: return "未參與"
        case .joining: return "加入中"
        case .active: return "參與中"
        case .paused: return "已暫停"
        case .eliminated: return "已淘汰"
        case .completed: return "已完成"
        }
    }
    
    var canTrade: Bool {
        switch self {
        case .active: return true
        default: return false
        }
    }
}

// MARK: - 錦標賽上下文
struct TournamentContext: Equatable {
    let tournament: Tournament
    let participant: TournamentParticipant?
    let state: TournamentParticipationState
    let portfolio: TournamentPortfolio?  // 使用新的錦標賽投資組合
    let performance: PerformanceMetrics?  // 使用統一的績效指標模型
    let currentRank: Int?
    let joinedAt: Date
    
    var isActive: Bool {
        return state == .active && tournament.status == .ongoing
    }
    
    var canMakeTrades: Bool {
        return isActive && state.canTrade
    }
    
    var displayTitle: String {
        return tournament.name
    }
    
    static func == (lhs: TournamentContext, rhs: TournamentContext) -> Bool {
        return lhs.tournament.id == rhs.tournament.id &&
               lhs.participant?.id == rhs.participant?.id &&
               lhs.state == rhs.state &&
               lhs.currentRank == rhs.currentRank
    }
}

// MARK: - 錦標賽狀態管理器
@MainActor
class TournamentStateManager: ObservableObject {
    static let shared = TournamentStateManager()
    
    // MARK: - Published Properties
    @Published var currentTournamentContext: TournamentContext?
    @Published var isParticipatingInTournament: Bool = false
    @Published var participationState: TournamentParticipationState = .none
    @Published var isJoining: Bool = false
    @Published var joinError: String?
    @Published var enrolledTournaments: Set<UUID> = []
    
    // MARK: - Private Properties
    private let tournamentService = TournamentService.shared
    private let portfolioManager = TournamentPortfolioManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 監聽錦標賽狀態變化
        setupStateObservers()
        
        // 載入持久化的錦標賽狀態
        loadPersistedTournamentState()
        
        // 延遲同步數據庫狀態，確保其他服務已初始化
        Task {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 延遲1秒
                await refreshUserTournamentStatus()
            } catch {
                Logger.error("初始化同步失敗: \(error)", category: .tournament)
            }
        }
    }
    
    // MARK: - 公共方法
    
    /// 加入錦標賽
    func joinTournament(_ tournament: Tournament) async {
        guard !isJoining else { return }
        
        isJoining = true
        joinError = nil
        
        do {
            Logger.info("開始加入錦標賽: \(tournament.name)", category: .tournament)
            
            // 使用 SupabaseService 進行真實的錦標賽加入
            let success = try await SupabaseService.shared.joinTournament(tournamentId: tournament.id)
            
            if success {
                // 獲取參與者資料
                let participants = try await SupabaseService.shared.fetchTournamentParticipants(tournamentId: tournament.id)
                let currentUser = SupabaseService.shared.getCurrentUser()
                let participant = participants.first { participant in
                    guard let user = currentUser else { return false }
                    return participant.userId == user.id
                }
                
                // 獲取錦標賽專用投資組合（應該已經由TournamentService.joinTournament創建）
                let tournamentPortfolio = portfolioManager.getPortfolio(for: tournament.id)
                
                // 設定錦標賽上下文
                let context = TournamentContext(
                    tournament: tournament,
                    participant: participant,
                    state: .active,
                    portfolio: tournamentPortfolio,
                    performance: tournamentPortfolio?.performanceMetrics,
                    currentRank: participant?.currentRank,
                    joinedAt: Date()
                )
                
                // 更新狀態
                currentTournamentContext = context
                isParticipatingInTournament = true
                participationState = .active
                enrolledTournaments.insert(tournament.id)
                
                // 持久化狀態
                persistTournamentState()
                
                Logger.info("成功加入錦標賽: \(tournament.name)", category: .tournament)
            } else {
                joinError = "加入錦標賽失敗"
                Logger.error("加入錦標賽失敗", category: .tournament)
            }
            
        } catch {
            Logger.error("加入錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            joinError = "加入錦標賽失敗：\(error.localizedDescription)"
        }
        
        isJoining = false
    }
    
    /// 離開錦標賽（僅切換到一般模式，不退出錦標賽）
    func leaveTournament() async {
        let previousTournamentId = currentTournamentContext?.tournament.id
        Logger.info("切換到一般模式", category: .tournament)
        
        // 僅清除當前錦標賽上下文，但保留報名狀態
        await MainActor.run {
            currentTournamentContext = nil
            isParticipatingInTournament = false
            participationState = .none
            
            // 發送切換到一般模式通知
            NotificationCenter.default.post(
                name: NSNotification.Name("TournamentContextChanged"),
                object: self,
                userInfo: [
                    "tournamentId": "",
                    "tournamentName": "一般模式"
                ]
            )
            Logger.debug("已發送 TournamentContextChanged 通知: 一般模式", category: .tournament)
        }
        
        // 持久化狀態（保留已報名的錦標賽）
        persistTournamentState()
        
        Logger.debug("已切換到一般模式", category: .tournament)
    }
    
    /// 完全退出錦標賽（真正離開）
    func exitTournament(_ tournamentId: UUID) async {
        do {
            Logger.info("開始退出錦標賽", category: .tournament)
            
            // 使用 SupabaseService 進行真實的錦標賽離開
            let success = try await SupabaseService.shared.leaveTournament(tournamentId: tournamentId)
            
            if success {
                // 移除報名狀態
                enrolledTournaments.remove(tournamentId)
                
                // 如果正在參與的是這個錦標賽，清除狀態
                if let context = currentTournamentContext, context.tournament.id == tournamentId {
                    currentTournamentContext = nil
                    isParticipatingInTournament = false
                    participationState = .none
                }
                
                // 持久化狀態
                persistTournamentState()
                
                Logger.info("成功退出錦標賽", category: .tournament)
            } else {
                Logger.error("退出錦標賽失敗", category: .tournament)
            }
            
        } catch {
            Logger.error("退出錦標賽失敗: \(error.localizedDescription)", category: .tournament)
            joinError = "退出錦標賽失敗：\(error.localizedDescription)"
        }
    }
    
    /// 更新投資組合
    func updatePortfolio(_ portfolio: TournamentPortfolio?) {
        guard var context = currentTournamentContext else { return }
        
        // 更新上下文中的投資組合
        let updatedContext = TournamentContext(
            tournament: context.tournament,
            participant: context.participant,
            state: context.state,
            portfolio: portfolio,
            performance: portfolio?.performanceMetrics,
            currentRank: context.currentRank,
            joinedAt: context.joinedAt
        )
        
        currentTournamentContext = updatedContext
        persistTournamentState()
        
        if let portfolio = portfolio {
            Logger.debug("投資組合已更新，總價值: \(portfolio.totalPortfolioValue)", category: .tournament)
        }
    }
    
    /// 更新績效指標
    func updatePerformance(_ performance: PerformanceMetrics?) {
        guard var context = currentTournamentContext else { return }
        
        // 更新上下文中的績效指標
        let updatedContext = TournamentContext(
            tournament: context.tournament,
            participant: context.participant,
            state: context.state,
            portfolio: context.portfolio,
            performance: performance,
            currentRank: context.currentRank,
            joinedAt: context.joinedAt
        )
        
        currentTournamentContext = updatedContext
        persistTournamentState()
        
        if let performance = performance {
            Logger.debug("績效指標已更新，總回報: \(performance.totalReturn)", category: .performance)
        }
    }
    
    /// 更新排名
    func updateRank(_ rank: Int) {
        guard var context = currentTournamentContext else { return }
        
        // 更新上下文中的排名
        let updatedContext = TournamentContext(
            tournament: context.tournament,
            participant: context.participant,
            state: context.state,
            portfolio: context.portfolio,
            performance: context.performance,
            currentRank: rank,
            joinedAt: context.joinedAt
        )
        
        currentTournamentContext = updatedContext
        persistTournamentState()
        
        Logger.debug("排名已更新: #\(rank)", category: .tournament)
    }
    
    /// 獲取當前錦標賽名稱（用於UI顯示）
    func getCurrentTournamentDisplayName() -> String? {
        return currentTournamentContext?.displayTitle
    }
    
    /// 檢查是否可以進行交易
    func canMakeTrades() -> Bool {
        return currentTournamentContext?.canMakeTrades ?? false
    }
    
    /// 獲取當前錦標賽 ID（靜默版本）
    func getCurrentTournamentId() -> UUID? {
        return currentTournamentContext?.tournament.id
    }
    
    /// 獲取當前錦標賽 ID（調試版本）
    func getCurrentTournamentIdDebug() -> UUID? {
        let tournamentId = currentTournamentContext?.tournament.id
        Logger.debug("getCurrentTournamentId(): \(tournamentId?.uuidString ?? "nil")", category: .tournament)
        return tournamentId
    }
    
    /// 檢查是否已報名特定錦標賽
    func isEnrolledInTournament(_ tournamentId: UUID) -> Bool {
        return enrolledTournaments.contains(tournamentId)
    }
    
    /// 檢查是否已報名特定錦標賽（使用 Tournament 對象）
    func isEnrolledInTournament(_ tournament: Tournament) -> Bool {
        return enrolledTournaments.contains(tournament.id)
    }
    
    /// 刷新用戶錦標賽狀態（公開方法，供外部調用）
    func refreshUserTournamentStatus() async {
        await syncEnrolledTournamentsFromDatabase()
    }
    
    /// 更新錦標賽上下文（切換錦標賽時使用）
    func updateTournamentContext(_ tournament: Tournament) async {
        Logger.info("切換到錦標賽: \(tournament.name)", category: .tournament)
        
        // 創建參與者資料
        let participant = createParticipantForTournament(tournament)
        
        // 獲取錦標賽專用投資組合，如果不存在則創建
        var portfolio = portfolioManager.getPortfolio(for: tournament.id)
        Logger.debug("錦標賽投資組合狀態: \(portfolio != nil ? "存在" : "不存在")", category: .tournament)
        
        // 如果投資組合不存在，為錦標賽創建投資組合
        if portfolio == nil {
            Logger.info("為錦標賽 \(tournament.name) 創建投資組合", category: .tournament)
            
            guard let currentUser = SupabaseService.shared.getCurrentUser() else {
                Logger.error("無法獲取當前用戶，無法創建投資組合", category: .tournament)
                return
            }
            
            let portfolioInitialized = await portfolioManager.initializePortfolio(
                for: tournament,
                userId: currentUser.id,
                userName: currentUser.username
            )
            
            if portfolioInitialized {
                portfolio = portfolioManager.getPortfolio(for: tournament.id)
                Logger.debug("錦標賽投資組合創建成功", category: .tournament)
            } else {
                Logger.error("錦標賽投資組合創建失敗", category: .tournament)
            }
        }
        
        // 設定錦標賽上下文
        let context = TournamentContext(
            tournament: tournament,
            participant: participant,
            state: .active,
            portfolio: portfolio,
            performance: portfolio?.performanceMetrics,
            currentRank: nil,
            joinedAt: Date()
        )
        
        // 更新狀態
        await MainActor.run {
            let previousTournamentId = currentTournamentContext?.tournament.id
            Logger.debug("從錦標賽切換到 \(tournament.id.uuidString)", category: .tournament)
            
            currentTournamentContext = context
            isParticipatingInTournament = true
            participationState = .active
            isJoining = false
            enrolledTournaments.insert(tournament.id)
            
            // 發送錦標賽切換通知
            let notificationName = NSNotification.Name("TournamentContextChanged")
            let userInfo = [
                "tournamentId": tournament.id.uuidString,
                "tournamentName": tournament.name
            ]
            
            
            NotificationCenter.default.post(
                name: notificationName,
                object: self,
                userInfo: userInfo
            )
            
            Logger.debug("已發送 TournamentContextChanged 通知", category: .tournament)
            
            // 延遲檢查是否有監聽器
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Logger.debug("通知發送後檢查 - 當前錦標賽ID: \(self.getCurrentTournamentId()?.uuidString ?? "nil")", category: .tournament)
            }
        }
        
        // 持久化狀態
        persistTournamentState()
        
        Logger.info("已切換到錦標賽: \(tournament.name)", category: .tournament)
    }
    
    // MARK: - 私有方法
    
    private func setupStateObservers() {
        // 監聽錦標賽服務的更新
        tournamentService.$tournaments
            .sink { [weak self] tournaments in
                self?.handleTournamentUpdates(tournaments)
            }
            .store(in: &cancellables)
    }
    
    /// 處理錦標賽更新（UTC時間標準化）
    private func handleTournamentUpdates(_ tournaments: [Tournament]) {
        guard let currentContext = currentTournamentContext else { return }
        
        // 檢查當前參與的錦標賽是否有更新
        if let updatedTournament = tournaments.first(where: { $0.id == currentContext.tournament.id }) {
            // 檢查是否處於狀態轉換點
            if updatedTournament.isAtTransitionPoint {
                Logger.info("錦標賽 \(updatedTournament.name) 處於狀態轉換點", category: .tournament)
                
                if let reminder = updatedTournament.transitionReminder {
                    Logger.debug("轉換提醒: \(reminder)", category: .tournament)
                    // 可以在此處發送用戶通知
                }
            }
            
            // 使用UTC標準化的狀態更新錦標賽資訊
            let finalTournament = updatedTournament.needsStatusUpdate ? updatedTournament.withUpdatedStatus() : updatedTournament
            
            let updatedContext = TournamentContext(
                tournament: finalTournament,
                participant: currentContext.participant,
                state: determineParticipationState(for: finalTournament),
                portfolio: currentContext.portfolio,
                performance: currentContext.performance,
                currentRank: currentContext.currentRank,
                joinedAt: currentContext.joinedAt
            )
            
            currentTournamentContext = updatedContext
            participationState = updatedContext.state
            
            Logger.debug("錦標賽狀態已更新: \(finalTournament.name) -> \(finalTournament.status.displayName)", category: .tournament)
        }
    }
    
    /// 基於UTC時間判斷錦標賽參與狀態
    private func determineParticipationState(for tournament: Tournament) -> TournamentParticipationState {
        // 使用UTC標準化的狀態判斷
        let computedStatus = tournament.computedStatusUTC
        
        switch computedStatus {
        case .upcoming, .enrolling:
            return .joining
        case .ongoing, .active:
            return .active
        case .finished, .ended:
            return .completed
        case .settling:
            return .completed
        case .cancelled:
            return .none
        }
    }
    
    private func createParticipantForTournament(_ tournament: Tournament) -> TournamentParticipant {
        return TournamentParticipant(
            id: UUID(),
            tournamentId: tournament.id,
            userId: UUID(), // 實際使用時應該是當前用戶的ID
            userName: "玩家\(Int.random(in: 1000...9999))",
            userAvatar: nil,
            currentRank: tournament.currentParticipants + 1,
            previousRank: tournament.currentParticipants + 1,
            virtualBalance: tournament.initialBalance,
            initialBalance: tournament.initialBalance,
            returnRate: 0.0,
            totalTrades: 0,
            winRate: 0.0,
            maxDrawdown: 0.0,
            sharpeRatio: 0.0,
            isEliminated: false,
            eliminationReason: nil,
            joinedAt: Date(),
            lastUpdated: Date()
        )
    }
    
    // MARK: - 錦標賽上下文管理方法
    
    /// 刷新當前錦標賽上下文
    func refreshCurrentTournamentContext() async {
        guard let context = currentTournamentContext else { return }
        
        do {
            // 獲取最新錦標賽資訊
            let updatedTournament = try await tournamentService.fetchTournament(id: context.tournament.id)
            
            // 檢查錦標賽是否存在
            guard let tournament = updatedTournament else {
                Logger.warning("錦標賽不存在，無法刷新上下文", category: .tournament)
                return
            }
            
            // 獲取最新投資組合
            let updatedPortfolio = portfolioManager.getPortfolio(for: context.tournament.id)
            
            // 獲取最新參與者資訊
            let participants = try await tournamentService.fetchTournamentParticipants(tournamentId: context.tournament.id)
            let currentUser = SupabaseService.shared.getCurrentUser()
            let updatedParticipant = participants.first { participant in
                guard let user = currentUser else { return false }
                return participant.userId == user.id
            }
            
            // 更新上下文
            let updatedContext = TournamentContext(
                tournament: tournament,
                participant: updatedParticipant,
                state: context.state,
                portfolio: updatedPortfolio,
                performance: updatedPortfolio?.performanceMetrics,
                currentRank: updatedParticipant?.currentRank,
                joinedAt: context.joinedAt
            )
            
            currentTournamentContext = updatedContext
            
            Logger.debug("錦標賽上下文已刷新", category: .tournament)
            
        } catch {
            Logger.error("刷新錦標賽上下文失敗: \(error)", category: .tournament)
        }
    }
    
    // MARK: - 持久化方法
    
    private func persistTournamentState() {
        guard let context = currentTournamentContext else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            // 只持久化基本資訊，避免循環引用
            let persistentData = TournamentPersistentData(
                tournamentId: context.tournament.id,
                tournamentName: context.tournament.name,
                participationState: context.state,
                joinedAt: context.joinedAt,
                currentRank: context.currentRank,
                enrolledTournaments: enrolledTournaments
            )
            
            let data = try encoder.encode(persistentData)
            UserDefaults.standard.set(data, forKey: "CurrentTournamentContext")
            
            Logger.debug("錦標賽狀態已持久化", category: .general)
        } catch {
            Logger.error("持久化錦標賽狀態失敗: \(error.localizedDescription)", category: .general)
        }
    }
    
    private func loadPersistedTournamentState() {
        guard let data = UserDefaults.standard.data(forKey: "CurrentTournamentContext") else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let persistentData = try decoder.decode(TournamentPersistentData.self, from: data)
            
            // 從持久化資料重建狀態（簡化版本）
            participationState = persistentData.participationState
            isParticipatingInTournament = persistentData.participationState != .none
            enrolledTournaments = persistentData.enrolledTournaments
            
            Logger.debug("已載入持久化的錦標賽狀態: \(persistentData.tournamentName)", category: .general)
            
            // 從數據庫同步實際的報名狀態
            Task {
                await syncEnrolledTournamentsFromDatabase()
            }
            
        } catch {
            Logger.error("載入持久化錦標賽狀態失敗: \(error.localizedDescription)", category: .general)
            clearPersistedTournamentState()
        }
    }
    
    /// 從API同步用戶錦標賽狀態
    private func syncEnrolledTournamentsFromDatabase() async {
        Logger.debug("開始從API同步用戶錦標賽狀態", category: .network)
        
        do {
            // 使用測試用戶ID - 實際應從AuthenticationService獲取
            let testUserId = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
            
            // 從Flask API獲取用戶錦標賽
            guard let url = URL(string: "http://localhost:5002/api/user-tournaments?user_id=\(testUserId)") else {
                Logger.error("無效的API URL", category: .network)
                return
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                Logger.error("API請求失敗: \(response)", category: .network)
                return
            }
            
            // 解析API回應
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let apiResponse = try decoder.decode(UserTournamentsResponse.self, from: data)
            
            await MainActor.run {
                let previousCount = enrolledTournaments.count
                
                // 將API回應轉換為Tournament對象
                var tournaments: [Tournament] = []
                var tournamentIds: Set<UUID> = []
                
                for apiTournament in apiResponse.tournaments {
                    guard let tournamentId = UUID(uuidString: apiTournament.id) else { continue }
                    
                    let tournament = Tournament(
                        id: tournamentId,
                        name: apiTournament.name,
                        type: .monthly,
                        status: .ongoing,
                        startDate: ISO8601DateFormatter().date(from: apiTournament.start_date) ?? Date(),
                        endDate: ISO8601DateFormatter().date(from: apiTournament.end_date) ?? Date(),
                        description: "來自API的錦標賽",
                        shortDescription: apiTournament.name,
                        initialBalance: apiTournament.initial_balance,
                        entryFee: 0.0,
                        prizePool: 0.0,
                        maxParticipants: apiTournament.max_participants,
                        currentParticipants: apiTournament.current_participants,
                        isFeatured: false,
                        createdBy: UUID(), // Default UUID for current user - should be replaced with actual user ID
                        riskLimitPercentage: 20.0,
                        minHoldingRate: 0.1,
                        maxSingleStockRate: 0.3,
                        rules: [],
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    
                    tournaments.append(tournament)
                    tournamentIds.insert(tournamentId)
                }
                
                // 更新狀態
                enrolledTournaments = tournamentIds
                
                if !tournaments.isEmpty {
                    isParticipatingInTournament = true
                    participationState = .active
                    
                    // 如果目前沒有錦標賽上下文，設定第一個錦標賽為當前上下文
                    if currentTournamentContext == nil {
                        Task {
                            await updateTournamentContext(tournaments[0])
                        }
                    }
                    
                    Logger.info("同步成功: 用戶參與 \(tournaments.count) 個錦標賽", category: .network)
                    tournaments.forEach { tournament in
                    }
                } else {
                    isParticipatingInTournament = false
                    participationState = .none
                    currentTournamentContext = nil
                    Logger.info("用戶未參與任何錦標賽", category: .tournament)
                }
                
                Logger.debug("同步狀態：從 \(previousCount) 個更新為 \(enrolledTournaments.count) 個錦標賽", category: .tournament)
            }
            
        } catch {
            Logger.error("API同步失敗: \(error)", category: .network)
            
            // API失敗時使用本地數據作為備援
            await MainActor.run {
                isParticipatingInTournament = false
                participationState = .none
                currentTournamentContext = nil
            }
        }
    }
    
    private func clearPersistedTournamentState() {
        UserDefaults.standard.removeObject(forKey: "CurrentTournamentContext")
        Logger.debug("已清除持久化的錦標賽狀態", category: .general)
    }
}

// MARK: - 持久化資料模型
private struct TournamentPersistentData: Codable {
    let tournamentId: UUID
    let tournamentName: String
    let participationState: TournamentParticipationState
    let joinedAt: Date
    let currentRank: Int?
    let enrolledTournaments: Set<UUID>
}

// MARK: - TournamentParticipationState Codable 支援
extension TournamentParticipationState: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        
        switch rawValue {
        case "none": self = .none
        case "joining": self = .joining
        case "active": self = .active
        case "paused": self = .paused
        case "eliminated": self = .eliminated
        case "completed": self = .completed
        default: self = .none
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawValue: String
        
        switch self {
        case .none: rawValue = "none"
        case .joining: rawValue = "joining"
        case .active: rawValue = "active"
        case .paused: rawValue = "paused"
        case .eliminated: rawValue = "eliminated"
        case .completed: rawValue = "completed"
        }
        
        try container.encode(rawValue, forKey: .rawValue)
    }
}

// MARK: - API 回應數據結構

struct UserTournamentsResponse: Codable {
    let tournaments: [APITournament]
    let total_count: Int
}

struct APITournament: Codable {
    let id: String
    let name: String
    let status: String
    let start_date: String
    let end_date: String
    let initial_balance: Double
    let current_participants: Int
    let max_participants: Int
    let total_trades: Int
    let is_enrolled: Bool
}