import SwiftUI

/// 台股搜尋組件演示頁面
/// 展示 StockSearchTextField 的功能和用法
struct StockSearchDemo: View {
    @State private var selectedStock = ""
    @State private var stockInfo: CompleteTaiwanStockItem?
    @State private var showInfo = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 標題區域
                VStack(spacing: 8) {
                    Text("🔍 台股智能搜尋")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("體驗實時搜尋台灣股票的功能")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // 搜尋組件展示
                VStack(alignment: .leading, spacing: 16) {
                    Text("搜尋股票")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    StockSearchTextField(
                        text: $selectedStock,
                        placeholder: "例如：2330、台積電、0050、元大"
                    ) { stock in
                        stockInfo = stock
                        showInfo = true
                    }
                    
                    // 功能說明
                    VStack(alignment: .leading, spacing: 8) {
                        Label("即時搜尋台股", systemImage: "magnifyingglass")
                        Label("防抖動優化", systemImage: "timer")
                        Label("鍵盤導航支持", systemImage: "keyboard")
                        Label("無障礙功能", systemImage: "accessibility")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                // 選擇結果顯示
                if let stock = stockInfo {
                    selectedStockCard(stock: stock)
                }
                
                Spacer()
                
                // 使用提示
                VStack(spacing: 8) {
                    Text("💡 使用提示")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 輸入股票代號：2330、0050")
                        Text("• 輸入公司名稱：台積電、元大")
                        Text("• 使用 ↑↓ 鍵選擇建議")
                        Text("• 按 Enter 鍵確認選擇")
                        Text("• 按 ESC 鍵關閉建議")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("搜尋演示")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("股票資訊", isPresented: $showInfo) {
            Button("確定") { showInfo = false }
        } message: {
            if let stock = stockInfo {
                Text("已選擇：\(stock.code) \(stock.name)\n市場：\(stock.market)\n產業：\(stock.industry)")
            }
        }
    }
    
    // MARK: - 選擇結果卡片
    private func selectedStockCard(stock: CompleteTaiwanStockItem) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("選擇的股票")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("清除") {
                    selectedStock = ""
                    stockInfo = nil
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.code)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(stock.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(stock.market)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(stock.market == "上市" ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(stock.market == "上市" ? .blue : .orange)
                        .cornerRadius(4)
                    
                    Text(stock.industry)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 2)
        )
    }
}

#Preview {
    StockSearchDemo()
}