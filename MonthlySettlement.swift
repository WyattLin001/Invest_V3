import Foundation

// MARK: - 月度結算記錄模型
struct MonthlySettlement: Identifiable, Codable {
    let id: UUID
    let authorId: UUID
    let settlementYear: Int
    let settlementMonth: Int
    let totalGrossRevenue: Int  // 總收入（分）
    let totalPlatformFee: Int   // 總平台抽成（分）
    let totalCreatorEarnings: Int  // 總創作者收益（分）
    let subscriptionRevenue: Int   // 訂閱收益（分）
    let donationRevenue: Int      // 抖內收益（分）
    let paidReadingRevenue: Int   // 付費閱讀收益（分）
    let bonusRevenue: Int         // 獎金收益（分）
    let status: String
    let processedAt: Date?
    let paidAt: Date?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case settlementYear = "settlement_year"
        case settlementMonth = "settlement_month"
        case totalGrossRevenue = "total_gross_revenue"
        case totalPlatformFee = "total_platform_fee"
        case totalCreatorEarnings = "total_creator_earnings"
        case subscriptionRevenue = "subscription_revenue"
        case donationRevenue = "donation_revenue"
        case paidReadingRevenue = "paid_reading_revenue"
        case bonusRevenue = "bonus_revenue"
        case status
        case processedAt = "processed_at"
        case paidAt = "paid_at"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        authorId: UUID,
        settlementYear: Int,
        settlementMonth: Int,
        totalGrossRevenue: Int = 0,
        totalPlatformFee: Int = 0,
        totalCreatorEarnings: Int = 0,
        subscriptionRevenue: Int = 0,
        donationRevenue: Int = 0,
        paidReadingRevenue: Int = 0,
        bonusRevenue: Int = 0,
        status: SettlementStatus = .pending,
        processedAt: Date? = nil,
        paidAt: Date? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.settlementYear = settlementYear
        self.settlementMonth = settlementMonth
        self.totalGrossRevenue = totalGrossRevenue
        self.totalPlatformFee = totalPlatformFee
        self.totalCreatorEarnings = totalCreatorEarnings
        self.subscriptionRevenue = subscriptionRevenue
        self.donationRevenue = donationRevenue
        self.paidReadingRevenue = paidReadingRevenue
        self.bonusRevenue = bonusRevenue
        self.status = status.rawValue
        self.processedAt = processedAt
        self.paidAt = paidAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 結算狀態
enum SettlementStatus: String, CaseIterable {
    case pending = "pending"      // 待處理
    case processing = "processing"  // 處理中
    case completed = "completed"   // 已完成
    case paid = "paid"            // 已支付
    case failed = "failed"        // 失敗
    case cancelled = "cancelled"   // 已取消
    
    var displayName: String {
        switch self {
        case .pending: return "待處理"
        case .processing: return "處理中"
        case .completed: return "已完成"
        case .paid: return "已支付"
        case .failed: return "失敗"
        case .cancelled: return "已取消"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "#FFC107"     // 黃色
        case .processing: return "#007BFF"  // 藍色
        case .completed: return "#28A745"   // 綠色
        case .paid: return "#00B900"        // 品牌綠色
        case .failed: return "#DC3545"      // 紅色
        case .cancelled: return "#6C757D"   // 灰色
        }
    }
}

// MARK: - 結算擴展
extension MonthlySettlement {
    var settlementStatus: SettlementStatus {
        SettlementStatus(rawValue: status) ?? .pending
    }
    
    var settlementPeriod: String {
        return "\(settlementYear)年\(settlementMonth)月"
    }
    
    var formattedTotalEarnings: String {
        return "NT$\(totalCreatorEarnings)"
    }
    
    var formattedGrossRevenue: String {
        return "NT$\(totalGrossRevenue)"
    }
    
    var formattedPlatformFee: String {
        return "NT$\(totalPlatformFee)"
    }
    
    var isEligibleForWithdrawal: Bool {
        return totalCreatorEarnings >= 100000  // NT$1,000 = 100000 分
    }
    
    var revenueBreakdown: [(String, Int)] {
        return [
            ("訂閱收益", subscriptionRevenue),
            ("抖內收益", donationRevenue),
            ("付費閱讀", paidReadingRevenue),
            ("獎金收益", bonusRevenue)
        ].filter { $0.1 > 0 }
    }
}

// MARK: - 結算匯總資料
struct SettlementSummary: Codable {
    let totalEarnings: Int
    let averageMonthlyEarnings: Int
    let totalSubscriptionRevenue: Int
    let totalDonationRevenue: Int
    let totalPaidReadingRevenue: Int
    let totalBonusRevenue: Int
    let monthCount: Int
    let lastSettlementDate: Date?
    
    var formattedTotalEarnings: String {
        return "NT$\(totalEarnings)"
    }
    
    var formattedAverageMonthlyEarnings: String {
        return "NT$\(averageMonthlyEarnings)"
    }
}