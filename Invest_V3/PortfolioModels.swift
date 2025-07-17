import Foundation
import SwiftUI

// MARK: - Portfolio Holding Model
struct PortfolioHolding: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    var shares: Double
    var averagePrice: Double
    let color: String // 儲存顏色的字串表示
    
    var totalValue: Double {
        return shares * averagePrice
    }
    
    var displayColor: Color {
        switch color {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - Portfolio Manager
class PortfolioManager: ObservableObject {
    @Published var holdings: [PortfolioHolding] = []
    @Published var virtualBalance: Double = 1_000_000 // 每月100萬虛擬幣
    @Published var totalInvested: Double = 0
    
    private let colors = ["blue", "orange", "green", "red", "purple"]
    private var colorIndex = 0
    
    init() {
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
            return (holding.symbol, percentage, holding.displayColor)
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
        return shares <= holding.shares
    }
    
    func buyStock(symbol: String, shares: Double, price: Double) -> Bool {
        let totalCost = shares * price
        
        guard canBuy(symbol: symbol, amount: totalCost) else {
            return false
        }
        
        if let index = holdings.firstIndex(where: { $0.symbol == symbol }) {
            // 更新現有持股
            let existingHolding = holdings[index]
            let newShares = existingHolding.shares + shares
            let newAveragePrice = ((existingHolding.shares * existingHolding.averagePrice) + (shares * price)) / newShares
            
            holdings[index] = PortfolioHolding(
                symbol: symbol,
                shares: newShares,
                averagePrice: newAveragePrice,
                color: existingHolding.color
            )
        } else {
            // 新增持股
            let newHolding = PortfolioHolding(
                symbol: symbol,
                shares: shares,
                averagePrice: price,
                color: getNextColor()
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
        
        if holding.shares == shares {
            // 全部賣出
            holdings.remove(at: index)
        } else {
            // 部分賣出
            holdings[index] = PortfolioHolding(
                symbol: symbol,
                shares: holding.shares - shares,
                averagePrice: holding.averagePrice,
                color: holding.color
            )
        }
        
        totalInvested -= costBasis
        savePortfolio()
        return true
    }
    
    // MARK: - Utility Methods
    
    private func getNextColor() -> String {
        let color = colors[colorIndex % colors.count]
        colorIndex += 1
        return color
    }
    
    private func savePortfolio() {
        // 儲存到 UserDefaults (後續可以改為 Supabase)
        if let encoded = try? JSONEncoder().encode(holdings) {
            UserDefaults.standard.set(encoded, forKey: "portfolio_holdings")
        }
        UserDefaults.standard.set(totalInvested, forKey: "total_invested")
        UserDefaults.standard.set(virtualBalance, forKey: "virtual_balance")
    }
    
    private func loadPortfolio() {
        // 從 UserDefaults 載入 (後續可以改為 Supabase)
        if let data = UserDefaults.standard.data(forKey: "portfolio_holdings"),
           let decodedHoldings = try? JSONDecoder().decode([PortfolioHolding].self, from: data) {
            holdings = decodedHoldings
        }
        
        totalInvested = UserDefaults.standard.double(forKey: "total_invested")
        virtualBalance = UserDefaults.standard.double(forKey: "virtual_balance")
        
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