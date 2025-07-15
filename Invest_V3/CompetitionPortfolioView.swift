import SwiftUI

struct CompetitionPortfolioView: View {
    let competition: Competition
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var stockViewModel = StockViewModel()
    @State private var showingTradingView = false
    @State private var selectedStock: Stock?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 投資組合總覽
                    portfolioSummaryCard
                    
                    // 持股明細
                    holdingsSection
                    
                    // 交易記錄
                    transactionHistorySection
                }
                .padding()
            }
            .navigationTitle("競賽投資組合")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("交易") {
                        showingTradingView = true
                    }
                    .disabled(!competition.isActive)
                }
            }
            .sheet(isPresented: $showingTradingView) {
                TradingView(competition: competition)
            }
            .onAppear {
                Task {
                    await loadPortfolioData()
                }
            }
            .refreshable {
                await loadPortfolioData()
            }
        }
    }
    
    // MARK: - 投資組合總覽卡片
    
    private var portfolioSummaryCard: some View {
        VStack(spacing: 16) {
            // 總資產
            VStack(spacing: 8) {
                Text("總資產")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("NT$ \(String(format: "%.0f", portfolioViewModel.totalValue))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // 收益率
            VStack(spacing: 8) {
                Text("總收益率")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(portfolioViewModel.returnRateFormatted)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(portfolioViewModel.returnRateColor)
            }
            
            Divider()
            
            // 詳細資訊
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("可用現金")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("NT$ \(String(format: "%.0f", portfolioViewModel.availableCash))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("持股價值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("NT$ \(String(format: "%.0f", portfolioViewModel.holdingsValue))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            // 資產配置圖表
            if !portfolioViewModel.portfolioItems.isEmpty {
                PieChartView(
                    data: portfolioViewModel.portfolioItems,
                    title: "資產配置"
                )
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 持股明細
    
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("持股明細")
                .font(.headline)
                .foregroundColor(.primary)
            
            if portfolioViewModel.holdings.isEmpty {
                emptyHoldingsView
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(portfolioViewModel.holdings) { holding in
                        HoldingRow(holding: holding)
                            .onTapGesture {
                                // 查看股票詳情
                                if let stock = stockViewModel.stocks.first(where: { $0.symbol == holding.symbol }) {
                                    selectedStock = stock
                                }
                            }
                    }
                }
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 交易記錄
    
    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("交易記錄")
                .font(.headline)
                .foregroundColor(.primary)
            
            if portfolioViewModel.transactions.isEmpty {
                emptyTransactionsView
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(portfolioViewModel.transactions.prefix(10)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 空狀態視圖
    
    private var emptyHoldingsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("尚無持股")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("開始交易以建立您的投資組合")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("開始交易") {
                showingTradingView = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!competition.isActive)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyTransactionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("尚無交易記錄")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("進行首次交易後將顯示記錄")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 載入資料
    
    private func loadPortfolioData() async {
        await portfolioViewModel.loadPortfolioData()
        await stockViewModel.loadStocks()
    }
}

// MARK: - 持股行
struct HoldingRow: View {
    let holding: PortfolioHolding
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.symbol)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(holding.quantity) 股")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("NT$ \(String(format: "%.2f", holding.currentPrice))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("\(holding.unrealizedGainLoss >= 0 ? "+" : "")\(String(format: "%.2f%%", holding.unrealizedGainLossPercent))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(holding.unrealizedGainLoss >= 0 ? .green : .red)
                    
                    Text("NT$ \(String(format: "%.0f", holding.unrealizedGainLoss))")
                        .font(.caption)
                        .foregroundColor(holding.unrealizedGainLoss >= 0 ? .green : .red)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - 交易記錄行
struct TransactionRow: View {
    let transaction: PortfolioTransaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.symbol)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formatDate(transaction.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text(transaction.action == "buy" ? "買入" : "賣出")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(transaction.action == "buy" ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((transaction.action == "buy" ? Color.green : Color.red).opacity(0.1))
                    .cornerRadius(4)
                
                Text("\(transaction.quantity) 股")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("NT$ \(String(format: "%.2f", transaction.price))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("NT$ \(String(format: "%.0f", transaction.amount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 投資組合 ViewModel
@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio?
    @Published var holdings: [PortfolioHolding] = []
    @Published var transactions: [PortfolioTransaction] = []
    @Published var portfolioItems: [PortfolioItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let portfolioService = PortfolioService.shared
    private let authService = AuthenticationService.shared
    
    var totalValue: Double {
        portfolio?.totalValue ?? 0
    }
    
    var availableCash: Double {
        portfolio?.availableCash ?? 0
    }
    
    var holdingsValue: Double {
        holdings.reduce(0) { $0 + $1.totalValue }
    }
    
    var returnRateFormatted: String {
        guard let portfolio = portfolio else { return "0.00%" }
        return String(format: "%.2f%%", portfolio.returnRate)
    }
    
    var returnRateColor: Color {
        guard let portfolio = portfolio else { return .gray }
        return portfolio.returnRate >= 0 ? .green : .red
    }
    
    func loadPortfolioData() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            portfolio = try await portfolioService.fetchUserPortfolio(userId: userId)
            transactions = try await portfolioService.fetchPortfolioTransactions(userId: userId)
            portfolioItems = try await portfolioService.getPortfolioDistribution(userId: userId)
            
            // 轉換交易記錄為持股
            holdings = convertTransactionsToHoldings(transactions)
        } catch {
            errorMessage = "載入投資組合失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func convertTransactionsToHoldings(_ transactions: [PortfolioTransaction]) -> [PortfolioHolding] {
        let groupedTransactions = Dictionary(grouping: transactions) { $0.symbol }
        var holdings: [PortfolioHolding] = []
        
        for (symbol, symbolTransactions) in groupedTransactions {
            let buyTransactions = symbolTransactions.filter { $0.action == "buy" }
            let sellTransactions = symbolTransactions.filter { $0.action == "sell" }
            
            let totalBuyQuantity = buyTransactions.reduce(0) { $0 + $1.quantity }
            let totalSellQuantity = sellTransactions.reduce(0) { $0 + $1.quantity }
            let netQuantity = totalBuyQuantity - totalSellQuantity
            
            if netQuantity > 0 {
                let totalBuyAmount = buyTransactions.reduce(0.0) { $0 + $1.amount }
                let averagePrice = totalBuyAmount / Double(totalBuyQuantity)
                
                // 假設當前價格（實際應該從股票服務獲取）
                let currentPrice = symbolTransactions.last?.price ?? averagePrice
                
                let holding = PortfolioHolding(
                    id: UUID(),
                    userId: authService.currentUser?.id ?? UUID(),
                    symbol: symbol,
                    quantity: netQuantity,
                    averagePrice: averagePrice,
                    currentPrice: currentPrice,
                    lastUpdated: Date()
                )
                
                holdings.append(holding)
            }
        }
        
        return holdings
    }
}

// MARK: - 股票 ViewModel
@MainActor
class StockViewModel: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let stockService = StockService.shared
    
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
}

#Preview {
    CompetitionPortfolioView(
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