import Foundation

class StockService: ObservableObject {
    static let shared = StockService()
    
    private let baseURL = "https://www.alphavantage.co/query"
    private let apiKey = "demo" // 實際使用時需要申請 API Key
    
    private init() {}
    
    // MARK: - 獲取單一股票報價
    func fetchStockQuote(symbol: String) async throws -> Stock {
        let url = URL(string: "\(baseURL)?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AlphaVantageResponse.self, from: data)
        
        return try convertToStock(from: response.globalQuote)
    }
    
    // MARK: - 批量獲取台股報價 (5檔熱門股票)
    func fetchTaiwanStocks() async throws -> [Stock] {
        var stocks: [Stock] = []
        
        // 由於 Alpha Vantage 免費版有速率限制，這裡使用模擬資料
        // 實際應用中應該使用台股專用 API 或付費版 Alpha Vantage
        
        for symbol in TaiwanStocks.popularStocks {
            let stock = generateMockStock(symbol: symbol)
            stocks.append(stock)
            
            // 避免 API 速率限制
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒延遲
        }
        
        return stocks
    }
    
    // MARK: - 獲取股票歷史資料 (用於圖表)
    func fetchStockHistory(symbol: String, interval: String = "5min") async throws -> [StockPrice] {
        // 模擬歷史資料，實際應該調用 Alpha Vantage TIME_SERIES API
        return generateMockHistoryData(symbol: symbol)
    }
    
    // MARK: - 搜尋股票
    func searchStocks(query: String) async throws -> [Stock] {
        // 模擬搜尋結果
        let allSymbols = Array(TaiwanStocks.stockNames.keys)
        let filteredSymbols = allSymbols.filter { symbol in
            let name = TaiwanStocks.stockNames[symbol] ?? ""
            return symbol.contains(query) || name.contains(query)
        }
        
        var results: [Stock] = []
        for symbol in filteredSymbols {
            let stock = generateMockStock(symbol: symbol)
            results.append(stock)
        }
        
        return results
    }
    
    // MARK: - 私有方法
    
    // 將 AlphaVantageResponse 轉換為我們的 Stock 模型
    private func convertToStock(from quote: GlobalQuote) throws -> Stock {
        guard let price = Double(quote.price),
              let change = Double(quote.change),
              let changePercent = Double(quote.changePercent.replacingOccurrences(of: "%", with: "")),
              let volume = Int64(quote.volume)
        else {
            throw StockServiceError.invalidData
        }
        
        let name = TaiwanStocks.stockNames[quote.symbol] ?? quote.symbol
        
        return Stock(
            symbol: quote.symbol,
            name: name,
            price: price,
            change: change,
            changePercent: changePercent,
            volume: volume,
            lastUpdated: Date()
        )
    }
    
    // MARK: - 模擬資料生成 (開發階段使用)
    
    private func generateMockStock(symbol: String) -> Stock {
        let name = TaiwanStocks.stockNames[symbol] ?? symbol
        let basePrice: Double
        
        // 根據股票設定基準價格
        switch symbol {
        case "2330.TW": basePrice = 580.0  // 台積電
        case "2317.TW": basePrice = 105.0  // 鴻海
        case "2454.TW": basePrice = 1200.0 // 聯發科
        case "2881.TW": basePrice = 75.0   // 富邦金
        case "6505.TW": basePrice = 95.0   // 台塑化
        default: basePrice = 100.0
        }
        
        // 模擬價格波動 (-3% 到 +3%)
        let changePercent = Double.random(in: -3.0...3.0)
        let change = basePrice * (changePercent / 100)
        let currentPrice = basePrice + change
        
        return Stock(
            symbol: symbol,
            name: name,
            price: currentPrice,
            change: change,
            changePercent: changePercent,
            volume: Int64.random(in: 1000000...50000000),
            lastUpdated: Date()
        )
    }
    
    private func generateMockHistoryData(symbol: String) -> [StockPrice] {
        var prices: [StockPrice] = []
        let basePrice = 100.0
        var currentPrice = basePrice
        
        // 生成過去24小時的5分鐘K線資料
        for i in 0..<288 { // 24 * 60 / 5 = 288個5分鐘區間
            let timestamp = Date().addingTimeInterval(-Double(i * 5 * 60))
            
            // 模擬價格隨機波動
            let change = Double.random(in: -0.5...0.5)
            currentPrice += change
            
            prices.append(StockPrice(
                timestamp: timestamp,
                price: currentPrice
            ))
        }
        
        return prices.reversed()
    }
}

// MARK: - 錯誤類型
enum StockServiceError: Error, LocalizedError {
    case invalidURL
    case invalidData
    case apiKeyMissing
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .invalidData:
            return "無效的資料格式"
        case .apiKeyMissing:
            return "缺少 API Key"
        case .rateLimitExceeded:
            return "API 請求頻率超限"
        }
    }
}

// 移除重複定義，使用 Stock.swift 中的定義

// MARK: - 股價歷史資料點
struct StockPrice: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let price: Double
} 