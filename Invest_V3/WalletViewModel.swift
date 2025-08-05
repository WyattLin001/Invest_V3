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
    
    // 分頁相關屬性
    @Published var currentPage = 0
    @Published var hasMoreTransactions = false
    @Published var isLoadingMore = false
    private let itemsPerPage = 10
    
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
                await self?.loadTransactions() // 同時重新載入交易記錄
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
            // 充值 10000 台幣 = 100 代幣 (10000 ÷ 100)
            let tokens = 100
            try await supabaseService.updateWalletBalance(delta: tokens)
            
            // 創建充值交易記錄
            try await supabaseService.createWalletTransaction(
                type: WalletTransactionType.deposit.rawValue,
                amount: Double(tokens), // 存儲代幣數量作為正數
                description: "充值 NT$10,000",
                paymentMethod: "test_topup"
            )
            
            // 重新載入餘額和交易記錄
            await loadBalance()
            await loadTransactions()
            
            await MainActor.run {
                print("✅ [WalletViewModel] 充值成功: 支付 NT$10,000，獲得 \(tokens) 代幣")
                
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
    func performTestTopUp(amountNTD: Double) async {
        do {
            // 計算代幣數量：100 台幣 = 1 代幣
            let tokens = Int(amountNTD / 100)
            
            // 以代幣數量更新 Supabase 餘額
            try await supabaseService.updateWalletBalance(delta: tokens)
            
            // 創建充值交易記錄
            try await supabaseService.createWalletTransaction(
                type: WalletTransactionType.deposit.rawValue,
                amount: Double(tokens), // 存儲代幣數量作為正數
                description: "充值 NT$\(Int(amountNTD))",
                paymentMethod: "test_topup"
            )
            
            // 重新載入餘額和交易記錄
            await loadBalance()
            await loadTransactions()
            
            await MainActor.run {
                print("✅ [WalletViewModel] 充值成功: 支付 NT$\(Int(amountNTD))，獲得 \(tokens) 代幣")
            }
            
            // 發送通知給其他頁面更新餘額
            NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceUpdated"), object: nil)
            
        } catch {
            await MainActor.run {
                print("❌ [WalletViewModel] 充值失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 載入交易記錄
    private func loadTransactions() async {
        do {
            // 重置分頁狀態
            currentPage = 0
            
            // 從 Supabase 載入真實的交易記錄（第一頁，10筆）
            let fetchedTransactions = try await supabaseService.fetchUserTransactions(
                limit: itemsPerPage, 
                offset: 0
            )
            
            await MainActor.run {
                self.transactions = fetchedTransactions
                self.hasMoreTransactions = fetchedTransactions.count == itemsPerPage
            }
            
            print("✅ [WalletViewModel] 成功載入 \(fetchedTransactions.count) 筆交易記錄")
        } catch {
            await MainActor.run {
                self.transactions = []
                self.hasMoreTransactions = false
            }
            print("❌ [WalletViewModel] 載入交易記錄失敗: \(error)")
        }
    }
    
    // MARK: - 載入更多交易記錄
    func loadMoreTransactions() async {
        guard !isLoadingMore && hasMoreTransactions else { return }
        
        await MainActor.run {
            self.isLoadingMore = true
        }
        
        do {
            let nextPage = currentPage + 1
            let offset = nextPage * itemsPerPage
            
            let moreTransactions = try await supabaseService.fetchUserTransactions(
                limit: itemsPerPage,
                offset: offset
            )
            
            await MainActor.run {
                self.transactions.append(contentsOf: moreTransactions)
                self.currentPage = nextPage
                self.hasMoreTransactions = moreTransactions.count == itemsPerPage
                self.isLoadingMore = false
            }
            
            print("✅ [WalletViewModel] 載入更多交易記錄：第 \(nextPage + 1) 頁，\(moreTransactions.count) 筆")
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
            }
            print("❌ [WalletViewModel] 載入更多交易記錄失敗: \(error)")
        }
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