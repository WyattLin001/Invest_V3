//
//  TournamentSettlementView.swift
//  Invest_V3
//
//  錦標賽結算視圖 - 顯示最終排名和獎勵分發
//

import SwiftUI
import Charts

struct TournamentSettlementView: View {
    let tournament: Tournament
    @StateObject private var workflowService: TournamentWorkflowService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 狀態
    @State private var settlementResults: [TournamentResult] = []
    @State private var isSettling: Bool = false
    @State private var settlementCompleted: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var selectedTab: SettlementTab = .finalRankings
    
    // 統計數據
    @State private var tournamentSummary: TournamentSettlementSummary?
    
    enum SettlementTab: String, CaseIterable {
        case finalRankings = "最終排名"
        case awards = "獎勵分發"
        case statistics = "統計分析"
        case history = "賽事回顧"
        
        var displayName: String { rawValue }
    }
    
    init(tournament: Tournament, workflowService: TournamentWorkflowService) {
        self.tournament = tournament
        self._workflowService = StateObject(wrappedValue: workflowService)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelector
                contentArea
            }
            .navigationTitle("錦標賽結算")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(settlementCompleted ? "完成" : "關閉") {
                        dismiss()
                    }
                }
                
                if !settlementCompleted && tournament.status == .ended {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("開始結算") {
                            startSettlement()
                        }
                        .disabled(isSettling)
                    }
                }
            }
        }
        .alert("結算狀態", isPresented: $showingAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
        .task {
            await loadSettlementData()
        }
        .onChange(of: workflowService.successMessage) { message in
            if let message = message {
                alertMessage = message
                showingAlert = true
                settlementCompleted = true
            }
        }
        .onChange(of: workflowService.errorMessage) { message in
            if let message = message {
                alertMessage = message
                showingAlert = true
            }
        }
    }
    
    // MARK: - 視圖組件
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tournament.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        statusBadge
                        Spacer()
                        durationInfo
                    }
                }
            }
            
            if let summary = tournamentSummary {
                tournamentSummarySection(summary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var durationInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatDateRange(tournament.startDate, tournament.endDate))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("持續 \(daysBetween(tournament.startDate, tournament.endDate)) 天")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var tabSelector: some View {
        Picker("選項", selection: $selectedTab) {
            ForEach(SettlementTab.allCases, id: \.self) { tab in
                Text(tab.displayName)
                    .tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var contentArea: some View {
        TabView(selection: $selectedTab) {
            finalRankingsView.tag(SettlementTab.finalRankings)
            awardsView.tag(SettlementTab.awards)
            statisticsView.tag(SettlementTab.statistics)
            historyView.tag(SettlementTab.history)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    // MARK: - 內容視圖
    
    private var finalRankingsView: some View {
        ScrollView {
            if isSettling {
                VStack(spacing: 20) {
                    ProgressView("正在進行結算...")
                        .scaleEffect(1.2)
                    
                    Text("請耐心等待，結算過程可能需要幾分鐘")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if settlementResults.isEmpty {
                emptyStateView("等待結算", "點擊開始結算按鈕來生成最終排名")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(settlementResults.prefix(10).enumerated()), id: \.element.userId) { index, result in
                        FinalRankingRow(result: result, position: index + 1)
                    }
                    
                    if settlementResults.count > 10 {
                        NavigationLink(destination: FullRankingsView(results: settlementResults)) {
                            Text("查看完整排名 (\(settlementResults.count) 名)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
    }
    
    private var awardsView: some View {
        ScrollView {
            if settlementCompleted {
                LazyVStack(spacing: 16) {
                    Text("獎勵分發")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    ForEach(awardedResults, id: \.userId) { result in
                        AwardRow(result: result)
                    }
                    
                    if awardedResults.isEmpty {
                        emptyStateView("暫無獎勵", "本次錦標賽沒有設置獎勵")
                    }
                }
                .padding()
            } else {
                emptyStateView("等待結算", "結算完成後將顯示獎勵分發情況")
            }
        }
    }
    
    private var statisticsView: some View {
        ScrollView {
            if let summary = tournamentSummary {
                VStack(spacing: 20) {
                    // 參與統計
                    participationStatsSection(summary)
                    
                    // 績效分佈
                    performanceDistributionSection(summary)
                    
                    // 交易活動統計
                    tradingActivitySection(summary)
                    
                    // 市場表現對比
                    marketComparisonSection(summary)
                }
                .padding()
            } else {
                emptyStateView("載入中", "正在載入統計資料...")
            }
        }
    }
    
    private var historyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("賽事回顧")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 重要事件時間軸
                timelineSection
                
                // 表現亮點
                highlightsSection
                
                // 學習要點
                lessonsLearnedSection
            }
            .padding()
        }
    }
    
    // MARK: - 子視圖組件
    
    private func tournamentSummarySection(_ summary: TournamentSettlementSummary) -> some View {
        HStack {
            summaryItem("參與者", "\(summary.totalParticipants)")
            Divider().frame(height: 20)
            summaryItem("完成率", formatPercentage(summary.completionRate))
            Divider().frame(height: 20)
            summaryItem("平均報酬", formatPercentage(summary.averageReturn))
            Divider().frame(height: 20)
            summaryItem("最高報酬", formatPercentage(summary.maxReturn))
        }
    }
    
    private func summaryItem(_ title: String, _ value: String) -> some View {
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
    
    private func participationStatsSection(_ summary: TournamentSettlementSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("參與統計")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("總參與者: \(summary.totalParticipants)")
                    Text("完成競賽: \(summary.activeParticipants)")
                    Text("中途退出: \(summary.totalParticipants - summary.activeParticipants)")
                }
                .font(.subheadline)
                
                Spacer()
                
                // 參與率圓餅圖（簡化版）
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: summary.completionRate / 100)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(summary.completionRate))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func performanceDistributionSection(_ summary: TournamentSettlementSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("績效分佈")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                distributionBar("獲利 (>5%)", summary.profitableCount, summary.totalParticipants, .green)
                distributionBar("持平 (-5% ~ 5%)", summary.breakEvenCount, summary.totalParticipants, .blue)
                distributionBar("虧損 (<-5%)", summary.lossCount, summary.totalParticipants, .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func distributionBar(_ title: String, _ count: Int, _ total: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(count) 人 (\(Int(Double(count) / Double(total) * 100))%)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (Double(count) / Double(total)), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func tradingActivitySection(_ summary: TournamentSettlementSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易活動")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                activityMetric("總交易數", "\(summary.totalTrades)")
                activityMetric("平均每人", "\(summary.avgTradesPerUser)")
                activityMetric("最活躍", "\(summary.maxTradesPerUser)")
                activityMetric("交易金額", formatCurrency(summary.totalVolume))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func activityMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func marketComparisonSection(_ summary: TournamentSettlementSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("市場表現對比")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                comparisonRow("錦標賽平均", summary.averageReturn, .blue)
                comparisonRow("大盤指數 (加權)", summary.marketBenchmark, .gray)
                comparisonRow("相對表現", summary.averageReturn - summary.marketBenchmark, 
                            summary.averageReturn > summary.marketBenchmark ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func comparisonRow(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(formatPercentage(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重要時刻")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                timelineEvent("錦標賽開始", tournament.startDate, "所有參與者獲得初始資金")
                timelineEvent("首次交易", tournament.startDate.addingTimeInterval(3600), "第一筆交易完成")
                timelineEvent("半程統計", tournament.startDate.addingTimeInterval(86400 * 3), "中期表現統計")
                timelineEvent("錦標賽結束", tournament.endDate, "交易停止，開始結算")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func timelineEvent(_ title: String, _ date: Date, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                
                if title != "錦標賽結束" {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("表現亮點")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                highlightItem("🏆", "冠軍報酬率達 18.5%，表現優異")
                highlightItem("📈", "超過 60% 的參與者獲得正報酬")
                highlightItem("🔥", "平均每日交易量達 500 萬元")
                highlightItem("⭐", "最長連勝紀錄：連續 12 筆獲利交易")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func highlightItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private var lessonsLearnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("學習要點")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                lessonItem("風險控制是關鍵：表現優異的參與者都做好了風險管理")
                lessonItem("分散投資降低風險：集中投資的參與者波動較大")
                lessonItem("耐心持有：頻繁交易並不一定帶來更好的報酬")
                lessonItem("市場時機：把握市場波動的參與者表現更佳")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private func lessonItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
                .fontWeight(.bold)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    private func emptyStateView(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 計算屬性
    
    private var statusColor: Color {
        if isSettling {
            return .orange
        } else if settlementCompleted {
            return .green
        } else {
            return tournament.status == .ended ? .red : .blue
        }
    }
    
    private var statusText: String {
        if isSettling {
            return "結算中"
        } else if settlementCompleted {
            return "結算完成"
        } else {
            return tournament.status == .ended ? "待結算" : tournament.status.displayName
        }
    }
    
    private var awardedResults: [TournamentResult] {
        return settlementResults.filter { $0.reward != nil }
    }
    
    // MARK: - 方法
    
    private func loadSettlementData() async {
        // 載入錦標賽摘要數據
        await MainActor.run {
            tournamentSummary = TournamentSettlementSummary(
                totalParticipants: tournament.currentParticipants,
                activeParticipants: tournament.currentParticipants - 5, // 模擬有些人中途退出
                completionRate: 85.0,
                averageReturn: 2.45,
                maxReturn: 18.5,
                minReturn: -12.3,
                profitableCount: 52,
                breakEvenCount: 18,
                lossCount: 15,
                totalTrades: 1234,
                avgTradesPerUser: 14,
                maxTradesPerUser: 48,
                totalVolume: 125000000,
                marketBenchmark: 1.8
            )
        }
        
        // 如果錦標賽已結束但未結算，可以載入預結算數據
        if tournament.status == .ended && settlementResults.isEmpty {
            // 可以在這裡載入已有的排名數據作為預覽
        }
    }
    
    private func startSettlement() {
        isSettling = true
        
        Task {
            do {
                let results = try await workflowService.settleTournament(tournamentId: tournament.id)
                
                await MainActor.run {
                    settlementResults = results
                    isSettling = false
                    settlementCompleted = true
                }
            } catch {
                await MainActor.run {
                    isSettling = false
                    alertMessage = "結算失敗: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 0
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_TW")
        if amount >= 1000000 {
            return formatter.string(from: NSNumber(value: amount / 1000000))?.replacingOccurrences(of: "NT$", with: "NT$") ?? "NT$\(amount/1000000)M"
        } else {
            return formatter.string(from: NSNumber(value: amount)) ?? "NT$\(amount)"
        }
    }
}

// MARK: - 支援結構

struct TournamentSettlementSummary {
    let totalParticipants: Int
    let activeParticipants: Int
    let completionRate: Double
    let averageReturn: Double
    let maxReturn: Double
    let minReturn: Double
    let profitableCount: Int
    let breakEvenCount: Int
    let lossCount: Int
    let totalTrades: Int
    let avgTradesPerUser: Int
    let maxTradesPerUser: Int
    let totalVolume: Double
    let marketBenchmark: Double
}

// MARK: - 最終排名行視圖

struct FinalRankingRow: View {
    let result: TournamentResult
    let position: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("\(result.rank)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // 用戶資訊
            VStack(alignment: .leading, spacing: 4) {
                Text("用戶 \(result.userId.uuidString.prefix(8))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Text("\(result.totalTrades) 筆交易")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("勝率 \(String(format: "%.1f", result.winRate))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 績效指標
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPercentage(result.returnPercentage))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(result.returnPercentage >= 0 ? .green : .red)
                
                if let reward = result.reward {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text("+\(Int(reward.amount))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(position <= 3 ? rankColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var rankColor: Color {
        switch result.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color.orange
        default: return .blue
        }
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
}

// MARK: - 獎勵行視圖

struct AwardRow: View {
    let result: TournamentResult
    
    var body: some View {
        HStack(spacing: 16) {
            // 獎勵圖標
            Image(systemName: awardIcon)
                .font(.title2)
                .foregroundColor(awardColor)
                .frame(width: 32, height: 32)
            
            // 獎勵資訊
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(result.rank) 名")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(result.reward?.description ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 獎勵數量
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(Int(result.reward?.amount ?? 0))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(awardColor)
                
                Text(result.reward?.type.rawValue.uppercased() ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(awardColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(awardColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var awardIcon: String {
        switch result.rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return "star.fill"
        }
    }
    
    private var awardColor: Color {
        switch result.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

// MARK: - 完整排名視圖

struct FullRankingsView: View {
    let results: [TournamentResult]
    
    var body: some View {
        List {
            ForEach(results.indices, id: \.self) { index in
                FinalRankingRow(result: results[index], position: index + 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("完整排名")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 預覽

struct TournamentSettlementView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTournament = Tournament(
            id: UUID(),
            name: "科技股挑戰賽",
            type: .monthly,
            status: .finished,
            startDate: Date().addingTimeInterval(-86400 * 7),
            endDate: Date().addingTimeInterval(-3600),
            description: "專注科技股投資競賽",
            shortDescription: "科技股挑戰賽",
            initialBalance: 1000000,
            entryFee: 100,
            prizePool: 0,
            maxParticipants: 100,
            currentParticipants: 85,
            isFeatured: false,
            createdBy: UUID(),
            riskLimitPercentage: 0.2,
            minHoldingRate: 0.5,
            maxSingleStockRate: 0.3,
            rules: [],
            createdAt: Date().addingTimeInterval(-86400 * 8),
            updatedAt: Date()
        )
        
        TournamentSettlementView(
            tournament: sampleTournament,
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