import Foundation
import SwiftUI

/// 交易服務 - 連接 Flask API 後端
/// 負責與 Flask 服務器通訊，處理股價查詢和交易執行
@MainActor
class TradingAPIService: ObservableObject {
    static let shared = TradingAPIService()
    
    // Flask API 配置
    private let baseURL = "http://localhost:5001/api"  // 開發環境 
    // private let baseURL = "https://invest-v3-api.fly.dev/api"  // 生產環境
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        // 設置 JSON 編解碼策略
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        
        // 配置 URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
    }
    
    // MARK: - 股價 API
    
    /// 獲取即時股價
    /// - Parameter symbol: 股票代號
    /// - Returns: 股價資訊
    func fetchStockPrice(symbol: String) async throws -> TradingStockPrice {
        let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)")!
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TradingAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    throw TradingAPIError.stockNotFound
                }
                throw TradingAPIError.httpError(httpResponse.statusCode)
            }
            
            // 解析 Flask API 回應
            let flaskResponse = try decoder.decode(FlaskStockPriceResponse.self, from: data)
            
            let stockPrice = TradingStockPrice(
                symbol: flaskResponse.symbol,
                name: flaskResponse.name,
                currentPrice: flaskResponse.current_price,
                previousClose: flaskResponse.previous_close,
                change: flaskResponse.change,
                changePercent: flaskResponse.change_percent,
                timestamp: flaskResponse.timestamp,
                currency: flaskResponse.currency,
                isTaiwanStock: flaskResponse.is_taiwan_stock
            )
            
            print("✅ [TradingAPI] 獲取股價成功: \(symbol) - $\(stockPrice.currentPrice)")
            return stockPrice
            
        } catch {
            print("❌ [TradingAPI] Flask API 失敗: \(error)")
            // 如果 Flask API 失敗，回退到模擬數據
            return try await fetchStockPriceMock(symbol: symbol)
        }
    }
    
    /// 執行交易
    /// - Parameters:
    ///   - symbol: 股票代號
    ///   - action: 交易動作 (buy/sell)
    ///   - amount: 金額（買入）或股數（賣出）
    ///   - userId: 用戶 ID
    /// - Returns: 交易結果
    func executeTrade(symbol: String, action: String, amount: Double, userId: String) async throws -> TradeResult {
        let url = URL(string: "\(baseURL)/trade")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let tradeRequest = FlaskTradeRequest(
            user_id: userId,
            symbol: symbol,
            action: action,
            amount: amount,
            is_day_trading: false
        )
        
        do {
            request.httpBody = try encoder.encode(tradeRequest)
        } catch {
            throw TradingAPIError.decodingError("編碼交易請求失敗: \(error.localizedDescription)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // 嘗試解析錯誤訊息
            if let errorData = try? decoder.decode(FlaskErrorResponse.self, from: data) {
                throw TradingAPIError.networkError(errorData.error)
            }
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let flaskResponse = try decoder.decode(FlaskTradeResponse.self, from: data)
            
            let tradeResult = TradeResult(
                success: flaskResponse.success,
                transactionId: flaskResponse.transaction_id,
                symbol: flaskResponse.symbol,
                action: flaskResponse.action,
                shares: flaskResponse.shares,
                price: flaskResponse.price,
                totalAmount: flaskResponse.total_amount,
                executedAt: ISO8601DateFormatter().date(from: flaskResponse.executed_at) ?? Date(),
                message: flaskResponse.message
            )
            
            print("✅ [TradingAPI] 交易執行成功: \(action) \(symbol)")
            return tradeResult
            
        } catch {
            print("❌ [TradingAPI] 解析交易結果失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    /// 獲取投資組合
    /// - Parameter userId: 用戶 ID
    /// - Returns: 投資組合資訊
    func fetchPortfolio(userId: String) async throws -> FlaskPortfolioResponse {
        let url = URL(string: "\(baseURL)/portfolio?user_id=\(userId)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let portfolio = try decoder.decode(FlaskPortfolioResponse.self, from: data)
            print("✅ [TradingAPI] 獲取投資組合成功: 總值 $\(portfolio.total_value)")
            return portfolio
        } catch {
            print("❌ [TradingAPI] 解析投資組合失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    /// 獲取熱門台股清單（保持向後兼容）
    /// - Returns: 熱門台股清單
    func fetchTaiwanStocks() async throws -> TaiwanStockListResponse {
        let url = URL(string: "\(baseURL)/taiwan-stocks")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let taiwanStocks = try decoder.decode(TaiwanStockListResponse.self, from: data)
            print("✅ [TradingAPI] 獲取熱門台股清單成功: \(taiwanStocks.totalCount) 支股票")
            return taiwanStocks
        } catch {
            print("❌ [TradingAPI] 解析熱門台股清單失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    /// 獲取完整台股清單
    /// - Parameters:
    ///   - page: 頁數 (預設 1)
    ///   - perPage: 每頁筆數 (預設 100)
    ///   - search: 搜尋關鍵字
    ///   - market: 市場篩選 ("listed" 或 "otc")
    ///   - industry: 產業篩選
    /// - Returns: 完整台股清單回應
    func fetchAllTaiwanStocks(
        page: Int = 1,
        perPage: Int = 100,
        search: String? = nil,
        market: String? = nil,
        industry: String? = nil
    ) async throws -> CompleteTaiwanStockListResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/taiwan-stocks/all")!
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let market = market, !market.isEmpty {
            queryItems.append(URLQueryItem(name: "market", value: market))
        }
        if let industry = industry, !industry.isEmpty {
            queryItems.append(URLQueryItem(name: "industry", value: industry))
        }
        
        urlComponents.queryItems = queryItems
        
        let (data, response) = try await session.data(from: urlComponents.url!)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let completeResponse = try decoder.decode(CompleteTaiwanStockListResponse.self, from: data)
            print("✅ [TradingAPI] 獲取完整台股清單成功: 第\(page)頁，\(completeResponse.stocks.count)/\(completeResponse.statistics.totalCount) 支股票")
            return completeResponse
        } catch {
            print("❌ [TradingAPI] 解析完整台股清單失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    /// 台股智能搜尋
    /// - Parameters:
    ///   - query: 搜尋關鍵字
    ///   - limit: 結果數量限制 (預設 20)
    /// - Returns: 台股搜尋回應
    func searchTaiwanStocks(query: String, limit: Int = 20) async throws -> TaiwanStockSearchResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/taiwan-stocks/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let (data, response) = try await session.data(from: urlComponents.url!)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let searchResponse = try decoder.decode(TaiwanStockSearchResponse.self, from: data)
            print("✅ [TradingAPI] 台股搜尋成功: '\(query)' 找到 \(searchResponse.totalCount) 支股票")
            return searchResponse
        } catch {
            print("❌ [TradingAPI] 台股搜尋失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    /// 獲取交易歷史
    /// - Parameters:
    ///   - userId: 用戶 ID
    ///   - limit: 限制返回筆數
    /// - Returns: 交易歷史列表
    func fetchTransactions(userId: String, limit: Int = 50) async throws -> [FlaskTransactionResponse] {
        let url = URL(string: "\(baseURL)/transactions?user_id=\(userId)&limit=\(limit)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let transactions = try decoder.decode([FlaskTransactionResponse].self, from: data)
            print("✅ [TradingAPI] 獲取交易歷史成功: \(transactions.count) 筆記錄")
            return transactions
        } catch {
            print("❌ [TradingAPI] 解析交易歷史失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - 簡化的股價檢查方法
    
    /// 檢查股票代號是否有效
    func validateStockSymbol(_ symbol: String) async -> Bool {
        do {
            _ = try await fetchStockPrice(symbol: symbol)
            return true
        } catch {
            return false
        }
    }
    
    /// 清除股價快取（Flask API 自動管理快取）
    func clearPriceCache() {
        // Flask API 使用 Redis 自動管理快取，無需客戶端操作
        print("📋 [TradingAPI] 快取已由 Flask API 管理")
    }
    
    // MARK: - 模擬模式（開發用）
    
    /// 模擬獲取股價（當後端不可用時使用）
    func fetchStockPriceMock(symbol: String) async throws -> TradingStockPrice {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        let mockPrices: [String: (price: Double, currency: String, name: String)] = [
            "AAPL": (150.25, "USD", "Apple Inc"),
            "TSLA": (220.80, "USD", "Tesla Inc"),
            "NVDA": (410.15, "USD", "NVIDIA Corporation"),
            "GOOGL": (125.50, "USD", "Alphabet Inc"),
            "MSFT": (305.75, "USD", "Microsoft Corporation"),
            "AMZN": (135.90, "USD", "Amazon.com Inc"),
            "META": (280.30, "USD", "Meta Platforms Inc"),
            "NFLX": (390.45, "USD", "Netflix Inc"),
            "2330.TW": (925.0, "TWD", "台積電"),
            "2454.TW": (1205.0, "TWD", "聯發科"),
            "2317.TW": (203.5, "TWD", "鴻海"),
            "2881.TW": (89.7, "TWD", "富邦金"),
            "2330": (925.0, "TWD", "台積電"),
            "2454": (1205.0, "TWD", "聯發科"),
            "2317": (203.5, "TWD", "鴻海"),
            "2881": (89.7, "TWD", "富邦金")
        ]
        
        guard let priceInfo = mockPrices[symbol.uppercased()] else {
            throw TradingAPIError.stockNotFound
        }
        
        let change = Double.random(in: -5...5)
        let previousClose = priceInfo.price - change
        let isTaiwanStock = symbol.hasSuffix(".TW") || symbol.count == 4 && CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: symbol))
        
        return TradingStockPrice(
            symbol: symbol.uppercased(),
            name: priceInfo.name,
            currentPrice: priceInfo.price,
            previousClose: previousClose,
            change: change,
            changePercent: change / previousClose,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            currency: priceInfo.currency,
            isTaiwanStock: isTaiwanStock
        )
    }
    
    /// 簡化的價格獲取（自動選擇最佳來源）
    func fetchStockPriceAuto(symbol: String) async throws -> TradingStockPrice {
        return try await fetchStockPrice(symbol: symbol)
    }
}

// MARK: - Flask API 回應模型

/// Flask 股價查詢回應
struct FlaskStockPriceResponse: Codable {
    let symbol: String
    let name: String
    let current_price: Double
    let previous_close: Double
    let change: Double
    let change_percent: Double
    let timestamp: String
    let currency: String?
    let is_taiwan_stock: Bool?
}

/// Flask 交易請求
struct FlaskTradeRequest: Codable {
    let user_id: String
    let symbol: String
    let action: String
    let amount: Double
    let is_day_trading: Bool?
}

/// Flask 交易回應
struct FlaskTradeResponse: Codable {
    let success: Bool
    let transaction_id: String
    let symbol: String
    let action: String
    let shares: Double
    let price: Double
    let total_amount: Double
    let fee: Double?
    let executed_at: String
    let message: String
}

/// Flask 投資組合回應
struct FlaskPortfolioResponse: Codable {
    let user_id: String
    let total_value: Double
    let cash_balance: Double
    let market_value: Double
    let total_invested: Double
    let total_return: Double
    let total_return_percent: Double
    let positions: [FlaskPositionResponse]
    let last_updated: String
}

/// Flask 持倉回應
struct FlaskPositionResponse: Codable {
    let symbol: String
    let name: String
    let shares: Double
    let average_price: Double
    let current_price: Double
    let market_value: Double
    let unrealized_gain: Double
    let unrealized_gain_percent: Double
}

/// Flask 交易歷史回應
struct FlaskTransactionResponse: Codable {
    let id: String
    let symbol: String
    let action: String
    let quantity: Double
    let price: Double
    let total_amount: Double
    let fee: Double?
    let executed_at: String
}

/// Flask 錯誤回應
struct FlaskErrorResponse: Codable {
    let error: String
}

/// 交易結果 (內部使用)
struct TradeResult {
    let success: Bool
    let transactionId: String
    let symbol: String
    let action: String
    let shares: Double
    let price: Double
    let totalAmount: Double
    let executedAt: Date
    let message: String
}

// MARK: - 錯誤類型

enum TradingAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(String)
    case stockNotFound
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無效的伺服器回應"
        case .httpError(let code):
            return "HTTP 錯誤：\(code)"
        case .decodingError(let details):
            return "解析錯誤：\(details)"
        case .stockNotFound:
            return "找不到股票代號"
        case .networkError(let details):
            return "網路錯誤：\(details)"
        }
    }
}

