import SwiftUI

// MARK: - 績效數據模型
struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let portfolioValue: Double
    let dailyChange: Double
    let cumulativeReturn: Double
}

// MARK: - 績效圖表時間範圍
enum PerformanceTimeRange: String, CaseIterable {
    case week = "1週"
    case month = "1月"
    case quarter = "3月"
    case year = "1年"
    case all = "全部"
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
                .background(Color(.systemGray6).opacity(0.3))
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
                context.stroke(baselinePath, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
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
            let trendColor = overallTrend >= 0 ? Color.green : Color.red
            
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
                context.stroke(circle, with: .color(.white), style: StrokeStyle(lineWidth: 1))
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
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 4)
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
}

// MARK: - 績效數據生成器
struct PerformanceDataGenerator {
    static func generateData(for range: PerformanceTimeRange, portfolio: TradingPortfolio?) -> [PerformanceDataPoint] {
        let initialValue = 1000000.0 // 初始100萬
        let endDate = Date()
        let startDate: Date
        let dataPoints: Int
        
        switch range {
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            dataPoints = 7
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
            dataPoints = 30
        case .quarter:
            startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate
            dataPoints = 90
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
            dataPoints = 365
        case .all:
            startDate = Calendar.current.date(byAdding: .year, value: -2, to: endDate) ?? endDate
            dataPoints = 730
        }
        
        var data: [PerformanceDataPoint] = []
        let timeInterval = endDate.timeIntervalSince(startDate) / Double(dataPoints - 1)
        
        var currentValue = initialValue
        var previousValue = initialValue
        
        for i in 0..<dataPoints {
            let date = startDate.addingTimeInterval(TimeInterval(i) * timeInterval)
            
            // 模擬價格波動（基於隨機遊走）
            let randomChange = Double.random(in: -0.02...0.025) // -2% 到 +2.5%
            let marketTrend = 0.0002 // 輕微上漲趨勢
            let totalChange = randomChange + marketTrend
            
            currentValue *= (1 + totalChange)
            
            let dailyChange = ((currentValue - previousValue) / previousValue) * 100
            let cumulativeReturn = ((currentValue - initialValue) / initialValue) * 100
            
            data.append(PerformanceDataPoint(
                date: date,
                value: currentValue,
                portfolioValue: currentValue,
                dailyChange: dailyChange,
                cumulativeReturn: cumulativeReturn
            ))
            
            previousValue = currentValue
        }
        
        // 如果有真實投資組合數據，調整最後一個點
        if let portfolio = portfolio {
            if var lastPoint = data.last {
                data[data.count - 1] = PerformanceDataPoint(
                    date: lastPoint.date,
                    value: portfolio.totalAssets,
                    portfolioValue: portfolio.totalAssets,
                    dailyChange: lastPoint.dailyChange,
                    cumulativeReturn: ((portfolio.totalAssets - initialValue) / initialValue) * 100
                )
            }
        }
        
        return data
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