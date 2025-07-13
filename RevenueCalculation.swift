import Foundation

// MARK: - 收益計算記錄模型
struct RevenueCalculation: Identifiable, Codable {
    let id: UUID
    let authorId: UUID
    let articleId: UUID?
    let calculationType: String
    let grossAmount: Int  // 總收入金額（分）
    let platformFee: Int  // 平台抽成金額（分）
    let creatorAmount: Int  // 創作者收益金額（分）
    let feeRate: Double  // 抽成比例
    let calculationDate: Date
    let settlementId: UUID?
    let metadata: String?  // JSON 格式的額外資料
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case articleId = "article_id"
        case calculationType = "calculation_type"
        case grossAmount = "gross_amount"
        case platformFee = "platform_fee"
        case creatorAmount = "creator_amount"
        case feeRate = "fee_rate"
        case calculationDate = "calculation_date"
        case settlementId = "settlement_id"
        case metadata
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        authorId: UUID,
        articleId: UUID? = nil,
        calculationType: RevenueCalculationType,
        grossAmount: Int,
        feeRate: Double,
        calculationDate: Date = Date(),
        settlementId: UUID? = nil,
        metadata: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.articleId = articleId
        self.calculationType = calculationType.rawValue
        self.grossAmount = grossAmount
        self.feeRate = feeRate
        self.platformFee = Int(Double(grossAmount) * feeRate)
        self.creatorAmount = grossAmount - self.platformFee
        self.calculationDate = calculationDate
        self.settlementId = settlementId
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - 收益計算類型
enum RevenueCalculationType: String, CaseIterable {
    case subscription = "subscription"  // 訂閱分潤
    case donation = "donation"         // 抖內收益
    case paidReading = "paid_reading"  // 付費閱讀
    case bonus = "bonus"               // 額外獎金
    
    var displayName: String {
        switch self {
        case .subscription: return "訂閱分潤"
        case .donation: return "抖內收益"
        case .paidReading: return "付費閱讀"
        case .bonus: return "額外獎金"
        }
    }
    
    var platformFeeRate: Double {
        switch self {
        case .subscription, .paidReading: return 0.30  // 30% 平台抽成
        case .donation: return 0.10  // 10% 平台抽成
        case .bonus: return 0.0  // 無抽成
        }
    }
    
    var creatorRate: Double {
        return 1.0 - platformFeeRate
    }
}

// MARK: - 收益計算擴展
extension RevenueCalculation {
    var type: RevenueCalculationType {
        RevenueCalculationType(rawValue: calculationType) ?? .subscription
    }
    
    var formattedGrossAmount: String {
        return "NT$\(grossAmount)"
    }
    
    var formattedCreatorAmount: String {
        return "NT$\(creatorAmount)"
    }
    
    var formattedPlatformFee: String {
        return "NT$\(platformFee)"
    }
    
    var feeRatePercentage: String {
        return String(format: "%.1f%%", feeRate * 100)
    }
}