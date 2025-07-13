import SwiftUI

// MARK: - 收益統計視圖
struct EarningsStatisticsView: View {
    @StateObject private var creatorService = CreatorRevenueService()
    @StateObject private var settlementService = MonthlySettlementService()
    @State private var selectedTimeRange: TimeRange = .lastSixMonths
    @State private var selectedCategory: StatisticsCategory = .overview
    @State private var isLoading = false
    @State private var dashboardData: CreatorDashboardData?
    
    let authorId: UUID
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 時間範圍選擇器
                timeRangeSelector()
                
                // 統計類別選擇器
                categorySelector()
                
                // 統計內容
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedCategory {
                        case .overview:
                            overviewSection()
                        case .revenue:
                            revenueSection()
                        case .articles:
                            articlesSection()
                        case .audience:
                            audienceSection()
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await loadData()
                }
            }
            .navigationTitle("收益統計")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - 時間範圍選擇器
    private func timeRangeSelector() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        selectedTimeRange = range
                        Task {
                            await loadData()
                        }
                    }) {
                        Text(range.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeRange == range ? Color(hex: "#00B900") : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 統計類別選擇器
    private func categorySelector() -> some View {
        Picker("統計類別", selection: $selectedCategory) {
            ForEach(StatisticsCategory.allCases, id: \.self) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - 概覽部分
    private func overviewSection() -> some View {
        VStack(spacing: 16) {
            // 關鍵指標卡片
            keyMetricsCard()
            
            // 收益趨勢圖
            revenueTrendChart()
            
            // 收益分佈圖
            revenueDistributionChart()
            
            // 最新結算
            latestSettlements()
        }
    }
    
    // MARK: - 關鍵指標卡片
    private func keyMetricsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("關鍵指標")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let earnings = dashboardData?.earnings {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    metricItem(
                        title: "總收益",
                        value: earnings.formattedTotalEarnings,
                        change: "+12.5%",
                        changeColor: Color(hex: "#00B900")
                    )
                    
                    metricItem(
                        title: "本月收益",
                        value: earnings.formattedCurrentMonthEarnings,
                        change: "+8.2%",
                        changeColor: Color(hex: "#00B900")
                    )
                    
                    metricItem(
                        title: "付費訂閱",
                        value: "\(earnings.paidSubscribers)",
                        change: "+15.7%",
                        changeColor: Color(hex: "#00B900")
                    )
                    
                    metricItem(
                        title: "發布文章",
                        value: "\(earnings.articlesPublished)",
                        change: "+2",
                        changeColor: Color(hex: "#00B900")
                    )
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(0..<4) { _ in
                        metricItemSkeleton()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 指標項目
    private func metricItem(title: String, value: String, change: String, changeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                Text(change)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(changeColor)
                
                Spacer()
                
                Text(selectedTimeRange.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - 指標項目骨架
    private func metricItemSkeleton() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 12)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 12)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .redacted(reason: .placeholder)
    }
    
    // MARK: - 收益趨勢圖
    private func revenueTrendChart() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收益趨勢")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 簡單的折線圖
            if let trends = dashboardData?.monthlyTrends {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(trends.indices, id: \.self) { index in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#00B900"))
                                .frame(width: 24, height: CGFloat(trends[index].earnings / 1000))
                            
                            Text(trends[index].periodLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 骨架圖
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<6) { index in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 24, height: CGFloat(30 + index * 10))
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 24, height: 12)
                        }
                    }
                }
                .redacted(reason: .placeholder)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 收益分佈圖
    private func revenueDistributionChart() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收益分佈")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                revenueDistributionItem(
                    title: "訂閱分潤",
                    percentage: 0.6,
                    color: Color(hex: "#00B900")
                )
                
                revenueDistributionItem(
                    title: "抖內收益",
                    percentage: 0.3,
                    color: Color(hex: "#FD7E14")
                )
                
                revenueDistributionItem(
                    title: "付費閱讀",
                    percentage: 0.1,
                    color: Color(hex: "#007BFF")
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 收益分佈項目
    private func revenueDistributionItem(title: String, percentage: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.1f%%", percentage * 100))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(width: geometry.size.width * percentage, height: 8)
                            Spacer()
                        }
                    )
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - 最新結算
    private func latestSettlements() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最新結算")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let settlements = dashboardData?.recentSettlements {
                ForEach(settlements.prefix(3), id: \.id) { settlement in
                    settlementRow(settlement: settlement)
                }
            } else {
                ForEach(0..<3) { _ in
                    settlementRowSkeleton()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 結算行
    private func settlementRow(settlement: MonthlySettlement) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(settlement.settlementPeriod)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(settlement.settlementStatus.displayName)
                    .font(.caption)
                    .foregroundColor(Color(hex: settlement.settlementStatus.color))
            }
            
            Spacer()
            
            Text(settlement.formattedTotalEarnings)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 結算行骨架
    private func settlementRowSkeleton() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 12)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 14)
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
    }
    
    // MARK: - 收益部分
    private func revenueSection() -> some View {
        VStack(spacing: 16) {
            Text("收益詳細分析")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 這裡可以添加更詳細的收益分析
            Text("詳細收益分析功能開發中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(40)
        }
    }
    
    // MARK: - 文章部分
    private func articlesSection() -> some View {
        VStack(spacing: 16) {
            Text("文章表現分析")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 這裡可以添加文章表現分析
            Text("文章表現分析功能開發中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(40)
        }
    }
    
    // MARK: - 觀眾部分
    private func audienceSection() -> some View {
        VStack(spacing: 16) {
            Text("觀眾分析")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 這裡可以添加觀眾分析
            Text("觀眾分析功能開發中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(40)
        }
    }
    
    // MARK: - 載入資料
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            dashboardData = try await creatorService.getCreatorDashboardData(authorId: authorId)
        } catch {
            print("載入統計資料失敗: \(error)")
        }
    }
}

// MARK: - 時間範圍枚舉
enum TimeRange: CaseIterable {
    case lastWeek
    case lastMonth
    case lastThreeMonths
    case lastSixMonths
    case lastYear
    
    var displayName: String {
        switch self {
        case .lastWeek: return "最近一週"
        case .lastMonth: return "最近一個月"
        case .lastThreeMonths: return "最近三個月"
        case .lastSixMonths: return "最近六個月"
        case .lastYear: return "最近一年"
        }
    }
}

// MARK: - 統計類別枚舉
enum StatisticsCategory: CaseIterable {
    case overview
    case revenue
    case articles
    case audience
    
    var displayName: String {
        switch self {
        case .overview: return "概覽"
        case .revenue: return "收益"
        case .articles: return "文章"
        case .audience: return "觀眾"
        }
    }
}

// MARK: - 預覽
struct EarningsStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        EarningsStatisticsView(authorId: UUID())
    }
}