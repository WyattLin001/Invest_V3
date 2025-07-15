import Foundation
import Supabase
import SwiftUI

@MainActor
class CompetitionService: ObservableObject {
    static let shared = CompetitionService()
    
    private var supabaseClient: SupabaseClient? {
        SupabaseManager.shared.client
    }
    private let portfolioService = PortfolioService.shared
    private let stockService = StockService.shared
    
    @Published var activeCompetitions: [Competition] = []
    @Published var userCompetitions: [Competition] = []
    @Published var competitionRankings: [CompetitionRanking] = []
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - 競賽管理
    
    /// 獲取所有進行中的競賽
    func fetchActiveCompetitions() async throws {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let competitions: [Competition] = try await client
            .from("competitions")
            .select()
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        self.activeCompetitions = competitions
    }
    
    /// 獲取用戶參與的競賽
    func fetchUserCompetitions(userId: UUID) async throws {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let participations: [CompetitionParticipation] = try await client
            .from("competition_participations")
            .select("""
                competition_id,
                competitions(*)
            """)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        self.userCompetitions = participations.compactMap { $0.competition }
    }
    
    /// 參加競賽
    func joinCompetition(competitionId: UUID, userId: UUID) async throws {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        // 檢查是否已經參加
        let existingParticipation: [CompetitionParticipation] = try await client
            .from("competition_participations")
            .select()
            .eq("competition_id", value: competitionId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        guard existingParticipation.isEmpty else {
            throw CompetitionServiceError.alreadyParticipating
        }
        
        // 創建競賽參與記錄
        let participation = CompetitionParticipation(
            id: UUID(),
            competitionId: competitionId,
            userId: userId,
            joinedAt: Date(),
            initialCash: 1_000_000, // 100萬虛擬資金
            currentValue: 1_000_000,
            returnRate: 0.0,
            rank: 0
        )
        
        try await client
            .from("competition_participations")
            .insert(participation)
            .execute()
        
        // 為用戶創建競賽專用投資組合
        let portfolio = Portfolio(
            id: UUID(),
            userId: userId,
            groupId: competitionId, // 使用競賽ID作為群組ID
            initialCash: 1_000_000,
            availableCash: 1_000_000,
            totalValue: 1_000_000,
            returnRate: 0.0,
            lastUpdated: Date()
        )
        
        try await client
            .from("user_portfolios")
            .insert(portfolio)
            .execute()
    }
    
    /// 離開競賽
    func leaveCompetition(competitionId: UUID, userId: UUID) async throws {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        // 刪除參與記錄
        try await client
            .from("competition_participations")
            .delete()
            .eq("competition_id", value: competitionId)
            .eq("user_id", value: userId)
            .execute()
        
        // 刪除競賽相關投資組合
        try await client
            .from("user_portfolios")
            .delete()
            .eq("user_id", value: userId)
            .eq("group_id", value: competitionId)
            .execute()
    }
    
    /// 獲取競賽排名
    func fetchCompetitionRankings(competitionId: UUID) async throws -> [CompetitionRanking] {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        let participations: [CompetitionParticipation] = try await client
            .from("competition_participations")
            .select("""
                *,
                user_profiles(username, avatar_url)
            """)
            .eq("competition_id", value: competitionId)
            .order("return_rate", ascending: false)
            .execute()
            .value
        
        var rankings: [CompetitionRanking] = []
        for (index, participation) in participations.enumerated() {
            let ranking = CompetitionRanking(
                id: UUID(),
                competitionId: competitionId,
                userId: participation.userId,
                username: participation.userProfile?.username ?? "Unknown",
                avatarUrl: participation.userProfile?.avatarUrl,
                rank: index + 1,
                returnRate: participation.returnRate,
                totalValue: participation.currentValue,
                lastUpdated: Date()
            )
            rankings.append(ranking)
        }
        
        self.competitionRankings = rankings
        return rankings
    }
    
    /// 更新競賽參與者的收益率
    func updateParticipantReturn(competitionId: UUID, userId: UUID) async throws {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        // 計算最新的投資組合收益率
        let returnRate = try await portfolioService.calculatePortfolioReturn(userId: userId)
        
        // 獲取投資組合總價值
        let portfolio = try await portfolioService.fetchUserPortfolio(userId: userId)
        let totalValue = portfolio.totalValue
        
        // 更新參與記錄
        let updatePayload = ParticipationUpdatePayload(
            current_value: totalValue,
            return_rate: returnRate,
            last_updated: Date().iso8601String
        )
        
        try await client
            .from("competition_participations")
            .update(updatePayload)
            .eq("competition_id", value: competitionId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    /// 創建新競賽（管理員功能）
    func createCompetition(
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        prizePool: Double? = nil
    ) async throws -> Competition {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        let competition = Competition(
            id: UUID(),
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            status: "active",
            prizePool: prizePool,
            participantCount: 0,
            createdAt: Date()
        )
        
        try await client
            .from("competitions")
            .insert(competition)
            .execute()
        
        return competition
    }
    
    /// 獲取競賽詳情
    func fetchCompetitionDetail(competitionId: UUID) async throws -> Competition {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        let competitions: [Competition] = try await client
            .from("competitions")
            .select()
            .eq("id", value: competitionId)
            .execute()
            .value
        
        guard let competition = competitions.first else {
            throw CompetitionServiceError.competitionNotFound
        }
        
        return competition
    }
    
    /// 檢查用戶是否已參加競賽
    func isUserParticipating(competitionId: UUID, userId: UUID) async throws -> Bool {
        guard let client = supabaseClient else {
            throw CompetitionServiceError.clientNotInitialized
        }
        
        let participations: [CompetitionParticipation] = try await client
            .from("competition_participations")
            .select()
            .eq("competition_id", value: competitionId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return !participations.isEmpty
    }
    
    /// 獲取用戶在競賽中的排名
    func getUserRankInCompetition(competitionId: UUID, userId: UUID) async throws -> Int? {
        let rankings = try await fetchCompetitionRankings(competitionId: competitionId)
        return rankings.first { $0.userId == userId }?.rank
    }
    
    /// 定期更新所有競賽排名（背景任務）
    func updateAllCompetitionRankings() async throws {
        for competition in activeCompetitions {
            _ = try await fetchCompetitionRankings(competitionId: competition.id)
        }
    }
}

// MARK: - 錯誤類型
enum CompetitionServiceError: Error, LocalizedError {
    case clientNotInitialized
    case competitionNotFound
    case alreadyParticipating
    case competitionClosed
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "Supabase 客戶端未初始化"
        case .competitionNotFound:
            return "找不到競賽"
        case .alreadyParticipating:
            return "已經參加此競賽"
        case .competitionClosed:
            return "競賽已結束"
        case .insufficientPermissions:
            return "權限不足"
        }
    }
}

// MARK: - 競賽模型
struct Competition: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let startDate: Date
    let endDate: Date
    let status: String // "active", "completed", "upcoming"
    let prizePool: Double?
    let participantCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case status
        case prizePool = "prize_pool"
        case participantCount = "participant_count"
        case createdAt = "created_at"
    }
    
    var isActive: Bool {
        let now = Date()
        return status == "active" && now >= startDate && now <= endDate
    }
    
    var isUpcoming: Bool {
        return status == "upcoming" || Date() < startDate
    }
    
    var isCompleted: Bool {
        return status == "completed" || Date() > endDate
    }
    
    var durationText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var statusColor: Color {
        switch status {
        case "active":
            return .green
        case "upcoming":
            return .orange
        case "completed":
            return .gray
        default:
            return .gray
        }
    }
}

struct CompetitionParticipation: Identifiable, Codable {
    let id: UUID
    let competitionId: UUID
    let userId: UUID
    let joinedAt: Date
    let initialCash: Double
    let currentValue: Double
    let returnRate: Double
    let rank: Int
    
    // 關聯資料
    var competition: Competition?
    var userProfile: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case competitionId = "competition_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case initialCash = "initial_cash"
        case currentValue = "current_value"
        case returnRate = "return_rate"
        case rank
        case competition = "competitions"
        case userProfile = "user_profiles"
    }
}

struct CompetitionRanking: Identifiable, Codable {
    let id: UUID
    let competitionId: UUID
    let userId: UUID
    let username: String
    let avatarUrl: String?
    let rank: Int
    let returnRate: Double
    let totalValue: Double
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case competitionId = "competition_id"
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case rank
        case returnRate = "return_rate"
        case totalValue = "total_value"
        case lastUpdated = "last_updated"
    }
    
    var returnRateFormatted: String {
        return String(format: "%.2f%%", returnRate)
    }
    
    var totalValueFormatted: String {
        return String(format: "%.0f", totalValue)
    }
    
    var returnRateColor: Color {
        if returnRate > 0 {
            return .green
        } else if returnRate < 0 {
            return .red
        } else {
            return .gray
        }
    }
    
    var rankColor: Color {
        switch rank {
        case 1:
            return .yellow // 金牌
        case 2:
            return .gray // 銀牌
        case 3:
            return Color.orange // 銅牌
        default:
            return .primary
        }
    }
    
    var rankIcon: String {
        switch rank {
        case 1:
            return "🥇"
        case 2:
            return "🥈"
        case 3:
            return "🥉"
        default:
            return "\(rank)"
        }
    }
}

// MARK: - 更新資料模型
struct ParticipationUpdatePayload: Codable {
    let current_value: Double
    let return_rate: Double
    let last_updated: String
}