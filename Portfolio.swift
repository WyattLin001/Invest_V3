import Foundation

// MARK: - 投資組合模型
struct Portfolio: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let groupId: UUID? // 新增 groupId 以關聯投資群組
    let initialCash: Double      // 初始資金 (100萬)
    var availableCash: Double    // 可用現金
    var totalValue: Double       // 總資產價值
    var returnRate: Double       // 回報率 (%)
    let lastUpdated: Date        // 最後更新時間
    
    // 添加 cashBalance 屬性
    var cashBalance: Double {
        return availableCash
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case groupId = "group_id" // 新增 coding key
        case initialCash = "initial_cash"
        case availableCash = "available_cash"
        case totalValue = "total_value"
        case returnRate = "return_rate"
        case lastUpdated = "last_updated"
    }
    
    // 計算屬性
    var totalInvested: Double {
        return initialCash - availableCash
    }
    
    var unrealizedGainLoss: Double {
        return totalValue - initialCash
    }
    
    var isProfit: Bool {
        return returnRate > 0
    }
    
    var returnRateFormatted: String {
        return String(format: "%.2f%%", returnRate)
    }
    
    var returnRateColor: String {
        if returnRate > 0 {
            return "#28A745" // 綠色
        } else if returnRate < 0 {
            return "#DC3545" // 紅色
        } else {
            return "#6C757D" // 灰色
        }
    }
}

struct Position: Codable, Identifiable {
    let id: UUID
    let portfolioId: UUID
    let symbol: String
    var shares: Double
    var averageCost: Double
    var currentValue: Double
    var returnRate: Double
    var lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case portfolioId = "portfolio_id"
        case symbol
        case shares
        case averageCost = "average_cost"
        case currentValue = "current_value"
        case returnRate = "return_rate"
        case lastUpdated = "last_updated"
    }
}

struct PortfolioWithPositions: Codable, Identifiable {
    var portfolio: Portfolio
    var positions: [Position]
    
    var id: UUID { portfolio.id }
    
    var totalValue: Double {
        positions.reduce(portfolio.cashBalance) { $0 + $1.currentValue }
    }
    
    var returnRate: Double {
        ((totalValue - 1000000) / 1000000) * 100
    }
    
    enum CodingKeys: String, CodingKey {
        case portfolio
        case positions
    }
    
    // 新增 memberwise initializer
    init(portfolio: Portfolio, positions: [Position]) {
        self.portfolio = portfolio
        self.positions = positions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        portfolio = try container.decode(Portfolio.self, forKey: .portfolio)
        positions = try container.decode([Position].self, forKey: .positions)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(portfolio, forKey: .portfolio)
        try container.encode(positions, forKey: .positions)
    }
} 