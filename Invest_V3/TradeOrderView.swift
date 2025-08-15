import SwiftUI

struct TradeOrderView: View {
    let stock: TradingStock
    let action: TradeAction
    
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var portfolioService = PortfolioService.shared
    @StateObject private var tournamentStateManager = TournamentStateManager.shared
    @State private var quantity = ""
    @State private var price = ""
    @State private var orderType: OrderType = .market
    @State private var showConfirmation = false
    @State private var isProcessing = false
    @State private var availableQuantity: Int = 0
    @State private var isLoadingHolding = false
    @State private var sellSuggestion: SellSuggestion?
    @State private var showSellSuggestion = false
    @State private var errorAlert: ErrorAlert?
    @State private var showErrorAlert = false
    @Environment(\.dismiss) private var dismiss
    
    enum OrderType: String, CaseIterable {
        case market = "市價"
        case limit = "限價"
    }
    
    private var isFormValid: Bool {
        guard let qty = Int(quantity), qty > 0 else { return false }
        
        if orderType == .limit {
            guard let priceValue = Double(price), priceValue > 0 else { return false }
        }
        
        // 對於賣出，檢查持股是否足夠
        if action == .sell && qty > availableQuantity {
            return false
        }
        
        return true
    }
    
    private var estimatedTotal: Double {
        guard let qty = Int(quantity) else { return 0 }
        
        let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
        let totalAmount = Double(qty) * stockPrice
        
        switch action {
        case .buy:
            let fee = TradingConstants.calculateBuyFee(amount: totalAmount)
            return totalAmount + fee
        case .sell:
            let (fee, tax) = TradingConstants.calculateSellFee(amount: totalAmount)
            return totalAmount - fee - tax
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 標題區域
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 股票資訊
                        stockInfoSection
                        
                        // 交易表單
                        tradingFormSection
                        
                        // 費用明細
                        feeBreakdownSection
                        
                        // 確認按鈕
                        confirmButton
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .alert("確認交易", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確認") {
                executeTradeOrder()
            }
        } message: {
            Text(confirmationMessage)
        }
        .onAppear {
            loadHoldingQuantity()
        }
        .alert("交易錯誤", isPresented: $showErrorAlert, presenting: errorAlert) { alert in
            Button("確定", role: .cancel) { }
            
            // 根據錯誤類型提供不同的操作選項
            if let primaryAction = alert.primaryAction {
                Button(primaryAction.title) {
                    primaryAction.action()
                }
            }
            
            if let secondaryAction = alert.secondaryAction {
                Button(secondaryAction.title) {
                    secondaryAction.action()
                }
            }
        } message: { alert in
            VStack(alignment: .leading, spacing: 8) {
                Text(alert.message)
                
                if !alert.suggestions.isEmpty {
                    Text("建議解決方式:")
                        .fontWeight(.semibold)
                    
                    ForEach(alert.suggestions, id: \.self) { suggestion in
                        Text("• \(suggestion)")
                    }
                }
            }
        }
    }
    
    // MARK: - 標題區域
    private var headerSection: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            .foregroundColor(Color.brandGreen)
            
            Spacer()
            
            Text("\(action.title) \(stock.symbol)")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            // 平衡按鈕
            Color.clear
                .frame(width: 44)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - 股票資訊區域
    private var stockInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(stock.symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("市價")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(stock.price))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(action.color)
                }
            }
            
            // 可用餘額 (買入) 或持股 (賣出)
            if let user = tradingService.currentUser {
                HStack {
                    if action == .buy {
                        Text("可用餘額")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(TradingService.shared.formatCurrency(user.cashBalance))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("持有股數")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if isLoadingHolding {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("載入中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("\(availableQuantity)股")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(availableQuantity > 0 ? .primary : .secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 交易表單區域
    private var tradingFormSection: some View {
        VStack(spacing: 20) {
            // 訂單類型選擇
            VStack(alignment: .leading, spacing: 8) {
                Text("訂單類型")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Picker("訂單類型", selection: $orderType) {
                    ForEach(OrderType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 股數輸入
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("股數")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // 賣出時顯示智能建議按鈕和快速填入按鈕
                    if action == .sell && availableQuantity > 0 {
                        HStack(spacing: 8) {
                            Button("全部賣出") {
                                quantity = String(availableQuantity)
                                checkSellViability()
                            }
                            .font(.caption)
                            .foregroundColor(.brandBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brandBlue.opacity(0.1))
                            .cornerRadius(6)
                            
                            Button("智能建議") {
                                provideSellSuggestion()
                            }
                            .font(.caption)
                            .foregroundColor(.brandGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brandGreen.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                
                HStack {
                    TextField("請輸入股數", text: $quantity)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onChange(of: quantity) { _ in
                            // 當股數改變時，即時檢查賣出可行性
                            if action == .sell {
                                checkSellViability()
                            }
                        }
                    
                    Text("股")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 賣出警告或建議
                if action == .sell, let qty = Int(quantity), qty > 0 {
                    let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
                    let suggestion = TradingConstants.getSellSuggestion(
                        requestedQuantity: qty,
                        availableQuantity: availableQuantity,
                        price: stockPrice
                    )
                    
                    sellSuggestionView(suggestion)
                }
            }
            
            // 價格輸入 (限價單)
            if orderType == .limit {
                VStack(alignment: .leading, spacing: 8) {
                    Text("限價")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("請輸入價格", text: $price)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        Text("TWD")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 費用明細區域
    private var feeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("費用明細")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let qty = Int(quantity), qty > 0 {
                let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
                let totalAmount = Double(qty) * stockPrice
                
                VStack(spacing: 8) {
                    // 交易金額
                    HStack {
                        Text("交易金額")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(TradingService.shared.formatCurrency(totalAmount))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    // 手續費
                    let fee = TradingConstants.calculateBuyFee(amount: totalAmount)
                    HStack {
                        Text("手續費 (0.1425%)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(TradingService.shared.formatCurrency(fee))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    // 證券交易稅 (僅賣出)
                    if action == .sell {
                        let tax = totalAmount * TradingConstants.taxRate
                        HStack {
                            Text("證券交易稅 (0.3%)")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(TradingService.shared.formatCurrency(tax))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        
                        // 顯示收益率提示
                        let netProceeds = TradingConstants.calculateSellProceedsAfterFees(amount: totalAmount)
                        let feeRatio = ((fee + tax) / totalAmount) * 100
                        
                        HStack {
                            Text("總費用佔比")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(String(format: "%.2f%%", feeRatio))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 總計
                    HStack {
                        Text(action == .buy ? "實付金額" : "實收金額")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(TradingService.shared.formatCurrency(estimatedTotal))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(action.color)
                    }
                }
            } else {
                Text("請輸入有效的股數")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 確認按鈕
    private var confirmButton: some View {
        Button(action: {
            showConfirmation = true
        }) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("確認\(action.title)")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isFormValid && !isProcessing {
                        action.color
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isProcessing)
        .padding(.horizontal)
    }
    
    // MARK: - 計算屬性
    private var confirmationMessage: String {
        guard let qty = Int(quantity) else { return "" }
        
        let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
        let orderTypeText = orderType.rawValue
        
        return """
        您即將\(action.title) \(stock.symbol)
        
        股數: \(qty)股
        價格: \(orderTypeText) \(TradingService.shared.formatCurrency(stockPrice))
        預估總額: \(TradingService.shared.formatCurrency(estimatedTotal))
        
        請確認交易資訊無誤後執行。
        """
    }
    
    // MARK: - 輔助方法
    
    /// 載入持股數量
    private func loadHoldingQuantity() {
        // 只有賣出時才需要載入持股數量
        guard action == .sell else { return }
        
        // 需要取得當前用戶ID
        guard let currentUser = tradingService.currentUser,
              let userId = UUID(uuidString: currentUser.id) else { return }
        
        isLoadingHolding = true
        
        Task {
            do {
                let quantity = try await portfolioService.getStockHolding(
                    userId: userId,
                    symbol: stock.symbol
                )
                
                await MainActor.run {
                    self.availableQuantity = quantity
                    self.isLoadingHolding = false
                }
            } catch {
                await MainActor.run {
                    self.availableQuantity = 0
                    self.isLoadingHolding = false
                    print("載入持股失敗: \(error)")
                }
            }
        }
    }
    
    /// 檢查賣出可行性
    private func checkSellViability() {
        guard let qty = Int(quantity), qty > 0 else { return }
        
        let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
        sellSuggestion = TradingConstants.getSellSuggestion(
            requestedQuantity: qty,
            availableQuantity: availableQuantity,
            price: stockPrice
        )
    }
    
    /// 提供賣出建議
    private func provideSellSuggestion() {
        let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
        let maxResult = TradingConstants.calculateMaxSellableQuantity(
            availableQuantity: availableQuantity,
            price: stockPrice
        )
        
        switch maxResult {
        case .maxQuantity(let suggestedQuantity, _):
            quantity = String(suggestedQuantity)
            checkSellViability()
        case .noStock:
            // 沒有持股
            break
        case .belowMinimum:
            // 建議賣出全部
            quantity = String(availableQuantity)
            checkSellViability()
        }
    }
    
    /// 賣出建議視圖
    @ViewBuilder
    private func sellSuggestionView(_ suggestion: SellSuggestion) -> some View {
        switch suggestion {
        case .approved(_, let netProceeds, let message):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text("實收: \(TradingService.shared.formatCurrency(netProceeds))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
        case .suggestAlternative(_, _, let suggestedQuantity, let suggestedProceeds, let message):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                
                Button("改為賣出 \(suggestedQuantity) 股") {
                    quantity = String(suggestedQuantity)
                }
                .font(.caption)
                .foregroundColor(.brandGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brandGreen.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
        case .notRecommended(_, let netProceeds, let message):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Text("實收: \(TradingService.shared.formatCurrency(netProceeds))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
        case .rejected(_, let reason, let netProceeds):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
                if netProceeds > 0 {
                    Text("實收: \(TradingService.shared.formatCurrency(netProceeds))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
        case .insufficientStock(_, let available, let message):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 執行交易
    private func executeTradeOrder() {
        guard let qty = Int(quantity) else { return }
        
        let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
        
        isProcessing = true
        
        Task {
            do {
                // 獲取當前錦標賽上下文
                let tournamentId = tournamentStateManager.getCurrentTournamentId()
                let tournamentName = tournamentStateManager.getCurrentTournamentDisplayName()
                
                switch action {
                case .buy:
                    try await tradingService.buyStock(
                        symbol: stock.symbol,
                        quantity: qty,
                        price: stockPrice
                    )
                case .sell:
                    try await tradingService.sellStock(
                        symbol: stock.symbol,
                        quantity: qty,
                        price: stockPrice
                    )
                }
                
                await MainActor.run {
                    self.isProcessing = false
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.handleTradingError(error)
                }
            }
        }
    }
    
    /// 處理交易錯誤
    private func handleTradingError(_ error: Error) {
        print("交易失敗: \(error)")
        
        if let tradingError = error as? TradingError {
            let alert = createErrorAlert(from: tradingError)
            self.errorAlert = alert
            self.showErrorAlert = true
        } else {
            // 處理其他類型的錯誤
            self.errorAlert = ErrorAlert(
                message: error.localizedDescription,
                suggestions: ["稍後重試", "檢查網路連接"]
            )
            self.showErrorAlert = true
        }
    }
    
    /// 根據 TradingError 創建錯誤提示
    private func createErrorAlert(from error: TradingError) -> ErrorAlert {
        switch error {
        case .insufficientHoldings:
            return ErrorAlert(
                message: error.userFriendlyMessage,
                suggestions: error.suggestions,
                primaryAction: ErrorAlert.Action(title: "檢查持股") {
                    // 重新載入持股數量
                    self.loadHoldingQuantity()
                }
            )
            
        case .minimumAmountNotMet:
            return ErrorAlert(
                message: error.userFriendlyMessage,
                suggestions: error.suggestions,
                primaryAction: ErrorAlert.Action(title: "智能建議") {
                    // 使用智能建議功能
                    self.provideSellSuggestion()
                }
            )
            
        case .invalidQuantity:
            return ErrorAlert(
                message: error.userFriendlyMessage,
                suggestions: error.suggestions,
                primaryAction: ErrorAlert.Action(title: "清空重填") {
                    // 清空股數重新填寫
                    self.quantity = ""
                }
            )
            
        case .sellValidationError:
            return ErrorAlert(
                message: error.userFriendlyMessage,
                suggestions: error.suggestions,
                primaryAction: ErrorAlert.Action(title: "智能建議") {
                    self.provideSellSuggestion()
                },
                secondaryAction: ErrorAlert.Action(title: "重新填寫") {
                    self.quantity = ""
                    self.price = ""
                }
            )
            
        default:
            return ErrorAlert(
                message: error.userFriendlyMessage,
                suggestions: error.suggestions
            )
        }
    }
}

// MARK: - 錯誤提示模型
struct ErrorAlert {
    let message: String
    let suggestions: [String]
    let primaryAction: Action?
    let secondaryAction: Action?
    
    init(message: String, suggestions: [String], primaryAction: Action? = nil, secondaryAction: Action? = nil) {
        self.message = message
        self.suggestions = suggestions
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    struct Action {
        let title: String
        let action: () -> Void
    }
}

#Preview {
    TradeOrderView(
        stock: TradingConstants.taiwanStocks[0],
        action: .buy
    )
}