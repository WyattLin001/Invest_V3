//
//  AnalyticsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/6.
//  推播通知分析數據界面
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    let analytics: [String: Any]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 概覽統計
                    overviewSection
                    
                    // 傳送率圖表
                    if let deliveryData = analytics["delivery_rate_data"] as? [[String: Any]] {
                        deliveryRateChart(deliveryData)
                    }
                    
                    // 開啟率圖表
                    if let openData = analytics["open_rate_data"] as? [[String: Any]] {
                        openRateChart(openData)
                    }
                    
                    // 通知類型分佈
                    if let typeData = analytics["notification_types"] as? [String: Int] {
                        notificationTypesSection(typeData)
                    }
                    
                    // 設備統計
                    if let deviceData = analytics["device_stats"] as? [String: Any] {
                        deviceStatsSection(deviceData)
                    }
                    
                    // 錯誤分析
                    if let errorData = analytics["error_stats"] as? [String: Any] {
                        errorStatsSection(errorData)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("推播分析")
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
    
    private var overviewSection: some View {
        AnalyticsSection(title: "總體統計", icon: "chart.bar.fill") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "總發送量",
                    value: "\(analytics["total_sent"] as? Int ?? 0)",
                    icon: "paperplane.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "成功傳送",
                    value: "\(analytics["total_delivered"] as? Int ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "已開啟",
                    value: "\(analytics["total_opened"] as? Int ?? 0)",
                    icon: "envelope.open.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "失敗數",
                    value: "\(analytics["total_failed"] as? Int ?? 0)",
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }
            
            // 成功率指標
            VStack(spacing: 12) {
                RateIndicator(
                    title: "傳送成功率",
                    rate: analytics["delivery_rate"] as? Double ?? 0.0,
                    color: .green
                )
                
                RateIndicator(
                    title: "開啟率",
                    rate: analytics["open_rate"] as? Double ?? 0.0,
                    color: .orange
                )
                
                RateIndicator(
                    title: "失敗率",
                    rate: analytics["failure_rate"] as? Double ?? 0.0,
                    color: .red
                )
            }
            .padding(.top, 16)
        }
    }
    
    private func deliveryRateChart(_ data: [[String: Any]]) -> some View {
        AnalyticsSection(title: "傳送率趨勢", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 12) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                            if let rate = item["rate"] as? Double,
                               let date = item["date"] as? String {
                                LineMark(
                                    x: .value("日期", date),
                                    y: .value("傳送率", rate * 100)
                                )
                                .foregroundStyle(.green)
                                .symbol(Circle())
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartYScale(domain: 0...100)
                } else {
                    // iOS 15 及以下的替代方案
                    SimpleLineChart(data: data, valueKey: "rate", color: .green)
                        .frame(height: 200)
                }
                
                Text("過去 7 天的推播傳送成功率變化")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func openRateChart(_ data: [[String: Any]]) -> some View {
        AnalyticsSection(title: "開啟率趨勢", icon: "envelope.open") {
            VStack(alignment: .leading, spacing: 12) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                            if let rate = item["rate"] as? Double,
                               let date = item["date"] as? String {
                                LineMark(
                                    x: .value("日期", date),
                                    y: .value("開啟率", rate * 100)
                                )
                                .foregroundStyle(.orange)
                                .symbol(Circle())
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartYScale(domain: 0...100)
                } else {
                    // iOS 15 及以下的替代方案
                    SimpleLineChart(data: data, valueKey: "rate", color: .orange)
                        .frame(height: 200)
                }
                
                Text("過去 7 天的推播開啟率變化")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func notificationTypesSection(_ typeData: [String: Int]) -> some View {
        AnalyticsSection(title: "通知類型分佈", icon: "chart.pie") {
            VStack(spacing: 12) {
                ForEach(typeData.keys.sorted(), id: \.self) { type in
                    if let count = typeData[type] {
                        NotificationTypeRow(
                            type: type,
                            count: count,
                            total: typeData.values.reduce(0, +)
                        )
                    }
                }
            }
        }
    }
    
    private func deviceStatsSection(_ deviceData: [String: Any]) -> some View {
        AnalyticsSection(title: "設備統計", icon: "iphone") {
            VStack(spacing: 12) {
                DeviceStatRow(
                    title: "iOS 設備",
                    count: deviceData["ios_devices"] as? Int ?? 0,
                    icon: "iphone"
                )
                
                DeviceStatRow(
                    title: "活躍設備",
                    count: deviceData["active_devices"] as? Int ?? 0,
                    icon: "checkmark.circle"
                )
                
                DeviceStatRow(
                    title: "離線設備",
                    count: deviceData["inactive_devices"] as? Int ?? 0,
                    icon: "xmark.circle"
                )
            }
        }
    }
    
    private func errorStatsSection(_ errorData: [String: Any]) -> some View {
        AnalyticsSection(title: "錯誤分析", icon: "exclamationmark.triangle") {
            VStack(spacing: 12) {
                ErrorStatRow(
                    title: "無效 Token",
                    count: errorData["invalid_token"] as? Int ?? 0,
                    description: "設備 Token 已失效"
                )
                
                ErrorStatRow(
                    title: "網路錯誤",
                    count: errorData["network_error"] as? Int ?? 0,
                    description: "網路連接問題"
                )
                
                ErrorStatRow(
                    title: "伺服器錯誤",
                    count: errorData["server_error"] as? Int ?? 0,
                    description: "APNs 伺服器錯誤"
                )
                
                ErrorStatRow(
                    title: "配額超限",
                    count: errorData["quota_exceeded"] as? Int ?? 0,
                    description: "推播配額已用盡"
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct AnalyticsSection<Content: View>: View {
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RateIndicator: View {
    let title: String
    let rate: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * rate, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.8), value: rate)
                }
            }
            .frame(height: 8)
        }
    }
}

struct NotificationTypeRow: View {
    let type: String
    let count: Int
    let total: Int
    
    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(notificationTypeDisplayName(type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGreen)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.brandGreen)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.8), value: percentage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func notificationTypeDisplayName(_ type: String) -> String {
        switch type {
        case "host_message": return "主持人訊息"
        case "stock_alert": return "股價提醒"
        case "ranking_update": return "排名更新"
        case "chat_message": return "聊天訊息"
        case "investment_update": return "投資更新"
        case "market_news": return "市場新聞"
        case "system_alert": return "系統通知"
        case "group_invite": return "群組邀請"
        case "trading_alert": return "交易提醒"
        default: return type.capitalized
        }
    }
}

struct DeviceStatRow: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.brandGreen)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.brandGreen)
        }
    }
}

struct ErrorStatRow: View {
    let title: String
    let count: Int
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// 簡單的線圖實現（適用於 iOS 15 及以下）
struct SimpleLineChart: View {
    let data: [[String: Any]]
    let valueKey: String
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(max(data.count - 1, 1))
                
                // 找到最大值以進行縮放
                let maxValue = data.compactMap { $0[valueKey] as? Double }.max() ?? 1.0
                
                for (index, item) in data.enumerated() {
                    if let value = item[valueKey] as? Double {
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(value / maxValue) * height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView(analytics: [
        "total_sent": 1000,
        "total_delivered": 950,
        "total_opened": 380,
        "total_failed": 50,
        "delivery_rate": 0.95,
        "open_rate": 0.40,
        "failure_rate": 0.05,
        "notification_types": [
            "host_message": 300,
            "stock_alert": 250,
            "ranking_update": 200,
            "chat_message": 150,
            "system_alert": 100
        ],
        "device_stats": [
            "ios_devices": 500,
            "active_devices": 450,
            "inactive_devices": 50
        ],
        "error_stats": [
            "invalid_token": 20,
            "network_error": 15,
            "server_error": 10,
            "quota_exceeded": 5
        ]
    ])
}