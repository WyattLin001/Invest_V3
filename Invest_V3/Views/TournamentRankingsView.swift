//
//  TournamentRankingsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  錦標賽排行榜與動態牆視圖

import SwiftUI

// MARK: - Data Models
struct TournamentStats {
    let totalParticipants: Int
    let averageReturn: Double
    let daysRemaining: Int
    let lastUpdated: Date
}

struct TournamentRankingsView: View {
    private let tournamentService = ServiceConfiguration.makeTournamentService()
    private let supabaseService = SupabaseService.shared
    @State private var selectedSegment: RankingSegment = .rankings
    @State private var selectedTournament: Tournament?
    @State private var participants: [TournamentParticipant] = []
    @State private var activities: [TournamentActivity] = []
    @State private var tournaments: [Tournament] = []
    @State private var isRefreshing = false
    @State private var showingTournamentPicker = false
    @State private var showingError = false
    @State private var tournamentStats: TournamentStats?
    
    // 模擬統計數據 - 當 Supabase 數據載入失敗時使用
    private var fallbackStats: TournamentStats {
        TournamentStats(
            totalParticipants: 1247,
            averageReturn: 0.156,
            daysRemaining: 18,
            lastUpdated: Date()
        )
    }
    
    // 格式化時間輔助函數
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
    
    // 模擬參與者數據
    private var mockParticipants: [MockParticipant] {
        [
            MockParticipant(
                code: "TR",
                name: "TradingMaster",
                badges: ["👑", "🏆", "⚡"],
                balance: "$1,450,000",
                returnRate: "+45.00%",
                dailyChange: "+1.75% 今日",
                trendIcon: "arrow.up",
                trendColor: .green,
                trendText: "+1",
                returnColor: .green
            ),
            MockParticipant(
                code: "ST",
                name: "StockWizard",
                badges: ["🥈", "📈"],
                balance: "$1,425,000",
                returnRate: "+42.50%",
                dailyChange: "-1.04% 今日",
                trendIcon: "arrow.down",
                trendColor: .red,
                trendText: "-1",
                returnColor: .green
            ),
            MockParticipant(
                code: "MA",
                name: "MarketSage",
                badges: ["🥉", "🎯"],
                balance: "$1,380,000",
                returnRate: "+38.00%",
                dailyChange: "+1.32% 今日",
                trendIcon: "arrow.up",
                trendColor: .green,
                trendText: "+1",
                returnColor: .green
            ),
            MockParticipant(
                code: "IN",
                name: "InvestorPro",
                badges: ["📊"],
                balance: "$1,350,000",
                returnRate: "+35.00%",
                dailyChange: "-0.59% 今日",
                trendIcon: "arrow.down",
                trendColor: .red,
                trendText: "-1",
                returnColor: .green
            ),
            MockParticipant(
                code: "YO",
                name: "You",
                badges: ["🌟"],
                balance: "$1,275,000",
                returnRate: "+27.50%",
                dailyChange: "+0.95% 今日",
                trendIcon: "minus",
                trendColor: .gray,
                trendText: "0",
                returnColor: .green
            )
        ]
    }
    
    var body: some View {
        VStack {
            // 統計橫幅
            HStack {
                // 參與者數量
                VStack(alignment: .center, spacing: 4) {
                    Text("\((tournamentStats ?? fallbackStats).totalParticipants)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("參與者")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 平均報酬
                VStack(alignment: .center, spacing: 4) {
                    Text(String(format: "+%.1f%%", (tournamentStats ?? fallbackStats).averageReturn * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("平均報酬")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 剩餘時間
                VStack(alignment: .center, spacing: 4) {
                    Text("\((tournamentStats ?? fallbackStats).daysRemaining) 天")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("剩餘時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 最後更新
                VStack(alignment: .center, spacing: 4) {
                    Text(formatTime((tournamentStats ?? fallbackStats).lastUpdated))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("最後更新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // 排行榜內容
            VStack(alignment: .leading, spacing: 16) {
                // 排行榜標題
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.orange)
                    Text("排行榜")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("查看全部") {
                        // TODO: 實現查看全部功能
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // 排行榜列表
                LazyVStack(spacing: 8) {
                    // 模擬排行榜數據
                    ForEach(mockParticipants.indices, id: \.self) { index in
                        modernRankingCard(mockParticipants[index], isCurrentUser: index == 4)
                    }
                }
                .padding(.horizontal)
            }
        }
        .adaptiveBackground()
        .onAppear {
            Task {
                await loadInitialData()
                await loadTournamentStatistics()
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
    
    // 現代化的排行榜卡片
    private func modernRankingCard(_ participant: MockParticipant, isCurrentUser: Bool = false) -> some View {
        HStack(spacing: 12) {
            // 排名變化指示器
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: participant.trendIcon)
                        .foregroundColor(participant.trendColor)
                        .font(.caption)
                    
                    Text(participant.trendText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(participant.trendColor)
                }
            }
            .frame(width: 40)
            
            // 用戶信息
            HStack(spacing: 8) {
                Text(participant.code)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(width: 30, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(participant.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // 成就徽章
                        ForEach(participant.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2)
                        }
                    }
                    
                    if isCurrentUser {
                        Text("你")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // 績效數據
            VStack(alignment: .trailing, spacing: 2) {
                Text(participant.balance)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(participant.returnRate)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(participant.returnColor)
                    
                    Text(participant.dailyChange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 1)
        )
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
    
    /// 從 Supabase 載入錦標賽統計數據
    private func loadTournamentStatistics() async {
        do {
            let statsResponse = try await supabaseService.fetchTournamentStatistics(
                tournamentId: selectedTournament?.id
            )
            
            await MainActor.run {
                self.tournamentStats = TournamentStats(
                    totalParticipants: statsResponse.totalParticipants,
                    averageReturn: statsResponse.averageReturn,
                    daysRemaining: statsResponse.daysRemaining,
                    lastUpdated: statsResponse.lastUpdated
                )
            }
            
            print("✅ [TournamentRankingsView] 成功載入錦標賽統計數據")
        } catch {
            print("❌ [TournamentRankingsView] 載入統計數據失敗: \(error.localizedDescription)")
            // 使用 fallback 數據，不顯示錯誤給用戶
        }
    }
    
    private func refreshRankings() async {
        isRefreshing = true
        
        if let tournament = selectedTournament {
            do {
                participants = try await tournamentService.fetchTournamentParticipants(tournamentId: tournament.id)
                await loadTournamentStatistics() // 同時更新統計數據
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

// MARK: - Mock Data Models
struct MockParticipant {
    let code: String
    let name: String
    let badges: [String]
    let balance: String
    let returnRate: String
    let dailyChange: String
    let trendIcon: String
    let trendColor: Color
    let trendText: String
    let returnColor: Color
}

// MARK: - 預覽
#Preview {
    TournamentRankingsView()
        .environmentObject(ThemeManager.shared)
}