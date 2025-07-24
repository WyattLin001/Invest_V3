import Foundation
import SwiftUI

/// 交易 API 服務
/// 負責與後端 Flask API 進行通訊
@MainActor
class TradingAPIService: ObservableObject {
    static let shared = TradingAPIService()
    
    // API 基礎 URL - 實際部署時需要替換為真實的後端地址
    private let baseURL = "http://localhost:5000/api"
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        // 設置 JSON 日期解碼策略
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - 股價 API
    
    /// 獲取即時股價
    /// - Parameter symbol: 股票代號
    /// - Returns: 股價資訊
    func fetchStockPrice(symbol: String) async throws -> StockPrice {
        let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let stockPrice = try decoder.decode(StockPrice.self, from: data)
            print("✅ [TradingAPI] 獲取股價成功: \(symbol) - $\(stockPrice.price)")
            return stockPrice
        } catch {
            print("❌ [TradingAPI] 股價解析失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - 交易 API
    
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
        
        let tradeRequest = TradeRequest(
            symbol: symbol,
            action: action,
            amount: amount,
            userId: userId
        )
        
        do {
            request.httpBody = try encoder.encode(tradeRequest)
        } catch {
            throw TradingAPIError.encodingError(error.localizedDescription)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // 嘗試解析錯誤訊息
            if let errorData = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw TradingAPIError.apiError(errorData.message)
            }
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let tradeResult = try decoder.decode(TradeResult.self, from: data)
            print("✅ [TradingAPI] 交易執行成功: \(action) \(symbol)")
            return tradeResult
        } catch {
            print("❌ [TradingAPI] 交易結果解析失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - 投資組合 API
    
    /// 獲取投資組合
    /// - Parameter userId: 用戶 ID
    /// - Returns: 投資組合資訊
    func fetchPortfolio(userId: String) async throws -> Portfolio {
        let url = URL(string: "\(baseURL)/portfolio?userId=\(userId)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let portfolio = try decoder.decode(Portfolio.self, from: data)
            print("✅ [TradingAPI] 獲取投資組合成功: 總值 $\(portfolio.totalValue)")
            return portfolio
        } catch {
            print("❌ [TradingAPI] 投資組合解析失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - 交易歷史 API
    
    /// 獲取交易歷史
    /// - Parameters:
    ///   - userId: 用戶 ID
    ///   - limit: 限制返回筆數
    /// - Returns: 交易歷史列表
    func fetchTransactions(userId: String, limit: Int = 50) async throws -> [Transaction] {
        let url = URL(string: "\(baseURL)/transactions?userId=\(userId)&limit=\(limit)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let transactions = try decoder.decode([Transaction].self, from: data)
            print("✅ [TradingAPI] 獲取交易歷史成功: \(transactions.count) 筆記錄")
            return transactions
        } catch {
            print("❌ [TradingAPI] 交易歷史解析失敗: \(error)")
            throw TradingAPIError.decodingError(error.localizedDescription)
        }
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
        
        return StockPrice(
            symbol: symbol.uppercased(),
            price: price,
            change: Double.random(in: -5...5),
            changePercent: Double.random(in: -0.05...0.05),
            lastUpdated: Date()
        )
    }
    
    /// 模擬執行交易（當後端不可用時使用）
    func executeTraceMock(symbol: String, action: String, amount: Double, userId: String) async throws -> TradeResult {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 模擬隨機成功/失敗
        if Double.random(in: 0...1) < 0.1 { // 10% 失敗率
            throw TradingAPIError.insufficientFunds
        }
        
        let currentPrice = try await fetchStockPriceMock(symbol: symbol).price
        let shares = action == "buy" ? amount / currentPrice : amount
        
        return TradeResult(
            success: true,
            transactionId: UUID().uuidString,
            symbol: symbol,
            action: action,
            shares: shares,
            price: currentPrice,
            totalAmount: shares * currentPrice,
            executedAt: Date(),
            message: "\(action == "buy" ? "買入" : "賣出")成功"
        )
    }
}

// MARK: - 資料模型

/// 股價資訊
struct StockPrice: Codable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let lastUpdated: Date
}

/// 交易請求
struct TradeRequest: Codable {
    let symbol: String
    let action: String
    let amount: Double
    let userId: String
}

/// 交易結果
struct TradeResult: Codable {
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

/// 投資組合
struct Portfolio: Codable {
    let userId: String
    let totalValue: Double
    let cashBalance: Double
    let positions: [Position]
    let totalReturn: Double
    let totalReturnPercent: Double
    let lastUpdated: Date
}

/// 持倉
struct Position: Codable {
    let symbol: String
    let shares: Double
    let averagePrice: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedGain: Double
    let unrealizedGainPercent: Double
}

/// API 錯誤回應
struct APIErrorResponse: Codable {
    let error: Bool
    let message: String
}

// MARK: - 錯誤類型

enum TradingAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case encodingError(String)
    case decodingError(String)
    case apiError(String)
    case stockNotFound
    case insufficientFunds
    case insufficientShares
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無效的伺服器回應"
        case .httpError(let code):
            return "HTTP 錯誤：\(code)"
        case .encodingError(let details):
            return "編碼錯誤：\(details)"
        case .decodingError(let details):
            return "解碼錯誤：\(details)"
        case .apiError(let message):
            return message
        case .stockNotFound:
            return "找不到股票代號"
        case .insufficientFunds:
            return "餘額不足"
        case .insufficientShares:
            return "持股不足"
        case .networkError(let details):
            return "網路錯誤：\(details)"
        }
    }
}

// MARK: - 便利方法

extension TradingAPIService {
    /// 檢查 API 連線狀態
    func checkAPIConnection() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("❌ [TradingAPI] 連線檢查失敗: \(error)")
        }
        
        return false
    }
    
    /// 自動選擇 API 模式（真實 API 或模擬模式）
    func fetchStockPriceAuto(symbol: String) async throws -> StockPrice {
        let isAPIAvailable = await checkAPIConnection()
        
        if isAPIAvailable {
            return try await fetchStockPrice(symbol: symbol)
        } else {
            print("⚠️ [TradingAPI] API 不可用，使用模擬模式")
            return try await fetchStockPriceMock(symbol: symbol)
        }
    }
    
    /// 自動選擇交易模式（真實 API 或模擬模式）
    func executeTradeAuto(symbol: String, action: String, amount: Double, userId: String) async throws -> TradeResult {
        let isAPIAvailable = await checkAPIConnection()
        
        if isAPIAvailable {
            return try await executeTrade(symbol: symbol, action: action, amount: amount, userId: userId)
        } else {
            print("⚠️ [TradingAPI] API 不可用，使用模擬模式")
            return try await executeTraceMock(symbol: symbol, action: action, amount: amount, userId: userId)
        }
    }
}