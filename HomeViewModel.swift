import SwiftUI
import Foundation

// MARK: - 排行榜時間週期
enum RankingPeriod: String, CaseIterable {
    case weekly = "本週冠軍"
    case quarterly = "本季冠軍" 
    case yearly = "本年冠軍"
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var investmentGroups: [InvestmentGroup] = []
    @Published var filteredGroups: [InvestmentGroup] = []
    @Published var joinedIds: Set<UUID> = []
    @Published var weeklyRankings: [RankingUser] = []
    @Published var quarterlyRankings: [RankingUser] = []
    @Published var yearlyRankings: [RankingUser] = []
    @Published var selectedPeriod: RankingPeriod = .weekly
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // B線邀請功能
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var isProcessingInvitation = false
    
    private let supabaseService = SupabaseService.shared
    
    // 根據選中的時間週期返回對應的排行榜
    var currentRankings: [RankingUser] {
        switch selectedPeriod {
        case .weekly:
            return weeklyRankings
        case .quarterly:
            return quarterlyRankings
        case .yearly:
            return yearlyRankings
        }
    }
    
    // MARK: - 初始化資料
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 並行載入資料
            async let groupsTask = loadInvestmentGroups()
            async let rankingsTask = loadAllRankings()
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
        // 由於目前沒有真實資料，使用模擬資料
        let mockGroups = [
            InvestmentGroup(
                id: UUID(),
                name: "科技股投資俱樂部",
                host: "張投資",
                returnRate: 15.5,
                entryFee: "10 代幣",
                memberCount: 25,
                category: "科技股",
                rules: "專注於台灣科技股，禁止投機短線操作，每日最多交易3次",
                createdAt: Date(),
                updatedAt: Date()
            ),
            InvestmentGroup(
                id: UUID(),
                name: "價值投資學院",
                host: "李分析師",
                returnRate: 12.3,
                entryFee: "20 代幣",
                memberCount: 18,
                category: "價值投資",
                rules: "長期持有策略，最少持股期間30天，重視基本面分析",
                createdAt: Date(),
                updatedAt: Date()
            ),
            InvestmentGroup(
                id: UUID(),
                name: "加密貨幣先鋒",
                host: "王區塊",
                returnRate: 28.7,
                entryFee: "30 代幣",
                memberCount: 12,
                category: "短期投機",
                rules: "高風險高報酬，允許槓桿交易，需有相關經驗",
                createdAt: Date(),
                updatedAt: Date()
            ),
            InvestmentGroup(
                id: UUID(),
                name: "綠能投資團",
                host: "陳環保",
                returnRate: 8.9,
                entryFee: nil,
                memberCount: 35,
                category: "綠能",
                rules: "僅投資ESG相關綠能股票，追求永續發展理念",
                createdAt: Date(),
                updatedAt: Date()
            ),
            InvestmentGroup(
                id: UUID(),
                name: "AI科技前瞻",
                host: "林未來",
                returnRate: 22.1,
                entryFee: "50 代幣",
                memberCount: 8,
                category: "科技股",
                rules: "專注AI、半導體相關股票，需定期分享投資心得",
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        self.investmentGroups = mockGroups
        self.filteredGroups = mockGroups
    }
    
    // MARK: - 載入所有排行榜
    private func loadAllRankings() async throws {
        // 模擬資料，實際應該從 Supabase 獲取不同時間週期的排行榜
        self.weeklyRankings = [
            RankingUser(name: "投資大師Tom", returnRate: 18.5, rank: 1),
            RankingUser(name: "環保投資者Lisa", returnRate: 12.3, rank: 2),
            RankingUser(name: "快手Kevin", returnRate: 25.7, rank: 3)
        ]
        
        self.quarterlyRankings = [
            RankingUser(name: "穩健投資王", returnRate: 45.2, rank: 1),
            RankingUser(name: "科技股女王", returnRate: 38.9, rank: 2),
            RankingUser(name: "價值投資者", returnRate: 32.1, rank: 3)
        ]
        
        self.yearlyRankings = [
            RankingUser(name: "年度投資王", returnRate: 125.8, rank: 1),
            RankingUser(name: "長期持有者", returnRate: 98.4, rank: 2),
            RankingUser(name: "分散投資專家", returnRate: 87.3, rank: 3)
        ]
    }
    
    // MARK: - 切換排行榜週期
    func switchPeriod(to period: RankingPeriod) {
        selectedPeriod = period
    }
    
    // MARK: - 篩選群組
    func filterGroups(by category: String) {
        if category == "全部" {
            filteredGroups = investmentGroups
        } else {
            filteredGroups = investmentGroups.filter { group in
                group.category?.contains(category) == true
            }
        }
    }
    
    // MARK: - 加入群組
    func joinGroup(_ groupId: UUID) async {
        do {
            try await SupabaseService.shared.joinGroup(groupId)
            print("✅ Joined group: \(groupId)")
            
            // 重新載入已加入群組列表
            await refreshJoinedGroups()
            
        } catch {
            errorMessage = "加入群組失敗: \(error.localizedDescription)"
            print("❌ Join failed: \(error)")
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
            
            try await supabaseService.client.database
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