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
    
    // 分頁相關狀態
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    private let itemsPerPage = 10
    
    
    // 格式化時間輔助函數
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
    
    // 分頁相關計算屬性
    private var paginatedParticipants: [TournamentParticipant] {
        let endIndex = min((currentPage + 1) * itemsPerPage, participants.count)
        return Array(participants[0..<endIndex])
    }
    
    private var hasMorePages: Bool {
        let totalItems = participants.count
        let currentItems = (currentPage + 1) * itemsPerPage
        return currentItems < totalItems
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 統計信息橫幅作為第一項
                statisticsHeader
                
                // 排行榜區域
                VStack(alignment: .leading, spacing: 16) {
                    // 排行榜標題
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        Text("排行榜")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    // 排行榜列表
                    LazyVStack(spacing: 10) {
                        ForEach(paginatedParticipants.indices, id: \.self) { index in
                            participantRankingCard(paginatedParticipants[index], rank: index + 1)
                        }
                        
                        // 載入更多按鈕 - HIG 遵循設計
                        if hasMorePages {
                            Button(action: {
                                loadNextPage()
                            }) {
                                HStack(spacing: 8) {
                                    if isLoadingMore {
                                        ProgressView()
                                            .scaleEffect(0.9)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16))
                                    }
                                    Text(isLoadingMore ? "載入中..." : "載入更多")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44) // HIG 最小觸控目標
                                .padding(.horizontal, 16)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isLoadingMore)
                            .accessibilityLabel(isLoadingMore ? "正在載入更多排名" : "載入更多排名")
                            .accessibilityHint("載入下一頁排行榜數據")
                        }
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal)
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            Task { @MainActor in
                await loadInitialData()
                await loadTournamentStatistics()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TournamentContextChanged"))) { _ in
            print("🔄 [TournamentRankingsView] 錦標賽切換，重新載入排行榜")
            Task { @MainActor in
                await refreshData()
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
                Task { @MainActor in
                    await loadTournamentData(tournament.id)
                }
            }
        }
        .onAppear {
            // 初始化分頁狀態
            currentPage = 0
            isLoadingMore = false
        }
    }
    
    // 統計信息橫幅
    private var statisticsHeader: some View {
        guard let stats = tournamentStats else {
            return AnyView(EmptyView())
        }
        
        return AnyView(VStack(spacing: 16) {
            // 新增頂部導航和標題
            HStack {
                Text("排行榜")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showingTournamentPicker = true
                }) {
                    HStack(spacing: 6) {
                        Text(selectedTournament?.name ?? "無選擇錦標賽")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            HStack(spacing: 0) {
                // 參與者
                VStack(alignment: .center, spacing: 6) {
                    Text("參與者")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(stats.totalParticipants)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                // 分隔線
                Rectangle()
                    .fill(Color.gray300)
                    .frame(width: 1, height: 40)
                
                // 平均報酬率
                VStack(alignment: .center, spacing: 6) {
                    Text("平均報酬率")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", stats.averageReturn * 100))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.success)
                }
                .frame(maxWidth: .infinity)
                
                // 分隔線
                Rectangle()
                    .fill(Color.gray300)
                    .frame(width: 1, height: 40)
                
                // 剩餘天數
                VStack(alignment: .center, spacing: 6) {
                    Text("剩餘天數")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(stats.daysRemaining)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
            }
            
            // 最後更新時間
            HStack {
                Text("最後更新：\(formatTime(stats.lastUpdated))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfaceSecondary)
        ))
    }
    
    
    // 排名顏色
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:
            return Color(hex: "#FFD700") // 金色
        case 2:
            return Color(hex: "#C0C0C0") // 銀色
        case 3:
            return Color(hex: "#CD7F32") // 銅色
        default:
            return Color.brandGreen
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
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.9)
                            
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
        Button(action: {
            // 排名詳情動作
        }) {
            ZStack {
                if rank <= 3 {
                    // 前三名特殊徽章
                    Circle()
                        .fill(rankColor(rank))
                        .frame(width: 32, height: 32) // 視覺尺寸
                        .shadow(color: rankColor(rank).opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: rank == 1 ? "crown.fill" : "star.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                } else {
                    // 普通排名
                    Circle()
                        .fill(Color.gray400)
                        .frame(width: 32, height: 32) // 視覺尺寸
                        .shadow(color: Color.gray400.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("\(rank)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(width: 44, height: 44) // HIG 要求的最小觸控目標
        .contentShape(Rectangle()) // 確保整個區域可點擊
        .accessibilityLabel("排名第\(rank)名")
        .accessibilityHint("點擊查看用戶詳情")
        .accessibilityAddTraits(.isButton)
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
    @MainActor
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
            print("❌ [TournamentRankingsView] 載入錦標賽失敗: \(error.localizedDescription)")
            showingError = true
        }
    }
    
    @MainActor
    private func loadTournamentData(_ tournamentId: UUID) async {
        do {
            async let participantsTask = tournamentService.fetchTournamentParticipants(tournamentId: tournamentId)
            async let activitiesTask = tournamentService.fetchTournamentActivities(tournamentId: tournamentId)
            
            participants = try await participantsTask
            activities = try await activitiesTask
        } catch {
            print("❌ [TournamentRankingsView] 載入錦標賽數據失敗: \(error.localizedDescription)")
            showingError = true
        }
    }
    
    
    /// 從 Supabase 載入錦標賽統計數據
    @MainActor
    private func loadTournamentStatistics() async {
        do {
            let statsResponse = try await supabaseService.fetchTournamentStatistics(
                tournamentId: selectedTournament?.id
            )
            
            self.tournamentStats = TournamentStats(
                totalParticipants: statsResponse.totalParticipants,
                averageReturn: statsResponse.averageReturn,
                daysRemaining: statsResponse.daysRemaining,
                lastUpdated: statsResponse.lastUpdated
            )
            
            print("✅ [TournamentRankingsView] 成功載入錦標賽統計數據")
        } catch {
            print("❌ [TournamentRankingsView] 載入統計數據失敗: \(error.localizedDescription)")
        }
    }
    
    @MainActor
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
    
    @MainActor
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
    
    // 刷新數據
    @MainActor
    private func refreshData() async {
        await refreshRankings()
        await loadTournamentStatistics()
    }
    
    // 加載下一頁
    private func loadNextPage() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        
        // 模擬異步加載
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentPage += 1
            self.isLoadingMore = false
            print("📄 [TournamentRankingsView] 已加載第 \(self.currentPage + 1) 頁")
        }
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
    @EnvironmentObject private var tournamentStateManager: TournamentStateManager
    
    // 只顯示已報名的錦標賽
    private var enrolledTournaments: [Tournament] {
        return tournaments.filter { tournament in
            tournamentStateManager.enrolledTournaments.contains(tournament.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if enrolledTournaments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("尚未參加任何錦標賽")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("前往錦標賽頁面參加錦標賽")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(enrolledTournaments, id: \.id) { tournament in
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