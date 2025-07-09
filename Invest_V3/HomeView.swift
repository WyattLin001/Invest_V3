//
//  HomeView.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//
import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @StateObject private var supabaseService = SupabaseService.shared
    @State var selectedCategory = "全部"
    @State private var showNotifications = false // 通知彈窗狀態
    @State private var showSearch = false // 搜尋彈窗狀態
    @State private var showJoinGroupSheet = false
    @State private var selectedRankingUser: RankingUser?
    @State private var selectedGroup: InvestmentGroup?
    @State private var walletBalance: Double = 0.0
    @State private var isLoadingBalance = false
    
    let categories = ["全部", "科技股", "綠能", "短期投機", "價值投資"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 頂部餘額列 (Safe-area top 54 pt)
                    balanceHeader
                    
                    // 邀請 Banner (B線功能)
                    invitationBanner
                    
                    // 排行榜區塊 (替換原來的冠軍輪播)
                    rankingSection
                    
                    // 類別篩選 (46×32 pt items)
                    categoryFilter
                    
                    // 群組列表
                    groupsList
                }
            }
            .background(Color.gray100)
            .navigationBarHidden(true)
            .ignoresSafeArea(.container, edges: .top) // 忽略頂部安全區域
                    .refreshable {
            await viewModel.loadData()
            await loadWalletBalance()
        }
            .sheet(isPresented: $showNotifications) {
                NotificationView()
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .sheet(isPresented: $showJoinGroupSheet) {
                if let user = selectedRankingUser {
                    JoinGroupRequestView(user: user)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
                await loadWalletBalance()
            }
        }
    }
    
    // MARK: - 頂部餘額列
    var balanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("餘額")
                    .font(.caption)
                    .foregroundColor(.gray600)
                
                if isLoadingBalance {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 8) {
                        Text(TokenSystem.formatTokens(walletBalance))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray900)
                        
                        // 假充值按鈕
                        Button(action: { 
                            Task {
                                await fakeTopUp()
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.brandGreen)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // 通知按鈕
                Button(action: { showNotifications = true }) {
                    ZStack {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundColor(.gray600)
                        
                        // 紅色通知點
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
                
                // 搜尋按鈕
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.gray600)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54) // Safe area top
        .padding(.bottom, 16)
        .background(Color.white)
    }
    
    // MARK: - 排行榜區塊
    var rankingSection: some View {
        VStack(spacing: 16) {
            // 時間週期選擇按鈕
            HStack(spacing: 12) {
                ForEach(RankingPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.switchPeriod(to: period)
                        }
                    }) {
                        Text(period.rawValue)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedPeriod == period ? Color.brandGreen : Color.gray200)
                            .foregroundColor(viewModel.selectedPeriod == period ? .white : .gray600)
                            .cornerRadius(20)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // 排行榜卡片 - 使用 GeometryReader 確保等寬
            GeometryReader { geometry in
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.currentRankings.prefix(3).enumerated()), id: \.element.id) { index, user in
                        Button(action: {
                            selectedRankingUser = user
                            showJoinGroupSheet = true
                        }) {
                            RankingCard(user: user, selectedPeriod: viewModel.selectedPeriod)
                                .frame(width: (geometry.size.width - 24) / 3) // 確保等寬
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 190) // 增加高度以配合卡片
        }
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - 類別篩選
    var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        viewModel.filterGroups(by: category)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray300),
            alignment: .bottom
        )
    }
    
    // MARK: - 群組列表
    var groupsList: some View {
        LazyVStack(spacing: 16) { // 增加群組間距
            ForEach(viewModel.filteredGroups) { group in
                GroupCard(
                    group: group,
                    isJoined: viewModel.joinedIds.contains(group.id)
                ) {
                    // 加入群組動作
                    selectedGroup = group
                    Task {
                        await viewModel.joinGroup(group.id)
                        // 成功加入後自動跳轉到聊天室
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToChatTab"),
                            object: group.id
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16) // 增加頂部間距
        .padding(.bottom, 32)
        .background(Color.gray100)
    }
    
    // MARK: - Helper Methods
    func getBadgeColor(for rank: Int) -> Color {
        switch rank {
        case 0: return Color(hex: "#FFD700") // 金
        case 1: return Color(hex: "#C0C0C0") // 銀
        case 2: return Color(hex: "#CD7F32") // 銅
        default: return .gray300
        }
    }
    
    // 載入錢包餘額
    private func loadWalletBalance() async {
        isLoadingBalance = true
        
        do {
            let balance = try await supabaseService.fetchWalletBalance()
            await MainActor.run {
                // balance 是從 user_balances 表獲取的 NTD 值，需要轉換為代幣顯示
                self.walletBalance = Double(balance).ntdToTokens()
                self.isLoadingBalance = false
            }
        } catch {
            await MainActor.run {
                // 如果無法獲取餘額，使用預設值
                self.walletBalance = 0.0
                self.isLoadingBalance = false
                print("❌ 載入錢包餘額失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // 假充值功能 - 增加 100 代幣（相當於 10000 NTD）
    private func fakeTopUp() async {
        do {
            // 增加 10000 NTD（相當於 100 代幣）
            try await supabaseService.updateWalletBalance(delta: 10000)
            
            await MainActor.run {
                // 直接更新顯示的代幣數量
                self.walletBalance += 100.0
                print("✅ [HomeView] 假充值成功: +100 代幣")
            }
        } catch {
            await MainActor.run {
                print("❌ [HomeView] 假充值失敗: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 排行榜卡片
struct RankingCard: View {
    let user: RankingUser
    let selectedPeriod: RankingPeriod
    
    var periodText: String {
        switch selectedPeriod {
        case .weekly:
            return "本週冠軍"
        case .quarterly:
            return "本季冠軍"
        case .yearly:
            return "本年冠軍"
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(user.badgeColor)
                    .frame(width: 50, height: 50)
                    .shadow(color: user.badgeColor.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // 獎牌圖案
                VStack(spacing: 1) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(user.rank)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // 用戶名 - 固定高度確保一致性
            Text(user.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 40) // 固定高度
            
            // 收益率 - 修復百分比顯示
            VStack(spacing: 4) {
                Text(String(format: "+%.1f%%", user.returnRate))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brandGreen)
                    .cornerRadius(12)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(periodText)
                    .font(.caption)
                    .foregroundColor(.gray600)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 170) // 增加最小高度以容納更多內容
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(user.borderColor, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 群組卡片
struct GroupCard: View {
    let group: InvestmentGroup
    let isJoined: Bool
    let onJoin: () -> Void
    
    // 根據代幣數量返回對應的圖示和文字
    private var entryFeeIcon: String {
        guard let fee = group.entryFee else { return "🆓" }
        return "🪙" // 統一使用代幣圖示
    }
    
    private var entryFeeText: String {
        guard let fee = group.entryFee else { return "免費" }
        
        if fee.contains("10") && !fee.contains("50") { // 10 代幣
            return "10 代幣"
        } else if fee.contains("20") { // 20 代幣
            return "20 代幣"
        } else if fee.contains("30") { // 30 代幣
            return "30 代幣"
        } else if fee.contains("50") { // 50 代幣
            return "50 代幣"
        } else {
            return "特殊資格"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 上半部：標題和主持人
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                        .lineLimit(1)
                    
                    Text("主持人: \(group.host)")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
                
                Spacer()
                
                // 加入群組按鈕
                Button(action: isJoined ? {} : onJoin) {
                    Text(isJoined ? "已加入" : "加入群組")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isJoined ? Color.gray400 : Color.brandOrange)
                        .cornerRadius(20)
                }
                .disabled(isJoined)
            }
            
            // 下半部：詳細資訊
            HStack {
                // 左側：回報率和分類
                VStack(alignment: .leading, spacing: 4) {
                    Text("回報率: +\(group.returnRate, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.brandGreen)
                    
                    if let category = group.category {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray200)
                            .foregroundColor(.gray600)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // 右側：入場費用（圖示替代）和成員數
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(entryFeeIcon)
                            .font(.system(size: 16))
                        
                        Text(entryFeeText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                    }
                    
                    Text("\(group.memberCount) 成員")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 加入群組請求視圖
struct JoinGroupRequestView: View {
    let user: RankingUser
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 用戶資訊
                VStack(spacing: 16) {
                    // 頭像和排名
                    ZStack {
                        Circle()
                            .fill(user.badgeColor)
                            .frame(width: 80, height: 80)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "medal.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(user.rank)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    
                    Text("回報率: +\(user.returnRate, specifier: "%.1f")%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandGreen)
                }
                
                // 加入資格
                VStack(alignment: .leading, spacing: 16) {
                    Text("加入資格要求")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                    
                    VStack(spacing: 12) {
                        requirementRow(icon: "🪙", title: "10 代幣", description: "支付群組入場費")
                        requirementRow(icon: "📈", title: "投資經驗", description: "至少完成3筆模擬交易")
                        requirementRow(icon: "🎯", title: "活躍度", description: "每週至少參與討論")
                    }
                }
                .padding(20)
                .background(Color.gray100)
                .cornerRadius(16)
                
                Spacer()
                
                // 按鈕
                VStack(spacing: 12) {
                    Button(action: {
                        // 發送加入請求
                        dismiss()
                    }) {
                        Text("發送加入請求")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandGreen)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.subheadline)
                            .foregroundColor(.gray600)
                    }
                }
            }
            .padding(24)
            .navigationTitle("加入群組")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requirementRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray600)
            }
            
            Spacer()
        }
    }
}

// MARK: - 類別標籤
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12) // 增加水平內距
                .padding(.vertical, 8) // 增加垂直內距
                .background(isSelected ? Color.brandGreen : Color.gray200)
                .foregroundColor(isSelected ? .white : .gray600)
                .cornerRadius(16) // 增加圓角半徑
        }
        // 移除固定寬度限制，讓文字自然顯示
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - HomeView 擴展
extension HomeView {
    // MARK: - 邀請 Banner (B線功能)
    var invitationBanner: some View {
        Group {
            if !viewModel.pendingInvitations.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.pendingInvitations) { invitation in
                        HStack(spacing: 12) {
                            // 邀請圖示
                            Image(systemName: "envelope.badge")
                                .font(.title2)
                                .foregroundColor(.brandBlue)
                            
                            // 邀請內容
                            VStack(alignment: .leading, spacing: 4) {
                                Text("群組邀請")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray900)
                                
                                Text("邀請您加入群組")
                                    .font(.body)
                                    .foregroundColor(.gray600)
                                
                                Text("邀請者: \(invitation.inviterName)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                            }
                            
                            Spacer()
                            
                            // 操作按鈕
                            HStack(spacing: 8) {
                                // 拒絕按鈕
                                Button(action: {
                                    Task {
                                        await viewModel.declineInvitation(invitation)
                                    }
                                }) {
                                    Text("拒絕")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray600)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray200)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isProcessingInvitation)
                                
                                // 接受按鈕
                                Button(action: {
                                    Task {
                                        await viewModel.acceptInvitation(invitation)
                                    }
                                }) {
                                    if viewModel.isProcessingInvitation {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("接受")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.brandGreen)
                                .cornerRadius(8)
                                .disabled(viewModel.isProcessingInvitation)
                            }
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.brandBlue.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
            }
        }
    }
}

#Preview {
    HomeView()
}
