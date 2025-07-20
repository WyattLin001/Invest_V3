//
//  HomeView.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//
import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var showNotifications = false // 通知彈窗狀態
    @State private var showSearch = false // 搜尋彈窗狀態
    @State private var showJoinGroupSheet = false
    @State private var selectedRankingUser: TradingUserRanking?
    @State private var selectedGroup: InvestmentGroup?
    @State private var walletBalance: Double = 0.0
    @State private var isLoadingBalance = false
    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false
    @State private var showInsufficientBalanceAlert = false
    @State private var showWalletView = false
    @State private var showCreateGroupView = false
    

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // 頂部餘額列 (Safe-area top 54 pt)
                        balanceHeader
                        
                        // 邀請 Banner (B線功能)
                        invitationBanner
                        
                        // 排行榜區塊 (替換原來的冠軍輪播)
                        rankingSection
                        
                        // 群組列表
                        groupsList
                    }
                }
                .background(Color.gray100)
                .navigationBarHidden(true)
                .ignoresSafeArea(.container, edges: .top) // 忽略頂部安全區域
                .refreshable {
                    await viewModel.loadData()
                    await loadWalletBalance()
                }
                
                // 創建群組浮動按鈕
                createGroupFloatingButton
            }
            .sheet(isPresented: $showNotifications) {
                NotificationView()
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .sheet(isPresented: $showJoinGroupSheet) {
                if let user = selectedRankingUser {
                    JoinGroupRequestView(user: user)
                }
            }
            .sheet(isPresented: $showCreateGroupView) {
                CreateGroupView()
            }
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("確定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "發生未知錯誤")
        }
        .alert("成功", isPresented: $showSuccessAlert) {
            Button("確定", role: .cancel) {
                viewModel.successMessage = nil
            }
        } message: {
            Text(viewModel.successMessage ?? "操作成功")
        }
        .alert("餘額不足", isPresented: $showInsufficientBalanceAlert) {
            Button("去加值", role: .none) {
                showWalletView = true
                viewModel.errorMessage = nil
            }
            Button("取消", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text("您的代幣餘額不足以加入此群組。是否前往加值？")
        }
        .sheet(isPresented: $showWalletView) {
            WalletView()
        }
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
        .onReceive(viewModel.$errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                // 檢查是否為餘額不足錯誤
                if errorMessage.contains("餘額不足") {
                    showInsufficientBalanceAlert = true
                } else {
                    showErrorAlert = true
                }
            }
        }
        .onReceive(viewModel.$successMessage) { successMessage in
            showSuccessAlert = successMessage != nil
        }
        .onAppear {
            Task {
                // 第一次載入時初始化測試數據
                await viewModel.initializeTestData()
                await loadWalletBalance()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshGroupsList"))) { _ in
            Task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - 頂部餘額列
    var balanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("餘額")
                    .font(.caption)
                    .foregroundColor(.gray600)
                
                if isLoadingBalance {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("載入餘額中")
                } else {
                    HStack(spacing: 8) {
                        Text(TokenSystem.formatTokens(walletBalance))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray900)
                            .monospacedDigit()
                            .accessibilityLabel("目前餘額 \(Int(walletBalance)) 代幣")
                        
                        // 假充值按鈕
                        Button(action: { 
                            Task {
                                await fakeTopUp()
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.brandGreen)
                        }
                        .accessibilityLabel("充值")
                        .accessibilityHint("點擊增加 100 代幣到帳戶")
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // 投資按鈕 📈
                Button(action: { viewModel.showInvestmentPanel = true }) {
                    Text("📈")
                        .font(.title2)
                }
                .accessibilityLabel("投資")
                .accessibilityHint("開啟投資面板進行股票交易")
                
                // 通知按鈕
                Button(action: { showNotifications = true }) {
                    ZStack {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundColor(.gray600)
                        
                        // 紅色通知點
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
                .accessibilityLabel("通知")
                .accessibilityHint("查看最新通知和消息")
                
                // 搜尋按鈕
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.gray600)
                }
                .accessibilityLabel("搜尋")
                .accessibilityHint("搜尋投資群組和內容")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54) // Safe area top
        .padding(.bottom, 16)
        .background(Color.white)
    }
    
    // MARK: - 排行榜區塊
    var rankingSection: some View {
        VStack(spacing: 16) {
            // 時間週期選擇按鈕
            periodSelectionButtons
            
            // 排行榜內容區域
            rankingContentView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    private var periodSelectionButtons: some View {
        HStack(spacing: 12) {
            ForEach(RankingPeriod.allCases, id: \.self) { period in
                periodButton(for: period)
            }
        }
    }
    
    private func periodButton(for period: RankingPeriod) -> some View {
        let isSelected = viewModel.selectedPeriod == period
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.switchPeriod(to: period)
            }
        }) {
            Text(period.rawValue)
                .font(.footnote)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brandGreen : Color.gray200)
                .foregroundColor(isSelected ? .white : .gray600)
                .cornerRadius(20)
        }
        .accessibilityLabel(isSelected ? "目前選擇：\(period.rawValue)" : "切換至\(period.rawValue)")
        .accessibilityHint("查看\(period.rawValue)排行榜")
    }
    
    private var rankingContentView: some View {
        VStack {
            // 排行榜卡片 - 使用 TabView 實現輪播
            TabView {
                ForEach(Array(viewModel.currentRankings.prefix(3).enumerated()), id: \.element.id) { index, user in
                    Button(action: {
                        selectedRankingUser = user
                        showJoinGroupSheet = true
                    }) {
                        TradingRankingCard(user: user, selectedPeriod: viewModel.selectedPeriod)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("\(viewModel.selectedPeriod.rawValue) 第 \(user.rank) 名，\(user.name)，回報率 \(user.formattedReturnRate)")
                    .accessibilityHint("點擊查看詳細資料並申請加入群組")
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 190)
        }
    }
    
    
    // MARK: - 群組列表
    var groupsList: some View {
        LazyVStack(spacing: 16) { // 增加群組間距
            if viewModel.isLoading {
                // 載入中狀態
                loadingStateView
            } else if viewModel.investmentGroups.isEmpty {
                // 空狀態
                emptyStateView
            } else {
                // 正常顯示群組列表
                ForEach(viewModel.investmentGroups) { group in
                    GroupCard(
                        group: group,
                        isJoined: viewModel.joinedIds.contains(group.id)
                    ) {
                        // 加入群組動作
                        selectedGroup = group
                        Task {
                            await viewModel.joinGroup(group.id)
                            // 成功加入後自動跳轉到聊天室
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SwitchToChatTab"),
                                object: group.id
                            )
                            // 無障礙聲明
                            await MainActor.run {
                                UIAccessibility.post(notification: .announcement, 
                                                   argument: "成功加入 \(group.name) 群組")
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16) // 增加頂部間距
        .padding(.bottom, 32)
        .background(Color.gray100)
    }
    
    // MARK: - Helper Methods
    func getBadgeColor(for rank: Int) -> Color {
        switch rank {
        case 0: return Color(hex: "#FFD700") // 金
        case 1: return Color(hex: "#C0C0C0") // 銀
        case 2: return Color(hex: "#CD7F32") // 銅
        default: return .gray300
        }
    }
    
    // 載入錢包餘額
    private func loadWalletBalance() async {
        isLoadingBalance = true
        
        do {
            let balance = try await supabaseService.fetchWalletBalance()
            await MainActor.run {
                // balance 是從 user_balances 表獲取的 NTD 值，需要轉換為代幣顯示
                self.walletBalance = Double(balance).ntdToTokens()
                self.isLoadingBalance = false
            }
        } catch {
            await MainActor.run {
                // 如果無法獲取餘額，使用預設值
                self.walletBalance = 0.0
                self.isLoadingBalance = false
                print("❌ 載入錢包餘額失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // 假充值功能 - 增加 100 代幣（相當於 10000 NTD）
    private func fakeTopUp() async {
        do {
            // 增加 10000 NTD（相當於 100 代幣）
            try await supabaseService.updateWalletBalance(delta: 10000)
            
            await MainActor.run {
                // 直接更新顯示的代幣數量
                self.walletBalance += 100.0
                print("✅ [HomeView] 假充值成功: +100 代幣")
            }
        } catch {
            await MainActor.run {
                print("❌ [HomeView] 假充值失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Empty & Loading States
    
    var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.brandPrimary)
            
            Text("載入投資群組中...")
                .font(.headline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray400)
            
            VStack(spacing: 8) {
                Text("目前沒有可加入的投資群組")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Text("請稍後再來看看，或邀請朋友一起創建群組！")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await viewModel.loadData()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新載入")
                }
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.brandPrimary)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Create Group Floating Button
    private var createGroupFloatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    showCreateGroupView = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("創建群組")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.brandPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // 避免與底部 Tab Bar 重疊
            }
        }
    }
}

// MARK: - 排行榜卡片  
struct TradingRankingCard: View {
    let user: TradingUserRanking
    let selectedPeriod: RankingPeriod
    
    var periodText: String {
        switch selectedPeriod {
        case .weekly:
            return "本週冠軍"
        case .monthly:
            return "本月冠軍"
        case .quarterly:
            return "本季冠軍"
        case .yearly:
            return "本年冠軍"
        case .all:
            return "總榜冠軍"
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(user.badgeColor)
                    .frame(width: 50, height: 50)
                    .shadow(color: user.badgeColor.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // 獎牌圖案
                VStack(spacing: 1) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(user.rank)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // 用戶名 - 固定高度確保一致性
            Text(user.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 40) // 固定高度
            
            // 收益率 - 修復百分比顯示
            VStack(spacing: 4) {
                Text(String(format: "+%.1f%%", user.returnRate))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brandGreen)
                    .cornerRadius(12)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(periodText)
                    .font(.caption)
                    .foregroundColor(.gray600)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 170) // 增加最小高度以容納更多內容
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(user.borderColor, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 群組卡片
struct GroupCard: View {
    let group: InvestmentGroup
    let isJoined: Bool
    let onJoin: () -> Void
    
    // 根據代幣數量返回對應的圖示和文字
    private var entryFeeIcon: String {
        guard let fee = group.entryFee else { return "🆓" }
        return "🪙" // 統一使用代幣圖示
    }
    
    private var entryFeeText: String {
        guard let fee = group.entryFee else { return "免費" }
        
        if fee.contains("10") && !fee.contains("50") { // 10 代幣
            return "10 代幣"
        } else if fee.contains("20") { // 20 代幣
            return "20 代幣"
        } else if fee.contains("30") { // 30 代幣
            return "30 代幣"
        } else if fee.contains("50") { // 50 代幣
            return "50 代幣"
        } else {
            return "特殊資格"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 上半部：標題和主持人
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                        .lineLimit(1)
                    
                    Text("主持人: \(group.host)")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
                
                Spacer()
                
                // 加入群組按鈕
                Button(action: isJoined ? {} : onJoin) {
                    Text(isJoined ? "已加入" : "加入群組")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isJoined ? Color.gray400 : Color.brandOrange)
                        .cornerRadius(20)
                }
                .disabled(isJoined)
                .accessibilityLabel(isJoined ? "已加入群組" : "加入群組")
                .accessibilityHint(isJoined ? "您已經是這個群組的成員" : "點擊加入 \(group.name) 群組，\(entryFeeText)")
            }
            
            // 下半部：詳細資訊
            HStack {
                // 左側：回報率和分類
                VStack(alignment: .leading, spacing: 4) {
                    Text("回報率: +\(group.returnRate, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.brandGreen)
                    
                    if let category = group.category {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray200)
                            .foregroundColor(.gray600)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // 右側：入場費用（圖示替代）和成員數
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(entryFeeIcon)
                            .font(.system(size: 16))
                        
                        Text(entryFeeText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                    }
                    
                    Text("\(group.memberCount) 成員")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("投資群組 \(group.name)，主持人 \(group.host)，\(group.memberCount) 名成員，回報率 \(group.returnRate, specifier: "%.1f")%，入場費 \(entryFeeText)")
        .accessibilityHint("雙擊查看群組詳細資訊")
    }
}

// MARK: - 加入群組請求視圖
struct JoinGroupRequestView: View {
    let user: TradingUserRanking
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 用戶資訊
                VStack(spacing: 16) {
                    // 頭像和排名
                    ZStack {
                        Circle()
                            .fill(user.badgeColor)
                            .frame(width: 80, height: 80)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "medal.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(user.rank)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    
                    Text("回報率: +\(user.returnRate, specifier: "%.1f")%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandGreen)
                }
                
                // 加入資格
                VStack(alignment: .leading, spacing: 16) {
                    Text("加入資格要求")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                    
                    VStack(spacing: 12) {
                        requirementRow(icon: "🪙", title: "10 代幣", description: "支付群組入場費")
                        requirementRow(icon: "📈", title: "投資經驗", description: "至少完成3筆模擬交易")
                        requirementRow(icon: "🎯", title: "活躍度", description: "每週至少參與討論")
                    }
                }
                .padding(20)
                .background(Color.gray100)
                .cornerRadius(16)
                
                Spacer()
                
                // 按鈕
                VStack(spacing: 12) {
                    Button(action: {
                        // 發送加入請求
                        dismiss()
                    }) {
                        Text("發送加入請求")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandGreen)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("發送加入請求")
                    .accessibilityHint("向 \(user.name) 發送加入群組請求，需要支付 10 代幣")
                    
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.subheadline)
                            .foregroundColor(.gray600)
                    }
                    .accessibilityLabel("取消")
                    .accessibilityHint("關閉加入群組請求視窗")
                }
            }
            .padding(24)
            .navigationTitle("加入群組")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requirementRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray600)
            }
            
            Spacer()
        }
    }
}


// MARK: - HomeView 擴展
extension HomeView {
    // MARK: - 邀請 Banner (B線功能)
    var invitationBanner: some View {
        Group {
            if !viewModel.pendingInvitations.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.pendingInvitations) { invitation in
                        HStack(spacing: 12) {
                            // 邀請圖示
                            Image(systemName: "envelope.badge")
                                .font(.title2)
                                .foregroundColor(.brandBlue)
                            
                            // 邀請內容
                            VStack(alignment: .leading, spacing: 4) {
                                Text("群組邀請")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray900)
                                
                                Text("邀請您加入群組")
                                    .font(.body)
                                    .foregroundColor(.gray600)
                                
                                Text("邀請者: \(invitation.inviterName)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                            }
                            
                            Spacer()
                            
                            // 操作按鈕
                            HStack(spacing: 8) {
                                // 拒絕按鈕
                                Button(action: {
                                    Task {
                                        await viewModel.declineInvitation(invitation)
                                    }
                                }) {
                                    Text("拒絕")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray600)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray200)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isProcessingInvitation)
                                
                                // 接受按鈕
                                Button(action: {
                                    Task {
                                        await viewModel.acceptInvitation(invitation)
                                    }
                                }) {
                                    if viewModel.isProcessingInvitation {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("接受")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.brandGreen)
                                .cornerRadius(8)
                                .disabled(viewModel.isProcessingInvitation)
                            }
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.brandBlue.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
            }
        }
    }
}

#Preview {
    HomeView()
}
