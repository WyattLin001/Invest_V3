import SwiftUI
import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var investmentGroups: [InvestmentGroup] = []
    @Published var joinedIds: Set<UUID> = []
    @Published var tradingRankings: [TradingUserRanking] = []
    @Published var selectedPeriod: RankingPeriod = .all
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // B線邀請功能
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var isProcessingInvitation = false
    
    private let supabaseService = SupabaseService.shared
    
    // 根據選中的時間週期返回對應的排行榜
    var currentRankings: [TradingUserRanking] {
        return tradingRankings
    }
    
    // MARK: - 初始化資料
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 並行載入資料
            async let groupsTask = loadInvestmentGroups()
            async let rankingsTask = loadTradingRankings()
            async let joinedGroupsTask = refreshJoinedGroups()
            async let invitationsTask = loadPendingInvitations()
            
            try await groupsTask
            try await rankingsTask
            try await joinedGroupsTask
            try await invitationsTask
            
        } catch {
            errorMessage = "載入資料失敗: \(error.localizedDescription)"
            print("HomeViewModel loadData error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 載入投資群組
    private func loadInvestmentGroups() async throws {
        // 從 Supabase 載入真實的投資群組資料
        let groups = try await supabaseService.fetchInvestmentGroups()
        self.investmentGroups = groups
        print("✅ 已載入 \(groups.count) 個投資群組")
    }
    
    // MARK: - 載入所有排行榜
    private func loadTradingRankings() async throws {
        do {
            // 從 Supabase 載入真實的投資排行榜資料
            let rankings = try await supabaseService.fetchTradingRankings(
                period: selectedPeriod.apiValue,
                limit: 10
            )
            
            self.tradingRankings = rankings
            print("✅ 成功載入 \(rankings.count) 筆排行榜資料")
            
        } catch {
            // 如果載入失敗，使用模擬資料
            print("⚠️ 載入排行榜失敗，使用模擬資料: \(error)")
            self.tradingRankings = TradingUserRanking.mockRankings()
        }
    }
    
    // MARK: - 切換排行榜週期
    func switchPeriod(to period: RankingPeriod) {
        selectedPeriod = period
        
        // 重新載入排行榜資料
        Task {
            await loadTradingRankings()
        }
    }
    
    
    // MARK: - 加入群組
    func joinGroup(_ groupId: UUID) async {
        do {
            // 先獲取群組資訊以顯示正確的代幣費用
            let group = investmentGroups.first(where: { $0.id == groupId })
            let groupName = group?.name ?? "群組"
            let tokenCost = group?.tokenCost ?? 0
            
            try await SupabaseService.shared.joinGroup(groupId)
            print("✅ Joined group: \(groupId)")
            
            // 重新載入已加入群組列表
            await refreshJoinedGroups()
            
            // 設定成功訊息
            await MainActor.run {
                self.successMessage = "成功加入\(groupName)！已扣除 \(tokenCost) 代幣"
            }
            
            // 發送通知切換到聊天 Tab 並直接進入該群組
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchToChatTab"), 
                object: groupId
            )
            
        } catch {
            let errorMsg: String
            if let supabaseError = error as? SupabaseError {
                errorMsg = supabaseError.localizedDescription
            } else {
                errorMsg = "加入群組失敗: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                self.errorMessage = errorMsg
            }
            print("❌ Join failed: \(error)")
        }
    }
    
    // MARK: - 清理假資料和載入真實數據
    func initializeTestData() async {
        do {
            // 清理所有假資料群組
            try await SupabaseService.shared.clearAllDummyGroups()
            
            // 清空聊天內容
            try await SupabaseService.shared.clearAllChatMessages()
            
            // 重新載入群組數據
            await loadData()
            
            await MainActor.run {
                self.successMessage = "資料清理完成！現在可以創建真實群組"
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "資料清理失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 刷新已加入群組
    func refreshJoinedGroups() async {
        do {
            let joinedGroups = try await SupabaseService.shared.fetchUserJoinedGroups()
            self.joinedIds = Set(joinedGroups.map { $0.id })
        } catch {
            print("❌ 獲取已加入群組失敗: \(error)")
        }
    }
    
    // MARK: - B線邀請功能
    
    /// 載入待處理的邀請
    func loadPendingInvitations() async {
        do {
            let invitations = try await supabaseService.fetchPendingInvites()
            self.pendingInvitations = invitations
            if !invitations.isEmpty {
                print("✅ 發現 \(invitations.count) 個待處理邀請")
            }
        } catch {
            print("❌ 載入邀請失敗: \(error)")
        }
    }
    
    /// 接受邀請
    func acceptInvitation(_ invitation: GroupInvitation) async {
        isProcessingInvitation = true
        
        do {
            try await supabaseService.acceptInvitation(invitationId: invitation.id)
            
            // 重新載入相關資料
            await refreshJoinedGroups()
            await loadPendingInvitations()
            
            print("✅ 成功接受邀請加入群組")
            
            // 發送通知切換到聊天 Tab
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchToChatTab"), 
                object: invitation.groupId
            )
            
        } catch {
            errorMessage = "接受邀請失敗: \(error.localizedDescription)"
            print("❌ 接受邀請失敗: \(error)")
        }
        
        isProcessingInvitation = false
    }
    
    /// 拒絕邀請
    func declineInvitation(_ invitation: GroupInvitation) async {
        isProcessingInvitation = true
        
        do {
            // 更新邀請狀態為已拒絕
            struct InvitationUpdate: Codable {
                let status: String
            }
            
            let update = InvitationUpdate(status: "declined")
            
            try await supabaseService.client
                .from("group_invitations")
                .update(update)
                .eq("id", value: invitation.id.uuidString)
                .execute()
            
            // 重新載入邀請列表
            await loadPendingInvitations()
            
            print("✅ 成功拒絕邀請")
            
        } catch {
            errorMessage = "拒絕邀請失敗: \(error.localizedDescription)"
            print("❌ 拒絕邀請失敗: \(error)")
        }
        
        isProcessingInvitation = false
    }
}

// MARK: - 排行榜用戶資料結構
struct RankingUser: Identifiable {
    let id = UUID()
    let name: String
    let returnRate: Double
    let rank: Int
    
    // 根據排名返回對應的顏色
    var borderColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700") // 金色
        case 2: return Color(hex: "#C0C0C0") // 銀色  
        case 3: return Color(hex: "#CD7F32") // 銅色
        default: return .gray300
        }
    }
    
    // 根據排名返回對應的徽章顏色
    var badgeColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700") // 金色
        case 2: return Color(hex: "#C0C0C0") // 銀色  
        case 3: return Color(hex: "#CD7F32") // 銅色
        default: return .gray400
        }
    }
    
    // 安全的格式化回報率顯示
    var formattedReturnRate: String {
        guard returnRate.isFinite && !returnRate.isNaN else {
            return "0.0%"
        }
        return String(format: "%.1f%%", returnRate)
    }
}

// MARK: - 週排名資料結構 (保留向後兼容)
struct WeeklyRanking: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let returnRate: Double
    let portfolioValue: Double
    let rank: Int
    let weekStartDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case returnRate = "return_rate"
        case portfolioValue = "portfolio_value"
        case rank
        case weekStartDate = "week_start_date"
    }
} 