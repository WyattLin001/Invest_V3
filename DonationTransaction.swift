import Foundation

// MARK: - 抖內交易記錄模型
struct DonationTransaction: Identifiable, Codable {
    let id: UUID
    let donorId: UUID           // 打賞者 ID
    let authorId: UUID          // 作者 ID
    let articleId: UUID?        // 文章 ID（可選）
    let amount: Int             // 打賞金額（分）
    let platformFee: Int        // 平台抽成（分）
    let authorAmount: Int       // 作者收益（分）
    let giftType: String        // 禮物類型
    let message: String?        // 打賞留言
    let isAnonymous: Bool       // 是否匿名
    let status: String          // 交易狀態
    let processedAt: Date?      // 處理時間
    let settlementId: UUID?     // 結算 ID
    let createdAt: Date         // 創建時間
    let updatedAt: Date         // 更新時間
    
    enum CodingKeys: String, CodingKey {
        case id
        case donorId = "donor_id"
        case authorId = "author_id"
        case articleId = "article_id"
        case amount
        case platformFee = "platform_fee"
        case authorAmount = "author_amount"
        case giftType = "gift_type"
        case message
        case isAnonymous = "is_anonymous"
        case status
        case processedAt = "processed_at"
        case settlementId = "settlement_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        donorId: UUID,
        authorId: UUID,
        articleId: UUID? = nil,
        amount: Int,
        giftType: DonationGiftType = .flower,
        message: String? = nil,
        isAnonymous: Bool = false,
        status: DonationStatus = .pending,
        processedAt: Date? = nil,
        settlementId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.donorId = donorId
        self.authorId = authorId
        self.articleId = articleId
        self.amount = amount
        self.platformFee = Int(Double(amount) * 0.1)  // 10% 平台抽成
        self.authorAmount = amount - self.platformFee
        self.giftType = giftType.rawValue
        self.message = message
        self.isAnonymous = isAnonymous
        self.status = status.rawValue
        self.processedAt = processedAt
        self.settlementId = settlementId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 抖內禮物類型
enum DonationGiftType: String, CaseIterable {
    case flower = "flower"      // 花束 - NT$100
    case coffee = "coffee"      // 咖啡 - NT$200
    case cake = "cake"          // 蛋糕 - NT$500
    case rocket = "rocket"      // 火箭 - NT$1000
    case diamond = "diamond"    // 鑽石 - NT$2000
    case crown = "crown"        // 皇冠 - NT$5000
    
    var displayName: String {
        switch self {
        case .flower: return "花束"
        case .coffee: return "咖啡"
        case .cake: return "蛋糕"
        case .rocket: return "火箭"
        case .diamond: return "鑽石"
        case .crown: return "皇冠"
        }
    }
    
    var emoji: String {
        switch self {
        case .flower: return "💐"
        case .coffee: return "☕"
        case .cake: return "🍰"
        case .rocket: return "🚀"
        case .diamond: return "💎"
        case .crown: return "👑"
        }
    }
    
    var price: Int {
        switch self {
        case .flower: return 10000    // NT$100 = 10000 分
        case .coffee: return 20000    // NT$200 = 20000 分
        case .cake: return 50000      // NT$500 = 50000 分
        case .rocket: return 100000   // NT$1000 = 100000 分
        case .diamond: return 200000  // NT$2000 = 200000 分
        case .crown: return 500000    // NT$5000 = 500000 分
        }
    }
    
    var formattedPrice: String {
        return "NT$\(price / 100)"
    }
    
    var description: String {
        switch self {
        case .flower: return "表達支持的小花束"
        case .coffee: return "請作者喝杯咖啡"
        case .cake: return "甜蜜的蛋糕祝福"
        case .rocket: return "衝上雲霄的火箭"
        case .diamond: return "珍貴的鑽石讚賞"
        case .crown: return "最高級的皇冠榮耀"
        }
    }
}

// MARK: - 抖內交易狀態
enum DonationStatus: String, CaseIterable {
    case pending = "pending"        // 待處理
    case processing = "processing"  // 處理中
    case completed = "completed"    // 已完成
    case failed = "failed"          // 失敗
    case refunded = "refunded"      // 已退款
    case cancelled = "cancelled"    // 已取消
    
    var displayName: String {
        switch self {
        case .pending: return "待處理"
        case .processing: return "處理中"
        case .completed: return "已完成"
        case .failed: return "失敗"
        case .refunded: return "已退款"
        case .cancelled: return "已取消"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "#FFC107"     // 黃色
        case .processing: return "#007BFF"  // 藍色
        case .completed: return "#28A745"   // 綠色
        case .failed: return "#DC3545"      // 紅色
        case .refunded: return "#FD7E14"    // 橙色
        case .cancelled: return "#6C757D"   // 灰色
        }
    }
}

// MARK: - 抖內交易擴展
extension DonationTransaction {
    var gift: DonationGiftType {
        DonationGiftType(rawValue: giftType) ?? .flower
    }
    
    var donationStatus: DonationStatus {
        DonationStatus(rawValue: status) ?? .pending
    }
    
    var formattedAmount: String {
        return "NT$\(amount / 100)"
    }
    
    var formattedAuthorAmount: String {
        return "NT$\(authorAmount / 100)"
    }
    
    var formattedPlatformFee: String {
        return "NT$\(platformFee / 100)"
    }
    
    var platformFeeRate: Double {
        return 0.1  // 10%
    }
    
    var authorRate: Double {
        return 0.9  // 90%
    }
    
    var formattedPlatformFeeRate: String {
        return String(format: "%.1f%%", platformFeeRate * 100)
    }
    
    var formattedAuthorRate: String {
        return String(format: "%.1f%%", authorRate * 100)
    }
    
    var isProcessed: Bool {
        return donationStatus == .completed
    }
}

// MARK: - 抖內統計
struct DonationStatistics: Identifiable, Codable {
    let id: UUID
    let authorId: UUID
    let totalDonations: Int         // 總抖內次數
    let totalAmount: Int            // 總抖內金額（分）
    let totalAuthorAmount: Int      // 總作者收益（分）
    let totalPlatformFee: Int       // 總平台抽成（分）
    let uniqueDonors: Int           // 獨特打賞者數
    let averageDonationAmount: Int  // 平均打賞金額（分）
    let topGiftType: String         // 最受歡迎禮物
    let thisMonthDonations: Int     // 本月抖內次數
    let thisMonthAmount: Int        // 本月抖內金額（分）
    let lastDonationDate: Date?     // 最後抖內日期
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case totalDonations = "total_donations"
        case totalAmount = "total_amount"
        case totalAuthorAmount = "total_author_amount"
        case totalPlatformFee = "total_platform_fee"
        case uniqueDonors = "unique_donors"
        case averageDonationAmount = "average_donation_amount"
        case topGiftType = "top_gift_type"
        case thisMonthDonations = "this_month_donations"
        case thisMonthAmount = "this_month_amount"
        case lastDonationDate = "last_donation_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var formattedTotalAmount: String {
        return "NT$\(totalAmount / 100)"
    }
    
    var formattedTotalAuthorAmount: String {
        return "NT$\(totalAuthorAmount / 100)"
    }
    
    var formattedAverageDonationAmount: String {
        return "NT$\(averageDonationAmount / 100)"
    }
    
    var formattedThisMonthAmount: String {
        return "NT$\(thisMonthAmount / 100)"
    }
    
    var topGift: DonationGiftType {
        DonationGiftType(rawValue: topGiftType) ?? .flower
    }
    
    var donationRate: Double {
        // 假設有總讀者數，計算抖內率
        // 這裡需要其他數據支持
        return 0.0
    }
}

// MARK: - 抖內排行榜
struct DonationLeaderboard: Identifiable, Codable {
    let id: UUID
    let authorId: UUID
    let authorName: String
    let totalDonationsReceived: Int
    let totalAmountReceived: Int
    let rank: Int
    let period: String  // monthly, weekly, yearly
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case authorName = "author_name"
        case totalDonationsReceived = "total_donations_received"
        case totalAmountReceived = "total_amount_received"
        case rank
        case period
        case createdAt = "created_at"
    }
    
    var formattedTotalAmountReceived: String {
        return "NT$\(totalAmountReceived / 100)"
    }
    
    var periodDisplayName: String {
        switch period {
        case "monthly": return "本月"
        case "weekly": return "本週"
        case "yearly": return "本年"
        default: return "全部"
        }
    }
    
    var rankSuffix: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
}