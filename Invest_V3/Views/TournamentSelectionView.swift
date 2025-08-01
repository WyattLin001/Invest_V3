//
//  TournamentSelectionView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  錦標賽競技場主視圖 - 完整的錦標賽選擇與管理界面
//

import SwiftUI

// MARK: - 錦標賽選擇主視圖

/// 錦標賽選擇主視圖
/// 提供完整的錦標賽瀏覽、篩選和參與功能
struct TournamentSelectionView: View {
    @Binding var selectedTournament: Tournament?
    @Binding var showingDetail: Bool
    
    // 狀態管理
    @State private var selectedFilter: TournamentFilter = .featured
    @State private var tournaments: [Tournament] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // 服務依賴
    // private let tournamentService = ServiceConfiguration.makeTournamentService()
    
    var body: some View {
        VStack(spacing: 0) {
            // 錦標賽標籤導航
            TournamentTabBarContainer(selectedFilter: $selectedFilter)
            
            // 主要內容區域
            mainContent
        }
        .background(.gray.opacity(0.05))
        .onAppear {
            loadTournaments()
        }
        .onChange(of: selectedFilter) { _, newFilter in
            loadTournaments(for: newFilter)
        }
        .refreshable {
            await refreshTournaments()
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 主要內容區域
    
    @ViewBuilder
    private var mainContent: some View {
        switch selectedFilter {
        case .featured:
            featuredContent
            
        case .all:
            allTournamentsContent
            
        default:
            filteredTournamentsContent
        }
    }
    
    // MARK: - 精選內容
    
    private var featuredContent: some View {
        FeaturedTournamentsView(
            onEnrollTournament: { tournament in
                handleEnrollTournament(tournament)
            },
            onViewTournamentDetails: { tournament in
                handleViewTournamentDetails(tournament)
            }
        )
    }
    
    // MARK: - 所有錦標賽內容
    
    private var allTournamentsContent: some View {
        VStack(spacing: 0) {
            // 搜尋和排序區域
            searchAndSortSection
            
            // 錦標賽列表
            tournamentsListContent
        }
    }
    
    // MARK: - 篩選錦標賽內容
    
    private var filteredTournamentsContent: some View {
        VStack(spacing: 0) {
            // 類型描述區域
            if selectedFilter != .all && selectedFilter != .featured {
                typeDescriptionSection
            }
            
            // 錦標賽列表
            tournamentsListContent
        }
    }
    
    // MARK: - 搜尋和排序區域
    
    private var searchAndSortSection: some View {
        VStack(spacing: 12) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("搜尋錦標賽名稱或類型...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { _, _ in
                        filterTournaments()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.05))
            )
            
            // 快速篩選選項
            quickFilterButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.gray.opacity(0.05))
    }
    
    private var quickFilterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickFilterButton(
                    title: "報名中",
                    icon: "person.badge.plus",
                    isSelected: false
                ) {
                    filterTournaments(by: .enrolling)
                }
                
                QuickFilterButton(
                    title: "進行中", 
                    icon: "play.circle",
                    isSelected: false
                ) {
                    filterTournaments(by: .ongoing)
                }
                
                QuickFilterButton(
                    title: "高獎金",
                    icon: "dollarsign.circle",
                    isSelected: false
                ) {
                    filterHighPrizeTournaments()
                }
                
                QuickFilterButton(
                    title: "新手友好",
                    icon: "heart.circle",
                    isSelected: false
                ) {
                    filterBeginnerFriendlyTournaments()
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 類型描述區域
    
    private var typeDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tournamentTypeIcon)
                    .font(.title2)
                    .foregroundColor(tournamentTypeColor)
                
                Text(tournamentTypeTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(tournamentTypeDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tournamentTypeColor.opacity(0.05))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 錦標賽列表內容
    
    private var tournamentsListContent: some View {
        Group {
            if isLoading {
                loadingView
            } else if filteredTournaments.isEmpty {
                emptyStateView
            } else {
                tournamentsList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                TournamentCardSkeleton()
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("沒有找到錦標賽")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("請調整篩選條件或稍後再試")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重新載入") {
                loadTournaments()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tournamentsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredTournaments) { tournament in
                    TournamentCardView(
                        tournament: tournament,
                        onEnroll: {
                            handleEnrollTournament(tournament)
                        },
                        onViewDetails: {
                            handleViewTournamentDetails(tournament)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - 計算屬性
    
    private var filteredTournaments: [Tournament] {
        var result = tournaments
        
        // 搜尋篩選
        if !searchText.isEmpty {
            result = result.filter { tournament in
                tournament.name.localizedCaseInsensitiveContains(searchText) ||
                tournament.type.displayName.localizedCaseInsensitiveContains(searchText) ||
                tournament.shortDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    private var tournamentTypeIcon: String {
        switch selectedFilter {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.circle.fill"
        case .monthly: return "calendar.badge.clock"
        case .quarterly: return "chart.line.uptrend.xyaxis"
        case .yearly: return "crown.fill"
        case .special: return "bolt.fill"
        default: return "grid.circle.fill"
        }
    }
    
    private var tournamentTypeColor: Color {
        switch selectedFilter {
        case .daily: return .yellow
        case .weekly: return .green
        case .monthly: return .blue
        case .quarterly: return .purple
        case .yearly: return .red
        case .special: return .pink
        default: return .blue
        }
    }
    
    private var tournamentTypeTitle: String {
        switch selectedFilter {
        case .daily: return "日賽競技場"
        case .weekly: return "週賽競技場"
        case .monthly: return "月賽競技場"
        case .quarterly: return "季賽競技場"
        case .yearly: return "年賽競技場"
        case .special: return "特別賽事"
        default: return "錦標賽競技場"
        }
    }
    
    private var tournamentTypeDescription: String {
        switch selectedFilter {
        case .daily: return "快節奏的單日交易競賽，適合日內交易者展現短線操作技巧"
        case .weekly: return "為期一週的波段操作競賽，平衡短期與中期投資策略"
        case .monthly: return "月度投資競賽，考驗中期投資策略和風險管理能力"
        case .quarterly: return "季度錦標賽，展現全面投資能力和長期策略規劃"
        case .yearly: return "年度冠軍賽，最高榮譽的長期投資策略競賽"
        case .special: return "限時特別賽事，把握重大市場事件的投資機會"
        default: return "探索各種類型的投資競賽，找到最適合您的挑戰"
        }
    }
    
    // MARK: - 資料載入
    
    private func loadTournaments(for filter: TournamentFilter? = nil) {
        let targetFilter = filter ?? selectedFilter
        isLoading = true
        
        // 模擬API呼叫
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch targetFilter {
            case .featured:
                tournaments = Tournament.featuredMockTournaments
            case .all:
                tournaments = Tournament.allMockTournaments
            case .daily:
                tournaments = Tournament.mockTournaments(for: .daily)
            case .weekly:
                tournaments = Tournament.mockTournaments(for: .weekly)
            case .monthly:
                tournaments = Tournament.mockTournaments(for: .monthly)
            case .quarterly:
                tournaments = Tournament.mockTournaments(for: .quarterly)
            case .yearly:
                tournaments = Tournament.mockTournaments(for: .yearly)
            case .special:
                tournaments = Tournament.mockTournaments(for: .special)
            }
            isLoading = false
        }
    }
    
    @MainActor
    private func refreshTournaments() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        loadTournaments()
    }
    
    private func filterTournaments() {
        // 實時搜尋，由 filteredTournaments 計算屬性處理
    }
    
    private func filterTournaments(by status: TournamentStatus) {
        tournaments = Tournament.mockTournaments(for: status)
    }
    
    private func filterHighPrizeTournaments() {
        tournaments = Tournament.allMockTournaments.filter { $0.prizePool >= 200000 }
    }
    
    private func filterBeginnerFriendlyTournaments() {
        tournaments = Tournament.allMockTournaments.filter { 
            $0.type == .daily || $0.type == .weekly 
        }
    }
    
    // MARK: - 事件處理
    
    private func handleEnrollTournament(_ tournament: Tournament) {
        // 處理錦標賽報名
        print("🏆 報名錦標賽: \(tournament.name)")
        
        Task {
            await TournamentStateManager.shared.joinTournament(tournament)
        }
    }
    
    private func handleViewTournamentDetails(_ tournament: Tournament) {
        selectedTournament = tournament
        showingDetail = true
        print("👀 查看錦標賽詳情: \(tournament.name)")
    }
}

// MARK: - 快速篩選按鈕

private struct QuickFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : .gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 錦標賽卡片骨架

private struct TournamentCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                skeletonRectangle(width: 60, height: 24)
                Spacer()
                skeletonRectangle(width: 50, height: 20)
            }
            
            skeletonRectangle(width: 200, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                skeletonRectangle(width: .infinity, height: 16)
                skeletonRectangle(width: 150, height: 16)
            }
            
            HStack(spacing: 20) {
                skeletonColumn()
                skeletonColumn()
            }
            
            HStack(spacing: 12) {
                skeletonRectangle(width: 100, height: 36)
                skeletonRectangle(width: 120, height: 36)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.05))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
    }
    
    private func skeletonColumn() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            skeletonRectangle(width: 60, height: 14)
            skeletonRectangle(width: 80, height: 18)
        }
    }
    
    private func skeletonRectangle(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(.gray.opacity(0.1))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .opacity(isAnimating ? 0.3 : 0.6)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - 按鈕樣式

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

/* #Preview("錦標賽競技場") {
    NavigationView {
        TournamentSelectionView(
            selectedTournament: .constant(nil),
            showingDetail: .constant(false)
        )
        .navigationTitle("錦標賽競技場")
        .navigationBarTitleDisplayMode(.large)
    }
}*/
