import SwiftUI

// MARK: - 績效數據模型
struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let portfolioValue: Double
    let dailyChange: Double
    let cumulativeReturn: Double
    let returnPercentage: Double
    
    init(date: Date, value: Double, portfolioValue: Double? = nil, dailyChange: Double = 0, cumulativeReturn: Double = 0, returnPercentage: Double = 0) {
        self.date = date
        self.value = value
        self.portfolioValue = portfolioValue ?? value
        self.dailyChange = dailyChange
        self.cumulativeReturn = cumulativeReturn
        self.returnPercentage = returnPercentage
    }
}

// MARK: - 績效圖表時間範圍
enum PerformanceTimeRange: String, CaseIterable {
    case week = "1週"
    case month = "1月"
    case quarter = "3月"
    case year = "1年"
    case all = "全部"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .all: return 1000
        }
    }
}

// MARK: - 績效圖表元件
struct PerformanceChart: View {
    let data: [PerformanceDataPoint]
    let timeRange: PerformanceTimeRange
    let width: CGFloat
    let height: CGFloat
    
    @State private var selectedPoint: PerformanceDataPoint?
    @State private var showTooltip = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 圖表標題和當前值
            chartHeader
            
            // 圖表區域
            chartView
                .frame(width: width, height: height)
                .background(getChartBackgroundColor())
                .cornerRadius(12)
                .overlay(
                    tooltipView,
                    alignment: .topLeading
                )
        }
    }
    
    // MARK: - 圖表標題
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("投資組合價值")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if let selectedPoint = selectedPoint {
                    Text(TradingService.shared.formatCurrency(selectedPoint.portfolioValue))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(selectedPoint.dailyChange >= 0 ? .green : .red)
                } else if let lastPoint = data.last {
                    Text(TradingService.shared.formatCurrency(lastPoint.portfolioValue))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(lastPoint.cumulativeReturn >= 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("累計報酬")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let selectedPoint = selectedPoint {
                    Text(String(format: "%+.2f%%", selectedPoint.cumulativeReturn))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedPoint.cumulativeReturn >= 0 ? .green : .red)
                } else if let lastPoint = data.last {
                    Text(String(format: "%+.2f%%", lastPoint.cumulativeReturn))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(lastPoint.cumulativeReturn >= 0 ? .green : .red)
                }
            }
        }
    }
    
    // MARK: - 圖表視圖
    private var chartView: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            
            let minValue = data.map { $0.portfolioValue }.min() ?? 0
            let maxValue = data.map { $0.portfolioValue }.max() ?? 0
            let valueRange = maxValue - minValue
            
            // 確保有足夠的範圍顯示
            let adjustedMinValue = valueRange > 0 ? minValue - valueRange * 0.1 : minValue - 1000
            let adjustedMaxValue = valueRange > 0 ? maxValue + valueRange * 0.1 : maxValue + 1000
            let adjustedRange = adjustedMaxValue - adjustedMinValue
            
            let stepX = size.width / CGFloat(data.count - 1)
            
            // 繪製基準線（初始投資金額）
            let initialValue = 1000000.0 // 初始100萬
            let baselineY = size.height - ((initialValue - adjustedMinValue) / adjustedRange) * size.height
            
            if baselineY >= 0 && baselineY <= size.height {
                let baselinePath = Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: size.width, y: baselineY))
                }
                context.stroke(baselinePath, with: .color(getDynamicBaselineColor()), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            
            // 繪製面積圖
            let areaPath = Path { path in
                var points: [CGPoint] = []
                
                for (index, point) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = size.height - ((point.portfolioValue - adjustedMinValue) / adjustedRange) * size.height
                    points.append(CGPoint(x: x, y: y))
                }
                
                // 創建面積路徑
                if let firstPoint = points.first {
                    path.move(to: CGPoint(x: firstPoint.x, y: size.height))
                    path.addLine(to: firstPoint)
                    
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    
                    if let lastPoint = points.last {
                        path.addLine(to: CGPoint(x: lastPoint.x, y: size.height))
                    }
                    path.closeSubpath()
                }
            }
            
            // 判斷整體趨勢顏色
            let overallTrend = data.last?.cumulativeReturn ?? 0
            let trendColor = overallTrend >= 0 ? getDynamicGreen() : getDynamicRed()
            
            // 填充面積
            context.fill(areaPath, with: .color(trendColor.opacity(0.2)))
            
            // 繪製折線
            let linePath = Path { path in
                for (index, point) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = size.height - ((point.portfolioValue - adjustedMinValue) / adjustedRange) * size.height
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            
            context.stroke(linePath, with: .color(trendColor), style: StrokeStyle(lineWidth: 2))
            
            // 繪製數據點
            for (index, point) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - ((point.portfolioValue - adjustedMinValue) / adjustedRange) * size.height
                
                let pointSize: CGFloat = selectedPoint?.id == point.id ? 6 : 3
                let pointColor = selectedPoint?.id == point.id ? trendColor : trendColor.opacity(0.8)
                
                let circle = Path { path in
                    path.addEllipse(in: CGRect(x: x - pointSize/2, y: y - pointSize/2, width: pointSize, height: pointSize))
                }
                
                context.fill(circle, with: .color(pointColor))
                context.stroke(circle, with: .color(getStrokeColor()), style: StrokeStyle(lineWidth: 1))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    selectPoint(at: value.location)
                }
                .onEnded { _ in
                    selectedPoint = nil
                    showTooltip = false
                }
        )
        .onTapGesture { location in
            selectPoint(at: location)
        }
    }
    
    // MARK: - 工具提示
    private var tooltipView: some View {
        Group {
            if let selectedPoint = selectedPoint, showTooltip {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate(selectedPoint.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(selectedPoint.portfolioValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(String(format: "%+.2f%%", selectedPoint.dailyChange))
                        .font(.caption)
                        .foregroundColor(selectedPoint.dailyChange >= 0 ? .green : .red)
                }
                .padding(8)
                .background(getTooltipBackgroundColor())
                .cornerRadius(8)
                .shadow(color: getShadowColor(), radius: 4)
                .opacity(showTooltip ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showTooltip)
            }
        }
    }
    
    // MARK: - 私有方法
    private func selectPoint(at location: CGPoint) {
        guard !data.isEmpty else { return }
        
        let stepX = width / CGFloat(data.count - 1)
        let index = Int(round(location.x / stepX))
        
        if index >= 0 && index < data.count {
            selectedPoint = data[index]
            showTooltip = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - 深色模式支援方法
    
    /// 獲取適應深色模式的綠色
    private func getDynamicGreen() -> Color {
        return Color.green
    }
    
    /// 獲取深色模式適應的紅色
    private func getDynamicRed() -> Color {
        return Color.red
    }
    
    /// 獲取基準線顏色
    private func getDynamicBaselineColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGray3
                : UIColor.systemGray
        })
    }
    
    /// 獲取圖表背景顏色
    private func getChartBackgroundColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemGray6.withAlphaComponent(0.2)
                : UIColor.systemGray6.withAlphaComponent(0.3)
        })
    }
    
    /// 獲取描邊顏色
    private func getStrokeColor() -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor.systemBackground
                : UIColor.white
        })
    }
    
    /// 獲取工具提示背景顏色
    private func getTooltipBackgroundColor() -> Color {
        return Color.primary.colorInvert().opacity(0.95)
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

// MARK: - 績效數據生成器（基於真實數據）
struct PerformanceDataGenerator {
    static func generateData(for range: PerformanceTimeRange, portfolio: TradingPortfolio?) -> [PerformanceDataPoint] {
        let initialValue = portfolio?.initialBalance ?? 1000000.0
        let currentValue = portfolio?.totalAssets ?? initialValue
        let endDate = Date()
        let startDate = getStartDate(for: range, from: endDate)
        
        // 優先使用真實投資組合歷史數據
        if let portfolio = portfolio {
            return generateRealPortfolioData(
                portfolio: portfolio,
                startDate: startDate,
                endDate: endDate,
                timeRange: range
            )
        }
        
        // 如果沒有真實數據，生成基本的兩點線
        return generateMinimalData(
            initialValue: initialValue,
            currentValue: currentValue,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    /// 基於真實投資組合生成數據
    private static func generateRealPortfolioData(
        portfolio: TradingPortfolio,
        startDate: Date,
        endDate: Date,
        timeRange: PerformanceTimeRange
    ) -> [PerformanceDataPoint] {
        var data: [PerformanceDataPoint] = []
        let initialValue = portfolio.initialBalance
        
        // 基於交易記錄生成歷史數據點
        let trades = portfolio.holdings.flatMap { holding in
            // 這裡應該從真實的交易記錄中獲取數據
            // 暫時使用當前持股信息作為數據來源
            return [holding] // 簡化處理
        }
        
        // 添加起始點
        data.append(PerformanceDataPoint(
            date: startDate,
            value: initialValue,
            portfolioValue: initialValue,
            dailyChange: 0.0,
            cumulativeReturn: 0.0
        ))
        
        // 如果有交易數據，可以在此處添加中間點
        // TODO: 實現基於真實交易記錄的歷史重建
        
        // 添加當前點
        let cumulativeReturn = ((portfolio.totalAssets - initialValue) / initialValue) * 100
        data.append(PerformanceDataPoint(
            date: endDate,
            value: portfolio.totalAssets,
            portfolioValue: portfolio.totalAssets,
            dailyChange: portfolio.todayPnlPercentage,
            cumulativeReturn: cumulativeReturn
        ))
        
        return data
    }
    
    /// 生成最小數據集（起點和終點）
    private static func generateMinimalData(
        initialValue: Double,
        currentValue: Double,
        startDate: Date,
        endDate: Date
    ) -> [PerformanceDataPoint] {
        let cumulativeReturn = initialValue > 0 ? ((currentValue - initialValue) / initialValue) * 100 : 0
        
        return [
            PerformanceDataPoint(
                date: startDate,
                value: initialValue,
                portfolioValue: initialValue,
                dailyChange: 0.0,
                cumulativeReturn: 0.0
            ),
            PerformanceDataPoint(
                date: endDate,
                value: currentValue,
                portfolioValue: currentValue,
                dailyChange: 0.0, // 沒有昨日數據時為0
                cumulativeReturn: cumulativeReturn
            )
        ]
    }
    
    /// 獲取時間範圍的開始日期
    private static func getStartDate(for range: PerformanceTimeRange, from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch range {
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
}

#Preview {
    let sampleData = PerformanceDataGenerator.generateData(for: .month, portfolio: nil)
    return PerformanceChart(
        data: sampleData,
        timeRange: .month,
        width: 300,
        height: 150
    )
    .padding()
}