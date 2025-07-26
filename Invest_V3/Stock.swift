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
    let name: String    // 公司名稱
    let shares: Double  // 改為 shares 以符合其他地方的使用
    let averagePrice: Double
    let currentPrice: Double
    let lastUpdated: Date
    
    // 向後兼容的計算屬性
    var quantity: Int {
        return Int(shares)
    }
    
    // 計算屬性
    var totalValue: Double {
        return shares * currentPrice
    }
    
    var totalCost: Double {
        return shares * averagePrice
    }
    
    var unrealizedGainLoss: Double {
        return totalValue - totalCost
    }
    
    var unrealizedGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    // MARK: - 新增日漲跌和權重計算屬性
    
    /// 模擬日漲跌金額（用於展示目的）
    var mockDailyChangeAmount: Double {
        // 基於股票代號生成一致的模擬數據
        let seed = Double(symbol.hash % 1000) / 1000.0
        let changePercent = (seed - 0.5) * 6.0 // -3% to +3%
        return currentPrice * (changePercent / 100.0)
    }
    
    /// 模擬日漲跌百分比
    var mockDailyChangePercent: Double {
        let seed = Double(symbol.hash % 1000) / 1000.0
        return (seed - 0.5) * 6.0 // -3% to +3%
    }
    
    /// 獲取中文股票名稱（為知名股票提供中文名）
    var displayName: String {
        let taiwanStockNames: [String: String] = [
            "2330": "台積電",
            "2317": "鴻海",
            "2454": "聯發科",
            "2881": "富邦金",
            "6505": "台塑化",
            "2412": "中華電",
            "2382": "廣達",
            "2308": "台達電",
            "2303": "聯電",
            "1303": "南亞"
        ]
        
        return taiwanStockNames[symbol] ?? name
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case symbol, name, shares
        case averagePrice = "average_price"
        case currentPrice = "current_price"
        case lastUpdated = "last_updated"
    }
} 