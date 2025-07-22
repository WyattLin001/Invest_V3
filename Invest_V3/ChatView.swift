//
//  ChatView.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/7/9.
//
import SwiftUI

// MARK: - ChatMessage 擴展 (UI-related logic can stay here)
extension ChatMessage {
    var isOwn: Bool {
        // This logic is now better handled inside the ViewModel or by passing the current user ID.
        // For now, we'll leave it but it's a candidate for refactoring.
        if let data = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return senderId == user.id
        }
        return false
    }
    
    var time: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: createdAt)
    }
}

// MARK: - 主要 ChatView
struct ChatView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel = ChatViewModel() // The single source of truth
    
    let preselectedGroupId: UUID?
    
    init(preselectedGroupId: UUID? = nil) {
        self.preselectedGroupId = preselectedGroupId
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showGroupSelection {
                    groupSelectionView
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                } else {
                    chatRoomView
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: viewModel.showGroupSelection)
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setup(authService: authService)
        }
        .onChange(of: preselectedGroupId) { groupId in
            if let groupId = groupId {
                // 收到預選群組 ID（靜默）
                Task {
                    await viewModel.selectGroup(groupId: groupId)
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    // Debug panel removed
                }
            }
        )
        .alert("錯誤", isPresented: $viewModel.showError) {
            Button("確定") { }
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
        .sheet(isPresented: $viewModel.showGiftModal) { giftModalView }
        .alert("確認送出禮物", isPresented: $viewModel.showGiftConfirmation) { giftConfirmationAlert }
        .sheet(isPresented: $viewModel.showInfoModal) { infoModalView }
        .sheet(isPresented: $viewModel.showInviteSheet) { inviteSheetView }
        .sheet(isPresented: $viewModel.showDonationLeaderboard) { donationLeaderboardView }
        .sheet(isPresented: $viewModel.showInvestmentPanel) {
            InvestmentPanelView(
                portfolioManager: ChatPortfolioManager.shared,
                stockSymbol: $viewModel.stockSymbol,
                tradeAmount: $viewModel.tradeAmount,
                tradeAction: $viewModel.tradeAction,
                showTradeSuccess: $viewModel.showTradeSuccess,
                tradeSuccessMessage: $viewModel.tradeSuccessMessage,
                onExecuteTrade: {
                    viewModel.executeTrade()
                },
                onClose: {
                    viewModel.showInvestmentPanel = false
                }
            )
        }
    }
    
    // MARK: - Subviews (now read from viewModel)
    
    private var groupSelectionView: some View {
        VStack(spacing: 0) {
            // 頂部標題
            HStack {
                Text("聊天")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.gray900)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // 搜尋欄
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.gray600)
                    
                    TextField("搜尋群組...", text: $viewModel.searchText)
                        .font(.body)
                        .onChange(of: viewModel.searchText) { _, newValue in
                            viewModel.filterGroups()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .frame(width: 343, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 群組列表
            if viewModel.isLoadingGroups {
                Spacer()
                ProgressView("載入群組中...")
                    .foregroundColor(.gray600)
                Spacer()
            } else if viewModel.filteredGroups.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.gray400)
                    
                    if !viewModel.isConnected {
                        Text("連線問題")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(viewModel.connectionStatus)
                            .font(.body)
                            .foregroundColor(.gray600)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("尚未加入任何群組")
                            .font(.headline)
                            .foregroundColor(.gray600)
                        Text("前往首頁探索投資群組")
                            .font(.body)
                            .foregroundColor(.gray500)
                    }
                    
                    // 診斷信息按鈕
                    #if DEBUG
                    Button("查看診斷信息") {
                        print("🔍 [診斷信息]\n\(viewModel.diagnosticInfo)")
                    }
                    .font(.caption)
                    .foregroundColor(.brandGreen)
                    #endif
                }
                Spacer()
            } else {
                List(viewModel.filteredGroups) { group in
                    GroupRowView(group: group) {
                        viewModel.selectGroup(group)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        // 錯誤和成功提示
        .alert("錯誤", isPresented: $viewModel.showErrorAlert) {
            Button("確定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("成功", isPresented: $viewModel.showSuccessAlert) {
            Button("確定", role: .cancel) {
                viewModel.successMessage = nil
            }
        } message: {
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
            }
        }
        .alert("餘額不足", isPresented: $viewModel.showInsufficientBalanceAlert) {
            Button("前往充值", role: .none) {
                // 注意：由於 ChatView 在 TabView 結構中，需要通過 NotificationCenter 來切換到錢包頁面
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToWallet"), object: nil)
                viewModel.showInsufficientBalanceAlert = false
            }
            Button("取消", role: .cancel) {
                viewModel.showInsufficientBalanceAlert = false
            }
        } message: {
            Text("您的餘額不足以購買此禮物，請先充值。")
        }
    }
    
    private var chatRoomView: some View {
        VStack(spacing: 0) {
            // 頂部導航欄
            topNavigationBar
            
            // 聊天訊息區域
            messagesSection
            
            // 底部輸入欄
            messageInputSection
        }
        .background(Color(.systemBackground))
        .overlay(
            // 禮物動畫覆蓋層 - 改善版
            Group {
                if viewModel.showGiftAnimation {
                    ZStack {
                        // 背景模糊效果
                        Color.black.opacity(0.1)
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                
                                // 主要禮物動畫
                                Text(viewModel.animatingGiftEmoji)
                                    .font(.system(size: 80))
                                    .scaleEffect(viewModel.showGiftAnimation ? 1.3 : 0.5)
                                    .rotationEffect(.degrees(viewModel.showGiftAnimation ? 360 : 0))
                                    .offset(viewModel.animatingGiftOffset)
                                    .opacity(viewModel.showGiftAnimation ? 1 : 0)
                                    .shadow(color: .brandGreen.opacity(0.6), radius: 15, x: 0, y: 5)
                                    .overlay(
                                        // 光環效果
                                        Circle()
                                            .stroke(Color.brandGreen.opacity(0.3), lineWidth: 3)
                                            .scaleEffect(viewModel.showGiftAnimation ? 2.0 : 0.5)
                                            .opacity(viewModel.showGiftAnimation ? 0 : 1)
                                    )
                                
                                Spacer()
                            }
                            
                            // 成功提示文字
                            if viewModel.showGiftAnimation {
                                Text("抖內成功！🎉")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandGreen)
                                    .scaleEffect(viewModel.showGiftAnimation ? 1.1 : 0.8)
                                    .opacity(viewModel.showGiftAnimation ? 1 : 0)
                                    .offset(y: viewModel.showGiftAnimation ? 0 : 20)
                                    .padding(.top, 20)
                            }
                            
                            Spacer()
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        )
    }
    
    private var topNavigationBar: some View {
        HStack {
            // 返回按鈕
            Button(action: viewModel.goBackToGroupSelection) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.brandGreen)
            }
            
            
            // 群組資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedGroup?.name ?? "載入中...")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                HStack(spacing: 8) {
                    Text("主持人：\(viewModel.groupDetails?.hostInfo?.displayName ?? viewModel.selectedGroup?.host ?? "未知")")
                        .font(.caption)
                        .foregroundColor(.gray600)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(viewModel.actualMemberCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.gray600)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // 邀請按鈕 (只有主持人才能顯示)
                if viewModel.isCurrentUserHost && viewModel.selectedGroup != nil {
                    Button(action: { viewModel.showInviteSheet = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(.brandBlue)
                    }
                }
                
                // 禮物按鈕
                Button(action: { viewModel.showGiftModal = true }) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.brandOrange)
                }
                
                // 資訊按鈕
                Button(action: { viewModel.showInfoModal = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.brandGreen)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private var messagesSection: some View {
        ScrollViewReader { proxy in
                    ScrollView {
                LazyVStack(spacing: 4) {
                    // 連線狀態提示
                    if !viewModel.isConnected {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "wifi.exclamationmark")
                                    .foregroundColor(.red)
                                Text("連線異常")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                    
                    if viewModel.isLoadingMessages {
                        HStack {
                            Spacer()
                            ProgressView("載入訊息中...")
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    } else if viewModel.messages.isEmpty {
                        // 空狀態提示 - 居中顯示
                        GeometryReader { geometry in
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray400)
                                
                                if !viewModel.isConnected {
                                    Text("未找到群組訊息")
                                        .font(.headline)
                                        .foregroundColor(.gray600)
                                    Text("請檢查連線或群組成員資格")
                                        .font(.body)
                                        .foregroundColor(.gray500)
                                        .multilineTextAlignment(.center)
                                    
                                    // 重新連線按鈕
                                    Button("重新檢查連線") {
                                        Task {
                                            await viewModel.performDiagnostics()
                                            if let groupId = viewModel.selectedGroupId {
                                                viewModel.loadChatMessages(for: groupId)
                                            }
                                        }
                                    }
                                    .font(.body)
                                    .foregroundColor(.brandGreen)
                                    .padding(.top, 4)
                                } else {
                                    Text("開始對話吧！")
                                        .font(.body)
                                        .foregroundColor(.gray500)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                        .frame(minHeight: 150)
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // 自動滾動到最新訊息
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messageInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // 投資面板按鈕 (只有主持人可見)
                if viewModel.isCurrentUserHost {
                    Button(action: { viewModel.showInvestmentPanel = true }) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // 文字輸入框
                HStack {
                    TextField("輸入訊息...", text: $viewModel.messageText, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...4)
                        .onChange(of: viewModel.messageText) { _, newValue in
                            // 即時儲存輸入內容
                            viewModel.lastMessageContent = newValue
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // 發送按鈕
                Button(action: viewModel.sendMessage) {
                    Image(systemName: viewModel.isSendingMessage ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 16))
                            .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray400 : Color.brandGreen)
                        .clipShape(Circle())
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private var giftConfirmationAlert: some View {
        Group {
            if let gift = viewModel.selectedGift {
                let totalCost = Double(gift.price) * Double(viewModel.giftQuantity)
                let totalNTD = totalCost * 100
                
                VStack {
                    Text("確定要送出 \(viewModel.giftQuantity) 個\(gift.name)嗎？")
                    Text("總計: \(Int(totalCost)) 金幣 (\(TokenSystem.formatCurrency(totalNTD)))")
                        .font(.subheadline)
                        .foregroundColor(.gray600)
                }
                
                Button("取消", role: .cancel) {
                    viewModel.cancelGiftSelection()
                }
                
                Button("確定送出") {
                    viewModel.confirmGiftPurchase()
                }
            } else {
                Button("確定") { }
                Button("取消", role: .cancel) { }
            }
        }
    }
    
    private var giftModalView: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 餘額顯示
                VStack(spacing: 8) {
                    Text("目前餘額")
                        .font(.headline)
                        .foregroundColor(.gray700)
                    
                    if viewModel.isLoadingBalance {
                        ProgressView()
                    } else {
                        Text("\(Int(viewModel.currentBalance)) 金幣")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGreen)
                        
                        Text("= \(TokenSystem.formatCurrency(viewModel.currentBalance * 100)) NTD")
                            .font(.caption)
                            .foregroundColor(.gray500)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 抖內選項
                Text("選擇抖內金額")
                    .font(.headline)
                    .foregroundColor(.gray700)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(GiftItem.defaultGifts) { gift in
                        GiftOptionViewWithQuantity(
                            gift: gift,
                            isAffordable: viewModel.currentBalance >= Double(gift.price),
                            isSelected: viewModel.selectedGift?.id == gift.id,
                            quantity: viewModel.selectedGift?.id == gift.id ? viewModel.giftQuantity : 1,
                            maxQuantity: Int(viewModel.currentBalance / Double(gift.price))
                        ) { action in
                            switch action {
                            case .select:
                                if viewModel.currentBalance >= Double(gift.price) {
                                    viewModel.selectGift(gift)
                                } else {
                                    viewModel.showGiftModal = false
                                    viewModel.showInsufficientBalanceAlert = true
                                }
                            case .increaseQuantity:
                                if viewModel.giftQuantity < 99 && 
                                   Double(gift.price) * Double(viewModel.giftQuantity + 1) <= viewModel.currentBalance {
                                    viewModel.giftQuantity += 1
                                }
                            case .decreaseQuantity:
                                if viewModel.giftQuantity > 1 {
                                    viewModel.giftQuantity -= 1
                                }
                            }
                        }
                    }
                }
                
                // 選中禮物時顯示確認按鈕
                if viewModel.selectedGift != nil {
                    VStack(spacing: 16) {
                        Divider()
                        
                        // 總計顯示
                        if let gift = viewModel.selectedGift {
                            let totalCost = Double(gift.price) * Double(viewModel.giftQuantity)
                            let totalNTD = totalCost * 100
                            
                            HStack {
                                Text("總計:")
                                    .font(.headline)
                                    .foregroundColor(.gray700)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(totalCost)) 金幣")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.brandGreen)
                                    
                                    Text("= \(TokenSystem.formatCurrency(totalNTD))")
                                        .font(.caption)
                                        .foregroundColor(.gray500)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // 確認按鈕
                        Button("確認送出") {
                            viewModel.showGiftConfirmation = true
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brandGreen)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("抖內禮物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        viewModel.showGiftModal = false
                    }
                }
            }
        }
    }
    
    private var infoModalView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 群組基本資訊
                    VStack(alignment: .leading, spacing: 12) {
                        Text("群組資訊")
                            .font(.headline)
                            .foregroundColor(.gray900)
                        
                        InfoRow(title: "群組名稱", value: viewModel.selectedGroup?.name ?? "")
                        InfoRow(title: "主持人", value: viewModel.groupDetails?.hostInfo?.displayName ?? viewModel.selectedGroup?.host ?? "")
                        InfoRow(title: "成員數", value: "\(viewModel.selectedGroup?.memberCount ?? 0)")
                        InfoRow(title: "類別", value: viewModel.selectedGroup?.category ?? "")
                        InfoRow(title: "回報率", value: String(format: "%.1f%%", viewModel.selectedGroup?.returnRate ?? 0))
                        if let entryFee = viewModel.selectedGroup?.entryFee {
                            InfoRow(title: "入會費", value: entryFee)
                        }
                    }
                    
                    Divider()
                    
                    // 群組規定
                    VStack(alignment: .leading, spacing: 12) {
                        Text("群組規定")
                            .font(.headline)
                            .foregroundColor(.gray900)
                        
                        Text(viewModel.selectedGroup?.rules ?? "無特別規定")
                            .font(.body)
                            .foregroundColor(.gray700)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // 投資績效圖表
                    VStack(alignment: .leading, spacing: 12) {
                        Text("投資績效")
                            .font(.headline)
                            .foregroundColor(.gray900)
                        
                        // 績效圖表
                        VStack(spacing: 16) {
                            // 總績效顯示
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("總績效")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("+12.5%")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("當前投資")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$56,250")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // 績效線圖 (簡化版本)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("30 天績效趨勢")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray900)
                                
                                ZStack {
                                    // 背景網格
                                    Rectangle()
                                        .fill(Color(.systemGray6))
                                        .frame(height: 120)
                                        .cornerRadius(8)
                                    
                                    // 模擬績效線
                                    GeometryReader { geometry in
                                        Path { path in
                                            let width = geometry.size.width
                                            let height = geometry.size.height
                                            
                                            // 模擬數據點 (代表上升趨勢)
                                            let points: [(Double, Double)] = [
                                                (0.0, 0.7), (0.1, 0.65), (0.2, 0.6), (0.3, 0.55),
                                                (0.4, 0.5), (0.5, 0.45), (0.6, 0.4), (0.7, 0.35),
                                                (0.8, 0.3), (0.9, 0.25), (1.0, 0.2)
                                            ]
                                            
                                            for (index, point) in points.enumerated() {
                                                let x = point.0 * width
                                                let y = point.1 * height
                                                
                                                if index == 0 {
                                                    path.move(to: CGPoint(x: x, y: y))
                                                } else {
                                                    path.addLine(to: CGPoint(x: x, y: y))
                                                }
                                            }
                                        }
                                        .stroke(Color.green, lineWidth: 3)
                                        
                                        // 數據點
                                        ForEach(0..<11, id: \.self) { index in
                                            let x = Double(index) * 0.1 * geometry.size.width
                                            let y = (0.7 - Double(index) * 0.05) * geometry.size.height
                                            
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 6, height: 6)
                                                .position(x: x, y: y)
                                        }
                                    }
                                    .frame(height: 120)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                
                                // 時間軸標籤
                                HStack {
                                    Text("30天前")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("今天")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 捐贈排行榜
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("捐贈排行榜")
                                .font(.headline)
                                .foregroundColor(.gray900)
                            
                            Spacer()
                            
                            if viewModel.isLoadingLeaderboard {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        if viewModel.donationLeaderboard.isEmpty && !viewModel.isLoadingLeaderboard {
                            // 空狀態
                            VStack(spacing: 8) {
                                Image(systemName: "heart.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray400)
                                
                                Text("還沒有人抖內")
                                    .font(.subheadline)
                                    .foregroundColor(.gray500)
                                    .fontWeight(.medium)
                                
                                Text("成為第一個支持主持人的人吧！")
                                    .font(.caption)
                                    .foregroundColor(.gray400)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            // 排行榜列表
                            LazyVStack(spacing: 8) {
                                ForEach(Array(viewModel.donationLeaderboard.prefix(5).enumerated()), id: \.element.id) { index, donor in
                                    DonorRankingRow(
                                        rank: index + 1,
                                        donor: donor,
                                        isTopDonor: index == 0
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // 顯示更多按鈕（如果有超過5個捐贈者）
                            if viewModel.donationLeaderboard.count > 5 {
                                Button(action: {
                                    viewModel.showDonationLeaderboard = true
                                }) {
                                    HStack {
                                        Text("查看完整排行榜")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.brandGreen)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 退出群組按鈕 (危險操作)
                    Button(role: .destructive) {
                        viewModel.showLeaveGroupAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("退出群組")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandOrange)
                        .cornerRadius(12)
                    }
                    
                    // 清除聊天記錄按鈕 (危險操作)
                    Button(role: .destructive) {
                        viewModel.showClearChatAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("清除聊天記錄")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.danger)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("群組詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        viewModel.showInfoModal = false
                    }
                }
            }
            .onAppear {
                // 當群組詳情頁面出現時，載入捐贈排行榜
                viewModel.loadDonationLeaderboard()
            }
        }
        .alert("確認清除", isPresented: $viewModel.showClearChatAlert, actions: {
            Button("清除", role: .destructive) {
                viewModel.clearChatHistory()
            }
            Button("取消", role: .cancel) {}
        }, message: {
            Text("您確定要刪除此群組中的所有訊息嗎？此操作無法復原。")
        })
        .alert("確認退出", isPresented: $viewModel.showLeaveGroupAlert, actions: {
            Button("退出", role: .destructive) {
                viewModel.leaveGroup()
            }
            Button("取消", role: .cancel) {}
        }, message: {
            Text("您確定要退出此群組嗎？退出後將無法查看群組訊息，且您的投資組合資料將被刪除。")
        })
    }
    
    // MARK: - 邀請面板視圖
    private var inviteSheetView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 標題
                VStack(spacing: 8) {
                    Text("邀請成員")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    
                    Text("邀請其他用戶加入群組")
                        .font(.body)
                        .foregroundColor(.gray600)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // 模式切換
                Picker("邀請模式", selection: $viewModel.inviteMode) {
                    ForEach(ChatViewModel.InviteMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 內容區域
                if viewModel.inviteMode == .friends {
                    friendsSelectionView
                } else {
                    emailInputView
                }
                
                Spacer()
                
                // 發送邀請按鈕
                Button(action: {
                    Task {
                        await viewModel.sendInvitation()
                    }
                }) {
                    HStack {
                        if viewModel.isSendingInvitation {
                            ProgressView()
                                .progressViewStyle(.circular)
                            .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        
                        Text(viewModel.isSendingInvitation ? "發送中..." : "發送邀請")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSendInvitation ? Color.brandBlue : Color.gray400)
                    .cornerRadius(12)
                }
                .disabled(!canSendInvitation || viewModel.isSendingInvitation)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("邀請成員")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        viewModel.showInviteSheet = false
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadFriends()
                }
            }
        }
    }
    
    // 好友選擇視圖
    private var friendsSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("選擇好友")
                .font(.headline)
                .foregroundColor(.gray900)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            if viewModel.friends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.gray400)
                    
                    Text("暫無好友")
                        .font(.body)
                        .foregroundColor(.gray600)
                    
                    Text("您可以使用 Email 邀請功能")
                        .font(.caption)
                        .foregroundColor(.gray500)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.friends) { friend in
                            HStack(spacing: 12) {
                                // 好友頭像
                                Circle()
                                    .fill(Color.brandGreen.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(friend.displayName.prefix(1)))
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.brandGreen)
                                    )
                                
                                // 好友信息
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray900)
                                    
                                    Text(friend.email)
                                        .font(.caption)
                                        .foregroundColor(.gray600)
                                }
                                
                                Spacer()
                                
                                // 選擇框
                                Button(action: {
                                    if viewModel.selectedFriendIds.contains(friend.id) {
                                        viewModel.selectedFriendIds.remove(friend.id)
                                    } else {
                                        viewModel.selectedFriendIds.insert(friend.id)
                                    }
                                }) {
                                    Image(systemName: viewModel.selectedFriendIds.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(viewModel.selectedFriendIds.contains(friend.id) ? .brandGreen : .gray400)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
    
    // Email 輸入視圖
    private var emailInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("受邀者 Email")
                .font(.headline)
                .foregroundColor(.gray900)
            
            TextField("輸入 Email 地址", text: $viewModel.inviteEmail)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // 計算是否可以發送邀請
    private var canSendInvitation: Bool {
        switch viewModel.inviteMode {
        case .friends:
            return !viewModel.selectedFriendIds.isEmpty
        case .email:
            return !viewModel.inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - 完整捐贈排行榜視圖
    private var donationLeaderboardView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 排行榜標題和統計
                    VStack(alignment: .leading, spacing: 12) {
                        Text("捐贈排行榜")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.gray900)
                        
                        if let groupName = viewModel.selectedGroup?.name {
                            Text("群組「\(groupName)」")
                                .font(.subheadline)
                                .foregroundColor(.gray600)
                        }
                        
                        // 統計信息
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("總捐贈者")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text("\(viewModel.donationLeaderboard.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandGreen)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("總捐贈額")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text("\(viewModel.donationLeaderboard.reduce(0) { $0 + $1.totalAmount }) 代幣")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandGreen)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 排行榜列表
                    if viewModel.donationLeaderboard.isEmpty && !viewModel.isLoadingLeaderboard {
                        // 空狀態
                        VStack(spacing: 16) {
                            Image(systemName: "heart.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray400)
                            
                            Text("還沒有人抖內")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.gray600)
                            
                            Text("成為第一個支持主持人的人吧！")
                                .font(.body)
                                .foregroundColor(.gray500)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.donationLeaderboard.enumerated()), id: \.element.id) { index, donor in
                                DonorRankingRow(
                                    rank: index + 1,
                                    donor: donor,
                                    isTopDonor: index == 0
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("排行榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        viewModel.showDonationLeaderboard = false
                    }
                }
            }
            .refreshable {
                viewModel.loadDonationLeaderboard()
            }
        }
    }
}

// MARK: - 群組行視圖
struct GroupRowView: View {
    let group: InvestmentGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 群組頭像
                ZStack {
                    Circle()
                        .fill(Color.brandGreen.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Text(String(group.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                }
                
                // 群組資訊
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("昨天")
                            .font(.caption)
                            .foregroundColor(.gray500)
                    }
                    
            HStack {
                        Text("主持人：\(group.host)")
                            .font(.subheadline)
                            .foregroundColor(.gray600)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(group.memberCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.gray500)
                    }
                }
                
                // 右箭頭
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray400)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 聊天氣泡視圖
struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    
    // 根據用戶角色決定泡泡顏色
    private var bubbleColor: Color {
        if message.isOwn {
            // 自己的訊息：根據角色顯示不同顏色
            return message.isHost ? Color.blue : Color.green
        } else {
            // 其他人的訊息：根據發送者角色顯示不同顏色
            return message.isHost ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)
        }
    }
    
    // 根據用戶角色決定文字顏色
    private var textColor: Color {
        if message.isOwn {
            return .white
        } else {
            return colorScheme == .dark ? Color(hex: "#E0E0E0") : Color(hex: "#000000")
        }
    }
    
    // 根據用戶角色決定背景顏色（深色模式支援）
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(hex: "#121212")
        } else {
            return Color(hex: "#FFFFFF")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isOwn {
                Spacer(minLength: 50)
                
                // 自己的訊息 - 右側
                VStack(alignment: .trailing, spacing: 4) {
                    // 發送者名稱和角色標示
                    HStack(spacing: 4) {
                        // 角色標示
                        if message.isHost {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        
                        Text(message.senderName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(message.isHost ? .blue : .green)
                    }
                    
                    // 訊息泡泡
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(bubbleColor)
                        .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                        .overlay(
                            // 投資指令標示
                            Group {
                                if message.isCommand {
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.top, 4)
                                }
                            }
                        )
                    
                    // 時間
                    Text(message.time)
                        .font(.caption2)
                        .foregroundColor(.gray500)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                
            } else {
                // 其他人的訊息 - 左側
                VStack(alignment: .leading, spacing: 4) {
                    // 發送者名稱、角色標示和時間
                    HStack(spacing: 4) {
                        // 角色標示
                        if message.isHost {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        
                        Text(message.senderName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(message.isHost ? .blue : .green)
                        
                        Text(message.time)
                            .font(.caption2)
                            .foregroundColor(.gray500)
                        
                        Spacer()
                    }
                    
                    // 訊息內容
                    HStack {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(bubbleColor)
                            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
                            .overlay(
                                // 投資指令標示
                                Group {
                                    if message.isCommand {
                                        HStack {
                                            Image(systemName: "chart.line.uptrend.xyaxis")
                                                .font(.caption)
                                                .foregroundColor(message.isHost ? .blue : .green)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.top, 4)
                                    }
                                }
                            )
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 50)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 16)
    }
}

// MARK: - 禮物選項視圖
struct GiftOptionView: View {
    let gift: GiftItem
    let isAffordable: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(gift.icon)
                    .font(.system(size: 28))
                
                Text(gift.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isAffordable ? .gray900 : .gray400)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(gift.price)) 金幣")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isAffordable ? .brandGreen : .gray400)
                
                Text("= \(TokenSystem.formatCurrency(Double(gift.price * 100)))")
                    .font(.caption)
                    .foregroundColor(.gray500)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(12)
            .background(isAffordable ? Color(.systemGray6) : Color(.systemGray5))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isAffordable ? Color.brandGreen : Color.gray300, lineWidth: isAffordable ? 2 : 1)
            )
            .scaleEffect(isAffordable ? 1.0 : 0.95)
            .opacity(isAffordable ? 1.0 : 0.6)
        }
        .disabled(!isAffordable)
    }
}

// MARK: - 帶數量選擇的禮物視圖
enum GiftAction {
    case select
    case increaseQuantity
    case decreaseQuantity
}

struct GiftOptionViewWithQuantity: View {
    let gift: GiftItem
    let isAffordable: Bool
    let isSelected: Bool
    let quantity: Int
    let maxQuantity: Int
    let onAction: (GiftAction) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 原有的禮物信息
            Button(action: { onAction(.select) }) {
                VStack(spacing: 6) {
                    Text(gift.icon)
                        .font(.system(size: 28))
                    
                    Text(gift.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isAffordable ? .gray900 : .gray400)
                        .multilineTextAlignment(.center)
                    
                    Text("\(Int(gift.price)) 金幣")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isAffordable ? .brandGreen : .gray400)
                    
                    Text("= \(TokenSystem.formatCurrency(Double(gift.price * 100)))")
                        .font(.caption)
                        .foregroundColor(.gray500)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(12)
                .background(isAffordable ? Color(.systemGray6) : Color(.systemGray5))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.brandGreen : (isAffordable ? Color.brandGreen : Color.gray300),
                            lineWidth: isSelected ? 3 : (isAffordable ? 2 : 1)
                        )
                )
                .scaleEffect(isAffordable ? 1.0 : 0.95)
                .opacity(isAffordable ? 1.0 : 0.6)
            }
            .disabled(!isAffordable)
            
            // 數量選擇器（僅在選中且可負擔時顯示）
            if isSelected && isAffordable {
                HStack(spacing: 12) {
                    // 減少按鈕
                    Button(action: { onAction(.decreaseQuantity) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(quantity > 1 ? .brandGreen : .gray400)
                    }
                    .disabled(quantity <= 1)
                    
                    // 數量顯示
                    Text("\(quantity)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                        .frame(minWidth: 30)
                    
                    // 增加按鈕
                    Button(action: { onAction(.increaseQuantity) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(
                                (quantity < maxQuantity && quantity < 99) ? .brandGreen : .gray400
                            )
                    }
                    .disabled(quantity >= maxQuantity || quantity >= 99)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.brandGreen.opacity(0.1))
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
    }
}

// MARK: - 資訊行視圖
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.gray600)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.gray900)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 投資面板視圖
extension ChatView {
    private var investmentPanelView: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 投資組合標題
                VStack(spacing: 8) {
                    Text("投資組合")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
    
                    
                    Divider()
                        .background(Color(.separator))
                }
                .padding(.top, 20)
                
                // 投資組合圓形圖表
                VStack(spacing: 16) {
                    ZStack {
                        // 背景圓圈
                        Circle()
                            .stroke(Color(.systemGray6), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        // 動態投資比例圓圈
                        if !viewModel.portfolioManager.holdings.isEmpty {
                            ForEach(Array(viewModel.portfolioManager.portfolioPercentages.enumerated()), id: \.offset) { index, item in
                                let (symbol, percentage, color) = item
                                let startAngle = viewModel.portfolioManager.portfolioPercentages.prefix(index).reduce(0) { $0 + $1.1 }
                                let endAngle = startAngle + percentage
                                
                                Circle()
                                    .trim(from: startAngle, to: endAngle)
                                    .stroke(color, lineWidth: 8)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        
                        // 中心總金額
                        VStack(spacing: 2) {
                            Text("總投資")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(Int(viewModel.portfolioManager.totalPortfolioValue))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // 動態圖例
                    VStack(spacing: 8) {
                        ForEach(viewModel.portfolioManager.holdings) { holding in
                            HStack {
                                Circle()
                                    .fill(colorForSymbol(holding.symbol))
                                    .frame(width: 12, height: 12)
                                Text(holding.symbol)
                                    .font(.caption)
                                Spacer()
                                Text("$\(Int(holding.totalValue))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // 顯示可用餘額
                        HStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 12, height: 12)
                            Text("可用餘額")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(Int(viewModel.portfolioManager.availableBalance))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // 股票交易區域
                VStack(spacing: 16) {
                    Text("股票交易")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // 輸入欄位
                    HStack(spacing: 12) {
                        // 股票代號
                        TextField("股票代號", text: $viewModel.stockSymbol)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .autocapitalization(.allCharacters)
                        
                        // 金額或股數
                        TextField(viewModel.tradeAction == "buy" ? "金額" : "股數", text: $viewModel.tradeAmount)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        
                        // 買入/賣出選擇器
                        Picker("操作", selection: $viewModel.tradeAction) {
                            Text("買入").tag("buy")
                            Text("賣出").tag("sell")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    
                    // 交易驗證提示
                    if !viewModel.stockSymbol.isEmpty && !viewModel.tradeAmount.isEmpty {
                        let canTrade = validateTrade()
                        if !canTrade.isValid {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(canTrade.message)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // 執行交易按鈕
                    Button(action: {
                        viewModel.executeTrade()
                    }) {
                        HStack {
                            Image(systemName: viewModel.tradeAction == "buy" ? "plus.circle.fill" : "minus.circle.fill")
                            Text(viewModel.tradeAction == "buy" ? "買入" : "賣出")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canTradeNow() ? (viewModel.tradeAction == "buy" ? Color.green : Color.red) : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canTradeNow())
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("投資面板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        viewModel.showInvestmentPanel = false
                    }
                }
            }
        }
        .alert("交易成功！", isPresented: $viewModel.showTradeSuccess) {
            Button("確認") {
                viewModel.showTradeSuccess = false
                viewModel.showInvestmentPanel = false
            }
        } message: {
            Text(viewModel.tradeSuccessMessage)
        }
    }
    
    // MARK: - Trade Validation Functions
    
    private func validateTrade() -> (isValid: Bool, message: String) {
        guard !viewModel.stockSymbol.isEmpty,
              !viewModel.tradeAmount.isEmpty,
              let amount = Double(viewModel.tradeAmount) else {
            return (false, "請輸入有效的股票代號和金額")
        }
        
        if viewModel.tradeAction == "buy" {
            if amount > viewModel.portfolioManager.availableBalance {
                return (false, "餘額不足，可用餘額：$\(Int(viewModel.portfolioManager.availableBalance))")
            }
        } else {
            // 賣出驗證
            if let holding = viewModel.portfolioManager.holdings.first(where: { $0.symbol == viewModel.stockSymbol.uppercased() }) {
                if amount > Double(holding.quantity) {
                    return (false, "持股不足，目前持有：\(holding.quantity) 股")
                }
            } else {
                return (false, "未持有此股票")
            }
        }
        
        return (true, "")
    }
    
    private func canTradeNow() -> Bool {
        guard !viewModel.stockSymbol.isEmpty,
              !viewModel.tradeAmount.isEmpty else {
            return false
        }
        
        return validateTrade().isValid
    }
    
    private func colorForSymbol(_ symbol: String) -> Color {
        switch symbol {
        case "AAPL": return .blue
        case "TSLA": return .orange
        case "NVDA": return .green
        case "GOOGL": return .red
        case "MSFT": return .purple
        default: return .blue
        }
    }
}

// MARK: - 捐贈排行榜行組件
struct DonorRankingRow: View {
    let rank: Int
    let donor: DonationSummary
    let isTopDonor: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 28, height: 28)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(rankTextColor)
            }
            
            // 捐贈者信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(donor.donorName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray900)
                    
                    if isTopDonor {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text("共 \(donor.donationCount) 次抖內")
                    .font(.caption)
                    .foregroundColor(.gray500)
            }
            
            Spacer()
            
            // 總金額
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(donor.totalAmount) 代幣")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGreen)
                
                Text(donor.formattedLastDonationDate)
                    .font(.caption)
                    .foregroundColor(.gray400)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isTopDonor ? Color.brandGreen.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .brandGreen.opacity(0.3)
        }
    }
    
    private var rankTextColor: Color {
        switch rank {
        case 1, 2, 3: return .white
        default: return .brandGreen
        }
    }
}


// MARK: - Preview
#Preview {
    ChatView()
        .environmentObject(AuthenticationService.shared)
}
