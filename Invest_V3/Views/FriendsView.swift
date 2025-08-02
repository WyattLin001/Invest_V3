//
//  FriendsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/27.
//  好友系統主頁面
//

import SwiftUI

struct FriendsView: View {
    @State private var selectedTab: FriendsTab = .friends
    @State private var friends: [Friend] = []
    @State private var friendRequests: [FriendRequest] = []
    @State private var friendActivities: [FriendActivity] = []
    @State private var isLoading = false
    @State private var showingAddFriend = false
    @State private var showingFriendRequests = false
    @State private var searchText = ""
    
    private let supabaseService = SupabaseService.shared
    
    enum FriendsTab: String, CaseIterable {
        case friends = "好友"
        case activities = "動態"
        case requests = "請求"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .activities: return "clock.arrow.circlepath"
            case .requests: return "person.badge.plus"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航區域
                headerSection
                
                // 分段控制器
                segmentedControl
                
                // 主要內容
                TabView(selection: $selectedTab) {
                    friendsListView
                        .tag(FriendsTab.friends)
                    
                    activitiesView
                        .tag(FriendsTab.activities)
                    
                    requestsView
                        .tag(FriendsTab.requests)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .adaptiveBackground()
            .onAppear {
                loadFriendsData()
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
                    .presentationBackground(Color.systemBackground)
            }
        }
    }
    
    // MARK: - 頂部導航區域
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("好友")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(friends.count) 位好友")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // 好友請求通知
                Button(action: {
                    showingFriendRequests = true
                }) {
                    ZStack {
                        Image(systemName: "bell")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        if !friendRequests.filter({ $0.status == .pending }).isEmpty {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                // 添加好友
                Button(action: {
                    showingAddFriend = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.brandGreen.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - 分段控制器
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: .medium))
                            
                            // 請求數量徽章
                            if tab == .requests && !friendRequests.filter({ $0.status == .pending }).isEmpty {
                                Text("\(friendRequests.filter({ $0.status == .pending }).count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .brandGreen : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.brandGreen : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .background(Color.surfacePrimary)
    }
    
    // MARK: - 好友列表視圖
    private var friendsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 搜尋框
                searchBar
                
                // 好友列表
                if friends.isEmpty {
                    emptyFriendsView
                } else {
                    ForEach(filteredFriends) { friend in
                        friendCard(friend)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await refreshFriends()
        }
    }
    
    // MARK: - 搜尋框
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜尋好友...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfaceSecondary)
        .cornerRadius(10)
    }
    
    // MARK: - 好友卡片
    private func friendCard(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            // 頭像
            ZStack {
                Circle()
                    .fill(Color.systemTertiaryBackground)
                    .frame(width: 50, height: 50)
                
                if let avatarUrl = friend.avatarUrl {
                    // TODO: 實現頭像載入
                    Text(String(friend.displayName.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text(String(friend.displayName.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // 在線狀態指示器
                Circle()
                    .fill(friend.onlineStatusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.surfacePrimary, lineWidth: 2)
                    )
                    .offset(x: 18, y: 18)
            }
            
            // 用戶信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let style = friend.investmentStyle {
                        HStack(spacing: 4) {
                            Image(systemName: style.icon)
                                .font(.caption2)
                            Text(style.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(style.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(style.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Text("@\(friend.userName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let bio = friend.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 績效數據
            VStack(alignment: .trailing, spacing: 4) {
                Text(friend.formattedReturn)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(friend.totalReturn >= 0 ? .success : .danger)
                
                HStack(spacing: 4) {
                    Image(systemName: friend.riskLevel.icon)
                        .font(.caption2)
                    Text(friend.riskLevel.displayName)
                        .font(.caption2)
                }
                .foregroundColor(friend.riskLevelColor)
                
                Text("評分 \(friend.formattedScore)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 動態視圖
    private var activitiesView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if friendActivities.isEmpty {
                    emptyActivitiesView
                } else {
                    ForEach(friendActivities) { activity in
                        activityCard(activity)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await refreshActivities()
        }
    }
    
    // MARK: - 活動卡片
    private func activityCard(_ activity: FriendActivity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 活動圖標
            Image(systemName: activity.activityType.icon)
                .font(.title3)
                .foregroundColor(activity.activityType.color)
                .frame(width: 32, height: 32)
                .background(activity.activityType.color.opacity(0.1))
                .cornerRadius(16)
            
            // 活動內容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.friendName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTimestamp(activity.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 活動數據
                if let data = activity.data {
                    HStack {
                        if let symbol = data.symbol {
                            Text(symbol)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.brandGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandGreen.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if let amount = data.amount {
                            Text(String(format: "$%.0f", amount))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        if let returnRate = data.returnRate {
                            Text(String(format: "%+.1f%%", returnRate))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(returnRate >= 0 ? .success : .danger)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 請求視圖
    private var requestsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if friendRequests.isEmpty {
                    emptyRequestsView
                } else {
                    ForEach(friendRequests) { request in
                        requestCard(request)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await refreshRequests()
        }
    }
    
    // MARK: - 請求卡片
    private func requestCard(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            // 頭像
            Circle()
                .fill(Color.systemTertiaryBackground)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(request.fromUserDisplayName.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // 用戶信息
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUserDisplayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("@\(request.fromUserName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let message = request.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(formatTimestamp(request.requestDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 操作按鈕
            if request.status == .pending {
                VStack(spacing: 8) {
                    Button(action: {
                        acceptFriendRequest(request)
                    }) {
                        Text("接受")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandGreen)
                            .cornerRadius(6)
                    }
                    
                    Button(action: {
                        declineFriendRequest(request)
                    }) {
                        Text("拒絕")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.surfaceSecondary)
                            .cornerRadius(6)
                    }
                }
            } else {
                VStack {
                    HStack(spacing: 4) {
                        Image(systemName: request.status == .accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(request.status.color)
                        Text(request.status.displayName)
                            .font(.caption)
                            .foregroundColor(request.status.color)
                    }
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 空狀態視圖
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("還沒有好友")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("開始添加好友，建立投資社群")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingAddFriend = true
            }) {
                Text("添加好友")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.brandGreen)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 40)
    }
    
    private var emptyActivitiesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暫無好友動態")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("當好友進行投資活動時，動態會顯示在這裡")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyRequestsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("沒有好友請求")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("當有人向您發送好友請求時，會顯示在這裡")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 過濾好友
    private var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friends
        } else {
            return friends.filter { friend in
                friend.displayName.localizedCaseInsensitiveContains(searchText) ||
                friend.userName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - 時間格式化
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(timestamp, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: timestamp))"
        } else if calendar.isDate(timestamp, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: timestamp))"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }
    
    // MARK: - 數據載入
    private func loadFriendsData() {
        Task {
            await loadFriends()
            await loadFriendRequests()
            await loadFriendActivities()
        }
    }
    
    private func loadFriends() async {
        do {
            let loadedFriends = try await supabaseService.fetchFriends()
            await MainActor.run {
                self.friends = loadedFriends
            }
        } catch {
            print("❌ 載入好友失敗: \(error.localizedDescription)")
            #if DEBUG
            // 僅在 Debug 模式下使用模擬數據
            await MainActor.run {
                self.friends = Friend.mockFriends()
            }
            #else
            // 生產環境顯示空狀態
            await MainActor.run {
                self.friends = []
            }
            #endif
        }
    }
    
    private func loadFriendRequests() async {
        do {
            let requests = try await supabaseService.fetchFriendRequests()
            await MainActor.run {
                self.friendRequests = requests
            }
        } catch {
            print("❌ 載入好友請求失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.friendRequests = []
            }
        }
    }
    
    private func loadFriendActivities() async {
        do {
            let activities = try await supabaseService.fetchFriendActivities()
            await MainActor.run {
                self.friendActivities = activities
            }
        } catch {
            print("❌ 載入好友動態失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.friendActivities = []
            }
        }
    }
    
    private func refreshFriends() async {
        await loadFriends()
    }
    
    private func refreshActivities() async {
        await loadFriendActivities()
    }
    
    private func refreshRequests() async {
        await loadFriendRequests()
    }
    
    // MARK: - 好友請求操作
    private func acceptFriendRequest(_ request: FriendRequest) {
        Task {
            do {
                try await supabaseService.acceptFriendRequest(request.id)
                await loadFriendRequests()
                await loadFriends()
            } catch {
                print("❌ 接受好友請求失敗: \(error.localizedDescription)")
            }
        }
    }
    
    private func declineFriendRequest(_ request: FriendRequest) {
        Task {
            do {
                try await supabaseService.declineFriendRequest(request.id)
                await loadFriendRequests()
            } catch {
                print("❌ 拒絕好友請求失敗: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 預覽
#Preview {
    FriendsView()
        .environmentObject(ThemeManager.shared)
}