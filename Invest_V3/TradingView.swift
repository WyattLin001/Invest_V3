import SwiftUI

struct TradingView: View {
    let competition: Competition
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TradingViewModel()
    @State private var selectedStock: Stock?
    @State private var tradeAction: TradeAction = .buy
    @State private var quantity: String = ""
    @State private var showingOrderConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜尋欄
                searchBar
                
                // 股票列表
                stockList
                
                // 交易面板
                if let selectedStock = selectedStock {
                    tradingPanel(for: selectedStock)
                }
            }
            .navigationTitle("股票交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("投資組合") {
                        // 顯示投資組合
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadStocks()
                }
            }
            .alert("錯誤", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("確定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("確認交易", isPresented: $showingOrderConfirmation) {
                Button("取消", role: .cancel) {
                    showingOrderConfirmation = false
                }
                Button("確認") {
                    if let stock = selectedStock {
                        Task {
                            await viewModel.executeOrder(
                                stock: stock,
                                action: tradeAction,
                                quantity: Int(quantity) ?? 0
                            )
                        }
                    }
                    showingOrderConfirmation = false
                }
            } message: {
                if let stock = selectedStock {
                    let orderAmount = (Double(quantity) ?? 0) * stock.price
                    Text("確定要\(tradeAction.displayName) \(quantity) 股 \(stock.name) 嗎？\n總金額: NT$ \(String(format: "%.0f", orderAmount))")
                }
            }
        }
    }
    
    // MARK: - 搜尋欄
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜尋股票代號或名稱", text: $viewModel.searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    Task {
                        await viewModel.searchStocks()
                    }
                }
            
            Button("搜尋") {
                Task {
                    await viewModel.searchStocks()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 股票列表
    
    private var stockList: some View {
        List {
            ForEach(viewModel.displayedStocks) { stock in
                StockRow(stock: stock, isSelected: selectedStock?.id == stock.id)
                    .onTapGesture {
                        selectedStock = stock
                    }
            }
        }
        .listStyle(PlainListStyle())
        .overlay {
            if viewModel.isLoading {
                ProgressView("載入中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.8))
            }
        }
    }
    
    // MARK: - 交易面板
    
    private func tradingPanel(for stock: Stock) -> some View {
        VStack(spacing: 16) {
            Divider()
            
            // 選中的股票資訊
            selectedStockInfo(stock)
            
            // 交易操作
            HStack {
                // 買賣選擇
                Picker("交易類型", selection: $tradeAction) {
                    ForEach(TradeAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: .infinity)
                
                // 數量輸入
                VStack(alignment: .leading, spacing: 4) {
                    Text("股數")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }
            
            // 預估金額
            if let quantityInt = Int(quantity), quantityInt > 0 {
                let totalAmount = Double(quantityInt) * stock.price
                
                VStack(spacing: 4) {
                    Text("預估金額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("NT$ \(String(format: "%.0f", totalAmount))")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            // 下單按鈕
            Button(action: {
                showingOrderConfirmation = true
            }) {
                Text("\(tradeAction.displayName) \(stock.name)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tradeAction == .buy ? Color.green : Color.red)
                    .cornerRadius(8)
            }
            .disabled(quantity.isEmpty || Int(quantity) ?? 0 <= 0)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - 選中股票資訊
    
    private func selectedStockInfo(_ stock: Stock) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(stock.symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("NT$ \(String(format: "%.2f", stock.price))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(stock.change >= 0 ? "+" : "")\(String(format: "%.2f", stock.change))")
                        Text("(\(stock.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", stock.changePercent))%)")
                    }
                    .font(.subheadline)
                    .foregroundColor(stock.change >= 0 ? .green : .red)
                }
            }
            
            // 成交量
            HStack {
                Text("成交量: \(stock.volume.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("更新時間: \(formatTime(stock.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 輔助方法
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 股票行
struct StockRow: View {
    let stock: Stock
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(stock.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("NT$ \(String(format: "%.2f", stock.price))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("\(stock.change >= 0 ? "+" : "")\(String(format: "%.2f", stock.change))")
                    Text("(\(stock.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", stock.changePercent))%)")
                }
                .font(.caption)
                .foregroundColor(stock.change >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - 交易 ViewModel
@MainActor
class TradingViewModel: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let stockService = StockService.shared
    private let portfolioService = PortfolioService.shared
    private let authService = AuthenticationService.shared
    
    var displayedStocks: [Stock] {
        if searchQuery.isEmpty {
            return stocks
        } else {
            return stocks.filter { stock in
                stock.name.contains(searchQuery) || 
                stock.symbol.contains(searchQuery)
            }
        }
    }
    
    func loadStocks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            stocks = try await stockService.fetchTaiwanStocks()
        } catch {
            errorMessage = "載入股票資料失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func searchStocks() async {
        guard !searchQuery.isEmpty else {
            await loadStocks()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            stocks = try await stockService.searchStocks(query: searchQuery)
        } catch {
            errorMessage = "搜尋失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func executeOrder(stock: Stock, action: TradeAction, quantity: Int) async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "請先登入"
            return
        }
        
        guard quantity > 0 else {
            errorMessage = "請輸入有效的股數"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let portfolioAction: TransactionAction = action == .buy ? .buy : .sell
            let amount = Double(quantity) * stock.price
            
            _ = try await portfolioService.executeTransaction(
                userId: userId,
                symbol: stock.symbol,
                action: portfolioAction,
                amount: amount
            )
            
            // 交易成功，清空輸入
            
        } catch {
            errorMessage = "交易失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - 交易動作
enum TradeAction: CaseIterable {
    case buy
    case sell
    
    var displayName: String {
        switch self {
        case .buy:
            return "買入"
        case .sell:
            return "賣出"
        }
    }
}

#Preview {
    TradingView(
        competition: Competition(
            id: UUID(),
            title: "測試競賽",
            description: "測試描述",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            status: "active",
            prizePool: 10000,
            participantCount: 50,
            createdAt: Date()
        )
    )
}