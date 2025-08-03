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
    @State private var showFriendSearch = false // 好友搜尋頁面
    @State private var currentTournamentName = "2025年度投資錦標賽" // 當前錦標賽名稱
    @State private var showTournamentSwitcher = false // 錦標賽切換器
    @State private var showTournamentTest = false // 錦標賽測試界面
    @StateObject private var tournamentStateManager = TournamentStateManager.shared
    

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // 改進的頂部導航和餘額區域
                        balanceHeader
                        
                        // 投資動作區域
                        investmentActionSection
                        
                        // 群組系統測試區域 (開發/測試用)
                        #if DEBUG
                        groupSystemTestSection
                        #endif
                        
                        // 邀請 Banner (B線功能)
                        invitationBanner
                        
                        // 改進的排行榜區塊
                        improvedRankingSection
                        
                        // 群組列表
                        groupsList
                    }
                }
                .background(Color(.systemGroupedBackground))
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
            .sheet(isPresented: $showFriendSearch) {
                FriendsView()
                    .environmentObject(ThemeManager.shared)
                    .presentationBackground(Color.systemBackground)
            }
            .sheet(isPresented: $showTournamentSwitcher) {
                TournamentSwitcherView(currentTournament: $currentTournamentName)
            }
            .sheet(isPresented: $showTournamentTest) {
                TournamentTestView()
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
        .fullScreenCover(isPresented: $viewModel.showInvestmentPanel) {
            EnhancedInvestmentView(currentTournamentName: currentTournamentName)
                .environmentObject(ThemeManager.shared)
        }
        .onReceive(viewModel.$errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                // 延遲顯示警告框確保視圖層級正確
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 檢查是否為餘額不足錯誤
                    if errorMessage.contains("餘額不足") {
                        showInsufficientBalanceAlert = true
                    } else {
                        showErrorAlert = true
                    }
                }
            }
        }
        .onReceive(viewModel.$successMessage) { successMessage in
            if successMessage != nil {
                // 延遲顯示成功警告框確保視圖層級正確
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showSuccessAlert = true
                }
            }
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
    
    // MARK: - 改進的頂部導航區域
    var balanceHeader: some View {
        VStack(spacing: 0) {
            // 導航列
            HStack {
                // 左側：Logo 或 App 名稱
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundColor(.brandGreen)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("股圈")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray900)
                        
                        
                    }
                }
                
                Spacer()
                
                // 右側：精簡的操作按鈕
                HStack(spacing: 20) {
                    // 通知按鈕
                    Button(action: { showNotifications = true }) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.title3)
                                .foregroundColor(.primary)
                            
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
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("搜尋")
                    .accessibilityHint("搜尋投資群組和內容")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 54) // Safe area top
            .padding(.bottom, 16)
            
            // 錢包餘額區域 - 突出顯示
            walletBalanceCard
        }
        .background(Color.surfacePrimary)
    }
    
    // MARK: - 錢包餘額卡片
    private var walletBalanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("錢包餘額")
                        .font(.subheadline)
                        .foregroundColor(.gray600)
                    
                    if isLoadingBalance {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("載入中...")
                                .font(.body)
                                .foregroundColor(.gray500)
                        }
                        .accessibilityLabel("載入餘額中")
                    } else {
                        HStack(spacing: 12) {
                            Text(TokenSystem.formatTokens(walletBalance))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray900)
                                .monospacedDigit()
                                .accessibilityLabel("目前餘額 \(Int(walletBalance)) 代幣")
                            
                            // 快速充值按鈕
                            Button(action: { 
                                Task {
                                    await fakeTopUp()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                    Text("充值")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.brandGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brandGreen.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .accessibilityLabel("充值")
                            .accessibilityHint("點擊增加 100 代幣到帳戶")
                        }
                    }
                }
                
                Spacer()
                
                // 快速訪問按鈕
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Button(action: { showFriendSearch = true }) {
                            Image(systemName: "person.2.fill")
                                .font(.title3)
                                .foregroundColor(.brandGreen)
                        }
                        .accessibilityLabel("好友管理")
                        
                        Text("好友")
                            .font(.caption2)
                            .foregroundColor(.gray600)
                    }
                    
                    VStack(spacing: 8) {
                        Button(action: { showTournamentTest = true }) {
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                        .accessibilityLabel("錦標賽測試")
                        
                        Text("測試")
                            .font(.caption2)
                            .foregroundColor(.gray600)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surfaceSecondary)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - 投資動作區域
    private var investmentActionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("投資工具")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
                .accessibilityAddTraits(.isHeader)

            // 投資交易按鈕
            Button(action: {
                viewModel.showInvestmentPanel = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        if tournamentStateManager.isParticipatingInTournament {
                            Text("錦標賽交易")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text(tournamentStateManager.getCurrentTournamentDisplayName() ?? "參與中...")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        } else {
                            Text("投資交易")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("模擬股票交易")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)
                .frame(height: 64)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(tournamentStateManager.isParticipatingInTournament ? "錦標賽交易" : "投資交易")
                .accessibilityHint(tournamentStateManager.isParticipatingInTournament ? "開啟錦標賽交易界面" : "開啟投資面板進行模擬股票交易")
            }
        }
        .padding(.all, 20)
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    
    // MARK: - 改進的排行榜區塊
    var improvedRankingSection: some View {
        VStack(spacing: 20) {
            // 標題和週期選擇
            VStack(spacing: 16) {
                HStack {
                    Text("交易排行榜")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                    
                    Spacer()
                }
                
                // 時間週期選擇按鈕
                periodSelectionButtons
            }
            
            // 排行榜內容區域 - 垂直佈局
            improvedRankingContentView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    private var periodSelectionButtons: some View {
        HStack(spacing: 8) {
            ForEach(RankingPeriod.allCases, id: \.self) { period in
                periodButton(for: period)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    private func periodButton(for period: RankingPeriod) -> some View {
        let isSelected = viewModel.selectedPeriod == period
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.switchPeriod(to: period)
            }
        }) {
            Text(period.rawValue)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel(isSelected ? "目前選擇：\(period.rawValue)" : "切換至\(period.rawValue)")
        .accessibilityHint("查看\(period.rawValue)排行榜")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var improvedRankingContentView: some View {
        VStack(spacing: 12) {
            if viewModel.currentRankings.isEmpty {
                // 空狀態顯示
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray400)
                    
                    VStack(spacing: 8) {
                        Text("暫無排行榜資料")
                            .font(.headline)
                            .foregroundColor(.gray900)
                        
                        Text("等待更多用戶加入交易排行榜")
                            .font(.body)
                            .foregroundColor(.gray600)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 120)
            } else {
                // 垂直排行榜列表 - 更好的可讀性
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.currentRankings.prefix(3).enumerated()), id: \.offset) { index, user in
                        Button(action: {
                            selectedRankingUser = user
                            showJoinGroupSheet = true
                        }) {
                            ImprovedRankingRow(user: user, selectedPeriod: viewModel.selectedPeriod)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("\(viewModel.selectedPeriod.rawValue) 第 \(user.rank) 名，\(user.name)，回報率 \(user.formattedReturnRate)")
                        .accessibilityHint("點擊查看詳細資料並申請加入群組")
                    }
                    
                    // 如果少於3個用戶，顯示空位
                    ForEach(viewModel.currentRankings.count..<min(3, max(3, viewModel.currentRankings.count)), id: \.self) { index in
                        EmptyRankingRow(rank: index + 1, selectedPeriod: viewModel.selectedPeriod)
                    }
                }
            }
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
        .background(Color(.systemGroupedBackground))
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
                // balance 是從 user_balances 表獲取的代幣數量，直接使用
                self.walletBalance = balance
                self.isLoadingBalance = false
            }
        } catch {
            await MainActor.run {
                // 如果無法獲取餘額，使用預設值
                self.walletBalance = 0.0
                self.isLoadingBalance = false
                // 載入錢包餘額失敗
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
    
    // MARK: - Group System Test Section
    #if DEBUG
    private var groupSystemTestSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("開發測試")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("僅限開發模式")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
            
            InlineGroupTestWidget()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    #endif
    
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

// MARK: - 空位排行榜卡片
struct EmptyRankingCard: View {
    let rank: Int
    let selectedPeriod: RankingPeriod
    
    var periodText: String {
        switch selectedPeriod {
        case .weekly:
            return "本週第\(rank)名"
        case .monthly:
            return "本月第\(rank)名"
        case .quarterly:
            return "本季第\(rank)名"
        case .yearly:
            return "本年第\(rank)名"
        case .all:
            return "總榜第\(rank)名"
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(Color.gray300)
                    .frame(width: 50, height: 50)
                
                VStack(spacing: 1) {
                    Image(systemName: "medal")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray500)
                    
                    Text("\(rank)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray500)
                }
            }
            
            // 空位提示
            Text("虛位以待")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray500)
                .multilineTextAlignment(.center)
                .frame(height: 40)
            
            // 排名位置說明
            VStack(spacing: 4) {
                Text("暫無用戶")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray400)
                    .cornerRadius(12)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(periodText)
                    .font(.caption)
                    .foregroundColor(.gray500)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(width: 100, height: 150)
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray300, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 改進的排行榜列項目
struct ImprovedRankingRow: View {
    let user: TradingUserRanking
    let selectedPeriod: RankingPeriod
    
    var periodText: String {
        switch selectedPeriod {
        case .weekly:
            return "本週"
        case .monthly:
            return "本月"
        case .quarterly:
            return "本季"
        case .yearly:
            return "本年"
        case .all:
            return "總榜"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(user.badgeColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: user.badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("\(user.rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // 用戶資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                Text("\(periodText)排名")
                    .font(.caption)
                    .foregroundColor(.gray600)
            }
            
            Spacer()
            
            // 收益率
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "+%.1f%%", user.returnRate))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGreen)
                
                Text("回報率")
                    .font(.caption)
                    .foregroundColor(.gray600)
            }
            
            // 箭頭指示器
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray400)
        }
        .padding(16)
        .background(Color.surfaceSecondary.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(user.badgeColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 空排行榜列項目
struct EmptyRankingRow: View {
    let rank: Int
    let selectedPeriod: RankingPeriod
    
    var periodText: String {
        switch selectedPeriod {
        case .weekly:
            return "本週"
        case .monthly:
            return "本月"
        case .quarterly:
            return "本季"
        case .yearly:
            return "本年"
        case .all:
            return "總榜"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(Color.gray300)
                    .frame(width: 44, height: 44)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray500)
            }
            
            // 空位資訊
            VStack(alignment: .leading, spacing: 4) {
                Text("虛位以待")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray500)
                
                Text("\(periodText)第\(rank)名")
                    .font(.caption)
                    .foregroundColor(.gray400)
            }
            
            Spacer()
            
            // 佔位符
            VStack(alignment: .trailing, spacing: 4) {
                Text("--")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray400)
                
                Text("回報率")
                    .font(.caption)
                    .foregroundColor(.gray400)
            }
        }
        .padding(16)
        .background(Color.surfaceSecondary.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray300.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - 原始排行榜卡片（保留兼容性）
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
        .padding(6)
        .frame(width: 100, height: 150)
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(user.borderColor, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
                            .background(Color.surfaceTertiary)
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
        .background(Color.surfacePrimary)
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
                .background(Color.surfaceSecondary)
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
                                        .background(Color.surfaceTertiary)
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
                .background(Color.surfacePrimary)
            }
        }
    }
}

// MARK: - 錦標賽切換器視圖
struct TournamentSwitcherView: View {
    @Binding var currentTournament: String
    @Environment(\.dismiss) private var dismiss
    
    private let availableTournaments = [
        "2025年度投資錦標賽",
        "2025第一季錦標賽",
        "新手投資挑戰賽",
        "專業投資競技賽"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 標題說明
                VStack(spacing: 12) {
                    Text("選擇錦標賽")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    
                    Text("選擇您想要參加的投資錦標賽")
                        .font(.body)
                        .foregroundColor(.gray600)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 錦標賽列表
                VStack(spacing: 16) {
                    ForEach(availableTournaments, id: \.self) { tournament in
                        Button(action: {
                            currentTournament = tournament
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tournament)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray900)
                                    
                                    Text(getTournamentDescription(tournament))
                                        .font(.caption)
                                        .foregroundColor(.gray600)
                                }
                                
                                Spacer()
                                
                                if currentTournament == tournament {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.brandGreen)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.title2)
                                        .foregroundColor(.gray400)
                                }
                            }
                            .padding(16)
                            .background(currentTournament == tournament ? Color.brandGreen.opacity(0.1) : Color.surfaceSecondary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(currentTournament == tournament ? Color.brandGreen : Color.gray300, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                // 確認按鈕
                Button(action: {
                    dismiss()
                }) {
                    Text("確認選擇")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandGreen)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("切換錦標賽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                }
            }
        }
    }
    
    private func getTournamentDescription(_ tournament: String) -> String {
        switch tournament {
        case "2025年度投資錦標賽":
            return "全年度最高榮譽競賽，獎勵豐厚"
        case "2025第一季錦標賽":
            return "季度競賽，適合穩健型投資者"
        case "新手投資挑戰賽":
            return "專為投資新手設計的入門賽事"
        case "專業投資競技賽":
            return "高難度競賽，適合專業投資者"
        default:
            return "投資競賽"
        }
    }
}

#Preview {
    HomeView()
}
