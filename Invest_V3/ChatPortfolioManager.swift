import Foundation
import SwiftUI

// MARK: - Chat Portfolio Manager (Shared Instance)
class ChatPortfolioManager: ObservableObject {
    static let shared = ChatPortfolioManager()
    
    @Published var holdings: [PortfolioHolding] = []
    @Published var virtualBalance: Double = 1_000_000 // 每月100萬虛擬幣
    @Published var totalInvested: Double = 0
    @Published var tradingRecords: [TradingRecord] = [] // 交易記錄歷史
    
    // MARK: - 錦標賽管理
    @Published var currentTournamentId: UUID? = nil
    @Published var currentTournamentName: String = "2025年度投資錦標賽"
    
    // 不同錦標賽的投資組合數據
    private var tournamentPortfolios: [String: [PortfolioHolding]] = [:]
    private var tournamentBalances: [String: Double] = [:]
    private var tournamentInvested: [String: Double] = [:]
    private var tournamentRecords: [String: [TradingRecord]] = [:]
    
    private let colors = ["blue", "orange", "green", "red", "purple"]
    private var colorIndex = 0
    
    private init() {
        loadPortfolio()
        loadTradingRecords()
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
    
    // MARK: - 新增投資組合統計計算屬性
    
    /// 總未實現損益（所有持股的盈虧總和）
    var totalUnrealizedGainLoss: Double {
        return holdings.reduce(0) { $0 + $1.unrealizedGainLoss }
    }
    
    /// 總未實現損益百分比
    var totalUnrealizedGainLossPercent: Double {
        let totalCost = holdings.reduce(0) { $0 + $1.totalCost }
        guard totalCost > 0 else { return 0 }
        return (totalUnrealizedGainLoss / totalCost) * 100
    }
    
    /// 投資組合多樣性（持股數量）
    var portfolioDiversityCount: Int {
        return holdings.count
    }
    
    /// 計算日漲跌數據（基於當前價格和歷史數據）
    var dailyChanges: [String: (amount: Double, percent: Double)] {
        var changes: [String: (amount: Double, percent: Double)] = [:]
        
        for holding in holdings {
            // 實際應用中這裡應該從市場數據API獲取真實的日漲跌數據
            // 目前使用基於股票代碼的穩定計算（保持展示一致性）
            let seed = Double(holding.symbol.hash % 1000) / 1000.0 // 0.0 to 1.0
            let changePercent = (seed - 0.5) * 6.0 // -3% to +3% 的變化範圍
            let changeAmount = holding.currentPrice * (changePercent / 100.0)
            
            changes[holding.symbol] = (amount: changeAmount, percent: changePercent)
        }
        
        return changes
    }
    
    /// 為 DynamicPieChart 提供數據
    var pieChartData: [PieChartData] {
        let total = totalPortfolioValue
        guard total > 0 else {
            return [PieChartData(category: "無投資", value: 100, color: .gray)]
        }
        
        return holdings.map { holding in
            let percentage = (holding.totalValue / total) * 100
            let color = StockColorPalette.colorForStock(symbol: holding.symbol)
            return PieChartData(
                category: "\(holding.symbol) \(holding.name)",
                value: percentage,
                color: color
            )
        }.sorted { $0.value > $1.value } // 按比例大小排序
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
            print("❌ [ChatPortfolioManager] canSell: 沒有找到股票 \(symbol)")
            return false
        }
        
        let canSell = shares <= holding.shares
        print("🔍 [ChatPortfolioManager] canSell: \(symbol), 要賣出: \(shares), 持有: \(holding.shares), 可以賣出: \(canSell)")
        
        return canSell
    }
    
    func buyStock(symbol: String, shares: Double, price: Double, stockName: String? = nil, tournamentId: UUID? = nil) -> Bool {
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
                name: stockName ?? existingHolding.name, // 優先使用傳入的名稱，否則保持原有名稱
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
                name: stockName ?? getStockName(for: symbol), // 優先使用傳入的名稱，否則使用字典查找
                shares: shares,
                averagePrice: price,
                currentPrice: price,
                lastUpdated: Date()
            )
            holdings.append(newHolding)
        }
        
        // 記錄買進交易
        let feeCalculator = FeeCalculator.shared
        let fees = feeCalculator.calculateTradingFees(amount: totalCost, action: .buy)
        
        let buyRecord = TradingRecord.createBuyRecord(
            userId: currentUser,
            tournamentId: tournamentId,
            symbol: symbol,
            stockName: stockName ?? getStockName(for: symbol),
            shares: shares,
            price: price,
            fee: fees.totalFees,
            notes: nil
        )
        tradingRecords.append(buyRecord)
        
        totalInvested += totalCost
        savePortfolio()
        saveTradingRecords()
        
        // 通知同步服務有數據變更
        Task { @MainActor in
            PortfolioSyncService.shared.hasPendingChanges = true
        }
        
        return true
    }
    
    func sellStock(symbol: String, shares: Double, price: Double, tournamentId: UUID? = nil) -> Bool {
        print("🔄 [ChatPortfolioManager] sellStock 開始: \(symbol), 股數: \(shares), 價格: \(price)")
        
        guard let index = holdings.firstIndex(where: { $0.symbol == symbol }) else {
            print("❌ [ChatPortfolioManager] sellStock: 沒有找到股票 \(symbol)")
            return false
        }
        
        let holding = holdings[index]
        print("🔍 [ChatPortfolioManager] sellStock: 找到持股 \(symbol), 持有股數: \(holding.shares)")
        
        guard canSell(symbol: symbol, shares: shares) else {
            print("❌ [ChatPortfolioManager] sellStock: canSell 檢查失敗")
            return false
        }
        
        print("✅ [ChatPortfolioManager] sellStock: canSell 檢查通過，開始執行賣出")
        
        let saleValue = shares * price
        let costBasis = shares * holding.averagePrice
        
        // 記錄賣出交易
        let currentUser = getCurrentUser()
        let sellRecord = TradingRecord.createSellRecord(
            userId: currentUser,
            tournamentId: tournamentId,
            symbol: symbol,
            stockName: holding.name,
            shares: shares,
            price: price,
            averageCost: holding.averagePrice,
            fee: saleValue * 0.001425, // 手續費 0.1425%
            notes: nil
        )
        tradingRecords.append(sellRecord)
        
        if holding.shares == shares {
            // 全部賣出
            holdings.remove(at: index)
        } else {
            // 部分賣出
            let newShares = holding.shares - shares
            holdings[index] = PortfolioHolding(
                id: holding.id,
                userId: holding.userId,
                symbol: symbol,
                name: holding.name,
                shares: newShares,
                averagePrice: holding.averagePrice,
                currentPrice: price,
                lastUpdated: Date()
            )
        }
        
        totalInvested -= costBasis
        savePortfolio()
        saveTradingRecords()
        
        // 通知同步服務有數據變更
        Task { @MainActor in
            PortfolioSyncService.shared.hasPendingChanges = true
        }
        
        print("✅ [ChatPortfolioManager] sellStock 成功完成: \(symbol), 賣出股數: \(shares)")
        return true
    }
    
    // MARK: - Utility Methods
    
    /// 獲取股票名稱（模擬數據）
    private func getStockName(for symbol: String) -> String {
        let stockNames: [String: String] = [
            "2330": "台積電",
            "2317": "鴻海",
            "2454": "聯發科",
            "2881": "富邦金",
            "2882": "國泰金",
            "2886": "兆豐金",
            "2891": "中信金",
            "6505": "台塑化",
            "3008": "大立光",
            "2308": "台達電",
            "0050": "台灣50",
            "2002": "中興", // 新增中興
            "AAPL": "Apple Inc",
            "TSLA": "Tesla Inc",
            "NVDA": "NVIDIA Corp",
            "GOOGL": "Alphabet Inc",
            "MSFT": "Microsoft Corp"
        ]
        return stockNames[symbol] ?? symbol
    }
    
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
    
    // MARK: - Portfolio Management
    
    /// 清空當前用戶的投資組合 (測試用)
    func clearCurrentUserPortfolio() {
        print("🧹 [ChatPortfolioManager] 開始清空當前用戶投資組合")
        
        // 清空本地數據
        holdings.removeAll()
        tradingRecords.removeAll() // 同時清空交易記錄
        totalInvested = 0
        virtualBalance = 1_000_000 // 重置為初始資金
        
        // 清空 UserDefaults
        UserDefaults.standard.removeObject(forKey: "chat_portfolio_holdings")
        UserDefaults.standard.removeObject(forKey: "chat_trading_records")
        UserDefaults.standard.removeObject(forKey: "chat_total_invested")
        UserDefaults.standard.set(virtualBalance, forKey: "chat_virtual_balance")
        
        print("✅ [ChatPortfolioManager] 當前用戶投資組合已清空")
        print("💰 [ChatPortfolioManager] 重置虛擬資金: NT$\(String(format: "%.0f", virtualBalance))")
    }
    
    /// 獲取投資組合統計資訊
    func getPortfolioStats() -> (totalHoldings: Int, totalValue: Double, availableBalance: Double) {
        return (
            totalHoldings: holdings.count,
            totalValue: totalPortfolioValue,
            availableBalance: availableBalance
        )
    }
    
    // MARK: - Trading Records Management
    
    /// 保存交易記錄到本地
    private func saveTradingRecords() {
        if let encoded = try? JSONEncoder().encode(tradingRecords) {
            UserDefaults.standard.set(encoded, forKey: "chat_trading_records")
        }
    }
    
    /// 從本地載入交易記錄
    private func loadTradingRecords() {
        if let data = UserDefaults.standard.data(forKey: "chat_trading_records"),
           let decodedRecords = try? JSONDecoder().decode([TradingRecord].self, from: data) {
            tradingRecords = decodedRecords
        }
    }
    
    /// 獲取交易統計數據
    func getTradingStatistics() -> TradingStatistics {
        let buyRecords = tradingRecords.filter { $0.type == .buy }
        let sellRecords = tradingRecords.filter { $0.type == .sell }
        
        let totalVolume = tradingRecords.reduce(0) { $0 + $1.totalAmount }
        let totalRealizedGainLoss = sellRecords.compactMap { $0.realizedGainLoss }.reduce(0, +)
        let totalFees = tradingRecords.reduce(0) { $0 + $1.fee }
        
        let profitableSelldingRecords = sellRecords.filter { ($0.realizedGainLoss ?? 0) > 0 }
        let winRate = sellRecords.isEmpty ? 0 : Double(profitableSelldingRecords.count) / Double(sellRecords.count) * 100
        
        let todayRecords = tradingRecords.filter { $0.isToday }
        let weekRecords = tradingRecords.filter { $0.isThisWeek }
        let monthRecords = tradingRecords.filter { $0.isThisMonth }
        
        return TradingStatistics(
            totalTrades: tradingRecords.count,
            totalVolume: totalVolume,
            buyTrades: buyRecords.count,
            sellTrades: sellRecords.count,
            totalRealizedGainLoss: totalRealizedGainLoss,
            totalFees: totalFees,
            averageTradeSize: tradingRecords.isEmpty ? 0 : totalVolume / Double(tradingRecords.count),
            winRate: winRate,
            todayTrades: todayRecords.count,
            weekTrades: weekRecords.count,
            monthTrades: monthRecords.count
        )
    }
    
    /// 刷新統計數據（觸發 UI 更新）
    func refreshStatistics() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
        print("📊 [ChatPortfolioManager] 統計數據已刷新")
    }
    
    /// 根據篩選條件獲取交易記錄
    func getFilteredTradingRecords(_ filter: TradingRecordFilter) -> [TradingRecord] {
        return tradingRecords
            .filter { filter.matches($0) }
            .sorted { $0.timestamp > $1.timestamp } // 最新的在前
    }
    
    /// 獲取特定時間範圍的交易記錄
    func getTradingRecords(for dateRange: TradingRecordFilter.DateRange) -> [TradingRecord] {
        let filter = TradingRecordFilter(dateRange: dateRange)
        return getFilteredTradingRecords(filter)
    }
    
    /// 獲取特定股票的交易記錄
    func getTradingRecords(for symbol: String) -> [TradingRecord] {
        return tradingRecords
            .filter { $0.symbol == symbol }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    
    // MARK: - 錦標賽切換功能
    
    /// 切換到指定錦標賽
    func switchToTournament(tournamentId: UUID, tournamentName: String) {
        print("🏆 [ChatPortfolioManager] 切換到錦標賽: \(tournamentName)")
        
        // 保存當前錦標賽的數據
        if let currentId = currentTournamentId {
            saveTournamentData(for: currentId)
        }
        
        // 切換到新錦標賽
        currentTournamentId = tournamentId
        currentTournamentName = tournamentName
        
        // 載入新錦標賽的數據
        loadTournamentData(for: tournamentId)
        
        // 通知UI更新
        objectWillChange.send()
    }
    
    /// 保存當前錦標賽數據
    private func saveTournamentData(for tournamentId: UUID) {
        let key = tournamentId.uuidString
        tournamentPortfolios[key] = holdings
        tournamentBalances[key] = virtualBalance
        tournamentInvested[key] = totalInvested
        tournamentRecords[key] = tradingRecords
        
        print("💾 [ChatPortfolioManager] 已保存錦標賽數據: \(key)")
    }
    
    /// 載入指定錦標賽數據
    private func loadTournamentData(for tournamentId: UUID) {
        let key = tournamentId.uuidString
        
        // 載入投資組合數據，如果沒有則使用預設值
        holdings = tournamentPortfolios[key] ?? []
        virtualBalance = tournamentBalances[key] ?? 1_000_000
        totalInvested = tournamentInvested[key] ?? 0
        
        // 載入交易記錄，過濾出屬於此錦標賽的記錄
        if let savedRecords = tournamentRecords[key] {
            tradingRecords = savedRecords
        } else {
            // 如果沒有保存的記錄，從全部記錄中過濾
            tradingRecords = getAllTradingRecords().filter { record in
                record.tournamentId == tournamentId
            }
        }
        
        print("📂 [ChatPortfolioManager] 已載入錦標賽數據: \(key)")
        print("   - 持股數: \(holdings.count)")
        print("   - 虛擬餘額: \(virtualBalance)")
        print("   - 交易記錄數: \(tradingRecords.count)")
    }
    
    /// 獲取所有交易記錄（跨錦標賽）
    private func getAllTradingRecords() -> [TradingRecord] {
        // 從UserDefaults載入所有交易記錄
        if let data = UserDefaults.standard.data(forKey: "chat_trading_records"),
           let allRecords = try? JSONDecoder().decode([TradingRecord].self, from: data) {
            return allRecords
        }
        return []
    }
    
    /// 重置到預設錦標賽（2025年度投資錦標賽）
    func resetToDefaultTournament() {
        // 創建或獲取2025年度錦標賽ID
        let defaultTournamentId = UUID() // 實際應用中這應該是固定的UUID
        switchToTournament(tournamentId: defaultTournamentId, tournamentName: "2025年度投資錦標賽")
    }
    
    /// 獲取當前錦標賽的投資組合摘要
    func getCurrentTournamentSummary() -> (holdings: Int, balance: Double, totalValue: Double) {
        return (
            holdings: holdings.count,
            balance: virtualBalance,
            totalValue: totalPortfolioValue
        )
    }
}