import Foundation
import SwiftUI

// MARK: - Chat Portfolio Manager (Shared Instance)
class ChatPortfolioManager: ObservableObject {
    static let shared = ChatPortfolioManager()
    
    @Published var holdings: [PortfolioHolding] = []
    @Published var virtualBalance: Double = 1_000_000 // 每月100萬虛擬幣
    @Published var totalInvested: Double = 0
    
    private let colors = ["blue", "orange", "green", "red", "purple"]
    private var colorIndex = 0
    
    private init() {
        loadPortfolio()
    }
    
    // MARK: - Portfolio Calculations
    
    var totalPortfolioValue: Double {
        return holdings.reduce(0) { $0 + $1.totalValue }
    }
    
    var availableBalance: Double {
        return virtualBalance - totalInvested
    }
    
    var portfolioPercentages: [(String, Double, Color)] {
        let total = totalPortfolioValue
        guard total > 0 else { return [] }
        
        return holdings.map { holding in
            let percentage = holding.totalValue / total
            let color = colorForSymbol(holding.symbol)
            return (holding.symbol, percentage, color)
        }
    }
    
    private func colorForSymbol(_ symbol: String) -> Color {
        switch symbol {
        case "AAPL": return .blue
        case "TSLA": return .orange
        case "NVDA": return .green
        case "GOOGL": return .red
        case "MSFT": return .purple
        default: return .blue
        }
    }
    
    // MARK: - Trading Operations
    
    func canBuy(symbol: String, amount: Double) -> Bool {
        return amount <= availableBalance
    }
    
    func canSell(symbol: String, shares: Double) -> Bool {
        guard let holding = holdings.first(where: { $0.symbol == symbol }) else {
            return false
        }
        return shares <= Double(holding.quantity)
    }
    
    func buyStock(symbol: String, shares: Double, price: Double) -> Bool {
        let totalCost = shares * price
        
        guard canBuy(symbol: symbol, amount: totalCost) else {
            return false
        }
        
        let currentUser = getCurrentUser()
        
        if let index = holdings.firstIndex(where: { $0.symbol == symbol }) {
            // 更新現有持股
            let existingHolding = holdings[index]
            let newShares = existingHolding.shares + shares
            let newAveragePrice = ((existingHolding.shares * existingHolding.averagePrice) + (shares * price)) / newShares
            
            holdings[index] = PortfolioHolding(
                id: existingHolding.id,
                userId: currentUser,
                symbol: symbol,
                shares: newShares,
                averagePrice: newAveragePrice,
                currentPrice: price,
                lastUpdated: Date()
            )
        } else {
            // 新增持股
            let newHolding = PortfolioHolding(
                id: UUID(),
                userId: currentUser,
                symbol: symbol,
                shares: shares,
                averagePrice: price,
                currentPrice: price,
                lastUpdated: Date()
            )
            holdings.append(newHolding)
        }
        
        totalInvested += totalCost
        savePortfolio()
        return true
    }
    
    func sellStock(symbol: String, shares: Double, price: Double) -> Bool {
        guard let index = holdings.firstIndex(where: { $0.symbol == symbol }) else {
            return false
        }
        
        let holding = holdings[index]
        guard canSell(symbol: symbol, shares: shares) else {
            return false
        }
        
        let saleValue = shares * price
        let costBasis = shares * holding.averagePrice
        
        if Double(holding.quantity) == shares {
            // 全部賣出
            holdings.remove(at: index)
        } else {
            // 部分賣出
            let newShares = holding.shares - shares
            holdings[index] = PortfolioHolding(
                id: holding.id,
                userId: holding.userId,
                symbol: symbol,
                shares: newShares,
                averagePrice: holding.averagePrice,
                currentPrice: price,
                lastUpdated: Date()
            )
        }
        
        totalInvested -= costBasis
        savePortfolio()
        return true
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentUser() -> UUID {
        // 從 UserDefaults 獲取當前用戶 ID
        if let data = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return user.id
        }
        return UUID() // 如果沒有當前用戶，返回新的 UUID
    }
    
    private func savePortfolio() {
        // 儲存到 UserDefaults (後續可以改為 Supabase)
        if let encoded = try? JSONEncoder().encode(holdings) {
            UserDefaults.standard.set(encoded, forKey: "chat_portfolio_holdings")
        }
        UserDefaults.standard.set(totalInvested, forKey: "chat_total_invested")
        UserDefaults.standard.set(virtualBalance, forKey: "chat_virtual_balance")
    }
    
    private func loadPortfolio() {
        // 從 UserDefaults 載入 (後續可以改為 Supabase)
        if let data = UserDefaults.standard.data(forKey: "chat_portfolio_holdings"),
           let decodedHoldings = try? JSONDecoder().decode([PortfolioHolding].self, from: data) {
            holdings = decodedHoldings
        }
        
        totalInvested = UserDefaults.standard.double(forKey: "chat_total_invested")
        virtualBalance = UserDefaults.standard.double(forKey: "chat_virtual_balance")
        
        // 如果是第一次使用，設置初始餘額
        if virtualBalance == 0 {
            virtualBalance = 1_000_000
        }
    }
    
    // MARK: - Monthly Reset
    
    func resetMonthlyBalance() {
        virtualBalance = 1_000_000
        savePortfolio()
    }
}