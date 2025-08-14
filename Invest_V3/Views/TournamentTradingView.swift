//
//  TournamentTradingView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/1.
//  錦標賽專用交易界面 - 提供錦標賽上下文的交易體驗
//

import SwiftUI

struct TournamentTradingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tournamentStateManager = TournamentStateManager.shared
    @StateObject private var tradingService = TradingService.shared
    @State private var selectedSegment = 0
    @State private var searchText = ""
    @State private var showExitConfirmation = false
    
    private let segments = ["熱門", "持股", "關注", "排行"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 錦標賽狀態標題欄
                tournamentHeaderSection
                
                // 投資組合摘要
                portfolioSummarySection
                
                // 分段控制器
                segmentPicker
                
                // 搜尋欄
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                // 內容區域
                contentView
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            loadInitialData()
        }
        .alert("離開錦標賽", isPresented: $showExitConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確認離開", role: .destructive) {
                Task {
                    await tournamentStateManager.leaveTournament()
                    dismiss()
                }
            }
        } message: {
            Text("您確定要離開當前錦標賽嗎？這將結束您的參與狀態。")
        }
    }
    
    // MARK: - 錦標賽標題區域
    
    private var tournamentHeaderSection: some View {
        VStack(spacing: 0) {
            // 導航欄
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    if let tournamentName = tournamentStateManager.getCurrentTournamentDisplayName() {
                        Text(tournamentName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    } else {
                        Text("錦標賽交易")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(tournamentStateManager.participationState.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: { showExitConfirmation = true }) {
                        Label("離開錦標賽", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 錦標賽狀態指示器
            if tournamentStateManager.isParticipatingInTournament {
                HStack {
                    Circle()
                        .fill(statusIndicatorColor)
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let rank = tournamentStateManager.currentTournamentContext?.currentRank {
                        Text("排名 #\(rank)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            Divider()
        }
        .background(.regularMaterial)
    }
    
    // MARK: - 投資組合摘要
    
    private var portfolioSummarySection: some View {
        VStack(spacing: 12) {
            if let context = tournamentStateManager.currentTournamentContext,
               let portfolio = context.portfolio,
               let performance = context.performance {
                
                HStack(spacing: 20) {
                    // 總價值
                    VStack(alignment: .leading, spacing: 4) {
                        Text("總價值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatCurrency(portfolio.totalPortfolioValue))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // 總回報
                    VStack(alignment: .leading, spacing: 4) {
                        Text("總回報")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Text(String(format: "%.2f%%", performance.totalReturnPercentage))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(performance.totalReturnPercentage >= 0 ? .green : .red)
                            
                            Image(systemName: performance.totalReturnPercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                                .foregroundColor(performance.totalReturnPercentage >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    // 現金比例
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("現金比例")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f%%", portfolio.cashPercentage))
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, 16)
                
                // 風險指標
                HStack(spacing: 16) {
                    TradingMetricItem(
                        title: "夏普比率",
                        value: String(format: "%.2f", performance.sharpeRatio ?? 0.0),
                        color: (performance.sharpeRatio ?? 0.0) > 1 ? .green : ((performance.sharpeRatio ?? 0.0) > 0 ? .orange : .red)
                    )
                    
                    TradingMetricItem(
                        title: "最大回撤",
                        value: String(format: "%.1f%%", performance.maxDrawdown),
                        color: performance.maxDrawdown < 10 ? .green : (performance.maxDrawdown < 20 ? .orange : .red)
                    )
                    
                    TradingMetricItem(
                        title: "勝率",
                        value: String(format: "%.1f%%", performance.winRate),
                        color: performance.winRate > 60 ? .green : (performance.winRate > 40 ? .orange : .red)
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
            } else {
                // 載入中或無數據狀態
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("載入投資組合資料中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 分段選擇器
    
    private var segmentPicker: some View {
        Picker("交易選項", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { index in
                Text(segments[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 內容視圖
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case 0:
            TournamentHotStocksView(stocks: filteredStocks)
        case 1:
            TournamentHoldingsView()
        case 2:
            TournamentWatchlistView()
        case 3:
            TournamentRankingsView()
        default:
            TournamentHotStocksView(stocks: filteredStocks)
        }
    }
    
    // MARK: - 計算屬性
    
    private var filteredStocks: [TradingStock] {
        if searchText.isEmpty {
            return tradingService.stocks
        } else {
            return tradingService.stocks.filter { stock in
                stock.symbol.lowercased().contains(searchText.lowercased()) ||
                stock.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private var statusIndicatorColor: Color {
        switch tournamentStateManager.participationState {
        case .active: return .green
        case .joining: return .orange
        case .paused: return .yellow
        case .eliminated: return .red
        case .completed: return .blue
        case .none: return .gray
        }
    }
    
    private var statusText: String {
        switch tournamentStateManager.participationState {
        case .active: return "積極參與中"
        case .joining: return "正在加入"
        case .paused: return "已暫停"
        case .eliminated: return "已淘汰"
        case .completed: return "已完成"
        case .none: return "未參與"
        }
    }
    
    // MARK: - 輔助方法
    
    private func loadInitialData() {
        Task {
            await tradingService.loadStocks()
            await tradingService.loadTournamentPortfolio(tournamentId: tradingService.currentTournamentId)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - 交易指標項目
struct TradingMetricItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - 錦標賽熱門股票視圖
struct TournamentHotStocksView: View {
    let stocks: [TradingStock]
    @StateObject private var tournamentStateManager = TournamentStateManager.shared
    
    var body: some View {
        if stocks.isEmpty {
            GeneralEmptyStateView(
                icon: "chart.bar",
                title: "暫無股票資料",
                message: "請檢查網路連接"
            )
        } else {
            List(stocks) { stock in
                TournamentStockRow(stock: stock, canTrade: tournamentStateManager.canMakeTrades())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(PlainListStyle())
        }
    }
}

// MARK: - 錦標賽持股視圖
struct TournamentHoldingsView: View {
    @StateObject private var tournamentStateManager = TournamentStateManager.shared
    
    var body: some View {
        if let portfolio = tournamentStateManager.currentTournamentContext?.portfolio,
           !portfolio.holdings.isEmpty {
            List(portfolio.holdings) { holding in
                TournamentHoldingRow(holding: holding)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(PlainListStyle())
        } else {
            GeneralEmptyStateView(
                icon: "briefcase",
                title: "暫無持股",
                message: "開始您的第一筆錦標賽交易吧！"
            )
        }
    }
}

// MARK: - 錦標賽關注清單視圖
struct TournamentWatchlistView: View {
    var body: some View {
        GeneralEmptyStateView(
            icon: "heart",
            title: "關注清單",
            message: "功能開發中，敬請期待"
        )
    }
}

// TournamentRankingsView is defined in a separate file

// MARK: - 錦標賽股票行
struct TournamentStockRow: View {
    let stock: TradingStock
    let canTrade: Bool
    @State private var showBuyOrder = false
    @State private var showSellOrder = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 股票資訊
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(stock.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TradingService.shared.formatCurrency(stock.price))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text("+2.5%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // 交易按鈕
            if canTrade {
                HStack(spacing: 12) {
                    Button(action: { showBuyOrder = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                            Text("買入")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showSellOrder = true }) {
                        HStack {
                            Image(systemName: "minus.circle.fill")
                                .font(.caption)
                            Text("賣出")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("交易已暫停")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showBuyOrder) {
            TradeOrderView(stock: stock, action: .buy)
        }
        .sheet(isPresented: $showSellOrder) {
            TradeOrderView(stock: stock, action: .sell)
        }
    }
}

// NOTE: TournamentHoldingRow is now defined in TournamentHoldingRow.swift to avoid duplicate declaration

// NOTE: TournamentAllocationRow is now defined in PortfolioView.swift to avoid duplicate declaration

#Preview {
    TournamentTradingView()
        .environmentObject(TournamentStateManager.shared)
}