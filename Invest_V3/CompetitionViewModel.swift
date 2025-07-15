import Foundation
import SwiftUI

@MainActor
class CompetitionViewModel: ObservableObject {
    @Published var activeCompetitions: [Competition] = []
    @Published var userCompetitions: [Competition] = []
    @Published var competitionRankings: [CompetitionRanking] = []
    @Published var selectedCompetition: Competition?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingJoinAlert = false
    @Published var showingLeaveAlert = false
    @Published var userParticipationStatus: [UUID: Bool] = [:]
    
    private let competitionService = CompetitionService.shared
    private let authService = AuthenticationService.shared
    
    init() {
        Task {
            await loadActiveCompetitions()
            await loadUserCompetitions()
        }
    }
    
    // MARK: - 數據載入
    
    func loadActiveCompetitions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await competitionService.fetchActiveCompetitions()
            self.activeCompetitions = competitionService.activeCompetitions
            
            // 檢查用戶參與狀態
            if let userId = authService.currentUser?.id {
                await checkUserParticipationStatus(userId: userId)
            }
        } catch {
            errorMessage = "載入競賽失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadUserCompetitions() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await competitionService.fetchUserCompetitions(userId: userId)
            self.userCompetitions = competitionService.userCompetitions
        } catch {
            errorMessage = "載入用戶競賽失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadCompetitionRankings(competitionId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let rankings = try await competitionService.fetchCompetitionRankings(competitionId: competitionId)
            self.competitionRankings = rankings
        } catch {
            errorMessage = "載入排名失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - 競賽操作
    
    func joinCompetition(_ competition: Competition) async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "請先登入"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await competitionService.joinCompetition(competitionId: competition.id, userId: userId)
            userParticipationStatus[competition.id] = true
            await loadUserCompetitions()
            showingJoinAlert = false
        } catch {
            errorMessage = "參加競賽失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func leaveCompetition(_ competition: Competition) async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "請先登入"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await competitionService.leaveCompetition(competitionId: competition.id, userId: userId)
            userParticipationStatus[competition.id] = false
            await loadUserCompetitions()
            showingLeaveAlert = false
        } catch {
            errorMessage = "離開競賽失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshCompetitionData() async {
        await loadActiveCompetitions()
        await loadUserCompetitions()
        
        if let selectedCompetition = selectedCompetition {
            await loadCompetitionRankings(competitionId: selectedCompetition.id)
        }
    }
    
    // MARK: - 輔助方法
    
    func isUserParticipating(in competition: Competition) -> Bool {
        return userParticipationStatus[competition.id] ?? false
    }
    
    func getUserRank(in competition: Competition) -> Int? {
        guard let userId = authService.currentUser?.id else { return nil }
        return competitionRankings.first { $0.userId == userId && $0.competitionId == competition.id }?.rank
    }
    
    func getUserReturnRate(in competition: Competition) -> Double? {
        guard let userId = authService.currentUser?.id else { return nil }
        return competitionRankings.first { $0.userId == userId && $0.competitionId == competition.id }?.returnRate
    }
    
    private func checkUserParticipationStatus(userId: UUID) async {
        for competition in activeCompetitions {
            do {
                let isParticipating = try await competitionService.isUserParticipating(competitionId: competition.id, userId: userId)
                userParticipationStatus[competition.id] = isParticipating
            } catch {
                // 忽略單個競賽的檢查錯誤
                continue
            }
        }
    }
    
    // MARK: - 格式化方法
    
    func formatPrizePool(_ amount: Double?) -> String {
        guard let amount = amount else { return "無獎金" }
        return String(format: "NT$ %.0f", amount)
    }
    
    func formatDuration(_ competition: Competition) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return "\(formatter.string(from: competition.startDate)) - \(formatter.string(from: competition.endDate))"
    }
    
    func formatTimeRemaining(_ competition: Competition) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if competition.isUpcoming {
            let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: competition.startDate)
            if let days = components.day, days > 0 {
                return "\(days) 天後開始"
            } else if let hours = components.hour, hours > 0 {
                return "\(hours) 小時後開始"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes) 分鐘後開始"
            } else {
                return "即將開始"
            }
        } else if competition.isActive {
            let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: competition.endDate)
            if let days = components.day, days > 0 {
                return "\(days) 天後結束"
            } else if let hours = components.hour, hours > 0 {
                return "\(hours) 小時後結束"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes) 分鐘後結束"
            } else {
                return "即將結束"
            }
        } else {
            return "已結束"
        }
    }
    
    func getStatusText(_ competition: Competition) -> String {
        if competition.isActive {
            return "進行中"
        } else if competition.isUpcoming {
            return "即將開始"
        } else {
            return "已結束"
        }
    }
    
    func getStatusColor(_ competition: Competition) -> Color {
        if competition.isActive {
            return .green
        } else if competition.isUpcoming {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - 競賽類型枚舉
enum CompetitionType: String, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case special = "special"
    
    var displayName: String {
        switch self {
        case .weekly:
            return "週賽"
        case .monthly:
            return "月賽"
        case .special:
            return "特別賽"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .weekly:
            return 7 * 24 * 60 * 60 // 7 天
        case .monthly:
            return 30 * 24 * 60 * 60 // 30 天
        case .special:
            return 14 * 24 * 60 * 60 // 14 天
        }
    }
}

// MARK: - 競賽狀態枚舉
enum CompetitionStatus: String, CaseIterable {
    case upcoming = "upcoming"
    case active = "active"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .upcoming:
            return "即將開始"
        case .active:
            return "進行中"
        case .completed:
            return "已結束"
        }
    }
    
    var color: Color {
        switch self {
        case .upcoming:
            return .orange
        case .active:
            return .green
        case .completed:
            return .gray
        }
    }
}