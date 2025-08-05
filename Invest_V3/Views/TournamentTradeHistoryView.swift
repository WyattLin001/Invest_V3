//
//  TournamentTradeHistoryView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽完整交易歷史檢視
//

import SwiftUI

struct TournamentTradeHistoryView: View {
    let records: [TournamentTradingRecord]
    
    @State private var searchText = ""
    @State private var selectedFilter: TradeFilter = .all
    @State private var selectedSortOrder: SortOrder = .newest
    
    enum TradeFilter: String, CaseIterable {
        case all = "全部"
        case buy = "買入"
        case sell = "賣出"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .buy: return "arrow.down.circle"
            case .sell: return "arrow.up.circle"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case newest = "最新"
        case oldest = "最舊"
        case highest = "金額高"
        case lowest = "金額低"
        
        var icon: String {
            switch self {
            case .newest: return "arrow.down"
            case .oldest: return "arrow.up"
            case .highest: return "arrow.down.right"
            case .lowest: return "arrow.up.right"
            }
        }
    }
    
    private var filteredAndSortedRecords: [TournamentTradingRecord] {
        var filtered = records
        
        // 應用搜尋過濾
        if !searchText.isEmpty {
            filtered = filtered.filter { record in
                record.stockName.localizedCaseInsensitiveContains(searchText) ||
                record.symbol.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 應用交易類型過濾
        switch selectedFilter {
        case .all:
            break
        case .buy:
            filtered = filtered.filter { $0.type == .buy }
        case .sell:
            filtered = filtered.filter { $0.type == .sell }
        }
        
        // 應用排序
        switch selectedSortOrder {
        case .newest:
            filtered.sort { $0.timestamp > $1.timestamp }
        case .oldest:
            filtered.sort { $0.timestamp < $1.timestamp }
        case .highest:
            filtered.sort { $0.totalAmount > $1.totalAmount }
        case .lowest:
            filtered.sort { $0.totalAmount < $1.totalAmount }
        }
        
        return filtered
    }
    
    private var tradingSummary: TradingSummary {
        let totalTrades = records.count
        let buyTrades = records.filter { $0.type == .buy }.count
        let sellTrades = records.filter { $0.type == .sell }.count
        let totalVolume = records.reduce(0) { $0 + $1.totalAmount }
        let totalFees = records.reduce(0) { $0 + $1.fee }
        
        return TradingSummary(
            totalTrades: totalTrades,
            buyTrades: buyTrades,
            sellTrades: sellTrades,
            totalVolume: totalVolume,
            totalFees: totalFees
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜尋和過濾器
                searchAndFilterSection
                
                // 交易統計摘要
                tradingSummarySection
                
                // 交易記錄列表
                if filteredAndSortedRecords.isEmpty {
                    emptyStateView
                } else {
                    tradeHistoryList
                }
            }
            .navigationTitle("交易歷史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button(action: { selectedSortOrder = order }) {
                                Label(order.rawValue, systemImage: order.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.brandGreen)
                    }
                }
            }
        }
    }
    
    // MARK: - 搜尋和過濾區域
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜尋股票名稱或代碼", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 過濾器選項
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TradeFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            HStack(spacing: 4) {
                                Image(systemName: filter.icon)
                                    .font(.caption)
                                
                                Text(filter.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.brandGreen : Color(.systemGray5))
                            )
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - 交易統計摘要
    private var tradingSummarySection: some View {
        HStack {
            StatCard(
                title: "總交易",
                value: "\(tradingSummary.totalTrades)",
                subtitle: "筆",
                color: .blue
            )
            
            StatCard(
                title: "買入",
                value: "\(tradingSummary.buyTrades)",
                subtitle: "筆",
                color: .red
            )
            
            StatCard(
                title: "賣出",
                value: "\(tradingSummary.sellTrades)",
                subtitle: "筆",
                color: .green
            )
            
            StatCard(
                title: "總成交額",
                value: formatCurrencyShort(tradingSummary.totalVolume),
                subtitle: "NT$",
                color: .purple
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 交易記錄列表
    private var tradeHistoryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredAndSortedRecords) { record in
                    TournamentTradeRow(record: record)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - 空狀態視圖
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("沒有找到交易記錄")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty || selectedFilter != .all {
                Text("嘗試調整搜尋條件或過濾器")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("清除篩選條件") {
                    searchText = ""
                    selectedFilter = .all
                }
                .foregroundColor(.brandGreen)
            } else {
                Text("開始交易後，您的交易記錄將顯示在這裡")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    // MARK: - 輔助方法
    private func formatCurrencyShort(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.1fK", amount / 1_000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}

// MARK: - 統計卡片組件
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - 交易統計數據模型
struct TradingSummary {
    let totalTrades: Int
    let buyTrades: Int
    let sellTrades: Int
    let totalVolume: Double
    let totalFees: Double
}

// MARK: - 預覽
#Preview {
    TournamentTradeHistoryView(
        records: [
            TournamentTradingRecord(
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
                timestamp: Date().addingTimeInterval(-3600),
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            ),
            TournamentTradingRecord(
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
                timestamp: Date().addingTimeInterval(-7200),
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            ),
            TournamentTradingRecord(
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
                timestamp: Date().addingTimeInterval(-86400),
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            )
        ]
    )
}