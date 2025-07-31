//
//  TestSectionView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  測試區塊組件

import SwiftUI

// MARK: - 測試區塊視圖
struct TestSectionView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let tests: [TestItemModel]
    let testRunner: TournamentTestRunner
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 區塊標題
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    // 圖標和標題
                    HStack(spacing: 12) {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(accentColor)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 狀態指示器
                    HStack(spacing: 8) {
                        // 完成進度
                        let completedCount = tests.compactMap { testRunner.getTestResult(for: $0.title) }.count
                        let totalCount = tests.count
                        
                        if totalCount > 0 {
                            Text("\(completedCount)/\(totalCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Circle()
                                .fill(completedCount == totalCount ? .green : .orange)
                                .frame(width: 8, height: 8)
                        }
                        
                        // 展開/收起圖標
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            
            // 測試項目列表
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(tests) { test in
                        TestItemView(
                            test: test,
                            testRunner: testRunner,
                            accentColor: accentColor
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 測試項目視圖
struct TestItemView: View {
    let test: TestItemModel
    let testRunner: TournamentTestRunner
    let accentColor: Color
    
    @State private var isRunning = false
    
    var body: some View {
        HStack {
            // 測試圖標
            Image(systemName: test.iconName)
                .font(.title3)
                .foregroundColor(accentColor)
                .frame(width: 20, height: 20)
            
            // 測試信息
            VStack(alignment: .leading, spacing: 2) {
                Text(test.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(test.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 狀態和操作按鈕
            HStack(spacing: 8) {
                // 測試結果狀態
                if let result = testRunner.getTestResult(for: test.title) {
                    TestResultIndicator(result: result)
                }
                
                // 執行按鈕
                Button(action: {
                    Task {
                        isRunning = true
                        await test.action()
                        isRunning = false
                    }
                }) {
                    Group {
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundColor(accentColor)
                        }
                    }
                }
                .disabled(isRunning || testRunner.isRunning)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - 測試結果指示器
struct TestResultIndicator: View {
    let result: TestResult
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(result.isSuccess ? .green : .red)
            
            Text(result.executionTime, format: .number.precision(.fractionLength(2)))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("s")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 預覽
struct TestSectionView_Previews: PreviewProvider {
    static var previews: some View {
        TestSectionView(
            title: "第一層：基礎模型測試",
            subtitle: "驗證資料結構完整性和計算邏輯",
            iconName: "cube.fill",
            accentColor: .blue,
            tests: [
                TestItemModel(
                    title: "Tournament 模型驗證",
                    description: "測試錦標賽基本屬性和計算邏輯",
                    iconName: "trophy",
                    action: { /* 測試動作 */ }
                ),
                TestItemModel(
                    title: "TournamentParticipant 測試",
                    description: "驗證參賽者指標計算正確性",
                    iconName: "person.fill",
                    action: { /* 測試動作 */ }
                )
            ],
            testRunner: TournamentTestRunner()
        )
        .padding()
    }
}