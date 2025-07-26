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

// MARK: - 投資組合總覽視圖（整合交易功能）
struct InvestmentHomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    init() {
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
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingMD) {
                // 投資組合總覽卡片
                portfolioSummaryCard
                
                // 動態圓餅圖和持股明細
                portfolioVisualizationCard
                
                // 交易區域
                tradingCard
                
                // 管理功能
                managementCard
            }
            .padding()
        }
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
    
    // MARK: - 投資組合總覽卡片
    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
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
            
            Divider()
                .background(Color.divider)
            
            HStack(alignment: .bottom, spacing: DesignTokens.spacingSM) {
                Text(String(format: "$%.0f", portfolioManager.totalPortfolioValue))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                let dailyChange = portfolioManager.totalPortfolioValue - portfolioManager.totalInvested
                let changePercent = portfolioManager.totalInvested > 0 ? (dailyChange / portfolioManager.totalInvested) : 0
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: dailyChange >= 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(dailyChange >= 0 ? .success : .danger)
                            .font(.caption)
                        
                        Text(String(format: "$%.2f", abs(dailyChange)))
                            .foregroundColor(dailyChange >= 0 ? .success : .danger)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(String(format: "(%.2f%%)", abs(changePercent * 100)))
                        .foregroundColor(dailyChange >= 0 ? .success : .danger)
                        .font(.caption)
                }
                
                Spacer()
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 投資組合視覺化卡片（圓餅圖 + 持股明細）
    private var portfolioVisualizationCard: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 動態圓餅圖
            VStack(spacing: 16) {
                DynamicPieChart(data: portfolioManager.pieChartData, size: 120)
                
                // 投資組合明細
                if portfolioManager.holdings.isEmpty {
                    Text("尚未進行任何投資")
                        .font(.body)
                        .adaptiveTextColor(primary: false)
                        .padding(.vertical, 20)
                } else {
                    // 股票列表標題
                    HStack {
                        Text("持股明細")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .adaptiveTextColor(primary: false)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
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
                                    Text("$\(String(format: "%.0f", value))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(String(format: "%.0f", percentage * 100))%")
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
                    .background(Color.surfacePrimary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignTokens.borderColor, lineWidth: DesignTokens.borderWidthThin)
                    )
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 交易區域卡片
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