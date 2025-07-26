import SwiftUI

// MARK: - 顏色系統測試視圖
struct ColorSystemTestView: View {
    @StateObject private var colorProvider = HybridColorProvider.shared
    @State private var testSymbols = ["2330", "0050", "2454", "AAPL", "TSLA", "GOOGL", "MSFT", "NVDA"]
    @State private var newSymbol = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 測試圓餅圖
                    testPieChartSection
                    
                    // 預定義顏色測試
                    predefinedColorsSection
                    
                    // 動態顏色測試
                    dynamicColorsSection
                    
                    // 顏色管理
                    colorManagementSection
                }
                .padding()
            }
            .navigationTitle("顏色系統測試")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var testPieChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("圓餅圖測試")
                .font(.headline)
                .fontWeight(.bold)
            
            let testData = [
                PieChartData(category: "台灣50", value: 45.5, color: StockColorPalette.colorForStock(symbol: "0050")),
                PieChartData(category: "台積電", value: 30.2, color: StockColorPalette.colorForStock(symbol: "2330")),
                PieChartData(category: "聯發科", value: 15.8, color: StockColorPalette.colorForStock(symbol: "2454")),
                PieChartData(category: "AAPL", value: 8.5, color: StockColorPalette.colorForStock(symbol: "AAPL"))
            ]
            
            DynamicPieChart(data: testData, size: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var predefinedColorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("預定義股票顏色")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(["2330", "0050", "2454", "2317", "2881"], id: \.self) { symbol in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(StockColorPalette.colorForStock(symbol: symbol))
                            .frame(width: 20, height: 20)
                        
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var dynamicColorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("動態生成顏色測試")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(testSymbols.filter { !ColorConfiguration.predefinedStocks.contains($0) }, id: \.self) { symbol in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(StockColorPalette.colorForStock(symbol: symbol))
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(symbol)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("動態生成")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
            
            // 添加新股票測試
            HStack {
                TextField("輸入股票代號", text: $newSymbol)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.allCharacters)
                
                Button("測試") {
                    if !newSymbol.isEmpty && !testSymbols.contains(newSymbol) {
                        testSymbols.append(newSymbol)
                        newSymbol = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newSymbol.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var colorManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("顏色管理")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Button("清除動態顏色緩存") {
                    StockColorPalette.clearDynamicColors()
                    // 強制重新整理
                    testSymbols = testSymbols
                }
                .buttonStyle(.bordered)
                
                Button("重新載入所有顏色") {
                    // 觸發重新計算
                    colorProvider.objectWillChange.send()
                }
                .buttonStyle(.bordered)
            }
            
            Text("總顏色數: \(StockColorPalette.allStockColors.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ColorSystemTestView()
}