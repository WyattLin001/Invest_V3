//
//  TournamentRankingsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  錦標賽排行榜與動態牆視圖

import SwiftUI

struct TournamentRankingsView: View {
    private let tournamentService = ServiceConfiguration.makeTournamentService()
    @State private var selectedSegment: RankingSegment = .rankings
    @State private var selectedTournament: Tournament?
    @State private var participants: [TournamentParticipant] = []
    @State private var activities: [TournamentActivity] = []
    @State private var tournaments: [Tournament] = []
    @State private var isRefreshing = false
    @State private var showingTournamentPicker = false
    @State private var showingError = false
    
    var body: some View {
        VStack {
            // 錦標賽選擇器
            tournamentPickerSection
            
            // 分段控制器
            segmentedControl
            
            // 內容區域
            TabView(selection: $selectedSegment) {
                // 排行榜
                rankingsContent
                    .tag(RankingSegment.rankings)
                
                // 動態牆
                activitiesContent
                    .tag(RankingSegment.activities)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .adaptiveBackground()
        .onAppear {
            Task {
                await loadInitialData()
            }
        }
        .sheet(isPresented: $showingTournamentPicker) {
            TournamentPickerSheet(
                tournaments: tournaments,
                selectedTournament: $selectedTournament
            )
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") { }
        } message: {
            Text("載入排行榜資料時發生錯誤，請稍後再試")
        }
        .onChange(of: selectedTournament) { _, newTournament in
            if let tournament = newTournament {
                Task {
                    await loadTournamentData(tournament.id)
                }
            }
        }
    }
    
    // MARK: - 錦標賽選擇器區域
    private var tournamentPickerSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            if let tournament = selectedTournament {
                Button(action: {
                    showingTournamentPicker = true
                }) {
                    HStack {
                        Image(systemName: tournament.type.iconName)
                            .foregroundColor(.brandGreen)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tournament.name)
                                .font(.headline)
                                .adaptiveTextColor()
                            
                            Text("\(tournament.currentParticipants) 參與者 • \(tournament.status.displayName)")
                                .font(.caption)
                                .adaptiveTextColor(primary: false)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.brandGreen)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.surfaceSecondary)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 分段控制器
    private var segmentedControl: some View {
        HStack {
            ForEach(RankingSegment.allCases, id: \.self) { segment in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = segment
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: segment.iconName)
                                .font(.caption)
                            Text(segment.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedSegment == segment ? .brandGreen : .gray600)
                        
                        Rectangle()
                            .fill(selectedSegment == segment ? Color.brandGreen : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color.surfacePrimary)
    }
    
    // MARK: - 排行榜內容
    private var rankingsContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                // 我的排名卡片
                if let myRank = participants.first {
                    myRankingCard(myRank)
                }
                
                // 排行榜列表
                ForEach(participants.indices, id: \.self) { index in
                    participantRankingCard(participants[index], rank: index + 1)
                }
            }
            .padding()
        }
        .refreshable {
            await refreshRankings()
        }
    }
    
    // MARK: - 動態牆內容
    private var activitiesContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                ForEach(activities, id: \.id) { activity in
                    activityCard(activity)
                }
                
                if activities.isEmpty {
                    emptyActivitiesView
                }
            }
            .padding()
        }
        .refreshable {
            await refreshActivities()
        }
    }
    
    // MARK: - 我的排名卡片
    private func myRankingCard(_ participant: TournamentParticipant) -> some View {
        HStack {
            // 排名
            VStack {
                Text("#\(participant.currentRank)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGreen)
                
                HStack(spacing: 2) {
                    Image(systemName: participant.rankChangeIcon)
                        .foregroundColor(participant.rankChangeColor)
                        .font(.caption2)
                    
                    Text("\(abs(participant.rankChange))")
                        .font(.caption2)
                        .foregroundColor(participant.rankChangeColor)
                }
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("我的排名")
                    .font(.headline)
                    .adaptiveTextColor()
                
                Text(String(format: "$%.0f", participant.virtualBalance))
                    .font(.title3)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                Text(String(format: "報酬率：%@%.2f%%", participant.returnRate >= 0 ? "+" : "", participant.returnRate * 100))
                    .font(.caption)
                    .foregroundColor(participant.returnRate >= 0 ? .success : .danger)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                performanceBadge(participant.performanceLevel)
                
                Text(String(format: "勝率 %.0f%%", participant.winRate * 100))
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.brandGreen.opacity(0.1), Color.brandGreen.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandGreen.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 參與者排名卡片
    private func participantRankingCard(_ participant: TournamentParticipant, rank: Int) -> some View {
        HStack {
            // 排名徽章
            rankBadge(rank)
            
            // 頭像
            Circle()
                .fill(Color.gray300)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(participant.userName.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .adaptiveTextColor()
                )
            
            // 用戶信息
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                HStack(spacing: 8) {
                    Text("\(participant.totalTrades) 交易")
                        .font(.caption2)
                        .adaptiveTextColor(primary: false)
                    
                    Text("•")
                        .font(.caption2)
                        .adaptiveTextColor(primary: false)
                    
                    Text(String(format: "勝率 %.0f%%", participant.winRate * 100))
                        .font(.caption2)
                        .adaptiveTextColor(primary: false)
                }
            }
            
            Spacer()
            
            // 績效信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.0f", participant.virtualBalance))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                HStack(spacing: 4) {
                    Image(systemName: participant.rankChangeIcon)
                        .foregroundColor(participant.rankChangeColor)
                        .font(.caption2)
                    
                    Text(String(format: "%@%.2f%%", participant.returnRate >= 0 ? "+" : "", participant.returnRate * 100))
                        .font(.caption)
                        .foregroundColor(participant.returnRate >= 0 ? .success : .danger)
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    }
    
    // MARK: - 活動卡片
    private func activityCard(_ activity: TournamentActivity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 活動圖標
            Image(systemName: activity.activityType.icon)
                .foregroundColor(activity.activityType.color)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(activity.activityType.color.opacity(0.1))
                .cornerRadius(16)
            
            // 活動內容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.userName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .adaptiveTextColor()
                    
                    Spacer()
                    
                    Text(formatTimestamp(activity.timestamp))
                        .font(.caption2)
                        .adaptiveTextColor(primary: false)
                }
                
                Text(activity.description)
                    .font(.subheadline)
                    .adaptiveTextColor(primary: false)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let amount = activity.amount, let symbol = activity.symbol {
                    HStack {
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.brandGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandGreen.opacity(0.1))
                            .cornerRadius(4)
                        
                        Text(String(format: "$%.0f", amount))
                            .font(.caption)
                            .fontWeight(.medium)
                            .adaptiveTextColor()
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    }
    
    // MARK: - 輔助視圖
    private func rankBadge(_ rank: Int) -> some View {
        ZStack {
            if rank <= 3 {
                // 前三名特殊徽章
                Circle()
                    .fill(rankColor(rank))
                    .frame(width: 32, height: 32)
                
                Image(systemName: rank == 1 ? "crown.fill" : "star.fill")
                    .foregroundColor(.white)
                    .font(.caption)
            } else {
                // 普通排名
                Circle()
                    .fill(Color.gray400)
                    .frame(width: 32, height: 32)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func performanceBadge(_ level: PerformanceLevel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.caption2)
            
            Text(level.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(level.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(level.color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var emptyActivitiesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.gray400)
            
            Text("暫無動態")
                .font(.headline)
                .adaptiveTextColor(primary: false)
            
            Text("當有參與者進行交易或排名變動時，動態將會出現在這裡")
                .font(.subheadline)
                .adaptiveTextColor(primary: false)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 輔助方法
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:
            return Color(hex: "#FFD700") // 金色
        case 2:
            return Color(hex: "#C0C0C0") // 銀色
        case 3:
            return Color(hex: "#CD7F32") // 銅色
        default:
            return Color.gray400
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(timestamp, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: timestamp))"
        } else if calendar.isDate(timestamp, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: timestamp))"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }
    
    // MARK: - 數據操作
    private func loadInitialData() async {
        do {
            tournaments = try await tournamentService.fetchTournaments()
            if selectedTournament == nil {
                selectedTournament = tournaments.first
            }
            
            if let tournament = selectedTournament {
                await loadTournamentData(tournament.id)
            }
        } catch {
            showingError = true
        }
    }
    
    private func loadTournamentData(_ tournamentId: UUID) async {
        do {
            async let participantsTask = tournamentService.fetchTournamentParticipants(tournamentId: tournamentId)
            async let activitiesTask = tournamentService.fetchTournamentActivities(tournamentId: tournamentId)
            
            participants = try await participantsTask
            activities = try await activitiesTask
        } catch {
            showingError = true
        }
    }
    
    private func refreshRankings() async {
        isRefreshing = true
        
        if let tournament = selectedTournament {
            do {
                participants = try await tournamentService.fetchTournamentParticipants(tournamentId: tournament.id)
            } catch {
                showingError = true
            }
        }
        
        isRefreshing = false
    }
    
    private func refreshActivities() async {
        isRefreshing = true
        
        if let tournament = selectedTournament {
            do {
                activities = try await tournamentService.fetchTournamentActivities(tournamentId: tournament.id)
            } catch {
                showingError = true
            }
        }
        
        isRefreshing = false
    }
}

// MARK: - 排名區段枚舉
enum RankingSegment: String, CaseIterable {
    case rankings = "rankings"
    case activities = "activities"
    
    var displayName: String {
        switch self {
        case .rankings:
            return "排行榜"
        case .activities:
            return "動態牆"
        }
    }
    
    var iconName: String {
        switch self {
        case .rankings:
            return "list.number"
        case .activities:
            return "clock.arrow.circlepath"
        }
    }
}

// MARK: - 錦標賽選擇器 Sheet
struct TournamentPickerSheet: View {
    let tournaments: [Tournament]
    @Binding var selectedTournament: Tournament?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tournaments, id: \.id) { tournament in
                    Button(action: {
                        selectedTournament = tournament
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: tournament.type.iconName)
                                .foregroundColor(.brandGreen)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tournament.name)
                                    .font(.headline)
                                    .adaptiveTextColor()
                                
                                Text("\(tournament.currentParticipants) 參與者 • \(tournament.status.displayName)")
                                    .font(.caption)
                                    .adaptiveTextColor(primary: false)
                            }
                            
                            Spacer()
                            
                            if selectedTournament?.id == tournament.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.brandGreen)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("選擇錦標賽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 預覽
#Preview {
    TournamentRankingsView()
        .environmentObject(ThemeManager.shared)
}