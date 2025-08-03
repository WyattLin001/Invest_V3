//
//  ComprehensiveAppTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/4.
//  全面應用功能測試 - 包含錢包、聊天、首頁及 Supabase 整合測試
//

import SwiftUI

struct ComprehensiveAppTestView: View {
    @StateObject private var testManager = ComprehensiveTestManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 測試概覽卡片
                    testOverviewCard
                    
                    // 快速測試按鈕
                    quickTestSection
                    
                    // 詳細測試分類
                    testCategoriesSection
                    
                    // 測試結果顯示
                    if !testManager.testResults.isEmpty {
                        testResultsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("全面應用測試")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 測試概覽
    private var testOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("應用健康檢查")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 整體狀態指示器
                Circle()
                    .fill(testManager.overallStatus.color)
                    .frame(width: 12, height: 12)
            }
            
            Text("檢測 HomeView、ChatView、WalletView 及 Supabase 整合")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 進度條
            if testManager.isRunningAnyTest {
                ProgressView(value: testManager.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 快速測試區域
    private var quickTestSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("快速測試")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // 全面測試按鈕
                TestActionButton(
                    title: "全面測試",
                    subtitle: "所有功能",
                    icon: "play.circle.fill",
                    color: .blue,
                    isLoading: testManager.isRunningComprehensiveTest
                ) {
                    Task {
                        await testManager.runComprehensiveTest()
                    }
                }
                
                // Supabase 專項測試
                TestActionButton(
                    title: "Supabase 測試",
                    subtitle: "資料庫整合",
                    icon: "server.rack",
                    color: .purple,
                    isLoading: testManager.isRunningSupabaseTest
                ) {
                    Task {
                        await testManager.runSupabaseIntegrationTest()
                    }
                }
                
                // 錢包專項測試
                TestActionButton(
                    title: "錢包測試",
                    subtitle: "代幣與交易",
                    icon: "creditcard.fill",
                    color: .green,
                    isLoading: testManager.isRunningWalletTest
                ) {
                    Task {
                        await testManager.runWalletTest()
                    }
                }
                
                // 壓力測試
                TestActionButton(
                    title: "壓力測試",
                    subtitle: "併發與穩定性",
                    icon: "speedometer",
                    color: .orange,
                    isLoading: testManager.isRunningStressTest
                ) {
                    Task {
                        await testManager.runStressTest()
                    }
                }
            }
        }
    }
    
    // MARK: - 測試分類區域
    private var testCategoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("詳細測試分類")
                    .font(.headline)
                Spacer()
            }
            
            // 錢包功能測試
            TestCategoryCard(
                title: "錢包功能測試",
                description: "代幣餘額、加值、交易記錄、跨View同步",
                status: testManager.walletTestStatus,
                details: testManager.walletTestDetails
            ) {
                Task {
                    await testManager.runWalletTest()
                }
            }
            
            // ChatView 測試
            TestCategoryCard(
                title: "聊天功能測試", 
                description: "群組聊天、即時訊息、代幣扣款",
                status: testManager.chatTestStatus,
                details: testManager.chatTestDetails
            ) {
                Task {
                    await testManager.runChatTest()
                }
            }
            
            // HomeView 測試
            TestCategoryCard(
                title: "首頁功能測試",
                description: "文章顯示、導航、代幣顯示同步",
                status: testManager.homeTestStatus,
                details: testManager.homeTestDetails
            ) {
                Task {
                    await testManager.runHomeViewTest()
                }
            }
            
            // 業務邏輯測試
            TestCategoryCard(
                title: "業務邏輯測試",
                description: "餘額不足處理、撤銷機制、加值引導",
                status: testManager.businessLogicTestStatus,
                details: testManager.businessLogicTestDetails
            ) {
                Task {
                    await testManager.runBusinessLogicTest()
                }
            }
        }
    }
    
    // MARK: - 測試結果區域
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("測試結果")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    testManager.clearResults()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(testManager.testResults.prefix(20), id: \.id) { result in
                    ComprehensiveTestResultRow(result: result)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 測試動作按鈕
struct TestActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 80)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - 測試分類卡片
struct TestCategoryCard: View {
    let title: String
    let description: String
    let status: TestStatus
    let details: [String: String]
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 狀態指示器
                HStack(spacing: 8) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    
                    Text(status.displayText)
                        .font(.caption)
                        .foregroundColor(status.color)
                }
            }
            
            // 詳細信息
            if !details.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(Array(details.keys.sorted().prefix(4)), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(details[key] ?? "")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            
            // 測試按鈕
            Button(action: action) {
                Text("執行測試")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - 測試結果行
struct ComprehensiveTestResultRow: View {
    let result: ComprehensiveTestResult
    
    var body: some View {
        HStack(spacing: 12) {
            // 狀態圖標
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.isSuccess ? .green : .red)
                .font(.caption)
            
            // 測試信息
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(result.message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 執行時間
            Text(String(format: "%.2fs", result.executionTime))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - 預覽
struct ComprehensiveAppTestView_Previews: PreviewProvider {
    static var previews: some View {
        ComprehensiveAppTestView()
    }
}