import SwiftUI

struct PortfolioView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
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
            .navigationTitle(portfolioTitle)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
            .onAppear {
                Task {
                    await loadData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TournamentContextChanged"))) { _ in
                print("🔄 [PortfolioView] 錦標賽切換，重新載入投資組合")
                Task {
                    await loadData()
                }
            }
            .onChange(of: tournamentStateManager.currentTournamentContext) { _, _ in
                print("🔄 [PortfolioView] 錦標賽上下文變更，重新載入投資組合")
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
        // Check if we're in tournament mode
        if tournamentStateManager.isParticipatingInTournament {
            // In tournament mode, try to load tournament-specific data from Supabase
            print("🏆 [PortfolioView] Tournament mode active - loading tournament portfolio data")
            
            if let tournamentId = tournamentStateManager.getCurrentTournamentId(),
               let currentUser = SupabaseService.shared.getCurrentUser() {
                
                do {
                    // 使用統一的 PortfolioService 載入錦標賽投資組合
                    let tournamentPortfolio = try await PortfolioService.shared.fetchUserPortfolio(
                        userId: currentUser.id,
                        tournamentId: tournamentId
                    )
                    
                    print("✅ [PortfolioView] 統一錦標賽投資組合載入成功")
                    print("   - 投資組合類型: \(tournamentPortfolio.portfolioType.displayName)")
                    print("   - 總價值: $\(Int(tournamentPortfolio.totalValue))")
                    print("   - 回報率: \(tournamentPortfolio.returnRateFormatted)")
                    
                    // 備用方案：同時嘗試載入詳細持股數據
                    do {
                        let holdings = try await PortfolioService.shared.fetchTournamentHoldings(
                            userId: currentUser.id,
                            tournamentId: tournamentId
                        )
                        print("✅ [PortfolioView] 錦標賽持股明細載入成功: \(holdings.count) 項")
                    } catch {
                        print("⚠️ [PortfolioView] 錦標賽持股明細載入失敗: \(error)")
                    }
                    
                    print("🏆 [PortfolioView] 錦標賽 \(tournamentId) 統一投資組合數據載入完成")
                    
                } catch {
                    print("⚠️ [PortfolioView] 統一投資組合載入失敗，嘗試舊方案: \(error)")
                    
                    // 備用方案：使用舊的 Supabase 方法
                    do {
                        let tournamentPortfolio = try await SupabaseService.shared.fetchTournamentPortfolio(
                            tournamentId: tournamentId, 
                            userId: currentUser.id
                        )
                        
                        if let portfolio = tournamentPortfolio {
                            print("✅ [PortfolioView] 備用方案：載入錦標賽投資組合成功")
                        } else {
                            print("🔄 [PortfolioView] 備用方案：使用 TournamentPortfolioManager")
                        }
                    } catch {
                        print("❌ [PortfolioView] 所有錦標賽數據載入方案都失敗: \(error)")
                    }
                }
            } else {
                print("❌ [PortfolioView] 缺少錦標賽 ID 或用戶資訊")
            }
        } else {
            // 一般模式：載入非錦標賽投資組合
            print("📊 [PortfolioView] 一般模式 - 載入一般投資組合")
            
            // 嘗試使用統一的 PortfolioService
            if let currentUser = SupabaseService.shared.getCurrentUser() {
                do {
                    let generalPortfolio = try await PortfolioService.shared.fetchUserPortfolio(
                        userId: currentUser.id,
                        tournamentId: nil,
                        groupId: nil
                    )
                    
                    print("✅ [PortfolioView] 統一一般投資組合載入成功")
                    print("   - 投資組合類型: \(generalPortfolio.portfolioType.displayName)")
                    print("   - 總價值: $\(Int(generalPortfolio.totalValue))")
                    print("   - 回報率: \(generalPortfolio.returnRateFormatted)")
                    
                } catch {
                    print("⚠️ [PortfolioView] 統一投資組合載入失敗，使用 TradingService: \(error)")
                }
            }
            
            // 備用方案：使用原有的 TradingService
            await tradingService.loadPortfolio()
            await tradingService.loadTransactions()
            print("📊 [PortfolioView] 一般模式數據載入完成")
        }
    }
    
    // MARK: - 計算屬性
    
    private var portfolioTitle: String {
        if let tournamentName = tournamentStateManager.getCurrentTournamentDisplayName() {
            return "\(tournamentName) - 投資組合"
        } else {
            return "投資組合"
        }
    }
}

// MARK: - 投資組合總覽
struct PortfolioOverviewView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 資產總覽卡片
                if tournamentStateManager.isParticipatingInTournament {
                    // Tournament mode - show tournament portfolio
                    if let context = tournamentStateManager.currentTournamentContext,
                       let portfolio = context.portfolio {
                        TournamentAssetOverviewCard(portfolio: portfolio, tournament: context.tournament)
                    }
                } else {
                    // Regular mode - show trading service data
                    if let user = tradingService.currentUser {
                        AssetOverviewCard(user: user)
                    }
                }
                
                // 投資組合分析
                if tournamentStateManager.isParticipatingInTournament {
                    // Tournament mode - use tournament portfolio
                    if let context = tournamentStateManager.currentTournamentContext,
                       let portfolio = context.portfolio {
                        TournamentPortfolioAnalysisCard(portfolio: portfolio)
                    }
                } else {
                    // Regular mode
                    if let portfolio = tradingService.portfolio {
                        PortfolioAnalysisCard(portfolio: portfolio)
                    }
                }
                
                // 資產分配圖
                TournamentAwareAssetAllocationCard()
                
                // 績效圖表
                TournamentAwarePerformanceChartCard()
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
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    
    var body: some View {
        Group {
            if tournamentStateManager.isParticipatingInTournament {
                // Tournament mode - show tournament portfolio holdings
                if let context = tournamentStateManager.currentTournamentContext,
                   let portfolio = context.portfolio,
                   !portfolio.allocations.isEmpty {
                    List(portfolio.allocations) { allocation in
                        TournamentAllocationRow(allocation: allocation)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(PlainListStyle())
                } else {
                    GeneralEmptyStateView(
                        icon: "trophy",
                        title: "錦標賽尚無持股",
                        message: "開始您的錦標賽投資之旅吧！"
                    )
                }
            } else {
                // Regular mode
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
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    
    var body: some View {
        NavigationView {
            Group {
                if tournamentStateManager.isParticipatingInTournament {
                    // Tournament mode - show tournament transactions (empty for now)
                    GeneralEmptyStateView(
                        icon: "trophy",
                        title: "錦標賽交易記錄",
                        message: "錦標賽交易記錄將在此顯示"
                    )
                } else {
                    // Regular mode
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
            }
            .navigationTitle(tournamentStateManager.isParticipatingInTournament ? "錦標賽交易記錄" : "交易記錄")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                if !tournamentStateManager.isParticipatingInTournament {
                    await tradingService.loadTransactions()
                }
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

// MARK: - Tournament-Specific Components

// MARK: - 錦標賽資產總覽卡片
struct TournamentAssetOverviewCard: View {
    let portfolio: TournamentPortfolio
    let tournament: Tournament
    
    var body: some View {
        VStack(spacing: 16) {
            // 總資產
            VStack(spacing: 8) {
                Text("錦標賽總資產")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(TradingService.shared.formatCurrency(portfolio.totalPortfolioValue))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            // 資產分佈
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現金")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(portfolio.currentBalance))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("持股市值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let stockValue = portfolio.holdingsValue
                    Text(TradingService.shared.formatCurrency(stockValue))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("總損益")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let totalProfit = portfolio.totalReturn
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

// MARK: - 錦標賽投資組合分析卡片
struct TournamentPortfolioAnalysisCard: View {
    let portfolio: TournamentPortfolio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("錦標賽投資組合分析")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                AnalysisRow(
                    title: "持股檔數",
                    value: "\(portfolio.holdings.count)檔",
                    icon: "chart.pie"
                )
                
                AnalysisRow(
                    title: "未實現損益",
                    value: TradingService.shared.formatCurrency(portfolio.holdingsValue - portfolio.totalInvested),
                    icon: "arrow.up.arrow.down",
                    valueColor: (portfolio.holdingsValue - portfolio.totalInvested) >= 0 ? .green : .red
                )
                
                AnalysisRow(
                    title: "累計報酬率",
                    value: String(format: "%.2f%%", portfolio.totalReturnPercentage),
                    icon: "percent",
                    valueColor: portfolio.totalReturnPercentage >= 0 ? .green : .red
                )
                
                AnalysisRow(
                    title: "現金比重",
                    value: String(format: "%.1f%%", portfolio.cashPercentage),
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

// MARK: - 錦標賽感知資產分配卡片
struct TournamentAwareAssetAllocationCard: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    
    private var allocationData: [PieChartData] {
        if tournamentStateManager.isParticipatingInTournament,
           let context = tournamentStateManager.currentTournamentContext,
           let portfolio = context.portfolio {
            return TournamentAssetAllocationCalculator.calculateAllocation(from: portfolio)
        } else {
            return AssetAllocationCalculator.calculateAllocation(from: tradingService.portfolio)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("資產分配")
                .font(.headline)
                .fontWeight(.bold)
            
            chartContent
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if allocationData.isEmpty {
            // 空狀態
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(tournamentStateManager.isParticipatingInTournament ? "錦標賽尚未開始投資" : "暫無資產分配資料")
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
}

// MARK: - 錦標賽感知績效圖表卡片
struct TournamentAwarePerformanceChartCard: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
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
            performanceChartContent
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var performanceData: [PerformanceDataPoint] {
        if tournamentStateManager.isParticipatingInTournament,
           let context = tournamentStateManager.currentTournamentContext,
           let portfolio = context.portfolio {
            return TournamentPerformanceDataGenerator.generateData(
                for: selectedTimeRange,
                portfolio: portfolio,
                tournament: context.tournament
            )
        } else {
            return PerformanceDataGenerator.generateData(
                for: selectedTimeRange,
                portfolio: tradingService.portfolio
            )
        }
    }
    
    @ViewBuilder
    private var performanceChartContent: some View {
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
                        
                        Text(tournamentStateManager.isParticipatingInTournament ? "錦標賽績效數據收集中" : "暫無績效數據")
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
}

// MARK: - Tournament Asset Allocation Calculator
struct TournamentAssetAllocationCalculator {
    static func calculateAllocation(from portfolio: TournamentPortfolio?) -> [PieChartData] {
        guard let portfolio = portfolio, !portfolio.holdings.isEmpty else {
            return []
        }
        
        let totalValue = portfolio.totalPortfolioValue
        
        return portfolio.holdings.map { holding in
            let percentage = totalValue > 0 ? (holding.totalValue / totalValue) * 100 : 0
            
            return PieChartData(
                category: holding.symbol,
                value: percentage,
                color: StockColorPalette.colorForStock(symbol: holding.symbol),
                holdingQuantity: holding.shares,
                purchasePrice: holding.averagePrice,
                currentValue: holding.totalValue,
                currentPrice: holding.currentPrice,
                unrealizedGainLoss: holding.unrealizedGainLoss,
                symbol: holding.symbol
            )
        }
    }
}

// MARK: - Tournament Performance Data Generator
struct TournamentPerformanceDataGenerator {
    static func generateData(for timeRange: PerformanceTimeRange, portfolio: TournamentPortfolio, tournament: Tournament) -> [PerformanceDataPoint] {
        // Generate tournament-specific performance data
        // This would normally come from the tournament service
        let days = timeRange.days
        let startValue = tournament.initialBalance
        let currentValue = portfolio.totalPortfolioValue
        
        return (0..<days).map { day in
            let progress = Double(day) / Double(days - 1)
            let value = startValue + (currentValue - startValue) * progress
            let date = Calendar.current.date(byAdding: .day, value: -days + day + 1, to: Date()) ?? Date()
            
            return PerformanceDataPoint(
                date: date,
                value: value,
                returnPercentage: ((value - startValue) / startValue) * 100
            )
        }
    }
}

// MARK: - 錦標賽配置行
struct TournamentAllocationRow: View {
    let allocation: AssetAllocation
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 股票顏色指示器
                Circle()
                    .fill(StockColorPalette.colorForStock(symbol: allocation.symbol))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(allocation.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("配置比重: \(String(format: "%.1f%%", allocation.percentage))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TradingService.shared.formatCurrency(allocation.value))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("目標配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("投資金額")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(allocation.investedAmount))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("目前價值")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    let currentValue = allocation.value
                    let profit = currentValue - allocation.investedAmount
                    let profitPercent = allocation.investedAmount > 0 ? (profit / allocation.investedAmount) * 100 : 0
                    
                    HStack(spacing: 4) {
                        Text(TradingService.shared.formatCurrency(profit))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(profit >= 0 ? .green : .red)
                        
                        Text(String(format: "(%.2f%%)", profitPercent))
                            .font(.caption2)
                            .foregroundColor(profit >= 0 ? .green : .red)
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

#Preview {
    PortfolioView()
}