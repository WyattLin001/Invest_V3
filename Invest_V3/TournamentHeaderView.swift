//
//  TournamentHeaderView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  錦標賽Header組件 - 顯示當前參與錦標賽的資訊
//

import SwiftUI

// MARK: - 錦標賽Header視圖

/// 錦標賽Header視圖
/// 顯示當前參與錦標賽的關鍵資訊，包括名稱、參與人數、排名等
struct TournamentHeaderView: View {
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    @State private var isExpanded = false
    
    var body: some View {
        if let context = tournamentStateManager.currentTournamentContext {
            headerContent(for: context)
                .background(headerBackground)
                .overlay(headerBorder)
        }
    }
    
    // MARK: - Header Content
    
    private func headerContent(for context: TournamentContext) -> some View {
        VStack(spacing: 0) {
            // 主要資訊行
            mainInfoRow(for: context)
            
            // 展開的詳細資訊（可選）
            if isExpanded {
                detailedInfo(for: context)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Main Info Row
    
    private func mainInfoRow(for context: TournamentContext) -> some View {
        HStack(spacing: 12) {
            // 錦標賽圖標
            tournamentIcon(for: context.tournament)
            
            // 錦標賽資訊
            VStack(alignment: .leading, spacing: 2) {
                // 錦標賽名稱
                Text(context.tournament.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // 狀態和資訊
                HStack(spacing: 8) {
                    participantInfo(for: context.tournament)
                    
                    if let rank = context.currentRank {
                        rankInfo(rank: rank)
                    }
                }
            }
            
            Spacer()
            
            // 展開/收起指示器
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Tournament Icon
    
    private func tournamentIcon(for tournament: Tournament) -> some View {
        ZStack {
            Circle()
                .fill(tournamentTypeColor(for: tournament.type))
                .frame(width: 40, height: 40)
            
            Image(systemName: tournamentTypeIcon(for: tournament.type))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Participant Info
    
    private func participantInfo(for tournament: Tournament) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(tournament.currentParticipants)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.white.opacity(0.2))
        )
    }
    
    // MARK: - Rank Info
    
    private func rankInfo(rank: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: rank <= 3 ? "crown.fill" : "number")
                .font(.system(size: 10))
                .foregroundColor(rankColor(for: rank))
            
            Text("#\(rank)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(rankBackgroundColor(for: rank))
        )
    }
    
    // MARK: - Detailed Info
    
    private func detailedInfo(for context: TournamentContext) -> some View {
        VStack(spacing: 8) {
            Divider()
                .background(.white.opacity(0.3))
                .padding(.vertical, 4)
            
            HStack(spacing: 16) {
                // 投資組合價值
                if let portfolio = context.portfolio {
                    StatItem(
                        icon: "dollarsign.circle.fill",
                        title: "總價值",
                        value: formatCurrency(portfolio.totalValue),
                        color: .white
                    )
                }
                
                Spacer()
                
                // 績效表現
                if let performance = context.performance {
                    StatItem(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "回報率",
                        value: String(format: "%.2f%%", performance.totalReturn),
                        color: performance.totalReturn >= 0 ? .green : .red
                    )
                }
                
                Spacer()
                
                // 參與時間
                StatItem(
                    icon: "clock.fill",
                    title: "參與天數",
                    value: "\(daysSinceJoined(context.joinedAt))天",
                    color: .white
                )
            }
        }
    }
    
    // MARK: - Stat Item
    
    private struct StatItem: View {
        let icon: String
        let title: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
        }
    }
    
    // MARK: - Background and Border
    
    private var headerBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemTeal).opacity(0.8),
                Color(.systemBlue).opacity(0.9)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var headerBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // MARK: - Helper Methods
    
    private func tournamentTypeColor(for type: TournamentType) -> Color {
        switch type {
        case .daily: return .yellow
        case .weekly: return .green  
        case .monthly: return .blue
        case .quarterly: return .purple
        case .yearly: return .red
        case .special: return .pink
        }
    }
    
    private func tournamentTypeIcon(for type: TournamentType) -> String {
        switch type {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.circle.fill"
        case .monthly: return "calendar.badge.clock"
        case .quarterly: return "chart.line.uptrend.xyaxis"
        case .yearly: return "crown.fill"
        case .special: return "bolt.fill"
        }
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white
        }
    }
    
    private func rankBackgroundColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow.opacity(0.3)
        case 2: return .gray.opacity(0.3)
        case 3: return .orange.opacity(0.3)
        default: return .white.opacity(0.2)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "$%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "$%.1fK", amount / 1_000)
        } else {
            return String(format: "$%.0f", amount)
        }
    }
    
    private func daysSinceJoined(_ joinedDate: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: joinedDate, to: Date()).day ?? 0
        return max(days, 1) // 至少顯示1天
    }
}

// MARK: - 緊湊版Header

/// 緊湊版錦標賽Header（單行顯示）
struct CompactTournamentHeaderView: View {
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    
    var body: some View {
        if let context = tournamentStateManager.currentTournamentContext {
            HStack(spacing: 12) {
                // 錦標賽圖標（小）
                ZStack {
                    Circle()
                        .fill(tournamentTypeColor(for: context.tournament.type))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: tournamentTypeIcon(for: context.tournament.type))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // 錦標賽名稱
                Text(context.tournament.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // 排名（如果有）
                if let rank = context.currentRank {
                    Text("#\(rank)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(rankBackgroundColor(for: rank))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.1))
            )
        }
    }
    
    // MARK: - Helper Methods (重複使用)
    
    private func tournamentTypeColor(for type: TournamentType) -> Color {
        switch type {
        case .daily: return .yellow
        case .weekly: return .green  
        case .monthly: return .blue
        case .quarterly: return .purple
        case .yearly: return .red
        case .special: return .pink
        }
    }
    
    private func tournamentTypeIcon(for type: TournamentType) -> String {
        switch type {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.circle.fill"
        case .monthly: return "calendar.badge.clock"
        case .quarterly: return "chart.line.uptrend.xyaxis"
        case .yearly: return "crown.fill"
        case .special: return "bolt.fill"
        }
    }
    
    private func rankBackgroundColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow.opacity(0.8)
        case 2: return .gray.opacity(0.8)
        case 3: return .orange.opacity(0.8)
        default: return .blue.opacity(0.8)
        }
    }
}

// MARK: - Preview

#Preview("錦標賽Header") {
    VStack(spacing: 16) {
        TournamentHeaderView()
        
        CompactTournamentHeaderView()
        
        Spacer()
    }
    .padding()
    .background(Color(.systemBackground))
}