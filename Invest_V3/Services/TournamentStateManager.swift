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
struct TournamentContext {
    let tournament: Tournament
    let participant: TournamentParticipant?
    let state: TournamentParticipationState
    let portfolio: TournamentPortfolio?  // 使用新的錦標賽投資組合
    let performance: TournamentPerformanceMetrics?  // 使用錦標賽專用績效指標
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
    }
    
    // MARK: - 公共方法
    
    /// 加入錦標賽
    func joinTournament(_ tournament: Tournament) async {
        guard !isJoining else { return }
        
        isJoining = true
        joinError = nil
        
        do {
            print("🏆 [TournamentStateManager] 開始加入錦標賽: \(tournament.name)")
            
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
                
                print("✅ [TournamentStateManager] 成功加入錦標賽: \(tournament.name)")
            } else {
                joinError = "加入錦標賽失敗"
                print("❌ [TournamentStateManager] 加入錦標賽失敗")
            }
            
        } catch {
            print("❌ [TournamentStateManager] 加入錦標賽失敗: \(error.localizedDescription)")
            joinError = "加入錦標賽失敗：\(error.localizedDescription)"
        }
        
        isJoining = false
    }
    
    /// 離開錦標賽（僅切換到一般模式，不退出錦標賽）
    func leaveTournament() async {
        print("🏆 [TournamentStateManager] 切換到一般模式")
        
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
        }
        
        // 持久化狀態（保留已報名的錦標賽）
        persistTournamentState()
        
        print("✅ [TournamentStateManager] 已切換到一般模式")
    }
    
    /// 完全退出錦標賽（真正離開）
    func exitTournament(_ tournamentId: UUID) async {
        do {
            print("🏆 [TournamentStateManager] 開始退出錦標賽")
            
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
                
                print("✅ [TournamentStateManager] 成功退出錦標賽")
            } else {
                print("❌ [TournamentStateManager] 退出錦標賽失敗")
            }
            
        } catch {
            print("❌ [TournamentStateManager] 退出錦標賽失敗: \(error.localizedDescription)")
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
            print("📊 [TournamentStateManager] 投資組合已更新，總價值: \(portfolio.totalPortfolioValue)")
        }
    }
    
    /// 更新績效指標
    func updatePerformance(_ performance: TournamentPerformanceMetrics?) {
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
            print("📈 [TournamentStateManager] 績效指標已更新，總回報: \(performance.totalReturnPercentage)%")
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
        
        print("🏅 [TournamentStateManager] 排名已更新: #\(rank)")
    }
    
    /// 獲取當前錦標賽名稱（用於UI顯示）
    func getCurrentTournamentDisplayName() -> String? {
        return currentTournamentContext?.displayTitle
    }
    
    /// 檢查是否可以進行交易
    func canMakeTrades() -> Bool {
        return currentTournamentContext?.canMakeTrades ?? false
    }
    
    /// 獲取當前錦標賽 ID
    func getCurrentTournamentId() -> UUID? {
        return currentTournamentContext?.tournament.id
    }
    
    /// 檢查是否已報名特定錦標賽
    func isEnrolledInTournament(_ tournamentId: UUID) -> Bool {
        return enrolledTournaments.contains(tournamentId)
    }
    
    /// 檢查是否已報名特定錦標賽（使用 Tournament 對象）
    func isEnrolledInTournament(_ tournament: Tournament) -> Bool {
        return enrolledTournaments.contains(tournament.id)
    }
    
    /// 更新錦標賽上下文（切換錦標賽時使用）
    func updateTournamentContext(_ tournament: Tournament) async {
        print("🔄 [TournamentStateManager] 切換到錦標賽: \(tournament.name)")
        
        // 創建參與者資料
        let participant = createParticipantForTournament(tournament)
        
        // 獲取錦標賽專用投資組合
        let portfolio = portfolioManager.getPortfolio(for: tournament.id)
        
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
            currentTournamentContext = context
            isParticipatingInTournament = true
            participationState = .active
            isJoining = false
            enrolledTournaments.insert(tournament.id)
            
            // 發送錦標賽切換通知
            NotificationCenter.default.post(
                name: NSNotification.Name("TournamentContextChanged"),
                object: self,
                userInfo: [
                    "tournamentId": tournament.id.uuidString,
                    "tournamentName": tournament.name
                ]
            )
        }
        
        // 持久化狀態
        persistTournamentState()
        
        print("✅ [TournamentStateManager] 已切換到錦標賽: \(tournament.name)")
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
    
    private func handleTournamentUpdates(_ tournaments: [Tournament]) {
        guard let currentContext = currentTournamentContext else { return }
        
        // 檢查當前參與的錦標賽是否有更新
        if let updatedTournament = tournaments.first(where: { $0.id == currentContext.tournament.id }) {
            // 更新錦標賽資訊
            let updatedContext = TournamentContext(
                tournament: updatedTournament,
                participant: currentContext.participant,
                state: determineParticipationState(for: updatedTournament),
                portfolio: currentContext.portfolio,
                performance: currentContext.performance,
                currentRank: currentContext.currentRank,
                joinedAt: currentContext.joinedAt
            )
            
            currentTournamentContext = updatedContext
            participationState = updatedContext.state
        }
    }
    
    private func determineParticipationState(for tournament: Tournament) -> TournamentParticipationState {
        switch tournament.status {
        case .upcoming, .enrolling:
            return .joining
        case .ongoing:
            return .active
        case .finished:
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
                tournament: updatedTournament,
                participant: updatedParticipant,
                state: context.state,
                portfolio: updatedPortfolio,
                performance: updatedPortfolio?.performanceMetrics,
                currentRank: updatedParticipant?.currentRank,
                joinedAt: context.joinedAt
            )
            
            currentTournamentContext = updatedContext
            
            print("🔄 [TournamentStateManager] 錦標賽上下文已刷新")
            
        } catch {
            print("❌ [TournamentStateManager] 刷新錦標賽上下文失敗: \(error)")
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
            
            print("💾 [TournamentStateManager] 錦標賽狀態已持久化")
        } catch {
            print("❌ [TournamentStateManager] 持久化錦標賽狀態失敗: \(error.localizedDescription)")
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
            
            print("💾 [TournamentStateManager] 已載入持久化的錦標賽狀態: \(persistentData.tournamentName)")
            
            // TODO: 在實際應用中，這裡應該重新獲取完整的錦標賽資料
            
        } catch {
            print("❌ [TournamentStateManager] 載入持久化錦標賽狀態失敗: \(error.localizedDescription)")
            clearPersistedTournamentState()
        }
    }
    
    private func clearPersistedTournamentState() {
        UserDefaults.standard.removeObject(forKey: "CurrentTournamentContext")
        print("🗑️ [TournamentStateManager] 已清除持久化的錦標賽狀態")
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