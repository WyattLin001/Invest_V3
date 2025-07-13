import SwiftUI

// MARK: - 創作者收益儀表板視圖
struct CreatorRevenueDashboardView: View {
    @StateObject private var creatorService = CreatorRevenueService()
    @StateObject private var settlementService = MonthlySettlementService()
    @State private var selectedTab = 0
    @State private var showingWithdrawalSheet = false
    @State private var showingSettlementDetail = false
    @State private var selectedSettlement: MonthlySettlement?
    
    let authorId: UUID
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 收益概覽卡片
                if let earnings = creatorService.creatorEarnings {
                    revenueOverviewCard(earnings: earnings)
                } else {
                    // 載入中狀態
                    revenueOverviewCardSkeleton()
                }
                
                // 分頁選擇器
                Picker("選項", selection: $selectedTab) {
                    Text("統計").tag(0)
                    Text("結算").tag(1)
                    Text("提領").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // 內容區域
                TabView(selection: $selectedTab) {
                    statisticsView()
                        .tag(0)
                    
                    settlementHistoryView()
                        .tag(1)
                    
                    withdrawalView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("創作者收益")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingWithdrawalSheet) {
                WithdrawalRequestView(
                    authorId: authorId,
                    availableBalance: creatorService.creatorEarnings?.withdrawableBalance ?? 0
                )
            }
            .sheet(isPresented: $showingSettlementDetail) {
                if let settlement = selectedSettlement {
                    MonthlySettlementDetailView(settlement: settlement)
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - 收益概覽卡片
    private func revenueOverviewCard(earnings: CreatorEarnings) -> some View {
        VStack(spacing: 16) {
            // 主要收益數據
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總收益")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(earnings.formattedTotalEarnings)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("本月收益")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(earnings.formattedCurrentMonthEarnings)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#00B900"))
                }
            }
            
            // 可提領餘額
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("可提領餘額")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(earnings.formattedWithdrawableBalance)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(earnings.isEligibleForWithdrawal ? Color(hex: "#00B900") : .secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingWithdrawalSheet = true
                }) {
                    Text("提領")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(earnings.isEligibleForWithdrawal ? Color(hex: "#00B900") : Color.gray)
                        )
                }
                .disabled(!earnings.isEligibleForWithdrawal)
            }
            
            // 統計數據
            HStack {
                statisticItem(title: "發布文章", value: "\(earnings.articlesPublished)")
                Spacer()
                statisticItem(title: "付費訂閱", value: "\(earnings.paidSubscribers)")
                Spacer()
                statisticItem(title: "總追蹤", value: "\(earnings.totalFollowers)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 收益概覽卡片骨架
    private func revenueOverviewCardSkeleton() -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 32)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 24)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 20)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 32)
            }
            
            HStack {
                ForEach(0..<3) { _ in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 16)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 30, height: 20)
                    }
                    if $0 < 2 { Spacer() }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .redacted(reason: .placeholder)
    }
    
    // MARK: - 統計項目
    private func statisticItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - 統計視圖
    private func statisticsView() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 收益分佈圖
                if let earnings = creatorService.creatorEarnings {
                    revenueDistributionChart(earnings: earnings)
                }
                
                // 月度趨勢
                monthlyTrendsView()
                
                // 最佳表現文章
                topPerformingArticlesView()
            }
            .padding(16)
        }
    }
    
    // MARK: - 收益分佈圖
    private func revenueDistributionChart(earnings: CreatorEarnings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("收益分佈")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 簡單的條形圖顯示不同收益來源
            VStack(spacing: 8) {
                revenueDistributionBar(title: "訂閱收益", amount: earnings.totalEarnings * 6 / 10, color: Color(hex: "#00B900"))
                revenueDistributionBar(title: "抖內收益", amount: earnings.totalEarnings * 3 / 10, color: Color(hex: "#FD7E14"))
                revenueDistributionBar(title: "付費閱讀", amount: earnings.totalEarnings * 1 / 10, color: Color(hex: "#007BFF"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 收益分佈條形圖
    private func revenueDistributionBar(title: String, amount: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text("NT$\(amount)")
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
                                .frame(width: geometry.size.width * 0.6, height: 8)
                            Spacer()
                        }
                    )
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - 月度趨勢視圖
    private func monthlyTrendsView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月度趨勢")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 簡單的線性圖表顯示月度趨勢
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<6) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#00B900"))
                            .frame(width: 24, height: CGFloat(30 + index * 10))
                        
                        Text("\(index + 1)月")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 最佳表現文章
    private func topPerformingArticlesView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最佳表現文章")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(0..<3) { index in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("文章標題 \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("收益: NT$\(1000 - index * 200)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("#\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(index == 0 ? Color.yellow : index == 1 ? Color.gray : Color.brown)
                        )
                }
                .padding(.vertical, 4)
                
                if index < 2 {
                    Divider()
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
    
    // MARK: - 結算歷史視圖
    private func settlementHistoryView() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 結算歷史列表
                ForEach(0..<6) { index in
                    settlementHistoryItem(month: index + 1, amount: 5000 - index * 500, status: .completed)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - 結算歷史項目
    private func settlementHistoryItem(month: Int, amount: Int, status: SettlementStatus) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("2024年\(month)月")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("NT$\(amount)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: status.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: status.color).opacity(0.1))
                    )
                
                Button(action: {
                    // 顯示結算詳情
                }) {
                    Text("詳情")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#007BFF"))
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
    
    // MARK: - 提領視圖
    private func withdrawalView() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 提領申請按鈕
                Button(action: {
                    showingWithdrawalSheet = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("申請提領")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("最低提領金額 NT$1,000")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#00B900"))
                    )
                }
                .disabled(!(creatorService.creatorEarnings?.isEligibleForWithdrawal ?? false))
                
                // 提領歷史
                ForEach(0..<3) { index in
                    withdrawalHistoryItem(date: Date(), amount: 1000 + index * 500, status: .completed)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - 提領歷史項目
    private func withdrawalHistoryItem(date: Date, amount: Int, status: WithdrawalStatus) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("NT$\(amount)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: status.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: status.color).opacity(0.1))
                    )
                
                Text("銀行轉帳")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 載入數據
    private func loadData() async {
        do {
            _ = try await creatorService.getCreatorEarnings(authorId: authorId)
        } catch {
            print("載入創作者收益失敗: \(error)")
        }
    }
}

// MARK: - 預覽
struct CreatorRevenueDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        CreatorRevenueDashboardView(authorId: UUID())
    }
}