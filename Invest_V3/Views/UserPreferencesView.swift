//
//  UserPreferencesView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/6.
//  用戶推播通知偏好設定界面
//

import SwiftUI

struct UserPreferencesView: View {
    @Binding var preferences: [String: Any]
    let onSave: ([String: Any]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var hostMessages = true
    @State private var stockAlerts = true
    @State private var rankingUpdates = true
    @State private var chatMessages = true
    @State private var investmentUpdates = true
    @State private var marketNews = true
    @State private var systemAlerts = true
    @State private var groupInvites = true
    @State private var tradingAlerts = true
    
    @State private var quietHoursEnabled = false
    @State private var quietStartTime = Date()
    @State private var quietEndTime = Date()
    @State private var weekendsOnly = false
    @State private var soundEnabled = true
    @State private var badgeEnabled = true
    @State private var alertStyle = AlertStyle.banner
    
    enum AlertStyle: String, CaseIterable {
        case banner = "banner"
        case alert = "alert"
        case none = "none"
        
        var displayName: String {
            switch self {
            case .banner: return "橫幅"
            case .alert: return "彈窗"
            case .none: return "無"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 通知類型設定
                    notificationTypesSection
                    
                    // 靜音時段設定
                    quietHoursSection
                    
                    // 顯示方式設定
                    displayOptionsSection
                    
                    // 高級設定
                    advancedOptionsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("推播偏好設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        savePreferences()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentPreferences()
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var notificationTypesSection: some View {
        PreferenceSection(title: "通知類型", icon: "bell") {
            VStack(spacing: 16) {
                PreferenceToggle(
                    title: "主持人訊息",
                    description: "來自投資主持人的訊息通知",
                    isOn: $hostMessages,
                    icon: "person.wave.2"
                )
                
                PreferenceToggle(
                    title: "股價提醒",
                    description: "股價到達設定目標時的提醒",
                    isOn: $stockAlerts,
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                PreferenceToggle(
                    title: "排名更新",
                    description: "投資排行榜變動通知",
                    isOn: $rankingUpdates,
                    icon: "trophy"
                )
                
                PreferenceToggle(
                    title: "聊天訊息",
                    description: "群組聊天和私人訊息",
                    isOn: $chatMessages,
                    icon: "message"
                )
                
                PreferenceToggle(
                    title: "投資更新",
                    description: "投資組合和績效更新",
                    isOn: $investmentUpdates,
                    icon: "chart.pie"
                )
                
                PreferenceToggle(
                    title: "市場新聞",
                    description: "重要市場新聞和公告",
                    isOn: $marketNews,
                    icon: "newspaper"
                )
                
                PreferenceToggle(
                    title: "系統通知",
                    description: "系統更新和重要公告",
                    isOn: $systemAlerts,
                    icon: "gear"
                )
                
                PreferenceToggle(
                    title: "群組邀請",
                    description: "加入投資群組的邀請",
                    isOn: $groupInvites,
                    icon: "person.2"
                )
                
                PreferenceToggle(
                    title: "交易提醒",
                    description: "交易機會和市場變動提醒",
                    isOn: $tradingAlerts,
                    icon: "dollarsign.circle"
                )
            }
        }
    }
    
    private var quietHoursSection: some View {
        PreferenceSection(title: "靜音時段", icon: "moon") {
            VStack(spacing: 16) {
                PreferenceToggle(
                    title: "啟用靜音時段",
                    description: "在指定時間內不接收推播通知",
                    isOn: $quietHoursEnabled,
                    icon: "moon.fill"
                )
                
                if quietHoursEnabled {
                    VStack(spacing: 12) {
                        HStack {
                            Text("開始時間")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            DatePicker("", selection: $quietStartTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("結束時間")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            DatePicker("", selection: $quietEndTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        
                        PreferenceToggle(
                            title: "僅週末靜音",
                            description: "靜音時段僅在週末生效",
                            isOn: $weekendsOnly,
                            icon: "calendar"
                        )
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var displayOptionsSection: some View {
        PreferenceSection(title: "顯示選項", icon: "display") {
            VStack(spacing: 16) {
                PreferenceToggle(
                    title: "聲音提醒",
                    description: "收到通知時播放提示音",
                    isOn: $soundEnabled,
                    icon: "speaker.2"
                )
                
                PreferenceToggle(
                    title: "角標提醒",
                    description: "在應用圖標上顯示未讀數量",
                    isOn: $badgeEnabled,
                    icon: "app.badge"
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "rectangle.stack")
                            .foregroundColor(.brandGreen)
                            .font(.title3)
                        Text("提醒樣式")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Picker("提醒樣式", selection: $alertStyle) {
                        ForEach(AlertStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("選擇通知在螢幕上的顯示方式")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        PreferenceSection(title: "高級設定", icon: "gearshape.2") {
            VStack(spacing: 16) {
                Button(action: {
                    resetToDefaults()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                        Text("重置為預設值")
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
                
                Button(action: {
                    exportPreferences()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("匯出設定")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadCurrentPreferences() {
        hostMessages = preferences["host_messages"] as? Bool ?? true
        stockAlerts = preferences["stock_alerts"] as? Bool ?? true
        rankingUpdates = preferences["ranking_updates"] as? Bool ?? true
        chatMessages = preferences["chat_messages"] as? Bool ?? true
        investmentUpdates = preferences["investment_updates"] as? Bool ?? true
        marketNews = preferences["market_news"] as? Bool ?? true
        systemAlerts = preferences["system_alerts"] as? Bool ?? true
        groupInvites = preferences["group_invites"] as? Bool ?? true
        tradingAlerts = preferences["trading_alerts"] as? Bool ?? true
        
        quietHoursEnabled = preferences["quiet_hours_enabled"] as? Bool ?? false
        soundEnabled = preferences["sound_enabled"] as? Bool ?? true
        badgeEnabled = preferences["badge_enabled"] as? Bool ?? true
        weekendsOnly = preferences["weekends_only"] as? Bool ?? false
        
        if let alertStyleString = preferences["alert_style"] as? String,
           let style = AlertStyle(rawValue: alertStyleString) {
            alertStyle = style
        }
        
        // 處理時間設定
        if let startTimeString = preferences["quiet_start_time"] as? String {
            quietStartTime = parseTimeString(startTimeString) ?? Date()
        }
        
        if let endTimeString = preferences["quiet_end_time"] as? String {
            quietEndTime = parseTimeString(endTimeString) ?? Date()
        }
    }
    
    private func savePreferences() {
        let newPreferences: [String: Any] = [
            "host_messages": hostMessages,
            "stock_alerts": stockAlerts,
            "ranking_updates": rankingUpdates,
            "chat_messages": chatMessages,
            "investment_updates": investmentUpdates,
            "market_news": marketNews,
            "system_alerts": systemAlerts,
            "group_invites": groupInvites,
            "trading_alerts": tradingAlerts,
            "quiet_hours_enabled": quietHoursEnabled,
            "quiet_start_time": formatTimeString(quietStartTime),
            "quiet_end_time": formatTimeString(quietEndTime),
            "weekends_only": weekendsOnly,
            "sound_enabled": soundEnabled,
            "badge_enabled": badgeEnabled,
            "alert_style": alertStyle.rawValue
        ]
        
        onSave(newPreferences)
        dismiss()
    }
    
    private func resetToDefaults() {
        hostMessages = true
        stockAlerts = true
        rankingUpdates = true
        chatMessages = true
        investmentUpdates = true
        marketNews = true
        systemAlerts = true
        groupInvites = true
        tradingAlerts = true
        
        quietHoursEnabled = false
        soundEnabled = true
        badgeEnabled = true
        weekendsOnly = false
        alertStyle = .banner
        
        let calendar = Calendar.current
        quietStartTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
        quietEndTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    private func exportPreferences() {
        // 創建用戶偏好設定的 JSON 導出
        let preferencesToExport: [String: Any] = [
            "通知設定": [
                "投資專家訊息": hostMessages,
                "股價提醒": stockAlerts,
                "排行榜更新": rankingUpdates,
                "聊天訊息": chatMessages,
                "投資更新": investmentUpdates,
                "市場新聞": marketNews,
                "系統警告": systemAlerts,
                "群組邀請": groupInvites,
                "交易提醒": tradingAlerts
            ],
            "顯示設定": [
                "靜音時段啟用": quietHoursEnabled,
                "靜音開始時間": formatTimeString(quietStartTime),
                "靜音結束時間": formatTimeString(quietEndTime),
                "僅週末": weekendsOnly,
                "聲音啟用": soundEnabled,
                "徽章啟用": badgeEnabled,
                "提醒樣式": alertStyle.displayName
            ],
            "匯出時間": ISO8601DateFormatter().string(from: Date()),
            "版本": "Invest_V3_1.0"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: preferencesToExport, options: .prettyPrinted)
            
            // 創建文件名稱
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "Invest_V3_偏好設定_\(formatter.string(from: Date())).json"
            
            // 使用 iOS 文件共享
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            
            // 在真實的 App 中，這裡會開啟分享面板
            print("📤 [UserPreferences] 偏好設定已匯出到: \(tempURL.path)")
            
            // 模擬成功提示
            DispatchQueue.main.async {
                // 這裡可以顯示成功提示或開啟分享面板
            }
            
        } catch {
            print("❌ [UserPreferences] 匯出偏好設定失敗: \(error)")
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.date(from: timeString)
    }
    
    private func formatTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct PreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

struct PreferenceToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandGreen)
                    .font(.title3)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            
            if isOn != (title == "主持人訊息") {
                Divider()
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UserPreferencesView(
        preferences: .constant([
            "host_messages": true,
            "stock_alerts": false,
            "sound_enabled": true
        ]),
        onSave: { _ in }
    )
}