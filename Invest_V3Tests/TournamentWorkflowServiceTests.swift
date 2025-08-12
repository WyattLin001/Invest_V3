//
//  TournamentWorkflowServiceTests.swift
//  Invest_V3Tests
//
//  錦標賽工作流程服務測試 - 測試新的服務架構
//

import XCTest
@testable import Invest_V3

@MainActor
class TournamentWorkflowServiceTests: XCTestCase {
    
    // MARK: - 測試對象
    
    var workflowService: TournamentWorkflowService!
    var mockTournamentService: MockTournamentService!
    var mockTradeService: MockTournamentTradeService!
    var mockWalletService: MockTournamentWalletService!
    var mockRankingService: MockTournamentRankingService!
    var mockBusinessService: MockTournamentBusinessService!
    
    // 測試數據
    var testTournament: Tournament!
    var testUser: UUID!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化 Mock 服務
        mockTournamentService = MockTournamentService()
        mockTradeService = MockTournamentTradeService()
        mockWalletService = MockTournamentWalletService()
        mockRankingService = MockTournamentRankingService()
        mockBusinessService = MockTournamentBusinessService()
        
        // 創建工作流程服務
        workflowService = TournamentWorkflowService(
            tournamentService: mockTournamentService,
            tradeService: mockTradeService,
            walletService: mockWalletService,
            rankingService: mockRankingService,
            businessService: mockBusinessService
        )
        
        // 準備測試數據
        testUser = UUID()
        testTournament = createTestTournament()
    }
    
    override func tearDown() async throws {
        workflowService = nil
        mockTournamentService = nil
        mockTradeService = nil
        mockWalletService = nil
        mockRankingService = nil
        mockBusinessService = nil
        testTournament = nil
        testUser = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 錦標賽創建測試
    
    func testCreateTournament_Success() async throws {
        // Arrange
        let parameters = TournamentCreationParameters(
            name: "測試錦標賽",
            description: "這是一個測試錦標賽",
            startDate: Date().addingTimeInterval(86400), // 明天開始
            endDate: Date().addingTimeInterval(86400 * 8), // 一週後結束
            entryCapital: 1000000,
            maxParticipants: 100,
            feeTokens: 0,
            returnMetric: "twr",
            resetMode: "monthly"
        )
        
        mockTournamentService.shouldSucceed = true
        
        // Act
        let result = try await workflowService.createTournament(parameters)
        
        // Assert
        XCTAssertEqual(result.name, parameters.name)
        XCTAssertEqual(result.description, parameters.description)
        XCTAssertEqual(result.entryCapital, parameters.entryCapital)
        XCTAssertEqual(result.maxParticipants, parameters.maxParticipants)
        XCTAssertEqual(result.status, .upcoming)
        XCTAssertTrue(mockTournamentService.createTournamentCalled)
    }
    
    func testCreateTournament_InvalidParameters_ThrowsError() async {
        // Arrange
        let invalidParameters = TournamentCreationParameters(
            name: "", // 無效的空名稱
            description: "測試",
            startDate: Date().addingTimeInterval(-86400), // 過去的開始時間
            endDate: Date().addingTimeInterval(86400),
            entryCapital: -1000, // 負數資金
            maxParticipants: 0, // 無效的參與者數量
            feeTokens: -10, // 負數費用
            returnMetric: "",
            resetMode: ""
        )
        
        // Act & Assert
        do {
            _ = try await workflowService.createTournament(invalidParameters)
            XCTFail("應該拋出錯誤")
        } catch TournamentWorkflowError.invalidParameters {
            // 期望的錯誤
        } catch {
            XCTFail("拋出了錯誤的錯誤類型: \(error)")
        }
    }
    
    // MARK: - 錦標賽參加測試
    
    func testJoinTournament_Success() async throws {
        // Arrange
        mockTournamentService.shouldSucceed = true
        mockWalletService.shouldSucceed = true
        mockBusinessService.shouldSucceed = true
        
        // Act
        try await workflowService.joinTournament(tournamentId: testTournament.id)
        
        // Assert
        XCTAssertTrue(mockBusinessService.joinTournamentCalled)
        XCTAssertTrue(mockWalletService.createWalletCalled)
    }
    
    func testJoinTournament_TournamentNotFound_ThrowsError() async {
        // Arrange
        mockTournamentService.shouldReturnNil = true
        
        // Act & Assert
        do {
            try await workflowService.joinTournament(tournamentId: UUID())
            XCTFail("應該拋出錯誤")
        } catch TournamentWorkflowError.tournamentNotFound {
            // 期望的錯誤
        } catch {
            XCTFail("拋出了錯誤的錯誤類型: \(error)")
        }
    }
    
    func testJoinTournament_TournamentFull_ThrowsError() async {
        // Arrange
        let fullTournament = Tournament(
            id: UUID(),
            name: "滿員錦標賽",
            type: .monthly,
            status: .ongoing,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            description: "測試滿員錦標賽",
            shortDescription: "滿員錦標賽",
            initialBalance: 1000000,
            entryFee: 0.0,
            prizePool: 0.0,
            maxParticipants: 100,
            currentParticipants: 100, // 已滿員
            isFeatured: false,
            createdBy: UUID(),
            riskLimitPercentage: 0.2,
            minHoldingRate: 0.5,
            maxSingleStockRate: 0.3,
            rules: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        mockTournamentService.mockTournament = fullTournament
        
        // Act & Assert
        do {
            try await workflowService.joinTournament(tournamentId: fullTournament.id)
            XCTFail("應該拋出錯誤")
        } catch TournamentWorkflowError.tournamentFull {
            // 期望的錯誤
        } catch {
            XCTFail("拋出了錯誤的錯誤類型: \(error)")
        }
    }
    
    // MARK: - 交易執行測試
    
    func testExecuteTournamentTrade_Success() async throws {
        // Arrange
        mockTradeService.shouldSucceed = true
        mockWalletService.shouldSucceed = true
        
        let tradeRequest = TournamentTradeRequest(
            tournamentId: testTournament.id,
            symbol: "2330",
            side: .buy,
            quantity: 1000,
            price: 580.0
        )
        
        // Act
        let result = try await workflowService.executeTournamentTrade(tradeRequest)
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result.symbol, tradeRequest.symbol)
        XCTAssertEqual(result.side, tradeRequest.side)
        XCTAssertEqual(result.quantity, tradeRequest.quantity)
        XCTAssertTrue(mockTradeService.executeTradeRawCalled)
        XCTAssertTrue(mockWalletService.updateWalletCalled)
    }
    
    func testExecuteTournamentTrade_InsufficientFunds_ThrowsError() async {
        // Arrange
        mockWalletService.shouldFailWithInsufficientFunds = true
        
        let tradeRequest = TournamentTradeRequest(
            tournamentId: testTournament.id,
            symbol: "2330",
            side: .buy,
            quantity: 10000, // 過大的數量
            price: 580.0
        )
        
        // Act & Assert
        do {
            _ = try await workflowService.executeTournamentTrade(tradeRequest)
            XCTFail("應該拋出錯誤")
        } catch TournamentWorkflowError.insufficientFunds {
            // 期望的錯誤
        } catch {
            XCTFail("拋出了錯誤的錯誤類型: \(error)")
        }
    }
    
    // MARK: - 排行榜更新測試
    
    func testUpdateLiveRankings_Success() async throws {
        // Arrange
        let mockRankings = [
            createMockRanking(rank: 1, userId: UUID(), totalReturn: 15.5),
            createMockRanking(rank: 2, userId: UUID(), totalReturn: 12.3),
            createMockRanking(rank: 3, userId: UUID(), totalReturn: 8.7)
        ]
        
        mockRankingService.mockRankings = mockRankings
        
        // Act
        let result = try await workflowService.updateLiveRankings(tournamentId: testTournament.id)
        
        // Assert
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].rank, 1)
        XCTAssertEqual(result[1].rank, 2)
        XCTAssertEqual(result[2].rank, 3)
        XCTAssertTrue(mockRankingService.updateLiveRankingsCalled)
    }
    
    // MARK: - 錦標賽結算測試
    
    func testSettleTournament_Success() async throws {
        // Arrange
        let endedTournament = Tournament(
            id: testTournament.id,
            name: testTournament.name,
            type: testTournament.type,
            status: .finished, // 使用數據庫的 finished 狀態
            startDate: testTournament.startDate,
            endDate: Date().addingTimeInterval(-3600), // 一小時前結束
            description: testTournament.description,
            shortDescription: testTournament.shortDescription,
            initialBalance: testTournament.initialBalance,
            entryFee: testTournament.entryFee,
            prizePool: testTournament.prizePool,
            maxParticipants: testTournament.maxParticipants,
            currentParticipants: testTournament.currentParticipants,
            isFeatured: testTournament.isFeatured,
            createdBy: testTournament.createdBy,
            riskLimitPercentage: testTournament.riskLimitPercentage,
            minHoldingRate: testTournament.minHoldingRate,
            maxSingleStockRate: testTournament.maxSingleStockRate,
            rules: testTournament.rules,
            createdAt: testTournament.createdAt,
            updatedAt: testTournament.updatedAt
        )
        
        mockTournamentService.mockTournament = endedTournament
        mockBusinessService.shouldSucceed = true
        
        let mockResults = [
            createMockTournamentResult(rank: 1, userId: UUID(), finalReturn: 18.5),
            createMockTournamentResult(rank: 2, userId: UUID(), finalReturn: 15.2),
            createMockTournamentResult(rank: 3, userId: UUID(), finalReturn: 12.1)
        ]
        mockBusinessService.mockResults = mockResults
        
        // Act
        let results = try await workflowService.settleTournament(tournamentId: testTournament.id)
        
        // Assert
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].rank, 1)
        XCTAssertEqual(results[1].rank, 2)
        XCTAssertEqual(results[2].rank, 3)
        XCTAssertTrue(mockBusinessService.settleTournamentCalled)
    }
    
    func testSettleTournament_TournamentNotEnded_ThrowsError() async {
        // Arrange
        mockTournamentService.mockTournament = testTournament // 狀態為 active
        
        // Act & Assert
        do {
            _ = try await workflowService.settleTournament(tournamentId: testTournament.id)
            XCTFail("應該拋出錯誤")
        } catch TournamentWorkflowError.tournamentNotEnded {
            // 期望的錯誤
        } catch {
            XCTFail("拋出了錯誤的錯誤類型: \(error)")
        }
    }
    
    // MARK: - 輔助方法
    
    private func createTestTournament() -> Tournament {
        return Tournament(
            id: UUID(),
            name: "測試錦標賽",
            type: .monthly,
            status: .ongoing, // 使用數據庫的 ongoing 狀態
            startDate: Date().addingTimeInterval(-3600), // 一小時前開始
            endDate: Date().addingTimeInterval(86400 * 7), // 一週後結束
            description: "這是一個測試用的錦標賽",
            shortDescription: "測試錦標賽",
            initialBalance: 1000000,  // 對應 initial_balance
            entryFee: 0.0,           // 對應 entry_fee
            prizePool: 0.0,
            maxParticipants: 100,
            currentParticipants: 50,
            isFeatured: false,
            createdBy: nil,
            riskLimitPercentage: 0.2,
            minHoldingRate: 0.5,
            maxSingleStockRate: 0.3,
            rules: [],
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date()
        )
    }
    
    private func createMockRanking(rank: Int, userId: UUID, totalReturn: Double) -> TournamentRanking {
        return TournamentRanking(
            userId: userId,
            rank: rank,
            totalAssets: 1000000 + (totalReturn * 10000),
            totalReturnPercent: totalReturn,
            totalTrades: Int.random(in: 10...50),
            winRate: Double.random(in: 40...80)
        )
    }
    
    private func createMockTournamentResult(rank: Int, userId: UUID, finalReturn: Double) -> TournamentResult {
        return TournamentResult(
            userId: userId,
            rank: rank,
            finalReturn: finalReturn,
            totalTrades: Int.random(in: 15...60),
            winRate: Double.random(in: 45...85),
            reward: rank <= 3 ? TournamentReward(
                type: "tokens",
                amount: Double([1000, 500, 250][rank - 1]),
                description: "第\(rank)名獎勵"
            ) : nil
        )
    }
}

// MARK: - Mock Services

class MockTournamentService: TournamentService {
    var shouldSucceed = true
    var shouldReturnNil = false
    var createTournamentCalled = false
    var mockTournament: Tournament?
    
    override func createTournament(_ tournament: Tournament) async throws {
        createTournamentCalled = true
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
    }
    
    override func getTournament(id: UUID) async throws -> Tournament? {
        if shouldReturnNil {
            return nil
        }
        return mockTournament ?? Tournament(
            id: id,
            name: "Mock Tournament",
            type: .monthly,
            status: .ongoing,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            description: "Mock Description",
            shortDescription: "Mock Tournament",
            initialBalance: 1000000,
            entryFee: 0.0,
            prizePool: 0.0,
            maxParticipants: 100,
            currentParticipants: 50,
            isFeatured: false,
            createdBy: UUID(),
            riskLimitPercentage: 0.2,
            minHoldingRate: 0.5,
            maxSingleStockRate: 0.3,
            rules: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

class MockTournamentTradeService: TournamentTradeService {
    var shouldSucceed = true
    var executeTradeRawCalled = false
    
    override func executeTradeRaw(_ request: TournamentTradeRequest) async throws -> TournamentTrade {
        executeTradeRawCalled = true
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        
        return TournamentTrade(
            id: UUID(),
            tournamentId: request.tournamentId,
            userId: UUID(),
            symbol: request.symbol,
            side: request.side,
            quantity: request.quantity,
            price: request.price,
            executedAt: Date(),
            status: .filled
        )
    }
}

class MockTournamentWalletService: TournamentWalletService {
    var shouldSucceed = true
    var shouldFailWithInsufficientFunds = false
    var createWalletCalled = false
    var updateWalletCalled = false
    
    override func createWallet(tournamentId: UUID, userId: UUID, initialBalance: Double) async throws {
        createWalletCalled = true
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
    }
    
    override func updateWalletAfterTrade(trade: TournamentTrade) async throws {
        updateWalletCalled = true
        if shouldFailWithInsufficientFunds {
            throw TournamentWorkflowError.insufficientFunds("餘額不足")
        }
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
    }
}

class MockTournamentRankingService: TournamentRankingService {
    var shouldSucceed = true
    var updateLiveRankingsCalled = false
    var mockRankings: [TournamentRanking] = []
    
    override func updateLiveRankings(tournamentId: UUID) async throws -> [TournamentRanking] {
        updateLiveRankingsCalled = true
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        return mockRankings
    }
}

class MockTournamentBusinessService: TournamentBusinessService {
    var shouldSucceed = true
    var joinTournamentCalled = false
    var settleTournamentCalled = false
    var mockResults: [TournamentResult] = []
    
    override func joinTournament(tournamentId: UUID, userId: UUID) async throws {
        joinTournamentCalled = true
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
    }
    
    override func settleTournament(tournamentId: UUID) async throws -> [TournamentResult] {
        settleTournamentCalled = true
        if !shouldSucceed {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        return mockResults
    }
}