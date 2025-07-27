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
    @State private var showingTournamentDetail = false
    @State private var selectedTournament: Tournament?
    @State private var showingTournamentSelection = false
    @State private var participatedTournaments: [Tournament] = []
    @State private var currentActiveTournament: Tournament?
    
    // 統計管理器
    @ObservedObject private var statisticsManager = StatisticsManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. 投資組合總覽
            NavigationView {
                VStack(spacing: 0) {
                    // 統計橫幅 - 固定在頂部
                    StatisticsBanner(
                        statisticsManager: statisticsManager,
                        portfolioManager: ChatPortfolioManager.shared
                    )
                    
                    // 主要內容 - 可滾動區域
                    ScrollView {
                        InvestmentHomeView(
                            currentActiveTournament: currentActiveTournament,
                            participatedTournaments: participatedTournaments,
                            showingTournamentTrading: .constant(false),
                            showingTournamentSelection: $showingTournamentSelection
                        )
                    }
                }
                .navigationTitle("投資總覽")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(false)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("投資總覽", systemImage: "chart.pie.fill")
            }
            .tag(InvestmentTab.home)
            
            // 2. 交易記錄
            NavigationView {
                VStack(spacing: 0) {
                    // 統計橫幅 - 固定在頂部
                    StatisticsBanner(
                        statisticsManager: statisticsManager,
                        portfolioManager: ChatPortfolioManager.shared
                    )
                    
                    // 主要內容 - 可滾動區域
                    ScrollView {
                        InvestmentRecordsView()
                    }
                }
                .navigationTitle("交易記錄")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("交易記錄", systemImage: "list.bullet.clipboard")
            }
            .tag(InvestmentTab.records)
            
            // 3. 錦標賽選擇
            NavigationView {
                VStack(spacing: 0) {
                    // 統計橫幅 - 固定在頂部
                    StatisticsBanner(
                        statisticsManager: statisticsManager,
                        portfolioManager: ChatPortfolioManager.shared
                    )
                    
                    // 主要內容 - 可滾動區域
                    ScrollView {
                        TournamentSelectionView(
                            selectedTournament: $selectedTournament,
                            showingDetail: $showingTournamentDetail
                        )
                    }
                }
                .navigationTitle("錦標賽")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("錦標賽", systemImage: "trophy.fill")
            }
            .tag(InvestmentTab.tournaments)
            
            // 4. 排行榜與動態
            NavigationView {
                TournamentRankingsView()
                    .navigationTitle("排行榜")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            tournamentSelectionButton
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("排行榜", systemImage: "list.number")
            }
            .tag(InvestmentTab.rankings)
            
            // 5. 個人績效
            NavigationView {
                VStack(spacing: 0) {
                    // 統計橫幅 - 固定在頂部
                    StatisticsBanner(
                        statisticsManager: statisticsManager,
                        portfolioManager: ChatPortfolioManager.shared
                    )
                    
                    // 主要內容 - 可滾動區域
                    ScrollView {
                        PersonalPerformanceView()
                    }
                }
                .navigationTitle("我的績效")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        tournamentSelectionButton
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
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
        .onAppear {
            initializeDefaultTournament()
        }
    }
    
    // MARK: - 工具欄按鈕
    private var tournamentSelectionButton: some View {
        Button(action: {
            showingTournamentSelection = true
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.brandGreen)
        }
    }
    
    // MARK: - 初始化與數據處理
    private func initializeDefaultTournament() {
        // 創建默認2025年度錦標賽
        let default2025Tournament = Tournament(
            id: UUID(),
            name: "2025年度錦標賽",
            type: .yearly,
            status: .ongoing,
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31)) ?? Date(),
            description: "2025年度錦標賽是全年最盛大的投資競賽，所有用戶自動參加",
            shortDescription: "全年投資競賽挑戰",
            initialBalance: 1000000, // 100萬初始資金
            maxParticipants: 100000,
            currentParticipants: 85432,
            entryFee: 0, // 免費參加
            prizePool: 10000000, // 1000萬獎金池
            riskLimitPercentage: 0.2, // 20%風險限制
            minHoldingRate: 0.1, // 10%最小持倉率
            maxSingleStockRate: 0.3, // 30%單股最大持倉率
            rules: [
                "使用平台提供的虛擬資金進行投資",
                "比賽期間為2025年1月1日至12月31日",
                "以總投資報酬率為評分標準",
                "禁止使用外部工具或不當手段",
                "遵守平台交易規則和時間限制"
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: true
        )
        
        // 如果還沒有參加任何錦標賽，自動加入2025年度錦標賽
        if participatedTournaments.isEmpty {
            participatedTournaments = [default2025Tournament]
            currentActiveTournament = default2025Tournament
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
    
    var body: some View {
        LazyVStack(spacing: DesignTokens.spacingMD) {
            // 投資組合統計卡片組
            portfolioStatsCards
            
            // 動態圓餅圖和持股明細
            portfolioVisualizationCard
            
            // 交易區域（錦標賽交易）
            tournamentTradingCard
            
            // 管理功能
            managementCard
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom)
        .adaptiveBackground()
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
                portfolioManager.clearCurrentUserPortfolio()
                tradeSuccessMessage = "投資組合已清空，虛擬資金已重置為 NT$1,000,000"
                showTradeSuccess = true
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
    private func fetchCurrentPrice() async {
        guard !stockSymbol.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run {
                currentPrice = 0.0
                priceError = nil
                priceLastUpdated = nil
            }
            return
        }
        
        await MainActor.run {
            isPriceLoading = true
            priceError = nil
        }
        
        do {
            let stockPrice = try await TradingAPIService.shared.fetchStockPriceAuto(symbol: stockSymbol)
            
            await MainActor.run {
                currentPrice = stockPrice.currentPrice
                priceLastUpdated = ISO8601DateFormatter().date(from: stockPrice.timestamp) ?? Date()
                priceError = nil
                isPriceLoading = false
                calculateEstimation()
            }
            
        } catch {
            await MainActor.run {
                currentPrice = 0.0
                if let tradingError = error as? TradingAPIError {
                    priceError = tradingError.localizedDescription
                } else {
                    priceError = "網路錯誤"
                }
                isPriceLoading = false
            }
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
            let feeRate = 0.001425
            let fee = amount * feeRate
            let availableAmount = amount - fee
            estimatedShares = availableAmount / currentPrice
            estimatedCost = amount
        }
    }
    
    /// 執行交易並進行驗證
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
        
        if tradeAction == "buy" {
            let success = portfolioManager.buyStock(
                symbol: stockSymbol, 
                shares: amount / currentPrice, 
                price: currentPrice,
                stockName: selectedStockName.isEmpty ? nil : selectedStockName
            )
            
            if success {
                tradeSuccessMessage = "成功購買 \(String(format: "%.2f", amount / currentPrice)) 股 \(stockSymbol)"
                showTradeSuccess = true
                clearTradeInputs()
            } else {
                showError("交易失敗，請檢查餘額是否足夠")
            }
        } else {
            let success = portfolioManager.sellStock(
                symbol: stockSymbol,
                shares: amount,
                price: currentPrice
            )
            
            if success {
                tradeSuccessMessage = "成功賣出 \(String(format: "%.2f", amount)) 股 \(stockSymbol)"
                showTradeSuccess = true
                clearTradeInputs()
            } else {
                showError("交易失敗，請檢查持股是否足夠")
            }
        }
    }
    
    /// 顯示錯誤訊息
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
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

// MARK: - 交易記錄視圖
struct InvestmentRecordsView: View {
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
            dateRange: selectedDateRange
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
            
            // 記錄列表
            ForEach(filteredRecords, id: \.id) { record in
                TradingRecordRow(record: record)
                    .background(Color.surfacePrimary)
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Table Header
    
    private var recordsTableHeader: some View {
        HStack {
            Group {
                Text("日期/時間")
                    .frame(width: 80, alignment: .leading)
                Text("代號")
                    .frame(width: 60, alignment: .leading)
                Text("類型")
                    .frame(width: 50, alignment: .center)
                Text("數量")
                    .frame(width: 60, alignment: .trailing)
                Text("價格")
                    .frame(width: 60, alignment: .trailing)
                Text("總額")
                    .frame(width: 70, alignment: .trailing)
                Text("損益")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
}

// MARK: - 交易記錄行組件

struct TradingRecordRow: View {
    let record: TradingRecord
    
    var body: some View {
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
            .frame(width: 80, alignment: .leading)
            
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
            .frame(width: 60, alignment: .leading)
            
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
                .frame(width: 50, alignment: .center)
            
            // 數量
            Text(String(format: "%.0f", record.shares))
                .font(.caption)
                .foregroundColor(.textPrimary)
                .frame(width: 60, alignment: .trailing)
            
            // 價格
            Text(String(format: "$%.0f", record.price))
                .font(.caption)
                .foregroundColor(.textPrimary)
                .frame(width: 60, alignment: .trailing)
            
            // 總額
            Text(String(format: "$%,.0f", record.totalAmount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
                .frame(width: 70, alignment: .trailing)
            
            // 損益（僅賣出顯示）
            Group {
                if let gainLoss = record.realizedGainLoss {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "$%,.0f", gainLoss))
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
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                                        currentActiveTournament = tournament
                                        dismiss()
                                    }
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
    
    var body: some View {
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
                            
                            Text(tournament.shortDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.brandGreen.opacity(0.1) : Color.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandGreen : Color.clear, lineWidth: 2)
            )
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


// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - 預覽
#Preview {
    EnhancedInvestmentView()
        .environmentObject(ThemeManager.shared)
}
