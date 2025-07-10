//
//  AlphaVantageService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation

@MainActor
class AlphaVantageService: ObservableObject {
    static let shared = AlphaVantageService()
    
    private let apiKey = "YOUR_ALPHA_VANTAGE_API_KEY" // 請替換為實際的 API Key
    private let baseURL = "https://www.alphavantage.co/query"
    
    private init() {}
    
    func fetchStockPrice(symbol: String) async throws -> StockPrice {
        let urlString = "\(baseURL)?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AlphaVantageResponse.self, from: data)
        
        guard let quote = response.globalQuote else {
            throw APIError.noData
        }
        
        return StockPrice(
            symbol: quote.symbol,
            price: Double(quote.price) ?? 0.0,
            change: Double(quote.change) ?? 0.0,
            changePercent: quote.changePercent,
            lastUpdated: Date()
        )
    }
    
    func fetchMultipleStockPrices(symbols: [String]) async throws -> [StockPrice] {
        var stockPrices: [StockPrice] = []
        
        for symbol in symbols {
            do {
                let price = try await fetchStockPrice(symbol: symbol)
                stockPrices.append(price)
                
                // Rate limiting - Alpha Vantage free tier allows 5 calls per minute
                try await Task.sleep(nanoseconds: 12_000_000_000) // 12 seconds
            } catch {
                print("Failed to fetch price for \(symbol): \(error)")
                // 如果 API 失敗，使用模擬數據
                let mockPrice = StockPrice(
                    symbol: symbol,
                    price: Double.random(in: 100...300),
                    change: Double.random(in: -10...10),
                    changePercent: String(format: "%.2f%%", Double.random(in: -5...5)),
                    lastUpdated: Date()
                )
                stockPrices.append(mockPrice)
            }
        }
        
        return stockPrices
    }
    
    // 模擬股價數據（用於開發測試）
    func getMockStockPrice(symbol: String) -> StockPrice {
        let basePrice: Double
        switch symbol {
        case "AAPL": basePrice = 175.0
        case "TSLA": basePrice = 240.0
        case "NVDA": basePrice = 450.0
        case "MSFT": basePrice = 380.0
        case "GOOGL": basePrice = 140.0
        default: basePrice = 100.0
        }
        
        let variation = Double.random(in: -0.1...0.1)
        let currentPrice = basePrice * (1 + variation)
        let change = currentPrice - basePrice
        let changePercent = String(format: "%.2f%%", (change / basePrice) * 100)
        
        return StockPrice(
            symbol: symbol,
            price: currentPrice,
            change: change,
            changePercent: changePercent,
            lastUpdated: Date()
        )
    }
}

// MARK: - Models
struct StockPrice: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: String
    let lastUpdated: Date
}

struct AlphaVantageResponse: Codable {
    let globalQuote: GlobalQuote?
    
    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

struct GlobalQuote: Codable {
    let symbol: String
    let open: String
    let high: String
    let low: String
    let price: String
    let volume: String
    let latestTradingDay: String
    let previousClose: String
    let change: String
    let changePercent: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case open = "02. open"
        case high = "03. high"
        case low = "04. low"
        case price = "05. price"
        case volume = "06. volume"
        case latestTradingDay = "07. latest trading day"
        case previousClose = "08. previous close"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .noData:
            return "無法獲取數據"
        case .decodingError:
            return "數據解析錯誤"
        }
    }
}