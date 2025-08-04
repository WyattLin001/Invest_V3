import SwiftUI

// MARK: - 動態圓餅圖資料模型
struct PieChartData: Identifiable, Equatable {
    let id = UUID()
    let category: String
    let value: Double
    let color: Color
    
    // 新增詳細資訊屬性
    let holdingQuantity: Double?
    let purchasePrice: Double?
    let currentValue: Double?
    let currentPrice: Double?
    let unrealizedGainLoss: Double?
    let symbol: String?
    
    var percentage: Double {
        return value
    }
    
    // 便利初始化器 - 保持向後兼容
    init(category: String, value: Double, color: Color) {
        self.category = category
        self.value = value
        self.color = color
        self.holdingQuantity = nil
        self.purchasePrice = nil
        self.currentValue = nil
        self.currentPrice = nil
        self.unrealizedGainLoss = nil
        self.symbol = nil
    }
    
    // 完整初始化器 - 包含詳細資訊
    init(category: String, value: Double, color: Color, 
         holdingQuantity: Double?, purchasePrice: Double?, 
         currentValue: Double?, currentPrice: Double?, 
         unrealizedGainLoss: Double?, symbol: String?) {
        self.category = category
        self.value = value
        self.color = color
        self.holdingQuantity = holdingQuantity
        self.purchasePrice = purchasePrice
        self.currentValue = currentValue
        self.currentPrice = currentPrice
        self.unrealizedGainLoss = unrealizedGainLoss
        self.symbol = symbol
    }
    
    // Equatable 實現
    static func == (lhs: PieChartData, rhs: PieChartData) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 動態圓餅圖元件
struct DynamicPieChart: View {
    let data: [PieChartData]
    let size: CGFloat
    @State private var selectedSegment: PieChartData?
    @State private var showDetails = false
    @State private var showDetailPopup = false
    @State private var detailPopupPosition: CGPoint = .zero
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // 圓餅圖容器
                ZStack {
                    pieChartView
                    
                    // 中心顯示選中項目或總計
                    VStack(spacing: 4) {
                        if let selected = selectedSegment {
                            Text(selected.symbol ?? selected.category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text(String(format: "%.1f%%", selected.percentage))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(selected.color)
                            
                            // 顯示當前價值
                            if let currentValue = selected.currentValue {
                                Text("$\(String(format: "%.0f", currentValue))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
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
                    .scaleEffect(selectedSegment != nil ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSegment)
                }
                .frame(width: size, height: size)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedSegment = nil
                        showDetailPopup = false
                    }
                }
                
                // 互動式圖例
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(data) { item in
                        EnhancedLegendItem(
                            data: item,
                            isSelected: selectedSegment?.id == item.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if selectedSegment?.id == item.id {
                                    selectedSegment = nil
                                    showDetailPopup = false
                                } else {
                                    selectedSegment = item
                                    // 延遲顯示詳情彈窗
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        if item.holdingQuantity != nil || item.currentValue != nil {
                                            showDetailPopup = true
                                        }
                                    }
                                }
                            }
                        }
                        .onLongPressGesture {
                            // 長按顯示詳細資訊
                            selectedSegment = item
                            showDetailPopup = true
                        }
                    }
                }
            }
            
            // 詳情彈窗
            if showDetailPopup, let selected = selectedSegment {
                DetailPopupView(data: selected)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showDetailPopup)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showDetailPopup = false
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
                
                // 判斷是否為選中項目並增強視覺效果
                let isSelected = selectedSegment?.id == item.id
                let fillColor = isSelected ? item.color.opacity(0.9) : item.color.opacity(0.8)
                
                // 選中時的外擴效果
                if isSelected {
                    let expandedRadius = radius + 8
                    let expandedPath = Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: expandedRadius,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    context.fill(expandedPath, with: .color(fillColor))
                    context.stroke(expandedPath, with: .color(Color.systemBackground), lineWidth: 3)
                } else {
                    context.fill(path, with: .color(fillColor))
                    context.stroke(path, with: .color(Color.systemBackground), lineWidth: 2)
                }
                
                // 添加內側高亮線條增強層次感
                if isSelected {
                    let innerRadius = radius * 0.3
                    let highlightPath = Path { path in
                        path.addArc(
                            center: center,
                            radius: innerRadius,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                    }
                    context.stroke(highlightPath, with: .color(item.color.opacity(0.6)), lineWidth: 2)
                }
                
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

// MARK: - 動態圖例項目 (保留向後兼容)
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

// MARK: - 增強圖例項目
struct EnhancedLegendItem: View {
    let data: PieChartData
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // 顏色指示器 - 增強動畫效果
            Circle()
                .fill(data.color)
                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                .overlay(
                    Circle()
                        .stroke(data.color.opacity(0.3), lineWidth: isSelected ? 2 : 0)
                        .scaleEffect(isSelected ? 1.3 : 1.0)
                        .opacity(isSelected ? 0.6 : 0)
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(data.symbol ?? "")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let category = data.category.split(separator: " ").dropFirst().joined(separator: " "), !category.isEmpty {
                        Text(category)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(String(format: "%.1f%%", data.percentage))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(data.color)
                    
                    if let currentValue = data.currentValue {
                        Text("$\(String(format: "%.0f", currentValue))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 盈虧指示器
                if let gainLoss = data.unrealizedGainLoss, gainLoss != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: gainLoss >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                            .foregroundColor(gainLoss >= 0 ? DesignTokens.priceUpColor : DesignTokens.priceDownColor)
                        
                        Text(String(format: "%+.0f", gainLoss))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(gainLoss >= 0 ? DesignTokens.priceUpColor : DesignTokens.priceDownColor)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? data.color.opacity(0.1) : Color.surfaceSecondary)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? data.color.opacity(0.4) : Color.clear,
                    lineWidth: isSelected ? 1.5 : 0
                )
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - 詳情彈窗視圖
struct DetailPopupView: View {
    let data: PieChartData
    
    var body: some View {
        VStack(spacing: 16) {
            // 標題
            HStack {
                Circle()
                    .fill(data.color)
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.symbol ?? data.category)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let symbol = data.symbol, let category = data.category.split(separator: " ").dropFirst().joined(separator: " "), !category.isEmpty {
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(String(format: "%.1f%%", data.percentage))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(data.color)
            }
            
            Divider()
            
            // 詳細資訊
            VStack(spacing: 12) {
                if let holdingQuantity = data.holdingQuantity {
                    DetailRow(
                        icon: "chart.bar.fill",
                        title: "持股數量",
                        value: String(format: "%.2f 股", holdingQuantity),
                        color: .primary
                    )
                }
                
                if let purchasePrice = data.purchasePrice {
                    DetailRow(
                        icon: "dollarsign.circle",
                        title: "平均買入價",
                        value: String(format: "$%.2f", purchasePrice),
                        color: .secondary
                    )
                }
                
                if let currentPrice = data.currentPrice {
                    DetailRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "當前價格",
                        value: String(format: "$%.2f", currentPrice),
                        color: .primary
                    )
                }
                
                if let currentValue = data.currentValue {
                    DetailRow(
                        icon: "banknote",
                        title: "當前價值",
                        value: String(format: "$%.0f", currentValue),
                        color: .primary
                    )
                }
                
                if let gainLoss = data.unrealizedGainLoss, gainLoss != 0 {
                    let isProfit = gainLoss >= 0
                    DetailRow(
                        icon: isProfit ? "arrowtriangle.up.circle.fill" : "arrowtriangle.down.circle.fill",
                        title: "未實現損益",
                        value: String(format: "%+.0f", gainLoss),
                        color: isProfit ? DesignTokens.priceUpColor : DesignTokens.priceDownColor
                    )
                    
                    // 計算損益百分比
                    if let purchasePrice = data.purchasePrice, let holdingQuantity = data.holdingQuantity {
                        let totalCost = purchasePrice * holdingQuantity
                        let gainLossPercent = (gainLoss / totalCost) * 100
                        DetailRow(
                            icon: isProfit ? "percent" : "percent",
                            title: "報酬率",
                            value: String(format: "%+.2f%%", gainLossPercent),
                            color: isProfit ? DesignTokens.priceUpColor : DesignTokens.priceDownColor
                        )
                    }
                }
            }
            
            // 關閉提示
            HStack {
                Spacer()
                Text("點擊任意處關閉")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surfacePrimary)
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(data.color.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: 300)
    }
}

// MARK: - 詳情行組件
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
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
    
    /// 從 ChatPortfolioManager 計算增強的資產分配 (包含詳細資訊)
    static func calculateEnhancedAllocation(from portfolioManager: ChatPortfolioManager) -> [PieChartData] {
        let holdings = portfolioManager.holdings
        guard !holdings.isEmpty else {
            return [PieChartData(
                category: "無投資", 
                value: 100, 
                color: .gray,
                holdingQuantity: nil,
                purchasePrice: nil,
                currentValue: nil,
                currentPrice: nil,
                unrealizedGainLoss: nil,
                symbol: nil
            )]
        }
        
        let totalValue = portfolioManager.totalPortfolioValue
        
        return holdings.map { holding in
            let percentage = (holding.totalValue / totalValue) * 100
            let stockColor = StockColorPalette.colorForStock(symbol: holding.symbol)
            
            return PieChartData(
                category: "\(holding.symbol) \(holding.name)",
                value: percentage,
                color: stockColor,
                holdingQuantity: holding.shares,
                purchasePrice: holding.averagePrice,
                currentValue: holding.totalValue,
                currentPrice: holding.currentPrice,
                unrealizedGainLoss: holding.unrealizedGainLoss,
                symbol: holding.symbol
            )
        }.sorted { $0.value > $1.value }
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