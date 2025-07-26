//
//  TradingStatsCard.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  交易統計卡片組件 - 顯示交易統計數據的專業卡片
//

import SwiftUI

// MARK: - 交易統計卡片類型

/// 交易統計卡片類型枚舉
enum TradingStatsCardType {
    case totalTrades        // 總交易筆數
    case totalVolume        // 總成交金額
    case buyToSellRatio     // 買賣比例
    case realizedGainLoss   // 已實現損益
    
    var title: String {
        switch self {
        case .totalTrades:
            return "總交易筆數"
        case .totalVolume:
            return "總成交金額"
        case .buyToSellRatio:
            return "買進/賣出"
        case .realizedGainLoss:
            return "已實現損益"
        }
    }
    
    var iconName: String {
        switch self {
        case .totalTrades:
            return "chart.bar.fill"
        case .totalVolume:
            return "dollarsign.circle.fill"
        case .buyToSellRatio:
            return "arrow.up.arrow.down.circle.fill"
        case .realizedGainLoss:
            return "arrow.up.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .totalTrades:
            return .blue
        case .totalVolume:
            return .orange
        case .buyToSellRatio:
            return .purple
        case .realizedGainLoss:
            return .green
        }
    }
}

// MARK: - 交易統計卡片

/// 交易統計卡片組件
/// 顯示各種交易統計數據，包含圖標、數值和趨勢指示
struct TradingStatsCard: View {
    let type: TradingStatsCardType
    let value: String
    let subtitle: String?
    let trend: TrendIndicator?
    let isLoading: Bool
    
    init(
        type: TradingStatsCardType,
        value: String,
        subtitle: String? = nil,
        trend: TrendIndicator? = nil,
        isLoading: Bool = false
    ) {
        self.type = type
        self.value = value
        self.subtitle = subtitle
        self.trend = trend
        self.isLoading = isLoading
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 標題和圖標
            headerSection
            
            // 主要數值
            valueSection
            
            // 副標題和趨勢
            if let subtitle = subtitle {
                subtitleSection
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfacePrimary)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.divider, lineWidth: 0.5)
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // 圖標
            Image(systemName: type.iconName)
                .font(.title3)
                .foregroundColor(type.iconColor)
            
            Spacer()
            
            // 趨勢指示器
            if let trend = trend {
                trendIndicatorView(trend)
            }
        }
    }
    
    // MARK: - Value Section
    
    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 標題
            HStack {
                Text(type.title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            
            // 主要數值
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.textPrimary)
                } else {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Subtitle Section
    
    private var subtitleSection: some View {
        HStack {
            Text(subtitle ?? "")
                .font(.caption2)
                .foregroundColor(.textSecondary)
            Spacer()
        }
    }
    
    // MARK: - Trend Indicator
    
    private func trendIndicatorView(_ trend: TrendIndicator) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend.iconName)
                .font(.caption2)
                .foregroundColor(trend.color)
            
            if let percentage = trend.percentage {
                Text(String(format: "%.1f%%", abs(percentage)))
                    .font(.caption2)
                    .foregroundColor(trend.color)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(trend.color.opacity(0.1))
        )
    }
}

// MARK: - 趨勢指示器

/// 趨勢指示器數據模型
struct TrendIndicator {
    let type: TrendType
    let percentage: Double?
    
    enum TrendType {
        case up
        case down
        case flat
        
        var iconName: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .flat: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .success
            case .down: return .danger
            case .flat: return .textSecondary
            }
        }
    }
    
    var iconName: String { type.iconName }
    var color: Color { type.color }
    
    static func up(_ percentage: Double) -> TrendIndicator {
        TrendIndicator(type: .up, percentage: percentage)
    }
    
    static func down(_ percentage: Double) -> TrendIndicator {
        TrendIndicator(type: .down, percentage: percentage)
    }
    
    static let flat = TrendIndicator(type: .flat, percentage: nil)
}

// MARK: - 統計卡片網格

/// 交易統計卡片網格容器
struct TradingStatsGrid: View {
    let statistics: TradingStatistics
    let isLoading: Bool
    
    init(statistics: TradingStatistics, isLoading: Bool = false) {
        self.statistics = statistics
        self.isLoading = isLoading
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            // 總交易筆數
            TradingStatsCard(
                type: .totalTrades,
                value: "\(statistics.totalTrades)",
                subtitle: trendDescription,
                trend: .up(5.2), // 模擬趨勢
                isLoading: isLoading
            )
            
            // 總成交金額
            TradingStatsCard(
                type: .totalVolume,
                value: formatLargeAmount(statistics.totalVolume),
                subtitle: "本月交易量",
                isLoading: isLoading
            )
            
            // 買賣比例
            TradingStatsCard(
                type: .buyToSellRatio,
                value: statistics.buyToSellRatio,
                subtitle: buyToSellDescription,
                trend: buyToSellTrend,
                isLoading: isLoading
            )
            
            // 已實現損益
            TradingStatsCard(
                type: .realizedGainLoss,
                value: formatGainLoss(statistics.totalRealizedGainLoss),
                subtitle: String(format: "勝率 %.1f%%", statistics.winRate),
                trend: gainLossTrend,
                isLoading: isLoading
            )
        }
    }
    
    // MARK: - Grid Configuration
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
    
    // MARK: - Computed Properties
    
    private var trendDescription: String {
        if statistics.todayTrades > 0 {
            return "今日 \(statistics.todayTrades) 筆"
        } else {
            return "本週 \(statistics.weekTrades) 筆"
        }
    }
    
    private var buyToSellDescription: String {
        let buyPercent = statistics.totalTrades > 0 ? 
            Double(statistics.buyTrades) / Double(statistics.totalTrades) * 100 : 0
        return String(format: "買進佔 %.0f%%", buyPercent)
    }
    
    private var buyToSellTrend: TrendIndicator? {
        if statistics.buyTrades > statistics.sellTrades {
            return .up(10.5) // 模擬數據
        } else if statistics.sellTrades > statistics.buyTrades {
            return .down(8.3) // 模擬數據
        } else {
            return .flat
        }
    }
    
    private var gainLossTrend: TrendIndicator? {
        if statistics.totalRealizedGainLoss > 0 {
            return .up(statistics.winRate)
        } else if statistics.totalRealizedGainLoss < 0 {
            return .down(100 - statistics.winRate)
        } else {
            return .flat
        }
    }
    
    // MARK: - Formatting Methods
    
    private func formatLargeAmount(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "$%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "$%.1fK", amount / 1_000)
        } else {
            return String(format: "$%.0f", amount)
        }
    }
    
    private func formatGainLoss(_ amount: Double) -> String {
        let absAmount = abs(amount)
        let sign = amount >= 0 ? "+" : "-"
        
        if absAmount >= 1_000_000 {
            return String(format: "%@$%.1fM", sign, absAmount / 1_000_000)
        } else if absAmount >= 1_000 {
            return String(format: "%@$%.1fK", sign, absAmount / 1_000)
        } else {
            return String(format: "%@$%.0f", sign, absAmount)
        }
    }
}

// MARK: - 緊湊版統計卡片

/// 緊湊版交易統計卡片（單行顯示）
struct CompactTradingStatsCard: View {
    let type: TradingStatsCardType
    let value: String
    let trend: TrendIndicator?
    
    var body: some View {
        HStack(spacing: 12) {
            // 圖標
            Image(systemName: type.iconName)
                .font(.title3)
                .foregroundColor(type.iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(type.iconColor.opacity(0.1))
                )
            
            // 內容
            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                HStack {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    if let trend = trend {
                        Image(systemName: trend.iconName)
                            .font(.caption2)
                            .foregroundColor(trend.color)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfacePrimary)
        )
    }
}

// MARK: - Preview

#Preview("交易統計卡片") {
    let mockStatistics = TradingStatistics(
        totalTrades: 5,
        totalVolume: 1754500,
        buyTrades: 3,
        sellTrades: 2,
        totalRealizedGainLoss: 104500,
        totalFees: 2499,
        averageTradeSize: 350900,
        winRate: 75.0,
        todayTrades: 2,
        weekTrades: 4,
        monthTrades: 5
    )
    
    ScrollView {
        VStack(spacing: 20) {
            Text("交易統計卡片")
                .font(.headline)
            
            TradingStatsGrid(statistics: mockStatistics)
                .padding()
            
            Text("緊湊版")
                .font(.headline)
            
            VStack(spacing: 8) {
                CompactTradingStatsCard(
                    type: .totalTrades,
                    value: "5",
                    trend: .up(12.5)
                )
                
                CompactTradingStatsCard(
                    type: .realizedGainLoss,
                    value: "+$104.5K",
                    trend: .up(18.3)
                )
            }
            .padding()
        }
    }
    .background(Color.backgroundPrimary)
}