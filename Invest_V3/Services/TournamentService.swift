//
//  TournamentService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//

import Foundation
import Combine

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
    func fetchTournament(id: UUID) async throws -> Tournament
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
    static let shared = TournamentService()
    
    // MARK: - Properties
    private let supabaseService = SupabaseService.shared
    
    // Published properties for UI binding
    @Published var tournaments: [Tournament] = []
    @Published var isLoading = false
    @Published var error: TournamentAPIError?
    @Published var realtimeConnected = false
    
    // 即時更新相關屬性
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30.0 // 30秒刷新一次
    
    private init() {
        // 初始化時載入錦標賽數據
        Task {
            await loadTournaments()
            await startRealtimeUpdates()
        }
    }
    
    // MARK: - Public API Methods
    
    /// 獲取所有錦標賽列表
    func fetchTournaments() async throws -> [Tournament] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let tournaments = try await supabaseService.fetchTournaments()
            
            await MainActor.run {
                self.tournaments = tournaments
                self.error = nil
            }
            
            print("✅ [TournamentService] 成功獲取 \(tournaments.count) 個錦標賽")
            return tournaments
        } catch {
            let apiError = handleError(error)
            await MainActor.run {
                self.error = apiError
            }
            print("❌ [TournamentService] 獲取錦標賽失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 獲取特定錦標賽詳情
    func fetchTournament(id: UUID) async throws -> Tournament {
        do {
            let tournament = try await supabaseService.fetchTournament(id: id)
            print("✅ [TournamentService] 成功獲取錦標賽詳情: \(tournament.name)")
            return tournament
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取錦標賽詳情失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 獲取錦標賽參與者列表
    func fetchTournamentParticipants(tournamentId: UUID) async throws -> [TournamentParticipant] {
        do {
            let participants = try await supabaseService.fetchTournamentParticipants(tournamentId: tournamentId)
            print("✅ [TournamentService] 成功獲取 \(participants.count) 個參與者")
            return participants
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取錦標賽參與者失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 獲取錦標賽活動列表
    func fetchTournamentActivities(tournamentId: UUID) async throws -> [TournamentActivity] {
        do {
            let activities = try await supabaseService.fetchTournamentActivities(tournamentId: tournamentId)
            print("✅ [TournamentService] 成功獲取 \(activities.count) 個活動記錄")
            return activities
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取錦標賽活動失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 加入錦標賽
    func joinTournament(tournamentId: UUID) async throws -> Bool {
        do {
            let success = try await supabaseService.joinTournament(tournamentId: tournamentId)
            print("✅ [TournamentService] 成功加入錦標賽")
            
            // 重新載入錦標賽數據以更新參與者數量
            await loadTournaments()
            
            return success
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 加入錦標賽失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 離開錦標賽
    func leaveTournament(tournamentId: UUID) async throws -> Bool {
        do {
            let success = try await supabaseService.leaveTournament(tournamentId: tournamentId)
            print("✅ [TournamentService] 成功離開錦標賽")
            
            // 重新載入錦標賽數據以更新參與者數量
            await loadTournaments()
            
            return success
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 離開錦標賽失敗: \(error.localizedDescription)")
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
            print("✅ [TournamentService] 成功獲取個人績效數據")
            return performance
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取個人績效數據失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 刷新錦標賽數據
    func refreshTournamentData(tournamentId: UUID) async throws -> Tournament {
        return try await fetchTournament(id: tournamentId)
    }
    
    // MARK: - Private Helper Methods
    
    /// 載入錦標賽數據的內部方法
    private func loadTournaments() async {
        do {
            let tournaments = try await supabaseService.fetchTournaments()
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
    
    /// 獲取精選錦標賽
    func fetchFeaturedTournaments() async throws -> [Tournament] {
        do {
            let tournaments = try await supabaseService.fetchFeaturedTournaments()
            print("✅ [TournamentService] 成功獲取 \(tournaments.count) 個精選錦標賽")
            return tournaments
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取精選錦標賽失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 根據類型獲取錦標賽
    func fetchTournaments(type: TournamentType) async throws -> [Tournament] {
        do {
            let tournaments = try await supabaseService.fetchTournaments(type: type)
            print("✅ [TournamentService] 成功獲取 \(tournaments.count) 個 \(type.displayName) 錦標賽")
            return tournaments
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取錦標賽類型失敗: \(error.localizedDescription)")
            throw apiError
        }
    }
    
    /// 根據狀態獲取錦標賽
    func fetchTournaments(status: TournamentStatus) async throws -> [Tournament] {
        do {
            let tournaments = try await supabaseService.fetchTournaments(status: status)
            print("✅ [TournamentService] 成功獲取 \(tournaments.count) 個 \(status.displayName) 錦標賽")
            return tournaments
        } catch {
            let apiError = handleError(error)
            print("❌ [TournamentService] 獲取錦標賽狀態失敗: \(error.localizedDescription)")
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
    
    // MARK: - Realtime Updates
    
    /// 開始即時更新
    private func startRealtimeUpdates() async {
        print("📊 [TournamentService] 開始即時更新")
        
        // 停止現有的計時器
        stopRealtimeUpdates()
        
        // 啟動定期刷新計時器
        await MainActor.run {
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
                Task {
                    await self?.refreshTournamentData()
                }
            }
            self.realtimeConnected = true
        }
        
        print("📊 [TournamentService] 即時更新已啟動，刷新間隔: \(refreshInterval)秒")
    }
    
    /// 停止即時更新
    private func stopRealtimeUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        realtimeConnected = false
        print("📊 [TournamentService] 即時更新已停止")
    }
    
    /// 刷新錦標賽數據
    private func refreshTournamentData() async {
        do {
            let tournaments = try await supabaseService.fetchTournaments()
            await MainActor.run {
                self.tournaments = tournaments
                self.error = nil
            }
            print("📊 [TournamentService] 自動刷新錦標賽數據成功")
        } catch {
            await MainActor.run {
                self.error = handleError(error)
            }
            print("❌ [TournamentService] 自動刷新錦標賽數據失敗: \(error.localizedDescription)")
        }
    }
    
    /// 手動刷新錦標賽數據
    func refreshTournaments() async {
        await refreshTournamentData()
    }
    
    /// 重新連接即時更新
    func reconnectRealtime() async {
        print("📊 [TournamentService] 重新連接即時更新")
        await startRealtimeUpdates()
    }
    
    deinit {
        // 在 deinit 中無法調用 @MainActor 方法，需要直接清理
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("📊 [TournamentService] 服務已釋放，即時更新已停止")
    }
}

