import SwiftUI
import Foundation

@MainActor
class AuthorEarningsViewModel: ObservableObject {
    @Published var totalEarnings: Double = 0
    @Published var subscriptionEarnings: Double = 0
    @Published var tipEarnings: Double = 0
    @Published var articleEarnings: Double = 0
    @Published var giftEarnings: Double = 0
    @Published var groupEntryFeeEarnings: Double = 0 // 群組入會費收入
    @Published var groupTipEarnings: Double = 0 // 群組抖內收入
    @Published var withdrawableAmount: Double = 0
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var isWithdrawalSuccessful = false
    
    // 新增統計數據
    @Published var totalSubscribers: Int = 0
    @Published var newSubscribersThisMonth: Int = 0
    @Published var monthlySubscriptionRevenue: Double = 0
    @Published var retentionRate: Double = 0.85
    @Published var topArticleEarnings: [ArticleEarning] = []
    @Published var earningsHistory: [EarningsData] = []
    
    // 計算屬性
    var articleReadingEarnings: Double { articleEarnings }
    var otherEarnings: Double { totalEarnings - subscriptionEarnings - tipEarnings - articleEarnings - giftEarnings - groupEntryFeeEarnings - groupTipEarnings }
    
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
    
    var groupEntryFeePercentage: Double {
        guard totalEarnings > 0 else { return 0 }
        return (groupEntryFeeEarnings / totalEarnings) * 100
    }
    
    var groupTipPercentage: Double {
        guard totalEarnings > 0 else { return 0 }
        return (groupTipEarnings / totalEarnings) * 100
    }
    
    var isGrowthPositive: Bool { true } // 可根據實際數據計算
    var maxEarnings: Double { earningsHistory.map(\.amount).max() ?? 100 }
    
    // 金幣轉台幣匯率 (1金幣 = 1台幣)
    private let coinToTWDRate: Double = 1.0
    
    // 格式化顯示總收益 (金幣)
    var formattedTotalEarningsInCoins: String {
        return "\(Int(totalEarnings)) 金幣"
    }
    
    // 格式化顯示總收益 (台幣)
    var formattedTotalEarningsInTWD: String {
        let twd = totalEarnings * coinToTWDRate
        return "NT$\(Int(twd))"
    }
    
    // 格式化顯示可提領金額 (金幣)
    var formattedWithdrawableInCoins: String {
        return "\(Int(withdrawableAmount)) 金幣"
    }
    
    // 格式化顯示可提領金額 (台幣)
    var formattedWithdrawableInTWD: String {
        let twd = withdrawableAmount * coinToTWDRate
        return "NT$\(Int(twd))"
    }

    private let supabaseService = SupabaseService.shared

    func loadData() async {
        isLoading = true
        hasError = false
        errorMessage = nil
        
        do {
            // 獲取當前用戶ID
            guard let currentUser = supabaseService.getCurrentUser() else {
                throw SupabaseError.notAuthenticated
            }
            
            // 從 Supabase 載入真實數據
            let stats = try await supabaseService.fetchCreatorRevenueStats(creatorId: currentUser.id)
            
            // 更新 UI 數據
            totalEarnings = stats.totalEarnings
            subscriptionEarnings = stats.subscriptionEarnings
            tipEarnings = stats.tipEarnings
            articleEarnings = stats.articleEarnings
            giftEarnings = stats.giftEarnings
            groupEntryFeeEarnings = stats.groupEntryFeeEarnings
            groupTipEarnings = stats.groupTipEarnings
            withdrawableAmount = stats.withdrawableAmount
            
            // 載入其他模擬數據 (訂閱統計等)
            await loadMockSupplementaryData()
            
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            print("❌ [AuthorEarningsViewModel] 載入數據失敗: \(error)")
            
            // 發生錯誤時使用模擬數據作為後備
            await loadMockEarningsData()
        }
        
        isLoading = false
    }
    
    private func loadMockSupplementaryData() async {
        // 訂閱統計 (這部分暫時使用模擬數據)
        totalSubscribers = 142
        newSubscribersThisMonth = 23
        monthlySubscriptionRevenue = subscriptionEarnings
        retentionRate = 0.87
        
        // 文章收益明細
        topArticleEarnings = generateMockArticleEarnings()
        
        // 收益歷史數據
        earningsHistory = generateEarningsHistory()
    }
    
    private func loadMockEarningsData() async {
        // 模擬作者收益數據  
        totalEarnings = 9850.0  // 更新總收益 (5300+1800+1950+800)
        subscriptionEarnings = 5300.0  // 確保訂閱分潤為正數
        tipEarnings = 1800.0
        articleEarnings = 1950.0
        giftEarnings = 800.0
        withdrawableAmount = 6500.0
        
        // 訂閱統計
        totalSubscribers = 142
        newSubscribersThisMonth = 23
        monthlySubscriptionRevenue = 5300.0  // 與 subscriptionEarnings 一致
        retentionRate = 0.87
        
        // 文章收益明細
        topArticleEarnings = generateMockArticleEarnings()
        
        // 收益歷史數據 (過去30天)
        earningsHistory = generateEarningsHistory()
    }
    
    private func generateMockArticleEarnings() -> [ArticleEarning] {
        return [
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
            // 獲取當前用戶ID
            guard let currentUser = supabaseService.getCurrentUser() else {
                throw SupabaseError.notAuthenticated
            }
            
            // 執行提領處理 (將收益轉入錢包並歸零總收益)
            try await supabaseService.processWithdrawal(
                creatorId: currentUser.id, 
                amount: withdrawableAmount
            )
            
            // 更新本地狀態
            totalEarnings = 0.0
            subscriptionEarnings = 0.0
            tipEarnings = 0.0
            articleEarnings = 0.0
            giftEarnings = 0.0
            groupEntryFeeEarnings = 0.0
            groupTipEarnings = 0.0
            withdrawableAmount = 0.0
            
            // 發送錢包餘額更新通知給其他頁面
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
            
            // 觸發提領成功狀態
            isWithdrawalSuccessful = true
            
            print("✅ [AuthorEarningsViewModel] 提領申請成功，收益已轉入錢包")
            
            // 重置提領成功狀態 (延遲一點點讓動畫有時間觸發)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isWithdrawalSuccessful = false
            }
            
        } catch {
            hasError = true
            errorMessage = "提領失敗: \(error.localizedDescription)"
            print("❌ [AuthorEarningsViewModel] 提領失敗: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 數據初始化功能
    /// 為當前用戶初始化所有必要數據（適用於所有用戶）
    func initializeUserData() async {
        isLoading = true
        hasError = false
        errorMessage = nil
        
        do {
            // 調用通用的用戶數據初始化方法
            let message = try await supabaseService.initializeCurrentUserData()
            
            // 重新載入數據
            await loadData()
            
            print("✅ [AuthorEarningsViewModel] 用戶數據初始化完成: \(message)")
            
        } catch {
            hasError = true
            errorMessage = "初始化數據失敗: \(error.localizedDescription)"
            print("❌ [AuthorEarningsViewModel] 初始化數據失敗: \(error)")
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

// MARK: - Creator Revenue Models
struct CreatorRevenue: Codable, Identifiable {
    let id: String
    let creatorId: String
    let revenueType: RevenueType
    let amount: Int // 金幣數量
    let sourceId: String? // 來源ID (例如：群組ID、文章ID等)
    let sourceName: String? // 來源名稱
    let description: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case revenueType = "revenue_type"
        case amount
        case sourceId = "source_id"
        case sourceName = "source_name"
        case description
        case createdAt = "created_at"
    }
}

// RevenueType 已移動到 InvestmentGroup.swift 以便共享

// 提領記錄模型
struct WithdrawalRecord: Codable, Identifiable {
    let id: String
    let creatorId: String
    let amount: Int // 提領金額 (金幣)
    let amountTWD: Int // 提領金額 (台幣)
    let status: WithdrawalStatus
    let bankAccount: String? // 銀行帳戶 (未來功能)
    let processedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case amount
        case amountTWD = "amount_twd"
        case status
        case bankAccount = "bank_account"
        case processedAt = "processed_at"
        case createdAt = "created_at"
    }
}

// 提領狀態枚舉
enum WithdrawalStatus: String, Codable {
    case pending = "pending" // 處理中
    case completed = "completed" // 已完成
    case failed = "failed" // 失敗
}

// 創作者收益統計結構
struct CreatorRevenueStats {
    var totalEarnings: Double = 0
    var subscriptionEarnings: Double = 0
    var tipEarnings: Double = 0
    var articleEarnings: Double = 0
    var giftEarnings: Double = 0
    var groupEntryFeeEarnings: Double = 0
    var groupTipEarnings: Double = 0
    var withdrawableAmount: Double = 0
    var totalTransactions: Int = 0
    
    // 新增缺少的屬性
    var subscriptionRevenue: Double = 0  // 訂閱分潤
    var readerTipRevenue: Double = 0     // 讀者抖內
    var tipRevenue: Double = 0           // 抖內收益
    var totalRevenue: Double = 0         // 總收益
    var lastMonthRevenue: Double = 0     // 上月收益
    var currentMonthRevenue: Double = 0  // 本月收益
}