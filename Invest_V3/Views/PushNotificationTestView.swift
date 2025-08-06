//
//  PushNotificationTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/6.
//  推播通知測試和管理界面
//

import SwiftUI
import UserNotifications

struct PushNotificationTestView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var testResults: [TestResult] = []
    @State private var isRunningTests = false
    @State private var selectedTestType = TestType.localNotification
    @State private var diagnosticInfo: [String: Any] = [:]
    @State private var showingDiagnostics = false
    @State private var userPreferences: [String: Any] = [:]
    @State private var showingPreferences = false
    @State private var analytics: [String: Any] = [:]
    @State private var showingAnalytics = false
    
    // 測試類型枚舉
    enum TestType: String, CaseIterable {
        case localNotification = "本地通知"
        case remoteNotification = "遠程推播"
        case bulkNotification = "批量推播"
        case deviceTokenRegistration = "Device Token 註冊"
        case permissions = "權限檢查"
        case preferences = "用戶偏好"
        case analytics = "分析數據"
        case fullSystemTest = "完整系統測試"
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
            .navigationTitle("推播通知測試")
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
            .sheet(isPresented: $showingPreferences) {
                UserPreferencesView(preferences: $userPreferences) { newPreferences in
                    Task {
                        await updateUserPreferences(newPreferences)
                    }
                }
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView(analytics: analytics)
            }
            .onAppear {
                Task {
                    await refreshSystemStatus()
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.brandGreen)
                    .font(.title2)
                Text("推播通知狀態")
                    .font(.headline)
                Spacer()
                Image(systemName: notificationService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(notificationService.isAuthorized ? .green : .red)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(title: "推播權限", value: notificationService.isAuthorized ? "已授權" : "未授權")
                StatusRow(title: "Device Token", value: notificationService.deviceToken != nil ? "已設置" : "未設置")
                StatusRow(title: "未讀通知", value: "\(notificationService.unreadCount)")
                StatusRow(title: "推播環境", value: PushNotificationConfig.environment.displayName)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
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
                .background(isRunningTests ? Color.gray : Color.brandGreen)
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
                    title: "系統診斷",
                    icon: "stethoscope",
                    color: .blue
                ) {
                    Task {
                        await loadDiagnosticInfo()
                    }
                }
                
                ActionButton(
                    title: "用戶偏好",
                    icon: "slider.horizontal.3",
                    color: .orange
                ) {
                    Task {
                        await loadUserPreferences()
                    }
                }
                
                ActionButton(
                    title: "分析數據",
                    icon: "chart.bar.fill",
                    color: .purple
                ) {
                    Task {
                        await loadAnalytics()
                    }
                }
                
                ActionButton(
                    title: "請求權限",
                    icon: "lock.open",
                    color: .green
                ) {
                    Task {
                        await requestPermissions()
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
    
    private func refreshSystemStatus() async {
        await notificationService.checkAuthorizationStatus()
        await notificationService.loadUnreadCount()
    }
    
    private func runTest(type: TestType) async {
        await MainActor.run {
            isRunningTests = true
        }
        
        let startTime = Date()
        var success = false
        var message = ""
        var details: [String: Any] = [:]
        
        do {
            switch type {
            case .localNotification:
                await notificationService.sendLocalNotification(
                    title: "測試本地通知",
                    body: "這是一個測試本地通知 - \(Date().formatted(date: .omitted, time: .shortened))",
                    categoryIdentifier: "SYSTEM_ALERT",
                    userInfo: ["test": true],
                    delay: 1.0
                )
                success = true
                message = "本地通知已發送"
                
            case .remoteNotification:
                if let user = try? await SupabaseService.shared.client.auth.user() {
                    success = await notificationService.sendPushNotification(
                        to: user.id.uuidString,
                        title: "測試遠程推播",
                        body: "這是一個測試遠程推播通知 - \(Date().formatted(date: .omitted, time: .shortened))",
                        category: "SYSTEM_ALERT",
                        data: ["test": true]
                    )
                    message = success ? "遠程推播已發送" : "遠程推播發送失敗"
                } else {
                    message = "用戶未登入，無法發送遠程推播"
                }
                
            case .bulkNotification:
                if let user = try? await SupabaseService.shared.client.auth.user() {
                    success = await notificationService.sendBulkPushNotification(
                        to: [user.id.uuidString],
                        title: "測試批量推播",
                        body: "這是一個測試批量推播通知 - \(Date().formatted(date: .omitted, time: .shortened))",
                        category: "SYSTEM_ALERT",
                        data: ["bulk_test": true]
                    )
                    message = success ? "批量推播已發送" : "批量推播發送失敗"
                } else {
                    message = "用戶未登入，無法發送批量推播"
                }
                
            case .deviceTokenRegistration:
                if let token = notificationService.deviceToken {
                    await notificationService.setDeviceToken(Data(token.utf8))
                    success = true
                    message = "Device Token 重新註冊完成"
                } else {
                    message = "Device Token 未設置"
                }
                
            case .permissions:
                let settings = await notificationService.getNotificationSettings()
                success = settings.authorizationStatus == .authorized
                message = "權限狀態: \(settings.authorizationStatus == .authorized ? "已授權" : "未授權")"
                details = [
                    "authorizationStatus": settings.authorizationStatus.rawValue,
                    "alertSetting": settings.alertSetting.rawValue,
                    "soundSetting": settings.soundSetting.rawValue,
                    "badgeSetting": settings.badgeSetting.rawValue
                ]
                
            case .preferences:
                if let prefs = await notificationService.getUserPushPreferences() {
                    success = true
                    message = "用戶偏好已加載"
                    details = prefs
                } else {
                    message = "無法加載用戶偏好"
                }
                
            case .analytics:
                if let analyticsData = await notificationService.getNotificationAnalytics() {
                    success = true
                    message = "分析數據已加載"
                    details = analyticsData
                } else {
                    message = "無法加載分析數據"
                }
                
            case .fullSystemTest:
                await notificationService.testNotificationSystem()
                success = true
                message = "完整系統測試已完成"
                details = await notificationService.getDiagnosticInfo()
            }
            
        } catch {
            message = "測試失敗: \(error.localizedDescription)"
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
    
    private func loadDiagnosticInfo() async {
        diagnosticInfo = await notificationService.getDiagnosticInfo()
        await MainActor.run {
            showingDiagnostics = true
        }
    }
    
    private func loadUserPreferences() async {
        if let prefs = await notificationService.getUserPushPreferences() {
            await MainActor.run {
                userPreferences = prefs
                showingPreferences = true
            }
        }
    }
    
    private func loadAnalytics() async {
        if let analyticsData = await notificationService.getNotificationAnalytics() {
            await MainActor.run {
                analytics = analyticsData
                showingAnalytics = true
            }
        }
    }
    
    private func updateUserPreferences(_ newPreferences: [String: Any]) async {
        let success = await notificationService.updateUserPushPreferences(newPreferences)
        let result = TestResult(
            type: .preferences,
            success: success,
            message: success ? "用戶偏好已更新" : "用戶偏好更新失敗",
            timestamp: Date(),
            details: newPreferences
        )
        
        await MainActor.run {
            testResults.append(result)
            if success {
                userPreferences = newPreferences
            }
        }
    }
    
    private func requestPermissions() async {
        let granted = await notificationService.requestPermission()
        let result = TestResult(
            type: .permissions,
            success: granted,
            message: granted ? "推播權限已授權" : "推播權限被拒絕",
            timestamp: Date(),
            details: nil
        )
        
        await MainActor.run {
            testResults.append(result)
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
    let result: PushNotificationTestView.TestResult
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
                        .foregroundColor(.brandGreen)
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

// MARK: - Preview

#Preview {
    PushNotificationTestView()
}