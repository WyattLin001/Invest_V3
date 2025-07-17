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
                
                // 添加邊框
                context.stroke(path, with: .color(Color(.systemBackground)), lineWidth: 2)
                
                startAngle = endAngle
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
            return [PieChartData(category: "現金", value: 100, color: Color.brandGreen)]
        }
        
        var allocations: [PieChartData] = []
        let totalValue = portfolio.totalAssets
        
        // 現金比例
        let cashPercentage = (portfolio.cashBalance / totalValue) * 100
        if cashPercentage > 0 {
            allocations.append(PieChartData(
                category: "現金",
                value: cashPercentage,
                color: Color.brandGreen
            ))
        }
        
        // 股票分類
        var stockCategories: [String: Double] = [:]
        var categoryColors: [String: Color] = [
            "科技股": .blue,
            "金融股": .orange,
            "傳統產業": .purple,
            "生技醫療": .pink,
            "其他": .gray
        ]
        
        for position in portfolio.positions {
            let category = categorizeStock(position.symbol)
            let percentage = (position.marketValue / totalValue) * 100
            stockCategories[category, default: 0] += percentage
        }
        
        // 轉換為 PieChartData
        for (category, percentage) in stockCategories.sorted(by: { $0.value > $1.value }) {
            if percentage > 0 {
                allocations.append(PieChartData(
                    category: category,
                    value: percentage,
                    color: categoryColors[category] ?? .gray
                ))
            }
        }
        
        return allocations
    }
    
    private static func categorizeStock(_ symbol: String) -> String {
        // 根據股票代碼分類（簡化版本）
        switch symbol.prefix(2) {
        case "23", "24", "25", "26": // 科技股相關代碼
            return "科技股"
        case "28", "29": // 金融股相關代碼
            return "金融股"
        case "41", "42": // 生技醫療相關代碼
            return "生技醫療"
        default:
            if symbol.hasPrefix("AA") || symbol.hasPrefix("GO") || symbol.hasPrefix("NV") {
                return "科技股"
            } else if symbol.hasPrefix("MS") || symbol.hasPrefix("JP") {
                return "金融股"
            } else {
                return "其他"
            }
        }
    }
}

#Preview {
    let sampleData = [
        PieChartData(category: "現金", value: 45.5, color: Color.brandGreen),
        PieChartData(category: "科技股", value: 30.2, color: .blue),
        PieChartData(category: "金融股", value: 15.8, color: .orange),
        PieChartData(category: "其他", value: 8.5, color: .purple)
    ]
    
    return DynamicPieChart(data: sampleData, size: 180)
        .padding()
}