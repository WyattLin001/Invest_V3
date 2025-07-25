import SwiftUI

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
    
    let onExecuteTrade: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 投資組合標題
                VStack(spacing: 8) {
                    Text("投資組合")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    
                    Divider()
                        .background(Color(.separator))
                }
                .padding(.top, 20)
                
                // 投資組合圓形圖表
                VStack(spacing: 16) {
                    ZStack {
                        // 背景圓圈
                        Circle()
                            .stroke(Color(.systemGray6), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        // 動態投資比例圓圈
                        if !portfolioManager.holdings.isEmpty {
                            ForEach(Array(portfolioManager.portfolioPercentages.enumerated()), id: \.offset) { index, item in
                                let (symbol, percentage, color) = item
                                let percentagePrefix = portfolioManager.portfolioPercentages.prefix(index)
                                let startAngle = percentagePrefix.reduce(0.0) { result, item in
                                    return result + item.1
                                }
                                let endAngle = startAngle + percentage
                                
                                Circle()
                                    .trim(from: startAngle, to: endAngle)
                                    .stroke(color, lineWidth: 8)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        
                        // 中心總金額
                        VStack(spacing: 2) {
                            Text("總投資")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(Int(portfolioManager.totalPortfolioValue))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // 投資組合明細
                    if portfolioManager.holdings.isEmpty {
                        Text("尚未進行任何投資")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(portfolioManager.holdings, id: \.id) { holding in
                                let value = holding.totalValue
                                let percentage = portfolioManager.portfolioPercentages.first { $0.0 == holding.symbol }?.1 ?? 0
                                
                                HStack {
                                    Text(holding.symbol)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("$\(Int(value))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("\(Int(percentage * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
                
                Spacer()
                
                // 交易區域
                VStack(spacing: 16) {
                    Text("進行交易")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
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
                            Task {
                                await fetchCurrentPrice()
                            }
                        }
                        .onChange(of: stockSymbol) { _ in
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("投資面板")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("關閉") {
                    onClose()
                }
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
            // 手續費假設為 0.1425%（台股一般手續費）
            let feeRate = 0.001425
            let fee = amount * feeRate
            let availableAmount = amount - fee
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
        
        // 執行原始的交易邏輯
        onExecuteTrade()
    }
    
    /// 顯示錯誤訊息
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
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
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", estimatedShares)) 股")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    HStack {
                        Text("含手續費約：")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                .background(Color(.systemGray6))
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
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", holding.shares)) 股")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
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

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}