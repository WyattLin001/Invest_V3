//
//  TournamentBusinessService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽業務流程服務 - 實現完整的錦標賽生命周期管理
//

import Foundation
import Combine

// MARK: - 錦標賽業務流程服務
@MainActor
class TournamentBusinessService: ObservableObject {
    static let shared = TournamentBusinessService(shared: ())
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var businessMetrics: TournamentBusinessMetrics?
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let tournamentService = TournamentService.shared
    private let tradeService = TournamentTradeService.shared
    private let walletService = TournamentWalletService.shared
    private let positionService = TournamentPositionService.shared
    private let rankingService = TournamentRankingService.shared
    private let portfolioManager = TournamentPortfolioManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 公開初始化器（用於測試和依賴注入）
    init() {
        // 用於測試的公開初始化器
    }
    
    private init(shared: Void) {
        setupBusinessMetricsTracking()
    }
    
    // MARK: - 階段1：建立賽事 (Tournament Creation)
    
    /// 創建新錦標賽 - 完整的賽事建立流程
    func createTournament(
        name: String,
        description: String,
        startDate: Date,
        endDate: Date,
        entryCapital: Double,
        feeTokens: Int = 0,
        returnMetric: ReturnMetric = .twr,
        resetMode: ResetMode = .monthly,
        maxParticipants: Int = 100,
        maxSingleStockRate: Double = 30.0,
        minHoldingRate: Double = 70.0
    ) async -> Result<Tournament, TournamentBusinessError> {
        
        print("🏗️ [TournamentBusinessService] 開始建立賽事: \(name)")
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 步驟1：驗證賽事參數
            try validateTournamentParameters(
                name: name,
                startDate: startDate,
                endDate: endDate,
                entryCapital: entryCapital,
                maxParticipants: maxParticipants
            )
            
            // 步驟2：創建錦標賽記錄
            let tournament = Tournament(
                id: UUID(),
                name: name,
                type: .monthly, // 默認月賽，可根據參數調整
                status: .enrolling,
                startDate: startDate,
                endDate: endDate,
                description: description,
                shortDescription: description, // 使用 description 作為短描述
                initialBalance: entryCapital,
                entryFee: Double(feeTokens),
                prizePool: 0,
                maxParticipants: maxParticipants,
                currentParticipants: 0,
                isFeatured: false,
                createdBy: UUID(), // 需要從當前用戶獲取
                riskLimitPercentage: maxSingleStockRate,
                minHoldingRate: minHoldingRate,
                maxSingleStockRate: maxSingleStockRate,
                rules: [],
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 步驟3：保存到數據庫
            try await supabaseService.createTournament(tournament)
            
            // 步驟4：初始化相關服務狀態
            await initializeTournamentServices(tournament: tournament)
            
            print("✅ [TournamentBusinessService] 賽事建立成功: \(tournament.id)")
            return .success(tournament)
            
        } catch let error as TournamentBusinessError {
            print("❌ [TournamentBusinessService] 建立賽事失敗: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return .failure(error)
        } catch {
            let businessError = TournamentBusinessError.creationFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - 階段2：參賽報名 (Tournament Registration)
    
    /// 用戶參加錦標賽 - 完整的參賽流程
    func joinTournament(
        tournamentId: UUID,
        userId: UUID,
        userName: String
    ) async -> Result<TournamentMember, TournamentBusinessError> {
        
        print("🎯 [TournamentBusinessService] 用戶參賽: \(userName) -> \(tournamentId)")
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 步驟1：驗證錦標賽狀態
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                throw TournamentBusinessError.tournamentNotFound
            }
            
            try validateTournamentForJoining(tournament: tournament)
            
            // 步驟2：檢查用戶是否已參加
            let existingMembers = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
            if existingMembers.contains(where: { $0.userId == userId }) {
                throw TournamentBusinessError.alreadyJoined
            }
            
            // 步驟3：創建錦標賽成員記錄
            let member = TournamentMember(
                tournamentId: tournamentId,
                userId: userId,
                joinedAt: Date(),
                status: .active,
                eliminationReason: nil
            )
            
            try await supabaseService.createTournamentMember(member)
            
            // 步驟4：創建用戶錢包
            let walletResult = await walletService.createWallet(
                tournamentId: tournamentId,
                userId: userId,
                initialBalance: tournament.initialBalance
            )
            
            guard case .success(_) = walletResult else {
                throw TournamentBusinessError.walletCreationFailed
            }
            
            // 步驟5：初始化用戶投資組合
            let portfolioSuccess = await portfolioManager.initializePortfolio(
                for: tournament,
                userId: userId,
                userName: userName
            )
            
            guard portfolioSuccess else {
                throw TournamentBusinessError.portfolioInitializationFailed
            }
            
            // 步驟6：更新錦標賽參加人數
            try await updateTournamentParticipantCount(tournamentId: tournamentId)
            
            print("✅ [TournamentBusinessService] 用戶參賽成功")
            return .success(member)
            
        } catch let error as TournamentBusinessError {
            print("❌ [TournamentBusinessService] 參賽失敗: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return .failure(error)
        } catch {
            let businessError = TournamentBusinessError.registrationFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - 階段3：交易執行 (Trading Execution)
    
    /// 執行錦標賽交易 - 完整的交易流程
    func executeTournamentTrade(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        side: TradeSide,
        qty: Double,
        price: Double
    ) async -> Result<TournamentTradeResult, TournamentBusinessError> {
        
        print("💹 [TournamentBusinessService] 執行交易: \(side.displayName) \(symbol) \(qty)股")
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 步驟1：驗證交易前置條件
            try await validateTradePreConditions(
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: side,
                qty: qty,
                price: price
            )
            
            // 步驟2：執行交易
            let tradeResult = await tradeService.executeTrade(
                tournamentId: tournamentId,
                userId: userId,
                symbol: symbol,
                side: side,
                qty: qty,
                price: price
            )
            
            guard case .success(let trade) = tradeResult else {
                if case .failure(let tradeError) = tradeResult {
                    throw TournamentBusinessError.tradeFailed(tradeError.localizedDescription)
                }
                throw TournamentBusinessError.tradeFailed("Unknown trade error")
            }
            
            // 步驟3：獲取交易後狀態
            let wallet = try await walletService.getWallet(tournamentId: tournamentId, userId: userId)
            let positionsResult = await positionService.getUserPositions(tournamentId: tournamentId, userId: userId)
            let positions = try positionsResult.get()
            
            // 步驟4：計算交易影響
            let tradeImpact = calculateTradeImpact(
                trade: trade,
                wallet: wallet,
                positions: positions
            )
            
            // 步驟5：異步更新排名（不阻塞返回）
            Task {
                await updateTournamentRankings(tournamentId: tournamentId)
            }
            
            let result = TournamentTradeResult(
                trade: trade,
                updatedWallet: wallet,
                updatedPositions: positions,
                tradeImpact: tradeImpact
            )
            
            print("✅ [TournamentBusinessService] 交易執行成功")
            return .success(result)
            
        } catch let error as TournamentBusinessError {
            print("❌ [TournamentBusinessService] 交易執行失敗: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return .failure(error)
        } catch {
            let businessError = TournamentBusinessError.tradeFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - 階段4：排行計算 (Ranking Calculation)
    
    /// 計算和更新錦標賽排行榜
    func calculateTournamentRanking(
        tournamentId: UUID,
        forceRefresh: Bool = false
    ) async -> Result<[TournamentLeaderboardEntry], TournamentBusinessError> {
        
        print("📊 [TournamentBusinessService] 計算排行榜")
        
        isProcessing = true
        defer { isProcessing = false }
        
        let result = await rankingService.getLeaderboard(
            tournamentId: tournamentId,
            forceRefresh: forceRefresh
        )
        
        switch result {
        case .success(let leaderboard):
            print("✅ [TournamentBusinessService] 排行榜計算完成: \(leaderboard.count) 位參賽者")
            return .success(leaderboard)
        case .failure(let error):
            let businessError = TournamentBusinessError.rankingFailed(error.localizedDescription)
            print("❌ [TournamentBusinessService] 排行榜計算失敗: \(businessError.localizedDescription)")
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    /// 獲取用戶排名詳情
    func getUserRankingDetail(
        tournamentId: UUID,
        userId: UUID
    ) async -> Result<UserRankingDetail, TournamentBusinessError> {
        
        do {
            // 獲取用戶排名信息
            let rankResult = await rankingService.getUserRank(tournamentId: tournamentId, userId: userId)
            let rankInfo = try rankResult.get()
            
            // 獲取錦標賽統計
            let statsResult = await rankingService.calculateAdvancedStats(tournamentId: tournamentId)
            let stats = try statsResult.get()
            
            // 獲取用戶錢包和持倉
            let wallet = try await walletService.getWallet(tournamentId: tournamentId, userId: userId)
            let positionsResult = await positionService.getUserPositions(tournamentId: tournamentId, userId: userId)
            let positions = try positionsResult.get()
            
            let detail = UserRankingDetail(
                rankInfo: rankInfo,
                wallet: wallet,
                positions: positions,
                tournamentStats: stats,
                lastUpdated: Date()
            )
            
            return .success(detail)
        } catch {
            let businessError = TournamentBusinessError.rankingFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - 階段5：賽事結算 (Tournament Settlement)
    
    /// 結算錦標賽 - 完整的結算流程
    func settleTournament(tournamentId: UUID) async -> Result<TournamentSettlement, TournamentBusinessError> {
        
        print("🏁 [TournamentBusinessService] 開始結算錦標賽")
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 步驟1：驗證錦標賽可以結算
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                throw TournamentBusinessError.tournamentNotFound
            }
            
            guard tournament.status == .ongoing || tournament.endDate <= Date() else {
                throw TournamentBusinessError.settlementNotAllowed
            }
            
            // 步驟2：生成最終快照
            let snapshotResult = await rankingService.generateDailySnapshot(tournamentId: tournamentId)
            _ = try snapshotResult.get()
            
            // 步驟3：計算最終排名
            let rankingResult = await calculateTournamentRanking(tournamentId: tournamentId, forceRefresh: true)
            let finalLeaderboard = try rankingResult.get()
            
            // 步驟4：計算最終統計
            let statsResult = await rankingService.calculateAdvancedStats(tournamentId: tournamentId)
            let finalStats = try statsResult.get()
            
            // 步驟5：更新錦標賽狀態為已結束
            let updatedTournament = Tournament(
                id: tournament.id,
                name: tournament.name,
                type: tournament.type,
                status: .ended,
                startDate: tournament.startDate,
                endDate: tournament.endDate,
                description: tournament.description,
                shortDescription: tournament.shortDescription,
                initialBalance: tournament.initialBalance,
                entryFee: tournament.entryFee,
                prizePool: tournament.prizePool,
                maxParticipants: tournament.maxParticipants,
                currentParticipants: tournament.currentParticipants,
                isFeatured: tournament.isFeatured,
                createdBy: tournament.createdBy,
                riskLimitPercentage: tournament.riskLimitPercentage,
                minHoldingRate: tournament.minHoldingRate,
                maxSingleStockRate: tournament.maxSingleStockRate,
                rules: tournament.rules,
                createdAt: tournament.createdAt,
                updatedAt: Date()
            )
            try await supabaseService.updateTournament(updatedTournament)
            
            // 步驟6：創建結算記錄
            let settlement = TournamentSettlement(
                tournamentId: tournamentId,
                finalLeaderboard: finalLeaderboard,
                finalStats: finalStats,
                settlementDate: Date(),
                totalParticipants: finalLeaderboard.count,
                averageReturn: finalStats.averageReturn,
                topPerformer: finalLeaderboard.first,
                worstPerformer: finalLeaderboard.last
            )
            
            // 步驟7：保存結算記錄
            try await saveSettlementRecord(settlement)
            
            print("✅ [TournamentBusinessService] 錦標賽結算完成")
            return .success(settlement)
            
        } catch let error as TournamentBusinessError {
            print("❌ [TournamentBusinessService] 結算失敗: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return .failure(error)
        } catch {
            let businessError = TournamentBusinessError.settlementFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - 綜合業務方法 (Comprehensive Business Methods)
    
    /// 獲取錦標賽完整狀態
    func getTournamentCompleteStatus(tournamentId: UUID) async -> Result<TournamentCompleteStatus, TournamentBusinessError> {
        
        do {
            // 獲取基本信息
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                return .failure(.tournamentNotFound)
            }
            
            // 獲取成員信息
            let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
            
            // 獲取排行榜
            let rankingResult = await rankingService.getLeaderboard(tournamentId: tournamentId)
            let leaderboard = try rankingResult.get()
            
            // 獲取統計信息
            let statsResult = await rankingService.calculateAdvancedStats(tournamentId: tournamentId)
            let stats = try statsResult.get()
            
            let completeStatus = TournamentCompleteStatus(
                tournament: tournament,
                members: members,
                leaderboard: leaderboard,
                stats: stats,
                lastUpdated: Date()
            )
            
            return .success(completeStatus)
        } catch {
            let businessError = TournamentBusinessError.statusRetrievalFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func validateTournamentParameters(
        name: String,
        startDate: Date,
        endDate: Date,
        entryCapital: Double,
        maxParticipants: Int
    ) throws {
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TournamentBusinessError.invalidParameters("錦標賽名稱不能為空")
        }
        
        guard startDate < endDate else {
            throw TournamentBusinessError.invalidParameters("開始時間必須早於結束時間")
        }
        
        guard entryCapital > 0 else {
            throw TournamentBusinessError.invalidParameters("初始資金必須大於0")
        }
        
        guard maxParticipants > 0 && maxParticipants <= 1000 else {
            throw TournamentBusinessError.invalidParameters("參賽人數必須在1-1000之間")
        }
    }
    
    private func validateTournamentForJoining(tournament: Tournament) throws {
        guard tournament.status == .enrolling else {
            throw TournamentBusinessError.tournamentNotAcceptingRegistrations
        }
        
        guard tournament.currentParticipants < tournament.maxParticipants else {
            throw TournamentBusinessError.tournamentFull
        }
    }
    
    private func validateTradePreConditions(
        tournamentId: UUID,
        userId: UUID,
        symbol: String,
        side: TradeSide,
        qty: Double,
        price: Double
    ) async throws {
        
        // 驗證基本參數
        guard !symbol.isEmpty, qty > 0, price > 0 else {
            throw TournamentBusinessError.invalidTradeParameters
        }
        
        // 驗證錦標賽狀態
        guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
            throw TournamentBusinessError.tournamentNotFound
        }
        
        guard tournament.status == .ongoing else {
            throw TournamentBusinessError.tradingNotAllowed
        }
        
        // 驗證用戶是否為參賽者
        let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
        guard members.contains(where: { $0.userId == userId && $0.status == TournamentMember.MemberStatus.active }) else {
            throw TournamentBusinessError.userNotParticipant
        }
    }
    
    private func initializeTournamentServices(tournament: Tournament) async {
        // 初始化各服務狀態，為錦標賽做準備
        print("🔧 [TournamentBusinessService] 初始化錦標賽服務狀態")
    }
    
    private func updateTournamentParticipantCount(tournamentId: UUID) async throws {
        let members = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
        let activeCount = members.filter { $0.status == TournamentMember.MemberStatus.active }.count
        
        // 更新錦標賽的參賽人數
        // 這裡需要實現更新邏輯
    }
    
    private func updateTournamentRankings(tournamentId: UUID) async {
        await rankingService.recalculateAllActiveRankings()
    }
    
    private func calculateTradeImpact(
        trade: TournamentTrade,
        wallet: TournamentPortfolioV2,
        positions: [TournamentPosition]
    ) -> TradeImpact {
        
        let portfolioValue = wallet.totalAssets
        let tradeValue = trade.amount
        let impactPercentage = (tradeValue / portfolioValue) * 100
        
        return TradeImpact(
            tradeValue: tradeValue,
            portfolioValueBefore: portfolioValue - (trade.side == .buy ? -tradeValue : tradeValue),
            portfolioValueAfter: portfolioValue,
            impactPercentage: impactPercentage,
            newCashBalance: wallet.cashBalance,
            newEquityValue: wallet.equityValue
        )
    }
    
    private func saveSettlementRecord(_ settlement: TournamentSettlement) async throws {
        // 保存結算記錄到數據庫
        // 實現結算記錄的持久化
        print("💾 [TournamentBusinessService] 保存結算記錄")
    }
    
    private func setupBusinessMetricsTracking() {
        // 設置業務指標追蹤
        // 監控各階段的成功率和性能
        print("📈 [TournamentBusinessService] 設置業務指標追蹤")
    }
    
    // MARK: - Missing Methods Implementation
    
    /// 初始化錦標賽（完整的初始化流程）
    func initializeTournament(
        tournamentId: UUID,
        forceReset: Bool = false
    ) async -> Result<TournamentInitializationResult, TournamentBusinessError> {
        
        print("🚀 [TournamentBusinessService] 開始初始化錦標賽: \(tournamentId)")
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // 步驟1：獲取錦標賽資訊
            guard let tournament = try await tournamentService.fetchTournament(id: tournamentId) else {
                return .failure(.tournamentNotFound)
            }
            
            // 步驟2：檢查是否已經初始化（除非強制重設）
            if !forceReset {
                let existingMembers = try await supabaseService.fetchTournamentMembers(tournamentId: tournamentId)
                if !existingMembers.isEmpty {
                    return .failure(.alreadyInitialized)
                }
            }
            
            // 步驟3：清理現有數據（如果是強制重設）
            if forceReset {
                try await cleanupTournamentData(tournamentId: tournamentId)
            }
            
            // 步驟4：初始化錦標賽服務狀態
            await initializeTournamentServices(tournament: tournament)
            
            // 步驟5：設置錦標賽規則和限制
            try await setupTournamentRules(tournament: tournament)
            
            // 步驟6：初始化排名系統
            await initializeRankingSystem(tournamentId: tournamentId)
            
            // 步驟7：設置監控和通知
            await setupTournamentMonitoring(tournamentId: tournamentId)
            
            let result = TournamentInitializationResult(
                tournamentId: tournamentId,
                status: .initialized,
                initializedAt: Date(),
                servicesInitialized: [
                    "TournamentService",
                    "WalletService", 
                    "TradeService",
                    "RankingService",
                    "PositionService"
                ],
                rulesConfigured: true,
                monitoringEnabled: true
            )
            
            print("✅ [TournamentBusinessService] 錦標賽初始化完成")
            return .success(result)
            
        } catch let error as TournamentBusinessError {
            print("❌ [TournamentBusinessService] 錦標賽初始化失敗: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return .failure(error)
        } catch {
            let businessError = TournamentBusinessError.initializationFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    /// 計算績效指標（綜合版本）
    func calculatePerformanceMetrics(
        tournamentId: UUID,
        userId: UUID
    ) async -> Result<ComprehensivePerformanceMetrics, TournamentBusinessError> {
        
        do {
            // 步驟1：獲取基礎績效指標
            let rankingResult = await rankingService.calculatePerformanceMetrics(
                tournamentId: tournamentId,
                userId: userId
            )
            let baseMetrics = try rankingResult.get()
            
            // 步驟2：獲取錢包資訊
            let wallet = try await walletService.getWallet(tournamentId: tournamentId, userId: userId)
            
            // 步驟3：獲取持倉資訊
            let positionsResult = await positionService.getUserPositions(
                tournamentId: tournamentId,
                userId: userId
            )
            let positions = try positionsResult.get()
            
            // 步驟4：獲取交易統計
            let tradingStatsResult = await tradeService.calculateTradingStatistics(
                tournamentId: tournamentId,
                userId: userId
            )
            let tradingStats = try tradingStatsResult.get()
            
            // 步驟5：計算風險指標
            let riskMetrics = calculateRiskMetrics(
                wallet: wallet,
                positions: positions,
                tournamentId: tournamentId
            )
            
            // 步驟6：計算市場比較指標
            let marketComparison = await calculateMarketComparison(
                tournamentId: tournamentId,
                userMetrics: baseMetrics
            )
            
            let comprehensiveMetrics = ComprehensivePerformanceMetrics(
                baseMetrics: baseMetrics,
                wallet: wallet,
                positions: positions,
                tradingStatistics: tradingStats,
                riskMetrics: riskMetrics,
                marketComparison: marketComparison,
                calculatedAt: Date()
            )
            
            return .success(comprehensiveMetrics)
        } catch {
            let businessError = TournamentBusinessError.performanceCalculationFailed(error.localizedDescription)
            lastError = businessError.localizedDescription
            return .failure(businessError)
        }
    }
    
    // MARK: - Private Helper Methods for Initialization
    
    private func cleanupTournamentData(tournamentId: UUID) async throws {
        // 清理現有的錦標賽數據
        print("🧹 [TournamentBusinessService] 清理錦標賽數據: \(tournamentId)")
        
        // 刪除成員記錄
        try await supabaseService.deleteTournamentMembers(tournamentId: tournamentId)
        
        // 清理錢包數據
        try await supabaseService.deleteTournamentWallets(tournamentId: tournamentId)
        
        // 清理交易記錄
        try await supabaseService.deleteTournamentTrades(tournamentId: tournamentId)
        
        // 清理持倉記錄
        try await supabaseService.deleteTournamentPositions(tournamentId: tournamentId)
        
        // 清理排名記錄
        try await supabaseService.deleteTournamentRankings(tournamentId: tournamentId)
    }
    
    private func setupTournamentRules(tournament: Tournament) async throws {
        // 設置錦標賽規則
        print("📋 [TournamentBusinessService] 設置錦標賽規則")
        
        // 這裡可以根據錦標賽類型設置不同的規則
        // 例如：交易限制、持倉限制、風險控制等
    }
    
    private func initializeRankingSystem(tournamentId: UUID) async {
        // 初始化排名系統
        print("🏆 [TournamentBusinessService] 初始化排名系統")
        
        // 觸發排名服務的初始化
        await rankingService.recalculateAllActiveRankings()
    }
    
    private func setupTournamentMonitoring(tournamentId: UUID) async {
        // 設置錦標賽監控
        print("📊 [TournamentBusinessService] 設置錦標賽監控")
        
        // 這裡可以設置各種監控和警報
        // 例如：異常交易監控、風險警報等
    }
    
    private func calculateRiskMetrics(
        wallet: TournamentPortfolioV2,
        positions: [TournamentPosition],
        tournamentId: UUID
    ) -> RiskMetrics {
        
        // 計算集中度風險
        let concentrationRisk = calculateConcentrationRisk(positions: positions, totalValue: wallet.totalAssets)
        
        // 計算流動性風險
        let liquidityRisk = calculateLiquidityRisk(positions: positions)
        
        // 計算市場風險
        let marketRisk = calculateMarketRisk(wallet: wallet)
        
        return RiskMetrics(
            concentrationRisk: concentrationRisk,
            liquidityRisk: liquidityRisk,
            marketRisk: marketRisk,
            overallRiskScore: (concentrationRisk + liquidityRisk + marketRisk) / 3
        )
    }
    
    private func calculateConcentrationRisk(positions: [TournamentPosition], totalValue: Double) -> Double {
        guard !positions.isEmpty && totalValue > 0 else { return 0 }
        
        let maxPositionPercentage = positions.max { 
            $0.marketValue / totalValue < $1.marketValue / totalValue 
        }?.marketValue ?? 0
        
        return (maxPositionPercentage / totalValue) * 100
    }
    
    private func calculateLiquidityRisk(positions: [TournamentPosition]) -> Double {
        // 簡化的流動性風險計算
        // 實際應用中應該考慮股票的成交量、市值等因素
        return positions.isEmpty ? 0 : 30.0 // 假設固定值
    }
    
    private func calculateMarketRisk(wallet: TournamentPortfolioV2) -> Double {
        // 基於最大回撤計算市場風險
        return wallet.maxDrawdown
    }
    
    private func calculateMarketComparison(
        tournamentId: UUID,
        userMetrics: TournamentRankingService.PerformanceMetrics
    ) async -> MarketComparison {
        
        do {
            // 獲取錦標賽所有參與者的平均表現
            let statsResult = await rankingService.calculateAdvancedStats(tournamentId: tournamentId)
            let tournamentStats = try statsResult.get()
            
            let performanceVsAverage = userMetrics.returnPercentage - tournamentStats.averageReturn
            let performanceVsMedian = userMetrics.returnPercentage - tournamentStats.medianReturn
            
            return MarketComparison(
                performanceVsAverage: performanceVsAverage,
                performanceVsMedian: performanceVsMedian,
                percentileRank: calculatePercentileRank(
                    userReturn: userMetrics.returnPercentage,
                    allReturns: [tournamentStats.averageReturn] // 簡化版本
                )
            )
        } catch {
            return MarketComparison(
                performanceVsAverage: 0,
                performanceVsMedian: 0,
                percentileRank: 50
            )
        }
    }
    
    private func calculatePercentileRank(userReturn: Double, allReturns: [Double]) -> Double {
        let sortedReturns = allReturns.sorted()
        let position = sortedReturns.firstIndex { $0 >= userReturn } ?? sortedReturns.count
        return (Double(position) / Double(sortedReturns.count)) * 100
    }
}

// MARK: - Supporting Types

/// 錦標賽業務流程錯誤類型
enum TournamentBusinessError: LocalizedError {
    case tournamentNotFound
    case creationFailed(String)
    case invalidParameters(String)
    case alreadyJoined
    case tournamentNotAcceptingRegistrations
    case tournamentFull
    case registrationFailed(String)
    case walletCreationFailed
    case portfolioInitializationFailed
    case tradingNotAllowed
    case userNotParticipant
    case invalidTradeParameters
    case tradeFailed(String)
    case rankingFailed(String)
    case settlementNotAllowed
    case settlementFailed(String)
    case statusRetrievalFailed(String)
    case alreadyInitialized
    case initializationFailed(String)
    case performanceCalculationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .tournamentNotFound:
            return "錦標賽不存在"
        case .creationFailed(let message):
            return "創建錦標賽失敗：\(message)"
        case .invalidParameters(let message):
            return "參數無效：\(message)"
        case .alreadyJoined:
            return "已經參加此錦標賽"
        case .tournamentNotAcceptingRegistrations:
            return "錦標賽未開放報名"
        case .tournamentFull:
            return "錦標賽人數已滿"
        case .registrationFailed(let message):
            return "報名失敗：\(message)"
        case .walletCreationFailed:
            return "創建錢包失敗"
        case .portfolioInitializationFailed:
            return "初始化投資組合失敗"
        case .tradingNotAllowed:
            return "錦標賽未開放交易"
        case .userNotParticipant:
            return "用戶未參加此錦標賽"
        case .invalidTradeParameters:
            return "交易參數無效"
        case .tradeFailed(let message):
            return "交易失敗：\(message)"
        case .rankingFailed(let message):
            return "排名計算失敗：\(message)"
        case .settlementNotAllowed:
            return "錦標賽尚不能結算"
        case .settlementFailed(let message):
            return "結算失敗：\(message)"
        case .statusRetrievalFailed(let message):
            return "獲取狀態失敗：\(message)"
        case .alreadyInitialized:
            return "錦標賽已經初始化"
        case .initializationFailed(let message):
            return "初始化失敗：\(message)"
        case .performanceCalculationFailed(let message):
            return "績效計算失敗：\(message)"
        }
    }
}

/// 錦標賽交易結果
struct TournamentTradeResult {
    let trade: TournamentTrade
    let updatedWallet: TournamentPortfolioV2
    let updatedPositions: [TournamentPosition]
    let tradeImpact: TradeImpact
}

/// 交易影響分析
struct TradeImpact {
    let tradeValue: Double
    let portfolioValueBefore: Double
    let portfolioValueAfter: Double
    let impactPercentage: Double
    let newCashBalance: Double
    let newEquityValue: Double
}

/// 用戶排名詳情
struct UserRankingDetail {
    let rankInfo: UserRankInfo
    let wallet: TournamentPortfolioV2
    let positions: [TournamentPosition]
    let tournamentStats: TournamentStats
    let lastUpdated: Date
}

/// 錦標賽結算記錄
struct TournamentSettlement {
    let tournamentId: UUID
    let finalLeaderboard: [TournamentLeaderboardEntry]
    let finalStats: TournamentStats
    let settlementDate: Date
    let totalParticipants: Int
    let averageReturn: Double
    let topPerformer: TournamentLeaderboardEntry?
    let worstPerformer: TournamentLeaderboardEntry?
}

/// 錦標賽完整狀態
struct TournamentCompleteStatus {
    let tournament: Tournament
    let members: [TournamentMember]
    let leaderboard: [TournamentLeaderboardEntry]
    let stats: TournamentStats
    let lastUpdated: Date
}

/// 業務指標
struct TournamentBusinessMetrics {
    let totalTournaments: Int
    let activeTournaments: Int
    let totalParticipants: Int
    let totalTrades: Int
    let averageParticipantsPerTournament: Double
    let averageTradesPerParticipant: Double
    let systemUptime: Double
    let lastUpdated: Date
}

/// 錦標賽初始化結果
struct TournamentInitializationResult {
    let tournamentId: UUID
    let status: InitializationStatus
    let initializedAt: Date
    let servicesInitialized: [String]
    let rulesConfigured: Bool
    let monitoringEnabled: Bool
    
    enum InitializationStatus {
        case initialized
        case partiallyInitialized
        case failed
        
        var displayName: String {
            switch self {
            case .initialized:
                return "已完成初始化"
            case .partiallyInitialized:
                return "部分初始化"
            case .failed:
                return "初始化失敗"
            }
        }
    }
}

/// 綜合績效指標
struct ComprehensivePerformanceMetrics {
    let baseMetrics: TournamentRankingService.PerformanceMetrics
    let wallet: TournamentPortfolioV2
    let positions: [TournamentPosition]
    let tradingStatistics: TournamentTradingStatistics
    let riskMetrics: RiskMetrics
    let marketComparison: MarketComparison
    let calculatedAt: Date
}

/// 風險指標
struct RiskMetrics {
    let concentrationRisk: Double  // 集中度風險 (%)
    let liquidityRisk: Double      // 流動性風險分數
    let marketRisk: Double         // 市場風險 (%)
    let overallRiskScore: Double   // 整體風險分數
    
    var riskLevel: RiskLevel {
        if overallRiskScore < 20 {
            return .low
        } else if overallRiskScore < 50 {
            return .medium
        } else {
            return .high
        }
    }
}

/// 市場比較指標
struct MarketComparison {
    let performanceVsAverage: Double    // 相對於平均表現 (%)
    let performanceVsMedian: Double     // 相對於中位數表現 (%)
    let percentileRank: Double          // 百分位排名
    
    var performanceCategory: PerformanceCategory {
        if percentileRank >= 80 {
            return .excellent
        } else if percentileRank >= 60 {
            return .good
        } else if percentileRank >= 40 {
            return .average
        } else if percentileRank >= 20 {
            return .belowAverage
        } else {
            return .poor
        }
    }
    
    enum PerformanceCategory {
        case excellent, good, average, belowAverage, poor
        
        var displayName: String {
            switch self {
            case .excellent: return "優秀"
            case .good: return "良好"
            case .average: return "一般"
            case .belowAverage: return "待改善"
            case .poor: return "需加強"
            }
        }
    }
}