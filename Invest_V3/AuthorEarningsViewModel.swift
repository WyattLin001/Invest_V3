import SwiftUI
import Foundation

@MainActor
class AuthorEarningsViewModel: ObservableObject {
    @Published var totalEarnings: Double = 0
    @Published var subscriptionEarnings: Double = 0
    @Published var tipEarnings: Double = 0
    @Published var articleEarnings: Double = 0
    @Published var giftEarnings: Double = 0
    @Published var withdrawableAmount: Double = 0
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    
    // 新增統計數據
    @Published var totalSubscribers: Int = 0
    @Published var newSubscribersThisMonth: Int = 0
    @Published var monthlySubscriptionRevenue: Double = 0
    @Published var retentionRate: Double = 0.85
    @Published var topArticleEarnings: [ArticleEarning] = []
    @Published var earningsHistory: [EarningsData] = []
    
    // 計算屬性
    var articleReadingEarnings: Double { articleEarnings }
    var otherEarnings: Double { totalEarnings - subscriptionEarnings - tipEarnings - articleEarnings - giftEarnings }
    
    var articleReadingPercentage: Double {
        guard totalEarnings > 0 else { return 0 }
        return (articleEarnings / totalEarnings) * 100
    }
    
    var subscriptionPercentage: Double {
        guard totalEarnings > 0 else { return 0 }
        return (subscriptionEarnings / totalEarnings) * 100
    }
    
    var giftPercentage: Double {
        guard totalEarnings > 0 else { return 0 }
        return (giftEarnings / totalEarnings) * 100
    }
    
    var otherPercentage: Double {
        guard totalEarnings > 0 else { return 0 }
        return (otherEarnings / totalEarnings) * 100
    }
    
    var isGrowthPositive: Bool { true } // 可根據實際數據計算
    var maxEarnings: Double { earningsHistory.map(\.amount).max() ?? 100 }

    private let supabaseService = SupabaseService.shared

    func loadData() async {
        isLoading = true
        hasError = false
        errorMessage = nil
        
        do {
            // 模擬網絡延遲
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 載入模擬數據
            await loadMockEarningsData()
            
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            print("❌ [AuthorEarningsViewModel] 載入數據失敗: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadMockEarningsData() async {
        // 模擬作者收益數據
        totalEarnings = 8750.0
        subscriptionEarnings = 4200.0
        tipEarnings = 1800.0
        articleEarnings = 1950.0
        giftEarnings = 800.0
        withdrawableAmount = 6500.0
        
        // 訂閱統計
        totalSubscribers = 142
        newSubscribersThisMonth = 23
        monthlySubscriptionRevenue = 4200.0
        retentionRate = 0.87
        
        // 文章收益明細
        topArticleEarnings = [
            ArticleEarning(
                title: "2024年AI投資趨勢分析",
                earnings: 580.0,
                views: 2340,
                date: Date().addingTimeInterval(-86400 * 2)
            ),
            ArticleEarning(
                title: "台積電Q4財報深度解讀",
                earnings: 420.0,
                views: 1890,
                date: Date().addingTimeInterval(-86400 * 5)
            ),
            ArticleEarning(
                title: "美股科技股投資策略",
                earnings: 380.0,
                views: 1560,
                date: Date().addingTimeInterval(-86400 * 7)
            ),
            ArticleEarning(
                title: "加密貨幣市場展望",
                earnings: 350.0,
                views: 1430,
                date: Date().addingTimeInterval(-86400 * 10)
            ),
            ArticleEarning(
                title: "ESG投資完整指南",
                earnings: 220.0,
                views: 980,
                date: Date().addingTimeInterval(-86400 * 14)
            )
        ]
        
        // 收益歷史數據 (過去30天)
        earningsHistory = generateEarningsHistory()
    }
    
    private func generateEarningsHistory() -> [EarningsData] {
        var history: [EarningsData] = []
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let baseAmount = 200.0
            let variation = Double.random(in: 50...350)
            let amount = baseAmount + variation
            
            history.append(EarningsData(date: date, amount: amount))
        }
        
        return history.reversed()
    }

    func refreshData() async {
        await loadData()
    }
    
    // MARK: - 時間範圍相關方法
    func totalEarnings(for timeframe: EarningsTimeframe) -> Double {
        switch timeframe {
        case .thisMonth:
            return totalEarnings * 0.3 // 本月收益約為30%
        case .thisQuarter:
            return totalEarnings * 0.8 // 本季收益約為80%
        case .thisYear:
            return totalEarnings
        case .allTime:
            return totalEarnings * 1.5 // 全部時間收益更多
        }
    }
    
    func growthRate(for timeframe: EarningsTimeframe) -> String {
        switch timeframe {
        case .thisMonth:
            return "+12.5%"
        case .thisQuarter:
            return "+8.3%"
        case .thisYear:
            return "+15.7%"
        case .allTime:
            return "+25.2%"
        }
    }
    
    func earningsData(for timeframe: EarningsTimeframe) -> [EarningsData] {
        switch timeframe {
        case .thisMonth:
            return Array(earningsHistory.suffix(30))
        case .thisQuarter:
            return Array(earningsHistory.suffix(90))
        case .thisYear:
            return earningsHistory
        case .allTime:
            return earningsHistory
        }
    }
    
    // MARK: - 提領功能
    func initiateWithdrawal() async {
        isLoading = true
        
        do {
            // 模擬提領處理
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            
            // 模擬成功提領
            withdrawableAmount = 0.0
            
            print("✅ [AuthorEarningsViewModel] 提領申請成功")
            
        } catch {
            hasError = true
            errorMessage = "提領失敗: \(error.localizedDescription)"
            print("❌ [AuthorEarningsViewModel] 提領失敗: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - 資料模型
enum EarningsTimeframe: CaseIterable {
    case thisMonth, thisQuarter, thisYear, allTime
    
    var displayName: String {
        switch self {
        case .thisMonth: return "本月"
        case .thisQuarter: return "本季"
        case .thisYear: return "本年"
        case .allTime: return "全部"
        }
    }
}

struct EarningsData: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct ArticleEarning: Identifiable {
    let id = UUID()
    let title: String
    let earnings: Double
    let views: Int
    let date: Date
}