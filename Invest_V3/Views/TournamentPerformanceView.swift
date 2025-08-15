//
//  TournamentPerformanceView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽專用績效圖表和統計功能
//

import SwiftUI
import Charts

struct TournamentPerformanceView: View {
    let tournamentPortfolio: TournamentPortfolio
    let tournament: Tournament
    
    @State private var selectedTimeRange: PerformanceTimeRange = .week
    @State private var showDetailStats = false
    @State private var selectedMetric: PerformanceMetric = .portfolio
    
    enum PerformanceMetric: String, CaseIterable {
        case portfolio = "投資組合價值"
        case returns = "累計報酬率"
        case dailyChange = "每日變化"
        case trades = "交易次數"
        
        var icon: String {
            switch self {
            case .portfolio: return "chart.bar.fill"
            case .returns: return "arrow.up.right"
            case .dailyChange: return "waveform.path.ecg"
            case .trades: return "arrow.left.arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .portfolio: return .blue
            case .returns: return .green
            case .dailyChange: return .orange
            case .trades: return .purple
            }
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 錦標賽標題和排名
                tournamentHeaderSection
                
                // 關鍵指標卡片
                keyMetricsSection
                
                // 時間範圍選擇器
                timeRangeSelector
                
                // 績效圖表
                performanceChartSection
                
                // 詳細統計
                detailedStatsSection
                
                // 持股分析
                holdingsAnalysisSection
                
                // 交易活動
                tradingActivitySection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // 為底部導航留空間
        }
        .navigationTitle("錦標賽績效")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showDetailStats.toggle() }) {
                    Image(systemName: showDetailStats ? "list.bullet" : "chart.bar")
                        .foregroundColor(.brandGreen)
                }
            }
        }
    }
    
    // MARK: - 錦標賽標題區域
    private var tournamentHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("初始資金: \(formatCurrency(tournament.initialBalance))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text("第 \(tournamentPortfolio.performanceMetrics.currentRank) 名")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    let rankChange = tournamentPortfolio.performanceMetrics.rankChange
                    if rankChange != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: rankChange > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                                .foregroundColor(rankChange > 0 ? .green : .red)
                            
                            Text("\(abs(rankChange))")
                                .font(.caption)
                                .foregroundColor(rankChange > 0 ? .green : .red)
                        }
                    }
                }
            }
            
            // 進度條（錦標賽進度）
            if tournament.status == .ongoing {
                TournamentProgressBar(
                    startDate: tournament.startDate,
                    endDate: tournament.endDate,
                    currentDate: Date()
                )
            }
        }
        .padding(16)
        .background(getCardBackgroundColor())
        .cornerRadius(12)
        .shadow(color: getCardShadowColor(), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 關鍵指標卡片
    private var keyMetricsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            // 投資組合總值
            TournamentMetricCard(
                title: "投資組合總值",
                value: formatCurrency(tournamentPortfolio.totalPortfolioValue),
                subtitle: "初始: \(formatCurrency(tournamentPortfolio.initialBalance))",
                icon: "dollarsign.circle.fill",
                color: .blue,
                trend: tournamentPortfolio.totalReturnPercentage
            )
            
            // 總報酬率
            TournamentMetricCard(
                title: "總報酬率",
                value: String(format: "%.2f%%", tournamentPortfolio.totalReturnPercentage),
                subtitle: formatCurrency(tournamentPortfolio.totalReturn),
                icon: "chart.line.uptrend.xyaxis",
                color: tournamentPortfolio.totalReturn >= 0 ? .green : .red,
                trend: tournamentPortfolio.totalReturnPercentage
            )
            
            // 現金比例
            TournamentMetricCard(
                title: "現金比例",
                value: String(format: "%.1f%%", tournamentPortfolio.cashPercentage),
                subtitle: formatCurrency(tournamentPortfolio.currentBalance),
                icon: "banknote.fill",
                color: .orange,
                trend: nil
            )
            
            // 交易次數
            TournamentMetricCard(
                title: "交易次數",
                value: "\(tournamentPortfolio.performanceMetrics.totalTrades)",
                subtitle: "勝率: \(String(format: "%.1f%%", tournamentPortfolio.performanceMetrics.winRate * 100))",
                icon: "arrow.left.arrow.right",
                color: .purple,
                trend: nil
            )
        }
    }
    
    // MARK: - 時間範圍選擇器
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PerformanceTimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        selectedTimeRange = range
                    }) {
                        Text(range.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedTimeRange == range ? Color.brandGreen : getTimeRangeButtonBackgroundColor())
                            )
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 績效圖表區域
    private var performanceChartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("績效表現")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 指標選擇器
                Picker("績效指標", selection: $selectedMetric) {
                    ForEach(PerformanceMetric.allCases, id: \.self) { metric in
                        Label(metric.rawValue, systemImage: metric.icon)
                            .tag(metric)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // 錦標賽專用績效圖表
            TournamentPerformanceChart(
                portfolio: tournamentPortfolio,
                timeRange: selectedTimeRange,
                metric: selectedMetric
            )
            .frame(height: 200)
            .background(getChartContainerBackgroundColor())
            .cornerRadius(12)
        }
        .padding(16)
        .background(getCardBackgroundColor())
        .cornerRadius(12)
        .shadow(color: getCardShadowColor(), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 詳細統計區域
    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("詳細統計")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatRow(title: "最大回撤", value: String(format: "%.2f%%", tournamentPortfolio.performanceMetrics.maxDrawdown * 100))
                StatRow(title: "夏普比率", value: tournamentPortfolio.performanceMetrics.sharpeRatio.map { String(format: "%.2f", $0) } ?? "N/A")
                StatRow(title: "風險評分", value: String(format: "%.1f/100", tournamentPortfolio.performanceMetrics.riskScore))
                StatRow(title: "多元化評分", value: String(format: "%.1f/100", tournamentPortfolio.performanceMetrics.diversificationScore))
                StatRow(title: "平均持股天數", value: String(format: "%.1f天", tournamentPortfolio.performanceMetrics.avgHoldingDays))
                StatRow(title: "盈利交易", value: "\(tournamentPortfolio.performanceMetrics.profitableTrades)/\(tournamentPortfolio.performanceMetrics.totalTrades)")
            }
        }
        .padding(16)
        .background(getCardBackgroundColor())
        .cornerRadius(12)
        .shadow(color: getCardShadowColor(), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 持股分析區域
    private var holdingsAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("持股分析")
                .font(.headline)
                .fontWeight(.bold)
            
            if tournamentPortfolio.holdings.isEmpty {
                Text("目前沒有持股")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(tournamentPortfolio.holdings.sorted(by: { $0.totalValue > $1.totalValue })) { holding in
                        TournamentHoldingRow(holding: holding)
                    }
                }
            }
        }
        .padding(16)
        .background(getCardBackgroundColor())
        .cornerRadius(12)
        .shadow(color: getCardShadowColor(), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 交易活動區域
    private var tradingActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近交易")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("共 \(tournamentPortfolio.tradingRecords.count) 筆")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if tournamentPortfolio.tradingRecords.isEmpty {
                Text("尚無交易記錄")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(tournamentPortfolio.tradingRecords.suffix(5).reversed())) { record in
                        TournamentTradeRow(record: record)
                    }
                }
                
                if tournamentPortfolio.tradingRecords.count > 5 {
                    NavigationLink(destination: TournamentTradeHistoryView(records: tournamentPortfolio.tradingRecords)) {
                        Text("查看全部交易記錄")
                            .font(.caption)
                            .foregroundColor(.brandGreen)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(16)
        .background(getCardBackgroundColor())
        .cornerRadius(12)
        .shadow(color: getCardShadowColor(), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 輔助方法
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "NT$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
    
    // MARK: - 深色模式支援方法
    
    /// 獲取卡片背景顏色
    private func getCardBackgroundColor() -> Color {
        return Color(.systemBackground)
    }
    
    /// 獲取卡片陰影顏色
    private func getCardShadowColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.white.withAlphaComponent(0.05)
                : UIColor.black.withAlphaComponent(0.1)
        })
    }
    
    /// 獲取時間範圍按鈕背景顏色
    private func getTimeRangeButtonBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGray4
                : UIColor.systemGray5
        })
    }
    
    /// 獲取圖表容器背景顏色
    private func getChartContainerBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGray6.withAlphaComponent(0.2)
                : UIColor.systemGray6.withAlphaComponent(0.3)
        })
    }
    
    /// 獲取指標卡片陰影顏色
    private func getMetricCardShadowColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.white.withAlphaComponent(0.02)
                : UIColor.black.withAlphaComponent(0.05)
        })
    }
    
    /// 獲取統計行背景顏色
    private func getStatRowBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGray5.withAlphaComponent(0.3)
                : UIColor.systemGray6.withAlphaComponent(0.5)
        })
    }
}

// MARK: - 指標卡片組件
struct TournamentMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                        
                        Text(String(format: "%.2f%%", abs(trend)))
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(getCardBackgroundColor())
        .cornerRadius(8)
        .shadow(color: getMetricCardShadowColor(), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Helper Methods
    
    /// 獲取卡片背景顏色
    private func getCardBackgroundColor() -> Color {
        return Color(.systemBackground)
    }
    
    /// 獲取指標卡片陰影顏色
    private func getMetricCardShadowColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.white.withAlphaComponent(0.02)
                : UIColor.black.withAlphaComponent(0.05)
        })
    }
}

// MARK: - 統計行組件
struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(getStatRowBackgroundColor())
        .cornerRadius(6)
    }
    
    /// 獲取統計行背景顏色
    private func getStatRowBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGray5.withAlphaComponent(0.3)
                : UIColor.systemGray6.withAlphaComponent(0.5)
        })
    }
}

// MARK: - 錦標賽進度條
struct TournamentProgressBar: View {
    let startDate: Date
    let endDate: Date
    let currentDate: Date
    
    private var progress: Double {
        let totalDuration = endDate.timeIntervalSince(startDate)
        let elapsed = currentDate.timeIntervalSince(startDate)
        return min(max(elapsed / totalDuration, 0), 1)
    }
    
    private var remainingDays: Int {
        let remaining = endDate.timeIntervalSince(currentDate)
        return max(Int(remaining / 86400), 0) // 86400 seconds in a day
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("錦標賽進度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("剩餘 \(remainingDays) 天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.brandGreen, .green]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - 預覽
#Preview {
    NavigationView {
        TournamentPerformanceView(
            tournamentPortfolio: TournamentPortfolioV2(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                cashBalance: 950000,
                equityValue: 50000,
                totalAssets: 1000000,
                initialBalance: 1000000,
                totalReturn: -50000,
                returnPercentage: -5.0,
                totalTrades: 10,
                winningTrades: 6,
                maxDrawdown: 10000,
                dailyReturn: 0.0,
                sharpeRatio: nil,
                lastUpdated: Date()
            ),
            tournament: Tournament(
                id: UUID(),
                name: "春季投資挑戰賽",
                type: .monthly,
                status: .ongoing,
                startDate: Date().addingTimeInterval(-86400 * 7),
                endDate: Date().addingTimeInterval(86400 * 23),
                description: "測試錦標賽",
                shortDescription: "春季投資挑戰賽",
                initialBalance: 1000000,
                entryFee: 0,
                prizePool: 0,
                maxParticipants: 100,
                currentParticipants: 75,
                isFeatured: false,
                createdBy: UUID(),
                riskLimitPercentage: 20.0,
                minHoldingRate: 60.0,
                maxSingleStockRate: 30.0,
                rules: ["最大單股比例不超過30%", "最小持股比例不少於60%"],
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}