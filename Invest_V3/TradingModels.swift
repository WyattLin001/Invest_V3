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
struct TradingStockPrice: Codable {
    let symbol: String
    let name: String
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let timestamp: String
    let currency: String?
    let isTaiwanStock: Bool?
    
    enum CodingKeys: String, CodingKey {
        case symbol, name
        case currentPrice = "current_price"
        case previousClose = "previous_close"
        case change
        case changePercent = "change_percent"
        case timestamp, currency
        case isTaiwanStock = "is_taiwan_stock"
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
    
    /// 格式化價格顯示
    var formattedPrice: String {
        let currencySymbol = getCurrencySymbol()
        if isTaiwanStock == true {
            return String(format: "%@ %.2f", currencySymbol, currentPrice)
        } else {
            return String(format: "%@ %.2f", currencySymbol, currentPrice)
        }
    }
    
    /// 格式化變動顯示
    var formattedChange: String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f (%.2f%%)", sign, change, changePercent)
    }
    
    /// 獲取貨幣符號
    func getCurrencySymbol() -> String {
        switch currency {
        case "TWD":
            return "NT$"
        case "USD":
            return "$"
        default:
            return currency ?? "$"
        }
    }
    
    /// 是否為台股
    var isFromTaiwan: Bool {
        return isTaiwanStock == true || symbol.hasSuffix(".TW") || symbol.hasSuffix(".TWO")
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
    let name: String
    let quantity: Int
    let averageCost: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedPnl: Double
    let unrealizedPnlPercent: Double
    let market: String
    
    private enum CodingKeys: String, CodingKey {
        case symbol, name, quantity
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

// MARK: - 台股相關模型

/// 台股清單項目
struct TaiwanStockItem: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let baseSymbol: String
    let name: String
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case symbol
        case baseSymbol = "base_symbol"
        case name
        case displayName = "display_name"
    }
}

/// 台股清單回應
struct TaiwanStockListResponse: Codable {
    let stocks: [TaiwanStockItem]
    let totalCount: Int
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case stocks
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

/// 完整台股清單項目
struct CompleteTaiwanStockItem: Codable, Identifiable, Equatable {
    let id = UUID()
    let code: String
    let name: String
    let fullCode: String
    let market: String
    let industry: String
    let isListed: Bool
    let exchange: String
    
    // 可選的額外欄位（搜尋結果可能包含）
    let change: String?
    let closingPrice: String?
    let tradeVolume: String?

    enum CodingKeys: String, CodingKey {
        case code
        case name
        case fullCode = "full_code"
        case market
        case industry
        case isListed = "is_listed"
        case exchange
        case change
        case closingPrice = "closing_price"
        case tradeVolume = "trade_volume"
    }

    // 自定義初始化器處理 id
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        fullCode = try container.decode(String.self, forKey: .fullCode)
        market = try container.decode(String.self, forKey: .market)
        industry = try container.decode(String.self, forKey: .industry)
        isListed = try container.decode(Bool.self, forKey: .isListed)
        exchange = try container.decode(String.self, forKey: .exchange)
        
        // 可選欄位
        change = try container.decodeIfPresent(String.self, forKey: .change)
        closingPrice = try container.decodeIfPresent(String.self, forKey: .closingPrice)
        tradeVolume = try container.decodeIfPresent(String.self, forKey: .tradeVolume)
    }

    // 可以加上明確 Equatable 規則（可選）
    static func == (lhs: CompleteTaiwanStockItem, rhs: CompleteTaiwanStockItem) -> Bool {
        return lhs.code == rhs.code
    }
}


/// 分頁資訊
struct PaginationInfo: Codable {
    let page: Int
    let perPage: Int
    let totalCount: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrev: Bool
    
    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case totalCount = "total_count"
        case totalPages = "total_pages"
        case hasNext = "has_next"
        case hasPrev = "has_prev"
    }
}

/// 統計資訊
struct StockStatistics: Codable {
    let totalCount: Int
    let listedCount: Int
    let otcCount: Int
    let industries: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case listedCount = "listed_count"
        case otcCount = "otc_count"
        case industries
    }
}

/// 完整台股清單回應
struct CompleteTaiwanStockListResponse: Codable {
    let stocks: [CompleteTaiwanStockItem]
    let pagination: PaginationInfo
    let statistics: StockStatistics
    let filters: [String: String]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case stocks, pagination, statistics, filters
        case lastUpdated = "last_updated"
    }
}

/// 台股搜尋回應
struct TaiwanStockSearchResponse: Codable {
    let stocks: [CompleteTaiwanStockItem]
    let totalCount: Int
    let query: String
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case stocks, query, limit
        case totalCount = "total_count"
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
    let executedAt: String  // 改為 executedAt 以符合其他地方的使用
    
    // 向後兼容的計算屬性
    var timestamp: String {
        return executedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case symbol, action, quantity, price, fee, tax
        case totalAmount = "total_amount"
        case totalCost = "total_cost"
        case totalReceived = "total_received"
        case executedAt = "executed_at"
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
