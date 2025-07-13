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
        .sheet(isPresented: $viewModel.showInfoModal) { infoModalView }
        .sheet(isPresented: $viewModel.showInviteSheet) { inviteSheetView }
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
            // 禮物動畫覆蓋層
            Group {
                if viewModel.showGiftAnimation {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(viewModel.animatingGiftEmoji)
                                .font(.system(size: 60))
                                .offset(viewModel.animatingGiftOffset)
                                .opacity(viewModel.showGiftAnimation ? 1 : 0)
                            Spacer()
                        }
                        Spacer()
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
            
            // 模式切換
            Toggle(isOn: $viewModel.isHostMode) {
                Image(systemName: viewModel.isHostMode ? "person.badge.key.fill" : "person.fill")
                    .foregroundColor(viewModel.isHostMode ? .brandBlue : .gray)
            }
            .tint(.brandBlue)
            .padding(.trailing, 8)
            
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
                // 邀請按鈕 (只有主持人模式才顯示)
                if viewModel.isHostMode {
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
                .padding(.horizontal, 12)
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
                    ForEach([100, 200, 500, 1000, 2000, 5000], id: \.self) { amount in
                        GiftOptionView(
                            amount: amount,
                            isAffordable: viewModel.currentBalance >= Double(amount)
                        ) {
                            if viewModel.currentBalance >= Double(amount) {
                                // 執行抖內
                                viewModel.performTip(amount: Double(amount))
                            } else {
                                // 跳轉到錢包
                                viewModel.showGiftModal = false
                                // TODO: 跳轉到 WalletView
                            }
                        }
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
        HStack(alignment: .top, spacing: 4) {
            if message.isOwn {
                Spacer(minLength: 40)
                
                // 自己的訊息 - 右側
                VStack(alignment: .trailing, spacing: 4) {
                    // 訊息內容
                    VStack(alignment: .leading, spacing: 2) {
                        // 發送者名稱和角色標示
                        HStack(spacing: 4) {
                            Spacer()
                            
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
                    }
                    
                    // 時間
                    Text(message.time)
                        .font(.caption2)
                        .foregroundColor(.gray500)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                
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
                    VStack(alignment: .leading, spacing: 4) {
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
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: .leading)
                
                Spacer()
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - 禮物選項視圖
struct GiftOptionView: View {
    let amount: Int
    let isAffordable: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text("🎁")
                    .font(.system(size: 24))
                
                Text("\(amount) 金幣")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(isAffordable ? .gray900 : .gray400)
                
                Text("= \(TokenSystem.formatCurrency(Double(amount * 100)))")
                    .font(.caption)
                    .foregroundColor(.gray500)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(isAffordable ? Color(.systemGray6) : Color(.systemGray5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAffordable ? Color.brandGreen : Color.gray300, lineWidth: 1)
            )
        }
        .disabled(!isAffordable)
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

// MARK: - Preview
#Preview {
    ChatView()
        .environmentObject(AuthenticationService())
}
