//
//  TournamentHoldingRow.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽持股行組件
//

import SwiftUI

struct TournamentHoldingRow: View {
    let holding: TournamentHolding
    
    var body: some View {
        HStack(spacing: 12) {
            // 股票圖標
            ZStack {
                Circle()
                    .fill(stockTypeColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(holding.symbol.prefix(2))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(stockTypeColor)
            }
            
            // 股票信息
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(holding.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 持股數據
            VStack(alignment: .trailing, spacing: 2) {
                // 股數和當前價格
                HStack(spacing: 4) {
                    Text("\(formatShares(holding.shares))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("股")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(formatCurrency(holding.currentPrice))
                    .font(.caption)
                    .foregroundColor(.primary)
                
                // 總價值
                Text(formatCurrency(holding.totalValue))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // 損益指示器
            VStack(alignment: .trailing, spacing: 2) {
                // 損益金額
                Text(formatCurrency(holding.unrealizedGainLoss))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(holding.unrealizedGainLoss >= 0 ? .green : .red)
                
                // 損益百分比
                Text(String(format: "%+.2f%%", holding.unrealizedGainLossPercent))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(holding.unrealizedGainLoss >= 0 ? .green : .red)
                
                // 持股比例
                Text(String(format: "%.1f%%", holding.allocationPercentage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
    
    // MARK: - 計算屬性
    private var stockTypeColor: Color {
        // 根據股票代碼或類型設定顏色
        if holding.symbol.hasPrefix("00") {
            return .blue // ETF
        } else if holding.symbol.first?.isNumber == true {
            let firstDigit = String(holding.symbol.prefix(1))
            switch firstDigit {
            case "1", "2":
                return .green // 金融、食品等
            case "3", "4":
                return .orange // 塑膠、電子等
            case "5", "6":
                return .purple // 電機、化工等
            default:
                return .gray
            }
        } else {
            return .brandGreen // 其他
        }
    }
    
    // MARK: - 輔助方法
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "NT$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
    
    private func formatShares(_ shares: Double) -> String {
        if shares >= 1000 {
            return String(format: "%.1fK", shares / 1000)
        } else {
            return String(format: "%.0f", shares)
        }
    }
}

// MARK: - 預覽
#Preview {
    VStack(spacing: 8) {
        TournamentHoldingRow(
            holding: TournamentHolding(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                symbol: "2330",
                name: "台積電",
                shares: 1000,
                averagePrice: 580.0,
                currentPrice: 620.0,
                firstPurchaseDate: Date(),
                lastUpdated: Date()
            )
        )
        
        TournamentHoldingRow(
            holding: TournamentHolding(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                symbol: "0050",
                name: "元大台灣50",
                shares: 500,
                averagePrice: 140.0,
                currentPrice: 135.0,
                firstPurchaseDate: Date(),
                lastUpdated: Date()
            )
        )
        
        TournamentHoldingRow(
            holding: TournamentHolding(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                symbol: "3008",
                name: "大立光",
                shares: 50,
                averagePrice: 2800.0,
                currentPrice: 2950.0,
                firstPurchaseDate: Date(),
                lastUpdated: Date()
            )
        )
    }
    .padding()
    .background(Color(.systemGray6))
}