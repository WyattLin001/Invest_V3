import SwiftUI

/// 群組資訊面板組件
/// 顯示群組詳細資訊、成員列表、捐贈排行榜等
struct GroupInfoPanel: View {
    let group: InvestmentGroup
    @Binding var isPresented: Bool
    
    @State private var groupMembers: [GroupMember] = []
    @State private var donationRankings: [DonationRanking] = []
    @State private var isLoadingMembers = false
    @State private var isLoadingRankings = false
    @State private var selectedTab: InfoTab = .overview
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 標籤切換
                tabSelector
                
                // 內容區域
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(InfoTab.overview)
                    
                    membersTab
                        .tag(InfoTab.members)
                    
                    rankingsTab
                        .tag(InfoTab.rankings)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("群組資訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadGroupData()
        }
    }
    
    // MARK: - 標籤選擇器
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(InfoTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .background(Color.surfaceSecondary)
    }
    
    private func tabButton(for tab: InfoTab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Text(tab.title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                
                Rectangle()
                    .frame(height: 2)
                    .opacity(selectedTab == tab ? 1 : 0)
            }
        }
        .foregroundColor(selectedTab == tab ? .brandGreen : .secondary)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 概覽標籤
    
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 群組基本信息
                groupBasicInfo
                
                // 群組統計
                groupStatistics
                
                // 群組描述
                if !group.rules.isEmpty {
                    groupDescription(group.rules.joined(separator: "\n"))
                }
                
                // 群組規則
                groupRules
            }
            .padding()
        }
    }
    
    private var groupBasicInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
                .fontWeight(.bold)
            
            InfoRow(title: "群組名稱", value: group.name)
            InfoRow(title: "主持人", value: group.host)
            InfoRow(title: "創建時間", value: formatDate(group.createdAt))
            
            if let entryFee = group.entryFee {
                InfoRow(title: "入群費用", value: entryFee)
            }
            
            if let category = group.category {
                InfoRow(title: "投資類別", value: category)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
    
    private var groupStatistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("群組統計")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                StatisticCard(
                    title: "成員數量",
                    value: "\(group.memberCount)",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                StatisticCard(
                    title: "平均回報",
                    value: String(format: "%.2f%%", group.returnRate),
                    icon: "chart.line.uptrend.xyaxis",
                    color: group.returnRate >= 0 ? .green : .red
                )
            }
            
            HStack {
                StatisticCard(
                    title: "活躍度",
                    value: getActivityStatus(),
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatisticCard(
                    title: "隱私設置",
                    value: "公開",
                    icon: "globe",
                    color: .cyan
                )
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
    
    private func groupDescription(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("群組簡介")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
    
    private var groupRules: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("群組規則")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                RuleItem("遵守投資討論主題，禁止無關聊天")
                RuleItem("尊重他人觀點，禁止人身攻擊")
                RuleItem("不得發布虛假或誤導性信息")
                RuleItem("禁止推廣未經驗證的投資產品")
                RuleItem("保護個人隱私，不透露敏感信息")
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
    
    // MARK: - 成員標籤
    
    private var membersTab: some View {
        VStack {
            if isLoadingMembers {
                ProgressView("載入成員列表...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(groupMembers) { member in
                            GroupMemberRow(member: member)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if groupMembers.isEmpty {
                loadGroupMembers()
            }
        }
    }
    
    // MARK: - 排行榜標籤
    
    private var rankingsTab: some View {
        VStack {
            if isLoadingRankings {
                ProgressView("載入排行榜...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if donationRankings.isEmpty {
                emptyRankingsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(donationRankings.enumerated()), id: \.element.id) { index, ranking in
                            DonationRankingRow(
                                ranking: ranking,
                                rank: index + 1
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if donationRankings.isEmpty {
                loadDonationRankings()
            }
        }
    }
    
    private var emptyRankingsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("暂无捐赠记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("成为第一个支持群组的成员吧！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 數據載入
    
    private func loadGroupData() {
        loadGroupMembers()
        loadDonationRankings()
    }
    
    private func loadGroupMembers() {
        isLoadingMembers = true
        
        Task {
            do {
                let members = try await GroupService.shared.getGroupMembers(groupId: group.id)
                
                await MainActor.run {
                    self.groupMembers = members
                    self.isLoadingMembers = false
                }
            } catch {
                Logger.error("❌ 載入群組成員失敗: \(error)", category: .ui)
                
                await MainActor.run {
                    self.isLoadingMembers = false
                }
            }
        }
    }
    
    private func loadDonationRankings() {
        isLoadingRankings = true
        
        Task {
            do {
                // 這裡應該調用適當的服務來獲取捐贈排行榜
                // 暫時使用模擬數據
                let mockRankings: [DonationRanking] = []
                
                await MainActor.run {
                    self.donationRankings = mockRankings
                    self.isLoadingRankings = false
                }
            } catch {
                Logger.error("❌ 載入捐贈排行榜失敗: \(error)", category: .ui)
                
                await MainActor.run {
                    self.isLoadingRankings = false
                }
            }
        }
    }
    
    // MARK: - 輔助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    private func getActivityStatus() -> String {
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(group.updatedAt)
        
        if timeSinceLastActivity < 3600 { // 1小時內
            return "非常活躍"
        } else if timeSinceLastActivity < 86400 { // 1天內
            return "活躍"
        } else if timeSinceLastActivity < 604800 { // 1週內
            return "一般"
        } else {
            return "不活躍"
        }
    }
}

// MARK: - 支持組件

enum InfoTab: CaseIterable {
    case overview
    case members
    case rankings
    
    var title: String {
        switch self {
        case .overview: return "概覽"
        case .members: return "成員"
        case .rankings: return "排行榜"
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
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

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.surfaceSecondary)
        .cornerRadius(8)
    }
}

struct RuleItem: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.brandGreen)
                .fontWeight(.bold)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

struct GroupMemberRow: View {
    let member: GroupMember
    
    var body: some View {
        HStack(spacing: 12) {
            // 成員頭像
            AsyncImage(url: URL(string: "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .overlay(
                        Text(String(member.userName.prefix(1)).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.userName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if member.role == .host {
                        Text("主持人")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandGreen)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Text("加入於 \(formatJoinDate(member.joinedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(8)
    }
    
    private func formatJoinDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct DonationRankingRow: View {
    let ranking: DonationRanking
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // 用戶信息
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(ranking.totalDonation) 金幣")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 貢獻徽章
            if rank <= 3 {
                Text(rankIcon)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(8)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color.brown
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
}

// MARK: - 數據模型

struct DonationRanking: Identifiable {
    let id = UUID()
    let userId: UUID
    let userName: String
    let totalDonation: Int
}

// MARK: - Preview

#Preview {
    GroupInfoPanel(
        group: InvestmentGroup(
            id: UUID(),
            name: "價值投資討論群",
            host: "巴菲特粉絲",
            hostId: nil,
            returnRate: 12.5,
            entryFee: "100 金幣",
            tokenCost: 100,
            memberCount: 156,
            maxMembers: 200,
            category: "價值投資",
            description: "專注於長期價值投資策略的討論群組",
            rules: "歡迎理性分析與經驗分享，禁止短線投機討論",
            isPrivate: false,
            inviteCode: nil,
            portfolioValue: 0.0,
            rankingPosition: 0,
            createdAt: Date(),
            updatedAt: Date()
        ),
        isPresented: .constant(true)
    )
}