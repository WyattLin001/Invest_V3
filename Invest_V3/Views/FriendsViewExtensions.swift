//
//  FriendsViewExtensions.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/9.
//  好友系統擴展功能
//

import SwiftUI

// MARK: - 好友群組模型
struct FriendGroup {
    let id: UUID
    let name: String
    let description: String?
    let memberCount: Int
    let color: Color
    let averageReturn: Double
    let lastActivityDate: Date
}

// MARK: - 好友資料詳情視圖
struct FriendProfileView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveConfirmation = false
    @State private var isFollowingInvestments = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 好友基本資料
                    profileHeaderSection
                    
                    // 投資績效詳情
                    performanceDetailsSection
                    
                    // 投資風格和風險等級
                    investmentStyleSection
                    
                    // 最近活動
                    recentActivitySection
                    
                    // 操作按鈕
                    actionButtonsSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("好友資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("移除好友", isPresented: $showingRemoveConfirmation) {
            Button("移除好友", role: .destructive) {
                removeFriend()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("確定要移除 \(friend.displayName) 嗎？")
        }
    }
    
    // MARK: - 資料頭部區域
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // 頭像和在線狀態
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen.opacity(0.3), Color.brandGreen.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Text(String(friend.displayName.prefix(1)))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // 在線狀態指示器
                Circle()
                    .fill(friend.onlineStatusColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.surfacePrimary, lineWidth: 3)
                    )
                    .offset(x: 45, y: 45)
            }
            
            // 基本信息
            VStack(spacing: 8) {
                Text(friend.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("@\(friend.userName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let bio = friend.bio {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 好友關係時間
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.pink)
                    Text("好友 \(formatFriendshipDuration(friend.friendshipDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 績效詳情區域
    private var performanceDetailsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.brandGreen)
                Text("投資績效")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 24) {
                performanceCard("總回報", value: friend.formattedReturn, color: friend.totalReturn >= 0 ? .success : .danger)
                performanceCard("績效評分", value: friend.formattedScore, color: .brandGreen)
                performanceCard("風險等級", value: friend.riskLevel.displayName, color: friend.riskLevelColor)
            }
            
            // 最近活動時間
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("最後活動: \(formatLastActiveTime(friend.lastActiveDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func performanceCard(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 投資風格區域
    private var investmentStyleSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.brandGreen)
                Text("投資偏好")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let style = friend.investmentStyle {
                HStack(spacing: 16) {
                    Image(systemName: style.icon)
                        .font(.title2)
                        .foregroundColor(style.color)
                        .frame(width: 40, height: 40)
                        .background(style.color.opacity(0.1))
                        .cornerRadius(20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(style.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(style.color)
                        
                        Text(getInvestmentStyleDescription(style))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            } else {
                Text("未設定投資風格")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 最近活動區域
    private var recentActivitySection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.brandGreen)
                Text("最近活動")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // 模擬最近活動
            VStack(spacing: 8) {
                activityItem("進行了股票交易", "2小時前", icon: "arrow.left.arrow.right", color: .blue)
                activityItem("更新了投資組合", "昨天", icon: "chart.pie.fill", color: .green)
                activityItem("發表了市場觀點", "3天前", icon: "bubble.left.fill", color: .orange)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func activityItem(_ description: String, _ time: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 操作按鈕區域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 主要操作按鈕
            Button(action: startChat) {
                HStack {
                    Image(systemName: "message.fill")
                    Text("開始聊天")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandGreen)
                .cornerRadius(12)
            }
            
            // 次要操作按鈕
            HStack(spacing: 12) {
                Button(action: toggleInvestmentTracking) {
                    HStack {
                        Image(systemName: isFollowingInvestments ? "star.fill" : "star")
                        Text(isFollowingInvestments ? "取消追蹤" : "追蹤投資")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isFollowingInvestments ? .orange : .primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.surfaceSecondary)
                    .cornerRadius(12)
                }
                
                Button(action: shareProfile) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.surfaceSecondary)
                    .cornerRadius(12)
                }
            }
            
            // 危險操作按鈕
            Button(action: {
                showingRemoveConfirmation = true
            }) {
                HStack {
                    Image(systemName: "person.badge.minus")
                    Text("移除好友")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 輔助方法
    private func getInvestmentStyleDescription(_ style: InvestmentStyle) -> String {
        switch style {
        case .growth: return "專注於成長型公司和未來潜力"
        case .value: return "尋找被低估的優質投資標的"
        case .dividend: return "重視穩定的現金流和股息收益"
        case .momentum: return "追蹤市場趨勢和動能變化"
        case .balanced: return "平衡風險與報酬的投資策略"
        case .tech: return "專注於科技產業的投資機會"
        case .healthcare: return "關注醫療保健領域的投資"
        case .finance: return "專精於金融服務業的投資"
        }
    }
    
    private func formatLastActiveTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分鐘前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小時前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
    
    private func formatFriendshipDuration(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        let days = Int(interval / 86400)
        
        if days < 7 {
            return "\(days)天"
        } else if days < 30 {
            return "\(days / 7)週"
        } else if days < 365 {
            return "\(days / 30)個月"
        } else {
            return "\(days / 365)年"
        }
    }
    
    // MARK: - 操作方法
    private func startChat() {
        Logger.info("💬 開始與 \(friend.displayName) 聊天", category: .ui)
        
        // 實現聊天功能
        Task {
            do {
                let chatGroup = try await ChatService.shared.getOrCreatePrivateChat(
                    withUser: friend.id
                )
                
                await MainActor.run {
                    // 導航到聊天界面
                    // navigationManager.navigateToChat(groupId: chatGroup.id)
                }
            } catch {
                Logger.error("❌ 無法開始聊天: \(error.localizedDescription)", category: .network)
            }
        }
    }
    
    private func toggleInvestmentTracking() {
        isFollowingInvestments.toggle()
        print("📈 \(isFollowingInvestments ? "開始" : "停止")追蹤 \(friend.displayName) 的投資")
    }
    
    private func shareProfile() {
        Logger.info("📤 分享 \(friend.displayName) 的資料", category: .ui)
        
        // 實現分享功能
        let shareText = "推薦投資專家：\(friend.displayName)\n" +
                       "投資回報率：\(String(format: "%.2f", friend.totalReturn))%\n" +
                       "投資風格：\(friend.investmentStyle?.displayName ?? "未知")\n" +
                       "來自 Invest_V3 投資平台"
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            activityViewController.popoverPresentationController?.sourceView = rootViewController.view
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func removeFriend() {
        Logger.info("❌ 移除好友 \(friend.displayName)", category: .ui)
        
        // 實現移除好友功能
        Task {
            do {
                try await FriendsService.shared.removeFriend(friendId: friend.id)
                
                await MainActor.run {
                    // 更新UI狀態，隐藏或移除好友卡片
                    // friendsManager.removeFriend(friend.id)
                }
                
                Logger.info("✅ 成功移除好友 \(friend.displayName)", category: .ui)
            } catch {
                Logger.error("❌ 移除好友失敗: \(error.localizedDescription)", category: .network)
            }
        }
        dismiss()
    }
}

// MARK: - 建立群組視圖
struct CreateFriendGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedColor = Color.brandGreen
    @State private var selectedFriends: Set<UUID> = []
    @State private var isCreating = false
    
    private let availableColors: [Color] = [
        .brandGreen, .blue, .purple, .orange, .pink, .cyan, .indigo, .teal
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 標題
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.brandGreen)
                        
                        Text("建立投資群組")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("組織好友一起討論投資話題")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // 表單
                    VStack(spacing: 20) {
                        // 群組名稱
                        VStack(alignment: .leading, spacing: 8) {
                            Text("群組名稱")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("輸入群組名稱", text: $groupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // 群組描述
                        VStack(alignment: .leading, spacing: 8) {
                            Text("群組描述")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("描述群組的投資主題 (可選)", text: $groupDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3, reservesSpace: true)
                        }
                        
                        // 群組顏色選擇
                        VStack(alignment: .leading, spacing: 12) {
                            Text("群組顏色")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                ForEach(availableColors, id: \.self) { color in
                                    Button(action: {
                                        selectedColor = color
                                    }) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // 預覽
                        groupPreview
                    }
                    .padding()
                    .background(Color.surfacePrimary)
                    .cornerRadius(16)
                    
                    Spacer(minLength: 30)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createGroup) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("建立")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(groupName.isEmpty || isCreating)
                    .foregroundColor(groupName.isEmpty ? .secondary : .brandGreen)
                }
            }
        }
    }
    
    // MARK: - 群組預覽
    private var groupPreview: some View {
        VStack(spacing: 12) {
            Text("預覽")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(groupName.isEmpty ? "?" : String(groupName.prefix(1)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(groupName.isEmpty ? "群組名稱" : groupName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(groupName.isEmpty ? .secondary : .primary)
                    
                    Text(groupDescription.isEmpty ? "群組描述" : groupDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.surfaceSecondary)
            .cornerRadius(12)
        }
    }
    
    // MARK: - 建立群組
    private func createGroup() {
        guard !groupName.isEmpty else { return }
        
        isCreating = true
        
        // 模擬建立群組
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCreating = false
            print("✅ 建立群組: \(groupName)")
            dismiss()
        }
    }
}

// MARK: - 預覽
#Preview("好友資料") {
    FriendProfileView(friend: Friend.mockFriends().first!)
}

#Preview("建立群組") {
    CreateFriendGroupView()
}