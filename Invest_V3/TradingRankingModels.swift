import Foundation

// MARK: - Trading Ranking Data Models

/// 投資排行榜用戶資料
struct TradingUserRanking: Identifiable, Codable {
    let id = UUID()
    let rank: Int
    let userId: String
    let name: String
    let returnRate: Double // 回報率 (%)
    let totalAssets: Double // 總資產
    let totalProfit: Double // 總盈虧
    let avatarUrl: String?
    let period: String // 排名週期: weekly, monthly, all
    
    // 格式化的回報率字串
    var formattedReturnRate: String {
        return String(format: "%.1f%%", returnRate)
    }
    
    // 格式化的總資產字串
    var formattedTotalAssets: String {
        if totalAssets >= 1_000_000 {
            return String(format: "%.1fM", totalAssets / 1_000_000)
        } else if totalAssets >= 1_000 {
            return String(format: "%.1fK", totalAssets / 1_000)
        } else {
            return String(format: "%.0f", totalAssets)
        }
    }
    
    // 格式化的盈虧字串
    var formattedProfit: String {
        let prefix = totalProfit >= 0 ? "+" : ""
        if abs(totalProfit) >= 1_000_000 {
            return String(format: "%@%.1fM", prefix, totalProfit / 1_000_000)
        } else if abs(totalProfit) >= 1_000 {
            return String(format: "%@%.1fK", prefix, totalProfit / 1_000)
        } else {
            return String(format: "%@%.0f", prefix, totalProfit)
        }
    }
    
    // 盈虧顏色
    var profitColor: String {
        return totalProfit >= 0 ? "brandGreen" : "red"
    }
    
    // 排名圖標
    var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal"
        default: return "\(rank).circle.fill"
        }
    }
    
    // 排名顏色
    var rankColor: String {
        switch rank {
        case 1: return "yellow" // 金色
        case 2: return "gray" // 銀色
        case 3: return "orange" // 銅色
        default: return "brandPrimary"
        }
    }
}

/// 用戶投資績效資料
struct TradingUserPerformance: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let name: String
    let rank: Int
    let returnRate: Double
    let totalAssets: Double
    let totalProfit: Double
    let cashBalance: Double
    let avatarUrl: String?
    
    // 持倉市值
    var positionValue: Double {
        return totalAssets - cashBalance
    }
    
    // 現金比例
    var cashRatio: Double {
        return totalAssets > 0 ? (cashBalance / totalAssets) * 100 : 0
    }
    
    // 持倉比例
    var positionRatio: Double {
        return totalAssets > 0 ? (positionValue / totalAssets) * 100 : 0
    }
    
    // 格式化的排名
    var formattedRank: String {
        return "第 \(rank) 名"
    }
    
    // 績效等級
    var performanceLevel: String {
        switch returnRate {
        case 20...: return "頂尖投資者"
        case 15..<20: return "優秀投資者"
        case 10..<15: return "進階投資者"
        case 5..<10: return "穩健投資者"
        case 0..<5: return "新手投資者"
        default: return "學習中"
        }
    }
    
    // 績效等級顏色
    var performanceLevelColor: String {
        switch returnRate {
        case 20...: return "purple"
        case 15..<20: return "brandGreen"
        case 10..<15: return "blue"
        case 5..<10: return "orange"
        case 0..<5: return "gray"
        default: return "red"
        }
    }
}

/// 排行榜期間枚舉
enum RankingPeriod: String, CaseIterable {
    case weekly = "週榜"
    case monthly = "月榜" 
    case all = "總榜"
    
    var apiValue: String {
        switch self {
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .all: return "all"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

/// 排行榜回應資料
struct RankingsResponse: Codable {
    let success: Bool
    let rankings: [TradingUserRanking]
    let period: String
    let totalUsers: Int?
    let message: String?
}

// MARK: - Mock Data for Testing

extension TradingUserRanking {
    /// 創建測試用的排行榜資料
    static func mockRankings() -> [TradingUserRanking] {
        return [
            TradingUserRanking(
                rank: 1,
                userId: "user1",
                name: "test王",
                returnRate: 25.8,
                totalAssets: 1258000,
                totalProfit: 258000,
                avatarUrl: nil,
                period: "all"
            ),
            TradingUserRanking(
                rank: 2,
                userId: "user2", 
                name: "test徐",
                returnRate: 22.3,
                totalAssets: 1223000,
                totalProfit: 223000,
                avatarUrl: nil,
                period: "all"
            ),
            TradingUserRanking(
                rank: 3,
                userId: "user3",
                name: "test張", 
                returnRate: 19.7,
                totalAssets: 1197000,
                totalProfit: 197000,
                avatarUrl: nil,
                period: "all"
            ),
            TradingUserRanking(
                rank: 4,
                userId: "user4",
                name: "test林",
                returnRate: 17.2,
                totalAssets: 1172000,
                totalProfit: 172000,
                avatarUrl: nil,
                period: "all"
            ),
            TradingUserRanking(
                rank: 5,
                userId: "user5",
                name: "test黃",
                returnRate: 15.6,
                totalAssets: 1156000,
                totalProfit: 156000,
                avatarUrl: nil,
                period: "all"
            )
        ]
    }
}

extension TradingUserPerformance {
    /// 創建測試用的用戶績效資料
    static func mockPerformance() -> TradingUserPerformance {
        return TradingUserPerformance(
            userId: "current_user",
            name: "我的投資",
            rank: 8,
            returnRate: 12.5,
            totalAssets: 1125000,
            totalProfit: 125000,
            cashBalance: 350000,
            avatarUrl: nil
        )
    }
}