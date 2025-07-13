import Foundation
import Supabase

// MARK: - 錢包結算整合服務
@MainActor
class WalletSettlementIntegrationService: ObservableObject {
    private let supabase = SupabaseManager.shared
    private let revenueService = RevenueCalculationService()
    private let settlementService = MonthlySettlementService()
    private let notificationService = SettlementNotificationService.shared
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - 處理訂閱付款並計算收益
    func processSubscriptionPayment(
        subscriberId: UUID,
        authorId: UUID,
        amount: Int,
        subscriptionId: UUID
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        // 1. 創建錢包交易記錄
        let walletTransaction = WalletTransaction(
            id: UUID(),
            userId: subscriberId,
            transactionType: TransactionType.subscription.rawValue,
            amount: -amount, // 負數表示支出
            description: "訂閱付費",
            status: TransactionStatus.confirmed.rawValue,
            paymentMethod: "wallet",
            blockchainId: nil,
            createdAt: Date()
        )
        
        try await client
            .from("wallet_transactions")
            .insert(walletTransaction)
            .execute()
        
        // 2. 更新用戶餘額
        try await updateUserBalance(userId: subscriberId, amount: -amount)
        
        // 3. 計算創作者收益
        let _ = try await revenueService.calculateSubscriptionRevenue(
            authorId: authorId,
            subscriptionAmount: amount,
            subscriberCount: 1,
            readingDistribution: [:] // 這裡需要實際的閱讀分佈數據
        )
        
        // 4. 檢查收益里程碑
        await checkRevenueMilestones(authorId: authorId, newAmount: amount)
    }
    
    // MARK: - 處理抖內付款
    func processDonationPayment(
        donorId: UUID,
        authorId: UUID,
        amount: Int,
        giftType: DonationGiftType,
        articleId: UUID? = nil,
        message: String? = nil,
        isAnonymous: Bool = false
    ) async throws -> DonationTransaction {
        isLoading = true
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        // 1. 創建抖內交易記錄
        let donationTransaction = DonationTransaction(
            donorId: donorId,
            authorId: authorId,
            articleId: articleId,
            amount: amount,
            giftType: giftType,
            message: message,
            isAnonymous: isAnonymous,
            status: .processing
        )
        
        try await client
            .from("donation_transactions")
            .insert(donationTransaction)
            .execute()
        
        // 2. 創建錢包交易記錄（打賞者）
        let donorTransaction = WalletTransaction(
            id: UUID(),
            userId: donorId,
            transactionType: TransactionType.tip.rawValue,
            amount: -amount, // 負數表示支出
            description: "抖內打賞",
            status: TransactionStatus.confirmed.rawValue,
            paymentMethod: "wallet",
            blockchainId: nil,
            createdAt: Date()
        )
        
        try await client
            .from("wallet_transactions")
            .insert(donorTransaction)
            .execute()
        
        // 3. 更新打賞者餘額
        try await updateUserBalance(userId: donorId, amount: -amount)
        
        // 4. 計算創作者收益
        let _ = try await revenueService.calculateDonationRevenue(
            authorId: authorId,
            donationAmount: amount,
            articleId: articleId
        )
        
        // 5. 更新抖內交易狀態
        try await updateDonationTransactionStatus(
            transactionId: donationTransaction.id,
            status: .completed
        )
        
        // 6. 檢查收益里程碑
        await checkRevenueMilestones(authorId: authorId, newAmount: donationTransaction.authorAmount)
        
        return donationTransaction
    }
    
    // MARK: - 處理提領申請
    func processWithdrawalRequest(
        userId: UUID,
        requestId: UUID,
        approved: Bool,
        adminNotes: String? = nil
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        // 1. 獲取提領申請
        let requests: [WithdrawalRequest] = try await client
            .from("withdrawal_requests")
            .select()
            .eq("id", value: requestId)
            .execute()
            .value
        
        guard let request = requests.first else {
            throw IntegrationError.withdrawalRequestNotFound
        }
        
        if approved {
            // 2. 創建錢包交易記錄
            let walletTransaction = WalletTransaction(
                id: UUID(),
                userId: userId,
                transactionType: TransactionType.withdrawal.rawValue,
                amount: -request.actualAmount, // 負數表示支出
                description: "提領",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: request.paymentMethod,
                blockchainId: nil,
                createdAt: Date()
            )
            
            try await client
                .from("wallet_transactions")
                .insert(walletTransaction)
                .execute()
            
            // 3. 更新用戶餘額
            try await updateUserBalance(userId: userId, amount: -request.actualAmount)
            
            // 4. 更新提領申請狀態
            try await updateWithdrawalRequestStatus(
                requestId: requestId,
                status: .completed,
                adminNotes: adminNotes
            )
            
            // 5. 發送提領完成通知
            await notificationService.sendWithdrawalCompletedNotification(request: request)
            
        } else {
            // 拒絕提領申請
            try await updateWithdrawalRequestStatus(
                requestId: requestId,
                status: .rejected,
                adminNotes: adminNotes
            )
        }
    }
    
    // MARK: - 同步用戶餘額
    func syncUserBalance(userId: UUID) async throws -> UserBalance {
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        // 1. 計算總收入
        let incomeTransactions: [WalletTransaction] = try await client
            .from("wallet_transactions")
            .select()
            .eq("user_id", value: userId)
            .in("transaction_type", values: [TransactionType.deposit.rawValue, TransactionType.bonus.rawValue])
            .eq("status", value: TransactionStatus.confirmed.rawValue)
            .execute()
            .value
        
        let totalIncome = incomeTransactions.reduce(0) { $0 + $1.amount }
        
        // 2. 計算總支出
        let expenseTransactions: [WalletTransaction] = try await client
            .from("wallet_transactions")
            .select()
            .eq("user_id", value: userId)
            .in("transaction_type", values: [TransactionType.withdrawal.rawValue, TransactionType.giftPurchase.rawValue, TransactionType.subscription.rawValue, TransactionType.tip.rawValue])
            .eq("status", value: TransactionStatus.confirmed.rawValue)
            .execute()
            .value
        
        let totalExpense = expenseTransactions.reduce(0) { $0 + abs($1.amount) }
        
        // 3. 計算當前餘額
        let currentBalance = totalIncome - totalExpense
        
        // 4. 計算可提領餘額（扣除未完成的提領申請）
        let pendingWithdrawals: [WithdrawalRequest] = try await client
            .from("withdrawal_requests")
            .select()
            .eq("user_id", value: userId)
            .in("status", values: [WithdrawalStatus.pending.rawValue, WithdrawalStatus.approved.rawValue, WithdrawalStatus.processing.rawValue])
            .execute()
            .value
        
        let pendingAmount = pendingWithdrawals.reduce(0) { $0 + $1.requestAmount }
        let withdrawableAmount = max(0, currentBalance - pendingAmount)
        
        // 5. 更新或創建用戶餘額記錄
        let userBalance = UserBalance(
            id: UUID(),
            userId: userId,
            balance: currentBalance,
            withdrawableAmount: withdrawableAmount,
            updatedAt: Date()
        )
        
        // 先嘗試更新現有記錄
        let existingBalances: [UserBalance] = try await client
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let existingBalance = existingBalances.first {
            // 更新現有記錄
            let updatedBalance = [
                "balance": currentBalance,
                "withdrawable_amount": withdrawableAmount,
                "updated_at": Date().ISO8601Format()
            ]
            
            try await client
                .from("user_balances")
                .update(updatedBalance)
                .eq("id", value: existingBalance.id)
                .execute()
        } else {
            // 創建新記錄
            try await client
                .from("user_balances")
                .insert(userBalance)
                .execute()
        }
        
        return userBalance
    }
    
    // MARK: - 獲取用戶餘額
    func getUserBalance(userId: UUID) async throws -> UserBalance? {
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        let balances: [UserBalance] = try await client
            .from("user_balances")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return balances.first
    }
    
    // MARK: - 私有方法
    private func updateUserBalance(userId: UUID, amount: Int) async throws {
        // 同步用戶餘額
        let _ = try await syncUserBalance(userId: userId)
    }
    
    private func updateDonationTransactionStatus(
        transactionId: UUID,
        status: DonationStatus
    ) async throws {
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        let update = [
            "status": status.rawValue,
            "processed_at": Date().ISO8601Format(),
            "updated_at": Date().ISO8601Format()
        ]
        
        try await client
            .from("donation_transactions")
            .update(update)
            .eq("id", value: transactionId)
            .execute()
    }
    
    private func updateWithdrawalRequestStatus(
        requestId: UUID,
        status: WithdrawalStatus,
        adminNotes: String? = nil
    ) async throws {
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        var update: [String: Any] = [
            "status": status.rawValue,
            "updated_at": Date().ISO8601Format()
        ]
        
        if let adminNotes = adminNotes {
            update["admin_notes"] = adminNotes
        }
        
        switch status {
        case .completed:
            update["completed_at"] = Date().ISO8601Format()
        case .rejected:
            update["rejected_at"] = Date().ISO8601Format()
        case .processing:
            update["processed_at"] = Date().ISO8601Format()
        default:
            break
        }
        
        try await client
            .from("withdrawal_requests")
            .update(update)
            .eq("id", value: requestId)
            .execute()
    }
    
    private func checkRevenueMilestones(authorId: UUID, newAmount: Int) async {
        do {
            // 獲取之前的總收益
            let earnings = try await CreatorRevenueService().getCreatorEarnings(authorId: authorId)
            let previousAmount = earnings.totalEarnings - newAmount
            
            // 檢查里程碑
            let milestones = RevenueMilestone.checkMilestones(
                currentAmount: earnings.totalEarnings,
                previousAmount: previousAmount
            )
            
            // 發送里程碑通知
            for milestone in milestones {
                await notificationService.sendRevenueMilestoneNotification(milestone: milestone)
            }
        } catch {
            print("檢查收益里程碑失敗: \(error)")
        }
    }
}

// MARK: - 整合錯誤類型
enum IntegrationError: LocalizedError {
    case supabaseNotInitialized
    case withdrawalRequestNotFound
    case insufficientBalance
    case invalidTransaction
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .supabaseNotInitialized:
            return "Supabase 未初始化"
        case .withdrawalRequestNotFound:
            return "提領申請不存在"
        case .insufficientBalance:
            return "餘額不足"
        case .invalidTransaction:
            return "無效的交易"
        case .userNotFound:
            return "用戶不存在"
        }
    }
}

// MARK: - 錢包整合擴展
extension WalletSettlementIntegrationService {
    
    // MARK: - 批量處理月度結算
    func processBatchMonthlySettlement(authorIds: [UUID], year: Int, month: Int) async throws {
        for authorId in authorIds {
            do {
                let settlement = try await settlementService.processMonthlySettlement(
                    authorId: authorId,
                    year: year,
                    month: month
                )
                
                // 發送結算完成通知
                await notificationService.sendSettlementCompletedNotification(settlement: settlement)
                
                // 如果符合條件，自動處理提領
                if settlement.isEligibleForWithdrawal {
                    try await autoProcessWithdrawal(authorId: authorId, settlement: settlement)
                }
                
            } catch {
                print("處理創作者 \(authorId) 的月度結算失敗: \(error)")
                continue
            }
        }
    }
    
    // MARK: - 自動處理提領
    private func autoProcessWithdrawal(authorId: UUID, settlement: MonthlySettlement) async throws {
        // 這裡可以實現自動提領邏輯
        // 例如：如果用戶開啟了自動提領設置，則自動創建提領申請
        print("自動提領邏輯：創作者 \(authorId)，結算 \(settlement.id)")
    }
    
    // MARK: - 獲取用戶財務概覽
    func getUserFinancialOverview(userId: UUID) async throws -> UserFinancialOverview {
        let balance = try await getUserBalance(userId: userId)
        let earnings = try await CreatorRevenueService().getCreatorEarnings(authorId: userId)
        let recentTransactions = try await getRecentTransactions(userId: userId, limit: 10)
        let recentWithdrawals = try await getRecentWithdrawals(userId: userId, limit: 5)
        
        return UserFinancialOverview(
            balance: balance,
            earnings: earnings,
            recentTransactions: recentTransactions,
            recentWithdrawals: recentWithdrawals
        )
    }
    
    private func getRecentTransactions(userId: UUID, limit: Int) async throws -> [WalletTransaction] {
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        let transactions: [WalletTransaction] = try await client
            .from("wallet_transactions")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return transactions
    }
    
    private func getRecentWithdrawals(userId: UUID, limit: Int) async throws -> [WithdrawalRequest] {
        guard let client = supabase.client else {
            throw IntegrationError.supabaseNotInitialized
        }
        
        let withdrawals: [WithdrawalRequest] = try await client
            .from("withdrawal_requests")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return withdrawals
    }
}

// MARK: - 用戶財務概覽
struct UserFinancialOverview {
    let balance: UserBalance?
    let earnings: CreatorEarnings
    let recentTransactions: [WalletTransaction]
    let recentWithdrawals: [WithdrawalRequest]
    
    var totalBalance: Int {
        return balance?.balance ?? 0
    }
    
    var withdrawableAmount: Int {
        return balance?.withdrawableAmount ?? 0
    }
    
    var formattedTotalBalance: String {
        return "NT$\(totalBalance / 100)"
    }
    
    var formattedWithdrawableAmount: String {
        return "NT$\(withdrawableAmount / 100)"
    }
}