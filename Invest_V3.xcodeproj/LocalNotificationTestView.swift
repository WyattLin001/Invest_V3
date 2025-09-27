//
//  LocalNotificationTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/9/19.
//  本地通知測試界面 - 適用於個人開發者賬號
//

import SwiftUI
import UserNotifications

struct LocalNotificationTestView: View {
    @StateObject private var notificationService = LocalNotificationService.shared
    @State private var testResults: [TestResult] = []
    @State private var isRunningTests = false
    @State private var selectedTestType = TestType.localNotification
    @State private var diagnosticInfo: [String: Any] = [:]
    @State private var showingDiagnostics = false
    
    // 測試類型枚舉
    enum TestType: String, CaseIterable {
        case localNotification = "本地通知"
        case stockAlert = "股價提醒"
        case rankingUpdate = "排名更新"
        case systemAlert = "系統通知"
        case permissions = "權限檢查"
        case bulkTest = "批量測試"
        case diagnostics = "系統診斷"
    }
    
    // 測試結果結構
    struct TestResult: Identifiable {
        let id = UUID()
        let type: TestType
        let success: Bool
        let message: String
        let timestamp: Date
        let details: [String: Any]?
        
        var statusIcon: String {
            success ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        
        var statusColor: Color {
            success ? .green : .red
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 系統狀態卡片
                    systemStatusCard
                    
                    // 重要提醒卡片
                    importantNoticeCard
                    
                    // 測試控制區域
                    testControlSection
                    
                    // 快速操作按鈕
                    quickActionsSection
                    
                    // 測試結果列表
                    testResultsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("本地通知測試")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清除結果") {
                        testResults.removeAll()
                    }
                    .disabled(testResults.isEmpty)
                }
            }
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticInfoView(diagnosticInfo: diagnosticInfo)
            }
            .onAppear {
                refreshSystemStatus()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("本地通知狀態")
                    .font(.headline)
                Spacer()
                Image(systemName: notificationService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(notificationService.isAuthorized ? .green : .red)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(title: "通知權限", value: notificationService.isAuthorized ? "已授權" : "未授權")
                StatusRow(title: "未讀通知", value: "\(notificationService.unreadCount)")
                StatusRow(title: "通知類型", value: "僅本地通知")
                StatusRow(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "未知")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var importantNoticeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("重要提醒")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 個人開發者賬號不支援遠程推播通知")
                    .font(.caption)
                Text("• 此版本僅使用本地通知功能")
                    .font(.caption)
                Text("• 本地通知在應用程式關閉時仍可正常工作")
                    .font(.caption)
                Text("• 如需遠程推播，請升級為付費開發者賬號")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var testControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("測試選項")
                .font(.headline)
            
            Picker("選擇測試類型", selection: $selectedTestType) {
                ForEach(TestType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Button(action: {
                Task {
                    await runTest(type: selectedTestType)
                }
            }) {
                HStack {
                    if isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(isRunningTests ? "測試進行中..." : "運行測試")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRunningTests ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isRunningTests)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速操作")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActionButton(
                    title: "請求權限",
                    icon: "lock.open",
                    color: .green
                ) {
                    Task {
                        await requestPermissions()
                    }
                }
                
                ActionButton(
                    title: "系統診斷",
                    icon: "stethoscope",
                    color: .blue
                ) {
                    Task {
                        await loadDiagnosticInfo()
                    }
                }
                
                ActionButton(
                    title: "清除通知",
                    icon: "trash",
                    color: .red
                ) {
                    await notificationService.removeAllNotifications()
                    addTestResult(
                        type: .diagnostics,
                        success: true,
                        message: "所有通知已清除"
                    )
                }
                
                ActionButton(
                    title: "完整測試",
                    icon: "checkmark.circle",
                    color: .purple
                ) {
                    Task {
                        await runFullTest()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("測試結果")
                    .font(.headline)
                Spacer()
                if !testResults.isEmpty {
                    Text("\(testResults.count) 項結果")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if testResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("尚無測試結果")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(testResults.reversed()) { result in
                        TestResultRow(result: result)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func refreshSystemStatus() {
        notificationService.checkAuthorizationStatus()
        Task {
            await notificationService.loadUnreadCount()
        }
    }
    
    private func runTest(type: TestType) async {
        await MainActor.run {
            isRunningTests = true
        }
        
        let startTime = Date()
        var success = false
        var message = ""
        var details: [String: Any] = [:]
        
        switch type {
        case .localNotification:
            await notificationService.sendLocalNotification(
                title: "測試本地通知",
                body: "這是一個測試本地通知 - \(Date().formatted(date: .omitted, time: .shortened))",
                categoryIdentifier: "DEFAULT",
                userInfo: ["test": true],
                delay: 1.0
            )
            success = true
            message = "本地通知已發送"
            
        case .stockAlert:
            await notificationService.sendStockPriceAlert(
                stockSymbol: "AAPL",
                stockName: "蘋果公司",
                targetPrice: 150.0,
                currentPrice: 152.0,
                delay: 2.0
            )
            success = true
            message = "股價提醒已發送"
            
        case .rankingUpdate:
            await notificationService.sendRankingUpdate(
                newRank: 5,
                previousRank: 8,
                delay: 3.0
            )
            success = true
            message = "排名更新通知已發送"
            
        case .systemAlert:
            await notificationService.sendSystemAlert(
                title: "系統提醒",
                message: "這是一個系統測試提醒",
                alertType: "test",
                delay: 4.0
            )
            success = true
            message = "系統提醒已發送"
            
        case .permissions:
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            success = settings.authorizationStatus == .authorized
            message = "權限狀態: \(success ? "已授權" : "未授權")"
            details = [
                "authorizationStatus": settings.authorizationStatus.rawValue,
                "alertSetting": settings.alertSetting.rawValue,
                "soundSetting": settings.soundSetting.rawValue,
                "badgeSetting": settings.badgeSetting.rawValue
            ]
            
        case .bulkTest:
            // 發送多個測試通知
            await notificationService.sendLocalNotification(
                title: "批量測試 1",
                body: "第一個批量測試通知",
                delay: 1.0
            )
            await notificationService.sendLocalNotification(
                title: "批量測試 2", 
                body: "第二個批量測試通知",
                delay: 3.0
            )
            await notificationService.sendLocalNotification(
                title: "批量測試 3",
                body: "第三個批量測試通知",
                delay: 5.0
            )
            success = true
            message = "已發送 3 個批量測試通知"
            
        case .diagnostics:
            details = await notificationService.getDiagnosticInfo()
            success = true
            message = "系統診斷已完成"
        }
        
        let result = TestResult(
            type: type,
            success: success,
            message: message,
            timestamp: startTime,
            details: details.isEmpty ? nil : details
        )
        
        await MainActor.run {
            testResults.append(result)
            isRunningTests = false
        }
    }
    
    private func addTestResult(type: TestType, success: Bool, message: String, details: [String: Any]? = nil) {
        let result = TestResult(
            type: type,
            success: success,
            message: message,
            timestamp: Date(),
            details: details
        )
        testResults.append(result)
    }
    
    private func loadDiagnosticInfo() async {
        diagnosticInfo = await notificationService.getDiagnosticInfo()
        await MainActor.run {
            showingDiagnostics = true
        }
    }
    
    private func requestPermissions() async {
        let granted = await notificationService.requestPermission()
        await MainActor.run {
            addTestResult(
                type: .permissions,
                success: granted,
                message: granted ? "推播權限已授權" : "推播權限被拒絕"
            )
        }
    }
    
    private func runFullTest() async {
        await MainActor.run {
            isRunningTests = true
        }
        
        // 執行完整的系統測試
        await notificationService.testNotificationSystem()
        
        // 等待一下讓通知有時間處理
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // 檢查系統狀態
        let diagnostics = await notificationService.getDiagnosticInfo()
        let pendingNotifications = await notificationService.getPendingNotifications()
        
        await MainActor.run {
            addTestResult(
                type: .diagnostics,
                success: true,
                message: "完整系統測試已完成，發現 \(pendingNotifications.count) 個待發送通知",
                details: diagnostics
            )
            isRunningTests = false
        }
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 8)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
        }
    }
}

struct TestResultRow: View {
    let result: LocalNotificationTestView.TestResult
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.statusIcon)
                    .foregroundColor(result.statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if result.details != nil {
                        Button("詳情") {
                            showingDetails.toggle()
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            if showingDetails, let details = result.details {
                VStack(alignment: .leading, spacing: 4) {
                    Text("詳細信息:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    ForEach(details.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(details[key] ?? "N/A")")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct DiagnosticInfoView: View {
    let diagnosticInfo: [String: Any]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(diagnosticInfo.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(diagnosticInfo[key] ?? "N/A")")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("系統診斷")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    LocalNotificationTestView()
}