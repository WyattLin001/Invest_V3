//
//  TournamentPerformanceHistory.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽歷史績效數據模型 - 用於存儲和管理錦標賽的歷史績效數據
//

import Foundation

// MARK: - 錦標賽每日績效快照
/// 記錄錦標賽參與者在特定日期的績效數據
struct TournamentDailySnapshot: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let snapshotDate: Date
    
    // 投資組合數據
    let portfolioValue: Double        // 投資組合總價值
    let cashBalance: Double           // 現金餘額
    let investedValue: Double         // 投資價值
    let totalReturn: Double           // 累計收益金額
    let totalReturnPercentage: Double // 累計收益率
    let dailyReturn: Double           // 當日收益金額
    let dailyReturnPercentage: Double // 當日收益率
    
    // 績效指標
    let maxDrawdown: Double           // 最大回撤金額
    let maxDrawdownPercentage: Double // 最大回撤百分比
    let sharpeRatio: Double?          // 夏普比率
    let volatility: Double            // 波動率
    
    // 交易統計
    let totalTrades: Int              // 累計交易次數
    let dailyTrades: Int              // 當日交易次數
    let winRate: Double               // 勝率
    
    // 排名資訊
    let rank: Int                     // 當日排名
    let totalParticipants: Int        // 總參與人數
    let percentile: Double            // 百分位數
    
    // 時間戳
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: UUID = UUID(),
        tournamentId: UUID,
        userId: UUID,
        snapshotDate: Date,
        portfolioValue: Double,
        cashBalance: Double,
        investedValue: Double,
        totalReturn: Double,
        totalReturnPercentage: Double,
        dailyReturn: Double,
        dailyReturnPercentage: Double,
        maxDrawdown: Double,
        maxDrawdownPercentage: Double,
        sharpeRatio: Double? = nil,
        volatility: Double = 0.0,
        totalTrades: Int,
        dailyTrades: Int,
        winRate: Double,
        rank: Int,
        totalParticipants: Int,
        percentile: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tournamentId = tournamentId
        self.userId = userId
        self.snapshotDate = snapshotDate
        self.portfolioValue = portfolioValue
        self.cashBalance = cashBalance
        self.investedValue = investedValue
        self.totalReturn = totalReturn
        self.totalReturnPercentage = totalReturnPercentage
        self.dailyReturn = dailyReturn
        self.dailyReturnPercentage = dailyReturnPercentage
        self.maxDrawdown = maxDrawdown
        self.maxDrawdownPercentage = maxDrawdownPercentage
        self.sharpeRatio = sharpeRatio
        self.volatility = volatility
        self.totalTrades = totalTrades
        self.dailyTrades = dailyTrades
        self.winRate = winRate
        self.rank = rank
        self.totalParticipants = totalParticipants
        self.percentile = percentile
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, rank, volatility, percentile
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case snapshotDate = "snapshot_date"
        case portfolioValue = "portfolio_value"
        case cashBalance = "cash_balance"
        case investedValue = "invested_value"
        case totalReturn = "total_return"
        case totalReturnPercentage = "total_return_percentage"
        case dailyReturn = "daily_return"
        case dailyReturnPercentage = "daily_return_percentage"
        case maxDrawdown = "max_drawdown"
        case maxDrawdownPercentage = "max_drawdown_percentage"
        case sharpeRatio = "sharpe_ratio"
        case totalTrades = "total_trades"
        case dailyTrades = "daily_trades"
        case winRate = "win_rate"
        case totalParticipants = "total_participants"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 錦標賽績效歷史管理器
/// 管理錦標賽的歷史績效數據
class TournamentPerformanceHistoryManager: ObservableObject {
    static let shared = TournamentPerformanceHistoryManager()
    
    // 本地快照緩存
    @Published var snapshots: [UUID: [TournamentDailySnapshot]] = [:]
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "TournamentPerformanceSnapshots"
    
    private init() {
        loadCachedSnapshots()
    }
    
    // MARK: - 快照管理
    
    /// 創建新的每日快照
    func createDailySnapshot(
        for tournamentId: UUID,
        userId: UUID,
        portfolio: TournamentPortfolio,
        rank: Int,
        totalParticipants: Int
    ) -> TournamentDailySnapshot {
        let today = Calendar.current.startOfDay(for: Date())
        let previousSnapshot = getLatestSnapshot(for: tournamentId, userId: userId)
        
        // 計算當日收益
        let dailyReturn = previousSnapshot?.portfolioValue != nil 
            ? portfolio.totalPortfolioValue - (previousSnapshot!.portfolioValue)
            : 0.0
        let dailyReturnPercentage = previousSnapshot?.portfolioValue != nil && previousSnapshot!.portfolioValue > 0
            ? (dailyReturn / previousSnapshot!.portfolioValue) * 100
            : 0.0
        
        // 計算當日交易次數
        let dailyTrades = countDailyTrades(for: portfolio, date: today)
        
        // 計算百分位數
        let percentile = totalParticipants > 0 ? (Double(totalParticipants - rank + 1) / Double(totalParticipants)) * 100 : 0
        
        let snapshot = TournamentDailySnapshot(
            tournamentId: tournamentId,
            userId: userId,
            snapshotDate: today,
            portfolioValue: portfolio.totalPortfolioValue,
            cashBalance: portfolio.currentBalance,
            investedValue: portfolio.totalInvested,
            totalReturn: portfolio.totalReturn,
            totalReturnPercentage: portfolio.totalReturnPercentage,
            dailyReturn: dailyReturn,
            dailyReturnPercentage: dailyReturnPercentage,
            maxDrawdown: portfolio.performanceMetrics.maxDrawdown,
            maxDrawdownPercentage: portfolio.performanceMetrics.maxDrawdownPercentage,
            sharpeRatio: portfolio.performanceMetrics.sharpeRatio,
            volatility: calculateVolatility(for: tournamentId, userId: userId),
            totalTrades: portfolio.performanceMetrics.totalTrades,
            dailyTrades: dailyTrades,
            winRate: portfolio.performanceMetrics.winRate,
            rank: rank,
            totalParticipants: totalParticipants,
            percentile: percentile
        )
        
        // 存儲到緩存
        addSnapshotToCache(snapshot)
        
        return snapshot
    }
    
    /// 獲取指定錦標賽和用戶的所有快照
    func getSnapshots(for tournamentId: UUID, userId: UUID) -> [TournamentDailySnapshot] {
        let key = snapshotKey(tournamentId: tournamentId, userId: userId)
        return snapshots[key] ?? []
    }
    
    /// 獲取指定時間範圍的快照
    func getSnapshots(
        for tournamentId: UUID,
        userId: UUID,
        from startDate: Date,
        to endDate: Date
    ) -> [TournamentDailySnapshot] {
        let allSnapshots = getSnapshots(for: tournamentId, userId: userId)
        return allSnapshots.filter { snapshot in
            snapshot.snapshotDate >= startDate && snapshot.snapshotDate <= endDate
        }.sorted { $0.snapshotDate < $1.snapshotDate }
    }
    
    /// 獲取最新快照
    func getLatestSnapshot(for tournamentId: UUID, userId: UUID) -> TournamentDailySnapshot? {
        let allSnapshots = getSnapshots(for: tournamentId, userId: userId)
        return allSnapshots.sorted { $0.snapshotDate > $1.snapshotDate }.first
    }
    
    /// 檢查今日是否已有快照
    func hasTodaySnapshot(for tournamentId: UUID, userId: UUID) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let todaySnapshots = getSnapshots(for: tournamentId, userId: userId).filter {
            Calendar.current.isDate($0.snapshotDate, inSameDayAs: today)
        }
        return !todaySnapshots.isEmpty
    }
    
    /// 更新快照
    func updateSnapshot(_ snapshot: TournamentDailySnapshot) {
        let key = snapshotKey(tournamentId: snapshot.tournamentId, userId: snapshot.userId)
        var userSnapshots = snapshots[key] ?? []
        
        if let index = userSnapshots.firstIndex(where: { $0.id == snapshot.id }) {
            userSnapshots[index] = snapshot
        } else {
            userSnapshots.append(snapshot)
        }
        
        snapshots[key] = userSnapshots.sorted { $0.snapshotDate < $1.snapshotDate }
        saveCachedSnapshots()
    }
    
    // MARK: - 數據分析方法
    
    /// 生成圖表數據點
    func generateChartData(
        for tournamentId: UUID,
        userId: UUID,
        timeRange: PerformanceTimeRange,
        metric: TournamentPerformanceMetric
    ) -> [TournamentPerformanceDataPoint] {
        let endDate = Date()
        let startDate = getStartDate(for: timeRange, endDate: endDate)
        let snapshots = getSnapshots(for: tournamentId, userId: userId, from: startDate, to: endDate)
        
        return snapshots.map { snapshot in
            let value = getValue(from: snapshot, for: metric)
            let change = calculateChange(from: snapshot, for: metric)
            
            return TournamentPerformanceDataPoint(
                date: snapshot.snapshotDate,
                value: value,
                change: change
            )
        }
    }
    
    /// 計算績效統計
    func calculatePerformanceStats(
        for tournamentId: UUID,
        userId: UUID,
        timeRange: PerformanceTimeRange
    ) -> TournamentPerformanceStats? {
        let endDate = Date()
        let startDate = getStartDate(for: timeRange, endDate: endDate)
        let snapshots = getSnapshots(for: tournamentId, userId: userId, from: startDate, to: endDate)
        
        guard !snapshots.isEmpty else { return nil }
        
        let portfolioValues = snapshots.map { $0.portfolioValue }
        let dailyReturns = snapshots.map { $0.dailyReturnPercentage }
        
        let maxValue = portfolioValues.max() ?? 0
        let minValue = portfolioValues.min() ?? 0
        let totalReturn = snapshots.last!.totalReturnPercentage - (snapshots.first?.totalReturnPercentage ?? 0)
        let volatility = calculateVolatility(from: dailyReturns)
        let maxDrawdown = snapshots.map { $0.maxDrawdownPercentage }.max() ?? 0
        let sharpeRatio = calculateSharpeRatio(from: dailyReturns)
        
        return TournamentPerformanceStats(
            timeRange: timeRange,
            totalReturn: totalReturn,
            volatility: volatility,
            maxDrawdown: maxDrawdown,
            sharpeRatio: sharpeRatio,
            maxValue: maxValue,
            minValue: minValue,
            dataPoints: snapshots.count
        )
    }
    
    // MARK: - 私有方法
    
    private func snapshotKey(tournamentId: UUID, userId: UUID) -> UUID {
        let combined = "\(tournamentId.uuidString)-\(userId.uuidString)"
        return UUID(uuidString: combined) ?? UUID()
    }
    
    private func addSnapshotToCache(_ snapshot: TournamentDailySnapshot) {
        let key = snapshotKey(tournamentId: snapshot.tournamentId, userId: snapshot.userId)
        var userSnapshots = snapshots[key] ?? []
        
        // 檢查是否已存在同一日期的快照
        if let existingIndex = userSnapshots.firstIndex(where: {
            Calendar.current.isDate($0.snapshotDate, inSameDayAs: snapshot.snapshotDate)
        }) {
            userSnapshots[existingIndex] = snapshot
        } else {
            userSnapshots.append(snapshot)
        }
        
        snapshots[key] = userSnapshots.sorted { $0.snapshotDate < $1.snapshotDate }
        saveCachedSnapshots()
    }
    
    private func countDailyTrades(for portfolio: TournamentPortfolio, date: Date) -> Int {
        let calendar = Calendar.current
        return portfolio.tradingRecords.filter { record in
            calendar.isDate(record.tradeDate, inSameDayAs: date)
        }.count
    }
    
    private func calculateVolatility(for tournamentId: UUID, userId: UUID) -> Double {
        let snapshots = getSnapshots(for: tournamentId, userId: userId)
        let dailyReturns = snapshots.map { $0.dailyReturnPercentage }
        return calculateVolatility(from: dailyReturns)
    }
    
    private func calculateVolatility(from returns: [Double]) -> Double {
        guard returns.count > 1 else { return 0 }
        
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count - 1)
        return sqrt(variance)
    }
    
    private func calculateSharpeRatio(from returns: [Double], riskFreeRate: Double = 0.02) -> Double {
        guard returns.count > 1 else { return 0 }
        
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let volatility = calculateVolatility(from: returns)
        
        guard volatility > 0 else { return 0 }
        return (avgReturn - riskFreeRate) / volatility
    }
    
    private func getStartDate(for timeRange: PerformanceTimeRange, endDate: Date) -> Date {
        let calendar = Calendar.current
        switch timeRange {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            return calendar.date(byAdding: .year, value: -2, to: endDate) ?? endDate
        }
    }
    
    private func getValue(from snapshot: TournamentDailySnapshot, for metric: TournamentPerformanceMetric) -> Double {
        switch metric {
        case .portfolio:
            return snapshot.portfolioValue
        case .returns:
            return snapshot.totalReturnPercentage
        case .dailyChange:
            return snapshot.dailyReturnPercentage
        case .trades:
            return Double(snapshot.totalTrades)
        }
    }
    
    private func calculateChange(from snapshot: TournamentDailySnapshot, for metric: TournamentPerformanceMetric) -> Double? {
        switch metric {
        case .portfolio, .returns:
            return snapshot.dailyReturnPercentage
        case .dailyChange:
            return nil
        case .trades:
            return Double(snapshot.dailyTrades)
        }
    }
    
    // MARK: - 持久化
    
    private func loadCachedSnapshots() {
        guard let data = userDefaults.data(forKey: cacheKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            snapshots = try decoder.decode([UUID: [TournamentDailySnapshot]].self, from: data)
        } catch {
            print("❌ [TournamentPerformanceHistoryManager] 載入快照緩存失敗: \(error)")
            snapshots = [:]
        }
    }
    
    private func saveCachedSnapshots() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshots)
            userDefaults.set(data, forKey: cacheKey)
        } catch {
            print("❌ [TournamentPerformanceHistoryManager] 保存快照緩存失敗: \(error)")
        }
    }
}

// MARK: - 支援數據結構

/// 績效指標類型
enum TournamentPerformanceMetric: String, CaseIterable {
    case portfolio = "投資組合價值"
    case returns = "累計報酬率"
    case dailyChange = "每日變化"
    case trades = "交易次數"
}

/// 績效統計數據
struct TournamentPerformanceStats {
    let timeRange: PerformanceTimeRange
    let totalReturn: Double
    let volatility: Double
    let maxDrawdown: Double
    let sharpeRatio: Double
    let maxValue: Double
    let minValue: Double
    let dataPoints: Int
}