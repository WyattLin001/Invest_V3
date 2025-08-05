//
//  TournamentPortfolioIntegrationTests.swift
//  Invest_V3Tests
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽投資組合隔離和多錦標賽並行功能測試
//

import XCTest
@testable import Invest_V3

@MainActor
class TournamentPortfolioIntegrationTests: XCTestCase {
    
    var portfolioManager: TournamentPortfolioManager!
    var tournamentService: TournamentService!
    var tournamentStateManager: TournamentStateManager!
    
    // 測試用錦標賽
    var tournament1: Tournament!
    var tournament2: Tournament!
    var tournament3: Tournament!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化服務
        portfolioManager = TournamentPortfolioManager.shared
        tournamentService = TournamentService.shared
        tournamentStateManager = TournamentStateManager()
        
        // 創建測試錦標賽
        await createTestTournaments()
    }
    
    override func tearDown() async throws {
        // 清理所有錦標賽投資組合
        await portfolioManager.clearAllPortfolios()
        try await super.tearDown()
    }
    
    // MARK: - 錦標賽投資組合隔離測試
    
    /// 測試多個錦標賽投資組合完全隔離
    func testMultipleTournamentPortfolioIsolation() async throws {
        let userId = UUID()
        
        // 1. 創建三個不同錦標賽的投資組合
        let portfolio1 = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament1.initialBalance
        )
        
        let portfolio2 = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament2.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament2.initialBalance
        )
        
        let portfolio3 = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament3.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament3.initialBalance
        )
        
        XCTAssertNotNil(portfolio1, "錦標賽1投資組合應該成功創建")
        XCTAssertNotNil(portfolio2, "錦標賽2投資組合應該成功創建")
        XCTAssertNotNil(portfolio3, "錦標賽3投資組合應該成功創建")
        
        // 2. 驗證每個投資組合都有正確的初始資金
        XCTAssertEqual(portfolio1!.initialBalance, 1_000_000, "錦標賽1初始資金應該是100萬")
        XCTAssertEqual(portfolio2!.initialBalance, 2_000_000, "錦標賽2初始資金應該是200萬")
        XCTAssertEqual(portfolio3!.initialBalance, 500_000, "錦標賽3初始資金應該是50萬")
        
        // 3. 驗證投資組合完全獨立
        XCTAssertNotEqual(portfolio1!.id, portfolio2!.id, "投資組合ID應該不同")
        XCTAssertNotEqual(portfolio2!.id, portfolio3!.id, "投資組合ID應該不同")
        XCTAssertNotEqual(portfolio1!.id, portfolio3!.id, "投資組合ID應該不同")
    }
    
    /// 測試不同錦標賽中的交易完全隔離
    func testTournamentTradingIsolation() async throws {
        let userId = UUID()
        
        // 創建兩個錦標賽投資組合
        guard let portfolio1 = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament1.initialBalance
        ) else {
            XCTFail("無法創建錦標賽1投資組合")
            return
        }
        
        guard let portfolio2 = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament2.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament2.initialBalance
        ) else {
            XCTFail("無法創建錦標賽2投資組合")
            return
        }
        
        // 在錦標賽1中進行交易
        let trade1Success = await portfolioManager.executeTrade(
            tournamentId: tournament1.id,
            symbol: "2330",
            stockName: "台積電",
            action: .buy,
            shares: 1000,
            price: 580.0
        )
        
        // 在錦標賽2中進行不同的交易
        let trade2Success = await portfolioManager.executeTrade(
            tournamentId: tournament2.id,
            symbol: "0050",
            stockName: "元大台灣50",
            action: .buy,
            shares: 5000,
            price: 140.0
        )
        
        XCTAssertTrue(trade1Success, "錦標賽1交易應該成功")
        XCTAssertTrue(trade2Success, "錦標賽2交易應該成功")
        
        // 驗證交易隔離 - 獲取更新後的投資組合
        guard let updatedPortfolio1 = await portfolioManager.getTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId
        ) else {
            XCTFail("無法獲取更新後的錦標賽1投資組合")
            return
        }
        
        guard let updatedPortfolio2 = await portfolioManager.getTournamentPortfolio(
            tournamentId: tournament2.id,
            userId: userId
        ) else {
            XCTFail("無法獲取更新後的錦標賽2投資組合")
            return
        }
        
        // 驗證錦標賽1只有台積電持股
        XCTAssertEqual(updatedPortfolio1.holdings.count, 1, "錦標賽1應該只有1筆持股")
        XCTAssertEqual(updatedPortfolio1.holdings.first?.symbol, "2330", "錦標賽1應該持有台積電")
        XCTAssertEqual(updatedPortfolio1.holdings.first?.quantity, 1000, "錦標賽1台積電數量正確")
        
        // 驗證錦標賽2只有0050持股
        XCTAssertEqual(updatedPortfolio2.holdings.count, 1, "錦標賽2應該只有1筆持股")
        XCTAssertEqual(updatedPortfolio2.holdings.first?.symbol, "0050", "錦標賽2應該持有0050")
        XCTAssertEqual(updatedPortfolio2.holdings.first?.quantity, 5000, "錦標賽20050數量正確")
        
        // 驗證交易記錄隔離
        XCTAssertEqual(updatedPortfolio1.tradingRecords.count, 1, "錦標賽1應該有1筆交易記錄")
        XCTAssertEqual(updatedPortfolio2.tradingRecords.count, 1, "錦標賽2應該有1筆交易記錄")
        
        XCTAssertEqual(updatedPortfolio1.tradingRecords.first?.symbol, "2330", "錦標賽1交易記錄是台積電")
        XCTAssertEqual(updatedPortfolio2.tradingRecords.first?.symbol, "0050", "錦標賽2交易記錄是0050")
    }
    
    /// 測試錦標賽績效計算獨立性
    func testTournamentPerformanceIsolation() async throws {
        let userId = UUID()
        
        // 創建兩個錦標賽投資組合
        guard let _ = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament1.initialBalance
        ),
        let _ = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament2.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament2.initialBalance
        ) else {
            XCTFail("無法創建測試錦標賽投資組合")
            return
        }
        
        // 在錦標賽1中進行盈利交易
        await portfolioManager.executeTrade(
            tournamentId: tournament1.id,
            symbol: "2330",
            stockName: "台積電",
            action: .buy,
            shares: 1000,
            price: 500.0
        )
        
        // 模擬價格上漲，更新持股價格
        await updateHoldingPrice(tournamentId: tournament1.id, userId: userId, symbol: "2330", newPrice: 600.0)
        
        // 在錦標賽2中進行虧損交易
        await portfolioManager.executeTrade(
            tournamentId: tournament2.id,
            symbol: "0050",
            stockName: "元大台灣50",
            action: .buy,
            shares: 5000,
            price: 150.0
        )
        
        // 模擬價格下跌
        await updateHoldingPrice(tournamentId: tournament2.id, userId: userId, symbol: "0050", newPrice: 130.0)
        
        // 獲取更新後的投資組合
        guard let portfolio1 = await portfolioManager.getTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId
        ),
        let portfolio2 = await portfolioManager.getTournamentPortfolio(
            tournamentId: tournament2.id,
            userId: userId
        ) else {
            XCTFail("無法獲取測試投資組合")
            return
        }
        
        // 驗證績效計算獨立性
        XCTAssertGreaterThan(portfolio1.totalReturnPercentage, 0, "錦標賽1應該有正報酬")
        XCTAssertLessThan(portfolio2.totalReturnPercentage, 0, "錦標賽2應該有負報酬")
        
        // 驗證總資產價值不同
        XCTAssertNotEqual(portfolio1.totalPortfolioValue, portfolio2.totalPortfolioValue, "兩個錦標賽的總資產應該不同")
    }
    
    /// 測試錦標賽排名系統獨立性
    func testTournamentRankingIsolation() async throws {
        let user1Id = UUID()
        let user2Id = UUID()
        let user3Id = UUID()
        
        // 為三個用戶在兩個不同錦標賽中創建投資組合
        let portfolios1 = await createMultiplePortfolios(
            tournamentId: tournament1.id,
            userIds: [user1Id, user2Id, user3Id],
            initialBalance: tournament1.initialBalance
        )
        
        let portfolios2 = await createMultiplePortfolios(
            tournamentId: tournament2.id,
            userIds: [user1Id, user2Id, user3Id],
            initialBalance: tournament2.initialBalance
        )
        
        XCTAssertEqual(portfolios1.count, 3, "錦標賽1應該有3個投資組合")
        XCTAssertEqual(portfolios2.count, 3, "錦標賽2應該有3個投資組合")
        
        // 在錦標賽1中進行不同績效的交易
        await simulateDifferentPerformances(tournamentId: tournament1.id, userIds: [user1Id, user2Id, user3Id])
        
        // 在錦標賽2中進行不同的績效模擬
        await simulateDifferentPerformances(tournamentId: tournament2.id, userIds: [user1Id, user2Id, user3Id])
        
        // 計算並更新排名
        await portfolioManager.updateAllRankings(tournamentId: tournament1.id)
        await portfolioManager.updateAllRankings(tournamentId: tournament2.id)
        
        // 驗證每個錦標賽都有獨立的排名
        let rankings1 = await portfolioManager.getTournamentRankings(tournamentId: tournament1.id)
        let rankings2 = await portfolioManager.getTournamentRankings(tournamentId: tournament2.id)
        
        XCTAssertEqual(rankings1.count, 3, "錦標賽1應該有3個排名")
        XCTAssertEqual(rankings2.count, 3, "錦標賽2應該有3個排名")
        
        // 驗證排名獨立性
        for i in 0..<3 {
            XCTAssertNotEqual(rankings1[i].rank, rankings2[i].rank, "同一用戶在不同錦標賽的排名應該可能不同")
        }
    }
    
    /// 測試錦標賽投資組合清理功能
    func testTournamentPortfolioCleanup() async throws {
        let userId = UUID()
        
        // 創建錦標賽投資組合
        guard let portfolio = await portfolioManager.createTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId,
            userName: "TestUser",
            initialBalance: tournament1.initialBalance
        ) else {
            XCTFail("無法創建測試投資組合")
            return
        }
        
        // 進行一些交易
        await portfolioManager.executeTrade(
            tournamentId: tournament1.id,
            symbol: "2330",
            stockName: "台積電",
            action: .buy,
            shares: 1000,
            price: 580.0
        )
        
        // 驗證投資組合存在
        let retrievedPortfolio = await portfolioManager.getTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId
        )
        XCTAssertNotNil(retrievedPortfolio, "投資組合應該存在")
        
        // 清理投資組合
        await portfolioManager.cleanupTournamentPortfolio(tournamentId: tournament1.id, userId: userId)
        
        // 驗證投資組合已被清理
        let cleanedPortfolio = await portfolioManager.getTournamentPortfolio(
            tournamentId: tournament1.id,
            userId: userId
        )
        XCTAssertNil(cleanedPortfolio, "投資組合應該已被清理")
    }
    
    // MARK: - 輔助方法
    
    private func createTestTournaments() async {
        tournament1 = Tournament(
            id: UUID(),
            name: "春季投資挑戰賽",
            description: "測試錦標賽1",
            hostUserId: UUID(),
            hostUserName: "Host1",
            initialBalance: 1_000_000,
            maxParticipants: 100,
            currentParticipants: 0,
            entryFee: 0,
            prizePool: 0,
            prizeDistribution: [],
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            status: .ongoing,
            rules: TournamentRules(
                maxSingleStockRate: 30.0,
                minHoldingRate: 60.0,
                allowedStockTypes: [.listed, .otc],
                maxLeverage: 1.0,
                tradingHours: TradingHours(
                    start: "09:00",
                    end: "13:30",
                    timezone: "Asia/Taipei"
                )
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        tournament2 = Tournament(
            id: UUID(),
            name: "夏季投資大賽",
            description: "測試錦標賽2",
            hostUserId: UUID(),
            hostUserName: "Host2",
            initialBalance: 2_000_000,
            maxParticipants: 50,
            currentParticipants: 0,
            entryFee: 1000,
            prizePool: 50000,
            prizeDistribution: [0.5, 0.3, 0.2],
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 60),
            status: .ongoing,
            rules: TournamentRules(
                maxSingleStockRate: 25.0,
                minHoldingRate: 50.0,
                allowedStockTypes: [.listed],
                maxLeverage: 1.5,
                tradingHours: TradingHours(
                    start: "09:00",
                    end: "13:30",
                    timezone: "Asia/Taipei"
                )
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        tournament3 = Tournament(
            id: UUID(),
            name: "新手友善賽",
            description: "測試錦標賽3",
            hostUserId: UUID(),
            hostUserName: "Host3",
            initialBalance: 500_000,
            maxParticipants: 200,
            currentParticipants: 0,
            entryFee: 0,
            prizePool: 0,
            prizeDistribution: [],
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 14),
            status: .ongoing,
            rules: TournamentRules(
                maxSingleStockRate: 40.0,
                minHoldingRate: 80.0,
                allowedStockTypes: [.listed, .otc, .etf],
                maxLeverage: 1.0,
                tradingHours: TradingHours(
                    start: "09:00",
                    end: "13:30",
                    timezone: "Asia/Taipei"
                )
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMultiplePortfolios(
        tournamentId: UUID,
        userIds: [UUID],
        initialBalance: Double
    ) async -> [TournamentPortfolio] {
        var portfolios: [TournamentPortfolio] = []
        
        for (index, userId) in userIds.enumerated() {
            if let portfolio = await portfolioManager.createTournamentPortfolio(
                tournamentId: tournamentId,
                userId: userId,
                userName: "User\(index + 1)",
                initialBalance: initialBalance
            ) {
                portfolios.append(portfolio)
            }
        }
        
        return portfolios
    }
    
    private func simulateDifferentPerformances(tournamentId: UUID, userIds: [UUID]) async {
        // 用戶1: 高績效
        await portfolioManager.executeTrade(
            tournamentId: tournamentId,
            symbol: "2330",
            stockName: "台積電",
            action: .buy,
            shares: 1000,
            price: 500.0
        )
        await updateHoldingPrice(tournamentId: tournamentId, userId: userIds[0], symbol: "2330", newPrice: 600.0)
        
        // 用戶2: 中等績效
        await portfolioManager.executeTrade(
            tournamentId: tournamentId,
            symbol: "0050",
            stockName: "元大台灣50",
            action: .buy,
            shares: 2000,
            price: 140.0
        )
        await updateHoldingPrice(tournamentId: tournamentId, userId: userIds[1], symbol: "0050", newPrice: 145.0)
        
        // 用戶3: 低績效
        await portfolioManager.executeTrade(
            tournamentId: tournamentId,
            symbol: "3008",
            stockName: "大立光",
            action: .buy,
            shares: 100,
            price: 3000.0
        )
        await updateHoldingPrice(tournamentId: tournamentId, userId: userIds[2], symbol: "3008", newPrice: 2800.0)
    }
    
    private func updateHoldingPrice(tournamentId: UUID, userId: UUID, symbol: String, newPrice: Double) async {
        // 模擬更新持股當前價格的功能
        // 在實際實現中，這會通過 TournamentPortfolioManager 的價格更新方法來完成
        await portfolioManager.updateHoldingPrice(
            tournamentId: tournamentId,
            userId: userId,
            symbol: symbol,
            newPrice: newPrice
        )
    }
}