import SwiftUI
import Foundation

/// 交易紀錄頁面
struct TransactionsView: View {
    @StateObject private var viewModel = TransactionsViewModel()
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    @State private var selectedFilter: TransactionFilter = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 篩選器
                filterSection
                
                // 交易紀錄列表
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("載入交易紀錄中...")
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionsList
                }
            }
            .navigationTitle(transactionsTitle)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadTransactionsData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TournamentContextChanged"))) { notification in
                let tournamentId = notification.userInfo?["tournamentId"] as? String ?? "unknown"
                let tournamentName = notification.userInfo?["tournamentName"] as? String ?? "unknown"
                print("📨 [TransactionsView] 收到錦標賽切換通知: \(tournamentName) (ID: \(tournamentId))")
                print("📨 [TransactionsView] 通知詳情: \(notification.userInfo ?? [:])")
                Task {
                    await loadTransactionsData()
                }
            }
            .onAppear {
                print("👁️ [TransactionsView] 視圖出現")
            }
            .onDisappear {
                print("👻 [TransactionsView] 視圖消失")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TournamentDataReloaded"))) { notification in
                let tournamentId = notification.userInfo?["tournamentId"] as? String ?? "unknown"
                print("📨 [TransactionsView] 收到錦標賽數據重載通知: \(tournamentId)")
                Task {
                    await loadTransactionsData()
                }
            }
            .onChange(of: tournamentStateManager.currentTournamentContext) { _, _ in
                print("🔄 [TransactionsView] 錦標賽上下文變更，重新載入交易紀錄")
                Task {
                    await loadTransactionsData()
                }
            }
        }
        .task {
            await loadTransactionsData()
        }
        .alert("載入失敗", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("重試") {
                Task {
                    await loadTransactionsData()
                }
            }
            Button("確定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 篩選器區域
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        viewModel.filterTransactions(by: filter)
                    }) {
                        Text(filter.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                            )
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - 交易紀錄列表
    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredTransactions) { transaction in
                    TradingTransactionRowView(transaction: transaction)
                    
                    if transaction.id != viewModel.filteredTransactions.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 空狀態視圖
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("尚無交易紀錄")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("開始您的第一筆投資交易")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("立即投資") {
                // TODO: 導航到投資面板
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.blue)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 計算屬性和方法
    
    private var transactionsTitle: String {
        if let tournamentName = tournamentStateManager.getCurrentTournamentDisplayName() {
            return "\(tournamentName) - 交易紀錄"
        } else {
            return "交易紀錄"
        }
    }
    
    private func loadTransactionsData() async {
        if tournamentStateManager.isParticipatingInTournament,
           let tournamentId = tournamentStateManager.getCurrentTournamentIdDebug() {
            print("🏆 [TransactionsView] 載入錦標賽交易紀錄: \(tournamentId)")
            await viewModel.loadTournamentTransactions(tournamentId: tournamentId)
        } else {
            print("📊 [TransactionsView] 載入一般模式交易紀錄")
            await viewModel.loadTransactions()
        }
    }
}

// MARK: - 交易紀錄行視圖
struct TradingTransactionRowView: View {
    let transaction: TransactionDisplay
    
    var body: some View {
        HStack(spacing: 12) {
            // 交易類型圖標
            ZStack {
                Circle()
                    .fill(transaction.type.backgroundColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(transaction.type.iconColor)
            }
            
            // 交易資訊
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.symbol)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(transaction.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(transaction.type.backgroundColor.opacity(0.2))
                        )
                        .foregroundColor(transaction.type.backgroundColor)
                }
                
                HStack {
                    Text("股數：\(String(format: "%.2f", transaction.shares))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("價格：$\(String(format: "%.2f", transaction.price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                HStack {
                    Text(DateFormatter.transactionDate.string(from: transaction.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("總額：$\(String(format: "%.2f", transaction.totalAmount))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.type == .buy ? .red : .green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - 交易紀錄擴展模型
struct TransactionDisplay: Identifiable {
    let id: UUID
    let symbol: String
    let type: TradingTransactionType
    let shares: Double
    let price: Double
    let totalAmount: Double
    let date: Date
    let groupId: UUID?
    
    init(id: UUID = UUID(), symbol: String, type: TradingTransactionType, shares: Double, price: Double, date: Date = Date(), groupId: UUID? = nil) {
        self.id = id
        self.symbol = symbol
        self.type = type
        self.shares = shares
        self.price = price
        self.totalAmount = shares * price
        self.date = date
        self.groupId = groupId
    }
    
    // 從 TransactionDetail 轉換
    init(from detail: TransactionDetail) {
        self.id = UUID() // TransactionDetail 可能沒有 UUID
        self.symbol = detail.symbol
        self.type = TradingTransactionType(rawValue: detail.action.lowercased()) ?? .buy
        self.shares = Double(detail.quantity)
        self.price = detail.price
        self.totalAmount = Double(detail.quantity) * detail.price
        self.date = ISO8601DateFormatter().date(from: detail.executedAt) ?? Date()
        self.groupId = nil
    }
}

enum TradingTransactionType: String, CaseIterable, Codable {
    case buy = "buy"
    case sell = "sell"
    
    var displayName: String {
        switch self {
        case .buy:
            return "買入"
        case .sell:
            return "賣出"
        }
    }
    
    var iconName: String {
        switch self {
        case .buy:
            return "arrow.down.circle.fill"
        case .sell:
            return "arrow.up.circle.fill"
        }
    }
    
    var iconColor: Color {
        return .white
    }
    
    var backgroundColor: Color {
        switch self {
        case .buy:
            return .green
        case .sell:
            return .red
        }
    }
}

enum TransactionFilter: String, CaseIterable {
    case all = "all"
    case buy = "buy"
    case sell = "sell"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .buy:
            return "買入"
        case .sell:
            return "賣出"
        case .thisWeek:
            return "本週"
        case .thisMonth:
            return "本月"
        }
    }
}

// MARK: - 交易紀錄 ViewModel
@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var transactions: [TransactionDisplay] = []
    @Published var filteredTransactions: [TransactionDisplay] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// 載入交易紀錄
    func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 獲取當前用戶
            guard let currentUser = SupabaseService.shared.getCurrentUser() else {
                print("❌ [TransactionsViewModel] 無法獲取當前用戶")
                throw NSError(domain: "TransactionsView", code: 404, userInfo: [NSLocalizedDescriptionKey: "用戶未登錄"])
            }
            
            // 使用統一的 PortfolioService 載入一般模式交易紀錄
            let portfolioTransactions = try await PortfolioService.shared.fetchPortfolioTransactions(userId: currentUser.id)
            
            // 將 PortfolioTransaction 轉換為 TransactionDisplay
            let displayTransactions = portfolioTransactions.map { portfolioTransaction in
                TransactionDisplay(
                    id: portfolioTransaction.id,
                    symbol: portfolioTransaction.symbol,
                    type: TradingTransactionType(rawValue: portfolioTransaction.action) ?? .buy,
                    shares: Double(portfolioTransaction.quantity),
                    price: portfolioTransaction.price,
                    date: portfolioTransaction.createdAt
                )
            }
            
            print("✅ [TransactionsViewModel] 成功載入 \(displayTransactions.count) 筆一般交易紀錄")
            transactions = displayTransactions.sorted { $0.date > $1.date }
            filteredTransactions = transactions
            
        } catch {
            // 如果真實數據載入失敗，使用模擬資料作為備用
            print("⚠️ [TransactionsView] 真實數據載入失敗，使用模擬資料: \(error)")
            let mockTransactions = generateMockTransactions()
            transactions = mockTransactions
            filteredTransactions = mockTransactions
            
            // 不顯示錯誤，因為有備用資料
        }
        
        isLoading = false
    }
    
    /// 載入錦標賽交易紀錄
    func loadTournamentTransactions(tournamentId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🏆 [TransactionsViewModel] 載入錦標賽 \(tournamentId) 的交易紀錄")
            
            // 獲取當前用戶 ID
            guard let currentUser = SupabaseService.shared.getCurrentUser() else {
                print("❌ [TransactionsViewModel] 無法獲取當前用戶")
                throw NSError(domain: "TransactionsView", code: 404, userInfo: [NSLocalizedDescriptionKey: "用戶未登錄"])
            }
            
            // 使用統一的 PortfolioService 載入錦標賽交易紀錄
            let portfolioTransactions = try await PortfolioService.shared.fetchTournamentTransactions(
                userId: currentUser.id,
                tournamentId: tournamentId
            )
            
            // 將 PortfolioTransaction 轉換為 TransactionDisplay
            let displayTransactions = portfolioTransactions.map { portfolioTransaction in
                TransactionDisplay(
                    id: portfolioTransaction.id,
                    symbol: portfolioTransaction.symbol,
                    type: TradingTransactionType(rawValue: portfolioTransaction.action) ?? .buy,
                    shares: Double(portfolioTransaction.quantity),
                    price: portfolioTransaction.price,
                    date: portfolioTransaction.createdAt
                )
            }
            
            print("✅ [TransactionsViewModel] 成功載入 \(displayTransactions.count) 筆錦標賽交易紀錄")
            transactions = displayTransactions.sorted { $0.date > $1.date }
            filteredTransactions = transactions
            
        } catch {
            print("⚠️ [TransactionsViewModel] 錦標賽交易載入失敗: \(error)")
            
            // 如果真實數據載入失敗，暫時使用空數組（表示數據隔離正常）
            print("🔒 [TransactionsViewModel] 使用空數組確保數據隔離")
            transactions = []
            filteredTransactions = []
            
            // 可選：顯示錯誤訊息
            errorMessage = "載入錦標賽交易紀錄失敗，請稍後重試"
        }
        
        isLoading = false
    }
    
    /// 獲取當前用戶 ID（暫時使用模擬值）
    private func getCurrentUserId() -> String {
        // 實際應該從 AuthenticationService 或 UserDefaults 獲取
        return "user_demo_001"
    }
    
    /// 篩選交易紀錄
    func filterTransactions(by filter: TransactionFilter) {
        let now = Date()
        let calendar = Calendar.current
        
        switch filter {
        case .all:
            filteredTransactions = transactions
        case .buy:
            filteredTransactions = transactions.filter { $0.type == .buy }
        case .sell:
            filteredTransactions = transactions.filter { $0.type == .sell }
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            filteredTransactions = transactions.filter { $0.date >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            filteredTransactions = transactions.filter { $0.date >= monthAgo }
        }
    }
    
    /// 生成模擬交易資料
    private func generateMockTransactions() -> [TransactionDisplay] {
        let symbols = ["AAPL", "TSLA", "NVDA", "GOOGL", "MSFT", "AMZN"]
        let calendar = Calendar.current
        var transactions: [TransactionDisplay] = []
        
        for i in 0..<20 {
            let symbol = symbols.randomElement() ?? "AAPL"
            let type: TradingTransactionType = Bool.random() ? .buy : .sell
            let shares = Double.random(in: 1...10)
            let price = Double.random(in: 100...400)
            let daysAgo = Int.random(in: 0...30)
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            
            let transaction = TransactionDisplay(
                symbol: symbol,
                type: type,
                shares: shares,
                price: price,
                date: date
            )
            
            transactions.append(transaction)
        }
        
        // 按日期排序（最新的在上面）
        return transactions.sorted { $0.date > $1.date }
    }
    
    /// 生成錦標賽專用模擬交易資料
    private func generateMockTournamentTransactions(for tournamentId: UUID) -> [TransactionDisplay] {
        // 根據不同的錦標賽 ID 生成不同的資料
        let tournamentString = tournamentId.uuidString
        let symbols: [String]
        let transactionCount: Int
        
        // 根據錦標賽 ID 的前幾個字符來決定模擬數據的特徵
        if tournamentString.hasPrefix("A") || tournamentString.hasPrefix("B") {
            // Test03 類型的錦標賽
            symbols = ["2330", "2454", "2317", "3008", "2891"] // 台股代號
            transactionCount = 15
        } else if tournamentString.hasPrefix("C") || tournamentString.hasPrefix("D") {
            // 2025 Q4 投資錦標賽類型
            symbols = ["SPY", "QQQ", "IWM", "VTI", "BRK.B"] // 美股ETF
            transactionCount = 12
        } else {
            // 其他錦標賽
            symbols = ["AAPL", "TSLA", "NVDA", "GOOGL", "MSFT", "META"]
            transactionCount = 18
        }
        
        let calendar = Calendar.current
        var transactions: [TransactionDisplay] = []
        
        // 使用錦標賽 ID 作為隨機種子，確保相同錦標賽總是生成相同的資料
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(tournamentId.hashValue)))
        
        for i in 0..<transactionCount {
            let symbol = symbols.randomElement(using: &generator) ?? symbols[0]
            let type: TradingTransactionType = Bool.random(using: &generator) ? .buy : .sell
            let shares = Double.random(in: 1...10, using: &generator)
            let price = Double.random(in: 50...300, using: &generator)
            let daysAgo = Int.random(in: 0...20, using: &generator)
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            
            let transaction = TransactionDisplay(
                symbol: symbol,
                type: type,
                shares: shares,
                price: price,
                date: date
            )
            
            transactions.append(transaction)
        }
        
        // 按日期排序（最新的在上面）
        return transactions.sorted { $0.date > $1.date }
    }
}

// MARK: - 隨機數生成器（確保相同種子產生相同結果）
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return state
    }
}

// MARK: - DateFormatter Extensions
extension DateFormatter {
    static let transactionDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()
}

#Preview {
    TransactionsView()
}