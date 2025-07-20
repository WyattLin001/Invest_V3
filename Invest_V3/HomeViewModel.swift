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
    
    // 追蹤是否已經初始化過測試資料
    private var hasInitializedTestData = false
    
    // B線邀請功能
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var isProcessingInvitation = false
    
    // 投資功能
    @Published var showInvestmentPanel = false
    @Published var stockSymbol = ""
    @Published var tradeAmount = ""
    @Published var tradeAction = "buy"
    @Published var showTradeSuccess = false
    @Published var tradeSuccessMessage = ""
    @Published var portfolioManager = ChatPortfolioManager.shared
    
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
            
            // 統合載入完成訊息
            let groupCount = investmentGroups.count
            let rankingCount = tradingRankings.count
            let joinedCount = joinedIds.count
            let inviteCount = pendingInvitations.count
            
            print("📊 資料載入完成: \(groupCount)個群組, \(rankingCount)筆排行榜, \(joinedCount)個已加入群組, \(inviteCount)個邀請")
            
        } catch {
            // 忽略取消錯誤，避免在快速重新整理時顯示錯誤
            if error is CancellationError {
                print("⚠️ 資料載入被取消（正常情況，用戶快速重新整理）")
            } else {
                errorMessage = "載入資料失敗: \(error.localizedDescription)"
                print("HomeViewModel loadData error: \(error)")
            }
        }
        
        isLoading = false
    }
    
    // MARK: - 投資功能
    
    /// 執行股票交易
    func executeTrade() {
        guard !stockSymbol.isEmpty,
              !tradeAmount.isEmpty,
              let amount = Double(tradeAmount) else {
            return
        }
        
        Task {
            do {
                // 獲取模擬股價
                let stockPrice = try await getStockPrice(symbol: stockSymbol)
                
                await MainActor.run {
                    let success: Bool
                    let errorMessage: String?
                    
                    if tradeAction == "buy" {
                        let shares = amount / stockPrice
                        success = portfolioManager.buyStock(symbol: stockSymbol, shares: shares, price: stockPrice)
                        errorMessage = success ? nil : "餘額不足或交易失敗"
                    } else {
                        // 賣出時，amount 是股數而不是金額
                        let shares = amount
                        success = portfolioManager.sellStock(symbol: stockSymbol, shares: shares, price: stockPrice)
                        errorMessage = success ? nil : "持股不足或交易失敗"
                    }
                    
                    if success {
                        // 設置成功訊息
                        let actionText = tradeAction == "buy" ? "買入" : "賣出"
                        if tradeAction == "buy" {
                            tradeSuccessMessage = "已\(actionText) \(stockSymbol) $\(Int(amount))"
                        } else {
                            tradeSuccessMessage = "已\(actionText) \(stockSymbol) \(Int(amount)) 股"
                        }
                        
                        // 清空輸入欄位
                        let symbolToAnnounce = stockSymbol
                        stockSymbol = ""
                        tradeAmount = ""
                        
                        // 顯示成功提示
                        showTradeSuccess = true
                        
                        // 發送交易通知到所有主持人的群組
                        Task {
                            await sendTradeNotificationToHostedGroups(symbol: symbolToAnnounce, amount: amount, action: tradeAction)
                        }
                    } else {
                        self.errorMessage = errorMessage ?? "交易失敗"
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "交易執行失敗: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 獲取股票價格 (模擬)
    private func getStockPrice(symbol: String) async throws -> Double {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // 模擬股價 (後續可以接真實 API)
        let mockPrices: [String: Double] = [
            "AAPL": 150.0,
            "TSLA": 200.0,
            "NVDA": 400.0,
            "GOOGL": 120.0,
            "MSFT": 300.0,
            "AMZN": 130.0
        ]
        
        return mockPrices[symbol.uppercased()] ?? 100.0
    }
    
    /// 發送交易通知到用戶主持的群組
    private func sendTradeNotificationToHostedGroups(symbol: String, amount: Double, action: String) async {
        do {
            // 獲取用戶主持的群組列表
            let hostedGroups = try await supabaseService.fetchUserHostedGroups()
            
            let actionText = action == "buy" ? "買入" : "賣出"
            let announcementText = "📈 我剛剛\(actionText)了 \(symbol) $\(Int(amount))"
            
            // 向每個主持的群組發送通知
            for group in hostedGroups {
                do {
                    try await supabaseService.sendMessage(
                        groupId: group.id,
                        content: announcementText,
                        isCommand: true
                    )
                    print("✅ [HomeViewModel] 交易通知已發送到群組: \(group.name)")
                } catch {
                    print("❌ [HomeViewModel] 發送交易通知失敗到群組 \(group.name): \(error)")
                }
            }
        } catch {
            print("❌ [HomeViewModel] 獲取主持群組失敗: \(error)")
        }
    }
    
    // MARK: - 載入投資群組
    private func loadInvestmentGroups() async throws {
        // 從 Supabase 載入真實的投資群組資料
        let groups = try await supabaseService.fetchInvestmentGroups()
        self.investmentGroups = groups
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
            
        } catch {
            // 如果載入失敗，設為空陣列
            print("⚠️ 載入排行榜失敗: \(error)")
            self.tradingRankings = []
        }
    }
    
    // MARK: - 切換排行榜週期
    func switchPeriod(to period: RankingPeriod) {
        selectedPeriod = period
        
        // 重新載入排行榜資料
        Task {
            try? await loadTradingRankings()
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
        // 避免重複初始化
        guard !hasInitializedTestData else {
            print("⚠️ 測試資料已經初始化過，跳過重複初始化")
            await loadData() // 只載入數據，不清理
            return
        }
        
        do {
            print("🧹 系統初始化：清理測試資料...")
            
            // 清理所有假資料群組
            try await SupabaseService.shared.clearAllDummyGroups()
            
            // 清空聊天內容
            try await SupabaseService.shared.clearAllChatMessages()
            
            // 標記已初始化
            hasInitializedTestData = true
            
            // 重新載入群組數據
            await loadData()
            
            print("✅ 系統初始化完成")
            
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