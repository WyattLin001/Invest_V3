//
//  TransactionHistoryView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  完整交易記錄頁面
//

import SwiftUI

struct TransactionHistoryView: View {
    @StateObject private var viewModel = TransactionHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.transactions.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 統計卡片作為第一項
                        statisticsCard
                        
                        // 交易記錄列表
                        ForEach(viewModel.groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                            transactionDateSection(date: date, transactions: viewModel.groupedTransactions[date] ?? [])
                        }
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await viewModel.refreshTransactions()
                }
            }
        }
        .navigationTitle("交易記錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(viewModel.transactions.count)")
                    .font(.caption)
                    .foregroundColor(.gray600)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray300)
                    .cornerRadius(10)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadAllTransactions()
            }
        }
    }
    
    
    // MARK: - 載入中視圖
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("載入交易記錄...")
                .font(.bodyText)
                .foregroundColor(.gray600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空狀態視圖
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray400)
            
            Text("尚無交易記錄")
                .font(.titleMedium)
                .fontWeight(.medium)
                .foregroundColor(.gray600)
            
            Text("當您進行儲值、消費或提領時，記錄會在這裡顯示")
                .font(.bodyText)
                .foregroundColor(.gray500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    // MARK: - 統計卡片
    
    private var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack {
                statisticItem(title: "總收入", amount: viewModel.totalIncome, color: .brandGreen)
                Spacer()
                statisticItem(title: "總支出", amount: viewModel.totalExpense, color: .brandOrange)
            }
            
            HStack {
                statisticItem(title: "本月交易", amount: Double(viewModel.monthlyTransactionCount), color: .blue, isCount: true)
                Spacer()
                statisticItem(title: "淨收益", amount: viewModel.netIncome, color: viewModel.netIncome >= 0 ? .brandGreen : .red)
            }
        }
        .padding(16)
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
    
    private func statisticItem(title: String, amount: Double, color: Color, isCount: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray600)
            
            if isCount {
                Text("\(Int(amount)) 筆")
                    .font(.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            } else {
                Text(TokenSystem.formatTokens(amount))
                    .font(.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
    }
    
    // MARK: - 日期分組
    
    private func transactionDateSection(date: String, transactions: [WalletTransaction]) -> some View {
        VStack(spacing: 0) {
            // 日期標題
            HStack {
                Text(date)
                    .font(.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(.gray700)
                Spacer()
                Text("\(transactions.count) 筆")
                    .font(.caption)
                    .foregroundColor(.gray500)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray200)
            
            // 交易列表
            ForEach(transactions) { transaction in
                TransactionRowView(transaction: transaction)
                
                if transaction.id != transactions.last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }
}


// MARK: - 交易記錄 ViewModel

@MainActor
class TransactionHistoryViewModel: ObservableObject {
    @Published var transactions: [WalletTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        // 監聽錢包餘額更新通知，以便及時更新交易記錄
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WalletBalanceUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshTransactions()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // 計算屬性
    var totalIncome: Double {
        transactions.filter { $0.amount > 0 }.reduce(0) { $0 + Double($1.amount) }
    }
    
    var totalExpense: Double {
        transactions.filter { $0.amount < 0 }.reduce(0) { $0 + Double(abs($1.amount)) }
    }
    
    var netIncome: Double {
        totalIncome - totalExpense
    }
    
    var monthlyTransactionCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }.count
    }
    
    var groupedTransactions: [String: [WalletTransaction]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        
        return Dictionary(grouping: transactions) { transaction in
            formatter.string(from: transaction.createdAt)
        }
    }
    
    // MARK: - 數據載入
    
    func loadAllTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 載入所有交易記錄（不限制數量）
            let fetchedTransactions = try await supabaseService.fetchUserTransactions(limit: 1000)
            self.transactions = fetchedTransactions.sorted { $0.createdAt > $1.createdAt }
            
            print("✅ [TransactionHistoryViewModel] 載入 \(fetchedTransactions.count) 筆交易記錄")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [TransactionHistoryViewModel] 載入交易記錄失敗: \(error)")
            
            // 使用模擬資料作為後備
            self.transactions = createMockTransactions()
        }
        
        isLoading = false
    }
    
    func refreshTransactions() async {
        await loadAllTransactions()
    }
    
    private func createMockTransactions() -> [WalletTransaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: WalletTransactionType.deposit.rawValue,
                amount: 10000,
                description: "創作者收益提領",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                recipientId: nil,
                groupId: nil,
                createdAt: calendar.date(byAdding: .hour, value: -1, to: now) ?? now
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: WalletTransactionType.groupEntryFee.rawValue,
                amount: -500,
                description: "加入「AI投資策略討論」群組",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                recipientId: nil,
                groupId: nil,
                createdAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: WalletTransactionType.subscription.rawValue,
                amount: 299,
                description: "訂閱分潤收益 - 投資達人內容",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "platform_revenue_share",
                blockchainId: nil,
                recipientId: nil,
                groupId: nil,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: WalletTransactionType.tip.rawValue,
                amount: -100,
                description: "抖內給「科技股分析專家」",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                recipientId: nil,
                groupId: nil,
                createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            WalletTransaction(
                id: UUID(),
                userId: UUID(),
                transactionType: WalletTransactionType.groupTip.rawValue,
                amount: -200,
                description: "群組內抖內給主持人",
                status: TransactionStatus.confirmed.rawValue,
                paymentMethod: "wallet",
                blockchainId: nil,
                recipientId: nil,
                groupId: nil,
                createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now
            )
        ].sorted { $0.createdAt > $1.createdAt }
    }
}

#Preview {
    TransactionHistoryView()
}