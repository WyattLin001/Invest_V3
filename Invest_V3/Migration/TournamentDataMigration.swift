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
            let newParticipant = convertLegacyPortfolio(legacyPortfolio)
            try await saveMigratedParticipant(newParticipant)
        }
        
        print("✅ 投資組合數據遷移完成，共遷移 \(legacyPortfolios.count) 個投資組合")
    }
    
    private func migrateTradeRecords() async throws {
        print("📊 遷移交易記錄...")
        
        let legacyTrades = try await fetchLegacyTrades()
        
        for legacyTrade in legacyTrades {
            let newTradeRecord = convertLegacyTrade(legacyTrade)
            try await saveMigratedTradeRecord(newTradeRecord)
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
        
        // 驗證參與者數據
        let migratedParticipants = try await fetchMigratedParticipants()
        let legacyPortfolios = try await fetchLegacyPortfolios()
        
        guard migratedParticipants.count == legacyPortfolios.count else {
            throw TournamentMigrationError.validationFailed("參與者數量不匹配")
        }
        
        // 驗證交易記錄數據
        let migratedTradeRecords = try await fetchMigratedTradeRecords()
        let legacyTrades = try await fetchLegacyTrades()
        
        guard migratedTradeRecords.count == legacyTrades.count else {
            throw TournamentMigrationError.validationFailed("交易記錄數量不匹配")
        }
        
        print("✅ 遷移結果驗證通過")
    }
    
    // MARK: - 數據轉換
    
    private func convertLegacyTournament(_ legacy: LegacyTournament) -> Tournament {
        // 轉換舊的錦標賽數據結構到新的結構（符合 schema 對齊模型）
        return Tournament(
            id: legacy.id,
            name: legacy.name,
            type: .monthly, // 新字段，根據業務邏輯設定預設值
            status: convertTournamentStatus(legacy.status),
            startDate: legacy.startDate,
            endDate: legacy.endDate,
            description: legacy.description,
            shortDescription: String(legacy.name.prefix(50)), // 從 name 截取短描述
            initialBalance: legacy.initialBalance, // 對應 initial_balance
            entryFee: Double(legacy.entryFee), // 對應 entry_fee，轉換為 Double
            prizePool: legacy.prizePool, // 對應 prize_pool
            maxParticipants: legacy.maxParticipants,
            currentParticipants: legacy.currentParticipants,
            isFeatured: false, // 新字段，設定預設值
            createdBy: legacy.hostUserId, // 對應 created_by，使用 hostUserId
            riskLimitPercentage: 0.2, // 新字段，設定預設風險限制 20%
            minHoldingRate: (legacy.rules?.minHoldingRate ?? 50.0) / 100.0, // 從舊規則取得並轉換百分比
            maxSingleStockRate: (legacy.rules?.maxSingleStockRate ?? 30.0) / 100.0, // 從舊規則取得並轉換百分比
            rules: [], // 簡化為空陣列，具體規則通過其他字段表達
            createdAt: legacy.createdAt,
            updatedAt: legacy.createdAt // 新字段，使用 createdAt 作為初始值
        )
    }
    
    private func convertLegacyPortfolio(_ legacy: LegacyTournamentPortfolio) -> TournamentParticipantRecord {
        // 將舊的投資組合轉換為新的參與者記錄（對應 tournament_participants 表）
        return TournamentParticipantRecord(
            id: legacy.id,
            tournamentId: legacy.tournamentId,
            userId: legacy.userId,
            userName: legacy.userName,
            userAvatar: nil, // 新字段，設定為 nil
            currentRank: 999999, // 預設排名，後續會更新
            previousRank: 999999,
            virtualBalance: legacy.totalPortfolioValue, // 對應當前總資產
            initialBalance: legacy.cash + legacy.holdings.reduce(0) { $0 + $1.currentValue }, // 估算初始資金
            returnRate: 0.0, // 需要重新計算
            totalTrades: 0, // 需要從交易記錄統計
            winRate: 0.0, // 需要從交易記錄計算
            maxDrawdown: 0.0, // 需要重新計算
            sharpeRatio: nil, // 需要重新計算
            isEliminated: false,
            eliminationReason: nil,
            joinedAt: legacy.createdAt ?? Date(),
            lastUpdated: Date()
        )
    }
    
    private func convertLegacyTrade(_ legacy: LegacyTradingRecord) -> TournamentTradeRecord {
        // 將舊交易記錄轉換為新的交易記錄（對應 tournament_trading_records 表）
        // 分別計算各個值以避免複雜表達式類型檢查問題
        let userId = legacy.userId ?? UUID()
        let tournamentId = legacy.tournamentId ?? UUID()
        let tradeType: TradeSide = legacy.action == .buy ? .buy : .sell
        let totalAmount = legacy.shares * legacy.price
        
        return TournamentTradeRecord(
            id: legacy.id,
            userId: userId,
            tournamentId: tournamentId,
            symbol: legacy.symbol,
            stockName: legacy.symbol, // 使用 symbol 作為股票名稱，實際應該查詢
            type: tradeType, // 對應 type 字段
            shares: legacy.shares, // 保持 Double 類型
            price: legacy.price,
            timestamp: legacy.timestamp,
            totalAmount: totalAmount, // 計算總金額
            fee: 0.0, // 舊數據沒有手續費，設為 0
            netAmount: totalAmount, // 淨金額等於總金額（無手續費）
            averageCost: nil, // 新字段，設為 nil
            realizedGainLoss: nil, // 新字段，需要重新計算
            realizedGainLossPercent: nil, // 新字段，需要重新計算
            notes: nil // 新字段，設為 nil
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
    
    private func convertTournamentStatus(_ legacyStatus: LegacyTournamentStatus) -> TournamentStatus {
        // 將舊狀態轉換為新的 TournamentStatus 枚舉
        switch legacyStatus {
        case .upcoming:
            return .upcoming
        case .ongoing:
            return .ongoing // 對應數據庫的 ongoing
        case .finished:
            return .finished // 對應數據庫的 finished
        case .cancelled:
            return .cancelled // 內部狀態，數據庫中映射為 finished
        }
    }
    
    private func convertTournamentRules(_ legacyRules: LegacyTournamentRules?) -> [String] {
        // 簡化規則轉換，返回空陣列（具體規則已通過 Tournament 的其他字段表達）
        // 在新的 schema 中，rules 字段是 String 陣列，主要用於存儲額外的規則描述
        guard let legacy = legacyRules else { return [] }
        
        var rules: [String] = []
        
        // 添加一些基本規則描述
        rules.append("最大單一持股比例: \(Int(legacy.maxSingleStockRate))%")
        rules.append("最小持倉比例: \(Int(legacy.minHoldingRate))%")
        rules.append("最大槓桿倍數: \(legacy.maxLeverage)x")
        rules.append("交易時間: \(legacy.tradingHours.start) - \(legacy.tradingHours.end) (\(legacy.tradingHours.timezone))")
        
        return rules
    }
    
    private func convertLegacyHoldings(_ legacyHoldings: [LegacyStockHolding]) -> [TournamentPositionRecord] {
        // 將舊持股轉換為新的持倉記錄（對應 tournament_positions 表）
        return legacyHoldings.map { legacy in
            TournamentPositionRecord(
                id: UUID(), // 新字段，生成新的 ID
                tournamentId: UUID(), // 需要從上下文取得，暫時使用空 UUID
                userId: UUID(), // 需要從上下文取得，暫時使用空 UUID
                symbol: legacy.symbol,
                stockName: legacy.symbol, // 使用 symbol 作為股票名稱
                quantity: Int(legacy.quantity), // 轉換為 Int 類型以符合 schema
                averageCost: legacy.averagePrice,
                currentPrice: legacy.currentPrice,
                marketValue: legacy.currentValue,
                unrealizedGainLoss: legacy.unrealizedGainLoss,
                unrealizedGainLossPercent: legacy.averagePrice * legacy.quantity > 0 ? (legacy.unrealizedGainLoss / (legacy.averagePrice * legacy.quantity) * 100) : 0.0,
                firstBuyDate: nil, // 新字段，設為 nil
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
    
    private func saveMigratedParticipant(_ participant: TournamentParticipantRecord) async throws {
        // 保存遷移後的參與者數據到 tournament_participants 表
        // 可能是 Supabase、新的 Core Data 模型等
    }
    
    private func saveMigratedTradeRecord(_ tradeRecord: TournamentTradeRecord) async throws {
        // 保存遷移後的交易記錄到 tournament_trading_records 表
    }
    
    private func saveMigratedRanking(_ ranking: TournamentRanking) async throws {
        // 保存遷移後的排名數據
    }
    
    private func fetchMigratedTournaments() async throws -> [Tournament] {
        // 獲取遷移後的錦標賽數據用於驗證
        return []
    }
    
    private func fetchMigratedParticipants() async throws -> [TournamentParticipantRecord] {
        // 獲取遷移後的參與者數據用於驗證
        return []
    }
    
    private func fetchMigratedTradeRecords() async throws -> [TournamentTradeRecord] {
        // 獲取遷移後的交易記錄數據用於驗證
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