import SwiftUI

struct TradeOrderView: View {
    let stock: TradingStock
    let action: StockDetailView.TradeAction
    
    @ObservedObject private var tradingService = TradingService.shared
    @State private var quantity = ""
    @State private var price = ""
    @State private var orderType: OrderType = .market
    @State private var showConfirmation = false
    @State private var isProcessing = false
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
                        
                        // 這裡應該從投資組合獲取實際持股數
                        Text("1,000股")
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
                Text("股數")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    TextField("請輸入股數", text: $quantity)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    Text("股")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
    
    // MARK: - 執行交易
    private func executeTradeOrder() {
        guard let qty = Int(quantity) else { return }
        
        let stockPrice = orderType == .market ? stock.price : (Double(price) ?? stock.price)
        
        isProcessing = true
        
        Task {
            do {
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
                    // 這裡可以顯示錯誤訊息
                    print("交易失敗: \(error)")
                }
            }
        }
    }
}

#Preview {
    TradeOrderView(
        stock: TradingConstants.taiwanStocks[0],
        action: .buy
    )
}