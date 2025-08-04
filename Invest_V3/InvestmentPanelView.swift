import SwiftUI
import Foundation

/// 可重用的投資面板組件
/// 可在 HomeView 和 ChatView 中使用
struct InvestmentPanelView: View {
    @ObservedObject var portfolioManager: ChatPortfolioManager
    @Binding var stockSymbol: String
    @Binding var tradeAmount: String
    @Binding var tradeAction: String
    @Binding var showTradeSuccess: Bool
    @Binding var tradeSuccessMessage: String
    
    // 新增即時股價相關狀態
    @State private var currentPrice: Double = 0.0
    @State private var priceLastUpdated: Date?
    @State private var isPriceLoading = false
    @State private var priceError: String?
    @State private var estimatedShares: Double = 0.0
    @State private var estimatedCost: Double = 0.0
    @State private var showSellConfirmation = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var selectedStockName: String = "" // 儲存選擇的股票名稱
    @State private var showClearPortfolioConfirmation = false // 清空投資組合確認對話框
    
    let onExecuteTrade: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 投資組合標題區塊 - 增強視覺層次
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("投資組合")
                                    .font(DesignTokens.titleMedium)
                                    .fontWeight(.bold)
                                    .adaptiveTextColor()
                                
                                Text("Portfolio Overview")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 總資產價值快速顯示
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("總資產")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("$\(String(format: "%.0f", portfolioManager.totalPortfolioValue))")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // 投資組合統計卡片
                        HStack(spacing: 12) {
                            StatisticCard(
                                title: "持股數",
                                value: "\(portfolioManager.holdings.count)",
                                icon: "chart.bar.fill",
                                color: .brandBlue
                            )
                            
                            StatisticCard(
                                title: "未實現損益",
                                value: String(format: "%+.0f", portfolioManager.totalUnrealizedGainLoss),
                                icon: portfolioManager.totalUnrealizedGainLoss >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill",
                                color: portfolioManager.totalUnrealizedGainLoss >= 0 ? DesignTokens.priceUpColor : DesignTokens.priceDownColor
                            )
                            
                            StatisticCard(
                                title: "報酬率",
                                value: String(format: "%+.1f%%", portfolioManager.totalUnrealizedGainLossPercent),
                                icon: "percent",
                                color: portfolioManager.totalUnrealizedGainLossPercent >= 0 ? DesignTokens.priceUpColor : DesignTokens.priceDownColor
                            )
                        }
                    }
                    .padding(DesignTokens.spacingLG)
                    .background(
                        LinearGradient(
                            colors: [Color.surfacePrimary, Color.surfaceSecondary.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(DesignTokens.cornerRadiusLG)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                            .stroke(DesignTokens.borderColor, lineWidth: DesignTokens.borderWidthThin)
                    )
                    
                    // 投資組合圓形圖表區塊 - 增強視覺設計
                    VStack(spacing: 20) {
                        // 圖表標題
                        HStack {
                            Text("資產配置")
                                .font(DesignTokens.sectionHeader)
                                .fontWeight(.bold)
                                .adaptiveTextColor()
                            
                            Spacer()
                            
                            if !portfolioManager.holdings.isEmpty {
                                Text("互動圖表")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.brandGreen.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // 圓餅圖容器
                        VStack(spacing: 16) {
                            DynamicPieChart(data: portfolioManager.pieChartData, size: 140)
                                .padding(.vertical, 8)
                        }
                        .padding(DesignTokens.spacingLG)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusXL)
                                .fill(Color.surfacePrimary)
                                .shadow(
                                    color: Color.black.opacity(0.05),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusXL)
                                .stroke(DesignTokens.borderColor, lineWidth: DesignTokens.borderWidthThin)
                        )
                        
                        // 持股明細區塊
                        VStack(spacing: 16) {
                            HStack {
                                Text("持股明細")
                                    .font(DesignTokens.subsectionHeader)
                                    .fontWeight(.semibold)
                                    .adaptiveTextColor()
                                
                                Spacer()
                                
                                if !portfolioManager.holdings.isEmpty {
                                    Text("\(portfolioManager.holdings.count) 檔")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if portfolioManager.holdings.isEmpty {
                                // 空狀態設計
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.pie")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    
                                    Text("尚未進行任何投資")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .adaptiveTextColor(primary: false)
                                    
                                    Text("開始您的第一筆投資")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 40)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfaceSecondary.opacity(0.5))
                                .cornerRadius(DesignTokens.cornerRadiusLG)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                                        .stroke(DesignTokens.borderColor.opacity(0.5), lineWidth: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.clear, Color.brandGreen.opacity(0.1), Color.clear],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    style: StrokeStyle(lineWidth: 2, dash: [5])
                                                )
                                        )
                                )
                            } else {
                                // 網格佈局的持股列表
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8)
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(portfolioManager.holdings, id: \.id) { holding in
                                        EnhancedHoldingCard(holding: holding, portfolioManager: portfolioManager)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 專業投資分析區塊
                    if !portfolioManager.holdings.isEmpty {
                        VStack(spacing: 16) {
                            let metrics = InvestmentMetricsCalculator.calculateMetrics(from: portfolioManager)
                            ProfessionalMetricsCard(metrics: metrics)
                        }
                    }
                
                // 交易區域
                VStack(spacing: 16) {
                    HStack {
                        Text("進行交易")
                            .font(DesignTokens.sectionHeader)
                            .fontWeight(.bold)
                            .adaptiveTextColor()
                        
                        Spacer()
                        
                        Text("Trading Panel")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 股票代號輸入 - 使用智能搜尋組件
                    VStack(alignment: .leading, spacing: 8) {
                        Text("股票代號")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        StockSearchTextField(
                            text: $stockSymbol,
                            placeholder: "例如：2330 或 台積電"
                        ) { selectedStock in
                            // 當用戶選擇股票時的回調
                            stockSymbol = selectedStock.code
                            selectedStockName = selectedStock.name // 同時保存股票名稱
                            Task {
                                await fetchCurrentPrice()
                            }
                        }
                        .onChange(of: stockSymbol) { newValue in
                            Task {
                                await fetchCurrentPrice()
                            }
                        }
                        
                        // 即時股價顯示
                        if !stockSymbol.isEmpty {
                            HStack {
                                if isPriceLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("正在獲取價格...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let priceError = priceError {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text(priceError)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if currentPrice > 0 {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(.green)
                                    Text("$\(String(format: "%.2f", currentPrice))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    if let lastUpdated = priceLastUpdated {
                                        Text("更新於 \(DateFormatter.timeOnly.string(from: lastUpdated))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // 交易動作選擇
                    VStack(alignment: .leading, spacing: 8) {
                        Text("交易動作")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("交易動作", selection: $tradeAction) {
                            Text("買入").tag("buy")
                            Text("賣出").tag("sell")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 金額輸入
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tradeAction == "buy" ? "投資金額 ($)" : "賣出股數")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField(tradeAction == "buy" ? "輸入投資金額" : "輸入股數", text: $tradeAmount)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: tradeAmount) { _ in
                                calculateEstimation()
                            }
                        
                        // 交易資訊提示
                        TradeInfoView(
                            tradeAction: tradeAction,
                            tradeAmount: tradeAmount,
                            stockSymbol: stockSymbol,
                            currentPrice: currentPrice,
                            estimatedShares: estimatedShares,
                            estimatedCost: estimatedCost,
                            portfolioManager: portfolioManager
                        )
                    }
                    
                    // 執行交易按鈕
                    Button(action: {
                        if tradeAction == "sell" {
                            showSellConfirmation = true
                        } else {
                            executeTradeWithValidation()
                        }
                    }) {
                        Text("\(tradeAction == "buy" ? "買入" : "賣出") \(stockSymbol.isEmpty ? "股票" : stockSymbol)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isTradeButtonDisabled ? Color.gray : (tradeAction == "buy" ? Color.green : Color.red))
                            )
                    }
                    .disabled(isTradeButtonDisabled)
                    
                    // 測試按鈕：清空投資組合
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 8) {
                        Text("測試功能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            clearPortfolioWithConfirmation()
                        }) {
                            Text("🧹 清空投資組合")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange)
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .adaptiveBackground()
            .navigationTitle("投資面板")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("關閉") {
                    onClose()
                }
                .adaptiveTextColor()
            )
        }
        .alert("交易成功", isPresented: $showTradeSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(tradeSuccessMessage)
        }
        .alert("確認賣出", isPresented: $showSellConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確定賣出", role: .destructive) {
                executeTradeWithValidation()
            }
        } message: {
            Text("您確定要賣出 \(tradeAmount) 股 \(stockSymbol) 嗎？")
        }
        .alert("交易失敗", isPresented: $showErrorAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .alert("清空投資組合", isPresented: $showClearPortfolioConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確定清空", role: .destructive) {
                portfolioManager.clearCurrentUserPortfolio()
                tradeSuccessMessage = "投資組合已清空，虛擬資金已重置為 NT$1,000,000"
                showTradeSuccess = true
            }
        } message: {
            Text("⚠️ 此操作將清空您的所有投資記錄並重置虛擬資金，此操作無法復原。\n\n確定要繼續嗎？")
        }
    }
    
    // MARK: - 輔助方法
    
    
    /// 檢查交易按鈕是否應該被禁用
    private var isTradeButtonDisabled: Bool {
        stockSymbol.isEmpty || tradeAmount.isEmpty || (tradeAction == "buy" && currentPrice <= 0)
    }
    
    /// 獲取即時股價
    private func fetchCurrentPrice() async {
        guard !stockSymbol.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run {
                currentPrice = 0.0
                priceError = nil
                priceLastUpdated = nil
            }
            return
        }
        
        await MainActor.run {
            isPriceLoading = true
            priceError = nil
        }
        
        do {
            // 使用 TradingAPIService 獲取即時股價
            let stockPrice = try await TradingAPIService.shared.fetchStockPriceAuto(symbol: stockSymbol)
            
            await MainActor.run {
                currentPrice = stockPrice.currentPrice
                priceLastUpdated = ISO8601DateFormatter().date(from: stockPrice.timestamp) ?? Date()
                priceError = nil
                isPriceLoading = false
                calculateEstimation()
            }
            
        } catch {
            await MainActor.run {
                currentPrice = 0.0
                if let tradingError = error as? TradingAPIError {
                    priceError = tradingError.localizedDescription
                } else {
                    priceError = "網路錯誤"
                }
                isPriceLoading = false
            }
        }
    }
    
    /// 計算預估購買資訊
    private func calculateEstimation() {
        guard let amount = Double(tradeAmount), amount > 0, currentPrice > 0 else {
            estimatedShares = 0.0
            estimatedCost = 0.0
            return
        }
        
        if tradeAction == "buy" {
            // 使用統一的手續費計算器
            let feeCalculator = FeeCalculator.shared
            let fees = feeCalculator.calculateTradingFees(amount: amount, action: .buy)
            let availableAmount = amount - fees.totalFees
            estimatedShares = availableAmount / currentPrice
            estimatedCost = amount // 包含手續費的總成本
        }
    }
    
    /// 執行交易並進行驗證
    private func executeTradeWithValidation() {
        // 驗證輸入
        guard let amount = Double(tradeAmount), amount > 0 else {
            showError("請輸入有效的金額")
            return
        }
        
        if tradeAction == "sell" {
            // 檢查持股是否足夠
            if let holding = portfolioManager.holdings.first(where: { $0.symbol == stockSymbol }) {
                if holding.shares < amount {
                    showError("持股不足，目前僅持有 \(String(format: "%.2f", holding.shares)) 股")
                    return
                }
            } else {
                showError("您目前沒有持有 \(stockSymbol) 股票")
                return
            }
        }
        
        // 使用 PortfolioSyncService 執行錦標賽交易
        Task {
            let success = await PortfolioSyncService.shared.executeTournamentTrade(
                tournamentId: nil as UUID?, // 可以根據當前錦標賽傳入 ID
                symbol: stockSymbol,
                stockName: selectedStockName.isEmpty ? getStockName(for: stockSymbol) : selectedStockName,
                action: tradeAction == "buy" ? TradingType.buy : TradingType.sell,
                shares: tradeAction == "buy" ? (amount / currentPrice) : amount,
                price: currentPrice
            )
            
            await MainActor.run {
                if success {
                    // 交易成功
                    if tradeAction == "buy" {
                        tradeSuccessMessage = "成功購買 \(String(format: "%.2f", amount / currentPrice)) 股 \(stockSymbol)"
                    } else {
                        tradeSuccessMessage = "成功賣出 \(String(format: "%.2f", amount)) 股 \(stockSymbol)"
                    }
                    showTradeSuccess = true
                    // 清空輸入
                    stockSymbol = ""
                    tradeAmount = ""
                    selectedStockName = ""
                } else {
                    showError("交易失敗，請檢查餘額或持股是否足夠")
                }
            }
        }
    }
    
    /// 獲取股票名稱（輔助方法）
    private func getStockName(for symbol: String) -> String {
        let stockNames: [String: String] = [
            "2330": "台積電",
            "2317": "鴻海",
            "2454": "聯發科",
            "2881": "富邦金",
            "2882": "國泰金",
            "2886": "兆豐金",
            "2891": "中信金",
            "6505": "台塑化",
            "3008": "大立光",
            "2308": "台達電",
            "0050": "台灣50",
            "2002": "中興",
            "AAPL": "Apple Inc",
            "TSLA": "Tesla Inc",
            "NVDA": "NVIDIA Corp",
            "GOOGL": "Alphabet Inc",
            "MSFT": "Microsoft Corp"
        ]
        return stockNames[symbol] ?? symbol
    }
    
    /// 顯示錯誤訊息
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    /// 顯示清空投資組合確認對話框
    private func clearPortfolioWithConfirmation() {
        showClearPortfolioConfirmation = true
    }
}

#Preview {
    @State var stockSymbol = ""
    @State var tradeAmount = ""
    @State var tradeAction = "buy"
    @State var showTradeSuccess = false
    @State var tradeSuccessMessage = ""
    
    InvestmentPanelView(
        portfolioManager: ChatPortfolioManager.shared,
        stockSymbol: $stockSymbol,
        tradeAmount: $tradeAmount,
        tradeAction: $tradeAction,
        showTradeSuccess: $showTradeSuccess,
        tradeSuccessMessage: $tradeSuccessMessage,
        onExecuteTrade: { },
        onClose: { }
    )
}

// MARK: - Extensions

// MARK: - 子視圖組件

struct TradeInfoView: View {
    let tradeAction: String
    let tradeAmount: String
    let stockSymbol: String
    let currentPrice: Double
    let estimatedShares: Double
    let estimatedCost: Double
    let portfolioManager: ChatPortfolioManager
    
    var body: some View {
        Group {
            // 預估購買資訊（僅在買入時顯示）
            if tradeAction == "buy" && !tradeAmount.isEmpty && currentPrice > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("預估可購得：")
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                        Text("\(String(format: "%.2f", estimatedShares)) 股")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .adaptiveTextColor()
                        Spacer()
                    }
                    
                    HStack {
                        Text("含手續費約：")
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                        Text("$\(String(format: "%.2f", estimatedCost))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color.surfaceSecondary)
                .cornerRadius(8)
            }
            
            // 賣出時顯示持股資訊
            if tradeAction == "sell" && !stockSymbol.isEmpty {
                if let holding = portfolioManager.holdings.first(where: { $0.symbol == stockSymbol }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("目前持股：")
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                        Text("\(String(format: "%.2f", holding.shares)) 股")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .adaptiveTextColor()
                        Spacer()
                    }
                    .padding(.top, 4)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("目前無持股")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - 統計卡片組件
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.surfaceSecondary)
        .cornerRadius(DesignTokens.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 增強持股卡片組件
struct EnhancedHoldingCard: View {
    let holding: PortfolioHolding
    let portfolioManager: ChatPortfolioManager
    
    private var percentage: Double {
        let total = portfolioManager.totalPortfolioValue
        guard total > 0 else { return 0 }
        return (holding.totalValue / total) * 100
    }
    
    private var dailyChange: (amount: Double, percent: Double) {
        portfolioManager.dailyChanges[holding.symbol] ?? (amount: 0, percent: 0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 標題區域
            HStack(spacing: 8) {
                Circle()
                    .fill(StockColorPalette.colorForStock(symbol: holding.symbol))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(holding.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(StockColorPalette.colorForStock(symbol: holding.symbol))
            }
            
            // 價值資訊區域
            VStack(spacing: 8) {
                HStack {
                    Text("市值")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.0f", holding.totalValue))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("持股")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f 股", holding.shares))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 損益區域
                HStack {
                    Text("損益")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        let gainLoss = holding.unrealizedGainLoss
                        let isProfit = gainLoss >= 0
                        
                        Image(systemName: isProfit ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                            .foregroundColor(isProfit ? DesignTokens.priceUpColor : DesignTokens.priceDownColor)
                        
                        Text(String(format: "%+.0f", gainLoss))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isProfit ? DesignTokens.priceUpColor : DesignTokens.priceDownColor)
                    }
                }
            }
            
            // 價格變動指示器
            if dailyChange.amount != 0 {
                HStack {
                    Text("今日")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        let isUp = dailyChange.percent >= 0
                        
                        Image(systemName: isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 6))
                            .foregroundColor(isUp ? DesignTokens.priceUpColor : DesignTokens.priceDownColor)
                        
                        Text(String(format: "%+.2f%%", dailyChange.percent))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(isUp ? DesignTokens.priceUpColor : DesignTokens.priceDownColor)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color.surfacePrimary)
        .cornerRadius(DesignTokens.cornerRadiusLG)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                .stroke(
                    StockColorPalette.colorForStock(symbol: holding.symbol).opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

