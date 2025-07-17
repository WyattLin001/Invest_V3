import Foundation

// MARK: - 交易用戶模型
struct TradingUser: Codable, Identifiable {
    let id: String
    let phone: String
    let name: String
    let cashBalance: Double
    let totalAssets: Double
    let inviteCode: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, phone, name
        case cashBalance = "cash_balance"
        case totalAssets = "total_assets"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
}

// MARK: - 交易股票模型
struct TradingStock: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    
    private enum CodingKeys: String, CodingKey {
        case symbol, name, price
    }
}

// MARK: - 股票價格模型
struct StockPrice: Codable {
    let symbol: String
    let name: String
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case symbol, name
        case currentPrice = "current_price"
        case previousClose = "previous_close"
        case change
        case changePercent = "change_percent"
        case timestamp
    }
    
    var isUp: Bool { change > 0 }
    var isDown: Bool { change < 0 }
    var changeColor: String {
        if change > 0 {
            return "#28A745" // 綠色 (上漲)
        } else if change < 0 {
            return "#DC3545" // 紅色 (下跌)
        } else {
            return "#6C757D" // 灰色 (平盤)
        }
    }
}

// MARK: - 投資組合模型
struct TradingPortfolio: Codable {
    let cashBalance: Double
    let totalAssets: Double
    let totalProfit: Double
    let cumulativeReturn: Double
    let positions: [PortfolioPosition]
    
    enum CodingKeys: String, CodingKey {
        case cashBalance = "cash_balance"
        case totalAssets = "total_assets"
        case totalProfit = "total_profit"
        case cumulativeReturn = "cumulative_return"
        case positions
    }
}

// MARK: - 持倉模型
struct PortfolioPosition: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let quantity: Int
    let averageCost: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedPnl: Double
    let unrealizedPnlPercent: Double
    let market: String
    
    private enum CodingKeys: String, CodingKey {
        case symbol, quantity
        case averageCost = "average_cost"
        case currentPrice = "current_price"
        case marketValue = "market_value"
        case unrealizedPnl = "unrealized_pnl"
        case unrealizedPnlPercent = "unrealized_pnl_percent"
        case market
    }
}

// MARK: - 交易記錄模型
struct TradingTransaction: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let action: String
    let quantity: Int
    let price: Double
    let totalAmount: Double
    let fee: Double
    let tax: Double?
    let timestamp: String
    
    private enum CodingKeys: String, CodingKey {
        case symbol, action, quantity, price
        case totalAmount = "total_amount"
        case fee, tax, timestamp
    }
    
    var actionText: String {
        switch action {
        case "buy":
            return "買入"
        case "sell":
            return "賣出"
        default:
            return action
        }
    }
    
    var actionColor: String {
        switch action {
        case "buy":
            return "#DC3545" // 紅色
        case "sell":
            return "#28A745" // 綠色
        default:
            return "#6C757D" // 灰色
        }
    }
}

// MARK: - 用戶排名模型
struct UserRanking: Codable, Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let returnRate: Double
    let totalAssets: Double
    
    private enum CodingKeys: String, CodingKey {
        case rank, name
        case returnRate = "return_rate"
        case totalAssets = "total_assets"
    }
}

// MARK: - API 回應模型

struct OTPResponse: Codable {
    let success: Bool
    let message: String
    let otp: String?
    let expiresIn: Int?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message, otp, error
        case expiresIn = "expires_in"
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let user: TradingUser
    let accessToken: String
    let isNewUser: Bool
    let referralBonus: Double?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message, user, error
        case accessToken = "access_token"
        case isNewUser = "is_new_user"
        case referralBonus = "referral_bonus"
    }
}

struct PortfolioResponse: Codable {
    let success: Bool
    let portfolio: TradingPortfolio
    let error: String?
}

struct StocksResponse: Codable {
    let success: Bool
    let stocks: [TradingStock]
    let total: Int
    let error: String?
}

struct StockPriceResponse: Codable {
    let success: Bool
    let symbol: String
    let name: String
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let timestamp: String
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, symbol, name, timestamp, error
        case currentPrice = "current_price"
        case previousClose = "previous_close"
        case change
        case changePercent = "change_percent"
    }
}

struct TransactionsResponse: Codable {
    let success: Bool
    let transactions: [TradingTransaction]
    let error: String?
}

struct TradeResponse: Codable {
    let success: Bool
    let message: String
    let transaction: TransactionDetail?
    let error: String?
}

struct TransactionDetail: Codable {
    let symbol: String
    let action: String
    let quantity: Int
    let price: Double
    let totalAmount: Double
    let fee: Double
    let tax: Double?
    let totalCost: Double?
    let totalReceived: Double?
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case symbol, action, quantity, price, fee, tax, timestamp
        case totalAmount = "total_amount"
        case totalCost = "total_cost"
        case totalReceived = "total_received"
    }
}

struct RankingsResponse: Codable {
    let success: Bool
    let period: String
    let rankings: [UserRanking]
    let error: String?
}

// MARK: - 交易相關常數
struct TradingConstants {
    static let taiwanStocks = [
        TradingStock(symbol: "2330", name: "台灣積體電路製造股份有限公司", price: 925.0),
        TradingStock(symbol: "2317", name: "鴻海精密工業股份有限公司", price: 203.5),
        TradingStock(symbol: "2454", name: "聯發科技股份有限公司", price: 1205.0),
        TradingStock(symbol: "2881", name: "富邦金融控股股份有限公司", price: 89.7),
        TradingStock(symbol: "2882", name: "國泰金融控股股份有限公司", price: 65.1),
        TradingStock(symbol: "2886", name: "兆豐金融控股股份有限公司", price: 45.2),
        TradingStock(symbol: "2891", name: "中國信託金融控股股份有限公司", price: 28.8),
        TradingStock(symbol: "6505", name: "台灣化學纖維股份有限公司", price: 102.5),
        TradingStock(symbol: "3008", name: "大立光電股份有限公司", price: 2890.0),
        TradingStock(symbol: "2308", name: "台達電子工業股份有限公司", price: 428.0)
    ]
    
    static let brokerFeeRate = 0.001425 // 0.1425%
    static let taxRate = 0.003 // 0.3%
    static let minBrokerFee = 20.0 // 最低手續費
    
    static func calculateBuyFee(amount: Double) -> Double {
        return max(amount * brokerFeeRate, minBrokerFee)
    }
    
    static func calculateSellFee(amount: Double) -> (fee: Double, tax: Double) {
        let fee = max(amount * brokerFeeRate, minBrokerFee)
        let tax = amount * taxRate
        return (fee, tax)
    }
}