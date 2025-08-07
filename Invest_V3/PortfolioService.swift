import Foundation
import SwiftUI
import Supabase
import Auth
import Realtime
import SupabaseStorage

@MainActor
class PortfolioService: ObservableObject {
    static let shared = PortfolioService()
    
    private var supabaseClient: SupabaseClient? {
        SupabaseManager.shared.client
    }
    private let stockService = StockService.shared
    
    private init() {}
    
    // MARK: - 投資組合管理
    
    /// 獲取用戶投資組合 (支持錦標賽和群組篩選)
    func fetchUserPortfolio(userId: UUID, tournamentId: UUID? = nil, groupId: UUID? = nil) async throws -> UserPortfolio {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        // 建構查詢，支持錦標賽和群組篩選
        var query = client
            .from("portfolios")
            .select()
            .eq("user_id", value: userId)
            
        // 添加錦標賽篩選
        if let tournamentId = tournamentId {
            query = query.eq("tournament_id", value: tournamentId)
        } else if tournamentId == nil && groupId == nil {
            // 如果沒有指定錦標賽和群組，則查詢一般模式（兩者都為 null）
            query = query.is("tournament_id", value: nil).is("group_id", value: nil)
        }
        
        // 添加群組篩選
        if let groupId = groupId {
            query = query.eq("group_id", value: groupId)
        }
        
        // 獲取用戶投資組合基本資訊
        let portfolioResponse: [UserPortfolio] = try await query.execute().value
        
        guard let portfolio = portfolioResponse.first else {
            // 如果沒有投資組合，創建一個新的
            return try await createInitialPortfolio(userId: userId, tournamentId: tournamentId, groupId: groupId)
        }
        
        return portfolio
    }
    
    /// 獲取投資組合交易記錄
    func fetchPortfolioTransactions(userId: UUID) async throws -> [PortfolioTransaction] {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        let transactions: [PortfolioTransaction] = try await client
            .from("portfolio_transactions")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return transactions
    }
    
    /// 執行投資交易
    func executeTransaction(
        userId: UUID,
        symbol: String,
        action: TransactionAction,
        amount: Double
    ) async throws -> PortfolioTransaction {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        // 獲取當前股價
        let stock = try await stockService.fetchStockQuote(symbol: symbol)
        let quantity = Int(amount / stock.price)
        
        // 檢查資金是否足夠
        let portfolio = try await fetchUserPortfolio(userId: userId)
        if action == .buy && amount > portfolio.availableCash {
            throw PortfolioServiceError.insufficientFunds
        }
        
        // 創建交易記錄
        let transaction = PortfolioTransaction(
            id: UUID(),
            userId: userId,
            symbol: symbol,
            action: action.rawValue,
            quantity: quantity,
            price: stock.price,
            amount: amount,
            createdAt: Date()
        )
        
        // 保存到 Supabase
        try await client
            .from("portfolio_transactions")
            .insert(transaction)
            .execute()
        
        // 更新投資組合
        try await updatePortfolioAfterTransaction(
            userId: userId,
            transaction: transaction
        )
        
        return transaction
    }
    
    /// 計算投資組合回報率
    func calculatePortfolioReturn(userId: UUID) async throws -> Double {
        let transactions = try await fetchPortfolioTransactions(userId: userId)
        let portfolio = try await fetchUserPortfolio(userId: userId)
        
        var totalCurrentValue: Double = 0
        var totalCost: Double = 0
        
        // 按股票分組計算
        let groupedHoldings = Dictionary(grouping: transactions) { $0.symbol }
        
        for (symbol, transactionsList) in groupedHoldings {
            let netQuantity = transactionsList.reduce(0) { (result: Int, transaction: PortfolioTransaction) -> Int in
                return transaction.action == "buy" ? result + transaction.quantity : result - transaction.quantity
            }
            
            if netQuantity > 0 {
                // 獲取當前股價
                let currentStock = try await stockService.fetchStockQuote(symbol: symbol)
                totalCurrentValue += Double(netQuantity) * currentStock.price
                
                // 計算平均成本
                let buyTransactions = transactionsList.filter { $0.action == "buy" }
                let totalBuyAmount = buyTransactions.reduce(0.0) { (result: Double, transaction: PortfolioTransaction) -> Double in
                    return result + transaction.amount
                }
                totalCost += totalBuyAmount
            }
        }
        
        // 加上現金
        totalCurrentValue += portfolio.availableCash
        
        // 計算回報率
        let initialCash = portfolio.initialCash
        let returnRate = ((totalCurrentValue - initialCash) / initialCash) * 100
        
        return returnRate
    }
    
    /// 獲取用戶持有特定股票的數量
    func getStockHolding(userId: UUID, symbol: String) async throws -> Int {
        let transactions = try await fetchPortfolioTransactions(userId: userId)
        let stockTransactions = transactions.filter { $0.symbol == symbol }
        
        let netQuantity = stockTransactions.reduce(0) { (result: Int, transaction: PortfolioTransaction) -> Int in
            return transaction.action == "buy" ? result + transaction.quantity : result - transaction.quantity
        }
        
        return max(netQuantity, 0) // 確保不會返回負數
    }
    
    /// 獲取用戶所有持股資訊
    func getAllHoldings(userId: UUID) async throws -> [StockHolding] {
        let transactions = try await fetchPortfolioTransactions(userId: userId)
        let groupedHoldings = Dictionary(grouping: transactions) { $0.symbol }
        
        var holdings: [StockHolding] = []
        
        for (symbol, transactionsList) in groupedHoldings {
            let netQuantity = transactionsList.reduce(0) { (result: Int, transaction: PortfolioTransaction) -> Int in
                return transaction.action == "buy" ? result + transaction.quantity : result - transaction.quantity
            }
            
            if netQuantity > 0 {
                // 計算平均成本
                let buyTransactions = transactionsList.filter { $0.action == "buy" }
                let totalBuyQuantity = buyTransactions.reduce(0) { $0 + $1.quantity }
                let totalBuyAmount = buyTransactions.reduce(0.0) { $0 + $1.amount }
                let averageCost = totalBuyQuantity > 0 ? totalBuyAmount / Double(totalBuyQuantity) : 0.0
                
                holdings.append(StockHolding(
                    symbol: symbol,
                    quantity: netQuantity,
                    averageCost: averageCost
                ))
            }
        }
        
        return holdings
    }
    
    /// 獲取投資組合分佈 (用於圓環圖)
    func getPortfolioDistribution(userId: UUID) async throws -> [PortfolioItem] {
        let transactions = try await fetchPortfolioTransactions(userId: userId)
        let groupedHoldings = Dictionary(grouping: transactions) { $0.symbol }
        
        var portfolioItems: [PortfolioItem] = []
        var totalValue: Double = 0
        
        // 計算每個股票的當前價值
        for (symbol, transactionsList) in groupedHoldings {
            let netQuantity = transactionsList.reduce(0) { (result: Int, transaction: PortfolioTransaction) -> Int in
                return transaction.action == "buy" ? result + transaction.quantity : result - transaction.quantity
            }
            
            if netQuantity > 0 {
                let currentStock = try await stockService.fetchStockQuote(symbol: symbol)
                let currentValue = Double(netQuantity) * currentStock.price
                totalValue += currentValue
                
                portfolioItems.append(PortfolioItem(
                    symbol: symbol,
                    percent: 0, // 稍後計算
                    amount: currentValue,
                    color: getColorForStock(symbol)
                ))
            }
        }
        
        // 計算百分比並重新創建數組
        portfolioItems = portfolioItems.map { item in
            PortfolioItem(
                symbol: item.symbol,
                percent: (item.amount / totalValue) * 100,
                amount: item.amount,
                color: item.color
            )
        }
        
        return portfolioItems
    }
    
    // MARK: - 投資組合刪除與清理
    
    /// 刪除指定投資組合的所有資料
    /// - Parameter portfolioId: 要刪除的投資組合 ID
    func deletePortfolio(portfolioId: UUID) async throws {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        print("🗑️ [PortfolioService] 開始刪除投資組合: \(portfolioId)")
        
        // 步驟 1: 刪除所有相關的持倉記錄 (user_positions)
        do {
            try await client
                .from("user_positions")
                .delete()
                .eq("portfolio_id", value: portfolioId)
                .execute()
            print("✅ [PortfolioService] 已刪除持倉記錄")
        } catch {
            print("❌ [PortfolioService] 刪除持倉記錄失敗: \(error)")
            throw PortfolioServiceError.deletionFailed("刪除持倉記錄失敗")
        }
        
        // 步驟 2: 刪除所有相關的交易記錄 (portfolio_transactions)
        do {
            // 先獲取投資組合資訊以取得 user_id
            let portfolioResponse: [UserPortfolio] = try await client
                .from("user_portfolios")
                .select()
                .eq("id", value: portfolioId)
                .execute()
                .value
            
            if let portfolio = portfolioResponse.first {
                try await client
                    .from("portfolio_transactions")
                    .delete()
                    .eq("user_id", value: portfolio.userId)
                    .execute()
                print("✅ [PortfolioService] 已刪除交易記錄")
            }
        } catch {
            print("❌ [PortfolioService] 刪除交易記錄失敗: \(error)")
            throw PortfolioServiceError.deletionFailed("刪除交易記錄失敗")
        }
        
        // 步驟 3: 刪除投資組合主記錄 (user_portfolios)
        do {
            try await client
                .from("user_portfolios")
                .delete()
                .eq("id", value: portfolioId)
                .execute()
            print("✅ [PortfolioService] 已刪除投資組合主記錄")
        } catch {
            print("❌ [PortfolioService] 刪除投資組合主記錄失敗: \(error)")
            throw PortfolioServiceError.deletionFailed("刪除投資組合主記錄失敗")
        }
        
        print("🎉 [PortfolioService] 投資組合刪除完成: \(portfolioId)")
    }
    
    /// 清空指定用戶的投資組合
    /// - Parameter userId: 用戶 ID
    func clearUserPortfolio(userId: UUID) async throws {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        print("🧹 [PortfolioService] 開始清空用戶投資組合: \(userId)")
        
        // 獲取用戶的所有投資組合
        let portfolioResponse: [UserPortfolio] = try await client
            .from("user_portfolios")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // 逐一刪除每個投資組合
        for portfolio in portfolioResponse {
            try await deletePortfolio(portfolioId: portfolio.id)
        }
        
        print("🎉 [PortfolioService] 用戶投資組合清空完成: \(userId)")
    }
    
    // MARK: - 錦標賽投資組合專用方法
    
    /// 創建錦標賽投資組合
    func createTournamentPortfolio(userId: UUID, tournamentId: UUID, initialBalance: Double = 1_000_000) async throws -> UserPortfolio {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        // 檢查是否已存在該用戶在該錦標賽的投資組合
        let existingPortfolio = try? await fetchUserPortfolio(userId: userId, tournamentId: tournamentId)
        if existingPortfolio != nil {
            print("⚠️ [PortfolioService] 錦標賽投資組合已存在")
            return existingPortfolio!
        }
        
        // 創建新的錦標賽投資組合
        let portfolio = UserPortfolio(
            id: UUID(),
            userId: userId,
            groupId: nil,
            tournamentId: tournamentId,
            initialCash: initialBalance,
            availableCash: initialBalance,
            totalValue: initialBalance,
            returnRate: 0.0,
            lastUpdated: Date()
        )
        
        try await client
            .from("portfolios")
            .insert(portfolio)
            .execute()
        
        print("✅ [PortfolioService] 創建錦標賽投資組合成功: userId=\(userId), tournamentId=\(tournamentId)")
        
        return portfolio
    }
    
    /// 獲取用戶在特定錦標賽的持股明細
    func fetchTournamentHoldings(userId: UUID, tournamentId: UUID) async throws -> [StockHolding] {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        let holdings: [StockHolding] = try await client
            .from("user_portfolios")
            .select()
            .eq("user_id", value: userId)
            .eq("tournament_id", value: tournamentId)
            .execute()
            .value
        
        return holdings.map { holding in
            StockHolding(
                symbol: holding.symbol,
                quantity: Int(holding.quantity),
                averageCost: holding.averageCost
            )
        }
    }
    
    /// 獲取錦標賽投資組合分佈
    func getTournamentPortfolioDistribution(userId: UUID, tournamentId: UUID) async throws -> [PortfolioItem] {
        let holdings = try await fetchTournamentHoldings(userId: userId, tournamentId: tournamentId)
        var portfolioItems: [PortfolioItem] = []
        var totalValue: Double = 0
        
        // 計算每個股票的當前價值
        for holding in holdings {
            let currentStock = try await stockService.fetchStockQuote(symbol: holding.symbol)
            let currentValue = Double(holding.quantity) * currentStock.price
            totalValue += currentValue
            
            portfolioItems.append(PortfolioItem(
                symbol: holding.symbol,
                percent: 0, // 稍後計算
                amount: currentValue,
                color: getColorForStock(holding.symbol)
            ))
        }
        
        // 計算百分比
        portfolioItems = portfolioItems.map { item in
            PortfolioItem(
                symbol: item.symbol,
                percent: totalValue > 0 ? (item.amount / totalValue) * 100 : 0,
                amount: item.amount,
                color: item.color
            )
        }
        
        return portfolioItems
    }
    
    /// 刪除錦標賽投資組合
    func deleteTournamentPortfolio(userId: UUID, tournamentId: UUID) async throws {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        print("🗑️ [PortfolioService] 開始刪除錦標賽投資組合: userId=\(userId), tournamentId=\(tournamentId)")
        
        // 步驟 1: 刪除持股記錄
        try await client
            .from("user_portfolios")
            .delete()
            .eq("user_id", value: userId)
            .eq("tournament_id", value: tournamentId)
            .execute()
        
        // 步驟 2: 刪除投資組合主記錄
        try await client
            .from("portfolios")
            .delete()
            .eq("user_id", value: userId)
            .eq("tournament_id", value: tournamentId)
            .execute()
        
        print("✅ [PortfolioService] 錦標賽投資組合刪除完成: userId=\(userId), tournamentId=\(tournamentId)")
    }

    // MARK: - 私有方法
    
    private func createInitialPortfolio(userId: UUID, tournamentId: UUID? = nil, groupId: UUID? = nil) async throws -> UserPortfolio {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        let initialCash: Double = 1_000_000 // 100萬虛擬資金
        
        let portfolio = UserPortfolio(
            id: UUID(),
            userId: userId,
            groupId: groupId,
            tournamentId: tournamentId, // 新增錦標賽關聯
            initialCash: initialCash,
            availableCash: initialCash,
            totalValue: initialCash,
            returnRate: 0.0,
            lastUpdated: Date()
        )
        
        try await client
            .from("portfolios")
            .insert(portfolio)
            .execute()
        
        // 記錄投資組合創建日誌
        print("✅ [PortfolioService] 創建投資組合成功: userId=\(userId), tournamentId=\(tournamentId?.uuidString ?? "nil"), groupId=\(groupId?.uuidString ?? "nil")")
        
        return portfolio
    }
    
    private func updatePortfolioAfterTransaction(
        userId: UUID,
        transaction: PortfolioTransaction
    ) async throws {
        guard let client = supabaseClient else {
            throw PortfolioServiceError.clientNotInitialized
        }
        
        let portfolio = try await fetchUserPortfolio(userId: userId)
        
        let newAvailableCash: Double
        if transaction.action == "buy" {
            newAvailableCash = portfolio.availableCash - transaction.amount
        } else {
            newAvailableCash = portfolio.availableCash + transaction.amount
        }
        
        // 計算新的回報率
        let newReturnRate = try await calculatePortfolioReturn(userId: userId)
        
        let updatePayload = PortfolioUpdatePayload(
            available_cash: newAvailableCash,
            return_rate: newReturnRate,
            last_updated: Date().iso8601String
        )
        
        try await client
            .from("user_portfolios")
            .update(updatePayload)
            .eq("user_id", value: userId)
            .execute()
    }
    
    private func getColorForStock(_ symbol: String) -> Color {
        let colors: [Color] = [.brandGreen, .brandOrange, .brandBlue, .info, .warning]
        let index = abs(symbol.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - 錯誤類型
enum PortfolioServiceError: Error, LocalizedError {
    case clientNotInitialized
    case insufficientFunds
    case invalidTransaction
    case stockNotFound
    case deletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "Supabase 客戶端未初始化"
        case .insufficientFunds:
            return "資金不足"
        case .invalidTransaction:
            return "無效的交易"
        case .stockNotFound:
            return "找不到股票"
        case .deletionFailed(let message):
            return "刪除失敗: \(message)"
        }
    }
}

// MARK: - 投資組合更新數據模型
struct PortfolioUpdatePayload: Codable {
    let available_cash: Double
    let return_rate: Double
    let last_updated: String
}

// MARK: - 交易動作
enum TransactionAction: String, CaseIterable {
    case buy = "buy"
    case sell = "sell"
    
    var displayName: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
}

// MARK: - 投資組合交易記錄
struct PortfolioTransaction: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String
    let action: String // "buy" or "sell"
    let quantity: Int
    let price: Double
    let amount: Double
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case symbol, action, quantity, price, amount
        case createdAt = "created_at"
    }
}

// 移除重複定義，使用 Stock.swift 中的 PortfolioHolding

// MARK: - 投資組合項目 (用於圓環圖)
struct PortfolioItem: Identifiable {
    let id = UUID()
    let symbol: String
    let percent: Double
    let amount: Double
    let color: Color
}

// MARK: - 持股資訊模型
struct StockHolding: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let quantity: Int
    let averageCost: Double
    
    enum CodingKeys: String, CodingKey {
        case symbol, quantity
        case averageCost = "average_cost"
    }
}

// MARK: - 擴展
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
} 
