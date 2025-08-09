import SwiftUI

// MARK: - 圓環圖組件
struct PieChartView: View {
    let items: [PortfolioItem]
    
    var body: some View {
        ZStack {
            if items.isEmpty {
                // 空狀態
                Circle()
                    .stroke(Color.gray300, lineWidth: 8)
                    .overlay(
                        Text("暫無持股")
                            .font(.caption2)
                            .foregroundColor(.gray600)
                    )
            } else {
                // 繪製圓環圖
                ForEach(0..<items.count, id: \.self) { index in
                    PieSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: items[index].color
                    )
                }
                
                // 中心圓
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("投資組合")
                            .font(.caption2)
                            .foregroundColor(.gray600)
                            .multilineTextAlignment(.center)
                    )
            }
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let previousPercents = items.prefix(index).map { $0.percent }.reduce(0, +)
        let degrees = safeDegrees(previousPercents * 3.6 - 90)
        return Angle(degrees: degrees)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let currentPercents = items.prefix(index + 1).map { $0.percent }.reduce(0, +)
        let degrees = safeDegrees(currentPercents * 3.6 - 90)
        return Angle(degrees: degrees)
    }
    
    // MARK: - Helper Functions
    
    /// 安全處理角度值，避免 NaN 和無限值
    private func safeDegrees(_ value: Double) -> Double {
        guard value.isFinite && !value.isNaN else { return 0.0 }
        return value
    }
}

// MARK: - 圓環片段
struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        Path { path in
            let center = CGPoint(x: 45, y: 45) // 圓心
            let radius: CGFloat = 35
            let innerRadius: CGFloat = 20
            
            // 安全檢查角度值
            guard !startAngle.degrees.isNaN && !endAngle.degrees.isNaN,
                  startAngle.degrees.isFinite && endAngle.degrees.isFinite else {
                print("⚠️ [PieSlice] 無效角度值 - start: \(startAngle.degrees), end: \(endAngle.degrees)")
                return
            }
            
            // 外圓弧
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            
            // 內圓弧
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: endAngle,
                endAngle: startAngle,
                clockwise: true
            )
            
            path.closeSubpath()
        }
        .fill(color)
    }
}

#Preview {
    VStack(spacing: 20) {
        // 有資料的圓環圖
        PieChartView(items: [
            PortfolioItem(symbol: "2330.TW", percent: 40, amount: 400000, color: .brandGreen),
            PortfolioItem(symbol: "2317.TW", percent: 30, amount: 300000, color: .brandOrange),
            PortfolioItem(symbol: "2454.TW", percent: 30, amount: 300000, color: .brandBlue)
        ])
        .frame(width: 90, height: 90)
        
        // 空狀態圓環圖
        PieChartView(items: [])
            .frame(width: 90, height: 90)
    }
    .padding()
} 