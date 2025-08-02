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
    @State private var showingQRScanner = false
    @State private var showingInviteCode = false
    @State private var showingContactImport = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView()
                .presentationBackground(Color.systemBackground)
        }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeView()
                .presentationBackground(Color.systemBackground)
        }
        .sheet(isPresented: $showingContactImport) {
            ContactImportView()
                .presentationBackground(Color.systemBackground)
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
                    showingQRScanner = true
                }
                
                quickActionButton("邀請碼", icon: "number") {
                    showingInviteCode = true
                }
                
                quickActionButton("通訊錄", icon: "person.crop.circle.badge.plus") {
                    showingContactImport = true
                }
            }
            
            #if DEBUG
            // 調試按鈕
            Button("🔍 調試權限") {
                Task {
                    do {
                        try await supabaseService.testFriendRequestPermissions()
                        await MainActor.run {
                            alertMessage = "✅ 權限測試完成，請查看控制台輸出"
                            showingAlert = true
                        }
                    } catch {
                        await MainActor.run {
                            alertMessage = "❌ 權限測試失敗: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                }
            }
            .padding(.top, 8)
            .font(.caption)
            .foregroundColor(.secondary)
            #endif
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
                .foregroundColor(.secondary)
            
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
                // 先檢查用戶認證狀態
                let currentUser = try await supabaseService.getCurrentUserAsync()
                print("✅ 當前用戶: \(currentUser.displayName) (\(currentUser.id))")
                
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
                    
                    // 顯示成功訊息
                    alertMessage = "✅ 好友請求已發送給 \(user.displayName)"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    print("❌ 發送好友請求失敗: \(error.localizedDescription)")
                    
                    // 檢查具體錯誤類型並提供對應訊息
                    if error.localizedDescription.contains("row-level security policy") {
                        alertMessage = "❌ 權限不足：請確保您已登入並有正確的權限"
                    } else if error.localizedDescription.contains("not authenticated") {
                        alertMessage = "❌ 請先登入您的帳號"
                    } else {
                        alertMessage = "❌ 發送好友請求失敗：\(error.localizedDescription)"
                    }
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - 模擬數據
    private var mockRecommendations: [FriendSearchResult] {
        [
            FriendSearchResult(
                id: UUID(),
                userId: UUID().uuidString,
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
                userId: UUID().uuidString,
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

// MARK: - QR 掃描視圖
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // QR 掃描區域模擬
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.brandGreen)
                    
                    Text("QR 掃描")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("將相機對準好友的 QR 碼以添加好友")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(Color.surfaceSecondary)
                .cornerRadius(16)
                
                // 示意說明
                VStack(alignment: .leading, spacing: 12) {
                    Text("如何使用：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundColor(.brandGreen)
                        Text("請好友打開設定頁面中的「我的 QR 碼」")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundColor(.brandGreen)
                        Text("將相機對準 QR 碼即可快速添加好友")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.surfaceSecondary.opacity(0.5))
                .cornerRadius(12)
                
                Spacer()
                
                // 模擬掃描按鈕
                Button(action: {
                    // 模擬掃描成功
                    HapticFeedback.impact(.light)
                    dismiss()
                }) {
                    Text(isScanning ? "掃描中..." : "模擬掃描")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isScanning ? Color.gray : Color.brandGreen)
                        .cornerRadius(12)
                }
                .disabled(isScanning)
            }
            .padding()
            .navigationTitle("掃描 QR 碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 邀請碼視圖
struct InviteCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 邀請碼輸入
                VStack(spacing: 16) {
                    Image(systemName: "number.square")
                        .font(.system(size: 60))
                        .foregroundColor(.brandGreen)
                    
                    Text("輸入邀請碼")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("輸入好友提供的 6 位數邀請碼")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 輸入框
                VStack(spacing: 16) {
                    TextField("輸入 6 位數邀請碼", text: $inviteCode)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.title3)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.surfaceSecondary)
                        .cornerRadius(12)
                        .onChange(of: inviteCode) { _ in
                            // 限制為 6 位數字
                            inviteCode = String(inviteCode.prefix(6).filter { $0.isNumber })
                        }
                    
                    Button(action: submitInviteCode) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isLoading ? "驗證中..." : "添加好友")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inviteCode.count == 6 && !isLoading ? Color.brandGreen : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(inviteCode.count != 6 || isLoading)
                }
                
                // 我的邀請碼
                VStack(spacing: 12) {
                    Text("我的邀請碼")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("123456")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGreen)
                            .padding()
                            .background(Color.surfaceSecondary)
                            .cornerRadius(8)
                        
                        Button(action: {
                            UIPasteboard.general.string = "123456"
                            alertMessage = "邀請碼已複製到剪貼板"
                            showingAlert = true
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.brandGreen)
                        }
                    }
                    
                    Text("分享此邀請碼給好友，讓他們快速添加您")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.surfaceSecondary.opacity(0.5))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("邀請碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submitInviteCode() {
        isLoading = true
        
        // 模擬 API 調用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            alertMessage = "邀請碼驗證成功！已發送好友請求。"
            showingAlert = true
            
            // 清空輸入
            inviteCode = ""
        }
    }
}

// MARK: - 通訊錄導入視圖
struct ContactImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var foundContacts: [MockContact] = []
    @State private var selectedContacts: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if foundContacts.isEmpty && !isImporting {
                    // 初始狀態
                    VStack(spacing: 24) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.brandGreen)
                        
                        VStack(spacing: 12) {
                            Text("從通訊錄找朋友")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("查看您的通訊錄聯絡人中\n誰已經在使用我們的應用程式")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: importContacts) {
                            Text("查找通訊錄好友")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brandGreen)
                                .cornerRadius(12)
                        }
                        
                        Text("我們將安全地檢查您的聯絡人，不會儲存任何個人資訊")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if isImporting {
                    // 載入狀態
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("正在搜尋通訊錄好友...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 顯示找到的聯絡人
                    VStack(alignment: .leading, spacing: 16) {
                        Text("找到 \(foundContacts.count) 位好友")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(foundContacts) { contact in
                                    ContactRow(
                                        contact: contact,
                                        isSelected: selectedContacts.contains(contact.id)
                                    ) {
                                        if selectedContacts.contains(contact.id) {
                                            selectedContacts.remove(contact.id)
                                        } else {
                                            selectedContacts.insert(contact.id)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Button(action: sendFriendRequests) {
                            Text("發送好友請求 (\(selectedContacts.count))")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedContacts.isEmpty ? Color.gray : Color.brandGreen)
                                .cornerRadius(12)
                        }
                        .disabled(selectedContacts.isEmpty)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("通訊錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func importContacts() {
        isImporting = true
        
        // 模擬通訊錄導入
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isImporting = false
            foundContacts = MockContact.mockContacts()
        }
    }
    
    private func sendFriendRequests() {
        // 模擬發送好友請求
        print("發送好友請求給 \(selectedContacts.count) 位聯絡人")
        dismiss()
    }
}

// MARK: - 聯絡人列項目
struct ContactRow: View {
    let contact: MockContact
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 頭像
            Circle()
                .fill(Color.systemTertiaryBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(contact.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // 聯絡人資訊
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(contact.username)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 選擇按鈕
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .brandGreen : .secondary)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(12)
    }
}

// MARK: - 模擬聯絡人模型
struct MockContact: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    
    static func mockContacts() -> [MockContact] {
        [
            MockContact(name: "王小明", username: "@wangxiaoming"),
            MockContact(name: "李美華", username: "@limeihua"),
            MockContact(name: "張志強", username: "@zhangzhiqiang"),
            MockContact(name: "陳雅婷", username: "@chenyating"),
            MockContact(name: "林大偉", username: "@lindawei")
        ]
    }
}


// MARK: - 預覽
#Preview {
    AddFriendView()
        .environmentObject(ThemeManager.shared)
}