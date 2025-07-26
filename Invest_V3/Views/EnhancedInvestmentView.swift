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
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // 1. 投資組合總覽
                InvestmentHomeView()
                    .tabItem {
                        Label("投資總覽", systemImage: "chart.pie.fill")
                    }
                    .tag(InvestmentTab.home)
                
                // 2. 交易記錄
                InvestmentRecordsView()
                    .tabItem {
                        Label("交易記錄", systemImage: "list.bullet.clipboard")
                    }
                    .tag(InvestmentTab.records)
                
                // 3. 錦標賽選擇
                TournamentSelectionView(
                    selectedTournament: $selectedTournament,
                    showingDetail: $showingTournamentDetail
                )
                .tabItem {
                    Label("錦標賽", systemImage: "trophy.fill")
                }
                .tag(InvestmentTab.tournaments)
                
                // 4. 排行榜與動態
                TournamentRankingsView()
                    .tabItem {
                        Label("排行榜", systemImage: "list.number")
                    }
                    .tag(InvestmentTab.rankings)
                
                // 5. 個人績效
                PersonalPerformanceView()
                    .tabItem {
                        Label("我的績效", systemImage: "chart.bar.fill")
                    }
                    .tag(InvestmentTab.performance)
            }
            .tint(.brandGreen)
            .navigationTitle(selectedTab.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    settingsButton
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingTournamentDetail) {
            if let tournament = selectedTournament {
                TournamentDetailView(tournament: tournament)
                    .environmentObject(themeManager)
            }
        }
    }
    
    // MARK: - 工具欄按鈕
    private var settingsButton: some View {
        Button(action: {
            // TODO: 導航至設置頁面
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.brandGreen)
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

// MARK: - 投資組合總覽視圖
struct InvestmentHomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var portfolioData = MockPortfolioData.sampleData
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingMD) {
                // 總覽卡片
                portfolioSummaryCard
                
                // 資產配置圖表
                assetAllocationCard
                
                // 持股明細
                holdingsListCard
                
                // 近期表現
                recentPerformanceCard
            }
            .padding()
        }
        .adaptiveBackground()
        .refreshable {
            await refreshPortfolioData()
        }
    }
    
    // MARK: - 投資組合總覽卡片
    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("投資組合總值")
                    .font(.headline)
                    .adaptiveTextColor()
                
                Spacer()
                
                Button(action: {
                    Task { await refreshPortfolioData() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.brandGreen)
                        .opacity(isRefreshing ? 0.5 : 1.0)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
            }
            
            HStack(alignment: .bottom, spacing: DesignTokens.spacingSM) {
                Text(String(format: "$%.0f", portfolioData.totalValue))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: portfolioData.dailyChange >= 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(portfolioData.dailyChange >= 0 ? .success : .danger)
                            .font(.caption)
                        
                        Text(String(format: "$%.2f", abs(portfolioData.dailyChange)))
                            .foregroundColor(portfolioData.dailyChange >= 0 ? .success : .danger)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(String(format: "(%@%.2f%%)", portfolioData.dailyChangePercentage >= 0 ? "+" : "", portfolioData.dailyChangePercentage))
                        .foregroundColor(portfolioData.dailyChange >= 0 ? .success : .danger)
                        .font(.caption)
                }
            }
            
            Divider()
                .background(Color.divider)
            
            HStack {
                portfolioMetric("現金", String(format: "$%.0f", portfolioData.cashBalance))
                Spacer()
                portfolioMetric("已投資", String(format: "$%.0f", portfolioData.investedAmount))
                Spacer()
                portfolioMetric("總報酬率", String(format: "%@%.2f%%", portfolioData.totalReturnPercentage >= 0 ? "+" : "", portfolioData.totalReturnPercentage))
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 資產配置卡片
    private var assetAllocationCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("資產配置")
                .font(.headline)
                .adaptiveTextColor()
            
            // TODO: 添加圓餅圖組件
            HStack {
                // 臨時的資產配置顯示
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(portfolioData.allocations.prefix(5), id: \.symbol) { allocation in
                        HStack {
                            Circle()
                                .fill(StockColorPalette.colorForStock(symbol: allocation.symbol))
                                .frame(width: 12, height: 12)
                            
                            Text(allocation.name)
                                .font(.subheadline)
                                .adaptiveTextColor()
                            
                            Spacer()
                            
                            Text(String(format: "%.1f%%", allocation.percentage))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .adaptiveTextColor(primary: false)
                        }
                    }
                }
                
                Spacer()
                
                // 圓餅圖佔位符
                Circle()
                    .stroke(Color.divider, lineWidth: 1)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text("圖表")
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                    )
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 持股明細卡片
    private var holdingsListCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("持股明細")
                    .font(.headline)
                    .adaptiveTextColor()
                
                Spacer()
                
                Button("查看全部") {
                    // TODO: 導航至完整持股列表
                }
                .font(.caption)
                .foregroundColor(.brandGreen)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(portfolioData.holdings.prefix(5), id: \.symbol) { holding in
                    holdingRow(holding)
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 近期表現卡片
    private var recentPerformanceCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("近期表現")
                .font(.headline)
                .adaptiveTextColor()
            
            HStack(spacing: DesignTokens.spacingMD) {
                performanceMetric("7天", portfolioData.weeklyReturn)
                performanceMetric("30天", portfolioData.monthlyReturn)
                performanceMetric("90天", portfolioData.quarterlyReturn)
            }
        }
        .brandCardStyle()
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
                Text(String(format: "$%.0f", holding.totalValue))
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
}

// MARK: - 交易記錄視圖
struct InvestmentRecordsView: View {
    var body: some View {
        VStack {
            Text("交易記錄")
                .font(.title2)
                .adaptiveTextColor()
            Text("TODO: 實現交易歷史記錄列表")
                .font(.caption)
                .adaptiveTextColor(primary: false)
                .padding()
        }
        .adaptiveBackground()
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
                    
                    if tournament.status != .ended {
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

// MARK: - 預覽
#Preview {
    EnhancedInvestmentView()
        .environmentObject(ThemeManager.shared)
}