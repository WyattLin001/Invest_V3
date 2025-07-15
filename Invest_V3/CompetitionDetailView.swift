import SwiftUI

struct CompetitionDetailView: View {
    let competition: Competition
    @StateObject private var viewModel = CompetitionViewModel()
    @State private var selectedTab = 0
    @State private var showingPortfolio = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 競賽標題和狀態
                competitionHeader
                
                // 標籤選擇器
                detailTabPicker
                
                // 內容區域
                TabView(selection: $selectedTab) {
                    competitionInfoView
                        .tag(0)
                    
                    rankingView
                        .tag(1)
                    
                    portfolioView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle(competition.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadCompetitionRankings(competitionId: competition.id)
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadCompetitionRankings(competitionId: competition.id)
                }
            }
            .refreshable {
                await viewModel.loadCompetitionRankings(competitionId: competition.id)
            }
        }
    }
    
    // MARK: - 競賽標題
    
    private var competitionHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(competition.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(competition.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
                
                CompetitionStatusBadge(competition: competition)
            }
            
            // 競賽統計
            HStack(spacing: 20) {
                CompetitionStatView(
                    title: "參與人數",
                    value: "\(competition.participantCount)",
                    icon: "person.3"
                )
                
                CompetitionStatView(
                    title: "剩餘時間",
                    value: viewModel.formatTimeRemaining(competition),
                    icon: "clock"
                )
                
                if let prizePool = competition.prizePool {
                    CompetitionStatView(
                        title: "獎金池",
                        value: viewModel.formatPrizePool(prizePool),
                        icon: "gift"
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - 標籤選擇器
    
    private var detailTabPicker: some View {
        HStack {
            TabButton(
                title: "競賽資訊",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabButton(
                title: "排行榜",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabButton(
                title: "我的投資組合",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 競賽資訊視圖
    
    private var competitionInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 競賽規則
                InfoSection(title: "競賽規則") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(title: "初始資金", value: "NT$ 1,000,000")
                        InfoRow(title: "交易手續費", value: "0.1425% (買入)")
                        InfoRow(title: "交易稅", value: "0.3% (賣出)")
                        InfoRow(title: "可交易標的", value: "台股上市股票")
                        InfoRow(title: "交易時間", value: "週一至週五 9:00-13:30")
                    }
                }
                
                // 競賽時間
                InfoSection(title: "競賽時間") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(
                            title: "開始時間",
                            value: formatDate(competition.startDate)
                        )
                        InfoRow(
                            title: "結束時間",
                            value: formatDate(competition.endDate)
                        )
                        InfoRow(
                            title: "競賽狀態",
                            value: viewModel.getStatusText(competition)
                        )
                    }
                }
                
                // 獎勵機制
                if let prizePool = competition.prizePool {
                    InfoSection(title: "獎勵機制") {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(title: "第1名", value: "NT$ \(Int(prizePool * 0.5))")
                            InfoRow(title: "第2名", value: "NT$ \(Int(prizePool * 0.3))")
                            InfoRow(title: "第3名", value: "NT$ \(Int(prizePool * 0.2))")
                        }
                    }
                }
                
                // 競賽說明
                InfoSection(title: "競賽說明") {
                    Text("""
                    1. 每位參與者將獲得 100 萬虛擬資金進行投資
                    2. 可買賣台股上市股票，遵循真實交易規則
                    3. 系統將即時計算投資組合價值和收益率
                    4. 競賽結束時，依收益率排名決定獲獎者
                    5. 所有交易記錄公開透明，確保競賽公平性
                    """)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 排行榜視圖
    
    private var rankingView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.competitionRankings) { ranking in
                    CompetitionRankingRow(ranking: ranking)
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .padding()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("載入排名中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.8))
            }
        }
    }
    
    // MARK: - 投資組合視圖
    
    private var portfolioView: some View {
        VStack {
            if viewModel.isUserParticipating(in: competition) {
                // 用戶已參加競賽，顯示投資組合
                CompetitionPortfolioView(competition: competition)
            } else {
                // 用戶未參加競賽，顯示提示
                VStack(spacing: 20) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("尚未參加此競賽")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("參加競賽後即可查看投資組合")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if competition.isActive {
                        Button("立即參加") {
                            Task {
                                await viewModel.joinCompetition(competition)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - 輔助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 標籤按鈕
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                if isSelected {
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
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 競賽統計視圖
struct CompetitionStatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 資訊區塊
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 資訊行
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 競賽排名行
struct CompetitionRankingRow: View {
    let ranking: CompetitionRanking
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名
            ZStack {
                Circle()
                    .fill(ranking.rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if ranking.rank <= 3 {
                    Text(ranking.rankIcon)
                        .font(.title2)
                } else {
                    Text("\(ranking.rank)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ranking.rankColor)
                }
            }
            
            // 用戶資訊
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("總資產: \(ranking.totalValueFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 收益率
            VStack(alignment: .trailing, spacing: 2) {
                Text(ranking.returnRateFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ranking.returnRateColor)
                
                Text("收益率")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

#Preview {
    CompetitionDetailView(
        competition: Competition(
            id: UUID(),
            title: "週末投資挑戰賽",
            description: "為期一週的投資競賽，考驗您的投資眼光",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            status: "active",
            prizePool: 50000,
            participantCount: 125,
            createdAt: Date()
        )
    )
}