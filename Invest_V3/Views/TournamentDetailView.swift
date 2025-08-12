//
//  TournamentDetailView.swift
//  Invest_V3
//
//  錦標賽詳情視圖 - 顯示錦標賽完整資訊
//

import SwiftUI

struct TournamentDetailView: View {
    let tournament: Tournament
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 錦標賽基本資訊
                tournamentHeader
                
                // 錦標賽規則和設定
                tournamentRules
                
                // 參與者統計
                participantStats
                
                // 時間安排
                timeSchedule
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var tournamentHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("錦標賽概覽")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(tournament.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                statusBadge
                Spacer()
                participantsInfo
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(tournament.status.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var participantsInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(tournament.currentParticipants)/\(tournament.maxParticipants)")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("參與者")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var tournamentRules: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("規則設定")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ruleItem("初始資金", formatCurrency(tournament.entryCapital))
                ruleItem("入場費", tournament.feeTokens > 0 ? "\(tournament.feeTokens) 代幣" : "免費")
                ruleItem("績效指標", tournament.returnMetric.uppercased())
                ruleItem("重置模式", tournament.resetMode.capitalized)
            }
            
            if let rules = tournament.rules {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("詳細規則")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if rules.allowShortSelling {
                        ruleDetail("✅ 允許做空", "可以進行賣空操作")
                    } else {
                        ruleDetail("❌ 禁止做空", "僅允許買入操作")
                    }
                    
                    ruleDetail("📊 最大持股比例", "\(Int(rules.maxPositionSize * 100))%")
                    
                    if let riskLimits = rules.riskLimits {
                        ruleDetail("⚠️ 最大回撤", "\(Int(riskLimits.maxDrawdown * 100))%")
                        ruleDetail("📈 最大槓桿", "\(String(format: "%.1f", riskLimits.maxLeverage))x")
                        ruleDetail("🔄 每日交易限制", "\(riskLimits.maxDailyTrades) 筆")
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var participantStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("參與統計")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("總參與者")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(tournament.currentParticipants)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("可用名額")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(tournament.maxParticipants - tournament.currentParticipants)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 參與進度條
            ProgressView(value: Double(tournament.currentParticipants), total: Double(tournament.maxParticipants))
                .tint(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var timeSchedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("時間安排")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                timelineEvent("開始時間", tournament.startDate)
                timelineEvent("結束時間", tournament.endDate)
                timelineEvent("創建時間", tournament.createdAt)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Helper Views
    
    private func ruleItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func ruleDetail(_ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func timelineEvent(_ title: String, _ date: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formatDateTime(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatRelativeTime(date))
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch tournament.status {
        case .upcoming:
            return .blue
        case .active:
            return .green
        case .ended:
            return .gray
        case .cancelled:
            return .red
        case .settling:
            return .orange
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$\(amount)"
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)
        
        if interval > 0 {
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            
            if days > 0 {
                return "\(days)天後"
            } else if hours > 0 {
                return "\(hours)小時後"
            } else {
                return "即將開始"
            }
        } else {
            let pastInterval = abs(interval)
            let days = Int(pastInterval / 86400)
            let hours = Int((pastInterval.truncatingRemainder(dividingBy: 86400)) / 3600)
            
            if days > 0 {
                return "\(days)天前"
            } else if hours > 0 {
                return "\(hours)小時前"
            } else {
                return "剛剛"
            }
        }
    }
}

// MARK: - Preview

struct TournamentDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TournamentDetailView(
                tournament: Tournament(
                    id: UUID(),
                    name: "科技股挑戰賽",
                    description: "專注於科技股投資的競賽，展現您的科技股投資策略",
                    status: .active,
                    startDate: Date().addingTimeInterval(-86400),
                    endDate: Date().addingTimeInterval(86400 * 6),
                    entryCapital: 1000000,
                    maxParticipants: 100,
                    currentParticipants: 78,
                    feeTokens: 0,
                    returnMetric: "twr",
                    resetMode: "monthly",
                    createdAt: Date().addingTimeInterval(-86400 * 2),
                    rules: TournamentRules(
                        allowShortSelling: true,
                        maxPositionSize: 0.3,
                        allowedInstruments: ["stocks", "etfs"],
                        tradingHours: TradingHours(startTime: "09:00", endTime: "16:00", timeZone: "Asia/Taipei"),
                        riskLimits: RiskLimits(maxDrawdown: 0.2, maxLeverage: 2.0, maxDailyTrades: 50)
                    )
                )
            )
        }
    }
}