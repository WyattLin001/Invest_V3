//
//  AddFriendView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/27.
//  添加好友頁面
//

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [FriendSearchResult] = []
    @State private var isSearching = false
    @State private var searchHistory: [String] = []
    @State private var selectedInvestmentStyle: InvestmentStyle?
    @State private var selectedRiskLevel: RiskLevel?
    @State private var showingFilters = false
    
    private let supabaseService = SupabaseService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜尋區域
                searchSection
                
                // 篩選器
                if showingFilters {
                    filtersSection
                }
                
                // 搜尋結果或推薦
                contentSection
            }
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingFilters.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(showingFilters ? .brandGreen : .primary)
                    }
                }
            }
            .adaptiveBackground()
        }
    }
    
    // MARK: - 搜尋區域
    private var searchSection: some View {
        VStack(spacing: 12) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜尋用戶名稱或代號...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.surfaceSecondary)
            .cornerRadius(10)
            
            // 快速操作
            HStack(spacing: 12) {
                quickActionButton("掃描QR碼", icon: "qrcode.viewfinder") {
                    // TODO: QR碼掃描功能
                }
                
                quickActionButton("邀請碼", icon: "number") {
                    // TODO: 邀請碼功能
                }
                
                quickActionButton("通訊錄", icon: "person.crop.circle.badge.plus") {
                    // TODO: 通訊錄導入功能
                }
            }
        }
        .padding()
        .background(Color.surfacePrimary)
    }
    
    // MARK: - 快速操作按鈕
    private func quickActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.brandGreen)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.surfaceSecondary)
            .cornerRadius(8)
        }
    }
    
    // MARK: - 篩選器區域
    private var filtersSection: some View {
        VStack(spacing: 16) {
            // 投資風格篩選
            VStack(alignment: .leading, spacing: 8) {
                Text("投資風格")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 全部選項
                        filterChip(
                            title: "全部",
                            isSelected: selectedInvestmentStyle == nil,
                            color: .gray
                        ) {
                            selectedInvestmentStyle = nil
                        }
                        
                        ForEach(InvestmentStyle.allCases, id: \.self) { style in
                            filterChip(
                                title: style.displayName,
                                isSelected: selectedInvestmentStyle == style,
                                color: style.color
                            ) {
                                selectedInvestmentStyle = selectedInvestmentStyle == style ? nil : style
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 風險等級篩選
            VStack(alignment: .leading, spacing: 8) {
                Text("風險等級")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // 全部選項
                    filterChip(
                        title: "全部",
                        isSelected: selectedRiskLevel == nil,
                        color: .gray
                    ) {
                        selectedRiskLevel = nil
                    }
                    
                    ForEach(RiskLevel.allCases, id: \.self) { level in
                        filterChip(
                            title: level.displayName,
                            isSelected: selectedRiskLevel == level,
                            color: .blue
                        ) {
                            selectedRiskLevel = selectedRiskLevel == level ? nil : level
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color.surfaceSecondary)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - 篩選器標籤
    private func filterChip(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(16)
        }
    }
    
    // MARK: - 主要內容區域
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isSearching {
                    loadingView
                } else if !searchText.isEmpty && searchResults.isEmpty {
                    noResultsView
                } else if searchResults.isEmpty {
                    recommendationsSection
                } else {
                    searchResultsSection
                }
            }
            .padding()
        }
    }
    
    // MARK: - 搜尋結果區域
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("搜尋結果")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ForEach(searchResults) { result in
                searchResultCard(result)
            }
        }
    }
    
    // MARK: - 推薦區域
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 推薦好友
            VStack(alignment: .leading, spacing: 12) {
                Text("推薦好友")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("根據您的投資風格和偏好推薦")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(mockRecommendations) { result in
                    searchResultCard(result)
                }
            }
            
            // 最近搜尋
            if !searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近搜尋")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(searchHistory, id: \.self) { query in
                        Button(action: {
                            searchText = query
                            performSearch()
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                
                                Text(query)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 搜尋結果卡片
    private func searchResultCard(_ result: FriendSearchResult) -> some View {
        HStack(spacing: 12) {
            // 頭像
            Circle()
                .fill(Color.gray300)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(result.displayName.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // 用戶信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let style = result.investmentStyle {
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
                
                Text("@\(result.userName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let bio = result.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(result.mutualFriendsText)
                    .font(.caption2)
                    .foregroundColor(.brandGreen)
            }
            
            Spacer()
            
            // 操作按鈕
            VStack(spacing: 8) {
                if result.isAlreadyFriend {
                    Text("已是好友")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.surfaceSecondary)
                        .cornerRadius(6)
                } else if result.hasPendingRequest {
                    Text("已發送")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    Button(action: {
                        sendFriendRequest(to: result)
                    }) {
                        Text("加好友")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandGreen)
                            .cornerRadius(6)
                    }
                }
                
                Text(String(format: "%+.1f%%", result.totalReturn))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(result.totalReturn >= 0 ? .success : .danger)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 載入視圖
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("搜尋中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 無結果視圖
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray400)
            
            Text("未找到用戶")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("請檢查用戶名稱或嘗試其他搜尋條件")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 搜尋功能
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 添加到搜尋歷史
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchHistory.contains(trimmedQuery) {
            searchHistory.insert(trimmedQuery, at: 0)
            if searchHistory.count > 5 {
                searchHistory = Array(searchHistory.prefix(5))
            }
        }
        
        isSearching = true
        
        Task {
            do {
                let results = try await supabaseService.searchUsers(
                    query: trimmedQuery,
                    investmentStyle: selectedInvestmentStyle,
                    riskLevel: selectedRiskLevel
                )
                
                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = results
                }
            } catch {
                print("❌ 搜尋用戶失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = mockSearchResults(for: trimmedQuery)
                }
            }
        }
    }
    
    // MARK: - 發送好友請求
    private func sendFriendRequest(to user: FriendSearchResult) {
        Task {
            do {
                try await supabaseService.sendFriendRequest(to: user.userId)
                print("✅ 好友請求已發送給 \(user.displayName)")
                
                // 更新搜尋結果中的狀態
                await MainActor.run {
                    if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
                        searchResults[index] = FriendSearchResult(
                            id: user.id,
                            userId: user.userId,
                            userName: user.userName,
                            displayName: user.displayName,
                            avatarUrl: user.avatarUrl,
                            bio: user.bio,
                            investmentStyle: user.investmentStyle,
                            performanceScore: user.performanceScore,
                            totalReturn: user.totalReturn,
                            mutualFriendsCount: user.mutualFriendsCount,
                            isAlreadyFriend: user.isAlreadyFriend,
                            hasPendingRequest: true
                        )
                    }
                }
            } catch {
                print("❌ 發送好友請求失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 模擬數據
    private var mockRecommendations: [FriendSearchResult] {
        [
            FriendSearchResult(
                id: UUID(),
                userId: "rec1",
                userName: "TechInvestor",
                displayName: "Tech投資者",
                avatarUrl: nil,
                bio: "專注於科技股投資，擅長分析成長型公司",
                investmentStyle: .tech,
                performanceScore: 8.5,
                totalReturn: 15.2,
                mutualFriendsCount: 3,
                isAlreadyFriend: false,
                hasPendingRequest: false
            ),
            FriendSearchResult(
                id: UUID(),
                userId: "rec2",
                userName: "ValueHunter",
                displayName: "價值獵人",
                avatarUrl: nil,
                bio: "尋找被低估的優質股票，長期價值投資",
                investmentStyle: .value,
                performanceScore: 7.8,
                totalReturn: 12.8,
                mutualFriendsCount: 1,
                isAlreadyFriend: false,
                hasPendingRequest: false
            )
        ]
    }
    
    private func mockSearchResults(for query: String) -> [FriendSearchResult] {
        // 模擬搜尋結果
        return mockRecommendations.filter { result in
            result.displayName.localizedCaseInsensitiveContains(query) ||
            result.userName.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - 預覽
#Preview {
    AddFriendView()
        .environmentObject(ThemeManager.shared)
}