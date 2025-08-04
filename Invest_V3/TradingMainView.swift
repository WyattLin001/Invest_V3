import SwiftUI

struct TradingMainView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 錦標賽Header（如果參與了錦標賽）
            if tournamentStateManager.isParticipatingInTournament {
                TournamentHeaderView()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            
            // 主要TabView
            TabView(selection: $selectedTab) {
                // 首頁 - 投資組合總覽
                HomeView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        Text("首頁")
                    }
                    .tag(0)
                
                // 股票市場
                StockMarketView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "chart.bar.fill" : "chart.bar")
                        Text("市場")
                    }
                    .tag(1)
                
                // 交易
                TradingView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                        Text("交易")
                    }
                    .tag(2)
                
                // 投資組合
                PortfolioView()
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "briefcase.fill" : "briefcase")
                        Text("投資組合")
                    }
                    .tag(3)
                
                // 排行榜
                RankingsView()
                    .tabItem {
                        Image(systemName: selectedTab == 4 ? "crown.fill" : "crown")
                        Text("排行榜")
                    }
                    .tag(4)
            }
            .accentColor(Color.brandGreen)
        }
        .background(Color(.systemBackground))
        .onAppear {
            configureTabBarAppearance()
            loadInitialData()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // 設定選中和未選中的顏色
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.brandGreen)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.brandGreen)
        ]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func loadInitialData() {
        Task {
            await tradingService.checkAuthStatus()
        }
    }
}

// MARK: - 首頁視圖
struct TradingHomeView: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用戶信息卡片
                    if let user = tradingService.currentUser {
                        UserInfoCard(user: user)
                    }
                    
                    // 投資組合摘要
                    if let portfolio = tradingService.portfolio {
                        PortfolioSummaryCard(portfolio: portfolio)
                    }
                    
                    // 今日市場熱門股票
                    HotStocksSection()
                    
                    // 最近交易
                    RecentTransactionsSection()
                }
                .padding()
            }
            .navigationTitle("投資模擬")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await tradingService.loadPortfolio()
            }
        }
    }
}

// MARK: - 用戶信息卡片
struct UserInfoCard: View {
    let user: TradingUser
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("歡迎回來")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("邀請碼")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(user.inviteCode)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.brandGreen)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現金餘額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(user.cashBalance))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("總資產")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(user.totalAssets))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.brandGreen)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 投資組合摘要卡片
struct PortfolioSummaryCard: View {
    let portfolio: TradingPortfolio
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("投資組合")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: PortfolioView()) {
                    Text("查看詳情")
                        .font(.caption)
                        .foregroundColor(Color.brandGreen)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總損益")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatCurrency(portfolio.totalProfit))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(portfolio.totalProfit >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("報酬率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TradingService.shared.formatPercentage(portfolio.cumulativeReturn))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(portfolio.cumulativeReturn >= 0 ? .green : .red)
                }
            }
            
            // 持股簡要列表
            if !portfolio.positions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(portfolio.positions.prefix(3)) { position in
                        HStack {
                            Text(position.symbol)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(position.quantity)股")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(TradingService.shared.formatCurrency(position.marketValue))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if portfolio.positions.count > 3 {
                        Text("還有 \(portfolio.positions.count - 3) 檔股票...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 熱門股票區域
struct HotStocksSection: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日熱門")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: StockMarketView()) {
                    Text("查看全部")
                        .font(.caption)
                        .foregroundColor(Color.brandGreen)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tradingService.stocks.prefix(5)) { stock in
                        StockCard(stock: stock)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - 股票卡片
struct StockCard: View {
    let stock: TradingStock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stock.symbol)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color.brandGreen)
            
            Text(TradingService.shared.formatCurrency(stock.price))
                .font(.headline)
                .fontWeight(.semibold)
            
            // 模擬漲跌
            let change = Double.random(in: -5...5)
            let changePercent = (change / stock.price) * 100
            
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "triangle.fill" : "triangle.fill")
                    .font(.caption2)
                    .foregroundColor(change >= 0 ? .green : .red)
                    .rotationEffect(change >= 0 ? .degrees(0) : .degrees(180))
                
                Text(String(format: "%.2f%%", abs(changePercent)))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .frame(width: 100, height: 80)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 最近交易區域
struct RecentTransactionsSection: View {
    @ObservedObject private var tradingService = TradingService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近交易")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
            }
            
            if tradingService.transactions.isEmpty {
                Text("尚無交易記錄")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(tradingService.transactions.prefix(3)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 交易記錄行
struct TransactionRow: View {
    let transaction: TradingTransaction
    
    var body: some View {
        HStack {
            // 交易類型圖標
            Circle()
                .fill(Color(hex: transaction.actionColor) ?? .gray)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: transaction.action == "buy" ? "plus" : "minus")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(transaction.actionText) \(transaction.symbol)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(transaction.quantity)股 @ \(TradingService.shared.formatCurrency(transaction.price))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(TradingService.shared.formatCurrency(transaction.totalAmount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// Color extension 已在 TradingAuthView.swift 中定義

#Preview {
    TradingMainView()
}