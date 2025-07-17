import SwiftUI

// MARK: - 專家檔案頁面
struct ExpertProfileView: View {
    let expert: UserRanking
    @ObservedObject private var tradingService = TradingService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isFollowing = false
    @State private var showFollowAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 專家資訊卡片
                expertInfoCard
                
                // 績效統計卡片
                performanceStatsCard
                
                // 投資組合卡片
                portfolioCard
                
                // 最近交易記錄
                recentTransactionsCard
                
                // 投資策略與理念
                investmentPhilosophyCard
            }
            .padding()
        }
        .navigationTitle(expert.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                followButton
            }
        }
    }
    
    // MARK: - 專家資訊卡片
    private var expertInfoCard: some View {
        VStack(spacing: 16) {
            // 頭像和基本資訊
            HStack {
                // 專家頭像
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen, Color.brandGreen.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(expert.name.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(expert.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("第 \(expert.rank) 名")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("1.2K 追蹤者")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 核心績效指標
            HStack {
                PerformanceMetric(
                    title: "總資產",
                    value: TradingService.shared.formatCurrency(expert.totalAssets),
                    color: .primary
                )
                
                Spacer()
                
                PerformanceMetric(
                    title: "累計報酬",
                    value: TradingService.shared.formatPercentage(expert.returnRate),
                    color: expert.returnRate >= 0 ? .green : .red
                )
                
                Spacer()
                
                PerformanceMetric(
                    title: "勝率",
                    value: "72.5%",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 績效統計卡片
    private var performanceStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("績效統計")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatItem(title: "最大回撤", value: "-8.2%", color: .red)
                StatItem(title: "夏普比率", value: "1.85", color: .blue)
                StatItem(title: "年化報酬", value: "24.3%", color: .green)
                StatItem(title: "波動度", value: "15.6%", color: .orange)
                StatItem(title: "交易次數", value: "128", color: .purple)
                StatItem(title: "平均持有", value: "12天", color: .pink)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 投資組合卡片
    private var portfolioCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("投資組合")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                HoldingItem(symbol: "AAPL", name: "蘋果", percentage: 25.5, change: 2.3)
                HoldingItem(symbol: "TSLA", name: "特斯拉", percentage: 18.2, change: -1.8)
                HoldingItem(symbol: "NVDA", name: "輝達", percentage: 15.8, change: 4.5)
                HoldingItem(symbol: "GOOGL", name: "谷歌", percentage: 12.3, change: 1.2)
                
                Button(action: {
                    // 查看完整投資組合
                }) {
                    Text("查看完整投資組合")
                        .font(.caption)
                        .foregroundColor(.brandGreen)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 最近交易記錄
    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近交易")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                TransactionItem(action: "買入", symbol: "MSFT", price: 420.50, time: "2小時前", color: .green)
                TransactionItem(action: "賣出", symbol: "AMZN", price: 145.20, time: "1天前", color: .red)
                TransactionItem(action: "買入", symbol: "NVDA", price: 875.30, time: "2天前", color: .green)
                
                Button(action: {
                    // 查看完整交易記錄
                }) {
                    Text("查看完整交易記錄")
                        .font(.caption)
                        .foregroundColor(.brandGreen)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 投資策略與理念
    private var investmentPhilosophyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("投資策略與理念")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("專精領域")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack {
                    TagView(text: "科技股")
                    TagView(text: "成長股")
                    TagView(text: "AI相關")
                    TagView(text: "半導體")
                }
                
                Text("投資理念")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Text("專注於科技創新領域的長期投資機會，特別關注AI、雲端計算和半導體產業的龍頭企業。採用基本面分析結合技術分析的方式，尋找具有持續競爭優勢的優質成長股。")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 追蹤按鈕
    private var followButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFollowing.toggle()
                showFollowAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showFollowAnimation = false
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isFollowing ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .scaleEffect(showFollowAnimation ? 1.3 : 1.0)
                
                Text(isFollowing ? "已追蹤" : "追蹤")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isFollowing ? .red : .brandGreen)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isFollowing ? Color.red.opacity(0.1) : Color.brandGreen.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isFollowing ? Color.red.opacity(0.3) : Color.brandGreen.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 支援元件

struct PerformanceMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct HoldingItem: View {
    let symbol: String
    let name: String
    let percentage: Double
    let change: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(String(format: "%+.1f%%", change))
                    .font(.caption)
                    .foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TransactionItem: View {
    let action: String
    let symbol: String
    let price: Double
    let time: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(action == "買入" ? "B" : "S")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(action) \(symbol)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(TradingService.shared.formatCurrency(price))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandGreen.opacity(0.1))
            .foregroundColor(.brandGreen)
            .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        ExpertProfileView(expert: UserRanking(
            id: UUID(),
            rank: 1,
            name: "投資大師",
            totalAssets: 1250000,
            returnRate: 25.8,
            email: "expert@example.com",
            createdAt: Date()
        ))
    }
}