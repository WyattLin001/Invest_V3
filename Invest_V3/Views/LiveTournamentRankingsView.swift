//
//  LiveTournamentRankingsView.swift
//  Invest_V3
//
//  實時錦標賽排行榜視圖 - 支援自動更新和詳細統計
//

import SwiftUI
import Combine

struct LiveTournamentRankingsView: View {
    let tournamentId: UUID
    @StateObject private var workflowService: TournamentWorkflowService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 狀態
    @State private var rankings: [TournamentRanking] = []
    @State private var tournament: Tournament?
    @State private var userRank: TournamentRanking?
    @State private var selectedSegment: RankingSegment = .overall
    @State private var searchText: String = ""
    @State private var showingUserDetails: Bool = false
    @State private var selectedUser: UUID?
    
    // 刷新和載入狀態
    @State private var isRefreshing: Bool = false
    @State private var lastUpdateTime: Date = Date()
    @State private var autoRefreshTimer: Timer?
    
    // 統計數據
    @State private var tournamentStats: TournamentOverviewStatistics?
    
    // 分段選項
    enum RankingSegment: String, CaseIterable {
        case overall = "總排名"
        case daily = "日排名"
        case weekly = "週排名"
        case performance = "績效"
        
        var displayName: String { rawValue }
    }
    
    init(tournamentId: UUID, workflowService: TournamentWorkflowService) {
        self.tournamentId = tournamentId
        self._workflowService = StateObject(wrappedValue: workflowService)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                segmentedControl
                
                if isRefreshing {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationTitle("實時排行榜")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        stopAutoRefresh()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    refreshButton
                }
            }
            .searchable(text: $searchText, prompt: "搜尋參與者")
            .task {
                await loadInitialData()
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .refreshable {
                await refreshRankings()
            }
        }
    }
    
    // MARK: - 視圖組件
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament?.name ?? "載入中...")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack {
                        statusIndicator
                        Spacer()
                        lastUpdatedInfo
                    }
                }
            }
            
            if let stats = tournamentStats {
                statsSection(stats)
            }
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
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            
            Text("實時更新")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var lastUpdatedInfo: some View {
        Text("更新: \(formatTime(lastUpdateTime))")
            .font(.caption)
            .foregroundColor(.secondary)
            .monospacedDigit()
    }
    
    private var segmentedControl: some View {
        Picker("排名類型", selection: $selectedSegment) {
            ForEach(RankingSegment.allCases, id: \.self) { segment in
                Text(segment.displayName)
                    .tag(segment)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: selectedSegment) { _ in
            Task {
                await loadRankingsForSegment()
            }
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshRankings()
            }
        }) {
            Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise.circle")
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .disabled(isRefreshing)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView("載入排行榜...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // 用戶排名（如果有）
                if let userRank = userRank {
                    userRankSection(userRank)
                }
                
                // 排行榜列表
                ForEach(filteredRankings.indices, id: \.self) { index in
                    let ranking = filteredRankings[index]
                    TournamentRankingRow(
                        ranking: ranking,
                        isCurrentUser: isCurrentUser(ranking.userId),
                        onTap: {
                            selectedUser = ranking.userId
                            showingUserDetails = true
                        }
                    )
                    .animation(.easeInOut(duration: 0.3), value: rankings)
                }
                
                if filteredRankings.isEmpty {
                    emptyStateView
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingUserDetails) {
            if let userId = selectedUser {
                UserRankingDetailView(
                    tournamentId: tournamentId,
                    userId: userId,
                    workflowService: workflowService
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暫無排名資料")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("排行榜將在參與者開始交易後顯示")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 統計部分
    
    private func statsSection(_ stats: TournamentOverviewStatistics) -> some View {
        HStack {
            statItem(title: "參與者", value: "\(stats.totalParticipants)")
            Divider().frame(height: 20)
            statItem(title: "平均報酬", value: formatPercentage(stats.averageReturn))
            Divider().frame(height: 20)
            statItem(title: "最高報酬", value: formatPercentage(stats.maxReturn))
            Divider().frame(height: 20)
            statItem(title: "活躍交易", value: "\(stats.activeTrades)")
        }
        .padding(.vertical, 8)
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 用戶排名部分
    
    private func userRankSection(_ userRank: TournamentRanking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的排名")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(userRank.rank) 名")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("共 \(rankings.count) 位參與者")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatPercentage(userRank.totalReturnPercent))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(userRank.totalReturnPercent >= 0 ? .green : .red)
                    
                    Text("總報酬率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 計算屬性
    
    private var filteredRankings: [TournamentRanking] {
        if searchText.isEmpty {
            return rankings
        } else {
            // 這裡需要根據實際的用戶數據進行搜尋
            return rankings.filter { ranking in
                // 簡化版本：按用戶ID搜尋
                ranking.userId.uuidString.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - 方法
    
    private func loadInitialData() async {
        isRefreshing = true
        
        async let tournamentTask = loadTournament()
        async let rankingsTask = loadRankingsForSegment()
        async let statsTask = loadTournamentStats()
        
        await tournamentTask
        await rankingsTask
        await statsTask
        
        isRefreshing = false
        lastUpdateTime = Date()
    }
    
    private func loadTournament() async {
        // 這裡應該從服務載入錦標賽資料
        // 目前使用模擬資料
        await MainActor.run {
            tournament = Tournament(
                id: tournamentId,
                name: "科技股挑戰賽",
                description: "專注科技股投資競賽",
                status: .active,
                startDate: Date().addingTimeInterval(-86400),
                endDate: Date().addingTimeInterval(86400 * 6),
                entryCapital: 1000000,
                maxParticipants: 100,
                currentParticipants: 85,
                feeTokens: 0,
                returnMetric: "twr",
                resetMode: "monthly",
                createdAt: Date(),
                rules: nil
            )
        }
    }
    
    private func loadRankingsForSegment() async {
        do {
            let newRankings = try await workflowService.updateLiveRankings(tournamentId: tournamentId)
            
            await MainActor.run {
                rankings = newRankings
                // 尋找當前用戶的排名
                userRank = rankings.first { isCurrentUser($0.userId) }
            }
        } catch {
            print("載入排行榜失敗: \(error)")
        }
    }
    
    private func loadTournamentStats() async {
        // 模擬載入統計數據
        await MainActor.run {
            tournamentStats = TournamentOverviewStatistics(
                totalParticipants: 85,
                averageReturn: 2.45,
                maxReturn: 15.67,
                minReturn: -8.23,
                activeTrades: 234
            )
        }
    }
    
    private func refreshRankings() async {
        await loadRankingsForSegment()
        lastUpdateTime = Date()
    }
    
    private func startAutoRefresh() {
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await refreshRankings()
            }
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    private func isCurrentUser(_ userId: UUID) -> Bool {
        // 這裡應該檢查是否為當前用戶
        // 目前使用簡化邏輯
        return false
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - 支援結構

struct TournamentOverviewStatistics {
    let totalParticipants: Int
    let averageReturn: Double
    let maxReturn: Double
    let minReturn: Double
    let activeTrades: Int
}

// MARK: - 排名行視圖

struct TournamentRankingRow: View {
    let ranking: TournamentRanking
    let isCurrentUser: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 排名
                rankBadge
                
                // 用戶資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text("用戶 \(ranking.userId.uuidString.prefix(8))")
                        .font(.subheadline)
                        .fontWeight(isCurrentUser ? .bold : .medium)
                        .foregroundColor(isCurrentUser ? .blue : .primary)
                    
                    HStack(spacing: 12) {
                        metricItem(title: "資產", value: formatCurrency(ranking.totalAssets))
                        metricItem(title: "交易", value: "\(ranking.totalTrades)")
                        metricItem(title: "勝率", value: formatPercentage(ranking.winRate))
                    }
                }
                
                Spacer()
                
                // 報酬率
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatPercentage(ranking.totalReturnPercent))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(returnColor)
                    
                    Text("總報酬")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankBackgroundColor)
                .frame(width: 40, height: 40)
            
            Text("\(ranking.rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(rankTextColor)
        }
    }
    
    private var rankBackgroundColor: Color {
        switch ranking.rank {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return Color.orange.opacity(0.7)
        default:
            return .blue.opacity(0.3)
        }
    }
    
    private var rankTextColor: Color {
        switch ranking.rank {
        case 1, 2, 3:
            return .white
        default:
            return .primary
        }
    }
    
    private var returnColor: Color {
        return ranking.totalReturnPercent >= 0 ? .green : .red
    }
    
    private func metricItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000000 {
            return String(format: "%.1fM", amount / 1000000)
        } else if amount >= 1000 {
            return String(format: "%.1fK", amount / 1000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
}

// MARK: - 用戶排名詳情視圖

struct UserRankingDetailView: View {
    let tournamentId: UUID
    let userId: UUID
    let workflowService: TournamentWorkflowService
    
    @Environment(\.dismiss) private var dismiss
    @State private var userDetails: UserRankingDetails?
    @State private var isLoading: Bool = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("載入中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let details = userDetails {
                    userDetailsContent(details)
                } else {
                    Text("無法載入用戶詳情")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("用戶詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadUserDetails()
        }
    }
    
    private func userDetailsContent(_ details: UserRankingDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 用戶基本資訊
            userInfoSection(details)
            
            // 績效指標
            performanceMetricsSection(details)
            
            // 交易歷史摘要
            tradingHistorySection(details)
            
            // 持股分佈
            holdingsSection(details)
        }
        .padding()
    }
    
    private func userInfoSection(_ details: UserRankingDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("用戶資訊")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("用戶ID")
                    .foregroundColor(.secondary)
                Spacer()
                Text(details.userId.uuidString.prefix(8))
                    .fontWeight(.medium)
                    .monospaced()
            }
            
            HStack {
                Text("排名")
                    .foregroundColor(.secondary)
                Spacer()
                Text("第 \(details.rank) 名")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("加入時間")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDate(details.joinedAt))
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func performanceMetricsSection(_ details: UserRankingDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("績效指標")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                metricCard("總資產", formatCurrency(details.totalAssets))
                metricCard("總報酬率", formatPercentage(details.totalReturnPercent))
                metricCard("最大回撤", formatPercentage(details.maxDrawdown))
                metricCard("夏普比率", String(format: "%.2f", details.sharpeRatio))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func tradingHistorySection(_ details: UserRankingDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易統計")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("總交易數")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(details.totalTrades)")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("勝率")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatPercentage(details.winRate))
                    .fontWeight(.medium)
                    .foregroundColor(details.winRate >= 50 ? .green : .red)
            }
            
            HStack {
                Text("平均持有天數")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", details.avgHoldingDays)) 天")
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func holdingsSection(_ details: UserRankingDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主要持股")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(details.topHoldings, id: \.symbol) { holding in
                HStack {
                    Text(holding.symbol)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(holding.marketValue))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(String(format: "%.1f", holding.percentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func loadUserDetails() async {
        // 模擬載入用戶詳情
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        await MainActor.run {
            userDetails = UserRankingDetails(
                userId: userId,
                rank: Int.random(in: 1...100),
                joinedAt: Date().addingTimeInterval(-86400 * 7),
                totalAssets: Double.random(in: 900000...1200000),
                totalReturnPercent: Double.random(in: -10...15),
                maxDrawdown: Double.random(in: 0...20),
                sharpeRatio: Double.random(in: -1...3),
                totalTrades: Int.random(in: 10...50),
                winRate: Double.random(in: 30...70),
                avgHoldingDays: Double.random(in: 1...10),
                topHoldings: [
                    HoldingInfo(symbol: "2330", marketValue: 150000, percentage: 15.0),
                    HoldingInfo(symbol: "AAPL", marketValue: 120000, percentage: 12.0),
                    HoldingInfo(symbol: "2454", marketValue: 80000, percentage: 8.0)
                ]
            )
            isLoading = false
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - 用戶詳情數據結構

struct UserRankingDetails {
    let userId: UUID
    let rank: Int
    let joinedAt: Date
    let totalAssets: Double
    let totalReturnPercent: Double
    let maxDrawdown: Double
    let sharpeRatio: Double
    let totalTrades: Int
    let winRate: Double
    let avgHoldingDays: Double
    let topHoldings: [HoldingInfo]
}

struct HoldingInfo {
    let symbol: String
    let marketValue: Double
    let percentage: Double
}

// MARK: - 預覽

struct LiveTournamentRankingsView_Previews: PreviewProvider {
    static var previews: some View {
        LiveTournamentRankingsView(
            tournamentId: UUID(),
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