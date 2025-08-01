import SwiftUI

struct PortfolioView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @State private var selectedSegment = 0
    
    private let segments = ["總覽", "持股", "交易記錄"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分段控制器
                segmentPicker
                
                // 內容區域
                contentView
            }
            .navigationTitle("投資組合")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
            .onAppear {
                Task {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - 分段選擇器
    private var segmentPicker: some View {
        Picker("投資組合選項", selection: $selectedSegment) {
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
            PortfolioOverviewView()
        case 1:
            PortfolioHoldingsView()
        case 2:
            TradingHistoryView()
        default:
            PortfolioOverviewView()
        }
    }
    
    private func loadData() async {
        await tradingService.loadPortfolio()
        await tradingService.loadTransactions()
    }
}

// MARK: - 投資組合總覽
struct PortfolioOverviewView: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 資產總覽卡片
                if let user = tradingService.currentUser {
                    AssetOverviewCard(user: user)
                }
                
                // 投資組合分析
                if let portfolio = tradingService.portfolio {
                    PortfolioAnalysisCard(portfolio: portfolio)
                }
                
                // 資產分配圖
                AssetAllocationCard()
                
                // 績效圖表
                PerformanceChartCard()
            }
            .padding()
        }
    }
}

// MARK: - 資產總覽卡片
struct AssetOverviewCard: View {
    let user: TradingUser
    
    var body: some View {
        VStack(spacing: 16) {
            // 總資產
            VStack(spacing: 8) {
                Text("總資產")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(TradingService.shared.formatCurrency(user.totalAssets))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            // 資產分佈
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現金")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(user.cashBalance))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("持股市值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let stockValue = user.totalAssets - user.cashBalance
                    Text(TradingService.shared.formatCurrency(stockValue))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("總損益")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let totalProfit = user.totalAssets - 1000000 // 初始資金
                    Text(TradingService.shared.formatCurrency(totalProfit))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(totalProfit >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 投資組合分析卡片
struct PortfolioAnalysisCard: View {
    let portfolio: TradingPortfolio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("投資組合分析")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                AnalysisRow(
                    title: "持股檔數",
                    value: "\(portfolio.positions.count)檔",
                    icon: "chart.pie"
                )
                
                AnalysisRow(
                    title: "未實現損益",
                    value: TradingService.shared.formatCurrency(portfolio.totalProfit),
                    icon: "arrow.up.arrow.down",
                    valueColor: portfolio.totalProfit >= 0 ? .green : .red
                )
                
                AnalysisRow(
                    title: "累計報酬率",
                    value: TradingService.shared.formatPercentage(portfolio.cumulativeReturn),
                    icon: "percent",
                    valueColor: portfolio.cumulativeReturn >= 0 ? .green : .red
                )
                
                AnalysisRow(
                    title: "現金比重",
                    value: String(format: "%.1f%%", (portfolio.cashBalance / portfolio.totalAssets) * 100),
                    icon: "dollarsign.circle"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 分析行
struct AnalysisRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color.brandGreen)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - 資產分配卡片
struct AssetAllocationCard: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    private var allocationData: [PieChartData] {
        return AssetAllocationCalculator.calculateAllocation(from: tradingService.portfolio)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("資產分配")
                .font(.headline)
                .fontWeight(.bold)
            
            if allocationData.isEmpty {
                // 空狀態
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("暫無資產分配資料")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 120)
            } else {
                DynamicPieChart(data: allocationData, size: 120)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 圖例項目
struct LegendItem: View {
    let color: Color
    let title: String
    let percentage: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(percentage)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 績效圖表卡片
struct PerformanceChartCard: View {
    @ObservedObject private var tradingService = TradingService.shared
    @State private var selectedTimeRange: PerformanceTimeRange = .month
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題和時間選擇器
            HStack {
                Text("績效走勢")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 時間範圍選擇器
                Menu {
                    ForEach(PerformanceTimeRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            selectedTimeRange = range
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedTimeRange.rawValue)
                            .font(.caption)
                            .foregroundColor(.brandGreen)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.brandGreen)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandGreen.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // 績效圖表
            let performanceData = PerformanceDataGenerator.generateData(
                for: selectedTimeRange,
                portfolio: tradingService.portfolio
            )
            
            if performanceData.isEmpty {
                // 空狀態
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 150)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            
                            Text("暫無績效數據")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            } else {
                PerformanceChart(
                    data: performanceData,
                    timeRange: selectedTimeRange,
                    width: UIScreen.main.bounds.width - 64, // 考慮 padding
                    height: 150
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 投資組合持股視圖
struct PortfolioHoldingsView: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        if let portfolio = tradingService.portfolio, !portfolio.positions.isEmpty {
            List(portfolio.positions) { position in
                PortfolioPositionRow(position: position)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(PlainListStyle())
        } else {
            GeneralEmptyStateView(
                icon: "briefcase",
                title: "暫無持股",
                message: "開始您的第一筆投資吧！"
            )
        }
    }
}

// MARK: - 投資組合持股行
struct PortfolioPositionRow: View {
    let position: PortfolioPosition
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 股票顏色指示器
                Circle()
                    .fill(StockColorPalette.colorForStock(symbol: position.symbol))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                
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
                    
                    Text(TradingService.shared.formatCurrency(position.currentPrice))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("成本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(position.averageCost))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("未實現損益")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(TradingService.shared.formatCurrency(position.unrealizedPnl))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(position.unrealizedPnl >= 0 ? .green : .red)
                        
                        Text(String(format: "(%.2f%%)", position.unrealizedPnlPercent))
                            .font(.caption2)
                            .foregroundColor(position.unrealizedPnl >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 交易記錄視圖
struct TradingHistoryView: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if tradingService.transactions.isEmpty {
                    GeneralEmptyStateView(
                        icon: "list.bullet",
                        title: "暫無交易記錄",
                        message: "開始您的第一筆交易吧！"
                    )
                } else {
                    List(tradingService.transactions) { transaction in
                        TransactionHistoryRow(transaction: transaction)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("交易記錄")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await tradingService.loadTransactions()
            }
        }
    }
}

// MARK: - 交易記錄行
struct TransactionHistoryRow: View {
    let transaction: TradingTransaction
    
    var body: some View {
        HStack {
            // 交易類型圖標
            Circle()
                .fill(Color(hex: transaction.actionColor) ?? .gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transaction.action == "buy" ? "plus" : "minus")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(transaction.actionText) \(transaction.symbol)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(TradingService.shared.formatCurrency(transaction.totalAmount))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.action == "buy" ? .red : .green)
                }
                
                HStack {
                    Text("\(transaction.quantity)股 @ \(TradingService.shared.formatCurrency(transaction.price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTransactionTime(transaction.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if transaction.fee > 0 {
                    Text("手續費: \(TradingService.shared.formatCurrency(transaction.fee))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatTransactionTime(_ timestamp: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: String(timestamp.prefix(19))) {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
        return timestamp
    }
}

#Preview {
    PortfolioView()
}