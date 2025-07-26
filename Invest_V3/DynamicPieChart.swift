import SwiftUI

// MARK: - 動態圓餅圖資料模型
struct PieChartData: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let color: Color
    
    var percentage: Double {
        return value
    }
}

// MARK: - 動態圓餅圖元件
struct DynamicPieChart: View {
    let data: [PieChartData]
    let size: CGFloat
    @State private var selectedSegment: PieChartData?
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 圓餅圖
            ZStack {
                pieChartView
                
                // 中心顯示選中項目或總計
                VStack {
                    if let selected = selectedSegment {
                        Text(selected.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", selected.percentage))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(selected.color)
                    } else {
                        Text("總資產")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("100%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(width: size, height: size)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSegment = nil
                }
            }
            
            // 圖例
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(data) { item in
                    DynamicLegendItem(
                        data: item,
                        isSelected: selectedSegment?.id == item.id
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedSegment = selectedSegment?.id == item.id ? nil : item
                        }
                    }
                }
            }
        }
    }
    
    private var pieChartView: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 10
            
            var startAngle: Double = -90 // 從12點鐘位置開始
            
            for item in data {
                let angle = (item.percentage / 100) * 360
                let endAngle = startAngle + angle
                
                let path = Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                
                // 判斷是否為選中項目
                let isSelected = selectedSegment?.id == item.id
                let fillColor = isSelected ? item.color.opacity(0.8) : item.color
                
                context.fill(path, with: .color(fillColor))
                
                // 添加較粗的背景顏色邊框以突出分段（深色模式適配）
                context.stroke(path, with: .color(Color.systemBackground), lineWidth: 4)
                
                startAngle = endAngle
                
            }
            
            // 如果只有一個項目且不是100%，添加剩餘部分
            if data.count == 1 && data.first?.percentage != 100 {
                let remainingPercentage = 100 - (data.first?.percentage ?? 0)
                let remainingAngle = (remainingPercentage / 100) * 360
                let remainingEndAngle = startAngle + remainingAngle
                
                let remainingPath = Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(remainingEndAngle),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                
                context.fill(remainingPath, with: .color(Color(.systemGray5)))
                context.stroke(remainingPath, with: .color(Color.systemBackground), lineWidth: 4)
            }
        }
    }
}

// MARK: - 動態圖例項目
struct DynamicLegendItem: View {
    let data: PieChartData
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(data.color)
                .frame(width: 12, height: 12)
                .scaleEffect(isSelected ? 1.2 : 1.0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(data.category)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(String(format: "%.1f%%", data.percentage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.brandGreen.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.brandGreen.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - 資產分配計算器
struct AssetAllocationCalculator {
    static func calculateAllocation(from portfolio: TradingPortfolio?) -> [PieChartData] {
        guard let portfolio = portfolio else {
            return [PieChartData(category: "現金", value: 100, color: StockColorPalette.cashColor)]
        }
        
        var allocations: [PieChartData] = []
        let totalValue = portfolio.totalAssets
        
        // 添加個別股票
        for position in portfolio.positions {
            let percentage = (position.marketValue / totalValue) * 100
            let stockColor = StockColorPalette.colorForStock(symbol: position.symbol)
            
            allocations.append(PieChartData(
                category: position.name,
                value: percentage,
                color: stockColor
            ))
            
        }
        
        // 現金比例
        let cashPercentage = (portfolio.cashBalance / totalValue) * 100
        if cashPercentage > 0 {
            allocations.append(PieChartData(
                category: "現金",
                value: cashPercentage,
                color: StockColorPalette.cashColor
            ))
        }
        
        // 按價值大小排序
        return allocations.sorted { $0.value > $1.value }
    }
    
}

// MARK: - 股票顏色調色盤 (重構為混合動態系統)
struct StockColorPalette {
    
    /// 混合顏色提供者（單例）
    private static let colorProvider = HybridColorProvider.shared
    
    /// 現金顏色（向後兼容）
    static let cashColor = HybridColorProvider.shared.colorForCash()
    
    /// 為股票獲取顏色
    /// - Parameter symbol: 股票代號
    /// - Returns: 對應的顏色
    static func colorForStock(symbol: String) -> Color {
        return colorProvider.colorForStock(symbol: symbol)
    }
    
    /// 獲取所有股票的顏色列表
    static var allStockColors: [(symbol: String, color: Color)] {
        return colorProvider.getAllColors()
    }
    
    /// 清除動態生成的顏色緩存（調試用）
    static func clearDynamicColors() {
        colorProvider.clearDynamicColors()
    }
}

#Preview {
    let sampleData = [
        PieChartData(category: "台灣50", value: 90.9, color: StockColorPalette.colorForStock(symbol: "0050")),
        PieChartData(category: "台積電", value: 9.1, color: StockColorPalette.colorForStock(symbol: "2330"))
    ]
    
    return VStack(spacing: 20) {
        Text("投資組合預覽")
            .font(.headline)
        
        DynamicPieChart(data: sampleData, size: 180)
        
        // 顯示顏色對應
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(StockColorPalette.colorForStock(symbol: "0050")).frame(width: 12, height: 12)
                Text("0050 台灣50 - 藍色")
                    .font(.caption)
            }
            HStack {
                Circle().fill(StockColorPalette.colorForStock(symbol: "2330")).frame(width: 12, height: 12)
                Text("2330 台積電 - 紅色")
                    .font(.caption)
            }
        }
    }
    .padding()
}