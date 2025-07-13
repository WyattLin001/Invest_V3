import Foundation

// MARK: - 提領申請記錄模型
struct WithdrawalRequest: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let requestAmount: Int          // 申請提領金額（分）
    let actualAmount: Int           // 實際提領金額（分）
    let fee: Int                    // 手續費（分）
    let status: String              // 提領狀態
    let paymentMethod: String       // 提領方式
    let bankAccount: String?        // 銀行帳戶
    let bankCode: String?           // 銀行代碼
    let accountHolder: String?      // 戶名
    let phoneNumber: String?        // 手機號碼
    let email: String?              // 電子郵件
    let reason: String?             // 申請原因
    let adminNotes: String?         // 管理員備註
    let requestedAt: Date           // 申請時間
    let processedAt: Date?          // 處理時間
    let completedAt: Date?          // 完成時間
    let rejectedAt: Date?           // 拒絕時間
    let rejectionReason: String?    // 拒絕原因
    let transactionId: String?      // 交易 ID
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case requestAmount = "request_amount"
        case actualAmount = "actual_amount"
        case fee
        case status
        case paymentMethod = "payment_method"
        case bankAccount = "bank_account"
        case bankCode = "bank_code"
        case accountHolder = "account_holder"
        case phoneNumber = "phone_number"
        case email
        case reason
        case adminNotes = "admin_notes"
        case requestedAt = "requested_at"
        case processedAt = "processed_at"
        case completedAt = "completed_at"
        case rejectedAt = "rejected_at"
        case rejectionReason = "rejection_reason"
        case transactionId = "transaction_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        requestAmount: Int,
        paymentMethod: WithdrawalMethod = .bankTransfer,
        bankAccount: String? = nil,
        bankCode: String? = nil,
        accountHolder: String? = nil,
        phoneNumber: String? = nil,
        email: String? = nil,
        reason: String? = nil,
        adminNotes: String? = nil,
        requestedAt: Date = Date(),
        processedAt: Date? = nil,
        completedAt: Date? = nil,
        rejectedAt: Date? = nil,
        rejectionReason: String? = nil,
        transactionId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.requestAmount = requestAmount
        self.paymentMethod = paymentMethod.rawValue
        self.fee = Self.calculateFee(amount: requestAmount, method: paymentMethod)
        self.actualAmount = requestAmount - self.fee
        self.status = WithdrawalStatus.pending.rawValue
        self.bankAccount = bankAccount
        self.bankCode = bankCode
        self.accountHolder = accountHolder
        self.phoneNumber = phoneNumber
        self.email = email
        self.reason = reason
        self.adminNotes = adminNotes
        self.requestedAt = requestedAt
        self.processedAt = processedAt
        self.completedAt = completedAt
        self.rejectedAt = rejectedAt
        self.rejectionReason = rejectionReason
        self.transactionId = transactionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    private static func calculateFee(amount: Int, method: WithdrawalMethod) -> Int {
        switch method {
        case .bankTransfer:
            return 1500  // NT$15 手續費
        case .digitalWallet:
            return 1000  // NT$10 手續費
        case .cryptocurrency:
            return 500   // NT$5 手續費
        }
    }
}

// MARK: - 提領方式
enum WithdrawalMethod: String, CaseIterable {
    case bankTransfer = "bank_transfer"      // 銀行轉帳
    case digitalWallet = "digital_wallet"    // 電子錢包
    case cryptocurrency = "cryptocurrency"   // 加密貨幣
    
    var displayName: String {
        switch self {
        case .bankTransfer: return "銀行轉帳"
        case .digitalWallet: return "電子錢包"
        case .cryptocurrency: return "加密貨幣"
        }
    }
    
    var icon: String {
        switch self {
        case .bankTransfer: return "🏦"
        case .digitalWallet: return "📱"
        case .cryptocurrency: return "₿"
        }
    }
    
    var feeAmount: Int {
        switch self {
        case .bankTransfer: return 1500   // NT$15
        case .digitalWallet: return 1000  // NT$10
        case .cryptocurrency: return 500  // NT$5
        }
    }
    
    var formattedFee: String {
        return "NT$\(feeAmount / 100)"
    }
    
    var processingTime: String {
        switch self {
        case .bankTransfer: return "1-2 個工作日"
        case .digitalWallet: return "即時"
        case .cryptocurrency: return "5-30 分鐘"
        }
    }
    
    var minimumAmount: Int {
        return 100000  // NT$1,000 最低提領金額
    }
    
    var maximumAmount: Int {
        switch self {
        case .bankTransfer: return 10000000    // NT$100,000
        case .digitalWallet: return 5000000    // NT$50,000
        case .cryptocurrency: return 1000000   // NT$10,000
        }
    }
}

// MARK: - 提領狀態
enum WithdrawalStatus: String, CaseIterable {
    case pending = "pending"            // 待審核
    case approved = "approved"          // 已批准
    case processing = "processing"      // 處理中
    case completed = "completed"        // 已完成
    case failed = "failed"              // 失敗
    case rejected = "rejected"          // 已拒絕
    case cancelled = "cancelled"        // 已取消
    
    var displayName: String {
        switch self {
        case .pending: return "待審核"
        case .approved: return "已批准"
        case .processing: return "處理中"
        case .completed: return "已完成"
        case .failed: return "失敗"
        case .rejected: return "已拒絕"
        case .cancelled: return "已取消"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "#FFC107"     // 黃色
        case .approved: return "#00B900"    // 品牌綠色
        case .processing: return "#007BFF"  // 藍色
        case .completed: return "#28A745"   // 綠色
        case .failed: return "#DC3545"      // 紅色
        case .rejected: return "#FD7E14"    // 橙色
        case .cancelled: return "#6C757D"   // 灰色
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "⏳"
        case .approved: return "✅"
        case .processing: return "🔄"
        case .completed: return "✅"
        case .failed: return "❌"
        case .rejected: return "❌"
        case .cancelled: return "❌"
        }
    }
    
    var canCancel: Bool {
        switch self {
        case .pending, .approved: return true
        case .processing, .completed, .failed, .rejected, .cancelled: return false
        }
    }
}

// MARK: - 提領申請擴展
extension WithdrawalRequest {
    var withdrawalStatus: WithdrawalStatus {
        WithdrawalStatus(rawValue: status) ?? .pending
    }
    
    var withdrawalMethod: WithdrawalMethod {
        WithdrawalMethod(rawValue: paymentMethod) ?? .bankTransfer
    }
    
    var formattedRequestAmount: String {
        return "NT$\(requestAmount / 100)"
    }
    
    var formattedActualAmount: String {
        return "NT$\(actualAmount / 100)"
    }
    
    var formattedFee: String {
        return "NT$\(fee / 100)"
    }
    
    var isEligible: Bool {
        return requestAmount >= withdrawalMethod.minimumAmount && 
               requestAmount <= withdrawalMethod.maximumAmount
    }
    
    var canCancel: Bool {
        return withdrawalStatus.canCancel
    }
    
    var processingTime: String {
        return withdrawalMethod.processingTime
    }
    
    var estimatedCompletionDate: Date? {
        guard let processedAt = processedAt else { return nil }
        
        switch withdrawalMethod {
        case .bankTransfer:
            return Calendar.current.date(byAdding: .day, value: 2, to: processedAt)
        case .digitalWallet:
            return processedAt
        case .cryptocurrency:
            return Calendar.current.date(byAdding: .hour, value: 1, to: processedAt)
        }
    }
    
    var formattedEstimatedCompletionDate: String {
        guard let date = estimatedCompletionDate else { return "未知" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - 提領統計
struct WithdrawalStatistics: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let totalWithdrawals: Int       // 總提領次數
    let totalAmount: Int            // 總提領金額（分）
    let totalFees: Int              // 總手續費（分）
    let successfulWithdrawals: Int  // 成功提領次數
    let failedWithdrawals: Int      // 失敗提領次數
    let pendingWithdrawals: Int     // 待處理提領次數
    let averageAmount: Int          // 平均提領金額（分）
    let lastWithdrawalDate: Date?   // 最後提領日期
    let preferredMethod: String     // 偏好提領方式
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case totalWithdrawals = "total_withdrawals"
        case totalAmount = "total_amount"
        case totalFees = "total_fees"
        case successfulWithdrawals = "successful_withdrawals"
        case failedWithdrawals = "failed_withdrawals"
        case pendingWithdrawals = "pending_withdrawals"
        case averageAmount = "average_amount"
        case lastWithdrawalDate = "last_withdrawal_date"
        case preferredMethod = "preferred_method"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var formattedTotalAmount: String {
        return "NT$\(totalAmount / 100)"
    }
    
    var formattedTotalFees: String {
        return "NT$\(totalFees / 100)"
    }
    
    var formattedAverageAmount: String {
        return "NT$\(averageAmount / 100)"
    }
    
    var successRate: Double {
        guard totalWithdrawals > 0 else { return 0.0 }
        return Double(successfulWithdrawals) / Double(totalWithdrawals)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var preferredWithdrawalMethod: WithdrawalMethod {
        WithdrawalMethod(rawValue: preferredMethod) ?? .bankTransfer
    }
    
    var totalNetAmount: Int {
        return totalAmount - totalFees
    }
    
    var formattedTotalNetAmount: String {
        return "NT$\(totalNetAmount / 100)"
    }
    
    var averageFee: Int {
        guard totalWithdrawals > 0 else { return 0 }
        return totalFees / totalWithdrawals
    }
    
    var formattedAverageFee: String {
        return "NT$\(averageFee / 100)"
    }
}