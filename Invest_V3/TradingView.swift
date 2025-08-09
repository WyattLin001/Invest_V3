import SwiftUI

struct TradingView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    @State private var selectedSegment = 0
    @State private var searchText = ""
    
    private let segments = ["熱門", "持股", "關注"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分段控制器
                segmentPicker
                
                // 搜尋欄
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                // 內容區域
                contentView
            }
            .navigationTitle("交易")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
            .onAppear {
                if tradingService.stocks.isEmpty {
                    Task {
                        await loadData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TournamentContextChanged"))) { _ in
                print("🔄 [TradingView] 錦標賽切換，重新載入交易數據")
                Task {
                    await loadData()
                }
            }
            .onChange(of: tournamentStateManager.currentTournamentContext) { _, _ in
                print("🔄 [TradingView] 錦標賽上下文變更，重新載入交易數據")
                Task {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - 分段選擇器
    private var segmentPicker: some View {
        Picker("交易選項", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { index in
                Text(segments[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 內容視圖
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case 0:
            HotStocksListView(stocks: filteredStocks)
        case 1:
            HoldingsListView()
        case 2:
            WatchlistView()
        default:
            HotStocksListView(stocks: filteredStocks)
        }
    }
    
    private var filteredStocks: [TradingStock] {
        if searchText.isEmpty {
            return tradingService.stocks
        } else {
            return tradingService.stocks.filter { stock in
                stock.symbol.lowercased().contains(searchText.lowercased()) ||
                stock.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private func loadData() async {
        await tradingService.loadStocks()
        
        // 根據錦標賽上下文載入對應的投資組合數據
        if tournamentStateManager.isParticipatingInTournament,
           let tournamentId = tournamentStateManager.getCurrentTournamentId() {
            print("🏆 [TradingView] 載入錦標賽投資組合: \(tournamentId)")
            
            // 載入錦標賽特定的投資組合數據
            await loadTournamentPortfolio(tournamentId: tournamentId)
        } else {
            print("📊 [TradingView] 載入一般模式投資組合")
            await tradingService.loadPortfolio()
        }
    }
    
    // MARK: - 錦標賽投資組合載入
    private func loadTournamentPortfolio(tournamentId: UUID) async {
        // 透過 TournamentService 載入錦標賽專用的投資組合
        let tournamentService = TournamentService.shared
        if let tournamentPortfolio = tournamentService.getUserTournamentPortfolio(
            tournamentId: tournamentId
        ) {
            // 將錦標賽投資組合數據轉換為 TradingService 格式
            await MainActor.run {
                convertTournamentPortfolioToTradingData(tournamentPortfolio)
            }
        } else {
            print("❌ [TradingView] 找不到錦標賽投資組合")
            // 錯誤情況下載入一般投資組合
            await tradingService.loadPortfolio()
        }
    }
    
    private func convertTournamentPortfolioToTradingData(_ tournamentPortfolio: TournamentPortfolio) {
        // 將錦標賽投資組合數據轉換為交易視圖可以使用的格式
        // 這裡需要根據 TournamentPortfolioManager 的具體實作來調整
        print("🔄 [TradingView] 轉換錦標賽投資組合數據")
        
        // 觸發界面更新
        tradingService.objectWillChange.send()
    }
}

// MARK: - 熱門股票列表
struct HotStocksListView: View {
    let stocks: [TradingStock]
    
    var body: some View {
        if stocks.isEmpty {
            GeneralEmptyStateView(
                icon: "chart.bar",
                title: "暫無股票資料",
                message: "請檢查網路連接"
            )
        } else {
            List(stocks) { stock in
                TradingStockRowWithActions(stock: stock)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(PlainListStyle())
        }
    }
}

// MARK: - 持股列表
struct HoldingsListView: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        if let portfolio = tradingService.portfolio, !portfolio.positions.isEmpty {
            List(portfolio.positions) { position in
                HoldingRow(position: position)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(PlainListStyle())
        } else {
            GeneralEmptyStateView(
                icon: "briefcase",
                title: "暫無持股",
                message: "開始您的第一筆交易吧！"
            )
        }
    }
}

// MARK: - 關注清單
struct WatchlistView: View {
    var body: some View {
        GeneralEmptyStateView(
            icon: "heart",
            title: "關注清單",
            message: "功能開發中，敬請期待"
        )
    }
}

// MARK: - 帶操作按鈕的交易股票行
struct TradingStockRowWithActions: View {
    let stock: TradingStock
    @State private var showBuyOrder = false
    @State private var showSellOrder = false
    @State private var currentPrice: Double
    @State private var change: Double
    @State private var changePercent: Double
    
    init(stock: TradingStock) {
        self.stock = stock
        
        // 模擬即時價格變化
        let priceChange = Double.random(in: -0.05...0.05)
        self._currentPrice = State(initialValue: stock.price * (1 + priceChange))
        self._change = State(initialValue: stock.price * priceChange)
        self._changePercent = State(initialValue: priceChange * 100)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 股票資訊
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(stock.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TradingService.shared.formatCurrency(currentPrice))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "triangle.fill" : "triangle.fill")
                            .font(.caption2)
                            .foregroundColor(change >= 0 ? .green : .red)
                            .rotationEffect(change >= 0 ? .degrees(0) : .degrees(180))
                        
                        Text(String(format: "%.2f%%", changePercent))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(change >= 0 ? .green : .red)
                    }
                }
            }
            
            // 交易按鈕
            HStack(spacing: 12) {
                Button(action: { showBuyOrder = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                        Text("買入")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                
                Button(action: { showSellOrder = true }) {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .font(.caption)
                        Text("賣出")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showBuyOrder) {
            TradeOrderView(stock: stock, action: .buy)
        }
        .sheet(isPresented: $showSellOrder) {
            TradeOrderView(stock: stock, action: .sell)
        }
    }
}

// MARK: - 交易股票行
struct TradingStockRow: View {
    let stock: TradingStock
    @State private var currentPrice: Double
    @State private var change: Double
    @State private var changePercent: Double
    
    init(stock: TradingStock) {
        self.stock = stock
        
        // 模擬即時價格變化
        let priceChange = Double.random(in: -0.05...0.05)
        self._currentPrice = State(initialValue: stock.price * (1 + priceChange))
        self._change = State(initialValue: stock.price * priceChange)
        self._changePercent = State(initialValue: priceChange * 100)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.symbol)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(stock.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(TradingService.shared.formatCurrency(currentPrice))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "triangle.fill" : "triangle.fill")
                        .font(.caption2)
                        .foregroundColor(change >= 0 ? .green : .red)
                        .rotationEffect(change >= 0 ? .degrees(0) : .degrees(180))
                    
                    Text(String(format: "%.2f%%", changePercent))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(change >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 持股行
struct HoldingRow: View {
    let position: PortfolioPosition
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.symbol)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(position.quantity)股")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(TradingService.shared.formatCurrency(position.marketValue))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Text(String(format: "%.2f", position.unrealizedPnl))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(position.unrealizedPnl >= 0 ? .green : .red)
                    
                    Text(String(format: "(%.2f%%)", position.unrealizedPnlPercent))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(position.unrealizedPnl >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TradingView()
}