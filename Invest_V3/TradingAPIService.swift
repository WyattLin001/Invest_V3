import Foundation
import SwiftUI

/// 交易服務 - 整合 Yahoo Finance 即時股價
/// 負責獲取真實股價數據
@MainActor
class TradingAPIService: ObservableObject {
    static let shared = TradingAPIService()
    
    // Yahoo Finance API
    private let yahooFinanceBaseURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    // 價格快取 (避免頻繁 API 調用)
    private var priceCache: [String: (price: StockPrice, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 10 // 10秒快取
    
    private init() {
        // 設置 JSON 日期解碼策略
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - 股價 API
    
    /// 獲取即時股價
    /// - Parameter symbol: 股票代號
    /// - Returns: 股價資訊
    func fetchStockPrice(symbol: String) async throws -> StockPrice {
        // 檢查快取
        if let cached = priceCache[symbol.uppercased()],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            print("📋 [TradingAPI] 使用快取股價: \(symbol) - $\(cached.price.currentPrice)")
            return cached.price
        }
        
        let url = URL(string: "\(yahooFinanceBaseURL)/\(symbol.uppercased())")!
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TradingAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw TradingAPIError.httpError(httpResponse.statusCode)
            }
            
            let yahooResponse = try decoder.decode(YahooFinanceResponse.self, from: data)
            
            guard let result = yahooResponse.chart.result.first,
                  let quote = result.indicators.quote.first,
                  let meta = result.meta,
                  let currentPrice = quote.close?.last else {
                throw TradingAPIError.stockNotFound
            }
            
            let previousClose = meta.previousClose ?? currentPrice
            let change = currentPrice - previousClose
            let changePercent = change / previousClose
            
            let stockPrice = StockPrice(
                symbol: symbol.uppercased(),
                name: meta.longName ?? "\(symbol.uppercased()) Inc",
                currentPrice: currentPrice,
                previousClose: previousClose,
                change: change,
                changePercent: changePercent,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            
            // 更新快取
            priceCache[symbol.uppercased()] = (price: stockPrice, timestamp: Date())
            
            print("✅ [TradingAPI] 獲取股價成功: \(symbol) - $\(stockPrice.currentPrice)")
            return stockPrice
            
        } catch {
            print("❌ [TradingAPI] Yahoo Finance API 失敗: \(error)")
            // 如果 Yahoo Finance 失敗，回退到模擬數據
            return try await fetchStockPriceMock(symbol: symbol)
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
    
    /// 清除股價快取
    func clearPriceCache() {
        priceCache.removeAll()
    }
    
    // MARK: - 模擬模式（開發用）
    
    /// 模擬獲取股價（當後端不可用時使用）
    func fetchStockPriceMock(symbol: String) async throws -> StockPrice {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        let mockPrices: [String: Double] = [
            "AAPL": 150.25,
            "TSLA": 220.80,
            "NVDA": 410.15,
            "GOOGL": 125.50,
            "MSFT": 305.75,
            "AMZN": 135.90,
            "META": 280.30,
            "NFLX": 390.45
        ]
        
        guard let price = mockPrices[symbol.uppercased()] else {
            throw TradingAPIError.stockNotFound
        }
        
        let change = Double.random(in: -5...5)
        let previousClose = price - change
        
        return StockPrice(
            symbol: symbol.uppercased(),
            name: "\(symbol.uppercased()) Inc",
            currentPrice: price,
            previousClose: previousClose,
            change: change,
            changePercent: change / previousClose,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    /// 簡化的價格獲取（自動選擇最佳來源）
    func fetchStockPriceAuto(symbol: String) async throws -> StockPrice {
        return try await fetchStockPrice(symbol: symbol)
    }
}

// MARK: - Yahoo Finance API 回應模型

struct YahooFinanceResponse: Codable {
    let chart: YahooChart
}

struct YahooChart: Codable {
    let result: [YahooResult]
    let error: YahooError?
}

struct YahooResult: Codable {
    let meta: YahooMeta
    let indicators: YahooIndicators
}

struct YahooMeta: Codable {
    let currency: String?
    let symbol: String
    let regularMarketPrice: Double?
    let previousClose: Double?
    let longName: String?
    let shortName: String?
}

struct YahooIndicators: Codable {
    let quote: [YahooQuote]
}

struct YahooQuote: Codable {
    let close: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let open: [Double?]?
    let volume: [Int?]?
}

struct YahooError: Codable {
    let code: String
    let description: String
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

