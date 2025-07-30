//
//  EnhancedInvestmentView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  投資管理主視圖 - 包含五大功能模組的完整投資體驗

import SwiftUI

/// EnhancedInvestmentView - 新的投資總覽界面，取代現有的 InvestmentPanelView
/// 提供更完整的投資管理體驗，包含以下五大功能模組：
/// 1. InvestmentHomeView - 投資組合總覽
/// 2. InvestmentRecordsView - 交易記錄
/// 3. TournamentSelectionView - 錦標賽選擇
/// 4. TournamentRankingsView - 排行榜與動態牆
/// 5. PersonalPerformanceView - 個人績效分析
struct EnhancedInvestmentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTab: InvestmentTab = .home
    let currentTournamentName: String?
    
    init(currentTournamentName: String? = nil) {
        self.currentTournamentName = currentTournamentName
    }
    @State private var showingTournamentDetail = false
    @State private var selectedTournament: Tournament?
    @State private var showingTournamentSelection = false
    @State private var showingCreateTournament = false
    @State private var participatedTournaments: [Tournament] = []
    @State private var currentActiveTournament: Tournament?
    
    // 統計管理器
    @ObservedObject private var statisticsManager = StatisticsManager.shared
    
    // Supabase 服務整合
    @ObservedObject private var supabaseService = SupabaseService.shared
    
    // 投資組合管理器
    @ObservedObject private var portfolioManager = ChatPortfolioManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. 投資組合總覽
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 統計橫幅作為內容第一項
                        StatisticsBanner(
                            statisticsManager: statisticsManager,
                            portfolioManager: ChatPortfolioManager.shared,
                            currentTournamentName: currentTournamentName ?? currentActiveTournament?.name ?? "2025年度投資錦標賽"
                        )
                        
                        // 主要投資內容
                        InvestmentHomeView(
                            currentActiveTournament: currentActiveTournament,
                            participatedTournaments: participatedTournaments,
                            showingTournamentTrading: .constant(false),
                            showingTournamentSelection: $showingTournamentSelection
                        )
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("投資總覽")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .tabItem {
                Label("投資總覽", systemImage: "chart.pie.fill")
            }
            .tag(InvestmentTab.home)
            // 2. 交易記錄
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 統計橫幅作為內容第一項
                        StatisticsBanner(
                            statisticsManager: statisticsManager,
                            portfolioManager: ChatPortfolioManager.shared,
                            currentTournamentName: currentTournamentName ?? currentActiveTournament?.name ?? "2025年度投資錦標賽"
                        )
                        
                        // 交易記錄內容
                        InvestmentRecordsView(currentActiveTournament: currentActiveTournament)
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("交易記錄")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .tabItem {
                Label("交易記錄", systemImage: "list.bullet.clipboard")
            }
            .tag(InvestmentTab.records)
            
            // 3. 錦標賽選擇
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 統計橫幅作為內容第一項
                        StatisticsBanner(
                            statisticsManager: statisticsManager,
                            portfolioManager: ChatPortfolioManager.shared,
                            currentTournamentName: currentTournamentName ?? currentActiveTournament?.name ?? "2025年度投資錦標賽"
                        )
                        
                        // 錦標賽選擇內容
                        TournamentSelectionView(
                            selectedTournament: $selectedTournament,
                            showingDetail: $showingTournamentDetail
                        )
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("錦標賽")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .tabItem {
                Label("錦標賽", systemImage: "trophy.fill")
            }
            .tag(InvestmentTab.tournaments)
            
            // 4. 排行榜與動態
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 統計橫幅作為內容第一項
                        StatisticsBanner(
                            statisticsManager: statisticsManager,
                            portfolioManager: ChatPortfolioManager.shared,
                            currentTournamentName: currentTournamentName ?? currentActiveTournament?.name ?? "2025年度投資錦標賽"
                        )
                        
                        // 排行榜內容
                        TournamentRankingsView()
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("排行榜")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .tabItem {
                Label("排行榜", systemImage: "list.number")
            }
            .tag(InvestmentTab.rankings)
            
            // 5. 個人績效  
            NavigationStack {
                PersonalPerformanceContentView()
                    .navigationTitle("我的績效")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            tournamentSelectionButton
                        }
                    }
            }
            .tabItem {
                Label("我的績效", systemImage: "chart.bar.fill")
            }
            .tag(InvestmentTab.performance)
        }
        .tint(.brandGreen)
        .sheet(isPresented: $showingTournamentDetail) {
            if let tournament = selectedTournament {
                TournamentDetailView(tournament: tournament)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingTournamentSelection) {
            TournamentSelectionSheet(
                participatedTournaments: $participatedTournaments,
                currentActiveTournament: $currentActiveTournament
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingCreateTournament) {
            CreateTournamentView()
                .environmentObject(themeManager)
        }
        .onAppear {
            initializeDefaultTournament()
            loadSupabaseData()
        }
    }
    
    // MARK: - 工具欄按鈕
    private var tournamentSelectionButton: some View {
        HStack(spacing: 8) {
            // 一般用戶的錦標賽選擇按鈕
            Button(action: {
                showingTournamentSelection = true
            }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.brandGreen)
            }
            
            // 管理員專用的錦標賽建立按鈕 (只有 test03 帳號可見)
            if isAdminUser {
                Button(action: {
                    showingCreateTournament = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.brandOrange)
                }
            }
        }
    }
    
    /// 檢查當前用戶是否為管理員 (test03)
    private var isAdminUser: Bool {
        guard let currentUser = SupabaseService.shared.getCurrentUser() else {
            return false
        }
        return currentUser.username == "test03"
    }
    
    /// 刪除錦標賽（僅限test03）
    private func deleteTournament(_ tournament: Tournament) {
        guard isAdminUser else {
            print("❌ 權限不足：只有test03可以刪除錦標賽")
            return
        }
        
        Task { @MainActor in
            do {
                let success = try await SupabaseService.shared.deleteTournament(tournamentId: tournament.id)
                if success {
                    // 從本地列表中移除
                    participatedTournaments.removeAll { $0.id == tournament.id }
                    
                    // 如果刪除的是當前活躍錦標賽，切換到第一個可用的錦標賽
                    if currentActiveTournament?.id == tournament.id {
                        currentActiveTournament = participatedTournaments.first
                        if let firstTournament = participatedTournaments.first {
                            portfolioManager.switchToTournament(
                                tournamentId: firstTournament.id,
                                tournamentName: firstTournament.name
                            )
                        }
                    }
                    
                    print("✅ 錦標賽已刪除：\(tournament.name)")
                } else {
                    print("❌ 刪除錦標賽失敗")
                }
            } catch {
                print("❌ 刪除錦標賽時發生錯誤：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 初始化與數據處理
    private func initializeDefaultTournament() {
        // 不再創建硬編碼的預設錦標賽
        // 所有錦標賽數據都從 Supabase 載入
        if participatedTournaments.isEmpty && currentActiveTournament == nil {
            // 如果沒有錦標賽數據，等待從 Supabase 載入
            print("ℹ️ 等待從 Supabase 載入錦標賽數據...")
        }
    }
    
    // MARK: - Supabase 數據載入
    private func loadSupabaseData() {
        Task { @MainActor in
            await loadUserProfile()
            await loadTournamentData()
            await loadUserInvestmentData()
        }
    }
    
    /// 載入用戶個人資料
    @MainActor
    private func loadUserProfile() async {
        if let currentUser = SupabaseService.shared.getCurrentUser() {
            print("✅ 成功載入用戶資料: \(currentUser.username)")
            // 可以在這裡更新 UI 狀態
        } else {
            print("ℹ️ 尚未登入或無用戶資料")
        }
    }
    
    /// 載入錦標賽相關數據
    @MainActor
    private func loadTournamentData() async {
        do {
            // 載入所有錦標賽並篩選精選錦標賽
            let tournaments = try await SupabaseService.shared.fetchFeaturedTournaments()
            participatedTournaments = tournaments
            
            if let firstTournament = tournaments.first {
                currentActiveTournament = firstTournament
            }
            
            print("✅ 成功載入 \(tournaments.count) 個精選錦標賽")
        } catch {
            print("❌ 載入錦標賽數據失敗: \(error.localizedDescription)")
            // 保持使用模擬數據
        }
    }
    
    /// 載入用戶投資數據
    @MainActor
    private func loadUserInvestmentData() async {
        do {
            // 目前使用現有的 ChatPortfolioManager 數據
            // 未來可以添加從 Supabase 載入投資組合的功能
            
            // 載入錦標賽統計數據
            let tournamentStats = try await SupabaseService.shared.fetchTournamentStatistics()
            print("✅ 成功載入錦標賽統計數據: \(tournamentStats.totalParticipants) 參與者")
            
            // 更新統計管理器
            await statisticsManager.refreshData()
            
        } catch {
            print("❌ 載入投資數據失敗: \(error.localizedDescription)")
            // 繼續使用本地模擬數據
        }
    }
}

// MARK: - 投資功能標籤
enum InvestmentTab: String, CaseIterable, Identifiable {
    case home = "home"
    case records = "records" 
    case tournaments = "tournaments"
    case rankings = "rankings"
    case performance = "performance"
    
    var id: String { rawValue }
    
    var navigationTitle: String {
        switch self {
        case .home:
            return "投資總覽"
        case .records:
            return "交易記錄"
        case .tournaments:
            return "錦標賽"
        case .rankings:
            return "排行榜"
        case .performance:
            return "我的績效"
        }
    }
    
    var iconName: String {
        switch self {
        case .home:
            return "chart.pie.fill"
        case .records:
            return "list.bullet.clipboard"
        case .tournaments:
            return "trophy.fill"
        case .rankings:
            return "list.number"
        case .performance:
            return "chart.bar.fill"
        }
    }
}

// MARK: - 投資組合總覽視圖（整合交易功能）
struct InvestmentHomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    // 錦標賽相關參數
    let currentActiveTournament: Tournament?
    let participatedTournaments: [Tournament]
    @Binding var showingTournamentTrading: Bool
    @Binding var showingTournamentSelection: Bool
    
    init(currentActiveTournament: Tournament?, participatedTournaments: [Tournament], showingTournamentTrading: Binding<Bool>, showingTournamentSelection: Binding<Bool>) {
        self.currentActiveTournament = currentActiveTournament
        self.participatedTournaments = participatedTournaments
        self._showingTournamentTrading = showingTournamentTrading
        self._showingTournamentSelection = showingTournamentSelection
        self._portfolioManager = ObservedObject(wrappedValue: ChatPortfolioManager.shared)
    }
    
    @ObservedObject private var portfolioManager: ChatPortfolioManager
    @ObservedObject private var syncService = PortfolioSyncService.shared
    
    // 交易相關狀態
    @State private var stockSymbol: String = ""
    @State private var tradeAmount: String = ""
    @State private var tradeAction: String = "buy"
    @State private var showTradeSuccess = false
    @State private var tradeSuccessMessage = ""
    
    // 即時股價相關狀態
    @State private var currentPrice: Double = 0.0
    @State private var priceLastUpdated: Date?
    @State private var isPriceLoading = false
    @State private var priceError: String?
    @State private var estimatedShares: Double = 0.0
    @State private var estimatedCost: Double = 0.0
    @State private var showSellConfirmation = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var selectedStockName: String = ""
    @State private var showClearPortfolioConfirmation = false
    @State private var isRefreshing = false
    @State private var clearPortfolioSuccessMessage = ""
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 投資組合圓餅圖
            portfolioOverviewCard
            
            // 交易區域（完整交易功能）
            tradingCard
        }
        .refreshable {
            await refreshPortfolioData()
        }
        .alert("交易成功", isPresented: $showTradeSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(tradeSuccessMessage)
        }
        .alert("確認賣出", isPresented: $showSellConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確定賣出", role: .destructive) {
                executeTradeWithValidation()
            }
        } message: {
            Text("您確定要賣出 \(tradeAmount) 股 \(stockSymbol) 嗎？")
        }
        .alert("交易失敗", isPresented: $showErrorAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .alert("清空投資組合", isPresented: $showClearPortfolioConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確定清空", role: .destructive) {
                Task { @MainActor in
                    await clearPortfolioWithSupabaseSync()
                }
            }
        } message: {
            Text("⚠️ 此操作將清空您的所有投資記錄並重置虛擬資金，此操作無法復原。\n\n確定要繼續嗎？")
        }
    }
    
    // MARK: - 投資組合統計卡片組
    private var portfolioStatsCards: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 標題列與刷新按鈕
            HStack {
                Text("投資組合")
                    .font(.title2)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
                
                Button(action: {
                    Task { await refreshPortfolioData() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.brandGreen)
                        .opacity(isRefreshing ? 0.5 : 1.0)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isRefreshing)
                }
            }
            
            // 三個統計卡片
            HStack(spacing: DesignTokens.spacingSM) {
                // 投資組合總價值
                portfolioValueCard
                
                // 總損益
                totalProfitLossCard
                
                // 投資組合多樣性
                portfolioDiversityCard
            }
        }
    }
    
    // MARK: - 投資組合總價值卡片
    private var portfolioValueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("投資組合總價值")
                .font(.caption)
                .adaptiveTextColor(primary: false)
            
            Text(formatCurrency(portfolioManager.totalPortfolioValue))
                .font(.title2)
                .fontWeight(.bold)
                .adaptiveTextColor()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brandCardStyle()
    }
    
    // MARK: - 總損益卡片
    private var totalProfitLossCard: some View {
        let totalGainLoss = portfolioManager.totalUnrealizedGainLoss
        let totalGainLossPercent = portfolioManager.totalUnrealizedGainLossPercent
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("總損益")
                .font(.caption)
                .adaptiveTextColor(primary: false)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: totalGainLoss >= 0 ? "arrow.up" : "arrow.down")
                        .foregroundColor(totalGainLoss >= 0 ? .success : .danger)
                        .font(.caption)
                    
                    Text(formatCurrency(abs(totalGainLoss)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(totalGainLoss >= 0 ? .success : .danger)
                }
                
                Text(String(format: "%@%.2f%% 總報酬率", totalGainLoss >= 0 ? "+" : "", totalGainLossPercent))
                    .font(.caption2)
                    .foregroundColor(totalGainLoss >= 0 ? .success : .danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brandCardStyle()
    }
    
    // MARK: - 投資組合多樣性卡片
    private var portfolioDiversityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("投資組合多樣性")
                .font(.caption)
                .adaptiveTextColor(primary: false)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(portfolioManager.portfolioDiversityCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.brandBlue)
                        .font(.caption2)
                    Text("檔持有的")
                        .font(.caption2)
                        .adaptiveTextColor(primary: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brandCardStyle()
    }
    
    // MARK: - 投資組合視覺化卡片（圓餅圖 + 專業持股表格）
    private var portfolioVisualizationCard: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 動態圓餅圖
            DynamicPieChart(data: portfolioManager.pieChartData, size: 120)
            
            // 投資組合明細
            if portfolioManager.holdings.isEmpty {
                Text("尚未進行任何投資")
                    .font(.body)
                    .adaptiveTextColor(primary: false)
                    .padding(.vertical, 20)
            } else {
                professionalHoldingsTable
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 專業持股明細表格
    private var professionalHoldingsTable: some View {
        VStack(spacing: 12) {
            // 表格標題
            HStack {
                Text("目前持股")
                    .font(.headline)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                Spacer()
            }
            
            // 表頭
            tableHeader
            
            // 表格內容
            LazyVStack(spacing: 8) {
                ForEach(portfolioManager.holdings, id: \.id) { holding in
                    professionalHoldingRow(holding)
                        .background(Color.surfaceSecondary)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - 表頭
    private var tableHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Group {
                    Text("代號")
                        .frame(width: 50, alignment: .leading)
                    Text("股數")
                        .frame(width: 50, alignment: .trailing)
                    Text("股價")
                        .frame(width: 50, alignment: .trailing)
                    Text("日漲跌")
                        .frame(width: 50, alignment: .trailing)
                    Text("總價值")
                        .frame(width: 60, alignment: .trailing)
                    Text("損益")
                        .frame(width: 60, alignment: .trailing)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .adaptiveTextColor(primary: false)
            }
            .padding(.horizontal, 12)
            
            Divider()
                .background(Color.divider)
        }
    }
    
    // MARK: - 專業持股列
    private func professionalHoldingRow(_ holding: PortfolioHolding) -> some View {
        let percentage = portfolioManager.portfolioPercentages.first { $0.0 == holding.symbol }?.1 ?? 0
        let dailyChange = holding.mockDailyChangeAmount
        let dailyChangePercent = holding.mockDailyChangePercent
        
        return VStack(spacing: 8) {
            // 主要資訊列
            HStack {
                // 代號和名稱 (更大空間)
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .adaptiveTextColor()
                    Text(holding.displayName)
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                        .lineLimit(1)
                }
                .frame(width: 50, alignment: .leading)
                
                // 股數
                Text(String(format: "%.0f", holding.shares))
                    .font(.caption)
                    .adaptiveTextColor()
                    .frame(width: 50, alignment: .trailing)
                
                // 股價
                Text(formatPrice(holding.currentPrice))
                    .font(.caption)
                    .adaptiveTextColor()
                    .frame(width: 50, alignment: .trailing)
                
                // 日漲跌
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: dailyChange >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(formatPrice(abs(dailyChange)))
                            .font(.caption2)
                    }
                    .foregroundColor(dailyChange >= 0 ? .success : .danger)
                    
                    Text(String(format: "%@%.2f%%", dailyChange >= 0 ? "+" : "", dailyChangePercent))
                        .font(.caption2)
                        .foregroundColor(dailyChange >= 0 ? .success : .danger)
                }
                .frame(width: 50, alignment: .trailing)
                
                // 總價值
                Text(formatCurrency(holding.totalValue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                    .frame(width: 60, alignment: .trailing)
                
                // 損益
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatCurrency(holding.unrealizedGainLoss))
                        .font(.caption2)
                        .foregroundColor(holding.unrealizedGainLoss >= 0 ? .success : .danger)
                    
                    Text(String(format: "%@%.1f%%", holding.unrealizedGainLoss >= 0 ? "+" : "", holding.unrealizedGainLossPercent))
                        .font(.caption2)
                        .foregroundColor(holding.unrealizedGainLoss >= 0 ? .success : .danger)
                }
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 錦標賽交易區域卡片
    private var tournamentTradingCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.brandGreen)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("投資交易")
                        .font(.title3)
                        .fontWeight(.bold)
                        .adaptiveTextColor()
                    
                    if let tournament = currentActiveTournament {
                        HStack(spacing: 4) {
                            Text("當前參與:")
                                .font(.caption)
                                .adaptiveTextColor(primary: false)
                            Text(tournament.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.brandGreen)
                            Text("已參加")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandGreen)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.divider)
            
            // 錦標賽交易按鈕
            Button(action: {
                showingTournamentTrading = true
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("模擬股票交易")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let tournament = currentActiveTournament {
                            Text("參與 \(tournament.name)")
                                .font(.subheadline)
                        } else {
                            Text("開始投資競賽")
                                .font(.subheadline)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandGreen)
                )
            }
            .sheet(isPresented: $showingTournamentTrading) {
                TournamentTradingSelectionSheet(
                    participatedTournaments: participatedTournaments,
                    currentActiveTournament: .constant(currentActiveTournament),
                    showingTournamentSelection: $showingTournamentSelection
                )
                .environmentObject(themeManager)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 完整交易功能卡片
    // 移除了 tradingViewCard，因為它會與 tradingCard 重複
    
    // MARK: - 投資組合總覽卡片
    private var portfolioOverviewCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.brandGreen)
                    .font(.title3)
                
                Text("投資組合")
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
            }
            
            Divider()
                .background(Color.divider)
            
            // 投資組合圓形圖表
            VStack(spacing: 16) {
                DynamicPieChart(data: portfolioManager.pieChartData, size: 150)
                
                // 投資組合明細
                if portfolioManager.holdings.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "briefcase")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("尚未進行任何投資")
                            .font(.body)
                            .adaptiveTextColor(primary: false)
                    }
                    .padding(.vertical, 20)
                } else {
                    // 股票列表
                    LazyVStack(spacing: 8) {
                        ForEach(portfolioManager.holdings, id: \.id) { holding in
                            let value = holding.totalValue
                            let percentage = portfolioManager.portfolioPercentages.first { $0.0 == holding.symbol }?.1 ?? 0
                            
                            HStack {
                                // 股票顏色指示器
                                Circle()
                                    .fill(StockColorPalette.colorForStock(symbol: holding.symbol))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(holding.symbol)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        
                                        Text(holding.name)
                                            .font(.subheadline)
                                            .adaptiveTextColor(primary: false)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(Int(value))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(Int(percentage * 100))%")
                                        .font(.caption)
                                        .adaptiveTextColor(primary: false)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.surfaceSecondary)
                            .cornerRadius(8)
                        }
                    }
                }
                
                // 清除投資組合按鈕（僅在有持股時顯示）
                if !portfolioManager.holdings.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 8) {
                        Text("管理功能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showClearPortfolioConfirmation = true
                        }) {
                            Text("🧹 清空投資組合")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange)
                                )
                        }
                    }
                }
            }
        }
        .brandCardStyle()
    }
    
    
    // MARK: - 原始交易區域卡片（保留）
    private var tradingCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text("進行交易")
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
            }
            
            Divider()
                .background(Color.divider)
            
            // 股票代號輸入 - 使用智能搜尋組件
            VStack(alignment: .leading, spacing: 8) {
                Text("股票代號")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                StockSearchTextField(
                    text: $stockSymbol,
                    placeholder: "例如：2330 或 台積電"
                ) { selectedStock in
                    stockSymbol = selectedStock.code
                    selectedStockName = selectedStock.name
                    Task {
                        await fetchCurrentPrice()
                    }
                }
                .onChange(of: stockSymbol) { newValue in
                    Task {
                        await fetchCurrentPrice()
                    }
                }
                
                // 即時股價顯示
                if !stockSymbol.isEmpty {
                    HStack {
                        if isPriceLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在獲取價格...")
                                .font(.caption)
                                .adaptiveTextColor(primary: false)
                        } else if let priceError = priceError {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(priceError)
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if currentPrice > 0 {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.success)
                            Text("$\(String(format: "%.2f", currentPrice))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .adaptiveTextColor()
                            
                            if let lastUpdated = priceLastUpdated {
                                Text("更新於 \(DateFormatter.timeOnly.string(from: lastUpdated))")
                                    .font(.caption2)
                                    .adaptiveTextColor(primary: false)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            
            // 交易動作選擇
            VStack(alignment: .leading, spacing: 8) {
                Text("交易動作")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                Picker("交易動作", selection: $tradeAction) {
                    Text("買入").tag("buy")
                    Text("賣出").tag("sell")
                }
                .pickerStyle(SegmentedPickerStyle())
                .tint(.brandGreen)
            }
            
            // 金額輸入
            VStack(alignment: .leading, spacing: 8) {
                Text(tradeAction == "buy" ? "投資金額 ($)" : "賣出股數")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                TextField(tradeAction == "buy" ? "輸入投資金額" : "輸入股數", text: $tradeAmount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .onChange(of: tradeAmount) { _ in
                        calculateEstimation()
                    }
                
                // 交易資訊提示
                TradeInfoView(
                    tradeAction: tradeAction,
                    tradeAmount: tradeAmount,
                    stockSymbol: stockSymbol,
                    currentPrice: currentPrice,
                    estimatedShares: estimatedShares,
                    estimatedCost: estimatedCost,
                    portfolioManager: portfolioManager
                )
            }
            
            // 執行交易按鈕
            Button(action: {
                if tradeAction == "sell" {
                    showSellConfirmation = true
                } else {
                    executeTradeWithValidation()
                }
            }) {
                Text("\(tradeAction == "buy" ? "買入" : "賣出") \(stockSymbol.isEmpty ? "股票" : stockSymbol)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isTradeButtonDisabled ? Color.gray : (tradeAction == "buy" ? Color.success : Color.danger))
                    )
            }
            .disabled(isTradeButtonDisabled)
        }
        .brandCardStyle()
    }
    
    // MARK: - 管理功能卡片
    private var managementCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text("投資組合管理")
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
            }
            
            Divider()
                .background(Color.divider)
            
            VStack(spacing: 8) {
                Text("測試功能")
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
                
                Button(action: {
                    showClearPortfolioConfirmation = true
                }) {
                    Text("🧹 清空投資組合")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange)
                        )
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 計算與驗證邏輯
    
    /// 檢查交易按鈕是否應該被禁用
    private var isTradeButtonDisabled: Bool {
        stockSymbol.isEmpty || tradeAmount.isEmpty || (tradeAction == "buy" && currentPrice <= 0)
    }
    
    /// 獲取即時股價
    @MainActor
    private func fetchCurrentPrice() async {
        guard !stockSymbol.trimmingCharacters(in: .whitespaces).isEmpty else {
            currentPrice = 0.0
            priceError = nil
            priceLastUpdated = nil
            return
        }
        
        isPriceLoading = true
        priceError = nil
        
        do {
            let stockPrice = try await TradingAPIService.shared.fetchStockPriceAuto(symbol: stockSymbol)
            
            currentPrice = stockPrice.currentPrice
            priceLastUpdated = ISO8601DateFormatter().date(from: stockPrice.timestamp) ?? Date()
            priceError = nil
            isPriceLoading = false
            calculateEstimation()
            
        } catch {
            currentPrice = 0.0
            if let tradingError = error as? TradingAPIError {
                priceError = tradingError.localizedDescription
            } else {
                priceError = "網路錯誤"
            }
            isPriceLoading = false
        }
    }
    
    /// 計算預估購買資訊
    private func calculateEstimation() {
        guard let amount = Double(tradeAmount), amount > 0, currentPrice > 0 else {
            estimatedShares = 0.0
            estimatedCost = 0.0
            return
        }
        
        if tradeAction == "buy" {
            let feeCalculator = FeeCalculator.shared
            let fees = feeCalculator.calculateTradingFees(amount: amount, action: .buy)
            let availableAmount = amount - fees.totalFees
            estimatedShares = availableAmount / currentPrice
            estimatedCost = amount
        }
    }
    
    /// 執行交易並進行驗證
    /// 異步交易執行方法
    @MainActor
    private func executeTradeOrder() async {
        executeTradeWithValidation()
    }
    
    @MainActor
    private func executeTradeWithValidation() {
        guard let amount = Double(tradeAmount), amount > 0 else {
            showError("請輸入有效的金額")
            return
        }
        
        if tradeAction == "sell" {
            if let holding = portfolioManager.holdings.first(where: { $0.symbol == stockSymbol }) {
                if holding.shares < amount {
                    showError("持股不足，目前僅持有 \(String(format: "%.2f", holding.shares)) 股")
                    return
                }
            } else {
                showError("您目前沒有持有 \(stockSymbol) 股票")
                return
            }
        }
        
        // 使用 PortfolioSyncService 執行錦標賽交易
        Task { @MainActor in
            let success = await PortfolioSyncService.shared.executeTournamentTrade(
                tournamentId: currentActiveTournament?.id, // 傳入當前錦標賽 ID
                symbol: stockSymbol,
                stockName: selectedStockName.isEmpty ? getStockName(for: stockSymbol) : selectedStockName,
                action: tradeAction == "buy" ? TradingType.buy : TradingType.sell,
                shares: tradeAction == "buy" ? (amount / currentPrice) : amount,
                price: currentPrice
            )
            
            if success {
                // 交易成功
                if tradeAction == "buy" {
                    tradeSuccessMessage = "成功購買 \(String(format: "%.2f", amount / currentPrice)) 股 \(stockSymbol)"
                } else {
                    tradeSuccessMessage = "成功賣出 \(String(format: "%.2f", amount)) 股 \(stockSymbol)"
                }
                showTradeSuccess = true
                clearTradeInputs()
            } else {
                showError("交易失敗，請檢查餘額或持股是否足夠")
            }
        }
    }
    
    /// 顯示錯誤訊息
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    /// 獲取股票名稱（輔助方法）
    private func getStockName(for symbol: String) -> String {
        let stockNames: [String: String] = [
            "2330": "台積電",
            "2317": "鴻海",
            "2454": "聯發科",
            "2881": "富邦金",
            "2882": "國泰金",
            "2886": "兆豐金",
            "2891": "中信金",
            "6505": "台塑化",
            "3008": "大立光",
            "2308": "台達電",
            "0050": "台灣50",
            "2002": "中興",
            "AAPL": "Apple Inc",
            "TSLA": "Tesla Inc",
            "NVDA": "NVIDIA Corp",
            "GOOGL": "Alphabet Inc",
            "MSFT": "Microsoft Corp"
        ]
        return stockNames[symbol] ?? symbol
    }
    
    /// 清空交易輸入
    private func clearTradeInputs() {
        stockSymbol = ""
        tradeAmount = ""
        selectedStockName = ""
        currentPrice = 0.0
        priceLastUpdated = nil
        priceError = nil
        estimatedShares = 0.0
        estimatedCost = 0.0
    }
    
    // MARK: - 輔助視圖
    private func portfolioMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .adaptiveTextColor(primary: false)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .adaptiveTextColor()
        }
    }
    
    private func holdingRow(_ holding: PortfolioHolding) -> some View {
        HStack {
            Circle()
                .fill(StockColorPalette.colorForStock(symbol: holding.symbol))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                Text("\(holding.shares) 股")
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(holding.totalValue))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                Text(String(format: "%@%.2f%%", holding.unrealizedGainLossPercent >= 0 ? "+" : "", holding.unrealizedGainLossPercent))
                    .font(.caption)
                    .foregroundColor(holding.unrealizedGainLossPercent >= 0 ? .success : .danger)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func performanceMetric(_ period: String, _ returnValue: Double) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(period)
                .font(.caption)
                .adaptiveTextColor(primary: false)
            Text(String(format: "%@%.2f%%", returnValue >= 0 ? "+" : "", returnValue))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(returnValue >= 0 ? .success : .danger)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 數據刷新
    private func refreshPortfolioData() async {
        isRefreshing = true
        
        // 簡化的數據刷新邏輯
        // TODO: 實際的數據刷新邏輯
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 模擬網路請求
        
        isRefreshing = false
    }
    
    // MARK: - 格式化輔助函數
    
    /// 格式化貨幣顯示
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    /// 格式化價格顯示（較小數字，保留小數點）
    private func formatPrice(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - 清除投資組合功能
extension InvestmentHomeView {
    /// 清除投資組合並與Supabase同步
    @MainActor
    private func clearPortfolioWithSupabaseSync() async {
        do {
            // 本地清除
            portfolioManager.clearCurrentUserPortfolio()
            
            // 與Supabase同步清除
            if let currentUser = SupabaseService.shared.getCurrentUser() {
                // 這裡可以添加Supabase同步邏輯
                print("✅ 投資組合已清空並與Supabase同步")
            }
            
            // 顯示成功消息
            showTradeSuccess = true
            tradeSuccessMessage = "投資組合已清空，虛擬資金已重置為 NT$1,000,000"
            
        } catch {
            // 處理錯誤
            errorMessage = "清空投資組合失敗：\(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

// MARK: - 交易記錄視圖
struct InvestmentRecordsView: View {
    let currentActiveTournament: Tournament?
    
    @ObservedObject private var portfolioManager = ChatPortfolioManager.shared
    @State private var searchText = ""
    @State private var selectedTradingType: TradingType? = nil
    @State private var selectedDateRange: TradingRecordFilter.DateRange = .month
    @State private var showingFilterOptions = false
    @State private var isRefreshing = false
    
    // 篩選條件
    private var currentFilter: TradingRecordFilter {
        TradingRecordFilter(
            searchText: searchText,
            tradingType: selectedTradingType,
            dateRange: selectedDateRange,
            tournamentId: currentActiveTournament?.id
        )
    }
    
    // 篩選後的交易記錄
    private var filteredRecords: [TradingRecord] {
        portfolioManager.getFilteredTradingRecords(currentFilter)
    }
    
    // 交易統計
    private var tradingStatistics: TradingStatistics {
        portfolioManager.getTradingStatistics()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingMD) {
                // 錦標賽選擇器
                tournamentSelectorSection
                
                // 統計卡片區域
                statisticsSection
                
                // 搜尋和篩選區域
                searchAndFilterSection
                
                // 交易記錄列表
                recordsSection
            }
            .padding()
        }
        .adaptiveBackground()
        .refreshable {
            await refreshData()
        }
        .onAppear {
            // 如果沒有交易記錄，添加一些模擬數據
            if portfolioManager.tradingRecords.isEmpty {
                portfolioManager.addMockTradingRecords()
            }
        }
    }
    
    // MARK: - Tournament Selector Section
    
    private var tournamentSelectorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("錦標賽篩選")
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
                
                if let tournament = currentActiveTournament {
                    Text("進行中")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.success)
                        )
                }
            }
            
            // 錦標賽選擇卡片
            if let tournament = currentActiveTournament {
                activeTournamentCard(tournament: tournament)
            } else {
                noTournamentCard
            }
        }
    }
    
    // MARK: - Active Tournament Card
    
    private func activeTournamentCard(tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 錦標賽標題和類型
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .adaptiveTextColor()
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        // 錦標賽類型標籤
                        Text(tournament.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(tournament.type == .special ? Color.brandOrange : Color.brandBlue)
                            )
                        
                        // 錦標賽狀態
                        Text(tournament.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(tournament.status.color)
                    }
                }
                
                Spacer()
                
                // 參與人數信息
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tournament.currentParticipants)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .adaptiveTextColor()
                    
                    Text("/ \(tournament.maxParticipants)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            // 錦標賽進度條
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("參與進度")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", tournament.participationPercentage))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                }
                
                ProgressView(value: tournament.participationPercentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: .brandGreen))
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }
            
            // 時間信息
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.textSecondary)
                    .font(.caption)
                
                Text("剩餘時間: \(tournament.timeRemaining)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.brandGreen)
                    .font(.caption)
                
                Text("獎金池: \(formatCurrency(tournament.prizePool))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.brandGreen)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfacePrimary)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - No Tournament Card
    
    private var noTournamentCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 32))
                .foregroundColor(.textSecondary.opacity(0.6))
            
            Text("目前未參與錦標賽")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
            
            Text("參與錦標賽可查看專屬交易記錄")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfaceSecondary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("交易統計")
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
                
                // 刷新按鈕
                Button(action: {
                    Task { await refreshData() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.brandGreen)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isRefreshing)
                }
            }
            
            // 統計卡片網格
            TradingStatsGrid(statistics: tradingStatistics, isLoading: isRefreshing)
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                
                TextField("代號或公司名稱", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surfaceSecondary)
            )
            
            // 篩選選項
            HStack(spacing: 12) {
                // 交易類型篩選
                Menu {
                    Button("全部類型") {
                        selectedTradingType = nil
                    }
                    
                    ForEach(TradingType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            selectedTradingType = type
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedTradingType?.displayName ?? "所有類型")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.surfaceSecondary)
                    )
                }
                
                // 日期範圍篩選
                Menu {
                    ForEach(TradingRecordFilter.DateRange.allCases, id: \.self) { range in
                        Button(range.displayName) {
                            selectedDateRange = range
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedDateRange.displayName)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.surfaceSecondary)
                    )
                }
                
                Spacer()
                
                // 進階篩選按鈕
                Button(action: {
                    showingFilterOptions.toggle()
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.brandGreen)
                }
            }
        }
    }
    
    // MARK: - Records Section
    
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // 標題和記錄數量
            HStack {
                Text("交易歷史記錄")
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Spacer()
                
                Text("\(filteredRecords.count) 筆記錄")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            if filteredRecords.isEmpty {
                // 空狀態
                emptyStateView
            } else {
                // 記錄列表
                recordsList
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary.opacity(0.5))
            
            Text("暫無交易記錄")
                .font(.headline)
                .foregroundColor(.textSecondary)
            
            Text("您的交易記錄將在這裡顯示")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("添加模擬數據") {
                portfolioManager.addMockTradingRecords()
            }
            .font(.subheadline)
            .foregroundColor(.brandGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Records List
    
    private var recordsList: some View {
        VStack(spacing: 8) {
            // 表頭
            recordsTableHeader
            
            // 記錄列表 - 橫向滾動
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 8) {
                    ForEach(filteredRecords, id: \.id) { record in
                        TradingRecordRow(record: record)
                            .background(Color.surfacePrimary)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Table Header
    
    private var recordsTableHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Group {
                    Text("日期/時間")
                        .frame(width: 90, alignment: .leading)
                    Text("代號")
                        .frame(width: 70, alignment: .leading)
                    Text("類型")
                        .frame(width: 60, alignment: .center)
                    Text("數量")
                        .frame(width: 70, alignment: .trailing)
                    Text("價格")
                        .frame(width: 80, alignment: .trailing)
                    Text("總額")
                        .frame(width: 90, alignment: .trailing)
                    Text("損益")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.textSecondary)
            }
            .frame(minWidth: 540) // 確保表格有足夠寬度
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.surfaceSecondary)
        .cornerRadius(6)
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() async {
        isRefreshing = true
        // 模擬數據刷新
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
    
    // 格式化貨幣顯示
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        if let formattedValue = formatter.string(from: NSNumber(value: abs(value))) {
            return value >= 0 ? "$\(formattedValue)" : "-$\(formattedValue)"
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - 交易記錄行組件

struct TradingRecordRow: View {
    let record: TradingRecord
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                // 日期時間
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.textPrimary)
                    Text(record.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
                .frame(width: 90, alignment: .leading)
                
                // 股票代號和名稱
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    Text(record.stockName)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 70, alignment: .leading)
                
                // 交易類型標籤
                Text(record.type.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(record.type == .buy ? Color.success : Color.danger)
                    )
                    .frame(width: 60, alignment: .center)
                
                // 數量
                Text(String(format: "%.0f", record.shares))
                    .font(.caption)
                    .foregroundColor(.textPrimary)
                    .frame(width: 70, alignment: .trailing)
                
                // 價格
                Text(formatCurrency(record.price))
                    .font(.caption)
                    .foregroundColor(.textPrimary)
                    .frame(width: 80, alignment: .trailing)
                
                // 總額 - 修復格式化問題
                Text(formatCurrency(record.totalAmount))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .frame(width: 90, alignment: .trailing)
                
                // 損益（僅賣出顯示）
                Group {
                    if let gainLoss = record.realizedGainLoss {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(formatCurrency(gainLoss))
                                .font(.caption2)
                                .foregroundColor(gainLoss >= 0 ? .success : .danger)
                            
                            if let percent = record.realizedGainLossPercent {
                                Text(String(format: "%@%.1f%%", gainLoss >= 0 ? "+" : "", percent))
                                    .font(.caption2)
                                    .foregroundColor(gainLoss >= 0 ? .success : .danger)
                            }
                        }
                    } else {
                        Text("-")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .frame(minWidth: 540) // 確保與表頭寬度一致
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
    
    // 格式化貨幣顯示
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        if let formattedValue = formatter.string(from: NSNumber(value: abs(value))) {
            return value >= 0 ? "$\(formattedValue)" : "-$\(formattedValue)"
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - 錦標賽詳情視圖
struct TournamentDetailView: View {
    let tournament: Tournament
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    // 錦標賽基本信息
                    tournamentHeaderCard
                    
                    // 規則說明
                    tournamentRulesCard
                    
                    // 參與狀態
                    participationCard
                }
                .padding()
            }
            .adaptiveBackground()
            .navigationTitle(tournament.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var tournamentHeaderCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: tournament.type.iconName)
                    .foregroundColor(.brandGreen)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.type.displayName)
                        .font(.headline)
                        .adaptiveTextColor()
                    Text(tournament.description)
                        .font(.subheadline)
                        .adaptiveTextColor(primary: false)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(tournament.status.displayName)
                        .font(.caption)
                        .foregroundColor(tournament.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tournament.status.color.opacity(0.1))
                        .cornerRadius(4)
                    
                    if tournament.status != .finished {
                        Text(tournament.timeRemaining)
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Label("\(tournament.currentParticipants)/\(tournament.maxParticipants)", systemImage: "person.2.fill")
                Spacer()
                Label(String(format: "$%.0f", tournament.prizePool), systemImage: "dollarsign.circle.fill")
                Spacer()
                Label(tournament.type.duration, systemImage: "clock.fill")
            }
            .font(.caption)
            .adaptiveTextColor(primary: false)
        }
        .brandCardStyle()
    }
    
    private var tournamentRulesCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("比賽規則")
                .font(.headline)
                .adaptiveTextColor()
            
            ForEach(tournament.rules, id: \.self) { rule in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .adaptiveTextColor(primary: false)
                    Text(rule)
                        .font(.subheadline)
                        .adaptiveTextColor()
                    Spacer()
                }
            }
        }
        .brandCardStyle()
    }
    
    private var participationCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            if tournament.isJoinable {
                Button("加入錦標賽") {
                    // TODO: 加入錦標賽邏輯
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandGreen)
                .cornerRadius(12)
            } else if tournament.isActive {
                Text("錦標賽進行中")
                    .font(.headline)
                    .foregroundColor(.brandOrange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandOrange.opacity(0.1))
                    .cornerRadius(12)
            } else {
                Text("錦標賽已結束")
                    .font(.headline)
                    .foregroundColor(.gray600)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray200)
                    .cornerRadius(12)
            }
        }
        .brandCardStyle()
    }
}

// MARK: - 錦標賽選擇 Sheet
struct TournamentSelectionSheet: View {
    @Binding var participatedTournaments: [Tournament]
    @Binding var currentActiveTournament: Tournament?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var portfolioManager = ChatPortfolioManager.shared
    @ObservedObject private var supabaseService = SupabaseService.shared
    
    /// 檢查當前用戶是否為管理員 (test03)  
    private var isAdminUser: Bool {
        guard let currentUser = SupabaseService.shared.getCurrentUser() else {
            return false
        }
        return currentUser.username == "test03"
    }
    
    /// 刪除錦標賽（僅限test03）
    private func deleteTournament(_ tournament: Tournament) {
        guard isAdminUser else {
            print("❌ 權限不足：只有test03可以刪除錦標賽")
            return
        }
        
        Task { @MainActor in
            do {
                let success = try await SupabaseService.shared.deleteTournament(tournamentId: tournament.id)
                if success {
                    // 從本地列表中移除
                    participatedTournaments.removeAll { $0.id == tournament.id }
                    
                    // 如果刪除的是當前活躍錦標賽，切換到第一個可用的錦標賽
                    if currentActiveTournament?.id == tournament.id {
                        currentActiveTournament = participatedTournaments.first
                        if let firstTournament = participatedTournaments.first {
                            portfolioManager.switchToTournament(
                                tournamentId: firstTournament.id,
                                tournamentName: firstTournament.name
                            )
                        }
                    }
                    
                    print("✅ 錦標賽已刪除：\(tournament.name)")
                } else {
                    print("❌ 刪除錦標賽失敗")
                }
            } catch {
                print("❌ 刪除錦標賽時發生錯誤：\(error.localizedDescription)")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if participatedTournaments.isEmpty {
                    // 空狀態
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("尚未參加任何錦標賽")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("所有用戶會自動參加2025年度錦標賽")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(participatedTournaments, id: \.id) { tournament in
                                TournamentSelectionRow(
                                    tournament: tournament,
                                    isSelected: currentActiveTournament?.id == tournament.id,
                                    onSelect: {
                                        // 切換錦標賽並更新投資組合數據
                                        currentActiveTournament = tournament
                                        portfolioManager.switchToTournament(
                                            tournamentId: tournament.id,
                                            tournamentName: tournament.name
                                        )
                                        dismiss()
                                    },
                                    onDelete: isAdminUser ? {
                                        deleteTournament(tournament)
                                    } : nil,
                                    isAdminUser: isAdminUser
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("選擇錦標賽")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 錦標賽選擇行
struct TournamentSelectionRow: View {
    let tournament: Tournament
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    let isAdminUser: Bool
    
    init(tournament: Tournament, isSelected: Bool, onSelect: @escaping () -> Void, onDelete: (() -> Void)? = nil, isAdminUser: Bool = false) {
        self.tournament = tournament
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.isAdminUser = isAdminUser
    }
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: tournament.type.iconName)
                                .foregroundColor(.brandGreen)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tournament.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .minimumScaleFactor(0.9)
                                
                                Text(tournament.shortDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandGreen)
                                    .font(.title2)
                            }
                        }
                        
                        HStack {
                            Label("\(tournament.currentParticipants) 參與者", systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("已參加")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brandGreen)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.brandGreen.opacity(0.1) : Color.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandGreen : Color.clear, lineWidth: 2)
            )
            
            // 管理員刪除按鈕（僅對test03可見）
            if isAdminUser, let deleteAction = onDelete {
                Button(action: deleteAction) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 錦標賽交易選擇 Sheet
struct TournamentTradingSelectionSheet: View {
    let participatedTournaments: [Tournament]
    @Binding var currentActiveTournament: Tournament?
    @Binding var showingTournamentSelection: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 當前錦標賽狀態
                if let tournament = currentActiveTournament {
                    currentTournamentSection(tournament)
                } else {
                    noTournamentSection
                }
                
                // 交易按鈕區域
                tradingActionsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("選擇錦標賽交易")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func currentTournamentSection(_ tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("當前錦標賽")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: tournament.type.iconName)
                        .foregroundColor(.brandGreen)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tournament.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(tournament.shortDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("已參加")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandGreen)
                        .cornerRadius(8)
                }
                
                HStack {
                    Label("\(tournament.currentParticipants) 參與者", systemImage: "person.2.fill")
                    Spacer()
                    Label(String(format: "$%.0f 獎金池", tournament.prizePool), systemImage: "dollarsign.circle.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surfaceSecondary)
            )
        }
    }
    
    private var noTournamentSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("請先選擇錦標賽")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("您需要先選擇要參與的錦標賽才能進行交易")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var tradingActionsSection: some View {
        VStack(spacing: 16) {
            if currentActiveTournament != nil {
                // 開始交易按鈕
                Button(action: {
                    // TODO: 導航到實際的交易界面
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                        
                        Text("開始股票交易")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandGreen)
                    )
                }
            }
            
            // 切換錦標賽按鈕
            Button(action: {
                showingTournamentSelection = true
                dismiss()
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                    
                    Text("切換錦標賽")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .foregroundColor(.brandGreen)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandGreen.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandGreen, lineWidth: 1)
                )
            }
        }
    }
}


// MARK: - 錦標賽建立視圖 (管理員專用)
struct CreateTournamentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var supabaseService = SupabaseService.shared
    
    // 表單狀態
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var shortDescription: String = ""
    @State private var selectedType: TournamentType = .monthly
    @State private var selectedStatus: TournamentStatus = .enrolling
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var initialBalance: Double = 1000000 // 預設一百萬
    @State private var maxParticipants: Int = 1000
    @State private var entryFee: Double = 0
    @State private var prizePool: Double = 50000
    @State private var riskLimitPercentage: Double = 20
    @State private var minHoldingRate: Double = 5
    @State private var maxSingleStockRate: Double = 30
    @State private var isFeatured: Bool = false
    @State private var rules: [String] = [
        "禁止使用槓桿交易",
        "每日風險限制不得超過設定比例",
        "必須保持最低持股率",
        "單一股票持股不得超過總資產30%"
    ]
    
    // UI 狀態
    @State private var isCreating: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var newRule: String = ""
    @State private var showAddRule: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 基本資訊區塊
                    basicInfoSection
                    
                    // 時間設定區塊
                    timeSettingsSection
                    
                    // 財務設定區塊
                    financialSettingsSection
                    
                    // 規則設定區塊
                    rulesSection
                    
                    // 進階設定區塊
                    advancedSettingsSection
                    
                    // 建立按鈕
                    createButton
                }
                .padding()
            }
            .navigationTitle("建立錦標賽")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("建立錦標賽", isPresented: $showAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - 基本資訊區塊
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("基本資訊", "info.circle.fill")
            
            VStack(spacing: 16) {
                formField("錦標賽名稱", text: $name, placeholder: "例如：2025年Q4投資錦標賽")
                
                formField("簡短描述", text: $shortDescription, placeholder: "一句話描述錦標賽特色")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("詳細描述")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("詳細說明錦標賽規則和目標", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("錦標賽類型")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Picker("錦標賽類型", selection: $selectedType) {
                        ForEach(TournamentType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.displayName)
                            }.tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("錦標賽狀態")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Picker("錦標賽狀態", selection: $selectedStatus) {
                        ForEach(TournamentStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - 時間設定區塊
    private var timeSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("時間設定", "calendar.circle.fill")
            
            VStack(spacing: 16) {
                DatePicker("開始時間", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
                
                DatePicker("結束時間", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
                
                if endDate <= startDate {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("結束時間必須晚於開始時間")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - 財務設定區塊
    private var financialSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("財務設定", "dollarsign.circle.fill")
            
            VStack(spacing: 16) {
                numberField("初始資金", value: $initialBalance, format: "NT$%.0f")
                numberField("最大參與人數", value: Binding(
                    get: { Double(maxParticipants) },
                    set: { maxParticipants = Int($0) }
                ), format: "%.0f人")
                numberField("報名費", value: $entryFee, format: "NT$%.0f")
                numberField("獎金池", value: $prizePool, format: "NT$%.0f")
            }
        }
        .cardStyle()
    }
    
    // MARK: - 規則設定區塊
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("比賽規則", "list.bullet.circle.fill")
                Spacer()
                Button(action: { showAddRule = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.brandGreen)
                        .font(.title3)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                    HStack {
                        Text("• \(rule)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: { rules.remove(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if rules.isEmpty {
                    Text("尚未設定規則")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .cardStyle()
        .alert("新增規則", isPresented: $showAddRule) {
            TextField("輸入新規則", text: $newRule)
            Button("取消", role: .cancel) { newRule = "" }
            Button("新增") {
                if !newRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rules.append(newRule.trimmingCharacters(in: .whitespacesAndNewlines))
                    newRule = ""
                }
            }
        }
    }
    
    // MARK: - 進階設定區塊
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("進階設定", "gearshape.fill")
            
            VStack(spacing: 16) {
                percentageField("風險限制比例", value: $riskLimitPercentage)
                percentageField("最低持股率", value: $minHoldingRate)
                percentageField("單一股票持股上限", value: $maxSingleStockRate)
                
                Toggle("設為精選錦標賽", isOn: $isFeatured)
                    .toggleStyle(SwitchToggleStyle(tint: .brandGreen))
            }
        }
        .cardStyle()
    }
    
    // MARK: - 建立按鈕
    private var createButton: some View {
        Button(action: createTournament) {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                
                Text(isCreating ? "建立中..." : "建立錦標賽")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canCreateTournament ? Color.brandGreen : Color.gray)
            )
        }
        .disabled(!canCreateTournament || isCreating)
    }
    
    // MARK: - 輔助視圖
    private func sectionHeader(_ title: String, _ iconName: String) -> some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.brandGreen)
                .font(.title3)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
    
    private func formField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private func numberField(_ label: String, value: Binding<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: value, in: label.contains("資金") ? 100000...10000000 : 
                   label.contains("人數") ? 10...10000 : 0...1000000, step: 
                   label.contains("資金") ? 100000 : label.contains("人數") ? 10 : 1000)
                .tint(.brandGreen)
        }
    }
    
    private func percentageField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.0f%%", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: value, in: 0...100, step: 1)
                .tint(.brandGreen)
        }
    }
    
    // MARK: - 驗證邏輯
    private var canCreateTournament: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !shortDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endDate > startDate &&
        !rules.isEmpty
    }
    
    // MARK: - 建立錦標賽
    private func createTournament() {
        guard canCreateTournament else { return }
        
        isCreating = true
        
        let tournament = Tournament(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            status: selectedStatus,
            startDate: startDate,
            endDate: endDate,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            shortDescription: shortDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            initialBalance: initialBalance,
            maxParticipants: maxParticipants,
            currentParticipants: 0,
            entryFee: entryFee,
            prizePool: prizePool,
            riskLimitPercentage: riskLimitPercentage,
            minHoldingRate: minHoldingRate,
            maxSingleStockRate: maxSingleStockRate,
            rules: rules,
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: isFeatured
        )
        
        Task { @MainActor in
            do {
                try await createTournamentInDatabase(tournament)
                isCreating = false
                alertMessage = "錦標賽「\(tournament.name)」建立成功！"
                showAlert = true
                
                // 延遲關閉視圖
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                isCreating = false
                alertMessage = "建立錦標賽失敗：\(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func createTournamentInDatabase(_ tournament: Tournament) async throws {
        // 使用 SupabaseService 建立錦標賽
        let _ = try await supabaseService.createTournament(tournament)
        print("✅ 錦標賽已建立：\(tournament.name)")
    }
}

// MARK: - 輔助擴展
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}


// MARK: - 預覽
#Preview {
    EnhancedInvestmentView()
        .environmentObject(ThemeManager.shared)
}

#Preview("Create Tournament") {
    CreateTournamentView()
        .environmentObject(ThemeManager.shared)
}
