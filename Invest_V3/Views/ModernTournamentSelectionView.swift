//
//  ModernTournamentSelectionView.swift
//  Invest_V3
//
//  現代化錦標賽選擇視圖 - 整合新的工作流程服務和數據模型
//

import SwiftUI

struct ModernTournamentSelectionView: View {
    @Binding var selectedTournament: Tournament?
    @Binding var showingDetail: Bool
    
    // MARK: - 服務和狀態
    @StateObject private var workflowService: TournamentWorkflowService
    @State private var tournaments: [Tournament] = []
    @State private var selectedFilter: TournamentFilter = .active
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    // 視圖狀態
    @State private var showingCreateTournament: Bool = false
    @State private var showingJoinTournament: Bool = false
    @State private var selectedTournamentForJoin: Tournament?
    
    enum TournamentFilter: String, CaseIterable {
        case active = "進行中"
        case upcoming = "即將開始"
        case ended = "已結束"
        case joined = "我參加的"
        case created = "我創建的"
        
        var displayName: String { rawValue }
        
        var systemImage: String {
            switch self {
            case .active: return "play.circle.fill"
            case .upcoming: return "clock.circle.fill"
            case .ended: return "checkmark.circle.fill"
            case .joined: return "person.circle.fill"
            case .created: return "plus.circle.fill"
            }
        }
    }
    
    init(selectedTournament: Binding<Tournament?>, showingDetail: Binding<Bool>, workflowService: TournamentWorkflowService) {
        self._selectedTournament = selectedTournament
        self._showingDetail = showingDetail
        self._workflowService = StateObject(wrappedValue: workflowService)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                filterTabBar
                
                if isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationTitle("錦標賽")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    createTournamentButton
                }
            }
            .searchable(text: $searchText, prompt: "搜尋錦標賽")
        }
        .sheet(isPresented: $showingCreateTournament) {
            TournamentCreationView(workflowService: workflowService)
        }
        .sheet(isPresented: $showingJoinTournament) {
            if let tournament = selectedTournamentForJoin {
                TournamentJoinView(tournament: tournament, workflowService: workflowService)
            }
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadInitialData()
        }
        .refreshable {
            await refreshTournaments()
        }
        .onChange(of: selectedFilter) { _ in
            Task {
                await loadTournamentsForFilter()
            }
        }
        .onChange(of: workflowService.successMessage) { message in
            if message != nil {
                Task {
                    await refreshTournaments()
                }
            }
        }
    }
    
    // MARK: - 視圖組件
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("投資競技場")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("參與錦標賽，展現投資技巧")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                quickStatsView
            }
            
            featuredTournamentBanner
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var quickStatsView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("活躍錦標賽")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(activeTournamentsCount)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
    }
    
    private var featuredTournamentBanner: some View {
        Group {
            if let featured = featuredTournament {
                FeaturedTournamentCard(tournament: featured) {
                    selectTournament(featured)
                }
            } else {
                EmptyFeaturedCard()
            }
        }
    }
    
    private var filterTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TournamentFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: getTournamentCount(for: filter)
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("載入錦標賽...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredTournaments.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredTournaments) { tournament in
                        ModernTournamentCard(
                            tournament: tournament,
                            showJoinButton: !isUserParticipant(tournament),
                            onTournamentTap: {
                                selectTournament(tournament)
                            },
                            onJoinTap: {
                                selectedTournamentForJoin = tournament
                                showingJoinTournament = true
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if selectedFilter == .created {
                Button(action: {
                    showingCreateTournament = true
                }) {
                    Label("創建第一個錦標賽", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderedProminentButtonStyle())
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var createTournamentButton: some View {
        Button(action: {
            showingCreateTournament = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - 計算屬性
    
    private var filteredTournaments: [Tournament] {
        let filtered = tournaments.filter { tournament in
            switch selectedFilter {
            case .active:
                return tournament.status == .active
            case .upcoming:
                return tournament.status == .upcoming
            case .ended:
                return tournament.status == .ended
            case .joined:
                return isUserParticipant(tournament)
            case .created:
                return isUserCreated(tournament)
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { tournament in
                tournament.name.localizedCaseInsensitiveContains(searchText) ||
                tournament.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var activeTournamentsCount: Int {
        tournaments.filter { $0.status == .active }.count
    }
    
    private var featuredTournament: Tournament? {
        tournaments.first { $0.status == .active && $0.currentParticipants > 20 }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .active: return "play.circle"
        case .upcoming: return "clock.circle"
        case .ended: return "checkmark.circle"
        case .joined: return "person.circle"
        case .created: return "plus.circle"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .active: return "暫無進行中的錦標賽"
        case .upcoming: return "暫無即將開始的錦標賽"
        case .ended: return "暫無已結束的錦標賽"
        case .joined: return "您還沒有參加任何錦標賽"
        case .created: return "您還沒有創建任何錦標賽"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .active: return "請稍後再查看或創建新的錦標賽"
        case .upcoming: return "敬請期待即將開始的精彩競賽"
        case .ended: return "查看其他類別的錦標賽"
        case .joined: return "加入錦標賽開始您的投資競賽之旅"
        case .created: return "創建您的第一個錦標賽，邀請朋友一起競賽"
        }
    }
    
    // MARK: - 方法
    
    private func loadInitialData() async {
        isLoading = true
        await loadTournamentsForFilter()
        isLoading = false
    }
    
    private func loadTournamentsForFilter() async {
        // 模擬載入不同類別的錦標賽
        let sampleTournaments = generateSampleTournaments()
        
        await MainActor.run {
            tournaments = sampleTournaments
        }
    }
    
    private func refreshTournaments() async {
        await loadTournamentsForFilter()
    }
    
    private func selectTournament(_ tournament: Tournament) {
        selectedTournament = tournament
        showingDetail = true
    }
    
    private func getTournamentCount(for filter: TournamentFilter) -> Int {
        switch filter {
        case .active:
            return tournaments.filter { $0.status == .active }.count
        case .upcoming:
            return tournaments.filter { $0.status == .upcoming }.count
        case .ended:
            return tournaments.filter { $0.status == .ended }.count
        case .joined:
            return tournaments.filter { isUserParticipant($0) }.count
        case .created:
            return tournaments.filter { isUserCreated($0) }.count
        }
    }
    
    private func isUserParticipant(_ tournament: Tournament) -> Bool {
        // 簡化實現 - 實際應該檢查用戶是否為參與者
        return tournament.currentParticipants > 0 && Bool.random()
    }
    
    private func isUserCreated(_ tournament: Tournament) -> Bool {
        // 簡化實現 - 實際應該檢查錦標賽創建者
        return tournament.name.contains("我的") || Bool.random()
    }
    
    private func generateSampleTournaments() -> [Tournament] {
        let statuses: [TournamentStatus] = [.active, .upcoming, .ended, .active, .active]
        let names = ["科技股挑戰賽", "價值投資大賽", "新手友善賽", "高手進階賽", "我的專屬賽"]
        let descriptions = [
            "專注科技股的投資競賽",
            "長期價值投資策略比拼",
            "適合投資新手的友善競賽",
            "高手雲集的進階投資挑戰",
            "我創建的專屬投資競賽"
        ]
        
        return statuses.enumerated().map { index, status in
            Tournament(
                id: UUID(),
                name: names[index],
                description: descriptions[index],
                status: status,
                startDate: Date().addingTimeInterval(TimeInterval(index * 86400 - 172800)),
                endDate: Date().addingTimeInterval(TimeInterval(index * 86400 + 518400)),
                entryCapital: [1000000, 500000, 2000000, 300000, 1500000][index],
                maxParticipants: [100, 50, 200, 30, 80][index],
                currentParticipants: [85, 35, 150, 28, 45][index],
                feeTokens: [0, 50, 0, 100, 0][index],
                returnMetric: "twr",
                resetMode: "monthly",
                createdAt: Date().addingTimeInterval(TimeInterval(-index * 172800)),
                rules: index == 0 ? [
                    "允許做空交易",
                    "單一持股上限：30%",
                    "允許投資：股票、ETF",
                    "交易時間：09:00 - 16:00 (台北時間)",
                    "最大回撤限制：20%",
                    "最大槓桿：2.0x",
                    "每日最大交易次數：50"
                ] : []
            )
        }
    }
}

// MARK: - 支援視圖組件

struct FilterTab: View {
    let filter: ModernTournamentSelectionView.TournamentFilter
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.caption)
                
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FeaturedTournamentCard: View {
    let tournament: Tournament
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("精選錦標賽")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text(tournament.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
                
                HStack {
                    featuredMetric("參與者", "\(tournament.currentParticipants)")
                    featuredMetric("獎金池", formatCurrency(Double(tournament.currentParticipants * tournament.feeTokens)))
                    featuredMetric("剩餘時間", timeRemaining)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func featuredMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var timeRemaining: String {
        let interval = tournament.endDate.timeIntervalSince(Date())
        let days = Int(interval / 86400)
        return days > 0 ? "\(days)天" : "即將結束"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000000 {
            return String(format: "%.1fM", amount / 1000000)
        } else if amount >= 1000 {
            return String(format: "%.0fK", amount / 1000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}

struct EmptyFeaturedCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("暫無精選錦標賽")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text("敬請期待精彩的錦標賽活動")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct ModernTournamentCard: View {
    let tournament: Tournament
    let showJoinButton: Bool
    let onTournamentTap: () -> Void
    let onJoinTap: () -> Void
    
    var body: some View {
        Button(action: onTournamentTap) {
            VStack(alignment: .leading, spacing: 16) {
                // 錦標賽標題和狀態
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tournament.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(tournament.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // 錦標賽詳情
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    cardMetric("參與者", "\(tournament.currentParticipants)/\(tournament.maxParticipants)")
                    cardMetric("初始資金", formatCurrency(tournament.entryCapital))
                    cardMetric("入場費", tournament.feeTokens > 0 ? "\(tournament.feeTokens)代幣" : "免費")
                }
                
                // 時間信息和操作按鈕
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(timeValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if showJoinButton && tournament.status.canJoin {
                        joinButton
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(tournament.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var joinButton: some View {
        Button(action: onJoinTap) {
            Text("加入")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func cardMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statusColor: Color {
        switch tournament.status {
        case .upcoming: return .blue
        case .enrolling: return .green
        case .ongoing: return .orange
        case .active: return .green
        case .finished: return .gray
        case .ended: return .gray
        case .cancelled: return .red
        case .settling: return .orange
        }
    }
    
    private var timeLabel: String {
        switch tournament.status {
        case .upcoming: return "開始時間"
        case .enrolling: return "報名中"
        case .ongoing: return "剩餘時間"
        case .active: return "剩餘時間"
        case .finished: return "結束時間"
        case .ended: return "結束時間"
        case .cancelled: return "取消時間"
        case .settling: return "結算中"
        }
    }
    
    private var timeValue: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        
        switch tournament.status {
        case .upcoming:
            return formatter.string(from: tournament.startDate)
        case .enrolling:
            return formatter.string(from: tournament.startDate)
        case .ongoing, .active:
            let interval = tournament.endDate.timeIntervalSince(Date())
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            return days > 0 ? "\(days)天\(hours)小時" : "\(hours)小時"
        case .finished, .ended, .cancelled:
            return formatter.string(from: tournament.endDate)
        case .settling:
            return "處理中..."
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000000 {
            return String(format: "%.0fM", amount / 1000000)
        } else if amount >= 1000 {
            return String(format: "%.0fK", amount / 1000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}

// MARK: - 預覽

struct ModernTournamentSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModernTournamentSelectionView(
            selectedTournament: .constant(nil),
            showingDetail: .constant(false),
            workflowService: TournamentWorkflowService(
                tournamentService: TournamentService(),
                tradeService: TournamentTradeService(),
                walletService: TournamentWalletService(),
                rankingService: TournamentRankingService(),
                businessService: TournamentBusinessService()
            )
        )
    }
}