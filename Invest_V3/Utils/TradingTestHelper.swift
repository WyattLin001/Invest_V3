//
//  TradingTestHelper.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  交易功能測試輔助工具
//

import Foundation

/// 交易功能測試輔助工具
/// 提供簡單的測試方法來驗證買入和賣出功能
class TradingTestHelper {
    static let shared = TradingTestHelper()
    private init() {}
    
    /// 測試股票交易功能
    @MainActor
    func testStockTrading() async {
        print("🧪 [TradingTestHelper] 開始測試股票交易功能")
        
        let portfolioManager = ChatPortfolioManager.shared
        let syncService = PortfolioSyncService.shared
        
        // 清空現有投資組合以進行乾淨的測試
        portfolioManager.clearCurrentUserPortfolio()
        
        // 測試股票資訊
        let testSymbol = "2330"
        let testName = "台積電"
        let testPrice = 500.0
        let testShares = 10.0
        
        print("📊 [TradingTestHelper] 測試前狀態:")
        print("   持股數量: \(portfolioManager.holdings.count)")
        print("   可用餘額: \(portfolioManager.availableBalance)")
        
        // 測試 1: 買入股票
        print("\n🔄 [TradingTestHelper] 測試 1: 買入股票")
        let buySuccess = await syncService.executeTournamentTrade(
            tournamentId: nil,
            symbol: testSymbol,
            stockName: testName,
            action: TradingType.buy,
            shares: testShares,
            price: testPrice
        )
        
        print("   買入結果: \(buySuccess ? "成功" : "失敗")")
        
        if buySuccess {
            print("📊 [TradingTestHelper] 買入後狀態:")
            print("   持股數量: \(portfolioManager.holdings.count)")
            if let holding = portfolioManager.holdings.first(where: { $0.symbol == testSymbol }) {
                print("   \(testSymbol) 持股: \(holding.shares) 股")
                print("   平均成本: $\(holding.averagePrice)")
            }
            print("   可用餘額: \(portfolioManager.availableBalance)")
        }
        
        // 測試 2: 部分賣出
        if buySuccess {
            print("\n🔄 [TradingTestHelper] 測試 2: 部分賣出股票")
            let sellShares = 5.0 // 賣出一半
            let sellPrice = 520.0 // 小幅上漲
            
            let sellSuccess = await syncService.executeTournamentTrade(
                tournamentId: nil,
                symbol: testSymbol,
                stockName: testName,
                action: TradingType.sell,
                shares: sellShares,
                price: sellPrice
            )
            
            print("   賣出結果: \(sellSuccess ? "成功" : "失敗")")
            
            if sellSuccess {
                print("📊 [TradingTestHelper] 賣出後狀態:")
                print("   持股數量: \(portfolioManager.holdings.count)")
                if let holding = portfolioManager.holdings.first(where: { $0.symbol == testSymbol }) {
                    print("   \(testSymbol) 剩餘持股: \(holding.shares) 股")
                    print("   未實現損益: $\(holding.unrealizedGainLoss)")
                }
                print("   可用餘額: \(portfolioManager.availableBalance)")
            }
        }
        
        // 測試 3: 全部賣出
        if buySuccess {
            print("\n🔄 [TradingTestHelper] 測試 3: 全部賣出剩餘股票")
            if let holding = portfolioManager.holdings.first(where: { $0.symbol == testSymbol }) {
                let remainingShares = holding.shares
                let sellPrice = 480.0 // 小幅下跌
                
                let sellAllSuccess = await syncService.executeTournamentTrade(
                    tournamentId: nil,
                    symbol: testSymbol,
                    stockName: testName,
                    action: TradingType.sell,
                    shares: remainingShares,
                    price: sellPrice
                )
                
                print("   全部賣出結果: \(sellAllSuccess ? "成功" : "失敗")")
                
                if sellAllSuccess {
                    print("📊 [TradingTestHelper] 全部賣出後狀態:")
                    print("   持股數量: \(portfolioManager.holdings.count)")
                    print("   可用餘額: \(portfolioManager.availableBalance)")
                }
            }
        }
        
        // 測試 4: 交易記錄統計
        print("\n📈 [TradingTestHelper] 交易記錄統計:")
        let statistics = portfolioManager.getTradingStatistics()
        print("   總交易次數: \(statistics.totalTrades)")
        print("   買入次數: \(statistics.buyTrades)")
        print("   賣出次數: \(statistics.sellTrades)")
        print("   總手續費: $\(statistics.totalFees)")
        print("   已實現損益: $\(statistics.totalRealizedGainLoss)")
        
        print("\n✅ [TradingTestHelper] 股票交易功能測試完成")
    }
    
    /// 測試錯誤情況
    @MainActor
    func testErrorCases() async {
        print("🧪 [TradingTestHelper] 開始測試錯誤情況")
        
        let syncService = PortfolioSyncService.shared
        
        // 測試 1: 賣出不存在的股票
        print("\n🔄 [TradingTestHelper] 測試 1: 賣出不存在的股票")
        let sellNonExistentSuccess = await syncService.executeTournamentTrade(
            tournamentId: nil,
            symbol: "9999",
            stockName: "不存在股票",
            action: TradingType.sell,
            shares: 10.0,
            price: 100.0
        )
        print("   結果: \(sellNonExistentSuccess ? "成功" : "失敗") (預期失敗)")
        
        // 測試 2: 賣出超過持股數量
        // 先買入一些股票
        let buyResult = await syncService.executeTournamentTrade(
            tournamentId: nil,
            symbol: "2454",
            stockName: "聯發科",
            action: TradingType.buy,
            shares: 5.0,
            price: 1000.0
        )
        
        if buyResult {
            print("\n🔄 [TradingTestHelper] 測試 2: 賣出超過持股數量")
            let oversellSuccess = await syncService.executeTournamentTrade(
                tournamentId: nil,
                symbol: "2454",
                stockName: "聯發科",
                action: TradingType.sell,
                shares: 10.0, // 超過持股的5股
                price: 1100.0
            )
            print("   結果: \(oversellSuccess ? "成功" : "失敗") (預期失敗)")
        }
        
        print("\n✅ [TradingTestHelper] 錯誤情況測試完成")
    }
}

/// 調試命令擴展
extension TradingTestHelper {
    /// 快速測試命令 - 可在調試時調用
    @MainActor
    static func quickTest() async {
        print("🚀 [TradingTestHelper] 執行快速測試")
        await shared.testStockTrading()
        await shared.testErrorCases()
    }
    
    /// 顯示當前投資組合狀態
    @MainActor
    static func showPortfolioStatus() {
        let portfolioManager = ChatPortfolioManager.shared
        print("📊 [TradingTestHelper] 當前投資組合狀態:")
        print("   持股數量: \(portfolioManager.holdings.count)")
        print("   總資產價值: $\(portfolioManager.totalPortfolioValue)")
        print("   可用餘額: $\(portfolioManager.availableBalance)")
        print("   總投資金額: $\(portfolioManager.totalInvested)")
        
        for holding in portfolioManager.holdings {
            print("   - \(holding.symbol) (\(holding.name)): \(holding.shares) 股 @ $\(holding.averagePrice)")
        }
    }
}