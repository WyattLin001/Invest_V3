//
//  EnhancedTournamentTradingView.swift
//  Invest_V3
//
//  強化版錦標賽交易視圖 - 整合新的工作流程服務
//

import SwiftUI
import Combine

struct EnhancedTournamentTradingView: View {
    let tournament: Tournament
    @StateObject private var workflowService: TournamentWorkflowService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 狀態
    @State private var selectedStock: String = ""
    @State private var tradeAction: TournamentTradeAction = .buy
    @State private var quantity: String = ""
    @State private var currentPrice: Double = 0.0
    @State private var searchText: String = ""
    @State private var selectedSegment: Int = 0
    
    // 視圖狀態
    @State private var showingTradeSheet: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isLoadingPrice: Bool = false
    
    // 模擬數據
    @State private var portfolio: TournamentPortfolioV2?
    @State private var holdings: [TournamentHolding] = []
    @State private var watchlist: [String] = ["2330", "2454", "2317", "AAPL", "TSLA"]
    @State private var marketData: [String: Double] = [:]
    
    private let segments = ["熱門股票", "我的持股", "關注清單", "實時排名"]
    private let currentUserId = UUID() // 在實際應用中從用戶服務獲取
    
    init(tournament: Tournament, workflowService: TournamentWorkflowService) {
        self.tournament = tournament
        self._workflowService = StateObject(wrappedValue: workflowService)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tournamentHeaderSection
                portfolioSummarySection
                segmentedControl
                contentArea
            }
            .navigationTitle("錦標賽交易")
            .navigationBarTitleDisplayMode(.never)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingTradeSheet) {
            TradeExecutionSheet(
                tournament: tournament,
                workflowService: workflowService,
                stockSymbol: selectedStock,
                currentPrice: currentPrice,
                portfolio: portfolio
            )
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
        .task {
            await loadInitialData()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - 視圖組件
    
    private var tournamentHeaderSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        statusBadge
                        Spacer()
                        timeRemaining
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tournament.status == .active ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            
            Text(tournament.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var timeRemaining: some View {
        Text(timeRemainingText)
            .font(.caption)
            .foregroundColor(.secondary)
            .monospacedDigit()
    }
    
    private var portfolioSummarySection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總資產")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(portfolio?.totalValue ?? 0))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("今日損益")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(formatCurrency(portfolio?.dailyPnL ?? 0))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("(\(formatPercentage(portfolio?.dailyPnLPercent ?? 0)))")
                            .font(.caption)
                    }
                    .foregroundColor(portfolioPnLColor)
                }
            }
            
            HStack {
                portfolioMetric(title: "現金", value: formatCurrency(portfolio?.cashBalance ?? 0))
                portfolioMetric(title: "持股市值", value: formatCurrency(portfolio?.equityValue ?? 0))
                portfolioMetric(title: "總報酬", value: formatPercentage(portfolio?.totalReturnPercent ?? 0))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private var segmentedControl: some View {
        Picker("選項", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { index in
                Text(segments[index])
                    .tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var contentArea: some View {
        TabView(selection: $selectedSegment) {
            popularStocksView.tag(0)
            holdingsView.tag(1)
            watchlistView.tag(2)
            rankingsView.tag(3)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    // MARK: - 內容視圖
    
    private var popularStocksView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(popularStocks, id: \.symbol) { stock in
                    StockRow(stock: stock) {
                        selectStock(stock.symbol, price: stock.price)
                    }
                }
            }
            .padding()
        }
    }
    
    private var holdingsView: some View {
        ScrollView {
            if holdings.isEmpty {
                EmptyHoldingsView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(holdings) { holding in
                        Button {
                            selectStock(holding.symbol, price: holding.currentPrice)
                        } label: {
                            TournamentHoldingRow(holding: holding)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
    
    private var watchlistView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(watchlistStocks, id: \.symbol) { stock in
                    StockRow(stock: stock) {
                        selectStock(stock.symbol, price: stock.price)
                    }
                }
            }
            .padding()
        }
    }
    
    private var rankingsView: some View {
        TournamentRankingsView(tournamentId: tournament.id)
    }
    
    // MARK: - 輔助視圖
    
    private func portfolioMetric(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 計算屬性
    
    private var timeRemainingText: String {
        let now = Date()
        
        if now < tournament.startDate {
            let interval = tournament.startDate.timeIntervalSince(now)
            return "開始: \(formatTimeInterval(interval))"
        } else if now < tournament.endDate {
            let interval = tournament.endDate.timeIntervalSince(now)
            return "剩餘: \(formatTimeInterval(interval))"
        } else {
            return "已結束"
        }
    }
    
    private var portfolioPnLColor: Color {
        guard let pnl = portfolio?.dailyPnL else { return .secondary }
        return pnl >= 0 ? .green : .red
    }
    
    private var popularStocks: [StockInfo] {
        // 模擬熱門股票數據
        return [
            StockInfo(symbol: "2330", name: "台積電", price: marketData["2330"] ?? 580.0, change: 2.5, changePercent: 0.43),
            StockInfo(symbol: "2454", name: "聯發科", price: marketData["2454"] ?? 1205.0, change: -15.0, changePercent: -1.23),
            StockInfo(symbol: "2317", name: "鴻海", price: marketData["2317"] ?? 203.5, change: 3.5, changePercent: 1.75),
            StockInfo(symbol: "AAPL", name: "Apple", price: marketData["AAPL"] ?? 189.5, change: -2.1, changePercent: -1.1),
            StockInfo(symbol: "TSLA", name: "Tesla", price: marketData["TSLA"] ?? 248.3, change: 5.2, changePercent: 2.1)
        ]
    }
    
    private var watchlistStocks: [StockInfo] {
        return watchlist.compactMap { symbol in
            guard let price = marketData[symbol] else { return nil }
            
            // 簡化的股票名稱映射
            let nameMap: [String: String] = [
                "2330": "台積電",
                "2454": "聯發科",
                "2317": "鴻海",
                "AAPL": "Apple",
                "TSLA": "Tesla"
            ]
            
            return StockInfo(
                symbol: symbol,
                name: nameMap[symbol] ?? symbol,
                price: price,
                change: Double.random(in: -10...10),
                changePercent: Double.random(in: -5...5)
            )
        }
    }
    
    // MARK: - 方法
    
    private func loadInitialData() async {
        await loadPortfolio()
        await loadHoldings()
        await loadMarketData()
    }
    
    private func refreshData() async {
        await loadPortfolio()
        await loadMarketData()
    }
    
    private func loadPortfolio() async {
        // 模擬加載投資組合數據
        await MainActor.run {
            portfolio = TournamentPortfolioV2(
                id: UUID(),
                tournamentId: tournament.id,
                userId: currentUserId,
                cashBalance: 850000,
                equityValue: 150000,
                totalAssets: 1000000,
                initialBalance: 1000000,
                totalReturn: 0,
                returnPercentage: 0.0,
                totalTrades: 0,
                winningTrades: 0,
                maxDrawdown: 0,
                lastUpdated: Date()
            )
        }
    }
    
    private func loadHoldings() async {
        // 模擬加載持股數據
        let sampleHoldings = [
            TournamentHolding(
                id: UUID(),
                tournamentId: tournament.id,
                userId: currentUserId,
                symbol: "2330",
                name: "台積電",
                shares: 100,
                averagePrice: 575.0,
                currentPrice: 580.0,
                firstPurchaseDate: Date().addingTimeInterval(-86400),
                lastUpdated: Date()
            )
        ]
        
        await MainActor.run {
            holdings = sampleHoldings
        }
    }
    
    private func loadMarketData() async {
        // 模擬獲取市場數據
        let sampleData: [String: Double] = [
            "2330": 580.0,
            "2454": 1205.0,
            "2317": 203.5,
            "AAPL": 189.5,
            "TSLA": 248.3
        ]
        
        await MainActor.run {
            marketData = sampleData
        }
    }
    
    private func selectStock(_ symbol: String, price: Double) {
        selectedStock = symbol
        currentPrice = price
        showingTradeSheet = true
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.currencyCode = "TWD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value / 100)) ?? "\(value)%"
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)天"
        } else if hours > 0 {
            return "\(hours)小時\(minutes)分"
        } else {
            return "\(minutes)分鐘"
        }
    }
}

// MARK: - 支援結構

struct StockInfo: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
}

// TournamentPortfolio 已移至 TournamentModels.swift 作為 TournamentPortfolioV2
// 使用 typealias 保持向後兼容
typealias TournamentPortfolio = TournamentPortfolioV2

// MARK: - 股票行視圖

struct StockRow: View {
    let stock: StockInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(stock.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatPrice(stock.price))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 2) {
                        Text(formatChange(stock.change))
                        Text("(\(formatPercentage(stock.changePercent)))")
                    }
                    .font(.caption)
                    .foregroundColor(stock.change >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatPrice(_ price: Double) -> String {
        return String(format: "%.1f", price)
    }
    
    private func formatChange(_ change: Double) -> String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change))"
    }
    
    private func formatPercentage(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", percent))%"
    }
}


// MARK: - 空持股視圖

struct EmptyHoldingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("尚未持有任何股票")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("選擇股票開始您的投資之旅")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 交易執行表單

struct TradeExecutionSheet: View {
    let tournament: Tournament
    let workflowService: TournamentWorkflowService
    let stockSymbol: String
    let currentPrice: Double
    let portfolio: TournamentPortfolio?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedAction: TournamentTradeAction = .buy
    @State private var quantity: String = "100"
    @State private var isExecuting: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    private let currentUserId = UUID()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 股票信息
                stockInfoSection
                
                // 交易表單
                tradeFormSection
                
                // 交易摘要
                tradeSummarySection
                
                Spacer()
                
                // 執行按鈕
                executeButtonSection
            }
            .padding()
            .navigationTitle("股票交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isExecuting)
                }
            }
        }
        .alert("交易結果", isPresented: $showingAlert) {
            Button("確定") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var stockInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stockSymbol)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("目前價格: $\(String(format: "%.1f", currentPrice))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var tradeFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("交易設定")
                .font(.headline)
            
            // 動作選擇
            Picker("交易動作", selection: $selectedAction) {
                Text("買入").tag(TournamentTradeAction.buy)
                Text("賣出").tag(TournamentTradeAction.sell)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 數量輸入
            VStack(alignment: .leading, spacing: 8) {
                Text("數量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("請輸入數量", text: $quantity)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var tradeSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易摘要")
                .font(.headline)
            
            VStack(spacing: 8) {
                summaryRow("動作", selectedAction.displayName)
                summaryRow("股票", stockSymbol)
                summaryRow("數量", "\(quantity) 股")
                summaryRow("價格", "$\(String(format: "%.1f", currentPrice))")
                summaryRow("總金額", "$\(String(format: "%.0f", totalAmount))")
                
                if selectedAction == .buy {
                    summaryRow("可用資金", "$\(String(format: "%.0f", portfolio?.cashBalance ?? 0))")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var executeButtonSection: some View {
        Button(action: executeTrade) {
            HStack {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: selectedAction == .buy ? "plus.circle" : "minus.circle")
                }
                
                Text(isExecuting ? "執行中..." : "\(selectedAction.displayName) \(stockSymbol)")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canExecute && !isExecuting ? .blue : .gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canExecute || isExecuting)
    }
    
    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private var totalAmount: Double {
        guard let qty = Double(quantity) else { return 0 }
        return qty * currentPrice
    }
    
    private var canExecute: Bool {
        guard let qty = Double(quantity), qty > 0 else { return false }
        
        if selectedAction == .buy {
            return totalAmount <= (portfolio?.cashBalance ?? 0)
        } else {
            // 簡化：假設總是有足夠的持股
            return true
        }
    }
    
    private func executeTrade() {
        guard let qty = Double(quantity) else { return }
        
        isExecuting = true
        
        Task {
            do {
                _ = try await workflowService.executeTournamentTrade(
                    tournamentId: tournament.id,
                    userId: currentUserId,
                    symbol: stockSymbol,
                    action: selectedAction,
                    quantity: qty,
                    price: currentPrice
                )
                
                await MainActor.run {
                    isExecuting = false
                    alertMessage = "交易執行成功！"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isExecuting = false
                    alertMessage = "交易執行失敗: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - 預覽

struct EnhancedTournamentTradingView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTournament = Tournament(
            id: UUID(),
            name: "科技股挑戰賽",
            type: .monthly,
            status: .ongoing,
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date().addingTimeInterval(86400 * 6),
            description: "專注科技股投資競賽",
            shortDescription: "科技股挑戰賽",
            initialBalance: 1000000,
            entryFee: 0,
            prizePool: 0,
            maxParticipants: 100,
            currentParticipants: 85,
            isFeatured: false,
            createdBy: UUID(),
            riskLimitPercentage: 0.2,
            minHoldingRate: 0.5,
            maxSingleStockRate: 0.3,
            rules: [
                "允許做空交易",
                "單一持股上限：30%",
                "允許投資：股票、ETF",
                "交易時間：09:00 - 16:00 (台北時間)"
            ],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        EnhancedTournamentTradingView(
            tournament: sampleTournament,
            workflowService: TournamentWorkflowService(
                tournamentService: TournamentService(),
                tradeService: TournamentTradeService(),
                walletService: TournamentWalletService(),
                rankingService: TournamentRankingService(),
                businessService: TournamentBusinessService()
            )
        )
    }
}