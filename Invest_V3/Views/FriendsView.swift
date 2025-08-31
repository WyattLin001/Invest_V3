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
    
    // Enhanced features
    @State private var sortOption: FriendSortOption = .name
    @State private var filterOption: FriendFilterOption = .all
    @State private var showingFilters = false
    @State private var showingFriendProfile = false
    @State private var selectedFriend: Friend?
    @State private var friendsCache: [String: Friend] = [:]
    @State private var lastRefreshTime: Date = Date()
    @State private var isAutoRefreshEnabled = true
    @State private var refreshTimer: Timer?
    @State private var showingCreateGroup = false
    
    private let supabaseService = SupabaseService.shared
    
    enum FriendsTab: String, CaseIterable {
        case friends = "好友"
        case activities = "動態"
        case requests = "請求"
        case groups = "群組"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .activities: return "clock.arrow.circlepath"
            case .requests: return "person.badge.plus"
            case .groups: return "person.3.fill"
            }
        }
    }
    
    enum FriendSortOption: String, CaseIterable {
        case name = "姓名"
        case lastActive = "最近活動"
        case performance = "績效"
        case friendshipDate = "好友時間"
        
        var icon: String {
            switch self {
            case .name: return "textformat"
            case .lastActive: return "clock"
            case .performance: return "chart.line.uptrend.xyaxis"
            case .friendshipDate: return "calendar"
            }
        }
    }
    
    enum FriendFilterOption: String, CaseIterable {
        case all = "全部"
        case online = "在線"
        case investmentStyle = "投資風格"
        case performance = "高績效"
        
        var icon: String {
            switch self {
            case .all: return "line.horizontal.3"
            case .online: return "circle.fill"
            case .investmentStyle: return "chart.pie.fill"
            case .performance: return "star.fill"
            }
        }
    }
    
    var body: some View {
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
                
                friendGroupsView
                    .tag(FriendsTab.groups)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("好友")
        .navigationBarTitleDisplayMode(.inline)
        .adaptiveBackground()
        .onAppear {
            loadFriendsData()
            if isAutoRefreshEnabled {
                startAutoRefresh()
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView()
                .presentationBackground(Color.systemBackground)
        }
        .sheet(isPresented: $showingFriendProfile) {
            if let friend = selectedFriend {
                FriendProfileView(friend: friend)
                    .presentationBackground(Color.systemBackground)
            }
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateFriendGroupView()
                .presentationBackground(Color.systemBackground)
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
                // 篩選和排序
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFilters.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(showingFilters ? .brandGreen : .primary)
                }
                
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
                
                // 自動刷新控制
                Button(action: {
                    isAutoRefreshEnabled.toggle()
                    if isAutoRefreshEnabled {
                        startAutoRefresh()
                    } else {
                        stopAutoRefresh()
                    }
                }) {
                    Image(systemName: isAutoRefreshEnabled ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .font(.title2)
                        .foregroundColor(isAutoRefreshEnabled ? .brandGreen : .secondary)
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
        VStack(spacing: 0) {
            // 篩選和排序選項
            if showingFilters {
                filtersAndSortingView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 搜尋框
                    searchBar
                    
                    // 快速篩選標籤
                    quickFiltersView
                    
                    // 好友統計概覽
                    friendsStatsView
                    
                    // 好友列表
                    if friends.isEmpty {
                        emptyFriendsView
                    } else {
                        ForEach(sortedAndFilteredFriends) { friend in
                            enhancedFriendCard(friend)
                                .onTapGesture {
                                    selectedFriend = friend
                                    showingFriendProfile = true
                                }
                        }
                    }
                    
                    // 載入更多指示器
                    if isLoading {
                        ProgressView("載入中...")
                            .padding()
                    }
                }
                .padding()
            }
            .refreshable {
                await refreshFriends()
            }
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
    
    // MARK: - 增強好友卡片
    private func enhancedFriendCard(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            // 頭像和狀態
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen.opacity(0.3), Color.brandGreen.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                if let avatarUrl = friend.avatarUrl, let url = URL(string: avatarUrl) {
                    // 實現頭像載入
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text(String(friend.displayName.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                } else {
                    Text(String(friend.displayName.prefix(1)))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // 在線狀態指示器
                Circle()
                    .fill(friend.onlineStatusColor)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.surfacePrimary, lineWidth: 3)
                    )
                    .offset(x: 22, y: 22)
                
                // 新活動指示器
                if hasRecentActivity(friend) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.surfacePrimary, lineWidth: 2)
                        )
                        .offset(x: -22, y: -22)
                }
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
                    
                    Spacer()
                    
                    // 最近活動時間
                    Text(formatLastActiveTime(friend.lastActiveDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                
                // 好友關係時間
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.pink)
                    Text("好友 \(formatFriendshipDuration(friend.friendshipDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 績效和操作
            VStack(alignment: .trailing, spacing: 8) {
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
                
                // 快速操作按鈕
                HStack(spacing: 6) {
                    Button(action: {
                        startChatWithFriend(friend)
                    }) {
                        Image(systemName: "message.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.brandGreen)
                            .cornerRadius(14)
                    }
                    
                    Menu {
                        Button("查看資料", systemImage: "person.circle") {
                            selectedFriend = friend
                            showingFriendProfile = true
                        }
                        Button("追蹤投資", systemImage: "chart.line.uptrend.xyaxis") {
                            trackFriendInvestment(friend)
                        }
                        Button("分享資料", systemImage: "square.and.arrow.up") {
                            shareFriend(friend)
                        }
                        Divider()
                        Button("移除好友", systemImage: "person.badge.minus", role: .destructive) {
                            removeFriend(friend)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.surfaceSecondary)
                            .cornerRadius(14)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(friend.isOnline ? Color.brandGreen.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(friend.isOnline ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: friend.isOnline)
    }
    
    // MARK: - 原始好友卡片 (保留為備用)
    private func friendCard(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            // 頭像
            ZStack {
                Circle()
                    .fill(Color.systemTertiaryBackground)
                    .frame(width: 50, height: 50)
                
                if let avatarUrl = friend.avatarUrl, let url = URL(string: avatarUrl) {
                    // 實現頭像載入
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                    } placeholder: {
                        Text(String(friend.displayName.prefix(1)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 50, height: 50)
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
    
    // MARK: - 篩選和排序視圖
    private var filtersAndSortingView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("篩選和排序")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("重設") {
                    sortOption = .name
                    filterOption = .all
                }
                .foregroundColor(.brandGreen)
            }
            
            // 排序選項
            VStack(alignment: .leading, spacing: 8) {
                Text("排序方式")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FriendSortOption.allCases, id: \.self) { option in
                            sortChip(option: option)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // 篩選選項
            VStack(alignment: .leading, spacing: 8) {
                Text("篩選條件")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FriendFilterOption.allCases, id: \.self) { option in
                            filterChip(option: option)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding()
        .background(Color.surfaceSecondary)
    }
    
    private func sortChip(option: FriendSortOption) -> some View {
        Button(action: {
            sortOption = option
        }) {
            HStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.caption2)
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(sortOption == option ? .white : .brandGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(sortOption == option ? Color.brandGreen : Color.brandGreen.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    private func filterChip(option: FriendFilterOption) -> some View {
        Button(action: {
            filterOption = option
        }) {
            HStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.caption2)
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(filterOption == option ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(filterOption == option ? Color.secondary : Color.secondary.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    // MARK: - 快速篩選標籤
    private var quickFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickFilterChip("全部", icon: "person.2", count: friends.count, isActive: filterOption == .all) {
                    filterOption = .all
                }
                
                let onlineFriends = friends.filter { $0.isOnline }
                quickFilterChip("在線", icon: "circle.fill", count: onlineFriends.count, isActive: filterOption == .online) {
                    filterOption = .online
                }
                
                let highPerformers = friends.filter { $0.totalReturn > 10 }
                quickFilterChip("高績效", icon: "star.fill", count: highPerformers.count, isActive: filterOption == .performance) {
                    filterOption = .performance
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func quickFilterChip(_ title: String, icon: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(isActive ? .brandGreen : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .brandGreen : .secondary)
                
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isActive ? Color.brandGreen : Color.secondary)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.brandGreen.opacity(0.1) : Color.surfaceSecondary)
            .cornerRadius(20)
        }
    }
    
    // MARK: - 好友統計概覽
    private var friendsStatsView: some View {
        HStack(spacing: 16) {
            statsCard(title: "好友總數", value: "\(friends.count)", icon: "person.2.fill", color: .brandGreen)
            
            let onlineCount = friends.filter { $0.isOnline }.count
            statsCard(title: "在線好友", value: "\(onlineCount)", icon: "circle.fill", color: .green)
            
            let avgReturn = friends.isEmpty ? 0.0 : friends.map { $0.totalReturn }.reduce(0, +) / Double(friends.count)
            statsCard(title: "平均績效", value: String(format: "%.1f%%", avgReturn), icon: "chart.line.uptrend.xyaxis", color: avgReturn >= 0 ? .success : .danger)
        }
        .padding(.horizontal)
    }
    
    private func statsCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 過濾和排序好友
    private var sortedAndFilteredFriends: [Friend] {
        var filtered = friends
        
        // 搜尋篩選
        if !searchText.isEmpty {
            filtered = filtered.filter { friend in
                friend.displayName.localizedCaseInsensitiveContains(searchText) ||
                friend.userName.localizedCaseInsensitiveContains(searchText) ||
                (friend.bio?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 條件篩選
        switch filterOption {
        case .all:
            break
        case .online:
            filtered = filtered.filter { $0.isOnline }
        case .investmentStyle:
            filtered = filtered.filter { $0.investmentStyle != nil }
        case .performance:
            filtered = filtered.filter { $0.totalReturn > 10 }
        }
        
        // 排序
        switch sortOption {
        case .name:
            filtered = filtered.sorted { $0.displayName < $1.displayName }
        case .lastActive:
            filtered = filtered.sorted { $0.lastActiveDate > $1.lastActiveDate }
        case .performance:
            filtered = filtered.sorted { $0.totalReturn > $1.totalReturn }
        case .friendshipDate:
            filtered = filtered.sorted { $0.friendshipDate > $1.friendshipDate }
        }
        
        return filtered
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
            #if DEBUG
            await MainActor.run {
                self.friendRequests = FriendRequest.mockRequests()
            }
            #else
            await MainActor.run {
                self.friendRequests = []
            }
            #endif
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
            #if DEBUG
            await MainActor.run {
                self.friendActivities = FriendActivity.mockActivities()
            }
            #else
            await MainActor.run {
                self.friendActivities = []
            }
            #endif
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
    
    // MARK: - 好友群組視圖
    private var friendGroupsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 新建群組按鈕
                Button(action: {
                    showingCreateGroup = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.brandGreen)
                        
                        VStack(alignment: .leading) {
                            Text("建立新群組")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("組織好友進行投資討論")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.surfacePrimary)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                // 群組列表 (模擬數據)
                ForEach(mockFriendGroups, id: \.id) { group in
                    friendGroupCard(group)
                }
            }
            .padding()
        }
    }
    
    private func friendGroupCard(_ group: FriendGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(group.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(group.name.prefix(1)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(group.memberCount) 位成員")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("平均績效")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%+.1f%%", group.averageReturn))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(group.averageReturn >= 0 ? .success : .danger)
                }
            }
            
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text("最近活動: \(formatTimestamp(group.lastActivityDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("加入討論") {
                    // 實現加入群組功能
                    joinGroupDiscussion(group)
                }
                .font(.caption)
                .foregroundColor(.brandGreen)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 輔助功能
    private func hasRecentActivity(_ friend: Friend) -> Bool {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return friend.lastActiveDate > oneHourAgo
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
    
    // MARK: - 好友操作
    private func startChatWithFriend(_ friend: Friend) {
        Logger.info("💬 開始與 \(friend.displayName) 聊天", category: .ui)
        
        // 實現聊天功能
        Task {
            do {
                // 檢查是否已有聊天群組或創建私人聊天
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
    
    private func trackFriendInvestment(_ friend: Friend) {
        Logger.info("📈 追蹤 \(friend.displayName) 的投資", category: .ui)
        
        // 實現追蹤投資功能
        Task {
            do {
                try await FriendsService.shared.followUserInvestments(
                    userId: friend.id
                )
                
                await MainActor.run {
                    // 更新UI狀態，顯示已追蹤
                    // friend.isTracking = true
                }
                
                Logger.info("✅ 成功追蹤 \(friend.displayName) 的投資", category: .ui)
            } catch {
                Logger.error("❌ 追蹤投資失敗: \(error.localizedDescription)", category: .network)
            }
        }
    }
    
    private func shareFriend(_ friend: Friend) {
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
        
        // 在適當的視窗中呈現分享界面
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            activityViewController.popoverPresentationController?.sourceView = rootViewController.view
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func removeFriend(_ friend: Friend) {
        Logger.info("❌ 移除好友 \(friend.displayName)", category: .ui)
        
        // 實現移除好友功能
        Task {
            do {
                try await FriendsService.shared.removeFriend(friendId: friend.id)
                
                await MainActor.run {
                    // 從好友列表中移除
                    if let index = friends.firstIndex(where: { $0.id == friend.id }) {
                        friends.remove(at: index)
                    }
                }
                
                Logger.info("✅ 成功移除好友 \(friend.displayName)", category: .ui)
            } catch {
                Logger.error("❌ 移除好友失敗: \(error.localizedDescription)", category: .network)
            }
        }
    }
    
    private func joinGroupDiscussion(_ group: FriendGroup) {
        Logger.info("🏠 加入群組討論: \(group.name)", category: .ui)
        
        // 實現加入群組功能
        Task {
            do {
                try await SupabaseService.shared.joinGroup(group.id)
                
                await MainActor.run {
                    // 導航到群組聊天室
                    // navigationManager.navigateToGroupChat(groupId: group.id)
                }
                
                Logger.info("✅ 成功加入群組 \(group.name)", category: .ui)
            } catch {
                Logger.error("❌ 加入群組失敗: \(error.localizedDescription)", category: .network)
                
                await MainActor.run {
                    // 顯示錯誤提示
                    // showError("無法加入群組: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 自動刷新
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await refreshFriendsQuietly()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshFriendsQuietly() async {
        do {
            let loadedFriends = try await supabaseService.fetchFriends()
            await MainActor.run {
                // 更新緩存
                for friend in loadedFriends {
                    friendsCache[friend.userId] = friend
                }
                self.friends = loadedFriends
                self.lastRefreshTime = Date()
            }
        } catch {
            // 靜默失敗，不顯示錯誤
            print("⚠️ 自動刷新失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 模擬數據
    private var mockFriendGroups: [FriendGroup] {
        [
            FriendGroup(
                id: UUID(),
                name: "科技股投資群",
                description: "專注於科技股的投資討論和分析",
                memberCount: 12,
                color: .cyan,
                averageReturn: 15.2,
                lastActivityDate: Date().addingTimeInterval(-3600)
            ),
            FriendGroup(
                id: UUID(),
                name: "價值投資者",
                description: "尋找被低估的優質股票",
                memberCount: 8,
                color: .blue,
                averageReturn: 12.8,
                lastActivityDate: Date().addingTimeInterval(-7200)
            ),
            FriendGroup(
                id: UUID(),
                name: "股息投資群",
                description: "追求穩定現金流的投資策略",
                memberCount: 15,
                color: .purple,
                averageReturn: 8.5,
                lastActivityDate: Date().addingTimeInterval(-10800)
            )
        ]
    }
}

// MARK: - 預覽
#Preview {
    FriendsView()
        .environmentObject(ThemeManager.shared)
}