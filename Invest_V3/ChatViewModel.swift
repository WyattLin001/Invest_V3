import SwiftUI
import Combine
import Auth
import Realtime

// MARK: - 測試常數
struct TestConstants {
    static let testGroupId = UUID(uuidString: "880b4b2c-7ff0-448b-80cf-ef4a4ea9c3d4")!  // Test01群組 (真實存在)
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
    @Published var isCurrentUserHost = false
    @Published var actualMemberCount: Int = 0
    
    // Text Input
    @Published var messageText = ""
    @AppStorage("lastMessageContent") var lastMessageContent = ""
    
    // Gift & Wallet
    @Published var showGiftModal = false
    @Published var selectedGift: GiftItem?
    @Published var showGiftConfirmation = false
    @Published var giftQuantity = 1
    @Published var showTopUpCard = false
    @Published var requiredAmount: Double = 0
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
    
    // Donation Leaderboard
    @Published var donationLeaderboard: [DonationSummary] = []
    @Published var showDonationLeaderboard = false
    @Published var isLoadingLeaderboard = false
    
    // Modals & Alerts
    @Published var showInfoModal = false
    @Published var showInviteSheet = false
    @Published var showInvestmentPanel = false
    @Published var groupDetails: (group: InvestmentGroup, hostInfo: UserProfile?)?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showErrorAlert = false
    @Published var successMessage: String?
    @Published var showSuccessAlert = false
    @Published var showClearChatAlert = false
    @Published var showLeaveGroupAlert = false
    
    // Investment Panel
    @Published var stockSymbol = ""
    @Published var tradeAmount = ""
    @Published var tradeAction = "buy"
    @Published var showTradeSuccess = false
    @Published var tradeSuccessMessage = ""
    @Published var portfolioManager = ChatPortfolioManager.shared
    
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
        
        // 監聽群組切換通知
        NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToChatTab"))
            .sink { [weak self] notification in
                if let groupId = notification.object as? UUID {
                    Task { @MainActor in
                        await self?.handleGroupSwitchNotification(groupId: groupId)
                    }
                }
            }
            .store(in: &cancellables)
        
        // 監聽錢包餘額更新通知
        NotificationCenter.default.publisher(for: NSNotification.Name("WalletBalanceUpdated"))
            .sink { [weak self] _ in
                self?.loadWalletBalance()
            }
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
            await loadJoinedGroups()
            loadWalletBalance()
            
            // 統合的載入完成訊息
            await MainActor.run {
                let groupCount = joinedGroups.count
                let balanceText = String(format: "%.0f", currentBalance)
                print("💬 聊天頁面載入完成: \(groupCount)個群組, \(balanceText)代幣")
            }
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
        // 診斷完成（靜默）
    }
    
    // MARK: - Data Loading & Actions
    
    func loadJoinedGroups(forceReload: Bool = false) async {
        isLoadingGroups = true
        do {
            let groups = try await supabaseService.fetchUserJoinedGroups()
            self.joinedGroups = groups
            self.filterGroups()
            self.isLoadingGroups = false
            
            // 群組載入完成（靜默）
        } catch {
            handleError(error, context: "載入群組失敗")
            self.joinedGroups = [] // 改為空陣列，不使用假資料
            self.filterGroups()
            self.isLoadingGroups = false
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
                    // 餘額載入成功（靜默）
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
    
    func performTip(amount: Double, giftItem: GiftItem? = nil, quantity: Int = 1) {
        guard let groupId = selectedGroupId else { 
            print("❌ [抖內] 沒有選中的群組")
            handleError(nil, context: "請先選擇群組")
            return 
        }
        
        guard let selectedGroup = selectedGroup else {
            print("❌ [抖內] 群組資料不完整")
            handleError(nil, context: "群組資料載入中，請稍後再試")
            return
        }
        
        // 確保 amount 是有效數值
        guard amount.isFinite && !amount.isNaN && amount > 0 else {
            handleError(nil, context: "無效的抖內金額")
            return
        }
        
        guard currentBalance >= amount else {
            // 計算需要的金額
            requiredAmount = amount - currentBalance
            
            // 顯示儲值卡片
            showTopUpCard = true
            return
        }
        
        print("🎁 [抖內] 開始執行抖內: \(amount) 金幣給群組 \(selectedGroup.name)")
        
        // 觸發動畫 - 專業級多階段動畫效果
        // 使用對應的禮物圖標，如果沒有指定則使用預設
        animatingGiftEmoji = giftItem?.icon ?? "🎁"
        animatingGiftOffset = CGSize(width: 0, height: 100) // 從下方開始
        
        // 第一階段：從下方彈入並放大
        withAnimation(.easeOut(duration: 0.1)) {
            showGiftAnimation = true
        }
        
        // 第二階段：向上飛行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                self.animatingGiftOffset = CGSize(width: 0, height: -100)
            }
        }
        
        // 第三階段：旋轉和光環效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.animatingGiftOffset = CGSize(width: 0, height: -80)
            }
        }
        
        // 第四階段：淡出並關閉禮物彈窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) { 
                self.showGiftAnimation = false 
            }
            
            // 延遲關閉禮物選擇彈窗
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showGiftModal = false
            }
        }
        
        Task { @MainActor in
            do {
                // 創建抖內交易記錄
                try await supabaseService.createDonationRecord(
                    groupId: groupId, 
                    amount: amount
                )
                
                // 安全地更新餘額
                let newBalance = currentBalance - amount
                if newBalance.isFinite && !newBalance.isNaN && newBalance >= 0 {
                    self.currentBalance = newBalance
                } else {
                    print("⚠️ [ChatViewModel] 計算新餘額時出現問題，重新載入餘額")
                    loadWalletBalance()
                }
                
                // 獲取當前用戶資訊來顯示訊息
                if let currentUser = supabaseService.getCurrentUser() {
                    let userName = currentUser.displayName.isEmpty ? "匿名用戶" : currentUser.displayName
                    
                    // 根據數量生成訊息
                    let giftName = giftItem?.name ?? "禮物"
                    let giftIcon = giftItem?.icon ?? "🎁"
                    let tipMessage: String
                    
                    if quantity > 1 {
                        tipMessage = "\(giftIcon) \(userName) 送出了 \(quantity) 個\(giftName)（\(Int(amount)) 金幣）給群組！感謝支持！ 🎉"
                    } else {
                        tipMessage = "\(giftIcon) \(userName) 送出了\(giftName)（\(Int(amount)) 金幣）給群組！感謝支持！ 🎉"
                    }
                    
                    self.messageText = tipMessage
                    self.sendMessage()
                }
                
                loadWalletBalance() // 重新載入餘額
                loadDonationLeaderboard() // 更新捐贈排行榜
                
                // 顯示成功反饋
                showSuccessMessage("抖內成功！🎉 感謝您的支持！")
                print("✅ [抖內] 抖內成功完成")
                
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
    
    
    /// 顯示捐贈排行榜
    func showLeaderboard() {
        loadDonationLeaderboard()
        showDonationLeaderboard = true
    }

    // MARK: - UI Logic
    
    /// 處理從 HomeView 來的群組切換通知
    func handleGroupSwitchNotification(groupId: UUID) async {
        // 先載入用戶的群組列表
        await loadJoinedGroups(forceReload: true)
        
        // 尋找對應的群組
        if let group = joinedGroups.first(where: { $0.id == groupId }) {
            // 切換到該群組
            selectGroup(group)
            
            print("✅ 已切換到群組: \(group.name)")
        } else {
            print("⚠️ 找不到群組 ID: \(groupId)")
        }
    }
    
    func selectGroup(_ group: InvestmentGroup) {
        self.selectedGroup = group
        self.selectedGroupId = group.id
        self.showGroupSelection = false
    }
    
    func selectGroup(groupId: UUID) async {
        print("🔍 透過 ID 選擇群組: \(groupId)")
        
        // 先檢查已載入的群組中是否有這個 ID
        if let group = joinedGroups.first(where: { $0.id == groupId }) {
            print("✅ 在已載入群組中找到: \(group.name)")
            await MainActor.run {
                selectGroup(group)
            }
            return
        }
        
        // 如果沒找到，嘗試重新載入群組列表
        print("🔄 重新載入群組列表以尋找群組...")
        await loadJoinedGroups()
        
        if let group = joinedGroups.first(where: { $0.id == groupId }) {
            print("✅ 重新載入後找到群組: \(group.name)")
            await MainActor.run {
                selectGroup(group)
            }
        } else {
            print("❌ 無法找到群組 ID: \(groupId)")
        }
    }
    
    private func onGroupSelected(_ groupId: UUID) {
        loadChatMessages(for: groupId)
        loadGroupDetails(for: groupId)
        loadWalletBalance()
        subscribeToChatMessages(groupId: groupId)
        
        // 延遲權限檢查以避免記憶體問題
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkIfCurrentUserIsHost(for: groupId)
        }
    }
    
    /// 檢查當前用戶是否為群組主持人
    private func checkIfCurrentUserIsHost(for groupId: UUID) {
        Task { @MainActor in
            do {
                let userRole = try await supabaseService.fetchUserRole(groupId: groupId)
                self.isCurrentUserHost = (userRole == .host)
                print("👑 [權限檢查] 用戶角色: \(userRole), 是否為主持人: \(self.isCurrentUserHost)")
            } catch {
                self.isCurrentUserHost = false
                print("❌ [權限檢查] 無法獲取用戶角色: \(error.localizedDescription)")
            }
        }
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
    
    private func createMockGroups() -> [InvestmentGroup] {
        return [
            InvestmentGroup(id: UUID(), name: "科技股投資俱樂部", host: "張投資", returnRate: 15.5, entryFee: "10 代幣", memberCount: 25, category: "科技股", rules: "專注於台灣科技股，禁止投機短線操作，每日最多交易3次", tokenCost: 10, createdAt: Date(), updatedAt: Date()),
            InvestmentGroup(id: UUID(), name: "價值投資學院", host: "李分析師", returnRate: 12.3, entryFee: "20 代幣", memberCount: 18, category: "價值投資", rules: "長期持有策略，最少持股期間30天，重視基本面分析", tokenCost: 20, createdAt: Date(), updatedAt: Date()),
            InvestmentGroup(id: UUID(), name: "AI科技前瞻", host: "林未來", returnRate: 22.1, entryFee: "50 代幣", memberCount: 8, category: "科技股", rules: "專注AI、半導體相關股票，需定期分享投資心得", tokenCost: 50, createdAt: Date(), updatedAt: Date())
        ]
    }
    
    // For Debug Panel
    func fullResetAndResync() {
        // This is a placeholder for more complex logic if needed
        print("🔄 [DEBUG] Performing full reset and resync...")
        Task {
            await loadJoinedGroups()
        }
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
        
        // 額外的權限檢查：確保只有主持人能發送邀請
        guard isCurrentUserHost else {
            await MainActor.run {
                self.errorMessage = "只有群組主持人才能邀請新成員"
                self.showError = true
            }
            return
        }
        
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
                    Task {
                        await loadJoinedGroups(forceReload: true)
                    }
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
                        
                        // 在聊天中發送交易通知
                        sendTradeAnnouncement(symbol: symbolToAnnounce, amount: amount, action: tradeAction)
                    } else {
                        handleError(NSError(domain: "TradeError", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "交易失敗"]), context: "交易執行失敗")
                    }
                }
                
            } catch {
                await MainActor.run {
                    handleError(error, context: "交易執行失敗")
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
    
    // MARK: - 捐贈排行榜功能
    
    /// 載入群組捐贈排行榜
    func loadDonationLeaderboard() {
        guard let groupId = selectedGroupId else { 
            print("❌ [排行榜] 沒有選中的群組")
            return 
        }
        
        isLoadingLeaderboard = true
        
        _Concurrency.Task { @MainActor in
            do {
                let leaderboard = try await supabaseService.fetchGroupDonationLeaderboard(groupId: groupId)
                self.donationLeaderboard = leaderboard
                self.isLoadingLeaderboard = false
                print("✅ [排行榜] 載入捐贈排行榜成功: \(leaderboard.count) 位捐贈者")
            } catch {
                self.isLoadingLeaderboard = false
                print("❌ [排行榜] 載入失敗: \(error.localizedDescription)")
            }
        }
    }
    
    /// 切換排行榜顯示狀態
    func toggleDonationLeaderboard() {
        showDonationLeaderboard.toggle()
        if showDonationLeaderboard {
            loadDonationLeaderboard()
        }
    }
    
    // MARK: - 禮物選擇流程
    
    /// 選擇禮物並進入數量選擇
    func selectGift(_ gift: GiftItem) {
        if selectedGift?.id == gift.id {
            // 如果已選中同一個禮物，則取消選擇
            selectedGift = nil
            giftQuantity = 1
        } else {
            // 選擇新禮物
            selectedGift = gift
            giftQuantity = 1
        }
    }
    
    
    /// 取消禮物選擇流程
    func cancelGiftSelection() {
        selectedGift = nil
        giftQuantity = 1
        showGiftConfirmation = false
    }
    
    /// 完成禮物送出
    func confirmGiftPurchase() {
        guard let gift = selectedGift else { return }
        
        let totalAmount = Double(gift.price) * Double(giftQuantity)
        performTip(amount: totalAmount, giftItem: gift, quantity: giftQuantity)
        
        // 重置狀態
        cancelGiftSelection()
        showGiftModal = false
    }
    
    // MARK: - 儲值卡片功能
    
    /// 關閉儲值卡片
    func dismissTopUpCard() {
        showTopUpCard = false
        requiredAmount = 0
    }
    
    /// 前往儲值頁面
    func goToTopUpPage() {
        dismissTopUpCard()
        // 發送通知跳轉到錢包頁面
        NotificationCenter.default.post(name: NSNotification.Name("ShowWalletForTopUp"), object: nil)
    }
    
    // MARK: - 錯誤處理和用戶反饋
    
    /// 統一錯誤處理方法
    func handleError(_ error: Error?, context: String) {
        let errorMessage: String
        
        if let error = error {
            switch error {
            case let supabaseError as SupabaseError:
                switch supabaseError {
                case .unknown(let message):
                    if message.contains("餘額不足") {
                        errorMessage = "餘額不足，請先充值後再試！💰"
                    } else {
                        errorMessage = "\(context): \(message)"
                    }
                case .notAuthenticated:
                    errorMessage = "請先登入後再進行操作 🔐"
                default:
                    errorMessage = "\(context): 服務暫時無法使用，請稍後再試"
                }
            default:
                if error.localizedDescription.contains("網路") || error.localizedDescription.contains("network") {
                    errorMessage = "\(context): 網路連線異常，請檢查網路連線 📶"
                } else {
                    errorMessage = "\(context): \(error.localizedDescription)"
                }
            }
        } else {
            errorMessage = context
        }
        
        // 設置錯誤消息並顯示
        self.errorMessage = errorMessage
        self.showErrorAlert = true
        
        // 自動清除錯誤消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.errorMessage == errorMessage {
                self.errorMessage = nil
                self.showErrorAlert = false
            }
        }
        
        print("❌ [ChatViewModel] \(errorMessage)")
    }
    
    /// 顯示成功反饋
    func showSuccessMessage(_ message: String) {
        self.successMessage = message
        self.showSuccessAlert = true
        
        // 自動清除成功消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.successMessage == message {
                self.successMessage = nil
                self.showSuccessAlert = false
            }
        }
        
        print("✅ [ChatViewModel] \(message)")
    }

} 
