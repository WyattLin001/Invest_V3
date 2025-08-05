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
        generateChartData()
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
                .foregroundStyle(metric.color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [metric.color.opacity(0.3), metric.color.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
            case .dailyChange:
                BarMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(dataPoint.value >= 0 ? Color.green : Color.red)
                
            case .trades:
                LineMark(
                    x: .value("日期", dataPoint.date),
                    y: .value(metric.rawValue, dataPoint.value)
                )
                .foregroundStyle(metric.color)
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
                    .fill(Color.clear)
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
                        .foregroundColor(change >= 0 ? .green : .red)
                    
                    Text(String(format: "%+.2f%%", change))
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .green : .red)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
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
    
    private func generateChartData() -> [TournamentPerformanceDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date
        
        switch timeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            startDate = calendar.date(byAdding: .year, value: -2, to: endDate) ?? endDate
        }
        
        var data: [TournamentPerformanceDataPoint] = []
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 7
        
        for i in 0...dayCount {
            let date = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate
            
            let value: Double
            let change: Double?
            
            switch metric {
            case .portfolio:
                value = portfolio.totalPortfolioValue
                change = portfolio.totalReturnPercentage
                
            case .returns:
                value = portfolio.totalReturnPercentage
                change = nil
                
            case .dailyChange:
                // 模擬每日變化數據
                value = Double.random(in: -3.0...3.0)
                change = nil
                
            case .trades:
                value = Double(portfolio.tradingRecords.count)
                change = nil
            }
            
            data.append(TournamentPerformanceDataPoint(
                date: date,
                value: value,
                change: change
            ))
        }
        
        return data
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
            return value >= portfolio.initialBalance ? .green : .red
        case .returns, .dailyChange:
            return value >= 0 ? .green : .red
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
            userName: "TestUser",
            holdings: [],
            initialBalance: 1000000,
            currentBalance: 950000,
            totalInvested: 50000,
            tradingRecords: [],
            performanceMetrics: TournamentPerformanceMetrics(
                totalReturn: -50000,
                totalReturnPercentage: -5.0,
                dailyReturn: -0.2,
                maxDrawdown: 10000,
                maxDrawdownPercentage: 1.0,
                sharpeRatio: 0.8,
                winRate: 0.6,
                totalTrades: 10,
                profitableTrades: 6,
                averageHoldingDays: 3.5,
                riskScore: 75.0,
                diversificationScore: 60.0,
                currentRank: 15,
                previousRank: 20,
                percentile: 25.0,
                lastUpdated: Date()
            ),
            lastUpdated: Date()
        ),
        timeRange: .week,
        metric: .portfolio
    )
    .frame(height: 200)
    .padding()
}