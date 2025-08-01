//
//  TestResultsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  測試結果展示組件

import SwiftUI

// MARK: - 測試結果主視圖
struct TestResultsView: View {
    @ObservedObject var testRunner: TournamentTestRunner
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showExportSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 統計概覽
                statisticsOverview
                
                // 標籤選擇器
                tabSelector
                
                // 內容區域
                TabView(selection: $selectedTab) {
                    // 結果列表
                    resultsListView
                        .tag(0)
                    
                    // 詳細統計
                    detailedStatisticsView
                        .tag(1)
                    
                    // 執行時間分析
                    performanceAnalysisView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("測試結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("匯出JSON") {
                            exportResults(format: .json)
                        }
                        
                        Button("匯出文字報告") {
                            exportResults(format: .text)
                        }
                        
                        Button("複製到剪貼板") {
                            copyResultsToClipboard()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    // MARK: - 統計概覽
    private var statisticsOverview: some View {
        let statistics = testRunner.getTestStatistics()
        
        return VStack(spacing: 16) {
            // 成功率圓形進度條
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: statistics.successRate / 100)
                        .stroke(
                            statistics.successRate >= 80 ? .green : 
                            statistics.successRate >= 60 ? .orange : .red,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(Int(statistics.successRate))%")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("成功率")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 統計數據
                VStack(alignment: .trailing, spacing: 8) {
                    StatisticRow(title: "總測試", value: "\(statistics.totalTests)", color: .blue)
                    StatisticRow(title: "通過", value: "\(statistics.passedTests)", color: .green)
                    StatisticRow(title: "失敗", value: "\(statistics.failedTests)", color: .red)
                    StatisticRow(title: "總時間", value: String(format: "%.2fs", statistics.totalExecutionTime), color: .purple)
                }
            }
            
            // 覆蓋率進度條
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("測試覆蓋率")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(testRunner.coveragePercentage))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(testRunner.coveragePercentage >= 80 ? .green : .orange)
                }
                
                ProgressView(value: testRunner.coveragePercentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: testRunner.coveragePercentage >= 80 ? .green : .orange))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - 標籤選擇器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "測試結果", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "統計分析", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabButton(title: "效能分析", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - 結果列表視圖
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(testRunner.testResults) { result in
                    GeneralTestResultRow(result: result)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 詳細統計視圖
    private var detailedStatisticsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 按層級統計
                layerStatisticsView
                
                // 按狀態統計
                statusStatisticsView
                
                // 執行時間分布
                executionTimeDistributionView
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 效能分析視圖
    private var performanceAnalysisView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 最慢的測試
                slowestTestsView
                
                // 最快的測試
                fastestTestsView
                
                // 效能建議
                performanceRecommendationsView
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 層級統計視圖
    private var layerStatisticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按測試層級統計")
                .font(.headline)
                .fontWeight(.bold)
            
            let layerStats = calculateLayerStatistics()
            
            ForEach(layerStats, id: \.layer) { stat in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stat.layer)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(stat.passed)/\(stat.total) 通過")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(stat.successRate))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(stat.successRate >= 80 ? .green : .orange)
                        
                        Text(String(format: "%.2fs", stat.avgTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 狀態統計視圖
    private var statusStatisticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("測試狀態分布")
                .font(.headline)
                .fontWeight(.bold)
            
            let statistics = testRunner.getTestStatistics()
            
            HStack(spacing: 20) {
                StatusCard(
                    title: "通過",
                    count: statistics.passedTests,
                    color: .green,
                    percentage: statistics.totalTests > 0 ? 
                        Double(statistics.passedTests) / Double(statistics.totalTests) * 100 : 0
                )
                
                StatusCard(
                    title: "失敗",
                    count: statistics.failedTests,
                    color: .red,
                    percentage: statistics.totalTests > 0 ? 
                        Double(statistics.failedTests) / Double(statistics.totalTests) * 100 : 0
                )
            }
        }
    }
    
    // MARK: - 執行時間分布視圖
    private var executionTimeDistributionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("執行時間分布")
                .font(.headline)
                .fontWeight(.bold)
            
            let timeRanges = calculateTimeRanges()
            
            ForEach(timeRanges, id: \.range) { timeRange in
                HStack {
                    Text(timeRange.range)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(timeRange.count) 個測試")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: CGFloat(timeRange.count) * 10, height: 20)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 最慢測試視圖
    private var slowestTestsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("執行最慢的測試")
                .font(.headline)
                .fontWeight(.bold)
            
            let slowestTests = testRunner.testResults
                .sorted { $0.executionTime > $1.executionTime }
                .prefix(5)
            
            ForEach(Array(slowestTests), id: \.id) { result in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.testName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(result.isSuccess ? "✅ 通過" : "❌ 失敗")
                            .font(.caption)
                            .foregroundColor(result.isSuccess ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.3fs", result.executionTime))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 最快測試視圖
    private var fastestTestsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("執行最快的測試")
                .font(.headline)
                .fontWeight(.bold)
            
            let fastestTests = testRunner.testResults
                .sorted { $0.executionTime < $1.executionTime }
                .prefix(5)
            
            ForEach(Array(fastestTests), id: \.id) { result in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.testName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(result.isSuccess ? "✅ 通過" : "❌ 失敗")
                            .font(.caption)
                            .foregroundColor(result.isSuccess ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.3fs", result.executionTime))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 效能建議視圖
    private var performanceRecommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("效能優化建議")
                .font(.headline)
                .fontWeight(.bold)
            
            let recommendations = generatePerformanceRecommendations()
            
            ForEach(recommendations, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    Text(recommendation)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 輔助方法
    
    private func calculateLayerStatistics() -> [LayerStatistic] {
        let layers = ["基礎模型", "服務層", "業務邏輯", "整合測試", "UI互動"]
        
        return layers.map { layer in
            let layerResults = testRunner.testResults.filter { result in
                result.testName.contains(layer) ||
                (layer == "基礎模型" && (result.testName.contains("模型") || result.testName.contains("指標"))) ||
                (layer == "服務層" && (result.testName.contains("Service") || result.testName.contains("API") || result.testName.contains("整合"))) ||
                (layer == "業務邏輯" && (result.testName.contains("管理器") || result.testName.contains("排名") || result.testName.contains("風險"))) ||
                (layer == "整合測試" && (result.testName.contains("流程") || result.testName.contains("更新") || result.testName.contains("壓力"))) ||
                (layer == "UI互動" && (result.testName.contains("界面") || result.testName.contains("顯示") || result.testName.contains("組件")))
            }
            
            let total = layerResults.count
            let passed = layerResults.filter { $0.isSuccess }.count
            let successRate = total > 0 ? Double(passed) / Double(total) * 100 : 0
            let avgTime = total > 0 ? layerResults.reduce(0) { $0 + $1.executionTime } / Double(total) : 0
            
            return LayerStatistic(
                layer: layer,
                total: total,
                passed: passed,
                successRate: successRate,
                avgTime: avgTime
            )
        }
    }
    
    private func calculateTimeRanges() -> [TimeRange] {
        let ranges = [
            ("< 0.1s", 0.0, 0.1),
            ("0.1s - 0.5s", 0.1, 0.5),
            ("0.5s - 1s", 0.5, 1.0),
            ("1s - 2s", 1.0, 2.0),
            ("> 2s", 2.0, Double.infinity)
        ]
        
        return ranges.map { range in
            let count = testRunner.testResults.filter { result in
                result.executionTime >= range.1 && result.executionTime < range.2
            }.count
            
            return TimeRange(range: range.0, count: count)
        }
    }
    
    private func generatePerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        let statistics = testRunner.getTestStatistics()
        
        if statistics.averageExecutionTime > 1.0 {
            recommendations.append("平均執行時間較長，建議優化測試邏輯或增加並行處理")
        }
        
        if statistics.failedTests > 0 {
            recommendations.append("有測試失敗，建議檢查失敗原因並修復相關問題")
        }
        
        if statistics.successRate < 80 {
            recommendations.append("成功率偏低，建議檢查測試設計和實現邏輯")
        }
        
        let slowTests = testRunner.testResults.filter { $0.executionTime > 2.0 }
        if !slowTests.isEmpty {
            recommendations.append("發現 \(slowTests.count) 個執行時間超過2秒的測試，建議優化")
        }
        
        if recommendations.isEmpty {
            recommendations.append("測試效能良好，無需特別優化")
        }
        
        return recommendations
    }
    
    private func exportResults(format: ExportFormat) {
        // 實現匯出邏輯
        print("匯出格式: \(format)")
    }
    
    private func copyResultsToClipboard() {
        // 實現複製到剪貼板邏輯
        print("已複製到剪貼板")
    }
}

// MARK: - 輔助組件

struct StatisticRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.clear)
                )
        }
    }
}

struct GeneralTestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            // 狀態圖標
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(result.isSuccess ? .green : .red)
            
            // 測試信息
            VStack(alignment: .leading, spacing: 4) {
                Text(result.testName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 執行時間
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.3fs", result.executionTime))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct StatusCard: View {
    let title: String
    let count: Int
    let color: Color
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("\(Int(percentage))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 資料模型

struct LayerStatistic {
    let layer: String
    let total: Int
    let passed: Int
    let successRate: Double
    let avgTime: Double
}

struct TimeRange {
    let range: String
    let count: Int
}

enum ExportFormat {
    case json, text
}

// MARK: - 預覽
struct TestResultsView_Previews: PreviewProvider {
    static var previews: some View {
        TestResultsView(testRunner: TournamentTestRunner())
    }
}