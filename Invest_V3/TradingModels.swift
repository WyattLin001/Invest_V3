import Foundation
import SwiftUI

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
    
    // 新增的缺失屬性
    let initialBalance: Double
    let holdings: [PortfolioPosition]
    let todayPnl: Double
    let todayPnlPercentage: Double
    
    enum CodingKeys: String, CodingKey {
        case cashBalance = "cash_balance"
        case totalAssets = "total_assets"
        case totalProfit = "total_profit"
        case cumulativeReturn = "cumulative_return"
        case positions
        case initialBalance = "initial_balance"
        case holdings
        case todayPnl = "today_pnl"
        case todayPnlPercentage = "today_pnl_percentage"
    }
}

// MARK: - 持倉模型
struct PortfolioPosition: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let shares: Double          // Flask API 使用 shares 字段
    let averagePrice: Double    // Flask API 使用 average_price
    let currentPrice: Double
    let marketValue: Double
    let unrealizedGain: Double  // Flask API 使用 unrealized_gain
    let unrealizedGainPercent: Double  // Flask API 使用 unrealized_gain_percent
    
    private enum CodingKeys: String, CodingKey {
        case symbol, shares
        case averagePrice = "average_price"
        case currentPrice = "current_price"
        case marketValue = "market_value"
        case unrealizedGain = "unrealized_gain"
        case unrealizedGainPercent = "unrealized_gain_percent"
    }
    
    // 向後兼容的計算屬性
    var name: String { symbol }  // 暫時使用 symbol 作為 name
    var quantity: Int { Int(shares) }
    var averageCost: Double { averagePrice }
    var unrealizedPnl: Double { unrealizedGain }
    var unrealizedPnlPercent: Double { unrealizedGainPercent }
    var market: String { "TWD" }
}

// MARK: - 交易記錄模型
struct TradingTransaction: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let action: String
    let quantity: Double  // 改為 Double 以配合 API 計算出的股數
    let price: Double
    let amount: Double    // 使用 amount 字段（對應 portfolio_transactions 表）
    let executedAt: String
    let tournamentId: UUID? // 新增：關聯的錦標賽ID
    
    private enum CodingKeys: String, CodingKey {
        case symbol, action, quantity, price, amount
        case executedAt = "executed_at"
        case tournamentId = "tournament_id"
    }
    
    // 向後兼容的計算屬性
    var totalAmount: Double { amount }
    var fee: Double { 0.0 }  // Flask API 已在 amount 中處理費用
    var tax: Double? { nil }
    var timestamp: String { executedAt }
    var tournamentName: String? { nil }
    
    // 自定義初始化器（支援向後兼容）
    init(symbol: String, action: String, quantity: Double, price: Double, amount: Double, executedAt: String, tournamentId: UUID? = nil) {
        self.symbol = symbol
        self.action = action
        self.quantity = quantity
        self.price = price
        self.amount = amount
        self.executedAt = executedAt
        self.tournamentId = tournamentId
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

// Flask API 直接返回投資組合物件，無包裝的 success 等字段
struct PortfolioResponse: Codable {
    let userId: String
    let tournamentId: UUID?
    let totalValue: Double
    let cashBalance: Double
    let marketValue: Double
    let totalInvested: Double
    let totalReturn: Double
    let totalReturnPercent: Double
    let positions: [PortfolioPosition]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tournamentId = "tournament_id"
        case totalValue = "total_value"
        case cashBalance = "cash_balance"
        case marketValue = "market_value"
        case totalInvested = "total_invested"
        case totalReturn = "total_return"
        case totalReturnPercent = "total_return_percent"
        case positions
        case lastUpdated = "last_updated"
    }
    
    // 向後兼容的計算屬性
    var success: Bool { true }
    var error: String? { nil }
    
    var portfolio: TradingPortfolio {
        return TradingPortfolio(
            cashBalance: cashBalance,
            totalAssets: totalValue,
            totalProfit: totalReturn,
            cumulativeReturn: totalReturnPercent,
            positions: positions,
            // 新增的缺失參數
            initialBalance: 1000000.0, // 假設初始資金為100萬
            holdings: positions, // 使用相同的持倉數據
            todayPnl: todayReturn ?? 0.0, // 使用今日損益或預設為0
            todayPnlPercentage: (todayReturn ?? 0.0) / 1000000.0 * 100.0 // 計算百分比
        )
    }
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
    let transactions: [TradingTransaction]  // Flask API 直接返回交易陣列，無 success 字段
    
    // 向後兼容的計算屬性
    var success: Bool { !transactions.isEmpty }
    var error: String? { nil }
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

struct TradeErrorResponse: Codable {
    let success: Bool
    let errorCode: String
    let message: String
    let details: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case success
        case errorCode = "error_code"
        case message
        case details
    }
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
    
    // 使用統一的手續費計算器
    private static let feeCalculator = FeeCalculator.shared
    
    // 向後相容的屬性（已廢棄，請使用 FeeCalculator）
    @available(*, deprecated, message: "請使用 FeeCalculator.shared")
    static var brokerFeeRate: Double { feeCalculator.brokerFeeRate }
    
    @available(*, deprecated, message: "請使用 FeeCalculator.shared")
    static var taxRate: Double { feeCalculator.transactionTaxRate }
    
    @available(*, deprecated, message: "請使用 FeeCalculator.shared")
    static var minBrokerFee: Double { feeCalculator.minimumBrokerFee }
    
    static func calculateBuyFee(amount: Double) -> Double {
        let fees = feeCalculator.calculateTradingFees(amount: amount, action: .buy)
        return fees.totalFees
    }
    
    static func calculateSellFee(amount: Double) -> (fee: Double, tax: Double) {
        let fees = feeCalculator.calculateTradingFees(amount: amount, action: .sell)
        return (fee: fees.brokerFee, tax: fees.transactionTax)
    }
    
    /// 計算賣出後實際收到的金額
    static func calculateSellProceedsAfterFees(amount: Double) -> Double {
        let (fee, tax) = calculateSellFee(amount: amount)
        return amount - fee - tax
    }
    
    /// 檢查賣出是否可行（考慮手續費和稅費）
    static func isSellViable(quantity: Int, price: Double) -> SellViabilityResult {
        let totalAmount = Double(quantity) * price
        let (fee, tax) = calculateSellFee(amount: totalAmount)
        let netProceeds = totalAmount - fee - tax
        
        // 檢查是否會虧損（實收金額小於等於 0）
        if netProceeds <= 0 {
            return .notViable(reason: "實收金額為負數", netProceeds: netProceeds)
        }
        
        // 檢查是否實收金額過低（建議至少實收 100 元）
        if netProceeds < 100 {
            return .lowReturns(reason: "實收金額過低", netProceeds: netProceeds)
        }
        
        return .viable(netProceeds: netProceeds)
    }
    
    /// 計算在給定價格下的最大可賣出數量
    static func calculateMaxSellableQuantity(availableQuantity: Int, price: Double, minNetProceeds: Double = 100) -> SellQuantityResult {
        if availableQuantity <= 0 {
            return .noStock
        }
        
        // 從最大數量開始往下測試
        for quantity in stride(from: availableQuantity, through: 1, by: -1) {
            let viabilityResult = isSellViable(quantity: quantity, price: price)
            
            switch viabilityResult {
            case .viable(let netProceeds):
                if netProceeds >= minNetProceeds {
                    return .maxQuantity(quantity: quantity, netProceeds: netProceeds)
                }
            case .lowReturns(_, let netProceeds):
                if netProceeds >= minNetProceeds {
                    return .maxQuantity(quantity: quantity, netProceeds: netProceeds)
                }
            case .notViable:
                continue
            }
        }
        
        return .belowMinimum(availableQuantity: availableQuantity)
    }
    
    /// 提供賣出建議
    static func getSellSuggestion(requestedQuantity: Int, availableQuantity: Int, price: Double) -> SellSuggestion {
        // 檢查持股是否足夠
        if requestedQuantity > availableQuantity {
            return .insufficientStock(
                requested: requestedQuantity,
                available: availableQuantity,
                message: "持股不足，您目前持有 \(availableQuantity) 股，但要賣出 \(requestedQuantity) 股"
            )
        }
        
        // 檢查請求數量的可行性
        let viabilityResult = isSellViable(quantity: requestedQuantity, price: price)
        
        switch viabilityResult {
        case .viable(let netProceeds):
            return .approved(
                quantity: requestedQuantity,
                netProceeds: netProceeds,
                message: "賣出可行，預估實收 \(formatCurrency(netProceeds))"
            )
            
        case .lowReturns(_, let netProceeds):
            // 計算建議數量
            let maxResult = calculateMaxSellableQuantity(availableQuantity: availableQuantity, price: price, minNetProceeds: 100)
            
            switch maxResult {
            case .maxQuantity(let suggestedQuantity, let suggestedProceeds):
                return .suggestAlternative(
                    originalQuantity: requestedQuantity,
                    originalProceeds: netProceeds,
                    suggestedQuantity: suggestedQuantity,
                    suggestedProceeds: suggestedProceeds,
                    message: "建議賣出 \(suggestedQuantity) 股，可獲得較好的實收金額"
                )
            default:
                return .notRecommended(
                    quantity: requestedQuantity,
                    netProceeds: netProceeds,
                    message: "賣出數量過少，實收金額偏低"
                )
            }
            
        case .notViable(let reason, let netProceeds):
            return .rejected(
                quantity: requestedQuantity,
                reason: reason,
                netProceeds: netProceeds
            )
        }
    }
    
    /// 格式化貨幣顯示
    private static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
}

// MARK: - 交易動作枚舉
enum TradeAction {
    case buy, sell
    
    var title: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
    
    var color: Color {
        switch self {
        case .buy: return .red
        case .sell: return .green
        }
    }
}

// MARK: - 賣出相關模型

/// 賣出可行性結果
enum SellViabilityResult {
    case viable(netProceeds: Double)
    case lowReturns(reason: String, netProceeds: Double)
    case notViable(reason: String, netProceeds: Double)
}

/// 賣出數量計算結果
enum SellQuantityResult {
    case maxQuantity(quantity: Int, netProceeds: Double)
    case belowMinimum(availableQuantity: Int)
    case noStock
}

/// 賣出建議
enum SellSuggestion {
    case approved(quantity: Int, netProceeds: Double, message: String)
    case suggestAlternative(originalQuantity: Int, originalProceeds: Double, suggestedQuantity: Int, suggestedProceeds: Double, message: String)
    case notRecommended(quantity: Int, netProceeds: Double, message: String)
    case rejected(quantity: Int, reason: String, netProceeds: Double)
    case insufficientStock(requested: Int, available: Int, message: String)
}
