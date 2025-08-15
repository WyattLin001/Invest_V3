//
//  TournamentStatusIndicatorView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽狀態指示器視圖 - 顯示錦標賽狀態和時間信息
//

import SwiftUI

// MARK: - 錦標賽狀態指示器
struct TournamentStatusIndicatorView: View {
    let tournament: Tournament
    @State private var currentTime = Date()
    
    // 定時更新當前時間
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            statusBadge
            timeDisplay
            transitionAlert
        }
        .onReceive(timer) { time in
            currentTime = time
        }
        .animation(.easeInOut(duration: 0.3), value: tournament.computedStatusUTC)
    }
    
    // MARK: - 狀態徽章
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(computedStatus.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                
                if let subtitle = statusSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if tournament.isAtTransitionPoint {
                transitionIndicator
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(statusColor)
            .frame(width: 24, height: 24)
    }
    
    private var transitionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .scaleEffect(1.5)
                .opacity(0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: currentTime)
            
            Text("狀態轉換中")
                .font(.caption2)
                .foregroundColor(.orange)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - 時間顯示
    
    private var timeDisplay: some View {
        HStack(spacing: 16) {
            timeInfoBlock(
                title: timeDisplayTitle,
                time: preciseTimeRemaining,
                subtitle: timeDisplaySubtitle
            )
            
            if shouldShowDuration {
                Divider()
                    .frame(height: 40)
                
                timeInfoBlock(
                    title: "持續時間",
                    time: tournament.startDate.durationString(to: tournament.endDate),
                    subtitle: "總長度"
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.05))
        )
    }
    
    private func timeInfoBlock(title: String, time: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text(time)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 轉換提醒
    
    @ViewBuilder
    private var transitionAlert: some View {
        if let reminder = tournament.transitionReminder {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text(reminder)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - 計算屬性
    
    private var computedStatus: TournamentStatus {
        return tournament.computedStatusUTC
    }
    
    private var statusColor: Color {
        return computedStatus.color
    }
    
    private var statusIconName: String {
        switch computedStatus {
        case .upcoming:
            return "clock"
        case .enrolling:
            return "person.badge.plus"
        case .ongoing, .active:
            return "play.circle.fill"
        case .finished, .ended:
            return "flag.checkered"
        case .settling:
            return "clock.badge.checkmark"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    private var statusSubtitle: String? {
        switch computedStatus {
        case .upcoming:
            return "即將開放報名"
        case .enrolling:
            return "現在可以報名"
        case .ongoing, .active:
            return "比賽進行中"
        case .finished, .ended:
            return "查看結果"
        case .settling:
            return "結算中"
        case .cancelled:
            return "比賽已取消"
        }
    }
    
    private var timeDisplayTitle: String {
        switch computedStatus {
        case .upcoming, .enrolling:
            return "距離開始"
        case .ongoing, .active:
            return "距離結束"
        case .finished, .ended, .settling, .cancelled:
            return "已結束"
        }
    }
    
    private var timeDisplaySubtitle: String {
        switch computedStatus {
        case .upcoming, .enrolling:
            return "開始時間"
        case .ongoing, .active:
            return "結束時間"
        case .finished, .ended, .settling, .cancelled:
            return "最終狀態"
        }
    }
    
    private var preciseTimeRemaining: String {
        switch computedStatus {
        case .finished, .ended, .settling, .cancelled:
            return "已完成"
        default:
            return tournament.preciseTimeRemaining
        }
    }
    
    private var shouldShowDuration: Bool {
        return computedStatus != .finished && computedStatus != .cancelled
    }
}

// MARK: - 精簡版狀態指示器
struct CompactTournamentStatusView: View {
    let tournament: Tournament
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            // 狀態點
            Circle()
                .fill(tournament.computedStatusUTC.color)
                .frame(width: 8, height: 8)
            
            // 狀態文字
            Text(tournament.computedStatusUTC.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(tournament.computedStatusUTC.color)
            
            Spacer()
            
            // 時間倒計時
            if tournament.computedStatusUTC != .finished && tournament.computedStatusUTC != .cancelled {
                Text(tournament.preciseTimeRemaining)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // 轉換指示器
            if tournament.isAtTransitionPoint {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .scaleEffect(1.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: currentTime)
            }
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }
}

// MARK: - 狀態進度條
struct TournamentProgressView: View {
    let tournament: Tournament
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("比賽進度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progressPercentage * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            HStack {
                Text(tournament.startDate.tournamentDateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(tournament.endDate.tournamentDateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var progressPercentage: Double {
        let now = Date().toUTC()
        let start = tournament.startDateUTC
        let end = tournament.endDateUTC
        
        if now < start {
            return 0.0
        } else if now > end {
            return 1.0
        } else {
            let totalDuration = end.timeIntervalSince(start)
            let elapsed = now.timeIntervalSince(start)
            return max(0, min(1, elapsed / totalDuration))
        }
    }
    
    private var progressColor: Color {
        if progressPercentage < 0.3 {
            return .green
        } else if progressPercentage < 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview
#Preview("狀態指示器") {
    VStack(spacing: 16) {
        // 完整版指示器
        TournamentStatusIndicatorView(tournament: mockTournament())
        
        Divider()
        
        // 精簡版指示器
        CompactTournamentStatusView(tournament: mockTournament())
        
        Divider()
        
        // 進度條
        TournamentProgressView(tournament: mockTournament())
    }
    .padding()
}

// Mock 錦標賽用於預覽
private func mockTournament() -> Tournament {
    Tournament(
        id: UUID(),
        name: "月度投資大賽",
        type: .monthly,
        status: .ongoing,
        startDate: Date().addingTimeInterval(-86400 * 7), // 7天前開始
        endDate: Date().addingTimeInterval(86400 * 7),    // 7天後結束
        description: "測試錦標賽",
        shortDescription: "測試",
        initialBalance: 1000000,
        entryFee: 0,
        prizePool: 100000,
        maxParticipants: 1000,
        currentParticipants: 500,
        isFeatured: true,
        createdBy: UUID(),
        riskLimitPercentage: 15,
        minHoldingRate: 0.1,
        maxSingleStockRate: 0.3,
        rules: [],
        createdAt: Date(),
        updatedAt: Date()
    )
}