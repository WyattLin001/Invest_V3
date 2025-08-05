//
//  TournamentTradeRow.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽交易記錄行組件
//

import SwiftUI

struct TournamentTradeRow: View {
    let record: TournamentTradingRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // 交易類型指示器
            ZStack {
                Circle()
                    .fill(tradeTypeColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: tradeTypeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tradeTypeColor)
            }
            
            // 股票信息和交易詳情
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(record.stockName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(record.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    // 交易數量和價格
                    Text("\(formatQuantity(record.shares)) 股 @ \(formatPrice(record.price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 交易時間
                    Text(formatDate(record.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 交易金額
            VStack(alignment: .trailing, spacing: 2) {
                Text(tradeTypeText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(tradeTypeColor)
                
                Text(formatCurrency(record.totalAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // 手續費（如果有）
                if record.fee > 0 {
                    Text("手續費 \(formatCurrency(record.fee))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
    }
    
    // MARK: - 計算屬性
    private var tradeTypeColor: Color {
        switch record.type {
        case .buy:
            return .red
        case .sell:
            return .green
        }
    }
    
    private var tradeTypeIcon: String {
        switch record.type {
        case .buy:
            return "arrow.down.circle.fill"
        case .sell:
            return "arrow.up.circle.fill"
        }
    }
    
    private var tradeTypeText: String {
        switch record.type {
        case .buy:
            return "買入"
        case .sell:
            return "賣出"
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
    
    private func formatPrice(_ price: Double) -> String {
        return String(format: "%.2f", price)
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity >= 1000 {
            return String(format: "%.1fK", quantity / 1000)
        } else {
            return String(format: "%.0f", quantity)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 預覽
#Preview {
    VStack(spacing: 8) {
        TournamentTradeRow(
            record: TournamentTradingRecord(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                symbol: "2330",
                stockName: "台積電",
                type: .buy,
                shares: 1000,
                price: 580.0,
                totalAmount: 580000,
                fee: 1159,
                netAmount: 578841,
                timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            )
        )
        
        TournamentTradeRow(
            record: TournamentTradingRecord(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                symbol: "0050",
                stockName: "元大台灣50",
                type: .sell,
                shares: 500,
                price: 140.0,
                totalAmount: 70000,
                fee: 140,
                netAmount: 69860,
                timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            )
        )
        
        TournamentTradeRow(
            record: TournamentTradingRecord(
                id: UUID(),
                tournamentId: UUID(),
                userId: UUID(),
                symbol: "3008",
                stockName: "大立光",
                type: .buy,
                shares: 20,
                price: 2800.0,
                totalAmount: 56000,
                fee: 112,
                netAmount: 55888,
                timestamp: Date().addingTimeInterval(-86400), // 1 day ago
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            )
        )
    }
    .padding()
    .background(Color(.systemGray6))
}