import SwiftUI

struct StockMarketView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @State private var searchText = ""
    @State private var selectedStock: TradingStock?
    @State private var showStockDetail = false
    
    var filteredStocks: [TradingStock] {
        if searchText.isEmpty {
            return tradingService.stocks
        } else {
            return tradingService.stocks.filter { stock in
                stock.symbol.lowercased().contains(searchText.lowercased()) ||
                stock.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜尋欄
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                // 股票清單
                if tradingService.stocks.isEmpty {
                    // 載入中或空狀態
                    if tradingService.isLoading {
                        ProgressView("載入股票資料中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyStateView(
                            icon: "chart.bar",
                            title: "暫無股票資料",
                            message: "請檢查網路連接或稍後再試"
                        )
                    }
                } else {
                    List(filteredStocks) { stock in
                        StockListRow(stock: stock) {
                            selectedStock = stock
                            showStockDetail = true
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("股票市場")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await tradingService.loadStocks()
            }
            .onAppear {
                if tradingService.stocks.isEmpty {
                    Task {
                        await tradingService.loadStocks()
                    }
                }
            }
        }
        .sheet(isPresented: $showStockDetail) {
            if let stock = selectedStock {
                StockDetailView(stock: stock)
            }
        }
    }
}

// MARK: - 搜尋欄
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜尋股票代號或名稱", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - 股票清單行
struct StockListRow: View {
    let stock: TradingStock
    let onTap: () -> Void
    
    @State private var currentPrice: Double
    @State private var change: Double
    @State private var changePercent: Double
    
    init(stock: TradingStock, onTap: @escaping () -> Void) {
        self.stock = stock
        self.onTap = onTap
        
        // 模擬即時價格變化
        let priceChange = Double.random(in: -0.05...0.05)
        self._currentPrice = State(initialValue: stock.price * (1 + priceChange))
        self._change = State(initialValue: stock.price * priceChange)
        self._changePercent = State(initialValue: priceChange * 100)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
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
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "triangle.fill" : "triangle.fill")
                            .font(.caption2)
                            .foregroundColor(change >= 0 ? .green : .red)
                            .rotationEffect(change >= 0 ? .degrees(0) : .degrees(180))
                        
                        Text(String(format: "%.2f (%.2f%%)", abs(change), abs(changePercent)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(change >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 股票詳情頁
struct StockDetailView: View {
    let stock: TradingStock
    @ObservedObject private var tradingService = TradingService.shared
    @State private var stockPrice: TradingStockPrice?
    @State private var isLoading = true
    @State private var showTradeSheet = false
    @State private var tradeAction: TradeAction = .buy
    @Environment(\.dismiss) private var dismiss
    
    enum TradeAction {
        case buy, sell
        
        var title: String {
            switch self {
            case .buy: return "買入"
            case .sell: return "賣出"
            }
        }
        
        var color: Color {
            switch self {
            case .buy: return .red
            case .sell: return .green
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 股票基本資訊
                    stockInfoSection
                    
                    // 價格資訊
                    if let price = stockPrice {
                        priceInfoSection(price: price)
                    }
                    
                    // 交易按鈕
                    tradingButtons
                    
                    // 模擬圖表區域
                    chartSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(stock.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStockPrice()
            }
        }
        .sheet(isPresented: $showTradeSheet) {
            TradeOrderView(stock: stock, action: tradeAction)
        }
    }
    
    // MARK: - 股票基本資訊區域
    private var stockInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stock.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack {
                Label("台灣證券交易所", systemImage: "building.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("TWD", systemImage: "dollarsign.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 價格資訊區域
    private func priceInfoSection(price: TradingStockPrice) -> some View {
        VStack(spacing: 16) {
            // 當前價格
            VStack(spacing: 8) {
                Text(TradingService.shared.formatCurrency(price.currentPrice))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Image(systemName: price.change >= 0 ? "triangle.fill" : "triangle.fill")
                        .font(.caption)
                        .foregroundColor(price.change >= 0 ? .green : .red)
                        .rotationEffect(price.change >= 0 ? .degrees(0) : .degrees(180))
                    
                    Text(String(format: "%.2f (%.2f%%)", price.change, price.changePercent))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(price.change >= 0 ? .green : .red)
                }
            }
            
            // 價格統計
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("昨收")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(price.previousClose))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("更新時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(price.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("漲跌幅")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f%%", price.changePercent))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(price.change >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 交易按鈕
    private var tradingButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                tradeAction = .buy
                showTradeSheet = true
            }) {
                Text("買入")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            
            Button(action: {
                tradeAction = .sell
                showTradeSheet = true
            }) {
                Text("賣出")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 圖表區域
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("價格走勢")
                .font(.headline)
                .fontWeight(.bold)
            
            // 模擬圖表
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("圖表功能開發中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 輔助方法
    private func loadStockPrice() {
        Task {
            do {
                let price = try await TradingService.shared.getStockPrice(symbol: stock.symbol)
                await MainActor.run {
                    self.stockPrice = price
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("載入股價失敗: \(error)")
            }
        }
    }
    
    private func formatTime(_ timestamp: String) -> String {
        // 簡化的時間格式化
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: String(timestamp.prefix(19))) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return "--:--"
    }
}

// MARK: - 空狀態視圖
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    StockMarketView()
}