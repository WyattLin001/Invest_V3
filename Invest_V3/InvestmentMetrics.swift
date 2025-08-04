//
//  InvestmentMetrics.swift
//  Invest_V3
//
//  Created by Claude Code on 2025/8/4.
//

import SwiftUI
import Foundation

// MARK: - 投資指標數據模型
struct InvestmentMetrics {
    let totalReturn: Double               // 總回報
    let annualizedReturn: Double          // 年化回報率
    let maxDrawdown: Double               // 最大回撤
    let sharpeRatio: Double?              // 夏普比率
    let winRate: Double                   // 勝率
    let averageReturn: Double             // 平均回報
    let volatility: Double                // 波動率
    let riskAdjustedReturn: Double        // 風險調整回報
    let betaCoefficient: Double?          // 貝塔係數
    let informationRatio: Double?         // 信息比率
    let calmarRatio: Double?              // 卡瑪比率
    let maximumConsecutiveLosses: Int     // 最大連續虧損次數
    let profitFactor: Double              // 盈利因子
    let averageHoldingPeriod: Double      // 平均持有天數
    
    // 計算投資等級
    var investmentGrade: InvestmentGrade {
        let score = calculateScore()
        switch score {
        case 90...100: return .excellent
        case 80..<90: return .good
        case 70..<80: return .average
        case 60..<70: return .belowAverage
        default: return .poor
        }
    }
    
    // 計算綜合評分
    private func calculateScore() -> Double {
        var score: Double = 0
        var factors: Double = 0
        
        // 年化回報率 (30分)
        if annualizedReturn > 15 {
            score += 30
        } else if annualizedReturn > 10 {
            score += 25
        } else if annualizedReturn > 5 {
            score += 20
        } else if annualizedReturn > 0 {
            score += 15
        } else {
            score += 0
        }
        factors += 30
        
        // 夏普比率 (25分)
        if let sharpe = sharpeRatio {
            if sharpe > 2.0 {
                score += 25
            } else if sharpe > 1.5 {
                score += 20
            } else if sharpe > 1.0 {
                score += 15
            } else if sharpe > 0.5 {
                score += 10
            } else {
                score += 5
            }
            factors += 25
        }
        
        // 最大回撤 (20分) - 越小越好
        if maxDrawdown > -5 {
            score += 20
        } else if maxDrawdown > -10 {
            score += 15
        } else if maxDrawdown > -20 {
            score += 10
        } else if maxDrawdown > -30 {
            score += 5
        } else {
            score += 0
        }
        factors += 20
        
        // 勝率 (15分)
        if winRate > 70 {
            score += 15
        } else if winRate > 60 {
            score += 12
        } else if winRate > 50 {
            score += 10
        } else if winRate > 40 {
            score += 6
        } else {
            score += 3
        }
        factors += 15
        
        // 盈利因子 (10分)
        if profitFactor > 2.0 {
            score += 10
        } else if profitFactor > 1.5 {
            score += 8
        } else if profitFactor > 1.2 {
            score += 6
        } else if profitFactor > 1.0 {
            score += 4
        } else {
            score += 0
        }
        factors += 10
        
        return factors > 0 ? (score / factors) * 100 : 0
    }
}

// MARK: - 投資等級枚舉
enum InvestmentGrade: String, CaseIterable {
    case excellent = "優秀"
    case good = "良好"
    case average = "一般"
    case belowAverage = "待改進"
    case poor = "不佳"
    
    var color: Color {
        switch self {
        case .excellent: return DesignTokens.excellentPerformanceColor
        case .good: return DesignTokens.goodPerformanceColor
        case .average: return DesignTokens.averagePerformanceColor
        case .belowAverage: return DesignTokens.warningPerformanceColor
        case .poor: return DesignTokens.poorPerformanceColor
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "crown.fill"
        case .good: return "star.fill"
        case .average: return "star.leadinghalf.filled"
        case .belowAverage: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "投資表現優秀，風險控制良好"
        case .good: return "投資表現良好，繼續保持"
        case .average: return "投資表現一般，有改進空間"
        case .belowAverage: return "投資表現待改進，需要調整策略"
        case .poor: return "投資表現不佳，建議重新檢視策略"
        }
    }
}

// MARK: - 投資指標計算器
struct InvestmentMetricsCalculator {
    
    /// 計算投資組合的專業指標
    static func calculateMetrics(from portfolioManager: ChatPortfolioManager) -> InvestmentMetrics {
        let holdings = portfolioManager.holdings
        let tradingRecords = portfolioManager.tradingRecords
        
        // 基礎計算
        let totalInvestment = portfolioManager.totalInvested
        let currentValue = portfolioManager.totalPortfolioValue
        let totalReturn = currentValue - totalInvestment
        let totalReturnPercent = totalInvestment > 0 ? (totalReturn / totalInvestment) * 100 : 0
        
        // 交易統計
        let buyRecords = tradingRecords.filter { $0.type == .buy }
        let sellRecords = tradingRecords.filter { $0.type == .sell }
        let profitableTrades = sellRecords.filter { ($0.realizedGainLoss ?? 0) > 0 }
        let losingTrades = sellRecords.filter { ($0.realizedGainLoss ?? 0) < 0 }
        
        let winRate = sellRecords.isEmpty ? 0 : Double(profitableTrades.count) / Double(sellRecords.count) * 100
        
        // 計算平均回報
        let averageReturn = sellRecords.isEmpty ? 0 : sellRecords.compactMap { $0.realizedGainLoss }.reduce(0, +) / Double(sellRecords.count)
        
        // 計算最大回撤 (簡化版本)
        let maxDrawdown = calculateMaxDrawdown(from: tradingRecords)
        
        // 計算夏普比率 (簡化版本)
        let sharpeRatio = calculateSharpeRatio(returns: tradingRecords.compactMap { $0.realizedGainLoss })
        
        // 計算波動率
        let volatility = calculateVolatility(returns: tradingRecords.compactMap { $0.realizedGainLoss })
        
        // 計算年化回報率 (假設投資時間為1年)
        let annualizedReturn = totalReturnPercent
        
        // 計算盈利因子
        let totalProfit = profitableTrades.compactMap { $0.realizedGainLoss }.reduce(0, +)
        let totalLoss = abs(losingTrades.compactMap { $0.realizedGainLoss }.reduce(0, +))
        let profitFactor = totalLoss > 0 ? totalProfit / totalLoss : (totalProfit > 0 ? 2.0 : 0.0)
        
        // 計算最大連續虧損
        let maxConsecutiveLosses = calculateMaxConsecutiveLosses(from: sellRecords)
        
        // 計算平均持有天數
        let averageHoldingPeriod = calculateAverageHoldingPeriod(from: tradingRecords)
        
        return InvestmentMetrics(
            totalReturn: totalReturn,
            annualizedReturn: annualizedReturn,
            maxDrawdown: maxDrawdown,
            sharpeRatio: sharpeRatio,
            winRate: winRate,
            averageReturn: averageReturn,
            volatility: volatility,
            riskAdjustedReturn: sharpeRatio != nil ? annualizedReturn / volatility : 0,
            betaCoefficient: nil, // 需要市場數據
            informationRatio: nil, // 需要基準數據
            calmarRatio: maxDrawdown != 0 ? annualizedReturn / abs(maxDrawdown) : nil,
            maximumConsecutiveLosses: maxConsecutiveLosses,
            profitFactor: profitFactor,
            averageHoldingPeriod: averageHoldingPeriod
        )
    }
    
    // MARK: - 私有計算方法
    
    private static func calculateMaxDrawdown(from records: [TradingRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        
        var peak: Double = 0
        var maxDrawdown: Double = 0
        var runningValue: Double = 0
        
        for record in records.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let gainLoss = record.realizedGainLoss {
                runningValue += gainLoss
                peak = max(peak, runningValue)
                let drawdown = (runningValue - peak) / max(peak, 1) * 100
                maxDrawdown = min(maxDrawdown, drawdown)
            }
        }
        
        return maxDrawdown
    }
    
    private static func calculateSharpeRatio(returns: [Double]) -> Double? {
        guard returns.count > 1 else { return nil }
        
        let averageReturn = returns.reduce(0, +) / Double(returns.count)
        let riskFreeRate: Double = 2.0 // 假設無風險利率為2%
        
        let variance = returns.map { pow($0 - averageReturn, 2) }.reduce(0, +) / Double(returns.count - 1)
        let standardDeviation = sqrt(variance)
        
        return standardDeviation > 0 ? (averageReturn - riskFreeRate) / standardDeviation : nil
    }
    
    private static func calculateVolatility(returns: [Double]) -> Double {
        guard returns.count > 1 else { return 0 }
        
        let averageReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - averageReturn, 2) }.reduce(0, +) / Double(returns.count - 1)
        
        return sqrt(variance)
    }
    
    private static func calculateMaxConsecutiveLosses(from records: [TradingRecord]) -> Int {
        var maxConsecutive = 0
        var currentConsecutive = 0
        
        for record in records.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let gainLoss = record.realizedGainLoss, gainLoss < 0 {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                currentConsecutive = 0
            }
        }
        
        return maxConsecutive
    }
    
    private static func calculateAverageHoldingPeriod(from records: [TradingRecord]) -> Double {
        let sellRecords = records.filter { $0.type == .sell }
        guard !sellRecords.isEmpty else { return 0 }
        
        // 簡化計算：假設平均持有7天
        return 7.0
    }
}

// MARK: - 專業指標卡片組件
struct ProfessionalMetricsCard: View {
    let metrics: InvestmentMetrics
    
    var body: some View {
        VStack(spacing: 20) {
            // 標題和等級
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("投資表現分析")
                        .font(DesignTokens.sectionHeader)
                        .fontWeight(.bold)
                        .adaptiveTextColor()
                    
                    Text("Professional Analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 投資等級徽章
                InvestmentGradeBadge(grade: metrics.investmentGrade)
            }
            
            // 核心指標網格
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 16
            ) {
                MetricCard(
                    title: "年化回報率",
                    value: String(format: "%.1f%%", metrics.annualizedReturn),
                    subtitle: "Annualized Return",
                    icon: "chart.line.uptrend.xyaxis",
                    color: metrics.annualizedReturn >= 0 ? DesignTokens.priceUpColor : DesignTokens.priceDownColor,
                    trend: metrics.annualizedReturn >= 10 ? .up : (metrics.annualizedReturn >= 0 ? .flat : .down)
                )
                
                MetricCard(
                    title: "夏普比率",
                    value: metrics.sharpeRatio != nil ? String(format: "%.2f", metrics.sharpeRatio!) : "N/A",
                    subtitle: "Sharpe Ratio",
                    icon: "target",
                    color: (metrics.sharpeRatio ?? 0) >= 1.0 ? Color.brandGreen : Color.brandBlue,
                    trend: (metrics.sharpeRatio ?? 0) >= 1.5 ? .up : ((metrics.sharpeRatio ?? 0) >= 1.0 ? .flat : .down)
                )
                
                MetricCard(
                    title: "最大回撤",
                    value: String(format: "%.1f%%", metrics.maxDrawdown),
                    subtitle: "Max Drawdown",
                    icon: "arrow.down.circle",
                    color: metrics.maxDrawdown >= -10 ? Color.brandGreen : Color.warning,
                    trend: metrics.maxDrawdown >= -5 ? .up : (metrics.maxDrawdown >= -15 ? .flat : .down)
                )
                
                MetricCard(
                    title: "勝率",
                    value: String(format: "%.1f%%", metrics.winRate),
                    subtitle: "Win Rate",
                    icon: "target",
                    color: metrics.winRate >= 60 ? DesignTokens.priceUpColor : (metrics.winRate >= 50 ? DesignTokens.averagePerformanceColor : DesignTokens.priceDownColor),
                    trend: metrics.winRate >= 70 ? .up : (metrics.winRate >= 50 ? .flat : .down)
                )
            }
            
            // 進階指標
            VStack(spacing: 12) {
                Text("進階指標")
                    .font(DesignTokens.subsectionHeader)
                    .fontWeight(.semibold)
                    .adaptiveTextColor()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    AdvancedMetricRow(
                        title: "波動率",
                        value: String(format: "%.2f", metrics.volatility),
                        icon: "waveform.path.ecg",
                        color: .brandBlue
                    )
                    
                    AdvancedMetricRow(
                        title: "盈利因子",
                        value: String(format: "%.2f", metrics.profitFactor),
                        icon: "multiply.circle",
                        color: metrics.profitFactor >= 1.5 ? Color.brandGreen : Color.warning
                    )
                    
                    if let calmar = metrics.calmarRatio {
                        AdvancedMetricRow(
                            title: "卡瑪比率",
                            value: String(format: "%.2f", calmar),
                            icon: "chart.bar.xaxis",
                            color: calmar >= 1.0 ? Color.brandGreen : Color.brandBlue
                        )
                    }
                    
                    AdvancedMetricRow(
                        title: "最大連續虧損",
                        value: "\(metrics.maximumConsecutiveLosses) 次",
                        icon: "arrow.down.forward.and.arrow.up.backward",
                        color: metrics.maximumConsecutiveLosses <= 3 ? Color.brandGreen : Color.warning
                    )
                    
                    AdvancedMetricRow(
                        title: "平均持有天數",
                        value: String(format: "%.1f 天", metrics.averageHoldingPeriod),
                        icon: "calendar",
                        color: .secondary
                    )
                }
            }
        }
        .padding(DesignTokens.spacingLG)
        .background(
            LinearGradient(
                colors: [Color.surfacePrimary, Color.surfaceSecondary.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignTokens.cornerRadiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusXL)
                .stroke(DesignTokens.borderColor, lineWidth: DesignTokens.borderWidthThin)
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 投資等級徽章
struct InvestmentGradeBadge: View {
    let grade: InvestmentGrade
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: grade.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(grade.color)
            
            Text(grade.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(grade.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(grade.color.opacity(0.1))
        .cornerRadius(DesignTokens.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .stroke(grade.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 指標卡片
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                TrendIndicator(direction: trend)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color.surfacePrimary)
        .cornerRadius(DesignTokens.cornerRadiusLG)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 進階指標行
struct AdvancedMetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
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
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(Color.surfaceSecondary.opacity(0.5))
        .cornerRadius(DesignTokens.cornerRadius)
    }
}

// MARK: - 趨勢方向
enum TrendDirection {
    case up, down, flat
    
    var icon: String {
        switch self {
        case .up: return "arrowtriangle.up.fill"
        case .down: return "arrowtriangle.down.fill"
        case .flat: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return DesignTokens.priceUpColor
        case .down: return DesignTokens.priceDownColor
        case .flat: return DesignTokens.neutralMetricColor
        }
    }
}

// MARK: - 趨勢指示器
struct TrendIndicator: View {
    let direction: TrendDirection
    
    var body: some View {
        Image(systemName: direction.icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(direction.color)
            .frame(width: 16, height: 16)
    }
}