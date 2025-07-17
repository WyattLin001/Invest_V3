import Foundation

// MARK: - 股票資料模型
struct Stock: Identifiable, Codable {
    let id = UUID()
    let symbol: String          // 股票代號 (例如: "2330.TW")
    let name: String           // 股票名稱 (例如: "台積電")
    let price: Double          // 當前價格
    let change: Double         // 漲跌點數
    let changePercent: Double  // 漲跌百分比
    let volume: Int64          // 成交量
    let lastUpdated: Date      // 最後更新時間
    
    // 計算屬性
    var isUp: Bool {
        return change > 0
    }
    
    var isDown: Bool {
        return change < 0
    }
    
    var changeColor: String {
        if change > 0 {
            return "#28A745" // 綠色 (上漲)
        } else if change < 0 {
            return "#DC3545" // 紅色 (下跌)
        } else {
            return "#6C757D" // 灰色 (平盤)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case symbol, name, price, change
        case changePercent = "change_percent"
        case volume
        case lastUpdated = "last_updated"
    }
}

// MARK: - 台股熱門股票清單
struct TaiwanStocks {
    static let popularStocks = [
        "2330.TW", // 台積電
        "2317.TW", // 鴻海
        "2454.TW", // 聯發科
        "2881.TW", // 富邦金
        "6505.TW"  // 台塑化
    ]
    
    static let stockNames: [String: String] = [
        "2330.TW": "台積電",
        "2317.TW": "鴻海",
        "2454.TW": "聯發科",
        "2881.TW": "富邦金",
        "6505.TW": "台塑化"
    ]
}

// MARK: - Alpha Vantage API 回應模型
struct AlphaVantageResponse: Codable {
    let globalQuote: GlobalQuote
    
    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

struct GlobalQuote: Codable {
    let symbol: String
    let price: String
    let change: String
    let changePercent: String
    let volume: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case price = "05. price"
        case change = "09. change"
        case changePercent = "10. change percent"
        case volume = "06. volume"
    }
}

// MARK: - 股票歷史價格點
struct StockHistoryPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let price: Double
    let volume: Int64
    
    enum CodingKeys: String, CodingKey {
        case timestamp, price, volume
    }
}

// MARK: - 投資組合持股
struct PortfolioHolding: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String
    let quantity: Int
    let averagePrice: Double
    let currentPrice: Double
    let lastUpdated: Date
    
    // 計算屬性
    var totalValue: Double {
        return Double(quantity) * currentPrice
    }
    
    var totalCost: Double {
        return Double(quantity) * averagePrice
    }
    
    var unrealizedGainLoss: Double {
        return totalValue - totalCost
    }
    
    var unrealizedGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case symbol, quantity
        case averagePrice = "average_price"
        case currentPrice = "current_price"
        case lastUpdated = "last_updated"
    }
} 