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
    @Published var subscriptionExpiryDate: Date?
    @Published var subscriptionPlan: String = "monthly"
    @Published var isCreator = true // 設定為 true 以便測試創作者功能
    @Published var withdrawableAmount: Double = 0.0 {
        didSet {
            // 確保 withdrawableAmount 始終是有效數值
            if withdrawableAmount.isNaN || !withdrawableAmount.isFinite {
                print("⚠️ [WalletViewModel] 檢測到無效 withdrawableAmount 值: \(withdrawableAmount)，重置為 0")
                withdrawableAmount = 0.0
            }
        }
    }
    @Published var gifts: [Gift] = [] // 禮物功能已刪除，改為抖內功能
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        // 確保初始值是安全的
        self.balance = 0.0
        self.withdrawableAmount = 0.0
        print("✅ [WalletViewModel] 初始化完成，balance: \(balance)")
        
        // 監聽錢包餘額更新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WalletBalanceUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadBalance()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 初始化資料
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // 載入錢包餘額和交易記錄
        await loadBalance()
        await loadTransactions()
        
        isLoading = false
    }
    
    // MARK: - 載入餘額
    func loadBalance() async {
        do {
            let walletBalance = try await supabaseService.fetchWalletBalance()
            
            // 確保獲取的餘額是有效數值
            let balanceDouble = Double(walletBalance)
            if balanceDouble.isFinite && !balanceDouble.isNaN && balanceDouble >= 0 {
                self.balance = balanceDouble
                print("✅ [WalletViewModel] 載入餘額成功: \(walletBalance) NTD")
            } else {
                print("⚠️ [WalletViewModel] 獲取到無效餘額: \(walletBalance)，使用預設值")
                self.balance = 0.0
            }
        } catch {
            print("❌ [WalletViewModel] 載入餘額失敗: \(error.localizedDescription)")
            self.balance = 0.0
        }
    }
    
    // MARK: - 充值功能
    func topUp10K() async {
        do {
            try await supabaseService.updateWalletBalance(delta: 10000)
            await loadBalance()
            
            await MainActor.run {
                print("✅ [WalletViewModel] 充值成功: 餘額增加 10000 NTD")
                
                // 發送通知給其他頁面更新餘額
                NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
            }
        } catch {
            await MainActor.run {
                print("❌ [WalletViewModel] 充值失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 測試充值功能
    func performTestTopUp(tokens: Int) async {
        let amountNTD = Double(tokens * 100) // 1 代幣 = 100 NTD
        
        do {
            // 實際更新 Supabase 餘額
            try await supabaseService.updateWalletBalance(delta: Int(amountNTD))
            
            // 重新載入餘額以確保同步
            await loadBalance()
            
            await MainActor.run {
                print("✅ [WalletViewModel] 測試充值成功: 增加 \(tokens) 代幣 (\(amountNTD) NTD)")
            }
            
            // 發送通知給其他頁面更新餘額
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
            
        } catch {
            await MainActor.run {
                print("❌ [WalletViewModel] 測試充值失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 載入交易記錄
    private func loadTransactions() async {
        do {
            // 從 Supabase 載入真實的交易記錄（最近5筆）
            let fetchedTransactions = try await supabaseService.fetchUserTransactions(limit: 5)
            self.transactions = fetchedTransactions
            print("✅ [WalletViewModel] 載入交易記錄成功: \(fetchedTransactions.count) 筆")
        } catch {
            print("❌ [WalletViewModel] 載入交易記錄失敗: \(error.localizedDescription)")
            // 發生錯誤時使用模擬資料作為後備
            self.transactions = createMockTransactions()
        }
    }
    
    // 創建模擬交易記錄（作為後備）
    private func createMockTransactions() -> [WalletTransaction] {
        return [
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: "deposit",
                amount: 1000,
                description: "儲值",
                status: "confirmed",
                paymentMethod: "apple_pay",
                blockchainId: nil as String?,
                recipientId: nil as String?,
                groupId: nil as String?,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: "tip",
                amount: 100,
                description: "抖內給用戶",
                status: "confirmed",
                paymentMethod: "wallet",
                blockchainId: nil as String?,
                recipientId: UUID().uuidString,
                groupId: UUID().uuidString,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: "subscription",
                amount: 300,
                description: "月費訂閱",
                status: "confirmed",
                paymentMethod: "wallet",
                blockchainId: nil as String?,
                recipientId: nil as String?,
                groupId: nil as String?,
                createdAt: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    // MARK: - 抖內功能
    func sendTip(recipientId: UUID, amount: Double, groupId: UUID) async {
        guard balance >= amount else {
            errorMessage = "餘額不足"
            return
        }
        
        do {
            // 扣除餘額
            balance -= amount
            
            // 創建本地交易記錄
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: "tip",
                amount: Int(amount),
                description: "抖內給用戶",
                status: "confirmed",
                paymentMethod: "wallet",
                blockchainId: nil as String?,
                recipientId: recipientId.uuidString,
                groupId: groupId.uuidString,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("✅ [WalletViewModel] 抖內成功: \(amount) 代幣")
            
        } catch {
            errorMessage = "抖內失敗: \(error.localizedDescription)"
            print("❌ [WalletViewModel] 抖內失敗: \(error)")
        }
    }
    
    // MARK: - 儲值
    func deposit(amount: Double) async {
        do {
            balance += amount
            
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: "deposit",
                amount: Int(amount),
                description: "儲值",
                status: "confirmed",
                paymentMethod: "apple_pay",
                blockchainId: nil as String?,
                recipientId: nil as String?,
                groupId: nil as String?,
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
                transactionType: "withdrawal",
                amount: Int(amount),
                description: "提領",
                status: "pending",
                paymentMethod: "bank_transfer",
                blockchainId: nil as String?,
                recipientId: nil as String?,
                groupId: nil as String?,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("提領: \(amount)")
            
        } catch {
            errorMessage = "提領失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 訂閱
    func subscribe(plan: String = "monthly") async {
        let subscriptionFee: Double = plan == "monthly" ? 300 : 3000 // 年費
        
        guard balance >= subscriptionFee else {
            errorMessage = "餘額不足"
            return
        }
        
        do {
            balance -= subscriptionFee
            isSubscribed = true
            subscriptionPlan = plan
            
            // 設定到期日
            let calendar = Calendar.current
            if plan == "monthly" {
                subscriptionExpiryDate = calendar.date(byAdding: .month, value: 1, to: Date())
            } else {
                subscriptionExpiryDate = calendar.date(byAdding: .year, value: 1, to: Date())
            }
            
            let transaction = WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: "subscription",
                amount: Int(subscriptionFee),
                description: plan == "monthly" ? "月費訂閱" : "年費訂閱",
                status: "confirmed",
                paymentMethod: "wallet",
                blockchainId: nil as String?,
                recipientId: nil as String?,
                groupId: nil as String?,
                createdAt: Date()
            )
            
            transactions.insert(transaction, at: 0)
            
            print("✅ [WalletViewModel] 訂閱成功: \(plan)")
            
        } catch {
            errorMessage = "訂閱失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 取消訂閱
    func cancelSubscription() async {
        isSubscribed = false
        subscriptionExpiryDate = nil
        subscriptionPlan = ""
        
        print("✅ [WalletViewModel] 訂閱已取消")
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
} 