//
//  TournamentService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//

import Foundation
import Combine

// MARK: - API Response Models
struct TournamentResponse: Codable {
    let id: String
    let name: String
    let description: String
    let type: String
    let status: String
    let startDate: String
    let endDate: String
    let initialBalance: Double
    let prizePool: Double
    let currentParticipants: Int
    let maxParticipants: Int
    let createdAt: String
    let updatedAt: String
}

struct TournamentParticipantResponse: Codable {
    let id: String
    let tournamentId: String
    let userId: String
    let userName: String
    let currentRank: Int
    let previousRank: Int?
    let virtualBalance: Double
    let returnRate: Double
    let winRate: Double
    let totalTrades: Int
    let profitableTrades: Int
    let performanceLevel: String
    let joinedAt: String
    let lastActive: String
}

struct TournamentActivityResponse: Codable {
    let id: String
    let tournamentId: String
    let userId: String
    let userName: String
    let activityType: String
    let description: String
    let amount: Double?
    let symbol: String?
    let timestamp: String
}

struct PersonalPerformanceResponse: Codable {
    let userId: String
    let totalReturn: Double
    let annualizedReturn: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let winRate: Double
    let totalTrades: Int
    let profitableTrades: Int
    let avgHoldingDays: Double
    let riskScore: Double
    let achievements: [AchievementResponse]
    let rankingHistory: [RankingPointResponse]
}

struct AchievementResponse: Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rarity: String
    let isUnlocked: Bool
    let progress: Double
    let unlockedAt: String?
}

struct RankingPointResponse: Codable {
    let id: String
    let date: String
    let rank: Int
    let totalParticipants: Int
    let percentile: Double
}

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
    private let baseURL = "https://api.invest-v3.com/v1"
    private let session = URLSession.shared
    private let dateFormatter = ISO8601DateFormatter()
    
    // Published properties for UI binding
    @Published var tournaments: [Tournament] = []
    @Published var isLoading = false
    @Published var error: TournamentAPIError?
    
    private init() {
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    // MARK: - Public API Methods
    
    /// 獲取所有錦標賽列表
    func fetchTournaments() async throws -> [Tournament] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = URL(string: "\(baseURL)/tournaments")!
            let (data, response) = try await session.data(from: url)
            
            try validateResponse(response)
            let tournamentResponses = try JSONDecoder().decode([TournamentResponse].self, from: data)
            let tournaments = tournamentResponses.compactMap { convertToTournament($0) }
            
            self.tournaments = tournaments
            return tournaments
        } catch {
            let apiError = handleError(error)
            self.error = apiError
            throw apiError
        }
    }
    
    /// 獲取特定錦標賽詳情
    func fetchTournament(id: UUID) async throws -> Tournament {
        let url = URL(string: "\(baseURL)/tournaments/\(id.uuidString)")!
        let (data, response) = try await session.data(from: url)
        
        try validateResponse(response)
        let tournamentResponse = try JSONDecoder().decode(TournamentResponse.self, from: data)
        
        guard let tournament = convertToTournament(tournamentResponse) else {
            throw TournamentAPIError.decodingError(NSError(domain: "TournamentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法轉換錦標賽數據"]))
        }
        
        return tournament
    }
    
    /// 獲取錦標賽參與者列表
    func fetchTournamentParticipants(tournamentId: UUID) async throws -> [TournamentParticipant] {
        let url = URL(string: "\(baseURL)/tournaments/\(tournamentId.uuidString)/participants")!
        let (data, response) = try await session.data(from: url)
        
        try validateResponse(response)
        let participantResponses = try JSONDecoder().decode([TournamentParticipantResponse].self, from: data)
        return participantResponses.compactMap { convertToParticipant($0) }
    }
    
    /// 獲取錦標賽活動列表
    func fetchTournamentActivities(tournamentId: UUID) async throws -> [TournamentActivity] {
        let url = URL(string: "\(baseURL)/tournaments/\(tournamentId.uuidString)/activities")!
        let (data, response) = try await session.data(from: url)
        
        try validateResponse(response)
        let activityResponses = try JSONDecoder().decode([TournamentActivityResponse].self, from: data)
        return activityResponses.compactMap { convertToActivity($0) }
    }
    
    /// 加入錦標賽
    func joinTournament(tournamentId: UUID) async throws -> Bool {
        let url = URL(string: "\(baseURL)/tournaments/\(tournamentId.uuidString)/join")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
        return true
    }
    
    /// 離開錦標賽
    func leaveTournament(tournamentId: UUID) async throws -> Bool {
        let url = URL(string: "\(baseURL)/tournaments/\(tournamentId.uuidString)/leave")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
        return true
    }
    
    /// 獲取個人績效數據
    func fetchPersonalPerformance(userId: UUID) async throws -> PersonalPerformance {
        let url = URL(string: "\(baseURL)/users/\(userId.uuidString)/performance")!
        let (data, response) = try await session.data(from: url)
        
        try validateResponse(response)
        let performanceResponse = try JSONDecoder().decode(PersonalPerformanceResponse.self, from: data)
        
        guard let performance = convertToPersonalPerformance(performanceResponse) else {
            throw TournamentAPIError.decodingError(NSError(domain: "TournamentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法轉換績效數據"]))
        }
        
        return performance
    }
    
    /// 刷新錦標賽數據
    func refreshTournamentData(tournamentId: UUID) async throws -> Tournament {
        return try await fetchTournament(id: tournamentId)
    }
    
    // MARK: - Private Helper Methods
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TournamentAPIError.unknown
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw TournamentAPIError.unauthorized
        case 400...499, 500...599:
            throw TournamentAPIError.serverError(httpResponse.statusCode)
        default:
            throw TournamentAPIError.unknown
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
    
    // MARK: - Data Conversion Methods
    
    private func convertToTournament(_ response: TournamentResponse) -> Tournament? {
        guard let tournamentId = UUID(uuidString: response.id),
              let type = TournamentType(rawValue: response.type),
              let status = TournamentStatus(rawValue: response.status),
              let startDate = dateFormatter.date(from: response.startDate),
              let endDate = dateFormatter.date(from: response.endDate),
              let createdAt = dateFormatter.date(from: response.createdAt),
              let updatedAt = dateFormatter.date(from: response.updatedAt) else {
            return nil
        }
        
        return Tournament(
            id: tournamentId,
            name: response.name,
            type: type,
            status: status,
            startDate: startDate,
            endDate: endDate,
            description: response.description,
            initialBalance: response.initialBalance,
            maxParticipants: response.maxParticipants,
            currentParticipants: response.currentParticipants,
            entryFee: 0.0, // 預設值，API 回應中暫無此欄位
            prizePool: response.prizePool,
            riskLimitPercentage: 0.1, // 預設值，API 回應中暫無此欄位
            minHoldingRate: 0.0, // 預設值，API 回應中暫無此欄位
            maxSingleStockRate: 0.3, // 預設值，API 回應中暫無此欄位
            rules: [], // 預設值，API 回應中暫無此欄位
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func convertToParticipant(_ response: TournamentParticipantResponse) -> TournamentParticipant? {
        guard let participantId = UUID(uuidString: response.id),
              let tournamentId = UUID(uuidString: response.tournamentId),
              let userId = UUID(uuidString: response.userId),
              let joinedAt = dateFormatter.date(from: response.joinedAt),
              let lastUpdated = dateFormatter.date(from: response.lastActive) else {
            return nil
        }
        
        return TournamentParticipant(
            id: participantId,
            tournamentId: tournamentId,
            userId: userId,
            userName: response.userName,
            userAvatar: nil, // API 回應中暫無此欄位
            currentRank: response.currentRank,
            previousRank: response.previousRank ?? response.currentRank,
            virtualBalance: response.virtualBalance,
            initialBalance: 100000.0, // 預設值，API 回應中暫無此欄位
            returnRate: response.returnRate,
            totalTrades: response.totalTrades,
            winRate: response.winRate,
            maxDrawdown: 0.0, // 預設值，API 回應中暫無此欄位
            sharpeRatio: nil, // 預設值，API 回應中暫無此欄位
            isEliminated: false, // 預設值，API 回應中暫無此欄位
            eliminationReason: nil, // 預設值，API 回應中暫無此欄位
            joinedAt: joinedAt,
            lastUpdated: lastUpdated
        )
    }
    
    private func convertToActivity(_ response: TournamentActivityResponse) -> TournamentActivity? {
        guard let activityId = UUID(uuidString: response.id),
              let tournamentId = UUID(uuidString: response.tournamentId),
              let userId = UUID(uuidString: response.userId),
              let activityType = TournamentActivity.ActivityType(rawValue: response.activityType),
              let timestamp = dateFormatter.date(from: response.timestamp) else {
            return nil
        }
        
        return TournamentActivity(
            id: activityId,
            tournamentId: tournamentId,
            userId: userId,
            userName: response.userName,
            activityType: activityType,
            description: response.description,
            amount: response.amount,
            symbol: response.symbol,
            timestamp: timestamp
        )
    }
    
    private func convertToPersonalPerformance(_ response: PersonalPerformanceResponse) -> PersonalPerformance? {
        guard let userId = UUID(uuidString: response.userId) else {
            return nil
        }
        
        let achievements = response.achievements.compactMap { convertToAchievement($0) }
        let rankingHistory = response.rankingHistory.compactMap { convertToRankingPoint($0) }
        
        return PersonalPerformance(
            userId: userId,
            totalReturn: response.totalReturn,
            annualizedReturn: response.annualizedReturn,
            maxDrawdown: response.maxDrawdown,
            sharpeRatio: response.sharpeRatio,
            winRate: response.winRate,
            totalTrades: response.totalTrades,
            profitableTrades: response.profitableTrades,
            avgHoldingDays: response.avgHoldingDays,
            riskScore: response.riskScore,
            achievements: achievements,
            performanceHistory: [], // 預設值，API 回應中暫無此欄位
            rankingHistory: rankingHistory
        )
    }
    
    private func convertToAchievement(_ response: AchievementResponse) -> Achievement? {
        guard let achievementId = UUID(uuidString: response.id),
              let rarity = Achievement.AchievementRarity(rawValue: response.rarity) else {
            return nil
        }
        
        let unlockedAt = response.unlockedAt != nil ? dateFormatter.date(from: response.unlockedAt!) : nil
        
        return Achievement(
            id: achievementId,
            name: response.name,
            description: response.description,
            icon: response.icon,
            rarity: rarity,
            isUnlocked: response.isUnlocked,
            progress: response.progress,
            earnedAt: unlockedAt
        )
    }
    
    private func convertToRankingPoint(_ response: RankingPointResponse) -> RankingPoint? {
        guard let date = dateFormatter.date(from: response.date) else {
            return nil
        }
        
        return RankingPoint(
            date: date,
            rank: response.rank,
            totalParticipants: response.totalParticipants,
            percentile: response.percentile
        )
    }
}

// MARK: - Mock Service for Development
class MockTournamentService: TournamentServiceProtocol {
    static let shared = MockTournamentService()
    
    private init() {}
    
    func fetchTournaments() async throws -> [Tournament] {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return Tournament.sampleData
    }
    
    func fetchTournament(id: UUID) async throws -> Tournament {
        try await Task.sleep(nanoseconds: 500_000_000)
        return Tournament.sampleData.first { $0.id == id } ?? Tournament.sampleData[0]
    }
    
    func fetchTournamentParticipants(tournamentId: UUID) async throws -> [TournamentParticipant] {
        try await Task.sleep(nanoseconds: 800_000_000)
        return TournamentParticipant.sampleData
    }
    
    func fetchTournamentActivities(tournamentId: UUID) async throws -> [TournamentActivity] {
        try await Task.sleep(nanoseconds: 600_000_000)
        return [] // 返回空數組，讓UI顯示空狀態
    }
    
    func joinTournament(tournamentId: UUID) async throws -> Bool {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        return true
    }
    
    func leaveTournament(tournamentId: UUID) async throws -> Bool {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
    
    func fetchPersonalPerformance(userId: UUID) async throws -> PersonalPerformance {
        try await Task.sleep(nanoseconds: 1_200_000_000)
        return MockPortfolioData.samplePerformance
    }
    
    func refreshTournamentData(tournamentId: UUID) async throws -> Tournament {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return try await fetchTournament(id: tournamentId)
    }
}