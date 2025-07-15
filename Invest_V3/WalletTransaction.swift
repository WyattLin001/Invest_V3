import Foundation

// MARK: - 錢包交易模型
struct WalletTransaction: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let transactionType: String
    let amount: Int
    let description: String
    let status: String
    let paymentMethod: String?
    let blockchainId: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case transactionType = "transaction_type"
        case amount
        case description
        case status
        case paymentMethod = "payment_method"
        case blockchainId = "blockchain_id"
        case createdAt = "created_at"
    }
    
    // 計算屬性用於向後兼容
    var type: TransactionType {
        TransactionType(rawValue: transactionType) ?? .deposit
    }
    
    var transactionStatus: TransactionStatus {
        TransactionStatus(rawValue: status) ?? .pending
    }
}

// MARK: - 交易類型
enum TransactionType: String, Codable, CaseIterable {
    case deposit = "deposit"        // 儲值
    case withdrawal = "withdrawal"  // 提領
    case giftPurchase = "gift_purchase"  // 購買禮物
    case subscription = "subscription"   // 訂閱
    case tip = "tip"               // 抖內
    case bonus = "bonus"           // 紅利
    
    var displayName: String {
        switch self {
        case .deposit: return "儲值"
        case .withdrawal: return "提領"
        case .giftPurchase: return "購買禮物"
        case .subscription: return "訂閱"
        case .tip: return "抖內"
        case .bonus: return "紅利"
        }
    }
    
    var isIncome: Bool {
        switch self {
        case .deposit, .bonus: return true
        case .withdrawal, .giftPurchase, .subscription, .tip: return false
        }
    }
}

// MARK: - 交易狀態
enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "pending"      // 待處理
    case confirmed = "confirmed"  // 已確認
    case failed = "failed"        // 失敗
    case cancelled = "cancelled"  // 已取消
    
    var displayName: String {
        switch self {
        case .pending: return "待處理"
        case .confirmed: return "已確認"
        case .failed: return "失敗"
        case .cancelled: return "已取消"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "#FFC107"    // 黃色
        case .confirmed: return "#28A745"  // 綠色
        case .failed: return "#DC3545"     // 紅色
        case .cancelled: return "#6C757D"  // 灰色
        }
    }
}

// MARK: - 禮物類型
struct Gift: Identifiable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let price: Double
    let description: String
    
    static let flower = Gift(
        id: UUID(),
        name: "花束",
        emoji: "💐",
        price: 100,
        description: "表達支持的小花束"
    )
    
    static let rocket = Gift(
        id: UUID(),
        name: "火箭",
        emoji: "🚀",
        price: 1000,
        description: "衝上雲霄的火箭"
    )
    
    static let gold = Gift(
        id: UUID(),
        name: "黃金",
        emoji: "🏆",
        price: 5000,
        description: "最高級的黃金獎杯"
    )
    
    static let allGifts = [flower, rocket, gold]
}

// MARK: - 用戶餘額模型
struct UserBalance: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let balance: Int
    let withdrawableAmount: Int
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case balance
        case withdrawableAmount = "withdrawable_amount"
        case updatedAt = "updated_at"
    }
}