//
//  TournamentIntegrationTests.swift
//  Invest_V3Tests
//
//  錦標賽集成測試 - 測試完整的錦標賽業務流程
//

import XCTest
@testable import Invest_V3

@MainActor
class TournamentIntegrationTests: XCTestCase {
    
    // MARK: - 測試組件
    
    var workflowService: TournamentWorkflowService!
    var tournamentService: TournamentService!
    var tradeService: TournamentTradeService!
    var walletService: TournamentWalletService!
    var rankingService: TournamentRankingService!
    var businessService: TournamentBusinessService!
    
    // 測試數據
    var testUsers: [UUID] = []
    var testTournament: Tournament!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化服務
        tournamentService = TournamentService()
        tradeService = TournamentTradeService()
        walletService = TournamentWalletService()
        rankingService = TournamentRankingService()
        businessService = TournamentBusinessService()
        
        workflowService = TournamentWorkflowService(
            tournamentService: tournamentService,
            tradeService: tradeService,
            walletService: walletService,
            rankingService: rankingService,
            businessService: businessService
        )
        
        // 創建測試用戶
        testUsers = (0..<5).map { _ in UUID() }
        
        // 創建測試錦標賽
        try await createTestTournament()
    }
    
    override func tearDown() async throws {
        // 清理測試數據
        if let tournament = testTournament {
            try? await cleanupTournament(tournament.id)
        }
        
        workflowService = nil
        tournamentService = nil
        tradeService = nil
        walletService = nil
        rankingService = nil
        businessService = nil
        testTournament = nil
        testUsers = []
        
        try await super.tearDown()
    }
    
    // MARK: - 完整錦標賽生命週期測試
    
    func testCompleteTournamentLifecycle() async throws {
        print("🧪 開始完整錦標賽生命週期測試")
        
        // 階段 1: 錦標賽創建
        print("📋 階段 1: 錦標賽創建")
        XCTAssertNotNil(testTournament, "錦標賽應該成功創建")
        XCTAssertEqual(testTournament.status, .upcoming, "新錦標賽狀態應該是即將開始")
        
        // 階段 2: 用戶報名
        print("👥 階段 2: 用戶報名")
        for (index, userId) in testUsers.enumerated() {
            do {
                try await workflowService.joinTournament(tournamentId: testTournament.id)
                print("✅ 用戶 \(index + 1) 報名成功")
            } catch {
                XCTFail("用戶 \(index + 1) 報名失敗: \(error)")
            }
        }
        
        // 驗證報名結果
        let updatedTournament = try await tournamentService.getTournament(id: testTournament.id)
        XCTAssertEqual(updatedTournament?.currentParticipants, testUsers.count, "錦標賽參與者數量應該正確")
        
        // 階段 3: 錦標賽開始（模擬狀態變更）
        print("🏁 階段 3: 錦標賽開始")
        try await updateTournamentStatus(testTournament.id, to: .active)
        
        // 階段 4: 用戶交易
        print("💰 階段 4: 用戶交易")
        try await simulateUserTrading()
        
        // 階段 5: 排行榜更新
        print("🏅 階段 5: 排行榜更新")
        let rankings = try await workflowService.updateLiveRankings(tournamentId: testTournament.id)
        XCTAssertGreaterThan(rankings.count, 0, "應該生成排行榜")
        XCTAssertEqual(rankings.first?.rank, 1, "第一名排名應該是1")
        
        // 階段 6: 錦標賽結束
        print("🏁 階段 6: 錦標賽結束")
        try await updateTournamentStatus(testTournament.id, to: .ended)
        
        // 階段 7: 錦標賽結算
        print("📊 階段 7: 錦標賽結算")
        let results = try await workflowService.settleTournament(tournamentId: testTournament.id)
        XCTAssertGreaterThan(results.count, 0, "應該生成結算結果")
        
        // 驗證結算結果
        validateSettlementResults(results)
        
        print("✅ 完整錦標賽生命週期測試完成")
    }
    
    // MARK: - 錦標賽並發測試
    
    func testConcurrentTournamentOperations() async throws {
        print("⚡ 開始並發操作測試")
        
        // 並發報名測試
        await withTaskGroup(of: Void.self) { group in
            for userId in testUsers {
                group.addTask {
                    do {
                        try await self.workflowService.joinTournament(tournamentId: self.testTournament.id)
                        print("✅ 並發報名成功: \(userId)")
                    } catch {
                        print("❌ 並發報名失敗: \(error)")
                    }
                }
            }
        }
        
        // 啟動錦標賽
        try await updateTournamentStatus(testTournament.id, to: .active)
        
        // 並發交易測試
        await withTaskGroup(of: Void.self) { group in
            for (index, userId) in testUsers.enumerated() {
                group.addTask {
                    do {
                        let tradeRequest = TournamentTradeRequest(
                            tournamentId: self.testTournament.id,
                            symbol: "233\(index)",
                            side: .buy,
                            quantity: 100 * (index + 1),
                            price: 500.0 + Double(index * 10)
                        )
                        _ = try await self.workflowService.executeTournamentTrade(tradeRequest)
                        print("✅ 並發交易成功: \(userId)")
                    } catch {
                        print("❌ 並發交易失敗: \(error)")
                    }
                }
            }
        }
        
        // 並發排行榜更新測試
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    do {
                        _ = try await self.workflowService.updateLiveRankings(tournamentId: self.testTournament.id)
                        print("✅ 並發排行榜更新成功")
                    } catch {
                        print("❌ 並發排行榜更新失敗: \(error)")
                    }
                }
            }
        }
        
        print("✅ 並發操作測試完成")
    }
    
    // MARK: - 錦標賽數據一致性測試
    
    func testTournamentDataConsistency() async throws {
        print("🔍 開始數據一致性測試")
        
        // 報名多個用戶
        for userId in testUsers {
            try await workflowService.joinTournament(tournamentId: testTournament.id)
        }
        
        // 啟動錦標賽
        try await updateTournamentStatus(testTournament.id, to: .active)
        
        // 執行交易
        for (index, userId) in testUsers.enumerated() {
            let tradeRequest = TournamentTradeRequest(
                tournamentId: testTournament.id,
                symbol: "2330",
                side: .buy,
                quantity: 1000,
                price: 580.0
            )
            _ = try await workflowService.executeTournamentTrade(tradeRequest)
        }
        
        // 驗證錢包數據一致性
        for userId in testUsers {
            let wallet = try await walletService.getWallet(tournamentId: testTournament.id, userId: userId)
            XCTAssertNotNil(wallet, "每個用戶都應該有錢包")
            
            if let wallet = wallet {
                // 驗證現金餘額計算正確
                let expectedCash = testTournament.initialBalance - (1000 * 580.0)
                XCTAssertEqual(wallet.cash, expectedCash, accuracy: 0.01, "現金餘額應該正確")
                
                // 驗證持倉數據
                let position = wallet.positions.first { $0.symbol == "2330" }
                XCTAssertNotNil(position, "應該有台積電持倉")
                XCTAssertEqual(position?.quantity, 1000, "持倉數量應該正確")
            }
        }
        
        // 驗證排行榜數據一致性
        let rankings = try await workflowService.updateLiveRankings(tournamentId: testTournament.id)
        XCTAssertEqual(rankings.count, testUsers.count, "排行榜人數應該正確")
        
        // 驗證排名順序
        for i in 0..<rankings.count - 1 {
            XCTAssertLessThanOrEqual(rankings[i].rank, rankings[i + 1].rank, "排名順序應該正確")
        }
        
        print("✅ 數據一致性測試完成")
    }
    
    // MARK: - 錦標賽錯誤處理測試
    
    func testTournamentErrorHandling() async throws {
        print("🚨 開始錯誤處理測試")
        
        // 測試重複報名
        try await workflowService.joinTournament(tournamentId: testTournament.id)
        
        do {
            try await workflowService.joinTournament(tournamentId: testTournament.id)
            XCTFail("重複報名應該失敗")
        } catch {
            print("✅ 重複報名正確被拒絕")
        }
        
        // 測試在未開始的錦標賽中交易
        let tradeRequest = TournamentTradeRequest(
            tournamentId: testTournament.id,
            symbol: "2330",
            side: .buy,
            quantity: 1000,
            price: 580.0
        )
        
        do {
            _ = try await workflowService.executeTournamentTrade(tradeRequest)
            XCTFail("在未開始的錦標賽中交易應該失敗")
        } catch {
            print("✅ 未開始錦標賽交易正確被拒絕")
        }
        
        // 測試結算未結束的錦標賽
        do {
            _ = try await workflowService.settleTournament(tournamentId: testTournament.id)
            XCTFail("結算未結束的錦標賽應該失敗")
        } catch TournamentWorkflowError.tournamentNotEnded {
            print("✅ 未結束錦標賽結算正確被拒絕")
        } catch {
            XCTFail("拋出了錯誤的錯誤類型: \(error)")
        }
        
        // 測試不存在的錦標賽操作
        let nonExistentTournamentId = UUID()
        
        do {
            try await workflowService.joinTournament(tournamentId: nonExistentTournamentId)
            XCTFail("加入不存在的錦標賽應該失敗")
        } catch {
            print("✅ 不存在錦標賽操作正確被拒絕")
        }
        
        print("✅ 錯誤處理測試完成")
    }
    
    // MARK: - 錦標賽性能測試
    
    func testTournamentPerformance() async throws {
        print("⚡ 開始性能測試")
        
        // 測試大量用戶報名性能
        let largeUserCount = 100
        let largeUserIds = (0..<largeUserCount).map { _ in UUID() }
        
        let startTime = Date()
        
        for userId in largeUserIds {
            try await workflowService.joinTournament(tournamentId: testTournament.id)
        }
        
        let enrollmentTime = Date().timeIntervalSince(startTime)
        print("📊 \(largeUserCount) 用戶報名耗時: \(enrollmentTime) 秒")
        
        // 性能斷言
        XCTAssertLessThan(enrollmentTime, 10.0, "大量用戶報名應該在10秒內完成")
        
        // 啟動錦標賽
        try await updateTournamentStatus(testTournament.id, to: .active)
        
        // 測試排行榜更新性能
        let rankingStartTime = Date()
        _ = try await workflowService.updateLiveRankings(tournamentId: testTournament.id)
        let rankingTime = Date().timeIntervalSince(rankingStartTime)
        
        print("📊 \(largeUserCount) 用戶排行榜更新耗時: \(rankingTime) 秒")
        XCTAssertLessThan(rankingTime, 5.0, "排行榜更新應該在5秒內完成")
        
        print("✅ 性能測試完成")
    }
    
    // MARK: - 輔助方法
    
    private func createTestTournament() async throws {
        let parameters = TournamentCreationParameters(
            name: "集成測試錦標賽",
            description: "用於集成測試的錦標賽",
            startDate: Date().addingTimeInterval(3600), // 1小時後開始
            endDate: Date().addingTimeInterval(86400 * 7), // 1週後結束
            entryCapital: 1000000,
            maxParticipants: 1000,
            feeTokens: 0,
            returnMetric: "twr",
            resetMode: "monthly"
        )
        
        testTournament = try await workflowService.createTournament(parameters)
    }
    
    private func updateTournamentStatus(_ tournamentId: UUID, to status: TournamentLifecycleState) async throws {
        // 這裡應該呼叫實際的狀態更新方法
        // 目前使用模擬實現
        print("🔄 更新錦標賽狀態到: \(status)")
        
        // 更新測試錦標賽對象的狀態
        testTournament = Tournament(
            id: testTournament.id,
            name: testTournament.name,
            type: testTournament.type,
            status: status,
            startDate: testTournament.startDate,
            endDate: testTournament.endDate,
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
    }
    
    private func simulateUserTrading() async throws {
        let stocks = ["2330", "2454", "0050", "2317", "1303"]
        
        for (index, userId) in testUsers.enumerated() {
            let stock = stocks[index % stocks.count]
            let quantity = 100 * (index + 1)
            let price = 500.0 + Double(index * 10)
            
            let tradeRequest = TournamentTradeRequest(
                tournamentId: testTournament.id,
                symbol: stock,
                side: .buy,
                quantity: quantity,
                price: price
            )
            
            _ = try await workflowService.executeTournamentTrade(tradeRequest)
            print("✅ 用戶 \(index + 1) 交易成功: \(stock)")
        }
    }
    
    private func validateSettlementResults(_ results: [TournamentResult]) {
        // 驗證排名唯一性
        let ranks = results.map { $0.rank }
        let uniqueRanks = Set(ranks)
        XCTAssertEqual(ranks.count, uniqueRanks.count, "排名應該唯一")
        
        // 驗證排名連續性
        let sortedRanks = ranks.sorted()
        for i in 0..<sortedRanks.count {
            XCTAssertEqual(sortedRanks[i], i + 1, "排名應該連續")
        }
        
        // 驗證獎勵分配（如果有獎勵）
        let rewardedResults = results.filter { $0.reward != nil }
        for result in rewardedResults {
            XCTAssertLessThanOrEqual(result.rank, 3, "只有前三名應該有獎勵")
            XCTAssertGreaterThan(result.reward!.amount, 0, "獎勵金額應該大於0")
        }
    }
    
    private func cleanupTournament(_ tournamentId: UUID) async throws {
        // 清理測試數據
        print("🧹 清理錦標賽測試數據: \(tournamentId)")
        // 實際實現應該刪除相關的錦標賽、錢包、交易等數據
    }
}

// MARK: - 測試輔助擴展

extension TournamentCreationParameters {
    static func testParameters(name: String = "測試錦標賽") -> TournamentCreationParameters {
        return TournamentCreationParameters(
            name: name,
            description: "測試用錦標賽",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(86400 * 7),
            entryCapital: 1000000,
            maxParticipants: 100,
            feeTokens: 0,
            returnMetric: "twr",
            resetMode: "monthly"
        )
    }
}