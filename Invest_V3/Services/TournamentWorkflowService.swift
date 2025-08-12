//
//  TournamentWorkflowService.swift
//  Invest_V3
//
//  統一錦標賽業務流程服務 - 管理完整的錦標賽生命周期
//  支援：建賽事、參賽、交易、排行、結算的統一業務流程
//

import Foundation
import SwiftUI
import Combine

// 注意：TournamentLifecycleState 和 TournamentCreationParameters 已在 TournamentModels.swift 中定義

// 注意：TournamentRules、TournamentResult、TournamentReward 等已在 TournamentModels.swift 中定義

// MARK: - 錦標賽工作流程服務
@MainActor
class TournamentWorkflowService: ObservableObject {
    
    // MARK: - 發布屬性
    @Published var currentWorkflow: TournamentWorkflow?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - 服務依賴
    private let tournamentService: TournamentService
    private let tradeService: TournamentTradeService
    private let walletService: TournamentWalletService
    private let rankingService: TournamentRankingService
    private let businessService: TournamentBusinessService
    
    // MARK: - 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init(
        tournamentService: TournamentService,
        tradeService: TournamentTradeService,
        walletService: TournamentWalletService,
        rankingService: TournamentRankingService,
        businessService: TournamentBusinessService
    ) {
        self.tournamentService = tournamentService
        self.tradeService = tradeService
        self.walletService = walletService
        self.rankingService = rankingService
        self.businessService = businessService
    }
    
    // MARK: - 1. 建賽事功能
    func createTournament(_ parameters: TournamentCreationParameters) async throws -> Tournament {
        print("🏆 開始創建錦標賽: \(parameters.name)")
        
        isProcessing = true
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // 驗證參數
            guard parameters.isValid else {
                throw TournamentWorkflowError.invalidParameters("錦標賽參數驗證失敗")
            }
            
            // 創建錦標賽記錄（使用新的 schema 對齊模型）
            let tournamentId = UUID()
            let tournament = Tournament(
                id: tournamentId,
                name: parameters.name,
                type: .monthly, // 預設類型，可以從參數中取得
                status: .upcoming,
                startDate: parameters.startDate,
                endDate: parameters.endDate,
                description: parameters.description,
                shortDescription: parameters.description, // 使用同樣的描述
                initialBalance: parameters.entryCapital, // 對應 initial_balance
                entryFee: Double(parameters.feeTokens),   // 對應 entry_fee
                prizePool: 0.0,  // 預設為 0
                maxParticipants: parameters.maxParticipants,
                currentParticipants: 0,
                isFeatured: false,
                createdBy: nil, // 需要從上下文取得
                riskLimitPercentage: 0.2, // 預設 20%
                minHoldingRate: 0.5,      // 預設 50%
                maxSingleStockRate: 0.3,  // 預設 30%
                rules: [], // 暫時為空陣列
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 保存到服務
            try await tournamentService.saveTournament(tournament)
            
            // 初始化錦標賽相關服務
            await initializeTournamentServices(for: tournamentId)
            
            // 創建工作流程
            let workflow = TournamentWorkflow(
                tournamentId: tournamentId,
                state: .created,
                steps: generateWorkflowSteps(for: tournament)
            )
            
            currentWorkflow = workflow
            successMessage = "錦標賽 '\(parameters.name)' 創建成功！"
            
            print("✅ 錦標賽創建成功: \(tournamentId)")
            return tournament
            
        } catch {
            errorMessage = "創建錦標賽失敗: \(error.localizedDescription)"
            print("❌ 錦標賽創建失敗: \(error)")
            throw error
        }
    }
    
    // MARK: - 2. 參賽功能
    func joinTournament(tournamentId: UUID, userId: UUID = UUID()) async throws {
        print("👤 用戶 \(userId) 嘗試加入錦標賽 \(tournamentId)")
        
        isProcessing = true
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // 檢查錦標賽狀態
            guard let tournament = await tournamentService.getTournament(tournamentId) else {
                throw TournamentWorkflowError.tournamentNotFound
            }
            
            guard tournament.status == .upcoming || tournament.status == .enrolling else {
                throw TournamentWorkflowError.cannotJoin("錦標賽已開始或結束，無法加入")
            }
            
            guard tournament.currentParticipants < tournament.maxParticipants else {
                throw TournamentWorkflowError.tournamentFull
            }
            
            // 檢查用戶是否已參加
            let existingMembership = await tournamentService.getMembership(tournamentId: tournamentId, userId: userId)
            if existingMembership != nil {
                throw TournamentWorkflowError.alreadyJoined
            }
            
            // 扣除入場費（使用新的 entryFee 屬性）
            if tournament.entryFee > 0 {
                let success = await walletService.deductTokens(userId: userId, amount: Int(tournament.entryFee))
                if !success {
                    throw TournamentWorkflowError.insufficientFunds("代幣不足，無法支付入場費")
                }
            }
            
            // 創建參與者記錄（使用新的 schema 對齊模型）
            let participant = TournamentParticipantRecord(
                id: UUID(),
                tournamentId: tournamentId,
                userId: userId,
                userName: "User_\(userId.uuidString.prefix(8))", // 暫時使用，實際應從用戶服務取得
                userAvatar: nil,
                currentRank: 999999,
                previousRank: 999999,
                virtualBalance: tournament.initialBalance,
                initialBalance: tournament.initialBalance,
                returnRate: 0.0,
                totalTrades: 0,
                winRate: 0.0,
                maxDrawdown: 0.0,
                sharpeRatio: nil,
                isEliminated: false,
                eliminationReason: nil,
                joinedAt: Date(),
                lastUpdated: Date()
            )
            
            try await tournamentService.saveParticipant(participant)
            
            // 初始化用戶錦標賽投資組合（使用新的 initialBalance）
            try await walletService.initializePortfolio(
                tournamentId: tournamentId,
                userId: userId,
                initialBalance: tournament.initialBalance
            )
            
            // 更新錦標賽參與人數
            await tournamentService.incrementParticipantCount(tournamentId)
            
            successMessage = "成功加入錦標賽！"
            print("✅ 用戶成功加入錦標賽")
            
            print("✅ 用戶成功加入錦標賽")
            
        } catch {
            errorMessage = "加入錦標賽失敗: \(error.localizedDescription)"
            print("❌ 加入錦標賽失敗: \(error)")
            throw error
        }
    }
    
    // MARK: - 3. 強化錦標賽交易功能（新版本）
    func executeTournamentTrade(_ request: TournamentTradeRequest) async throws -> TournamentTradeRecord {
        print("💰 執行錦標賽交易: \(request.symbol) \(request.side.rawValue) \(request.quantity)@\(request.price)")
        
        isProcessing = true
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // 檢查錦標賽和用戶狀態
            try await validateTradingEligibility(tournamentId: request.tournamentId, userId: UUID()) // 需要傳入用戶ID
            
            // 創建新的交易記錄（對應 tournament_trading_records 表）
            let tradeRecord = TournamentTradeRecord(
                id: UUID(),
                userId: UUID(), // 需要從上下文取得
                tournamentId: request.tournamentId,
                symbol: request.symbol,
                stockName: request.symbol, // 暫時使用 symbol，實際應查詢股票名稱
                type: request.side,
                shares: Double(request.quantity),
                price: request.price,
                timestamp: Date(),
                totalAmount: Double(request.quantity) * request.price,
                fee: 0.0, // 預設無手續費
                netAmount: Double(request.quantity) * request.price,
                averageCost: nil,
                realizedGainLoss: nil,
                realizedGainLossPercent: nil,
                notes: nil
            )
            
            // 使用交易服務執行
            try await tradeService.executeTradeRaw(tradeRecord)
            
            print("✅ 錦標賽交易執行成功")
            return tradeRecord
            
        } catch {
            errorMessage = "交易執行失敗: \(error.localizedDescription)"
            print("❌ 交易執行失敗: \(error)")
            throw error
        }
    }
    
    // MARK: - 3. 強化錦標賽交易功能（舊版本兼容）
    func executeTournamentTrade(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        action: TournamentTradeAction,
        quantity: Double,
        price: Double
    ) async throws -> TournamentTrade {
        print("💰 執行錦標賽交易: \(symbol) \(action.rawValue) \(quantity)@\(price)")
        
        isProcessing = true
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // 檢查錦標賽和用戶狀態
            try await validateTradingEligibility(tournamentId: tournamentId, userId: userId)
            
            // 檢查交易規則
            try await validateTradeRules(tournamentId: tournamentId, userId: userId, symbol: symbol, action: action, quantity: quantity)
            
            // 執行交易
            let trade = TournamentTrade(
                id: UUID(),
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: action.rawValue,
                quantity: quantity,
                price: price,
                totalAmount: quantity * price,
                executedAt: Date(),
                status: .executed
            )
            
            // 使用原子操作執行交易
            try await executeAtomicTrade(trade)
            
            // 更新排名（異步）
            Task {
                await updateRankingsAfterTrade(tournamentId: tournamentId)
            }
            
            successMessage = "交易執行成功！"
            print("✅ 錦標賽交易執行成功")
            
            return trade
            
        } catch {
            errorMessage = "交易執行失敗: \(error.localizedDescription)"
            print("❌ 錦標賽交易失敗: \(error)")
            throw error
        }
    }
    
    // MARK: - 4. 實時排行榜更新
    func updateLiveRankings(tournamentId: UUID) async throws -> [TournamentRanking] {
        print("📊 更新錦標賽排行榜: \(tournamentId)")
        
        do {
            // 獲取所有參與者的最新投資組合
            let portfolios = await walletService.getAllPortfolios(tournamentId: tournamentId)
            
            // 計算績效指標
            var rankings: [TournamentRanking] = []
            
            for portfolio in portfolios {
                let performance = await businessService.calculatePerformanceMetrics(
                    tournamentId: tournamentId,
                    userId: portfolio.userId
                )
                
                let ranking = TournamentRanking(
                    userId: portfolio.userId,
                    rank: 0, // 將在排序後設定
                    totalAssets: portfolio.totalValue,
                    totalReturnPercent: performance.totalReturnPercent,
                    totalTrades: performance.totalTrades,
                    winRate: performance.winRate
                )
                
                rankings.append(ranking)
            }
            
            // 根據總報酬率排序
            rankings.sort { $0.totalReturnPercent > $1.totalReturnPercent }
            
            // 設定排名
            for (index, _) in rankings.enumerated() {
                rankings[index].rank = index + 1
            }
            
            // 保存排名
            try await rankingService.saveRankings(rankings)
            
            print("✅ 排行榜更新完成，共 \(rankings.count) 位參與者")
            return rankings
            
        } catch {
            print("❌ 排行榜更新失敗: \(error)")
            throw error
        }
    }
    
    // MARK: - 5. 賽事結算功能
    func settleTournament(tournamentId: UUID) async throws -> [TournamentResult] {
        print("🏁 開始錦標賽結算: \(tournamentId)")
        
        isProcessing = true
        errorMessage = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // 檢查錦標賽狀態
            guard let tournament = await tournamentService.getTournament(tournamentId) else {
                throw TournamentWorkflowError.tournamentNotFound
            }
            
            guard tournament.status == .ongoing || tournament.status == .finished else {
                throw TournamentWorkflowError.invalidState("錦標賽狀態不允許結算")
            }
            
            // 更新錦標賽狀態為結算中（注意：需要在數據庫中支持 settling 狀態）
            // await tournamentService.updateTournamentStatus(tournamentId, status: .settling)
            
            // 鎖定所有交易
            await tradeService.lockTrading(tournamentId: tournamentId)
            
            // 生成最終排行榜
            let finalRankings = try await updateLiveRankings(tournamentId: tournamentId)
            
            // 計算獎勵
            let results = try await calculateTournamentResults(
                tournament: tournament,
                rankings: finalRankings
            )
            
            // 分發獎勵
            for result in results {
                if let reward = result.reward {
                    await distributeTournamentReward(userId: result.userId, reward: reward)
                }
            }
            
            // 更新錦標賽狀態為已結束（使用數據庫的 finished 狀態）
            await tournamentService.updateTournamentStatus(tournamentId, status: .finished)
            
            // 生成結算報告
            await generateSettlementReport(tournament: tournament, results: results)
            
            successMessage = "錦標賽結算完成！"
            print("✅ 錦標賽結算完成")
            
            return results
            
        } catch {
            errorMessage = "錦標賽結算失敗: \(error.localizedDescription)"
            print("❌ 錦標賽結算失敗: \(error)")
            
            // 恢復錦標賽狀態
            if let tournament = await tournamentService.getTournament(tournamentId) {
                await tournamentService.updateTournamentStatus(tournamentId, status: tournament.status)
            }
            
            throw error
        }
    }
    
    // MARK: - 輔助方法
    
    private func initializeTournamentServices(for tournamentId: UUID) async {
        await tradeService.initializeTournament(tournamentId)
        await walletService.initializeTournament(tournamentId)
        await rankingService.initializeTournament(tournamentId)
        await businessService.initializeTournament(tournamentId)
    }
    
    private func generateWorkflowSteps(for tournament: Tournament) -> [WorkflowStep] {
        var steps: [WorkflowStep] = []
        
        steps.append(WorkflowStep(
            id: UUID(),
            name: "錦標賽創建",
            description: "創建錦標賽並初始化服務",
            status: .completed,
            completedAt: Date()
        ))
        
        steps.append(WorkflowStep(
            id: UUID(),
            name: "開放報名",
            description: "開放用戶報名參加錦標賽",
            status: .pending,
            scheduledAt: tournament.startDate.addingTimeInterval(-86400) // 開始前一天
        ))
        
        steps.append(WorkflowStep(
            id: UUID(),
            name: "錦標賽開始",
            description: "錦標賽正式開始，開放交易",
            status: .pending,
            scheduledAt: tournament.startDate
        ))
        
        steps.append(WorkflowStep(
            id: UUID(),
            name: "錦標賽結束",
            description: "錦標賽結束，停止交易",
            status: .pending,
            scheduledAt: tournament.endDate
        ))
        
        steps.append(WorkflowStep(
            id: UUID(),
            name: "結算和獎勵",
            description: "計算最終排名並分發獎勵",
            status: .pending,
            scheduledAt: tournament.endDate.addingTimeInterval(3600) // 結束後一小時
        ))
        
        return steps
    }
    
    private func validateTradingEligibility(tournamentId: UUID, userId: UUID) async throws {
        guard let tournament = await tournamentService.getTournament(tournamentId) else {
            throw TournamentWorkflowError.tournamentNotFound
        }
        
        guard tournament.status.canTrade else {
            throw TournamentWorkflowError.tradingNotAllowed("錦標賽未開始或已結束")
        }
        
        guard let membership = await tournamentService.getMembership(tournamentId: tournamentId, userId: userId) else {
            throw TournamentWorkflowError.notAMember
        }
        
        guard membership.status == .active else {
            throw TournamentWorkflowError.membershipInactive
        }
    }
    
    private func validateTradeRules(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        action: TournamentTradeAction,
        quantity: Double
    ) async throws {
        // 實現交易規則驗證邏輯
        // 例如：檢查持股上限、交易時間、允許的金融商品等
        
        guard let tournament = await tournamentService.getTournament(tournamentId),
              let rules = tournament.rules else {
            return
        }
        
        // 檢查允許的金融商品
        if !rules.allowedInstruments.isEmpty && !rules.allowedInstruments.contains(symbol) {
            throw TournamentWorkflowError.instrumentNotAllowed(symbol)
        }
        
        // 檢查做空限制
        if action == .sell && !rules.allowShortSelling {
            let currentHolding = await walletService.getHolding(tournamentId: tournamentId, userId: userId, symbol: symbol)
            if currentHolding?.shares ?? 0 < quantity {
                throw TournamentWorkflowError.shortSellingNotAllowed
            }
        }
        
        // 檢查交易時間（簡化版本）
        let currentTime = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        
        if hour < 9 || hour > 16 {
            throw TournamentWorkflowError.outsideTradingHours
        }
    }
    
    private func executeAtomicTrade(_ trade: TournamentTrade) async throws {
        // 原子性執行交易
        try await tradeService.executeTrade(trade)
        
        // 更新投資組合
        try await walletService.updatePortfolioAfterTrade(trade)
        
        // 更新持倉
        try await walletService.updateHoldings(trade)
    }
    
    private func updateRankingsAfterTrade(tournamentId: UUID) async {
        do {
            _ = try await updateLiveRankings(tournamentId: tournamentId)
        } catch {
            print("⚠️ 交易後排名更新失敗: \(error)")
        }
    }
    
    private func calculateTournamentResults(
        tournament: Tournament,
        rankings: [TournamentRanking]
    ) async throws -> [TournamentResult] {
        var results: [TournamentResult] = []
        
        for ranking in rankings {
            let reward = calculateReward(for: ranking, tournament: tournament, totalParticipants: rankings.count)
            
            let result = TournamentResult(
                tournamentId: tournament.id,
                userId: ranking.userId,
                rank: ranking.rank,
                totalParticipants: rankings.count,
                finalReturn: ranking.totalReturnPercent,
                maxDrawdown: ranking.maxDrawdown,
                sharpeRatio: ranking.sharpeRatio,
                totalTrades: ranking.totalTrades,
                winRate: ranking.winRate,
                reward: reward
            )
            
            results.append(result)
        }
        
        return results
    }
    
    private func calculateReward(for ranking: TournamentRanking, tournament: Tournament, totalParticipants: Int) -> TournamentReward? {
        // 簡單的獎勵計算邏輯
        let topPercentage = Double(ranking.rank) / Double(totalParticipants)
        
        if topPercentage <= 0.1 { // 前10%
            return TournamentReward(
                type: "tokens",
                amount: 1000,
                description: "前10%獲得1000代幣獎勵"
            )
        } else if topPercentage <= 0.25 { // 前25%
            return TournamentReward(
                type: "tokens",
                amount: 500,
                description: "前25%獲得500代幣獎勵"
            )
        }
        
        return nil
    }
    
    private func distributeTournamentReward(userId: UUID, reward: TournamentReward) async {
        switch reward.type {
        case "tokens":
            await walletService.addTokens(userId: userId, amount: Int(reward.amount))
        default:
            break
        }
    }
    
    private func generateSettlementReport(tournament: Tournament, results: [TournamentResult]) async {
        // 生成結算報告的邏輯
        print("📄 生成錦標賽結算報告...")
        // 可以保存到數據庫或發送通知給參與者
    }
}

// MARK: - 工作流程相關結構

struct TournamentWorkflow: Identifiable, Codable {
    let id = UUID()
    let tournamentId: UUID
    var state: WorkflowState
    var steps: [WorkflowStep]
    let createdAt = Date()
    var updatedAt = Date()
}

enum WorkflowState: String, CaseIterable, Codable {
    case created = "created"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
}

struct WorkflowStep: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    var status: StepStatus
    var scheduledAt: Date?
    var completedAt: Date?
    var error: String?
}

enum StepStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
}

// MARK: - 會員結構

struct TournamentMembership: Identifiable, Codable {
    let id = UUID()
    let tournamentId: UUID
    let userId: UUID
    let joinedAt: Date
    var status: MembershipStatus
    let initialBalance: Double
    var currentBalance: Double = 0
}

enum MembershipStatus: String, CaseIterable, Codable {
    case active = "active"
    case inactive = "inactive"
    case disqualified = "disqualified"
}

// MARK: - 錯誤定義

enum TournamentWorkflowError: LocalizedError {
    case invalidParameters(String)
    case tournamentNotFound
    case cannotJoin(String)
    case tournamentFull
    case alreadyJoined
    case insufficientFunds(String)
    case notAMember
    case membershipInactive
    case tradingNotAllowed(String)
    case invalidState(String)
    case instrumentNotAllowed(String)
    case shortSellingNotAllowed
    case outsideTradingHours
    
    var errorDescription: String? {
        switch self {
        case .invalidParameters(let message):
            return "參數無效: \(message)"
        case .tournamentNotFound:
            return "找不到指定的錦標賽"
        case .cannotJoin(let reason):
            return "無法加入錦標賽: \(reason)"
        case .tournamentFull:
            return "錦標賽已滿員"
        case .alreadyJoined:
            return "已經加入此錦標賽"
        case .insufficientFunds(let message):
            return "資金不足: \(message)"
        case .notAMember:
            return "用戶未參加此錦標賽"
        case .membershipInactive:
            return "會員資格已停用"
        case .tradingNotAllowed(let reason):
            return "不允許交易: \(reason)"
        case .invalidState(let message):
            return "狀態無效: \(message)"
        case .instrumentNotAllowed(let symbol):
            return "不允許的金融商品: \(symbol)"
        case .shortSellingNotAllowed:
            return "此錦標賽不允許做空"
        case .outsideTradingHours:
            return "超出交易時間"
        }
    }
}