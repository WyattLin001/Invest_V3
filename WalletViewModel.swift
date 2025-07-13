import SwiftUI
import Foundation

@MainActor
class WalletViewModel: ObservableObject {
    @Published var balance: Double = 0.0 {
        didSet {
            // 確保 balance 始終是有效數值
            if balance.isNaN || !balance.isFinite {
                print("⚠️ [WalletViewModel] 檢測到無效 balance 值: \(balance)，重置為 0")
                balance = 0.0
            }
        }
    }
    @Published var transactions: [WalletTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showDepositSheet = false
    @Published var showWithdrawalSheet = false
    @Published var showSubscriptionSheet = false
    @Published var isSubscribed = false
    @Published var isCreator = false
    @Published var withdrawableAmount: Double = 0.0 {
        didSet {
            // 確保 withdrawableAmount 始終是有效數值
            if withdrawableAmount.isNaN || !withdrawableAmount.isFinite {
                print("⚠️ [WalletViewModel] 檢測到無效 withdrawableAmount 值: \(withdrawableAmount)，重置為 0")
                withdrawableAmount = 0.0
            }
        }
    }
    @Published var gifts: [GiftItem] = GiftItem.defaultGifts
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        // 確保初始值是安全的
        self.balance = 0.0
        self.withdrawableAmount = 0.0
        print("✅ [WalletViewModel] 初始化完成，balance: \(balance)")
    }
    
    // MARK: - 初始化資料
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 載入錢包餘額和交易記錄
            async let balanceTask = loadBalance()
            async let transactionsTask = loadTransactions()
            
            try await balanceTask
            try await transactionsTask
            
        } catch {
            errorMessage = "載入資料失敗: \(error.localizedDescription)"
            print("WalletViewModel loadData error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 載入餘額
    private func loadBalance() async throws {
        do {
            // 從 Supabase 獲取真實餘額
            let walletBalance = try await supabaseService.fetchWalletBalance()
            
            // 確保獲取的餘額是有效數值
            if walletBalance >= 0 {
                self.balance = Double(walletBalance)
                print("✅ [WalletViewModel] 載入餘額成功: \(walletBalance) NTD")
            } else {
                print("⚠️ [WalletViewModel] 獲取到無效餘額: \(walletBalance)，使用預設值")
                self.balance = 10000.0
            }
        } catch {
            print("❌ [WalletViewModel] 載入餘額失敗: \(error)")
            // 使用模擬資料作為後備
            self.balance = 10000.0 // 初始餘額 10000 NTD
        }
    }
    
    // MARK: - 充值功能
    func topUp10K() async {
        do {
            try await supabaseService.updateWalletBalance(delta: 10000)
            await MainActor.run {
                self.balance += 10000
                print("✅ [WalletViewModel] 充值成功: 餘額增加 10000 NTD")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "充值失敗: \(error.localizedDescription)"
                print("❌ [WalletViewModel] 充值失敗: \(error)")
            }
        }
    }
    
    // MARK: - 載入交易記錄
    private func loadTransactions() async throws {
        // 模擬資料，實際應該從 Supabase 獲取
        self.transactions = [
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.deposit.rawValue,
                amount: 1000,
                description: "儲值",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "apple_pay",
                blockchainId: nil,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.giftPurchase.rawValue,
                amount: 100,
                description: "購買花束",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.subscription.rawValue,
                amount: 300,
                description: "月費訂閱",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                createdAt: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    // MARK: - 購買禮物
    func purchaseGift(_ gift: GiftItem) async {
        guard balance >= gift.price else {
            errorMessage = "餘額不足"
            return
        }
        
        do {
            // 調用 Supabase 服務創建交易
            _ = try await supabaseService.createTipTransaction(
                recipientId: UUID(), // 這裡應該是實際的接收者 ID
                amount: gift.price,
                groupId: UUID() // 這裡應該是實際的群組 ID
            )
            
            // 扣除餘額
            balance -= gift.price
            
            // 創建本地交易記錄
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.giftPurchase.rawValue,
                amount: Int(gift.price),
                description: "購買\(gift.name)",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("✅ [WalletViewModel] 購買禮物成功: \(gift.name)")
            
        } catch {
            errorMessage = "購買失敗: \(error.localizedDescription)"
            print("❌ [WalletViewModel] 購買禮物失敗: \(error)")
        }
    }
    
    // MARK: - 儲值
    func deposit(amount: Double) async {
        do {
            balance += amount
            
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.deposit.rawValue,
                amount: Int(amount),
                description: "儲值",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "apple_pay",
                blockchainId: nil,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("儲值: \(amount)")
            
        } catch {
            errorMessage = "儲值失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 提領
    func withdraw(amount: Double) async {
        guard balance >= amount else {
            errorMessage = "餘額不足"
            return
        }
        
        do {
            balance -= amount
            
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.withdrawal.rawValue,
                amount: Int(amount),
                description: "提領",
                status: TransactionStatus.pending.rawValue,
                paymentMethod: "bank_transfer",
                blockchainId: nil,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("提領: \(amount)")
            
        } catch {
            errorMessage = "提領失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 訂閱
    func subscribe() async {
        let subscriptionFee: Double = 300
        
        guard balance >= subscriptionFee else {
            errorMessage = "餘額不足"
            return
        }
        
        do {
            balance -= subscriptionFee
            
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: TransactionType.subscription.rawValue,
                amount: Int(subscriptionFee),
                description: "月費訂閱",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("訂閱成功")
            
        } catch {
            errorMessage = "訂閱失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 提領處理
    func processWithdrawal() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 這裡應該實現實際的提領邏輯
            // 目前只是模擬
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延遲
            
            // 模擬提領成功
            withdrawableAmount = 0.0
            
        } catch {
            errorMessage = "提領失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - 測試功能
    func simulateUserSwitch() async {
        print("🔄 [WalletViewModel] 模擬用戶切換，重新載入餘額...")
        await loadData()
    }
} 