import Foundation

class StockService: ObservableObject {
    static let shared = StockService()
    
    private let baseURL = "https://api.tej.com.tw/v1"
    private let apiKey = "l2PG310rhEHbRkLV9MKklcjyqneDV8"
    
    private init() {}
    
    // MARK: - 獲取單一股票報價
    func fetchStockQuote(symbol: String) async throws -> Stock {
        // 使用 TEJ API 獲取股票報價
        let url = URL(string: "\(baseURL)/quote/\(symbol)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TEJQuoteResponse.self, from: data)
        
        return try convertToStock(from: response)
    }
    
    // MARK: - 批量獲取台股報價
    func fetchTaiwanStocks() async throws -> [Stock] {
        var stocks: [Stock] = []
        
        // 使用 TEJ API 批量獲取台股報價
        let url = URL(string: "\(baseURL)/stocks/quotes")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        let symbols = TaiwanStocks.popularStocks.map { $0.replacingOccurrences(of: ".TW", with: "") }
        let requestBody = TEJBatchRequest(symbols: symbols)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TEJBatchResponse.self, from: data)
            
            for quoteData in response.data {
                let stock = try convertToStock(from: quoteData)
                stocks.append(stock)
            }
        } catch {
            // 如果 API 請求失敗，使用模擬資料
            print("TEJ API 請求失敗，使用模擬資料: \(error)")
            for symbol in TaiwanStocks.popularStocks {
                let stock = generateMockStock(symbol: symbol)
                stocks.append(stock)
            }
        }
        
        return stocks
    }
    
    // MARK: - 獲取股票歷史資料 (用於圖表)
    func fetchStockHistory(symbol: String, interval: String = "1d") async throws -> [StockPrice] {
        let url = URL(string: "\(baseURL)/history/\(symbol.replacingOccurrences(of: ".TW", with: ""))")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TEJHistoryResponse.self, from: data)
            
            return response.data.map { historyData in
                StockPrice(
                    timestamp: historyData.date,
                    price: historyData.close
                )
            }
        } catch {
            // 如果 API 請求失敗，使用模擬資料
            print("TEJ API 歷史資料請求失敗，使用模擬資料: \(error)")
            return generateMockHistoryData(symbol: symbol)
        }
    }
    
    // MARK: - 搜尋股票
    func searchStocks(query: String) async throws -> [Stock] {
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        let searchRequest = TEJSearchRequest(query: query)
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TEJSearchResponse.self, from: data)
            
            var results: [Stock] = []
            for stockInfo in response.data {
                let stock = Stock(
                    symbol: stockInfo.symbol + ".TW",
                    name: stockInfo.name,
                    price: stockInfo.price ?? 0.0,
                    change: stockInfo.change ?? 0.0,
                    changePercent: stockInfo.changePercent ?? 0.0,
                    volume: stockInfo.volume ?? 0,
                    lastUpdated: Date()
                )
                results.append(stock)
            }
            
            return results
        } catch {
            // 如果 API 請求失敗，使用模擬搜尋
            print("TEJ API 搜尋請求失敗，使用模擬資料: \(error)")
            return try await mockSearchStocks(query: query)
        }
    }
    
    // 模擬搜尋功能（備用）
    private func mockSearchStocks(query: String) async throws -> [Stock] {
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
    
    // 將 TEJ API 回應轉換為我們的 Stock 模型
    private func convertToStock(from tejData: TEJQuoteData) throws -> Stock {
        let symbol = tejData.symbol + ".TW"
        let name = TaiwanStocks.stockNames[symbol] ?? tejData.name ?? tejData.symbol
        
        return Stock(
            symbol: symbol,
            name: name,
            price: tejData.price,
            change: tejData.change,
            changePercent: tejData.changePercent,
            volume: tejData.volume,
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
    case tejApiError(String)
    
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
        case .tejApiError(let message):
            return "TEJ API 錯誤: \(message)"
        }
    }
}

// MARK: - TEJ API 回應模型
struct TEJQuoteResponse: Codable {
    let data: TEJQuoteData
    let message: String?
    let status: String
}

struct TEJQuoteData: Codable {
    let symbol: String
    let name: String?
    let price: Double
    let change: Double
    let changePercent: Double
    let volume: Int64
    let date: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case name = "name"
        case price = "price"
        case change = "change"
        case changePercent = "change_percent"
        case volume = "volume"
        case date = "date"
    }
}

struct TEJBatchRequest: Codable {
    let symbols: [String]
}

struct TEJBatchResponse: Codable {
    let data: [TEJQuoteData]
    let message: String?
    let status: String
}

struct TEJSearchRequest: Codable {
    let query: String
}

struct TEJSearchResponse: Codable {
    let data: [TEJSearchData]
    let message: String?
    let status: String
}

struct TEJSearchData: Codable {
    let symbol: String
    let name: String
    let price: Double?
    let change: Double?
    let changePercent: Double?
    let volume: Int64?
    
    enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case name = "name"
        case price = "price"
        case change = "change"
        case changePercent = "change_percent"
        case volume = "volume"
    }
}

struct TEJHistoryResponse: Codable {
    let data: [TEJHistoryData]
    let message: String?
    let status: String
}

struct TEJHistoryData: Codable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int64
    
    enum CodingKeys: String, CodingKey {
        case date = "date"
        case open = "open"
        case high = "high"
        case low = "low"
        case close = "close"
        case volume = "volume"
    }
}

// MARK: - 股價歷史資料點
struct StockPrice: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let price: Double
} 