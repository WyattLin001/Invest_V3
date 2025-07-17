import SwiftUI
import Combine
import Supabase

// MARK: - 測試常數
struct TestConstants {
    static let testGroupId = UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!
    static let testUserEmail = "f227006900@gmail.com"
    static let yukaUserEmail = "yuka@gmail.com"
}

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Services
    private let supabaseService = SupabaseService.shared
    private var authService: AuthenticationService?

    // MARK: - Published Properties
    
    // Navigation & Selection
    @Published var showGroupSelection = true
    @Published var selectedGroupId: UUID?
    @Published var selectedGroup: InvestmentGroup?
    
    // Group Data
    @Published var joinedGroups: [InvestmentGroup] = []
    @Published var filteredGroups: [InvestmentGroup] = []
    @Published var searchText = ""
    @Published var isLoadingGroups = false
    
    // Chat Data
    @Published var messages: [ChatMessage] = []
    @Published var isLoadingMessages = false
    @Published var isSendingMessage = false
    @Published var isHostMode = false
    @Published var actualMemberCount: Int = 0
    
    // Text Input
    @Published var messageText = ""
    @AppStorage("lastMessageContent") var lastMessageContent = ""
    
    // Gift & Wallet
    @Published var showGiftModal = false
    @Published var currentBalance: Double = 0.0 {
        didSet {
            // 確保 currentBalance 始終是有效數值
            if currentBalance.isNaN || !currentBalance.isFinite || currentBalance < 0 {
                print("⚠️ [ChatViewModel] 檢測到無效 currentBalance 值: \(currentBalance)，重置為 0")
                currentBalance = 0.0
            }
        }
    }
    @Published var isLoadingBalance = false
    @Published var showGiftAnimation = false
    @Published var animatingGiftEmoji = ""
    @Published var animatingGiftOffset: CGSize = .zero
    
    // Modals & Alerts
    @Published var showInfoModal = false
    @Published var showInviteSheet = false
    @Published var showInvestmentPanel = false
    @Published var groupDetails: (group: InvestmentGroup, hostInfo: UserProfile?)?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showClearChatAlert = false
    @Published var showLeaveGroupAlert = false
    
    // Investment Panel
    @Published var stockSymbol = ""
    @Published var tradeAmount = ""
    @Published var tradeAction = "buy"
    @Published var showTradeSuccess = false
    @Published var tradeSuccessMessage = ""
    
    // Invitation
    @Published var inviteEmail = ""
    @Published var isSendingInvitation = false
    @Published var friends: [UserProfile] = []
    @Published var selectedFriendIds: Set<UUID> = []
    @Published var inviteMode: InviteMode = .friends
    
    enum InviteMode: String, CaseIterable {
        case friends = "好友"
        case email = "Email"
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var chatSubscription: RealtimeChannelV2?
    private var messagePollingTimer: Timer?
    
    // 診斷相關屬性
    @Published var connectionStatus: String = "未檢查"
    @Published var isConnected: Bool = false
    @Published var diagnosticInfo: String = ""
    
    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.filterGroups() }
            .store(in: &cancellables)
            
        $selectedGroupId
            .compactMap { $0 }
            .sink { [weak self] groupId in self?.onGroupSelected(groupId) }
            .store(in: &cancellables)
    }
    
    deinit {
        // 清理資源
        messagePollingTimer?.invalidate()
        if let subscription = chatSubscription {
            supabaseService.unsubscribeFromGroupMessages(channel: subscription)
        }
        print("🔄 [ChatViewModel] 已清理所有資源")
    }

    // MARK: - Setup
    func setup(authService: AuthenticationService) {
        self.authService = authService
        
        // 先進行連線診斷
        Task {
            await performDiagnostics()
            loadJoinedGroups()
            loadWalletBalance()
        }
        
        self.messageText = lastMessageContent
    }
    
    // MARK: - 診斷功能
    
    /// 執行完整的診斷檢查
    func performDiagnostics() async {
        var diagnosticResults: [String] = []
        
        // 1. 檢查資料庫連線
        let connectionResult = await supabaseService.checkDatabaseConnection()
        self.isConnected = connectionResult.isConnected
        self.connectionStatus = connectionResult.message
        diagnosticResults.append("連線狀態: \(connectionResult.message)")
        
        // 2. 檢查 f227006900@gmail.com 的訊息記錄
        let messageCheck = await supabaseService.checkUserMessages(userEmail: TestConstants.testUserEmail)
        diagnosticResults.append("f227006900@gmail.com 訊息: \(messageCheck.messageCount) 則")
        if let latestMessage = messageCheck.latestMessage {
            diagnosticResults.append("最新訊息: \(latestMessage)")
        }
        
        // 3. 檢查當前用戶的群組成員資格
        if let authService = authService,
           let currentUser = authService.currentUser {
            diagnosticResults.append("當前用戶: \(currentUser.displayName)")
            
            // 檢查是否為測試群組成員
            let isMember = await supabaseService.isUserInGroup(userId: currentUser.id, groupId: TestConstants.testGroupId)
            diagnosticResults.append("測試群組成員: \(isMember ? "是" : "否")")
        }
        
        self.diagnosticInfo = diagnosticResults.joined(separator: "\n")
        print("🔍 [診斷] 診斷完成:\n\(diagnosticInfo)")
    }
    
    // MARK: - 測試功能
    
    /// 模擬加入測試群組
    func simulateJoinTestGroup() async throws {
        print("🏠 [測試] 開始模擬加入測試群組...")
        
        do {
            // 獲取當前用戶 ID
            guard let authService = authService,
                  let currentUser = authService.currentUser else {
                throw NSError(domain: "ChatViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
            }
            
            // 嘗試加入測試群組
            try await supabaseService.joinGroup(groupId: TestConstants.testGroupId, userId: currentUser.id)
            print("✅ [測試] 成功加入測試群組")
            
            // 重新載入群組列表
            loadJoinedGroups(forceReload: true)
            
        } catch {
            print("❌ [測試] 加入測試群組失敗: \(error.localizedDescription)")
            handleError(error, context: "加入測試群組失敗")
        }
    }
    
    /// 發送測試訊息
    func sendTestMessage() async throws {
        print("💬 [測試] 開始發送測試訊息...")
        
        do {
            let testMessage = "測試訊息 - \(Date().formatted(date: .omitted, time: .shortened))"
            let message = try await supabaseService.sendMessage(
                groupId: TestConstants.testGroupId,
                content: testMessage
            )
            
            print("✅ [測試] 測試訊息發送成功: \(message.content)")
            
            // 如果當前在測試群組，更新訊息列表
            if selectedGroupId == TestConstants.testGroupId {
                loadChatMessages(for: TestConstants.testGroupId)
            }
            
        } catch {
            print("❌ [測試] 發送測試訊息失敗: \(error.localizedDescription)")
            handleError(error, context: "發送測試訊息失敗")
        }
    }
    
    /// 檢查測試群組訊息
    func checkTestGroupMessages() async throws {
        print("📋 [測試] 開始檢查測試群組訊息...")
        
        do {
            let messages = try await supabaseService.fetchChatMessages(groupId: TestConstants.testGroupId)
            print("📋 [測試] 測試群組共有 \(messages.count) 則訊息")
            
            // 顯示最近的 5 則訊息
            let recentMessages = messages.suffix(5)
            for message in recentMessages {
                print("📋 [測試]   - \(message.senderName): \(message.content)")
            }
            
            // 如果當前在測試群組，更新訊息列表
            if selectedGroupId == TestConstants.testGroupId {
                self.messages = messages.sorted { $0.createdAt < $1.createdAt }
            }
            
        } catch {
            print("❌ [測試] 檢查測試群組訊息失敗: \(error.localizedDescription)")
            handleError(error, context: "檢查測試群組訊息失敗")
        }
    }
    
    /// 將 yuka 用戶加入測試群組
    func addYukaToTestGroup() async throws {
        print("👥 [測試] 開始將 yuka 用戶加入測試群組...")
        
        do {
            try await supabaseService.addYukaToTestGroup()
            print("✅ [測試] yuka 用戶已成功加入測試群組")
            
            // 重新載入群組列表
            loadJoinedGroups(forceReload: true)
            
        } catch {
            print("❌ [測試] 將 yuka 用戶加入測試群組失敗: \(error.localizedDescription)")
            handleError(error, context: "將 yuka 用戶加入測試群組失敗")
        }
    }

    // MARK: - Data Loading & Actions
    
    func loadJoinedGroups(forceReload: Bool = false) {
        isLoadingGroups = true
        Task {
            do {
                let groups = try await supabaseService.fetchUserJoinedGroups()
                if groups.isEmpty {
                    self.joinedGroups = createMockGroups()
                } else {
                    self.joinedGroups = groups
                }
                self.filterGroups()
                self.isLoadingGroups = false
            } catch {
                handleError(error, context: "載入群組失敗")
                self.joinedGroups = createMockGroups() // Fallback
                self.filterGroups()
                self.isLoadingGroups = false
            }
        }
    }
    
    func loadChatMessages(for groupId: UUID) {
        isLoadingMessages = true
        Task {
            do {
                let fetchedMessages = try await supabaseService.fetchChatMessages(groupId: groupId)
                self.messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
                self.isLoadingMessages = false
            } catch {
                handleError(error, context: "載入訊息失敗")
                self.isLoadingMessages = false
            }
        }
    }
    
    func loadGroupDetails(for groupId: UUID) {
        Task {
            do {
                self.groupDetails = try await supabaseService.fetchGroupDetails(groupId: groupId)
                print("✅ [ChatViewModel] 群組詳情載入成功")
                
                // 載入實際成員數
                let memberCount = try await supabaseService.fetchGroupMemberCount(groupId: groupId)
                self.actualMemberCount = memberCount
                print("✅ [ChatViewModel] 群組成員數載入成功: \(memberCount)")
                
            } catch {
                print("⚠️ [ChatViewModel] 載入群組詳情時發生問題: \(error.localizedDescription)")
                // 這個錯誤不影響聊天功能，所以不顯示給用戶
            }
        }
    }
    
    func loadWalletBalance() {
        isLoadingBalance = true
        Task {
            do {
                let walletBalance = try await supabaseService.fetchWalletBalance()
                
                // 確保獲取的餘額是有效數值
                let balanceDouble = Double(walletBalance)
                if balanceDouble.isFinite && !balanceDouble.isNaN && balanceDouble >= 0 {
                    self.currentBalance = balanceDouble
                    print("✅ [ChatViewModel] 載入餘額成功: \(walletBalance) 代幣")
                } else {
                    print("⚠️ [ChatViewModel] 獲取到無效餘額: \(walletBalance)，使用預設值")
                    self.currentBalance = 5280.0
                }
                
                self.isLoadingBalance = false
            } catch {
                handleError(error, context: "載入餘額失敗")
                self.currentBalance = 5280.0 // 使用安全的預設值
                self.isLoadingBalance = false
            }
        }
    }
    
    func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let groupId = selectedGroupId else { return }
        
        isSendingMessage = true
        Task {
            do {
                // 使用新的 sendMessage 方法，它會自動檢查群組成員資格
                let newMessage = try await supabaseService.sendMessage(groupId: groupId, content: content)
                
                // 檢查訊息是否已存在，避免重複
                if !self.messages.contains(where: { $0.id == newMessage.id }) {
                    self.messages.append(newMessage)
                }
                
                self.messageText = ""
                self.lastMessageContent = ""
                self.isSendingMessage = false
                
                print("✅ [發送訊息] 訊息發送成功: \(content)")
                
            } catch {
                handleError(error, context: "發送訊息失敗")
                self.isSendingMessage = false
                
                // 如果是權限問題，提供更詳細的錯誤信息
                if error.localizedDescription.contains("不是群組成員") {
                    self.errorMessage = "您不是此群組的成員，無法發送訊息。請先加入群組。"
                }
            }
        }
    }
    
    func performTip(amount: Double) {
        guard let groupId = selectedGroupId, let hostInfo = groupDetails?.hostInfo else { return }
        
        // 確保 amount 是有效數值
        guard amount.isFinite && !amount.isNaN && amount > 0 else {
            handleError(nil, context: "無效的抖內金額")
            return
        }
        
        guard currentBalance >= amount else {
            handleError(nil, context: "餘額不足，請先儲值")
            return
        }
        
        // Trigger animation
        animatingGiftEmoji = "🎁"
        animatingGiftOffset = CGSize(width: 0, height: -120)
        showGiftAnimation = true
        withAnimation(.easeOut(duration: 0.5)) { self.animatingGiftOffset = .zero }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.2)) { self.showGiftAnimation = false }
        }
        
        Task {
            do {
                _ = try await supabaseService.createTipTransaction(recipientId: hostInfo.id, amount: amount, groupId: groupId)
                
                // 安全地更新餘額
                let newBalance = currentBalance - amount
                if newBalance.isFinite && !newBalance.isNaN && newBalance >= 0 {
                    self.currentBalance = newBalance
                } else {
                    print("⚠️ [ChatViewModel] 計算新餘額時出現問題，重新載入餘額")
                    loadWalletBalance()
                }
                
                self.showGiftModal = false
                let tipMessage = "🎁 抖內了 \(Int(amount)) 金幣給主持人！"
                self.messageText = tipMessage
                self.sendMessage()
                loadWalletBalance() // Refresh balance
            } catch {
                handleError(error, context: "抖內失敗")
            }
        }
    }
    
    func clearChatHistory() {
        guard let groupId = selectedGroupId else { return }
        Task {
            do {
                try await supabaseService.clearChatHistory(for: groupId)
                self.messages.removeAll()
                self.showInfoModal = false
            } catch {
                handleError(error, context: "清除訊息失敗")
            }
        }
    }

    // MARK: - UI Logic
    
    func selectGroup(_ group: InvestmentGroup) {
        self.selectedGroup = group
        self.selectedGroupId = group.id
        self.showGroupSelection = false
    }
    
    private func onGroupSelected(_ groupId: UUID) {
        loadChatMessages(for: groupId)
        loadGroupDetails(for: groupId)
        loadWalletBalance()
        subscribeToChatMessages(groupId: groupId)
    }

    private func subscribeToChatMessages(groupId: UUID) {
        // 取消之前的訂閱
        if let existingSubscription = chatSubscription {
            supabaseService.unsubscribeFromGroupMessages(channel: existingSubscription)
        }
        
        // 停止之前的輪詢計時器
        messagePollingTimer?.invalidate()
        
        // 使用定時器進行訊息同步（每 3 秒檢查一次新訊息）
        print("🔄 [訊息同步] 開始定時器同步，群組: \(groupId)")
        messagePollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // 只有在當前選中的群組才進行同步
            if self.selectedGroupId == groupId {
                Task {
                    await self.refreshMessages(for: groupId)
                }
            } else {
                // 如果切換了群組，停止定時器
                timer.invalidate()
                self.messagePollingTimer = nil
            }
        }
    }
    
    private func refreshMessages(for groupId: UUID) async {
        do {
            let fetchedMessages = try await supabaseService.fetchChatMessages(groupId: groupId)
            let sortedMessages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            
            // 檢查是否有新訊息
            let currentMessageIds = Set(self.messages.map { $0.id })
            let newMessages = sortedMessages.filter { !currentMessageIds.contains($0.id) }
            
            if !newMessages.isEmpty {
                await MainActor.run {
                    self.messages.append(contentsOf: newMessages)
                    print("🔄 [定時更新] 添加 \(newMessages.count) 則新訊息")
                }
            }
        } catch {
            print("❌ [定時更新] 重新載入訊息失敗: \(error)")
        }
    }
    
    func goBackToGroupSelection() {
        showGroupSelection = true
        selectedGroupId = nil
        selectedGroup = nil
        
        // 離開聊天室時取消訂閱
        if let subscription = chatSubscription {
            supabaseService.unsubscribeFromGroupMessages(channel: subscription)
            chatSubscription = nil
        }
        
        // 停止訊息輪詢計時器
        messagePollingTimer?.invalidate()
        messagePollingTimer = nil
        print("🔄 [訊息同步] 已停止定時器同步")
    }
    
    func filterGroups() {
        if searchText.isEmpty {
            filteredGroups = joinedGroups
        } else {
            filteredGroups = joinedGroups.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.host.localizedCaseInsensitiveContains(searchText) ||
                ($0.category ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Helpers
    
    private func handleError(_ error: Error?, context: String) {
        let message = error?.localizedDescription ?? "未知錯誤"
        if message.contains("not authenticated") {
            self.errorMessage = "認證失效，請重新登入後再試"
        } else {
            self.errorMessage = "\(context): \(message)"
        }
        self.showError = true
        print("❌ \(context): \(message)")
    }
    
    private func createMockGroups() -> [InvestmentGroup] {
        return [
            InvestmentGroup(id: UUID(), name: "科技股投資俱樂部", host: "張投資", returnRate: 15.5, entryFee: "10 代幣", memberCount: 25, category: "科技股", rules: "專注於台灣科技股，禁止投機短線操作，每日最多交易3次", createdAt: Date(), updatedAt: Date()),
            InvestmentGroup(id: UUID(), name: "價值投資學院", host: "李分析師", returnRate: 12.3, entryFee: "20 代幣", memberCount: 18, category: "價值投資", rules: "長期持有策略，最少持股期間30天，重視基本面分析", createdAt: Date(), updatedAt: Date()),
            InvestmentGroup(id: UUID(), name: "AI科技前瞻", host: "林未來", returnRate: 22.1, entryFee: "50 代幣", memberCount: 8, category: "科技股", rules: "專注AI、半導體相關股票，需定期分享投資心得", createdAt: Date(), updatedAt: Date())
        ]
    }
    
    // For Debug Panel
    func fullResetAndResync() {
        // This is a placeholder for more complex logic if needed
        print("🔄 [DEBUG] Performing full reset and resync...")
        loadJoinedGroups()
    }
    
    // MARK: - Invitation Methods (B線邀請功能)
    
    /// 載入好友列表
    func loadFriends() async {
        do {
            let friendList = try await supabaseService.fetchFriendList()
            await MainActor.run {
                self.friends = friendList
                print("✅ [好友] 載入 \(friendList.count) 位好友")
            }
        } catch {
            await MainActor.run {
                handleError(error, context: "載入好友列表失敗")
            }
        }
    }
    
    /// 發送群組邀請
    func sendInvitation() async {
        guard let groupId = selectedGroupId else { return }
        
        isSendingInvitation = true
        
        do {
            switch inviteMode {
            case .friends:
                // 發送好友邀請
                for friendId in selectedFriendIds {
                    try await supabaseService.createInvitationByUserId(groupId: groupId, inviteeId: friendId)
                }
                print("✅ [邀請] 成功邀請 \(selectedFriendIds.count) 位好友")
                
            case .email:
                // 發送 Email 邀請
                guard !inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await MainActor.run {
                        self.isSendingInvitation = false
                    }
                    return
                }
                try await supabaseService.createInvitation(groupId: groupId, email: inviteEmail)
                print("✅ [邀請] 邀請發送成功: \(inviteEmail)")
            }
            
            await MainActor.run {
                self.inviteEmail = ""
                self.selectedFriendIds.removeAll()
                self.showInviteSheet = false
                self.isSendingInvitation = false
            }
            
        } catch {
            await MainActor.run {
                self.isSendingInvitation = false
                handleError(error, context: "發送邀請失敗")
            }
        }
    }
    
    /// 退出群組
    func leaveGroup() {
        guard let groupId = selectedGroupId else { return }
        
        Task {
            do {
                // 調用 SupabaseService 退出群組
                try await supabaseService.leaveGroup(groupId: groupId)
                
                await MainActor.run {
                    print("✅ 成功退出群組")
                    
                    // 清除當前選中的群組
                    selectedGroupId = nil
                    selectedGroup = nil
                    messages.removeAll()
                    
                    // 關閉資訊彈窗
                    showInfoModal = false
                    
                    // 返回群組選擇頁面
                    showGroupSelection = true
                    
                    // 重新載入群組列表
                    loadJoinedGroups(forceReload: true)
                }
                
            } catch {
                await MainActor.run {
                    handleError(error, context: "退出群組失敗")
                }
            }
        }
    }
    
    // MARK: - Investment Trading Methods
    
    /// 執行股票交易
    func executeTrade() {
        guard !stockSymbol.isEmpty,
              !tradeAmount.isEmpty,
              let amount = Double(tradeAmount) else {
            return
        }
        
        Task {
            do {
                // 這裡應該調用實際的交易服務
                // 暫時使用模擬交易
                try await simulateTrade(symbol: stockSymbol, amount: amount, action: tradeAction)
                
                await MainActor.run {
                    // 設置成功訊息
                    let actionText = tradeAction == "buy" ? "買入" : "賣出"
                    tradeSuccessMessage = "已\(actionText) \(stockSymbol) $\(Int(amount))"
                    
                    // 清空輸入欄位
                    stockSymbol = ""
                    tradeAmount = ""
                    
                    // 顯示成功提示
                    showTradeSuccess = true
                    
                    // 在聊天中發送交易通知
                    sendTradeAnnouncement(symbol: stockSymbol, amount: amount, action: tradeAction)
                }
                
            } catch {
                await MainActor.run {
                    handleError(error, context: "交易執行失敗")
                }
            }
        }
    }
    
    /// 模擬交易
    private func simulateTrade(symbol: String, amount: Double, action: String) async throws {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
        
        // 這裡可以添加實際的 Supabase 交易記錄邏輯
        print("🔄 執行\(action == "buy" ? "買入" : "賣出")交易: \(symbol) $\(amount)")
    }
    
    /// 在聊天中發送交易通知
    private func sendTradeAnnouncement(symbol: String, amount: Double, action: String) {
        guard let groupId = selectedGroupId else { return }
        
        let actionText = action == "buy" ? "買入" : "賣出"
        let announcementText = "📈 我剛剛\(actionText)了 \(symbol) $\(Int(amount))"
        
        Task {
            do {
                try await supabaseService.sendMessage(
                    groupId: groupId,
                    content: announcementText,
                    isCommand: true
                )
                
                // 重新載入訊息以顯示新的交易通知
                loadChatMessages(for: groupId)
                
            } catch {
                print("❌ 發送交易通知失敗: \(error)")
            }
        }
    }

} 
