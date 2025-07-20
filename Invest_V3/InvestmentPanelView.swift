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
                    
                    // 股票代號輸入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("股票代號")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("例如：AAPL", text: $stockSymbol)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
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
                    }
                    
                    // 執行交易按鈕
                    Button(action: onExecuteTrade) {
                        Text("\(tradeAction == "buy" ? "買入" : "賣出") \(stockSymbol.isEmpty ? "股票" : stockSymbol)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(stockSymbol.isEmpty || tradeAmount.isEmpty ? Color.gray : (tradeAction == "buy" ? Color.green : Color.red))
                            )
                    }
                    .disabled(stockSymbol.isEmpty || tradeAmount.isEmpty)
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