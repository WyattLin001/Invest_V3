import SwiftUI

struct CompetitionListView: View {
    @StateObject private var viewModel = CompetitionViewModel()
    @State private var selectedTab = 0
    @State private var showingCreateCompetition = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 標籤選擇器
                competitionTabPicker
                
                // 競賽列表
                TabView(selection: $selectedTab) {
                    activeCompetitionsView
                        .tag(0)
                    
                    userCompetitionsView
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("投資競賽")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        Task {
                            await viewModel.refreshCompetitionData()
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshCompetitionData()
            }
            .alert("錯誤", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("確定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - 標籤選擇器
    
    private var competitionTabPicker: some View {
        HStack {
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 4) {
                    Text("全部競賽")
                        .font(.system(size: 16, weight: selectedTab == 0 ? .semibold : .regular))
                        .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                    
                    if selectedTab == 0 {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 4) {
                    Text("我的競賽")
                        .font(.system(size: 16, weight: selectedTab == 1 ? .semibold : .regular))
                        .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                    
                    if selectedTab == 1 {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 全部競賽視圖
    
    private var activeCompetitionsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.activeCompetitions) { competition in
                    CompetitionCardView(
                        competition: competition,
                        isUserParticipating: viewModel.isUserParticipating(in: competition),
                        userRank: viewModel.getUserRank(in: competition),
                        userReturnRate: viewModel.getUserReturnRate(in: competition)
                    ) {
                        // 參加競賽
                        if viewModel.isUserParticipating(in: competition) {
                            // 查看競賽詳情
                            viewModel.selectedCompetition = competition
                        } else {
                            // 顯示參加確認
                            viewModel.selectedCompetition = competition
                            viewModel.showingJoinAlert = true
                        }
                    }
                    .onTapGesture {
                        viewModel.selectedCompetition = competition
                        Task {
                            await viewModel.loadCompetitionRankings(competitionId: competition.id)
                        }
                    }
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("載入中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.8))
            }
        }
        .alert("參加競賽", isPresented: $viewModel.showingJoinAlert) {
            Button("取消", role: .cancel) {
                viewModel.showingJoinAlert = false
            }
            Button("參加") {
                if let competition = viewModel.selectedCompetition {
                    Task {
                        await viewModel.joinCompetition(competition)
                    }
                }
            }
        } message: {
            if let competition = viewModel.selectedCompetition {
                Text("確定要參加「\(competition.title)」競賽嗎？")
            }
        }
    }
    
    // MARK: - 我的競賽視圖
    
    private var userCompetitionsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.userCompetitions) { competition in
                    CompetitionCardView(
                        competition: competition,
                        isUserParticipating: true,
                        userRank: viewModel.getUserRank(in: competition),
                        userReturnRate: viewModel.getUserReturnRate(in: competition)
                    ) {
                        // 查看競賽詳情或離開競賽
                        viewModel.selectedCompetition = competition
                    }
                    .onTapGesture {
                        viewModel.selectedCompetition = competition
                        Task {
                            await viewModel.loadCompetitionRankings(competitionId: competition.id)
                        }
                    }
                    .contextMenu {
                        Button("離開競賽", role: .destructive) {
                            viewModel.selectedCompetition = competition
                            viewModel.showingLeaveAlert = true
                        }
                    }
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.userCompetitions.isEmpty && !viewModel.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("尚未參加任何競賽")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("參加競賽，與其他投資者比拼實力！")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("瀏覽競賽") {
                        selectedTab = 0
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .alert("離開競賽", isPresented: $viewModel.showingLeaveAlert) {
            Button("取消", role: .cancel) {
                viewModel.showingLeaveAlert = false
            }
            Button("離開", role: .destructive) {
                if let competition = viewModel.selectedCompetition {
                    Task {
                        await viewModel.leaveCompetition(competition)
                    }
                }
            }
        } message: {
            if let competition = viewModel.selectedCompetition {
                Text("確定要離開「\(competition.title)」競賽嗎？此操作無法復原。")
            }
        }
    }
}

// MARK: - 競賽卡片視圖
struct CompetitionCardView: View {
    let competition: Competition
    let isUserParticipating: Bool
    let userRank: Int?
    let userReturnRate: Double?
    let onActionTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題和狀態
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(competition.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(competition.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 狀態標籤
                CompetitionStatusBadge(competition: competition)
            }
            
            // 競賽資訊
            VStack(spacing: 8) {
                CompetitionInfoRow(
                    icon: "calendar",
                    title: "競賽時間",
                    value: formatDuration(competition)
                )
                
                if let prizePool = competition.prizePool {
                    CompetitionInfoRow(
                        icon: "gift",
                        title: "獎金池",
                        value: formatPrizePool(prizePool)
                    )
                }
                
                CompetitionInfoRow(
                    icon: "person.3",
                    title: "參與人數",
                    value: "\(competition.participantCount) 人"
                )
            }
            
            // 用戶狀態
            if isUserParticipating {
                userStatusView
            }
            
            // 操作按鈕
            HStack {
                if isUserParticipating {
                    Button("查看詳情") {
                        onActionTap()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("參加競賽") {
                        onActionTap()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!competition.isActive)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var userStatusView: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的排名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let rank = userRank {
                        Text("第 \(rank) 名")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("我的收益率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let returnRate = userReturnRate {
                        Text(String(format: "%.2f%%", returnRate))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(returnRate >= 0 ? .green : .red)
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ competition: Competition) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        return "\(formatter.string(from: competition.startDate)) - \(formatter.string(from: competition.endDate))"
    }
    
    private func formatPrizePool(_ amount: Double) -> String {
        return String(format: "NT$ %.0f", amount)
    }
}

// MARK: - 競賽狀態標籤
struct CompetitionStatusBadge: View {
    let competition: Competition
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusText: String {
        if competition.isActive {
            return "進行中"
        } else if competition.isUpcoming {
            return "即將開始"
        } else {
            return "已結束"
        }
    }
    
    private var statusColor: Color {
        if competition.isActive {
            return .green
        } else if competition.isUpcoming {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - 競賽資訊行
struct CompetitionInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    CompetitionListView()
}