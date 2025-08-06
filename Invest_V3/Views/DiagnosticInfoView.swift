//
//  DiagnosticInfoView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/6.
//  推播通知系統診斷信息界面
//

import SwiftUI

struct DiagnosticInfoView: View {
    let diagnosticInfo: [String: Any]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 系統狀態概覽
                    systemOverviewSection
                    
                    // 權限設定詳情
                    permissionsSection
                    
                    // 推播環境配置
                    environmentSection
                    
                    // 後端連接狀態
                    backendSection
                    
                    // 用戶偏好概覽
                    if let userPreferences = diagnosticInfo["userPreferences"] as? [String: Any] {
                        preferencesSection(userPreferences)
                    }
                    
                    // 分析數據概覽
                    if let analytics = diagnosticInfo["analytics"] as? [String: Any] {
                        analyticsSection(analytics)
                    }
                    
                    // 原始數據
                    rawDataSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("系統診斷")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var systemOverviewSection: some View {
        DiagnosticSection(title: "系統狀態", icon: "stethoscope") {
            VStack(spacing: 8) {
                DiagnosticRow(
                    title: "推播權限",
                    value: (diagnosticInfo["isAuthorized"] as? Bool ?? false) ? "已授權" : "未授權",
                    status: diagnosticInfo["isAuthorized"] as? Bool ?? false ? .success : .error
                )
                
                DiagnosticRow(
                    title: "Device Token",
                    value: diagnosticInfo["deviceToken"] as? String ?? "未設置",
                    status: (diagnosticInfo["deviceToken"] as? String)?.isEmpty == false ? .success : .warning
                )
                
                DiagnosticRow(
                    title: "未讀通知",
                    value: "\(diagnosticInfo["unreadCount"] as? Int ?? 0)",
                    status: .info
                )
                
                DiagnosticRow(
                    title: "通知功能",
                    value: (diagnosticInfo["canSendNotifications"] as? Bool ?? false) ? "可用" : "不可用",
                    status: diagnosticInfo["canSendNotifications"] as? Bool ?? false ? .success : .error
                )
            }
        }
    }
    
    private var permissionsSection: some View {
        DiagnosticSection(title: "權限詳情", icon: "lock") {
            VStack(spacing: 8) {
                DiagnosticRow(
                    title: "授權狀態",
                    value: authorizationStatusText(diagnosticInfo["authorizationStatus"] as? Int ?? 0),
                    status: (diagnosticInfo["authorizationStatus"] as? Int ?? 0) == 2 ? .success : .error
                )
                
                DiagnosticRow(
                    title: "彈窗提醒",
                    value: notificationSettingText(diagnosticInfo["alertSetting"] as? Int ?? 0),
                    status: (diagnosticInfo["alertSetting"] as? Int ?? 0) == 2 ? .success : .warning
                )
                
                DiagnosticRow(
                    title: "聲音提醒",
                    value: notificationSettingText(diagnosticInfo["soundSetting"] as? Int ?? 0),
                    status: (diagnosticInfo["soundSetting"] as? Int ?? 0) == 2 ? .success : .warning
                )
                
                DiagnosticRow(
                    title: "角標提醒",
                    value: notificationSettingText(diagnosticInfo["badgeSetting"] as? Int ?? 0),
                    status: (diagnosticInfo["badgeSetting"] as? Int ?? 0) == 2 ? .success : .warning
                )
            }
        }
    }
    
    private var environmentSection: some View {
        DiagnosticSection(title: "推播環境", icon: "server.rack") {
            VStack(spacing: 8) {
                DiagnosticRow(
                    title: "當前環境",
                    value: diagnosticInfo["environment"] as? String ?? "未知",
                    status: .info
                )
                
                DiagnosticRow(
                    title: "APNs 伺服器",
                    value: diagnosticInfo["apnsServer"] as? String ?? "未設置",
                    status: .info
                )
                
                DiagnosticRow(
                    title: "Bundle ID",
                    value: diagnosticInfo["bundleId"] as? String ?? "未設置",
                    status: .info
                )
            }
        }
    }
    
    private var backendSection: some View {
        DiagnosticSection(title: "後端連接", icon: "network") {
            VStack(spacing: 8) {
                DiagnosticRow(
                    title: "連接狀態",
                    value: (diagnosticInfo["backendConnected"] as? Bool ?? false) ? "已連接" : "未連接",
                    status: diagnosticInfo["backendConnected"] as? Bool ?? false ? .success : .error
                )
            }
        }
    }
    
    private func preferencesSection(_ preferences: [String: Any]) -> some View {
        DiagnosticSection(title: "用戶偏好", icon: "slider.horizontal.3") {
            VStack(spacing: 8) {
                ForEach(preferences.keys.sorted(), id: \.self) { key in
                    DiagnosticRow(
                        title: key,
                        value: "\(preferences[key] ?? "N/A")",
                        status: .info
                    )
                }
            }
        }
    }
    
    private func analyticsSection(_ analytics: [String: Any]) -> some View {
        DiagnosticSection(title: "分析數據", icon: "chart.bar") {
            VStack(spacing: 8) {
                ForEach(analytics.keys.sorted(), id: \.self) { key in
                    DiagnosticRow(
                        title: key,
                        value: "\(analytics[key] ?? "N/A")",
                        status: .info
                    )
                }
            }
        }
    }
    
    private var rawDataSection: some View {
        DiagnosticSection(title: "原始數據", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(diagnosticInfo.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("\(diagnosticInfo[key] ?? "N/A")")
                            .font(.caption)
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func authorizationStatusText(_ status: Int) -> String {
        switch status {
        case 0: return "未請求"
        case 1: return "已拒絕"
        case 2: return "已授權"
        case 3: return "臨時授權"
        case 4: return "暫時授權"
        default: return "未知 (\(status))"
        }
    }
    
    private func notificationSettingText(_ setting: Int) -> String {
        switch setting {
        case 0: return "不支持"
        case 1: return "已禁用"
        case 2: return "已啟用"
        default: return "未知 (\(setting))"
        }
    }
}

// MARK: - Supporting Views

struct DiagnosticSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandGreen)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DiagnosticRow: View {
    let title: String
    let value: String
    let status: DiagnosticStatus
    
    enum DiagnosticStatus {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Preview

#Preview {
    DiagnosticInfoView(diagnosticInfo: [
        "isAuthorized": true,
        "deviceToken": "abc123def456",
        "unreadCount": 5,
        "canSendNotifications": true,
        "authorizationStatus": 2,
        "alertSetting": 2,
        "soundSetting": 2,
        "badgeSetting": 2,
        "environment": "開發環境",
        "apnsServer": "https://api.sandbox.push.apple.com",
        "bundleId": "com.yourcompany.invest-v3",
        "backendConnected": true
    ])
}