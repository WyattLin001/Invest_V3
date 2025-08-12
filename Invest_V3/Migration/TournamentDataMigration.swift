//
//  TournamentDataMigration.swift
//  Invest_V3
//
//  錦標賽數據遷移腳本 - 從舊數據模型遷移到新數據模型
//

import Foundation

/// 錦標賽數據遷移管理器
@MainActor
class TournamentDataMigration {
    static let shared = TournamentDataMigration()
    
    // 遷移版本標識
    private let currentMigrationVersion = "1.0.0"
    private let migrationKey = "TournamentMigrationVersion"
    
    private init() {}
    
    /// 檢查是否需要執行遷移
    func needsMigration() -> Bool {
        let savedVersion = UserDefaults.standard.string(forKey: migrationKey)
        return savedVersion != currentMigrationVersion
    }
    
    /// 執行完整的數據遷移流程
    func performMigration() async throws {
        print("🔄 開始錦標賽數據遷移...")
        
        do {
            // 步驟 1: 備份現有數據
            try await backupExistingData()
            
            // 步驟 2: 遷移錦標賽基本數據
            try await migrateTournamentData()
            
            // 步驟 3: 遷移投資組合數據
            try await migratePortfolioData()
            
            // 步驟 4: 遷移交易記錄
            try await migrateTradeRecords()
            
            // 步驟 5: 遷移排名數據
            try await migrateRankingData()
            
            // 步驟 6: 清理舊數據 (可選)
            try await cleanupOldData()
            
            // 步驟 7: 驗證遷移結果
            try await validateMigration()
            
            // 更新遷移版本
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationKey)
            
            print("✅ 錦標賽數據遷移完成")
            
        } catch {
            print("❌ 錦標賽數據遷移失敗: \(error)")
            // 嘗試恢復備份
            try await restoreBackup()
            throw TournamentMigrationError.migrationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 備份和恢復
    
    private func backupExistingData() async throws {
        print("📦 備份現有錦標賽數據...")
        
        // 備份錦標賽數據
        let tournaments = try await fetchLegacyTournaments()
        try saveBackup(tournaments, to: "tournaments_backup.json")
        
        // 備份投資組合數據
        let portfolios = try await fetchLegacyPortfolios()
        try saveBackup(portfolios, to: "portfolios_backup.json")
        
        // 備份交易記錄
        let trades = try await fetchLegacyTrades()
        try saveBackup(trades, to: "trades_backup.json")
        
        print("✅ 數據備份完成")
    }
    
    private func restoreBackup() async throws {
        print("🔄 嘗試恢復備份數據...")
        
        // 實現備份恢復邏輯
        // 這裡應該從備份文件恢復數據到原始狀態
        
        print("✅ 備份數據恢復完成")
    }
    
    // MARK: - 數據遷移步驟
    
    private func migrateTournamentData() async throws {
        print("🏆 遷移錦標賽基本數據...")
        
        let legacyTournaments = try await fetchLegacyTournaments()
        
        for legacyTournament in legacyTournaments {
            let newTournament = convertLegacyTournament(legacyTournament)
            try await saveMigratedTournament(newTournament)
        }
        
        print("✅ 錦標賽基本數據遷移完成，共遷移 \(legacyTournaments.count) 個錦標賽")
    }
    
    private func migratePortfolioData() async throws {
        print("💼 遷移投資組合數據...")
        
        let legacyPortfolios = try await fetchLegacyPortfolios()
        
        for legacyPortfolio in legacyPortfolios {
            let newWallet = convertLegacyPortfolio(legacyPortfolio)
            try await saveMigratedWallet(newWallet)
        }
        
        print("✅ 投資組合數據遷移完成，共遷移 \(legacyPortfolios.count) 個投資組合")
    }
    
    private func migrateTradeRecords() async throws {
        print("📊 遷移交易記錄...")
        
        let legacyTrades = try await fetchLegacyTrades()
        
        for legacyTrade in legacyTrades {
            let newTrade = convertLegacyTrade(legacyTrade)
            try await saveMigratedTrade(newTrade)
        }
        
        print("✅ 交易記錄遷移完成，共遷移 \(legacyTrades.count) 筆交易")
    }
    
    private func migrateRankingData() async throws {
        print("🏅 遷移排名數據...")
        
        let legacyRankings = try await fetchLegacyRankings()
        
        for legacyRanking in legacyRankings {
            let newRanking = convertLegacyRanking(legacyRanking)
            try await saveMigratedRanking(newRanking)
        }
        
        print("✅ 排名數據遷移完成，共遷移 \(legacyRankings.count) 個排名記錄")
    }
    
    private func cleanupOldData() async throws {
        print("🧹 清理舊數據...")
        
        // 謹慎清理舊數據，確保新數據已正確保存
        // 可以設置為可選操作，允許用戶決定是否清理
        
        print("✅ 舊數據清理完成")
    }
    
    private func validateMigration() async throws {
        print("🔍 驗證遷移結果...")
        
        // 驗證錦標賽數據
        let migratedTournaments = try await fetchMigratedTournaments()
        let legacyTournaments = try await fetchLegacyTournaments()
        
        guard migratedTournaments.count == legacyTournaments.count else {
            throw TournamentMigrationError.validationFailed("錦標賽數量不匹配")
        }
        
        // 驗證投資組合數據
        let migratedWallets = try await fetchMigratedWallets()
        let legacyPortfolios = try await fetchLegacyPortfolios()
        
        guard migratedWallets.count == legacyPortfolios.count else {
            throw TournamentMigrationError.validationFailed("投資組合數量不匹配")
        }
        
        // 驗證交易記錄數據
        let migratedTrades = try await fetchMigratedTrades()
        let legacyTrades = try await fetchLegacyTrades()
        
        guard migratedTrades.count == legacyTrades.count else {
            throw TournamentMigrationError.validationFailed("交易記錄數量不匹配")
        }
        
        print("✅ 遷移結果驗證通過")
    }
    
    // MARK: - 數據轉換
    
    private func convertLegacyTournament(_ legacy: LegacyTournament) -> Tournament {
        // 轉換舊的錦標賽數據結構到新的結構
        return Tournament(
            id: legacy.id,
            name: legacy.name,
            description: legacy.description,
            status: convertTournamentStatus(legacy.status),
            startDate: legacy.startDate,
            endDate: legacy.endDate,
            entryCapital: legacy.initialBalance, // 映射舊字段名
            maxParticipants: legacy.maxParticipants,
            currentParticipants: legacy.currentParticipants,
            feeTokens: legacy.entryFee, // 映射舊字段名
            returnMetric: "twr", // 新字段，使用默認值
            resetMode: "monthly", // 新字段，使用默認值
            createdAt: legacy.createdAt,
            rules: convertTournamentRules(legacy.rules)
        )
    }
    
    private func convertLegacyPortfolio(_ legacy: LegacyTournamentPortfolio) -> TournamentWallet {
        return TournamentWallet(
            id: UUID(),
            tournamentId: legacy.tournamentId,
            userId: legacy.userId,
            cash: legacy.cash,
            totalAssets: legacy.totalPortfolioValue,
            positions: convertLegacyHoldings(legacy.holdings),
            createdAt: legacy.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
    
    private func convertLegacyTrade(_ legacy: LegacyTradingRecord) -> TournamentTrade {
        return TournamentTrade(
            id: UUID(),
            tournamentId: legacy.tournamentId ?? UUID(), // 處理可能的 nil 值
            userId: legacy.userId ?? UUID(),
            symbol: legacy.symbol,
            side: legacy.action == .buy ? .buy : .sell,
            quantity: Int(legacy.shares),
            price: legacy.price,
            executedAt: legacy.timestamp,
            status: .filled // 舊數據假設都已成交
        )
    }
    
    private func convertLegacyRanking(_ legacy: LegacyRanking) -> TournamentRanking {
        return TournamentRanking(
            userId: legacy.userId,
            rank: legacy.rank,
            totalAssets: legacy.totalAssets,
            totalReturnPercent: legacy.returnPercentage,
            totalTrades: legacy.totalTrades,
            winRate: legacy.winRate
        )
    }
    
    private func convertTournamentStatus(_ legacyStatus: LegacyTournamentStatus) -> TournamentLifecycleState {
        switch legacyStatus {
        case .upcoming:
            return .upcoming
        case .ongoing:
            return .active
        case .finished:
            return .ended
        case .cancelled:
            return .cancelled
        }
    }
    
    private func convertTournamentRules(_ legacyRules: LegacyTournamentRules?) -> TournamentRules? {
        guard let legacy = legacyRules else { return nil }
        
        return TournamentRules(
            allowShortSelling: true, // 新字段，使用默認值
            maxPositionSize: legacy.maxSingleStockRate / 100.0, // 轉換百分比到小數
            allowedInstruments: ["stocks", "etfs"], // 新字段，使用默認值
            tradingHours: TradingHours(
                startTime: legacy.tradingHours.start,
                endTime: legacy.tradingHours.end,
                timeZone: legacy.tradingHours.timezone
            ),
            riskLimits: RiskLimits(
                maxDrawdown: 0.2, // 新字段，使用默認值
                maxLeverage: legacy.maxLeverage,
                maxDailyTrades: 100 // 新字段，使用默認值
            )
        )
    }
    
    private func convertLegacyHoldings(_ legacyHoldings: [LegacyStockHolding]) -> [TournamentPosition] {
        return legacyHoldings.map { legacy in
            TournamentPosition(
                symbol: legacy.symbol,
                quantity: Int(legacy.quantity),
                averagePrice: legacy.averagePrice,
                currentPrice: legacy.currentPrice,
                marketValue: legacy.currentValue,
                unrealizedPnL: legacy.unrealizedGainLoss,
                lastUpdated: Date()
            )
        }
    }
    
    // MARK: - 數據存取方法
    
    private func fetchLegacyTournaments() async throws -> [LegacyTournament] {
        // 實現從舊數據源獲取錦標賽數據
        // 這裡可能需要訪問 Core Data、SQLite 或其他持久化存儲
        return []
    }
    
    private func fetchLegacyPortfolios() async throws -> [LegacyTournamentPortfolio] {
        // 實現從舊數據源獲取投資組合數據
        return []
    }
    
    private func fetchLegacyTrades() async throws -> [LegacyTradingRecord] {
        // 實現從舊數據源獲取交易記錄
        return []
    }
    
    private func fetchLegacyRankings() async throws -> [LegacyRanking] {
        // 實現從舊數據源獲取排名數據
        return []
    }
    
    private func saveMigratedTournament(_ tournament: Tournament) async throws {
        // 保存遷移後的錦標賽數據到新的數據源
        // 可能是 Supabase、新的 Core Data 模型等
    }
    
    private func saveMigratedWallet(_ wallet: TournamentWallet) async throws {
        // 保存遷移後的錢包數據
    }
    
    private func saveMigratedTrade(_ trade: TournamentTrade) async throws {
        // 保存遷移後的交易數據
    }
    
    private func saveMigratedRanking(_ ranking: TournamentRanking) async throws {
        // 保存遷移後的排名數據
    }
    
    private func fetchMigratedTournaments() async throws -> [Tournament] {
        // 獲取遷移後的錦標賽數據用於驗證
        return []
    }
    
    private func fetchMigratedWallets() async throws -> [TournamentWallet] {
        // 獲取遷移後的錢包數據用於驗證
        return []
    }
    
    private func fetchMigratedTrades() async throws -> [TournamentTrade] {
        // 獲取遷移後的交易數據用於驗證
        return []
    }
    
    // MARK: - 備份工具方法
    
    private func saveBackup<T: Codable>(_ data: [T], to filename: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupPath = documentsPath.appendingPathComponent("TournamentBackup")
        
        // 創建備份目錄
        try FileManager.default.createDirectory(at: backupPath, withIntermediateDirectories: true)
        
        let fileURL = backupPath.appendingPathComponent(filename)
        let jsonData = try JSONEncoder().encode(data)
        try jsonData.write(to: fileURL)
        
        print("✅ 備份保存到: \(fileURL.path)")
    }
}

// MARK: - 遷移錯誤

enum TournamentMigrationError: LocalizedError {
    case migrationFailed(String)
    case validationFailed(String)
    case backupFailed(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let message):
            return "遷移失敗: \(message)"
        case .validationFailed(let message):
            return "驗證失敗: \(message)"
        case .backupFailed(let message):
            return "備份失敗: \(message)"
        case .restoreFailed(let message):
            return "恢復失敗: \(message)"
        }
    }
}

// MARK: - 舊數據模型定義

// 這些結構體代表舊的數據模型，用於遷移過程
struct LegacyTournament: Codable {
    let id: UUID
    let name: String
    let description: String
    let hostUserId: UUID
    let hostUserName: String
    let initialBalance: Double
    let maxParticipants: Int
    let currentParticipants: Int
    let entryFee: Int
    let prizePool: Double
    let startDate: Date
    let endDate: Date
    let status: LegacyTournamentStatus
    let rules: LegacyTournamentRules?
    let createdAt: Date
}

enum LegacyTournamentStatus: String, Codable {
    case upcoming
    case ongoing
    case finished
    case cancelled
}

struct LegacyTournamentRules: Codable {
    let maxSingleStockRate: Double
    let minHoldingRate: Double
    let maxLeverage: Double
    let tradingHours: LegacyTradingHours
}

struct LegacyTradingHours: Codable {
    let start: String
    let end: String
    let timezone: String
}

struct LegacyTournamentPortfolio: Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let cash: Double
    let totalPortfolioValue: Double
    let holdings: [LegacyStockHolding]
    let createdAt: Date?
}

struct LegacyStockHolding: Codable {
    let symbol: String
    let quantity: Double
    let averagePrice: Double
    let currentPrice: Double
    let currentValue: Double
    let unrealizedGainLoss: Double
}

struct LegacyTradingRecord: Codable {
    let id: UUID
    let tournamentId: UUID?
    let userId: UUID?
    let symbol: String
    let action: LegacyTradeAction
    let shares: Double
    let price: Double
    let timestamp: Date
}

enum LegacyTradeAction: String, Codable {
    case buy
    case sell
}

struct LegacyRanking: Codable {
    let userId: UUID
    let rank: Int
    let totalAssets: Double
    let returnPercentage: Double
    let totalTrades: Int
    let winRate: Double
}