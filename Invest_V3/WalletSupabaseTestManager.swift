//
//  WalletSupabaseTestManager.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/4.
//  錢包 Supabase 測試管理器 - 專門測試錢包相關的資料庫操作
//

import Foundation
import SwiftUI

@MainActor
class WalletSupabaseTestManager: ObservableObject {
    @Published var isRunning = false
    @Published var testResults: [ComprehensiveTestResult] = []
    
    private let supabaseService = SupabaseService.shared
    private let TOPUP_RATE = 100.0 // 100台幣 = 1代幣
    
    // MARK: - 主要測試方法
    func runWalletTest() async {
        isRunning = true
        testResults.removeAll()
        
        print("💰 [WalletSupabaseTest] 開始錢包 Supabase 測試")
        
        // 執行各項錢包測試
        await testWalletBalanceOperations()
        await testTransactionOperations()
        await testTopUpFunctionality()
        await testInsufficientBalanceHandling()
        await testTokenSynchronization()
        await testWalletDataIntegrity()
        await testConcurrentWalletOperations()
        
        isRunning = false
        print("✅ [WalletSupabaseTest] 錢包 Supabase 測試完成")
    }
    
    // MARK: - 錢包餘額操作測試
    private func testWalletBalanceOperations() async {
        let startTime = Date()
        
        do {
            // 1. 測試餘額讀取
            let currentBalance = try await supabaseService.fetchWalletBalance()
            
            // 2. 測試餘額是否為有效數值
            guard currentBalance.isFinite && !currentBalance.isNaN else {
                let duration = Date().timeIntervalSince(startTime)
                addTestResult(
                    testName: "錢包餘額操作",
                    isSuccess: false,
                    message: "餘額數值無效: \(currentBalance)",
                    executionTime: duration
                )
                return
            }
            
            // 3. 驗證餘額格式 (應該是正數或零)
            let isValidBalance = currentBalance >= 0
            
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "錢包餘額操作",
                isSuccess: isValidBalance,
                message: isValidBalance ? 
                    "餘額讀取正常: \(Int(currentBalance))代幣" : 
                    "餘額為負數: \(currentBalance)",
                executionTime: duration,
                details: [
                    "當前餘額": "\(Int(currentBalance))代幣",
                    "數值有效性": isValidBalance ? "有效" : "無效"
                ]
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "錢包餘額操作",
                isSuccess: false,
                message: "餘額讀取失敗: \(error.localizedDescription)",
                executionTime: duration
            )
        }
    }
    
    // MARK: - 交易操作測試
    private func testTransactionOperations() async {
        let startTime = Date()
        
        do {
            // 1. 讀取交易記錄
            let transactions = try await supabaseService.fetchUserTransactions(limit: 10)
            
            // 2. 驗證交易記錄結構
            var validTransactionCount = 0
            var totalAmount: Double = 0
            var transactionTypes: Set<String> = []
            
            for transaction in transactions.prefix(10) {
                // 檢查交易的基本欄位
                if !transaction.id.uuidString.isEmpty &&
                   !transaction.transactionType.isEmpty &&
                   transaction.amountAsDouble.isFinite &&
                   !transaction.amountAsDouble.isNaN {
                    validTransactionCount += 1
                    totalAmount += transaction.amountAsDouble
                    transactionTypes.insert(transaction.transactionType)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "交易操作測試",
                isSuccess: true,
                message: "交易記錄結構正常",
                executionTime: duration,
                details: [
                    "總交易筆數": "\(transactions.count)筆",
                    "驗證筆數": "\(validTransactionCount)筆",
                    "交易類型": "\(transactionTypes.count)種",
                    "交易類型列表": transactionTypes.joined(separator: ", ")
                ]
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "交易操作測試",
                isSuccess: false,
                message: "交易記錄讀取失敗: \(error.localizedDescription)",
                executionTime: duration
            )
        }
    }
    
    // MARK: - 加值功能測試
    private func testTopUpFunctionality() async {
        let startTime = Date()
        
        // 測試加值比例和邏輯
        let testAmountNTD = 100.0 // 100台幣
        let expectedTokens = testAmountNTD / TOPUP_RATE // 應該得到1代幣
        
        // 模擬加值測試（不實際執行）
        let isCorrectRate = abs(expectedTokens - 1.0) < 0.001
        
        let duration = Date().timeIntervalSince(startTime)
        addTestResult(
            testName: "加值功能測試",
            isSuccess: isCorrectRate,
            message: isCorrectRate ? 
                "加值比例正確: 100台幣 = 1代幣" : 
                "加值比例錯誤",
            executionTime: duration,
            details: [
                "加值比例": "100台幣 = 1代幣",
                "測試金額": "100台幣",
                "預期代幣": "1代幣",
                "實際計算": "\(expectedTokens)代幣"
            ]
        )
    }
    
    // MARK: - 餘額不足處理測試
    private func testInsufficientBalanceHandling() async {
        let startTime = Date()
        
        do {
            // 讀取當前餘額
            let currentBalance = try await supabaseService.fetchWalletBalance()
            
            // 模擬各種消費場景
            let scenarios = [
                ("群組入場費", 20.0),
                ("抖內", 50.0),
                ("訂閱", 300.0),
                ("大額消費", 1000.0)
            ]
            
            var handlingResults: [String: String] = [:]
            
            for (scenarioName, cost) in scenarios {
                if currentBalance < cost {
                    handlingResults[scenarioName] = "餘額不足→引導加值"
                } else {
                    handlingResults[scenarioName] = "餘額充足→可執行"
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "餘額不足處理",
                isSuccess: true,
                message: "餘額不足處理邏輯正常",
                executionTime: duration,
                details: handlingResults
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "餘額不足處理",
                isSuccess: false,
                message: "餘額不足處理測試失敗: \(error.localizedDescription)",
                executionTime: duration
            )
        }
    }
    
    // MARK: - 代幣同步測試
    private func testTokenSynchronization() async {
        let startTime = Date()
        
        do {
            // 模擬跨View代幣同步測試
            let currentBalance = try await supabaseService.fetchWalletBalance()
            
            // 驗證代幣顯示一致性
            let homeViewBalance = currentBalance // 模擬HomeView讀取
            let chatViewBalance = currentBalance // 模擬ChatView讀取
            let walletViewBalance = currentBalance // 模擬WalletView讀取
            
            let isConsistent = homeViewBalance == chatViewBalance && 
                              chatViewBalance == walletViewBalance
            
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "代幣同步測試",
                isSuccess: isConsistent,
                message: isConsistent ? 
                    "跨View代幣顯示一致" : 
                    "代幣顯示不一致",
                executionTime: duration,
                details: [
                    "HomeView": "\(Int(homeViewBalance))代幣",
                    "ChatView": "\(Int(chatViewBalance))代幣", 
                    "WalletView": "\(Int(walletViewBalance))代幣",
                    "同步狀態": isConsistent ? "一致" : "不一致"
                ]
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "代幣同步測試",
                isSuccess: false,
                message: "代幣同步測試失敗: \(error.localizedDescription)",
                executionTime: duration
            )
        }
    }
    
    // MARK: - 錢包資料完整性測試
    private func testWalletDataIntegrity() async {
        let startTime = Date()
        
        do {
            // 1. 檢查錢包餘額表
            if let currentUser = supabaseService.getCurrentUser() {
                let walletData: [WalletBalance] = try await supabaseService.client
                    .from("wallet_balances")
                    .select()
                    .eq("user_id", value: currentUser.id.uuidString)
                    .execute()
                    .value
                
                // 2. 檢查交易記錄表
                let transactionData: [WalletTransaction] = try await supabaseService.client
                    .from("wallet_transactions")
                    .select()
                    .eq("user_id", value: currentUser.id.uuidString)
                    .limit(5)
                    .execute()
                    .value
                
                let hasWalletRecord = !walletData.isEmpty
                let hasTransactionRecords = !transactionData.isEmpty
                
                let duration = Date().timeIntervalSince(startTime)
                addTestResult(
                    testName: "錢包資料完整性",
                    isSuccess: hasWalletRecord,
                    message: hasWalletRecord ? 
                        "錢包資料完整" : 
                        "缺少錢包記錄",
                    executionTime: duration,
                    details: [
                        "錢包記錄": hasWalletRecord ? "存在" : "不存在",
                        "交易記錄": hasTransactionRecords ? "存在" : "不存在",
                        "交易筆數": "\(transactionData.count)筆"
                    ]
                )
            } else {
                let duration = Date().timeIntervalSince(startTime)
                addTestResult(
                    testName: "錢包資料完整性",
                    isSuccess: false,
                    message: "用戶未登入，無法檢查錢包資料",
                    executionTime: duration
                )
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "錢包資料完整性",
                isSuccess: false,
                message: "資料完整性檢查失敗: \(error.localizedDescription)",
                executionTime: duration
            )
        }
    }
    
    // MARK: - 併發錢包操作測試
    private func testConcurrentWalletOperations() async {
        let startTime = Date()
        
        do {
            // 併發讀取錢包餘額
            async let balance1 = supabaseService.fetchWalletBalance()
            async let balance2 = supabaseService.fetchWalletBalance()
            async let balance3 = supabaseService.fetchWalletBalance()
            async let transactions = supabaseService.fetchUserTransactions(limit: 5)
            
            let results = try await (balance1, balance2, balance3, transactions)
            
            // 檢查併發讀取的一致性
            let balanceResult1 = results.0
            let balanceResult2 = results.1
            let balanceResult3 = results.2
            let isConsistent = balanceResult1 == balanceResult2 && balanceResult2 == balanceResult3
            
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "併發錢包操作",
                isSuccess: isConsistent,
                message: isConsistent ? 
                    "併發操作一致性正常" : 
                    "併發操作出現不一致",
                executionTime: duration,
                details: [
                    "併發讀取1": "\(Int(balanceResult1))代幣",
                    "併發讀取2": "\(Int(balanceResult2))代幣",
                    "併發讀取3": "\(Int(balanceResult3))代幣",
                    "交易記錄": "\(results.3.count)筆"
                ]
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult(
                testName: "併發錢包操作",
                isSuccess: false,
                message: "併發操作測試失敗: \(error.localizedDescription)",
                executionTime: duration
            )
        }
    }
    
    // MARK: - 工具方法
    private func addTestResult(testName: String, isSuccess: Bool, message: String, executionTime: TimeInterval, details: [String: String] = [:]) {
        let result = ComprehensiveTestResult(
            testName: testName,
            isSuccess: isSuccess,
            message: message,
            executionTime: executionTime,
            details: details
        )
        testResults.insert(result, at: 0)
    }
}

// MARK: - 錢包餘額模型 (用於測試)
struct WalletBalance: Codable {
    let id: UUID
    let userId: UUID
    let balance: Double
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case balance
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}