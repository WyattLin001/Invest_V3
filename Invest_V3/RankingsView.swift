import SwiftUI

struct RankingsView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    @State private var selectedPeriod = 0
    
    private let periods = ["週榜", "月榜", "總榜"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 期間選擇器
                periodPicker
                
                // 排行榜內容
                rankingsList
            }
            .navigationTitle(rankingsTitle)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await tradingService.loadRankings()
            }
            .onAppear {
                if tradingService.rankings.isEmpty {
                    Task {
                        await tradingService.loadRankings()
                    }
                }
            }
        }
    }
    
    // MARK: - 期間選擇器
    private var periodPicker: some View {
        Picker("排行榜期間", selection: $selectedPeriod) {
            ForEach(0..<periods.count, id: \.self) { index in
                Text(periods[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color(.systemBackground))
        .onChange(of: selectedPeriod) { _ in
            // 這裡可以根據選擇的期間載入不同的排行榜資料
            Task {
                await tradingService.loadRankings()
            }
        }
    }
    
    // MARK: - 排行榜列表
    private var rankingsList: some View {
        Group {
            if tradingService.rankings.isEmpty {
                if tradingService.isLoading {
                    ProgressView("載入排行榜中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeneralEmptyStateView(
                        icon: "crown",
                        title: "暫無排行榜資料",
                        message: "排行榜正在統計中"
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 我的排名
                        MyRankingCard()
                        
                        // 前三名特殊顯示
                        topThreeSection
                        
                        // 其他排名
                        otherRankingsSection
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - 前三名區域
    private var topThreeSection: some View {
        VStack(spacing: 16) {
            Text("🏆 前三名")
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if tradingService.rankings.count >= 3 {
                HStack(alignment: .bottom, spacing: 12) {
                    // 第二名
                    TopRankerCard(
                        ranking: tradingService.rankings[1],
                        podiumHeight: 80,
                        crownIcon: "medal.fill",
                        crownColor: .gray
                    )
                    
                    // 第一名
                    TopRankerCard(
                        ranking: tradingService.rankings[0],
                        podiumHeight: 100,
                        crownIcon: "crown.fill",
                        crownColor: .yellow
                    )
                    
                    // 第三名
                    TopRankerCard(
                        ranking: tradingService.rankings[2],
                        podiumHeight: 60,
                        crownIcon: "medal.fill",
                        crownColor: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 其他排名區域
    private var otherRankingsSection: some View {
        VStack(spacing: 0) {
            if tradingService.rankings.count > 3 {
                ForEach(Array(tradingService.rankings[3...].enumerated()), id: \.element.id) { index, ranking in
                    RankingRow(ranking: ranking)
                    
                    if index < tradingService.rankings.count - 4 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - 計算屬性
    
    private var rankingsTitle: String {
        if let tournamentName = tournamentStateManager.getCurrentTournamentDisplayName() {
            return "\(tournamentName) - 排行榜"
        } else {
            return "排行榜"
        }
    }
}

// MARK: - 前三名卡片
struct TopRankerCard: View {
    let ranking: UserRanking
    let podiumHeight: CGFloat
    let crownIcon: String
    let crownColor: Color
    
    var body: some View {
        NavigationLink(destination: ExpertProfileView(expert: ranking)) {
            VStack(spacing: 8) {
                // 排名圖標
                Image(systemName: crownIcon)
                    .font(.title2)
                    .foregroundColor(crownColor)
                
                // 用戶資訊
                VStack(spacing: 4) {
                    Text(ranking.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    Text(TradingService.shared.formatPercentage(ranking.returnRate))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                    
                    Text(TradingService.shared.formatCurrency(ranking.totalAssets))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 台座
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen.opacity(0.3), Color.brandGreen.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: podiumHeight)
                    .cornerRadius(8)
                    .overlay(
                        Text("#\(ranking.rank)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color.brandGreen)
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 排行榜行
struct RankingRow: View {
    let ranking: UserRanking
    
    var body: some View {
        NavigationLink(destination: ExpertProfileView(expert: ranking)) {
            HStack {
                // 排名徽章
                ZStack {
                    Circle()
                        .fill(rankingColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text("#\(ranking.rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(rankingColor)
                }
                
                // 用戶資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(ranking.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("總資產: \(TradingService.shared.formatCurrency(ranking.totalAssets))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 報酬率
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TradingService.shared.formatPercentage(ranking.returnRate))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                    
                    HStack(spacing: 4) {
                        Image(systemName: ranking.returnRate >= 0 ? "triangle.fill" : "triangle.fill")
                            .font(.caption2)
                            .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                            .rotationEffect(ranking.returnRate >= 0 ? .degrees(0) : .degrees(180))
                        
                        Text(ranking.returnRate >= 0 ? "獲利" : "虧損")
                            .font(.caption2)
                            .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                    }
                }
                
                // 添加箭頭指示器
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rankingColor: Color {
        switch ranking.rank {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return .orange
        case 4...10:
            return Color.brandGreen
        default:
            return .blue
        }
    }
}

// MARK: - 我的排名卡片（可選）
struct MyRankingCard: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        if let user = tradingService.currentUser {
            VStack(spacing: 12) {
                HStack {
                    Text("我的排名")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // 這裡可以顯示用戶在排行榜中的位置
                    Text("#42")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.brandGreen)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("總資產")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(TradingService.shared.formatCurrency(user.totalAssets))
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        let returnRate = ((user.totalAssets - 1000000) / 1000000) * 100
                        Text(String(format: "%.2f%%", returnRate))
                            .font(.caption)
                            .foregroundColor(returnRate >= 0 ? .green : .red)
                    }
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
    }
}

#Preview {
    RankingsView()
}