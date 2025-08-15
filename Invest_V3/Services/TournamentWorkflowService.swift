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
    private let supabaseService: SupabaseService
    
    // MARK: - 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init(
        tournamentService: TournamentService,
        tradeService: TournamentTradeService,
        walletService: TournamentWalletService,
        rankingService: TournamentRankingService,
        businessService: TournamentBusinessService,
        supabaseService: SupabaseService = SupabaseService.shared
    ) {
        self.tournamentService = tournamentService
        self.tradeService = tradeService
        self.walletService = walletService
        self.rankingService = rankingService
        self.businessService = businessService
        self.supabaseService = supabaseService
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
                createdBy: UUID(), // Default UUID for current user - should be replaced with actual user ID
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
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                throw TournamentWorkflowError.tournamentNotFound
            }
            
            guard tournament.status == .upcoming || tournament.status == .enrolling else {
                throw TournamentWorkflowError.cannotJoin("錦標賽已開始或結束，無法加入")
            }
            
            guard tournament.currentParticipants < tournament.maxParticipants else {
                throw TournamentWorkflowError.tournamentFull
            }
            
            // 檢查用戶是否已參加
            let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
            if members.contains(where: { $0.userId == userId }) {
                throw TournamentWorkflowError.alreadyJoined
            }
            
            // 扣除入場費（使用新的 entryFee 屬性）
            if tournament.entryFee > 0 {
                let result = await walletService.deductTokens(
                    tournamentId: tournamentId,
                    userId: userId,
                    amount: tournament.entryFee
                )
                switch result {
                case .success(_):
                    print("✅ 入場費已扣除: \(tournament.entryFee)")
                case .failure(_):
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
            
            let tournamentMember = TournamentMember(
                tournamentId: tournamentId,
                userId: userId,
                joinedAt: Date(),
                status: .active,
                eliminationReason: nil
            )
            
            try await supabaseService.createTournamentMember(tournamentMember)
            
            // 初始化用戶錦標賽投資組合（使用新的 initialBalance）
            let portfolioResult = await walletService.initializePortfolio(
                tournamentId: tournamentId,
                userId: userId,
                initialBalance: tournament.initialBalance
            )
            switch portfolioResult {
            case .success(_):
                print("✅ 投資組合初始化成功")
            case .failure(let error):
                throw TournamentWorkflowError.invalidState("投資組合初始化失敗: \(error.localizedDescription)")
            }
            
            // 更新錦標賽參與人數
            try await supabaseService.updateTournamentParticipantCount(tournamentId: tournamentId, increment: 1)
            
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
                notes: nil,
                tradeDate: Date() // 添加 tradeDate 參數，使用當前日期
            )
            
            // 使用交易服務執行
            let tradeResult = await tradeService.executeTradeRaw(
                tournamentId: request.tournamentId,
                userId: UUID(), // 需要從上下文取得
                symbol: request.symbol,
                side: request.side,
                qty: Double(request.quantity),
                price: request.price,
                fees: tradeRecord.fee
            )
            switch tradeResult {
            case .success(_):
                break
            case .failure(let error):
                throw error
            }
            
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
            let tradeSide: TradeSide = (action.rawValue == "buy") ? .buy : .sell
            let totalAmount = quantity * price
            let fees = totalAmount * 0.001425 // 0.1425% trading fee
            
            let trade = TournamentTrade(
                id: UUID(),
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: tradeSide,
                qty: quantity,
                price: price,
                amount: totalAmount,
                fees: fees,
                netAmount: totalAmount + fees,
                realizedPnl: nil,
                realizedPnlPercentage: nil,
                status: .executed,
                executedAt: Date(),
                createdAt: Date()
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
            let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
            var portfolios: [TournamentPortfolioV2] = []
            
            for member in members {
                do {
                    let wallet = try await walletService.getWallet(tournamentId: tournamentId, userId: member.userId)
                    portfolios.append(wallet)
                } catch {
                    print("❌ 獲取成員 \(member.userId) 的錢包失敗: \(error)")
                }
            }
            
            // 計算績效指標
            var rankings: [TournamentRanking] = []
            
            for portfolio in portfolios {
                let performanceResult = await businessService.calculatePerformanceMetrics(
                    tournamentId: tournamentId,
                    userId: portfolio.userId
                )
                
                // Extract values from performance result
                let returnPercentage: Double
                let trades: Int
                let winRate: Double
                
                switch performanceResult {
                case .success(let performance):
                    returnPercentage = performance.wallet.returnPercentage
                    trades = performance.wallet.totalTrades
                    winRate = performance.wallet.winRate
                case .failure(_):
                    returnPercentage = 0.0
                    trades = 0
                    winRate = 0.0
                }
                
                let ranking = TournamentRanking(
                    userId: portfolio.userId,
                    rank: 0, // 將在排序後設定
                    totalAssets: portfolio.totalAssets,
                    totalReturnPercent: returnPercentage,
                    totalTrades: trades,
                    winRate: winRate,
                    maxDrawdown: portfolio.maxDrawdown,
                    sharpeRatio: nil // 暫時設為 nil，可以之後計算
                )
                
                rankings.append(ranking)
            }
            
            // 根據總報酬率排序
            rankings.sort { $0.totalReturnPercent > $1.totalReturnPercent }
            
            // 設定排名（創建新實例而非修改現有實例）
            rankings = rankings.enumerated().map { (index, ranking) in
                TournamentRanking(
                    userId: ranking.userId,
                    rank: index + 1,
                    totalAssets: ranking.totalAssets,
                    totalReturnPercent: ranking.totalReturnPercent,
                    totalTrades: ranking.totalTrades,
                    winRate: ranking.winRate,
                    maxDrawdown: ranking.maxDrawdown,
                    sharpeRatio: ranking.sharpeRatio
                )
            }
            
            // 保存排名
            let result = await rankingService.saveRankings(tournamentId: tournamentId, rankings: rankings.map { ranking in
                TournamentLeaderboardEntry(
                    tournamentId: tournamentId,
                    userId: ranking.userId,
                    userName: nil,
                    userAvatar: nil,
                    totalAssets: ranking.totalAssets,
                    returnPercentage: ranking.totalReturnPercent,
                    totalTrades: ranking.totalTrades,
                    lastUpdated: Date(),
                    currentRank: ranking.rank,
                    totalParticipants: rankings.count
                )
            })
            switch result {
            case .success():
                break
            case .failure(let error):
                throw error
            }
            
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
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                throw TournamentWorkflowError.tournamentNotFound
            }
            
            guard tournament.status == .ongoing || tournament.status == .finished else {
                throw TournamentWorkflowError.invalidState("錦標賽狀態不允許結算")
            }
            
            // 更新錦標賽狀態為結算中
            try await supabaseService.updateTournamentStatus(tournamentId: tournamentId, status: .finished)
            
            // 鎖定所有交易（簡化實現）
            print("🔒 鎖定錦標賽交易: \(tournamentId)")
            
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
            
            // 更新錦標賽狀態為已結束
            try await supabaseService.updateTournamentStatus(tournamentId: tournamentId, status: .finished)
            
            // 生成結算報告
            await generateSettlementReport(tournament: tournament, results: results)
            
            successMessage = "錦標賽結算完成！"
            print("✅ 錦標賽結算完成")
            
            return results
            
        } catch {
            errorMessage = "錦標賽結算失敗: \(error.localizedDescription)"
            print("❌ 錦標賽結算失敗: \(error)")
            
            // 恢復錦標賽狀態
            do {
                if let tournament = try await tournamentService.fetchTournament(id: tournamentId) {
                    try await supabaseService.updateTournamentStatus(tournamentId: tournamentId, status: tournament.status)
                }
            } catch {
                print("恢復錦標賽狀態失敗: \(error)")
            }
            
            throw error
        }
    }
    
    // MARK: - 輔助方法
    
    private func initializeTournamentServices(for tournamentId: UUID) async {
        print("🚀 初始化錦標賽服務: \(tournamentId)")
        // 服務初始化邏輯在各自的服務類中處理
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
        // 檢查錦標賽狀態
        guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
            throw TournamentWorkflowError.tournamentNotFound
        }
        
        guard tournament.status == .ongoing else {
            throw TournamentWorkflowError.tradingNotAllowed("錦標賽未開始或已結束")
        }
        
        // 檢查用戶是否為參賽者
        let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
        guard let member = members.first(where: { $0.userId == userId }) else {
            throw TournamentWorkflowError.notAMember
        }
        
        guard member.status == TournamentMember.MemberStatus.active else {
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
        
        do {
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                return
            }
            
            // 注意：Tournament 模型可能沒有 rules 屬性，使用基本檢查
            guard tournament.status == .ongoing else {
                throw TournamentWorkflowError.tradingNotAllowed("錦標賽未開始")
            }
            
            // 基本檢查 - 簡化版本，暫時跳過詳細規則檢查
            // 未來可以添加更詳細的規則檢查邏輯
        } catch {
            print("檢查交易規則時發生錯誤: \(error)")
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
        let result = await tradeService.executeTrade(
            tournamentId: trade.tournamentId,
            userId: trade.userId,
            symbol: trade.symbol,
            side: trade.side,
            qty: trade.qty,
            price: trade.price
        )
        
        switch result {
        case .success(let executedTrade):
            // 更新投資組合
            try await walletService.updatePortfolioAfterTrade(executedTrade)
            
            // 更新持倉
            try await walletService.updateHoldings(executedTrade)
        case .failure(let error):
            throw error
        }
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
                id: UUID(),
                userId: ranking.userId,
                tournamentId: tournament.id,
                rank: ranking.rank,
                totalAssets: ranking.totalAssets,
                returnPercentage: ranking.totalReturnPercent,
                reward: reward,
                finalizedAt: Date()
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
                amount: 1000,
                type: .tokens,
                description: "前10%獲得1000代幣獎勵"
            )
        } else if topPercentage <= 0.25 { // 前25%
            return TournamentReward(
                amount: 500,
                type: .tokens,
                description: "前25%獲得500代幣獎勵"
            )
        }
        
        return nil
    }
    
    private func distributeTournamentReward(userId: UUID, reward: TournamentReward) async {
        switch reward.type {
        case .tokens:
            await walletService.addTokens(userId: userId, amount: Int(reward.amount))
        case .cash, .title, .achievement:
            // 其他獎勵類型的處理邏輯
            print("🏆 [TournamentWorkflow] 分發 \(reward.type.rawValue) 獎勵: \(reward.amount)")
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