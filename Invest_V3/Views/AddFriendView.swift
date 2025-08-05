//
//  AddFriendView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/27.
//  添加好友頁面
//

import SwiftUI
import AVFoundation

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
                
                TextField("搜尋用戶ID或名稱...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
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
    @State private var scannedCode: String = ""
    @State private var showingResult = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var scannedUserProfile: FriendSearchResult?
    @State private var isLoadingProfile = false
    
    private let supabaseService = SupabaseService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // 相機預覽背景
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // QR 掃描相機區域
                    QRCodeScannerView(
                        isScanning: $isScanning,
                        scannedCode: $scannedCode,
                        onCodeScanned: handleScannedCode
                    )
                    .frame(height: 400)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.brandGreen, lineWidth: 2)
                    )
                    
                    Spacer()
                    
                    // 使用說明
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title)
                                .foregroundColor(.brandGreen)
                            
                            Text("將相機對準好友的 QR 碼")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("掃描成功後將自動顯示好友資料")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        if isScanning {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.brandGreen)
                                Text("正在掃描...")
                                    .font(.subheadline)
                                    .foregroundColor(.brandGreen)
                            }
                        } else if isLoadingProfile {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.brandGreen)
                                Text("載入用戶資料...")
                                    .font(.subheadline)
                                    .foregroundColor(.brandGreen)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("掃描 QR 碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            isScanning = true
        }
        .onDisappear {
            isScanning = false
        }
        .sheet(isPresented: $showingResult) {
            if let userProfile = scannedUserProfile {
                ScannedUserProfileView(
                    userProfile: userProfile,
                    onDismiss: { dismiss() }
                )
            }
        }
        .alert("掃描錯誤", isPresented: $showingError) {
            Button("確定", role: .cancel) { 
                isScanning = true // 重新開始掃描
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleScannedCode(_ code: String) {
        guard !code.isEmpty else { return }
        
        // 處理特殊錯誤代碼
        switch code {
        case "CAMERA_PERMISSION_DENIED":
            showError("需要相機權限\n請到設定 > 隱私權與安全性 > 相機，允許此應用程式使用相機")
            return
        case "CAMERA_UNAVAILABLE":
            showError("無法使用相機\n請確認設備有可用的相機")
            return
        case "CAMERA_SETUP_FAILED":
            showError("相機設置失敗\n請稍後再試或重新啟動應用程式")
            return
        default:
            break
        }
        
        print("✅ [QRScannerView] 掃描到 QR 碼: \(code)")
        
        // 暫停掃描避免重複觸發
        isScanning = false
        
        // 解析深度連結
        if let userId = parseDeepLink(code) {
            // 檢查是否是自己的 QR 碼
            Task {
                await checkAndFetchUserProfile(userId: userId)
            }
        } else {
            showError("無效的 QR 碼格式\n請確認這是從 Invest V3 應用程式生成的 QR 碼")
        }
    }
    
    private func checkAndFetchUserProfile(userId: String) async {
        do {
            let currentUser = try await supabaseService.getCurrentUserAsync()
            
            // 檢查是否掃描到自己的 QR 碼
            if userId == currentUser.id.uuidString {
                await MainActor.run {
                    self.showError("這是您自己的 QR 碼\n請掃描好友的 QR 碼來添加好友")
                }
                return
            }
            
            // 獲取用戶資料
            await fetchUserProfile(userId: userId)
            
        } catch {
            await MainActor.run {
                self.showError("驗證用戶失敗: \(error.localizedDescription)")
            }
        }
    }
    
    private func parseDeepLink(_ code: String) -> String? {
        // 解析 investv3://user/{id} 格式
        let prefix = "investv3://user/"
        
        if code.hasPrefix(prefix) {
            let userId = String(code.dropFirst(prefix.count))
            return userId.isEmpty ? nil : userId
        }
        
        return nil
    }
    
    private func fetchUserProfile(userId: String) async {
        await MainActor.run {
            self.isLoadingProfile = true
        }
        
        do {
            // 先嘗試按 UUID 直接查詢
            let userProfile = try await fetchUserByUUID(userId)
            
            await MainActor.run {
                self.isLoadingProfile = false
                if let profile = userProfile {
                    self.scannedUserProfile = profile
                    self.showingResult = true
                } else {
                    self.showError("找不到該用戶")
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingProfile = false
                self.showError("載入用戶資料失敗: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchUserByUUID(_ userId: String) async throws -> FriendSearchResult? {
        // 驗證 UUID 格式
        guard UUID(uuidString: userId) != nil else {
            throw NSError(domain: "QRScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "無效的用戶 ID 格式"])
        }
        
        let currentUser = try await supabaseService.getCurrentUserAsync()
        
        // 直接按 UUID 查詢用戶資料
        let profiles: [UserProfileResponse] = try await supabaseService.client
            .from("user_profiles")
            .select()
            .eq("id", value: userId)
            .neq("id", value: currentUser.id.uuidString) // 排除自己
            .limit(1)
            .execute()
            .value
        
        guard let profile = profiles.first else {
            return nil
        }
        
        // 檢查好友狀態
        let friendIds = try await supabaseService.getFriendIds(userId: currentUser.id)
        let pendingRequestIds = try await supabaseService.getPendingRequestIds(userId: currentUser.id)
        
        let isAlreadyFriend = friendIds.contains(profile.id)
        let hasPendingRequest = pendingRequestIds.contains(profile.id)
        
        // 轉換為 FriendSearchResult
        return FriendSearchResult(
            id: UUID(),
            userId: profile.id,
            userName: profile.username,
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            bio: profile.bio,
            investmentStyle: profile.investmentStyle.flatMap { InvestmentStyle(rawValue: $0) },
            performanceScore: profile.performanceScore ?? 0.0,
            totalReturn: profile.totalReturn ?? 0.0,
            mutualFriendsCount: 0, // 可未來實作共同好友計算
            isAlreadyFriend: isAlreadyFriend,
            hasPendingRequest: hasPendingRequest
        )
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - QR 碼掃描器組件
struct QRCodeScannerView: UIViewRepresentable {
    @Binding var isScanning: Bool
    @Binding var scannedCode: String
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> QRScannerUIView {
        let scannerView = QRScannerUIView()
        scannerView.delegate = context.coordinator
        return scannerView
    }
    
    func updateUIView(_ uiView: QRScannerUIView, context: Context) {
        if isScanning {
            uiView.startScanning()
        } else {
            uiView.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRCodeScannerView
        
        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            parent.scannedCode = code
            parent.onCodeScanned(code)
        }
    }
}

// MARK: - QR 掃描器 UIView
protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class QRScannerUIView: UIView {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScannedCode: String?
    private var lastScanTime: Date?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    func startScanning() {
        guard captureSession == nil else { return }
        
        setupCaptureSession()
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
    
    private func setupCaptureSession() {
        // 檢查相機權限
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                    } else {
                        self.delegate?.didScanCode("CAMERA_PERMISSION_DENIED")
                    }
                }
            }
        case .denied, .restricted:
            delegate?.didScanCode("CAMERA_PERMISSION_DENIED")
        @unknown default:
            delegate?.didScanCode("CAMERA_PERMISSION_DENIED")
        }
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("❌ [QRScanner] 無法獲取相機設備")
            delegate?.didScanCode("CAMERA_UNAVAILABLE")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            captureSession?.addOutput(output)
            
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = bounds
            
            if let previewLayer = previewLayer {
                layer.addSublayer(previewLayer)
            }
            
            DispatchQueue.global(qos: .background).async {
                self.captureSession?.startRunning()
            }
            
        } catch {
            print("❌ [QRScanner] 設置相機失敗: \(error)")
            delegate?.didScanCode("CAMERA_SETUP_FAILED")
        }
    }
}

extension QRScannerUIView: AVCaptureMetadataOutputObjectsDelegate {
    @objc func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else { return }
        
        // 防止重複掃描同一個 QR 碼
        let now = Date()
        if let lastCode = lastScannedCode,
           let lastTime = lastScanTime,
           lastCode == code && now.timeIntervalSince(lastTime) < 2.0 {
            return
        }
        
        lastScannedCode = code
        lastScanTime = now
        
        // 觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        delegate?.didScanCode(code)
    }
}

// MARK: - 掃描結果顯示視圖
struct ScannedUserProfileView: View {
    let userProfile: FriendSearchResult
    let onDismiss: () -> Void
    
    @State private var isSendingRequest = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let supabaseService = SupabaseService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 成功掃描提示（帶動畫效果）
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.brandGreen)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0), value: UUID())
                    
                    Text("掃描成功！")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .transition(.scale.combined(with: .opacity))
                
                // 用戶資料卡片
                VStack(spacing: 16) {
                    // 頭像
                    Circle()
                        .fill(Color.gray300)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(userProfile.displayName.prefix(1)))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    // 用戶信息
                    VStack(spacing: 8) {
                        HStack {
                            Text(userProfile.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if let style = userProfile.investmentStyle {
                                HStack(spacing: 4) {
                                    Image(systemName: style.icon)
                                        .font(.caption)
                                    Text(style.displayName)
                                        .font(.caption)
                                }
                                .foregroundColor(style.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(style.color.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        Text("@\(userProfile.userName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let bio = userProfile.bio {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        
                        HStack(spacing: 16) {
                            VStack {
                                Text(String(format: "%+.1f%%", userProfile.totalReturn))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(userProfile.totalReturn >= 0 ? .success : .danger)
                                Text("總回報")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 30)
                            
                            VStack {
                                Text("\(userProfile.mutualFriendsCount)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("共同好友")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color.surfacePrimary)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // 操作按鈕
                VStack(spacing: 12) {
                    if userProfile.isAlreadyFriend {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("已是好友")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.surfaceSecondary)
                            .cornerRadius(12)
                        }
                        .disabled(true)
                    } else if userProfile.hasPendingRequest {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "clock.fill")
                                Text("好友請求已發送")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(true)
                    } else {
                        Button(action: sendFriendRequest) {
                            HStack {
                                if isSendingRequest {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "person.badge.plus.fill")
                                }
                                Text(isSendingRequest ? "發送中..." : "加為好友")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSendingRequest ? Color.gray : Color.brandGreen)
                            .cornerRadius(12)
                        }
                        .disabled(isSendingRequest)
                    }
                    
                    Button("完成") {
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.surfaceSecondary)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("掃描結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        onDismiss()
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
    
    private func sendFriendRequest() {
        isSendingRequest = true
        
        Task {
            do {
                try await supabaseService.sendFriendRequest(to: userProfile.userId)
                
                await MainActor.run {
                    self.isSendingRequest = false
                    self.alertMessage = "✅ 好友請求已發送給 \(userProfile.displayName)"
                    self.showingAlert = true
                }
                
                print("✅ [ScannedUserProfileView] 好友請求已發送")
                
            } catch {
                await MainActor.run {
                    self.isSendingRequest = false
                    self.alertMessage = "❌ 發送好友請求失敗：\(error.localizedDescription)"
                    self.showingAlert = true
                }
                
                print("❌ [ScannedUserProfileView] 發送好友請求失敗: \(error)")
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