//
//  TournamentCardView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  錦標賽卡片組件 - 顯示錦標賽詳細信息的專業卡片
//

import SwiftUI

// MARK: - 錦標賽卡片主組件

/// 錦標賽卡片視圖
/// 顯示錦標賽的所有關鍵信息，支持報名操作
struct TournamentCardView: View {
    let tournament: Tournament
    let onEnroll: (() -> Void)?
    let onViewDetails: (() -> Void)?
    
    @State private var isEnrolling = false
    
    init(
        tournament: Tournament,
        onEnroll: (() -> Void)? = nil,
        onViewDetails: (() -> Void)? = nil
    ) {
        self.tournament = tournament
        self.onEnroll = onEnroll
        self.onViewDetails = onViewDetails
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片頭部
            cardHeader
            
            // 卡片內容
            cardContent
            
            // 卡片底部操作
            cardActions
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.05))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }
    
    // MARK: - 卡片頭部
    
    private var cardHeader: some View {
        HStack {
            // 錦標賽類型標籤
            tournamentTypeLabel
            
            Spacer()
            
            // 狀態標籤
            statusLabel
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var tournamentTypeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: tournament.type.iconName)
                .font(.system(size: 12, weight: .medium))
            
            Text(tournament.type.displayName)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(typeColor)
        )
    }
    
    private var statusLabel: some View {
        Text(tournament.status.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(tournament.status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tournament.status.color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tournament.status.color.opacity(0.3), lineWidth: 0.5)
            )
    }
    
    // MARK: - 卡片內容
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 錦標賽標題
            tournamentTitle
            
            // 錦標賽描述
            if !tournament.shortDescription.isEmpty {
                tournamentDescription
            }
            
            // 統計信息
            statisticsSection
            
            // 時間信息
            timeSection
            
            // 起始資金
            startingCapitalSection
            
            // 比賽規則（簡要）
            if !tournament.rules.isEmpty {
                rulesSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private var tournamentTitle: some View {
        Text(tournament.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
    }
    
    private var tournamentDescription: some View {
        Text(tournament.shortDescription)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    private var statisticsSection: some View {
        HStack(spacing: 20) {
            // 參賽人數
            StatisticItem(
                icon: "person.2.fill",
                title: "參賽人數",
                value: "\(tournament.currentParticipants) / \(tournament.maxParticipants)",
                color: .blue
            )
            
            // 獎金池
            StatisticItem(
                icon: "dollarsign.circle.fill",
                title: "獎金池",
                value: formatPrizePool(tournament.prizePool),
                color: .green
            )
        }
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("期間")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(formatDateRange(start: tournament.startDate, end: tournament.endDate))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    private var startingCapitalSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "banknote")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("起始資金：")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(formatCurrency(tournament.startingCapital))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("比賽規則")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(tournament.rules.prefix(3).enumerated()), id: \.offset) { _, rule in
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(rule)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if tournament.rules.count > 3 {
                    Text("及其他規則...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
    
    // MARK: - 卡片底部操作
    
    private var cardActions: some View {
        VStack(spacing: 8) {
            // 參賽進度條
            if tournament.status == .enrolling {
                participationProgressBar
            }
            
            // 操作按鈕
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 12)
    }
    
    private var participationProgressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("報名進度")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(participationPercentage))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            ProgressView(value: participationPercentage / 100.0)
                .tint(progressColor)
                .scaleEffect(y: 0.8)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 查看詳情按鈕
            if onViewDetails != nil {
                Button("查看詳情") {
                    onViewDetails?()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            // 主要操作按鈕
            mainActionButton
        }
    }
    
    @ViewBuilder
    private var mainActionButton: some View {
        switch tournament.status {
        case .enrolling:
            if tournament.currentParticipants < tournament.maxParticipants {
                Button(action: handleEnroll) {
                    HStack(spacing: 4) {
                        if isEnrolling {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        Text(isEnrolling ? "報名中..." : "立即報名")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isEnrolling)
            } else {
                Button("已額滿") { }
                    .buttonStyle(DisabledButtonStyle())
                    .disabled(true)
            }
            
        case .upcoming:
            Button("即將開始") { }
                .buttonStyle(InfoButtonStyle())
                .disabled(true)
            
        case .ongoing:
            NavigationLink(destination: TournamentTradingView()) {
                Text("參加錦標賽")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .simultaneousGesture(TapGesture().onEnded {
                Task {
                    await TournamentStateManager.shared.joinTournament(tournament)
                }
            })
            
        case .finished:
            Button("查看結果") {
                onViewDetails?()
            }
            .buttonStyle(SecondaryButtonStyle())
            
        case .cancelled:
            Button("已取消") { }
                .buttonStyle(DisabledButtonStyle())
                .disabled(true)
        }
    }
    
    // MARK: - 輔助方法
    
    private func handleEnroll() {
        guard !isEnrolling else { return }
        
        isEnrolling = true
        
        Task {
            await TournamentStateManager.shared.joinTournament(tournament)
            await MainActor.run {
                isEnrolling = false
                onEnroll?()
            }
        }
    }
    
    // MARK: - 計算屬性
    
    private var typeColor: Color {
        switch tournament.type {
        case .daily: return .yellow
        case .weekly: return .green  
        case .monthly: return .blue
        case .quarterly: return .purple
        case .yearly: return .red
        case .special: return .pink
        }
    }
    
    private var borderColor: Color {
        if tournament.status == .enrolling {
            return typeColor.opacity(0.3)
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        return tournament.status == .enrolling ? 1.0 : 0.5
    }
    
    private var participationPercentage: Double {
        guard tournament.maxParticipants > 0 else { return 0 }
        return min(100.0, Double(tournament.currentParticipants) / Double(tournament.maxParticipants) * 100.0)
    }
    
    private var progressColor: Color {
        let percentage = participationPercentage
        if percentage < 50 {
            return .green
        } else if percentage < 80 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - 格式化方法
    
    private func formatPrizePool(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "$%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "$%.0fK", amount / 1_000)
        } else {
            return String(format: "$%.0f", amount)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy-MM-dd"
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
}

// MARK: - 統計項目組件

private struct StatisticItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 按鈕樣式

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.green)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.green.opacity(0.1))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.green, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct InfoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
            )
    }
}

private struct DisabledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.1))
            )
    }
}

// MARK: - Preview

/*
#Preview("錦標賽卡片") {
    ScrollView {
        LazyVStack(spacing: 16) {
            // 報名中的錦標賽
            TournamentCardView(
                tournament: Tournament.mockEnrollingTournament,
                onEnroll: {
                    print("報名錦標賽")
                },
                onViewDetails: {
                    print("查看詳情")
                }
            )
            
            // 進行中的錦標賽
            TournamentCardView(
                tournament: Tournament.mockOngoingTournament,
                onViewDetails: {
                    print("參加錦標賽")
                }
            )
            
            // 已結束的錦標賽
            TournamentCardView(
                tournament: Tournament.mockFinishedTournament,
                onViewDetails: {
                    print("查看結果")
                }
            )
        }
        .padding()
    }
    .background(.gray.opacity(0.05))
}
*/

