//
//  TournamentPerformanceChart.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽專用績效圖表組件
//

import SwiftUI
import Charts

struct TournamentPerformanceChart: View {
    let portfolio: TournamentPortfolio
    let timeRange: PerformanceTimeRange
    let metric: TournamentPerformanceView.PerformanceMetric
    
    @State private var selectedDataPoint: TournamentPerformanceDataPoint?
    @State private var showTooltip = false
    
    private var chartData: [TournamentPerformanceDataPoint] {
        generateRealChartData()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 圖表標題和當前值
            chartHeader
            
            // 圖表區域
            if chartData.isEmpty {
                emptyChartView
            } else {
                chartView
            }
        }
    }
    
    // MARK: - 圖表標題
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let selectedPoint = selectedDataPoint {
                    Text(formatValue(selectedPoint.value, for: metric))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(getValueColor(selectedPoint.value, for: metric))
                } else if let lastPoint = chartData.last {
                    Text(formatValue(lastPoint.value, for: metric))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(getValueColor(lastPoint.value, for: metric))
                }
            }
            
            Spacer()
            
            // 時間範圍指示器
            Text(timeRange.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brandGreen.opacity(0.1))
                .foregroundColor(.brandGreen)
                .cornerRadius(4)
        }
    }
    
    // MARK: - 圖表視圖
    private var chartView: some View {
        Chart(chartData) { dataPoint in
            switch metric {
            case .portfolio, .returns:
                LineMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(getDynamicColor(for: metric))
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            getDynamicColor(for: metric).opacity(0.3), 
                            getDynamicColor(for: metric).opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
            case .dailyChange:
                BarMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(dataPoint.value >= 0 ? Color.taiwanStockUp : Color.taiwanStockDown)
                
            case .trades:
                LineMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(getDynamicColor(for: metric))
                .symbol(.circle)
                .symbolSize(30)
        }
        }
        .frame(height: 180)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartBackground { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(getChartBackgroundColor())
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, in: geometry, proxy: proxy)
                            }
                            .onEnded { _ in
                                selectedDataPoint = nil
                                showTooltip = false
                            }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            if let selectedPoint = selectedDataPoint, showTooltip {
                tooltipView(for: selectedPoint)
            }
        }
    }
    
    // MARK: - 空圖表視圖
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暫無數據")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("錦標賽進行期間將顯示績效數據")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 工具提示
    private func tooltipView(for dataPoint: TournamentPerformanceDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(dataPoint.date))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatValue(dataPoint.value, for: metric))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(getValueColor(dataPoint.value, for: metric))
            
            if let change = dataPoint.change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundColor(change >= 0 ? .taiwanStockUp : .taiwanStockDown)
                    
                    Text(String(format: "%+.2f%%", change))
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .taiwanStockUp : .taiwanStockDown)
                }
            }
        }
        .padding(8)
        .background(getTooltipBackgroundColor())
        .cornerRadius(8)
        .shadow(color: getShadowColor(), radius: 4)
        .animation(.easeInOut(duration: 0.2), value: showTooltip)
    }
    
    // MARK: - 私有方法
    private func updateSelection(at location: CGPoint, in geometry: GeometryProxy, proxy: ChartProxy) {
        guard !chartData.isEmpty else { return }
        
        let xPosition = location.x - geometry[proxy.plotAreaFrame].minX
        let plotWidth = geometry[proxy.plotAreaFrame].width
        let dataIndex = Int((xPosition / plotWidth) * CGFloat(chartData.count - 1))
        
        if dataIndex >= 0 && dataIndex < chartData.count {
            selectedDataPoint = chartData[dataIndex]
            showTooltip = true
        }
    }
    
    /// 生成基於真實數據的圖表數據
    private func generateRealChartData() -> [TournamentPerformanceDataPoint] {
        let historyManager = TournamentPerformanceHistoryManager.shared
        
        // 獲取當前用戶ID（需要從 portfolio 或其他地方獲取）
        guard let userId = getCurrentUserId() else {
            return generateFallbackData()
        }
        
        // 從歷史管理器獲取真實數據
        let realData = historyManager.generateChartData(
            for: portfolio.tournamentId,
            userId: userId,
            timeRange: timeRange,
            metric: mapToHistoryMetric(metric)
        )
        
        // 如果沒有歷史數據，生成基於當前投資組合狀態的數據點
        if realData.isEmpty {
            return generateCurrentPortfolioData()
        }
        
        return realData
    }
    
    /// 獲取當前用戶ID的輔助方法
    private func getCurrentUserId() -> UUID? {
        // 從 Supabase 服務獲取當前用戶ID
        return SupabaseService.shared.getCurrentUser()?.id
    }
    
    /// 映射績效指標類型
    private func mapToHistoryMetric(_ metric: TournamentPerformanceView.PerformanceMetric) -> TournamentPerformanceMetric {
        switch metric {
        case .portfolio:
            return .portfolio
        case .returns:
            return .returns
        case .dailyChange:
            return .dailyChange
        case .trades:
            return .trades
        }
    }
    
    /// 生成基於當前投資組合狀態的數據點
    private func generateCurrentPortfolioData() -> [TournamentPerformanceDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = getStartDate(for: timeRange, from: endDate, using: calendar)
        
        // 至少生成一個當前狀態的數據點
        let currentValue = getCurrentValue(for: metric)
        let currentChange = getCurrentChange(for: metric)
        
        var data: [TournamentPerformanceDataPoint] = []
        
        // 如果沒有歷史數據，創建一個基準線和當前點
        let initialValue = getInitialValue(for: metric)
        
        // 添加起始點（基於初始投資金額）
        data.append(TournamentPerformanceDataPoint(
            date: startDate,
            value: initialValue,
            change: 0.0
        ))
        
        // 添加當前點
        data.append(TournamentPerformanceDataPoint(
            date: endDate,
            value: currentValue,
            change: currentChange
        ))
        
        return data
    }
    
    /// 獲取後備數據（最小化的數據集）
    private func generateFallbackData() -> [TournamentPerformanceDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = getStartDate(for: timeRange, from: endDate, using: calendar)
        
        let currentValue = getCurrentValue(for: metric)
        let initialValue = getInitialValue(for: metric)
        
        return [
            TournamentPerformanceDataPoint(date: startDate, value: initialValue, change: 0.0),
            TournamentPerformanceDataPoint(date: endDate, value: currentValue, change: getCurrentChange(for: metric))
        ]
    }
    
    /// 獲取指定時間範圍的開始日期
    private func getStartDate(for timeRange: PerformanceTimeRange, from endDate: Date, using calendar: Calendar) -> Date {
        switch timeRange {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            return calendar.date(byAdding: .year, value: -2, to: endDate) ?? endDate
        }
    }
    
    /// 獲取當前指標值
    private func getCurrentValue(for metric: TournamentPerformanceView.PerformanceMetric) -> Double {
        switch metric {
        case .portfolio:
            return portfolio.totalPortfolioValue
        case .returns:
            return portfolio.totalReturnPercentage
        case .dailyChange:
            // 從績效指標獲取今日收益，而不是隨機數
            return portfolio.performanceMetrics.dailyReturn
        case .trades:
            return Double(portfolio.tradingRecords.count)
        }
    }
    
    /// 獲取當前變化值
    private func getCurrentChange(for metric: TournamentPerformanceView.PerformanceMetric) -> Double? {
        switch metric {
        case .portfolio:
            return portfolio.totalReturnPercentage
        case .returns:
            return portfolio.performanceMetrics.dailyReturn
        case .dailyChange:
            return nil // 每日變化本身就是變化
        case .trades:
            // 可以返回今日交易次數
            let today = Calendar.current.startOfDay(for: Date())
            let todayTrades = portfolio.tradingRecords.filter { record in
                Calendar.current.isDate(record.timestamp, inSameDayAs: today)
            }.count
            return Double(todayTrades)
        }
    }
    
    /// 獲取初始值（基準線）
    private func getInitialValue(for metric: TournamentPerformanceView.PerformanceMetric) -> Double {
        switch metric {
        case .portfolio:
            return portfolio.initialBalance
        case .returns:
            return 0.0 // 初始收益率為0
        case .dailyChange:
            return 0.0 // 初始每日變化為0
        case .trades:
            return 0.0 // 初始交易次數為0
        }
    }
    
    private func formatValue(_ value: Double, for metric: TournamentPerformanceView.PerformanceMetric) -> String {
        switch metric {
        case .portfolio:
            return formatCurrency(value)
        case .returns, .dailyChange:
            return String(format: "%.2f%%", value)
        case .trades:
            return String(format: "%.0f", value)
        }
    }
    
    private func getValueColor(_ value: Double, for metric: TournamentPerformanceView.PerformanceMetric) -> Color {
        switch metric {
        case .portfolio:
            return value >= portfolio.initialBalance ? .taiwanStockUp : .taiwanStockDown
        case .returns, .dailyChange:
            return value >= 0 ? .taiwanStockUp : .taiwanStockDown
        case .trades:
            return metric.color
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "NT$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - 深色模式支援方法
    
    /// 獲取適應深色模式的動態顏色
    private func getDynamicColor(for metric: TournamentPerformanceView.PerformanceMetric) -> Color {
        switch metric {
        case .portfolio:
            return Color.blue
        case .returns:
            return getDynamicGreen()
        case .dailyChange:
            return Color.orange
        case .trades:
            return Color.purple
        }
    }
    
    /// 獲取深色模式適應的綠色
    private func getDynamicGreen() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGreen
                : UIColor.systemGreen
        })
    }
    
    /// 獲取深色模式適應的紅色
    private func getDynamicRed() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemRed
                : UIColor.systemRed
        })
    }
    
    /// 獲取圖表背景顏色
    private func getChartBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.black.withAlphaComponent(0.1)
                : UIColor.clear
        })
    }
    
    /// 獲取工具提示背景顏色
    private func getTooltipBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemBackground
                : UIColor.systemBackground
        })
    }
    
    /// 獲取陰影顏色
    private func getShadowColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.white.withAlphaComponent(0.1)
                : UIColor.black.withAlphaComponent(0.2)
        })
    }
}

// MARK: - 錦標賽績效數據點
struct TournamentPerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let change: Double?
    
    init(date: Date, value: Double, change: Double? = nil) {
        self.date = date
        self.value = value
        self.change = change
    }
}

// MARK: - 預覽
#Preview {
    TournamentPerformanceChart(
        portfolio: TournamentPortfolio(
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
            dailyReturn: -1.2,
            sharpeRatio: 0.8,
            lastUpdated: Date(),
            dailyValueHistory: []
        ),
        timeRange: .week,
        metric: .portfolio
    )
    .frame(height: 200)
    .padding()
}