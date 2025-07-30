//
//  PersonalPerformanceView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  個人績效分析視圖 - 綜合投資表現與成就系統

import SwiftUI

struct PersonalPerformanceView: View {
    private let tournamentService = ServiceConfiguration.makeTournamentService()
    @State private var selectedTimeframe: PerformanceTimeframe = .month
    @State private var performanceData: PersonalPerformance = MockPortfolioData.samplePerformance
    @State private var isRefreshing = false
    @State private var showingShareSheet = false
    @State private var selectedTab: PerformanceTab = .overview
    @State private var showingError = false
    
    // 模擬當前用戶ID - 在實際應用中應從用戶會話中獲取
    private let currentUserId = UUID()
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    // 績效總覽卡片
                    performanceOverviewCard
                    
                    // 時間範圍選擇器
                    timeframeSelector
                    
                    // 分頁內容
                    TabView(selection: $selectedTab) {
                        // 績效總覽
                        performanceOverviewContent
                            .tag(PerformanceTab.overview)
                        
                        // 風險分析
                        riskAnalysisContent
                            .tag(PerformanceTab.risk)
                        
                        // 成就系統
                        achievementsContent
                            .tag(PerformanceTab.achievements)
                    }
                    .frame(minHeight: 900) // 改用最小高度，允許內容擴展
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // 標籤選擇器
                    tabSelector
                    
                    // 詳細指標
                    detailedMetricsCard
                    
                    // 績效歷史圖表
                    performanceHistoryCard
                    
                    // 排名歷史
                    rankingHistoryCard
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            Task {
                await loadPerformanceData()
            }
        }
        .refreshable {
            await refreshPerformanceData()
        }
        .sheet(isPresented: $showingShareSheet) {
            PerformanceShareSheet(performanceData: performanceData)
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") { }
        } message: {
            Text("載入績效資料時發生錯誤，請稍後再試")
        }
    }
    
    // MARK: - 績效總覽卡片
    private var performanceOverviewCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("投資績效")
                    .font(.headline)
                    .adaptiveTextColor()
                
                Spacer()
                
                performanceGrade
            }
            
            HStack(alignment: .bottom, spacing: DesignTokens.spacingSM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總報酬率")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                    
                    Text(String(format: "%@%.2f%%", performanceData.totalReturn >= 0 ? "+" : "", performanceData.totalReturn * 100))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(performanceData.totalReturn >= 0 ? .success : .danger)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("年化報酬率")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                    
                    Text(String(format: "%@%.2f%%", performanceData.annualizedReturn >= 0 ? "+" : "", performanceData.annualizedReturn * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(performanceData.annualizedReturn >= 0 ? .success : .danger)
                }
            }
            
            Divider()
                .background(Color.divider)
            
            HStack {
                performanceMetric("勝率", String(format: "%.0f%%", performanceData.winRate * 100), .brandGreen)
                Spacer()
                performanceMetric("交易次數", "\(performanceData.totalTrades)", .brandBlue)
                Spacer()
                performanceMetric("平均持有", String(format: "%.0f天", performanceData.avgHoldingDays), .brandOrange)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 時間範圍選擇器
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(PerformanceTimeframe.allCases, id: \.self) { timeframe in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeframe = timeframe
                        }
                    }) {
                        Text(timeframe.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeframe == timeframe ? .white : .brandGreen)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeframe == timeframe ? Color.brandGreen : Color.brandGreen.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 標籤選擇器
    private var tabSelector: some View {
        HStack {
            ForEach(PerformanceTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.caption)
                            Text(tab.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .brandGreen : .gray600)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.brandGreen : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.surfacePrimary)
    }
    
    // MARK: - 績效總覽內容
    private var performanceOverviewContent: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingMD) {
                // 多維度績效分析
                multiDimensionalAnalysis
                
                // 原有關鍵指標
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignTokens.spacingSM) {
                    metricCard("最大回撤", String(format: "%.2f%%", performanceData.maxDrawdown * 100), .danger)
                    metricCard("夏普比率", performanceData.sharpeRatio != nil ? String(format: "%.2f", performanceData.sharpeRatio!) : "N/A", .brandBlue)
                    metricCard("獲利交易", "\(performanceData.profitableTrades)", .success)
                    metricCard("風險評分", String(format: "%.1f/10", performanceData.riskScore), .warning)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 多維度績效分析
    private var multiDimensionalAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.brandBlue)
                Text("多維度績效分析")
                    .font(.title2)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                Spacer()
            }
            
            VStack(spacing: 20) {
                // 收益指標和風險指標
                HStack(spacing: 20) {
                    // 收益指標
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.green)
                            Text("收益指標")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        MetricRow(title: "總報酬", value: "+28.5%", color: .green)
                        MetricRow(title: "年化報酬", value: "+15.2%", color: .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 風險指標
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("風險指標")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        MetricRow(title: "夏普比率", value: "1.85", color: .blue)
                        MetricRow(title: "最大回撤", value: "-8.3%", color: .red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 一致性和組合健康度
                HStack(spacing: 20) {
                    // 一致性
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                            Text("一致性")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        MetricRow(title: "勝率", value: "+68.4%", color: .green)
                        MetricRow(title: "平均持有期", value: "12.5 天", color: .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 組合健康度
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "heart.circle")
                                .foregroundColor(.purple)
                            Text("組合健康度")
                                .font(.headline)
                                .foregroundColor(.purple)
                        }
                        
                        HealthScoreRow(title: "多樣化", score: 82, maxScore: 100, color: .blue)
                        HealthScoreRow(title: "風險分數", score: 65, maxScore: 100, color: .orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 新增：行業分散度和趨勢分析
                HStack(spacing: 20) {
                    // 行業分散度
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.indigo)
                            Text("行業分散")
                                .font(.headline)
                                .foregroundColor(.indigo)
                        }
                        
                        MetricRow(title: "科技股佔比", value: "45.2%", color: .blue)
                        MetricRow(title: "金融股佔比", value: "23.8%", color: .green)
                        MetricRow(title: "分散度評分", value: "7.5/10", color: .indigo)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 趨勢分析
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(.mint)
                            Text("趨勢分析")
                                .font(.headline)
                                .foregroundColor(.mint)
                        }
                        
                        MetricRow(title: "7日趨勢", value: "↗ 上升", color: .green)
                        MetricRow(title: "30日趨勢", value: "→ 盤整", color: .orange)
                        MetricRow(title: "波動率", value: "12.4%", color: .red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 新增：交易行為和市場對比
                HStack(spacing: 20) {
                    // 交易行為
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.cyan)
                            Text("交易行為")
                                .font(.headline)
                                .foregroundColor(.cyan)
                        }
                        
                        MetricRow(title: "交易頻率", value: "每週 2.3 次", color: .primary)
                        MetricRow(title: "平均成本", value: "$125,430", color: .blue)
                        MetricRow(title: "資金運用率", value: "78.5%", color: .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 市場對比
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(.teal)
                            Text("市場對比")
                                .font(.headline)
                                .foregroundColor(.teal)
                        }
                        
                        MetricRow(title: "vs 大盤", value: "+12.3%", color: .green)
                        MetricRow(title: "vs 同業", value: "+8.7%", color: .green)
                        MetricRow(title: "β係數", value: "1.15", color: .orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 新增：風險警示和改善建議
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                        Text("智能建議")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                    
                    VStack(spacing: 12) {
                        // 風險警示
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("科技股集中度過高，建議分散到傳統產業")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        
                        // 正面建議
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("持有週期適中，投資紀律良好")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        // 改善建議
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text("考慮增加債券配置以降低整體波動")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.surfaceSecondary.opacity(0.5))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 風險分析內容
    private var riskAnalysisContent: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 風險雷達圖 (暫時用圓形指示器替代)
            riskRadarChart
            
            // 風險指標說明
            VStack(alignment: .leading, spacing: 8) {
                Text("風險分析")
                    .font(.headline)
                    .adaptiveTextColor()
                
                riskIndicator("市場風險", 0.6, .danger)
                riskIndicator("集中度風險", 0.4, .warning)
                riskIndicator("流動性風險", 0.3, .success)
                riskIndicator("波動率風險", 0.7, .brandOrange)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - 成就系統內容
    private var achievementsContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                ForEach(performanceData.achievements, id: \.id) { achievement in
                    achievementCard(achievement)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 詳細指標卡片
    private var detailedMetricsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("詳細指標")
                .font(.headline)
                .adaptiveTextColor()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignTokens.spacingSM) {
                detailedMetric("總報酬", String(format: "%@%.2f%%", performanceData.totalReturn >= 0 ? "+" : "", performanceData.totalReturn * 100))
                detailedMetric("年化報酬", String(format: "%@%.2f%%", performanceData.annualizedReturn >= 0 ? "+" : "", performanceData.annualizedReturn * 100))
                detailedMetric("最大回撤", String(format: "%.2f%%", performanceData.maxDrawdown * 100))
                detailedMetric("夏普比率", performanceData.sharpeRatio != nil ? String(format: "%.2f", performanceData.sharpeRatio!) : "N/A")
                detailedMetric("勝率", String(format: "%.0f%%", performanceData.winRate * 100))
                detailedMetric("平均持有", String(format: "%.0f天", performanceData.avgHoldingDays))
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 績效歷史圖表
    private var performanceHistoryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("績效走勢")
                .font(.headline)
                .adaptiveTextColor()
            
            // TODO: 添加實際的線圖組件
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen.opacity(0.3), Color.brandGreen.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 150)
                .cornerRadius(8)
                .overlay(
                    Text("績效走勢圖")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                )
        }
        .brandCardStyle()
    }
    
    // MARK: - 排名歷史卡片
    private var rankingHistoryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("排名變化")
                .font(.headline)
                .adaptiveTextColor()
            
            // 排名歷史列表
            ForEach(performanceData.rankingHistory.suffix(5), id: \.id) { rankingPoint in
                HStack {
                    Text(formatDate(rankingPoint.date))
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                        .frame(width: 60, alignment: .leading)
                    
                    Text("#\(rankingPoint.rank)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                        .frame(width: 40, alignment: .center)
                    
                    Text("/ \(rankingPoint.totalParticipants)")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                        .frame(width: 50, alignment: .leading)
                    
                    Spacer()
                    
                    Text("前 \(Int(100 - rankingPoint.percentile))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.success.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.vertical, 2)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 輔助視圖
    private var performanceGrade: some View {
        VStack(spacing: 2) {
            Text("A+")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.success)
            
            Text("績效等級")
                .font(.caption2)
                .adaptiveTextColor(primary: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.success.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func performanceMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.caption)
                .adaptiveTextColor(primary: false)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
    
    private func metricCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .adaptiveTextColor(primary: false)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSecondary)
        .cornerRadius(12)
    }
    
    private func detailedMetric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .adaptiveTextColor(primary: false)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .adaptiveTextColor()
        }
        .padding(.vertical, 4)
    }
    
    private var riskRadarChart: some View {
        VStack {
            Text("風險雷達圖")
                .font(.headline)
                .adaptiveTextColor()
            
            // 簡化的風險圖表
            ZStack {
                Circle()
                    .stroke(Color.gray300, lineWidth: 1)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(Color.gray300, lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(Color.gray300, lineWidth: 1)
                    .frame(width: 40, height: 40)
                
                // 風險指標點
                Circle()
                    .fill(Color.danger)
                    .frame(width: 8, height: 8)
                    .offset(x: 30, y: -30)
                
                Circle()
                    .fill(Color.warning)
                    .frame(width: 8, height: 8)
                    .offset(x: -20, y: 25)
                
                Circle()
                    .fill(Color.success)
                    .frame(width: 8, height: 8)
                    .offset(x: 35, y: 20)
            }
        }
    }
    
    private func riskIndicator(_ title: String, _ level: Double, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .adaptiveTextColor()
                .frame(width: 80, alignment: .leading)
            
            ProgressView(value: level)
                .tint(color)
                .background(Color.gray300)
            
            Text("\(Int(level * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .adaptiveTextColor(primary: false)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private func achievementCard(_ achievement: Achievement) -> some View {
        HStack {
            // 成就圖標
            Image(systemName: achievement.icon)
                .foregroundColor(achievement.isUnlocked ? achievement.rarity.color : .gray400)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(achievement.isUnlocked ? achievement.rarity.color.opacity(0.1) : Color.gray200)
                )
            
            // 成就信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .adaptiveTextColor()
                    
                    Spacer()
                    
                    if achievement.isUnlocked {
                        Text("已解鎖")
                            .font(.caption2)
                            .foregroundColor(.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.success.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("\(Int(achievement.progress * 100))%")
                            .font(.caption2)
                            .adaptiveTextColor(primary: false)
                    }
                }
                
                Text(achievement.description)
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
                
                if !achievement.isUnlocked {
                    ProgressView(value: achievement.progress)
                        .tint(.brandGreen)
                        .background(Color.gray300)
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    }
    
    // MARK: - 輔助方法
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    private func loadPerformanceData() async {
        do {
            performanceData = try await tournamentService.fetchPersonalPerformance(userId: currentUserId)
        } catch {
            showingError = true
        }
    }
    
    private func refreshPerformanceData() async {
        isRefreshing = true
        await loadPerformanceData()
        isRefreshing = false
    }
}

// MARK: - 績效時間範圍
enum PerformanceTimeframe: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .week:
            return "7天"
        case .month:
            return "30天"
        case .quarter:
            return "90天"
        case .year:
            return "1年"
        case .all:
            return "全部"
        }
    }
}

// MARK: - 績效標籤
enum PerformanceTab: String, CaseIterable {
    case overview = "overview"
    case risk = "risk"
    case achievements = "achievements"
    
    var displayName: String {
        switch self {
        case .overview:
            return "總覽"
        case .risk:
            return "風險"
        case .achievements:
            return "成就"
        }
    }
    
    var iconName: String {
        switch self {
        case .overview:
            return "chart.bar.fill"
        case .risk:
            return "exclamationmark.triangle.fill"
        case .achievements:
            return "star.fill"
        }
    }
}

// MARK: - 績效分享 Sheet
struct PerformanceShareSheet: View {
    let performanceData: PersonalPerformance
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("分享我的投資績效")
                    .font(.title2)
                    .fontWeight(.bold)
                    .adaptiveTextColor()
                
                // 分享預覽
                VStack(spacing: 16) {
                    Text(String(format: "總報酬率 %@%.2f%%", performanceData.totalReturn >= 0 ? "+" : "", performanceData.totalReturn * 100))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(performanceData.totalReturn >= 0 ? .success : .danger)
                    
                    Text(String(format: "勝率 %.0f%% • %d 筆交易", performanceData.winRate * 100, performanceData.totalTrades))
                        .font(.subheadline)
                        .adaptiveTextColor(primary: false)
                }
                .padding()
                .background(Color.surfaceSecondary)
                .cornerRadius(16)
                
                Spacer()
                
                // 分享按鈕
                Button("分享到社群媒體") {
                    // TODO: 實現分享邏輯
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandGreen)
                .cornerRadius(12)
            }
            .padding()
            .adaptiveBackground()
            .navigationTitle("分享績效")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 多維度分析組件
struct MetricRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct HealthScoreRow: View {
    let title: String
    let score: Int
    let maxScore: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(score)/\(maxScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score) / CGFloat(maxScore), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 預覽
#Preview {
    PersonalPerformanceView()
        .environmentObject(ThemeManager.shared)
}
