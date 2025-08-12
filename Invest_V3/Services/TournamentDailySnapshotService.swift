//
//  TournamentDailySnapshotService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽每日績效快照服務 - 負責生成和管理每日績效快照
//

import Foundation
import Combine

// MARK: - 每日快照服務
@MainActor
class TournamentDailySnapshotService: ObservableObject {
    static let shared = TournamentDailySnapshotService()
    
    // MARK: - Properties
    @Published var isGeneratingSnapshots = false
    @Published var lastSnapshotDate: Date?
    
    private let historyManager = TournamentPerformanceHistoryManager.shared
    private let portfolioManager = TournamentPortfolioManager.shared
    private let tournamentService = TournamentService.shared
    private var snapshotTimer: Timer?
    
    // 快照生成配置
    private let snapshotTime: DateComponents = {
        var components = DateComponents()
        components.hour = 23    // 晚上11點
        components.minute = 30  // 30分
        return components
    }()
    
    private init() {
        setupDailySnapshotTimer()
        loadLastSnapshotDate()
    }
    
    // MARK: - Public Methods
    
    /// 手動觸發快照生成
    func generateDailySnapshots() async {
        guard !isGeneratingSnapshots else {
            print("⏳ [TournamentDailySnapshotService] 快照生成已在進行中...")
            return
        }
        
        isGeneratingSnapshots = true
        defer { isGeneratingSnapshots = false }
        
        print("📸 [TournamentDailySnapshotService] 開始生成每日績效快照...")
        
        do {
            let snapshotCount = await generateSnapshotsForAllActiveTournaments()
            
            await MainActor.run {
                lastSnapshotDate = Date()
                saveLastSnapshotDate()
            }
            
            print("✅ [TournamentDailySnapshotService] 已生成 \(snapshotCount) 個績效快照")
            
        } catch {
            print("❌ [TournamentDailySnapshotService] 生成快照失敗: \(error)")
        }
    }
    
    /// 為特定錦標賽生成快照
    func generateSnapshot(
        for tournamentId: UUID,
        userId: UUID,
        force: Bool = false
    ) async -> TournamentDailySnapshot? {
        
        // 檢查今日是否已有快照（除非強制生成）
        if !force && historyManager.hasTodaySnapshot(for: tournamentId, userId: userId) {
            print("ℹ️ [TournamentDailySnapshotService] 今日已有快照，跳過生成")
            return historyManager.getLatestSnapshot(for: tournamentId, userId: userId)
        }
        
        // 獲取投資組合數據
        guard let portfolio = portfolioManager.getPortfolio(for: tournamentId) else {
            print("❌ [TournamentDailySnapshotService] 找不到投資組合: \(tournamentId)")
            return nil
        }
        
        // 獲取排名資訊
        let (rank, totalParticipants) = await getRankingInfo(for: tournamentId, userId: userId)
        
        // 生成快照
        let snapshot = historyManager.createDailySnapshot(
            for: tournamentId,
            userId: userId,
            portfolio: portfolio,
            rank: rank,
            totalParticipants: totalParticipants
        )
        
        print("📸 [TournamentDailySnapshotService] 已為錦標賽 \(tournamentId) 生成快照")
        
        return snapshot
    }
    
    /// 檢查是否需要生成今日快照
    func shouldGenerateTodaySnapshot() -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // 檢查是否已經過了快照時間
        guard let snapshotTimeToday = calendar.nextDate(
            after: calendar.startOfDay(for: today),
            matching: snapshotTime,
            matchingPolicy: .nextTime
        ) else {
            return false
        }
        
        let hasPassedSnapshotTime = today >= snapshotTimeToday
        
        // 檢查今日是否已經生成過快照
        let hasGeneratedToday = lastSnapshotDate.map { date in
            calendar.isDate(date, inSameDayAs: today)
        } ?? false
        
        return hasPassedSnapshotTime && !hasGeneratedToday
    }
    
    /// 獲取快照統計
    func getSnapshotStats() -> SnapshotStats {
        let allSnapshots = historyManager.snapshots.values.flatMap { $0 }
        let todaySnapshots = allSnapshots.filter { snapshot in
            Calendar.current.isDate(snapshot.snapshotDate, inSameDayAs: Date())
        }
        
        return SnapshotStats(
            totalSnapshots: allSnapshots.count,
            todaySnapshots: todaySnapshots.count,
            lastSnapshotDate: lastSnapshotDate
        )
    }
    
    // MARK: - Private Methods
    
    /// 設置每日快照定時器
    private func setupDailySnapshotTimer() {
        // 每小時檢查一次是否需要生成快照
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.shouldGenerateTodaySnapshot() == true {
                    await self?.generateDailySnapshots()
                }
            }
        }
        
        print("⏰ [TournamentDailySnapshotService] 已設置每日快照定時器")
    }
    
    /// 為所有活躍錦標賽生成快照
    private func generateSnapshotsForAllActiveTournaments() async -> Int {
        var snapshotCount = 0
        
        // 獲取所有進行中的錦標賽
        let activeTournaments = tournamentService.tournaments.filter { tournament in
            tournament.computedStatusUTC == .ongoing
        }
        
        print("🏆 [TournamentDailySnapshotService] 找到 \(activeTournaments.count) 個進行中的錦標賽")
        
        // 為每個活躍錦標賽生成快照
        for tournament in activeTournaments {
            let tournamentSnapshots = await generateSnapshotsForTournament(tournament.id)
            snapshotCount += tournamentSnapshots
        }
        
        return snapshotCount
    }
    
    /// 為特定錦標賽的所有參與者生成快照
    private func generateSnapshotsForTournament(_ tournamentId: UUID) async -> Int {
        var count = 0
        
        // 獲取錦標賽的所有投資組合
        let allPortfolios = portfolioManager.getAllPortfolios().filter { portfolio in
            portfolio.tournamentId == tournamentId
        }
        
        print("👥 [TournamentDailySnapshotService] 錦標賽 \(tournamentId) 有 \(allPortfolios.count) 個參與者")
        
        // 為每個參與者生成快照
        for portfolio in allPortfolios {
            if await generateSnapshot(for: tournamentId, userId: portfolio.userId) != nil {
                count += 1
            }
        }
        
        return count
    }
    
    /// 獲取排名資訊
    private func getRankingInfo(for tournamentId: UUID, userId: UUID) async -> (rank: Int, totalParticipants: Int) {
        do {
            // 獲取錦標賽參與者排名
            let participants = try await tournamentService.fetchTournamentParticipants(tournamentId: tournamentId)
            let totalParticipants = participants.count
            
            // 找到當前用戶的排名
            if let userParticipant = participants.first(where: { $0.userId == userId }) {
                return (userParticipant.currentRank, totalParticipants)
            } else {
                // 如果找不到用戶，給予默認排名
                return (totalParticipants, totalParticipants)
            }
        } catch {
            print("❌ [TournamentDailySnapshotService] 獲取排名資訊失敗: \(error)")
            return (1, 1) // 默認排名
        }
    }
    
    // MARK: - 持久化
    
    private func loadLastSnapshotDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "LastSnapshotDate") as? Date {
            lastSnapshotDate = timestamp
        }
    }
    
    private func saveLastSnapshotDate() {
        UserDefaults.standard.set(lastSnapshotDate, forKey: "LastSnapshotDate")
    }
    
    deinit {
        snapshotTimer?.invalidate()
    }
}

// MARK: - 支援數據結構

/// 快照統計信息
struct SnapshotStats {
    let totalSnapshots: Int
    let todaySnapshots: Int
    let lastSnapshotDate: Date?
    
    var formattedLastSnapshotDate: String {
        guard let date = lastSnapshotDate else { return "從未生成" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 快照生成策略
enum SnapshotGenerationStrategy {
    case daily          // 每日生成
    case onDemand      // 按需生成
    case intervalBased // 基於時間間隔
    
    var description: String {
        switch self {
        case .daily:
            return "每日自動生成"
        case .onDemand:
            return "按需手動生成"
        case .intervalBased:
            return "基於時間間隔"
        }
    }
}

// MARK: - 管理方法
extension TournamentDailySnapshotService {
    
    /// 清除所有快照（僅用於重設）
    func clearAllSnapshots() {
        historyManager.snapshots.removeAll()
        lastSnapshotDate = nil
        UserDefaults.standard.removeObject(forKey: "LastSnapshotDate")
        print("🗑️ [TournamentDailySnapshotService] 已清除所有快照數據")
    }
    
    /// 重建歷史快照（基於真實交易紀錄）
    func rebuildHistoricalSnapshots(for tournamentId: UUID, userId: UUID) async {
        guard let portfolio = portfolioManager.getPortfolio(for: tournamentId) else {
            print("⚠️ [TournamentDailySnapshotService] 找不到投資組合: \(tournamentId)")
            return
        }
        
        // 清除舊的快照
        historyManager.clearSnapshots(for: tournamentId, userId: userId)
        
        // 基於交易紀錄重建歷史快照
        let tradingRecords = portfolio.tradingRecords.sorted { $0.tradeDate < $1.tradeDate }
        let calendar = Calendar.current
        
        // 獲取交易日期範圍
        guard let firstTradeDate = tradingRecords.first?.tradeDate else {
            print("⚠️ [TournamentDailySnapshotService] 無法獲取交易歷史")
            return
        }
        
        let tournament: Tournament
        do {
            tournament = try await tournamentService.fetchTournament(id: tournamentId)
        } catch {
            print("⚠️ [TournamentDailySnapshotService] 無法獲取錦標賽資訊: \(error)")
            return
        }
        
        let startDate = max(firstTradeDate, tournament.startDate)
        let endDate = min(Date(), tournament.endDate)
        
        var currentDate = calendar.startOfDay(for: startDate)
        let finalDate = calendar.startOfDay(for: endDate)
        
        var portfolioValueHistory: [Date: Double] = [:]
        var currentValue = tournament.initialBalance
        
        // 逐日重建投資組合價值
        while currentDate <= finalDate {
            // 處理當日的交易
            let dayTrades = tradingRecords.filter { 
                calendar.isDate($0.tradeDate, inSameDayAs: currentDate)
            }
            
            for trade in dayTrades {
                switch trade.type {
                case .buy:
                    currentValue -= trade.totalValue
                case .sell:
                    currentValue += trade.totalValue
                }
            }
            
            portfolioValueHistory[currentDate] = currentValue
            
            // 如果有該日的真實投資組合數據，生成快照
            if let realPortfolio = getRealPortfolioData(for: tournamentId, userId: userId, on: currentDate) {
                let snapshot = historyManager.createDailySnapshot(
                    for: tournamentId,
                    userId: userId,
                    portfolio: realPortfolio,
                    rank: getRankForDate(tournamentId: tournamentId, userId: userId, date: currentDate),
                    totalParticipants: getTotalParticipantsForDate(tournamentId: tournamentId, date: currentDate)
                )
                
                // 調整快照日期
                let adjustedSnapshot = TournamentDailySnapshot(
                    id: snapshot.id,
                    tournamentId: snapshot.tournamentId,
                    userId: snapshot.userId,
                    snapshotDate: currentDate,
                    portfolioValue: snapshot.portfolioValue,
                    cashBalance: snapshot.cashBalance,
                    investedValue: snapshot.investedValue,
                    totalReturn: snapshot.totalReturn,
                    totalReturnPercentage: snapshot.totalReturnPercentage,
                    dailyReturn: snapshot.dailyReturn,
                    dailyReturnPercentage: snapshot.dailyReturnPercentage,
                    maxDrawdown: snapshot.maxDrawdown,
                    maxDrawdownPercentage: snapshot.maxDrawdownPercentage,
                    sharpeRatio: snapshot.sharpeRatio,
                    volatility: snapshot.volatility,
                    totalTrades: snapshot.totalTrades,
                    dailyTrades: snapshot.dailyTrades,
                    winRate: snapshot.winRate,
                    rank: snapshot.rank,
                    totalParticipants: snapshot.totalParticipants,
                    percentile: snapshot.percentile,
                    createdAt: currentDate,
                    updatedAt: currentDate
                )
                
                historyManager.updateSnapshot(adjustedSnapshot)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        print("🔄 [TournamentDailySnapshotService] 已重建歷史快照數據")
    }
    
    // MARK: - 私有輔助方法
    
    private func getRealPortfolioData(for tournamentId: UUID, userId: UUID, on date: Date) -> TournamentPortfolio? {
        // 這裡應該從數據庫或緩存中獲取特定日期的真實投資組合數據
        // 目前返回當前投資組合作為替代
        return portfolioManager.getPortfolio(for: tournamentId)
    }
    
    private func getRankForDate(tournamentId: UUID, userId: UUID, date: Date) -> Int {
        // 這裡應該從歷史排名數據中獲取特定日期的排名
        // 目前返回預設值
        return 1
    }
    
    private func getTotalParticipantsForDate(tournamentId: UUID, date: Date) -> Int {
        // 這裡應該從歷史數據中獲取特定日期的參與人數
        // 目前返回預設值
        return 100
    }
}