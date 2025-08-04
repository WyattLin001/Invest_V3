

//
//  SettingsView.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//


import SwiftUI
import UIKit
import PhotosUI


struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var tournamentStateManager = TournamentStateManager.shared
    
    @State private var showImagePicker = false
    @State private var showQRCodeFullScreen = false
    @State private var showLoginSheet = false // 用於顯示登入畫面
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showLogoutAlert = false
    @State private var nicknameInput = ""
    @State private var showTournamentSelector = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                HStack {
                    Text("設定")
                        .font(.titleLarge) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .frame(height: 44)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray300),
                    alignment: .bottom
                )

                // 可滑動的內容區域
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: DesignTokens.spacingLG) {
                        if authService.isAuthenticated {
                            // 個人資料區
                            profileSection
                            
                            // 好友管理
                            friendManagementSection
                            
                            // 通知設定
                            notificationSection
                            
                            // 通知測試（僅在 DEBUG 模式顯示）
                            #if DEBUG
                            notificationTestSection
                            
                            // 好友系統測試
                            friendSystemTestSection
                            #endif
                            
                            // 應用設定
                            appSettingsSection
                            
                            // 訂閱管理
                            subscriptionSection
                            
                            // 登出按鈕
                            logoutButton
                            
                        } else {
                            // 未登入時顯示登入提示
                            loginSection
                            
                            // 應用設定
                            appSettingsSection
                        }
                        
                        // 關於部分 (對所有用戶可見)
                        aboutSection
                        
                        // 底部間距
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingMD)
                }
                .background(Color.gray100)
                .refreshable {
                    Task {
                        await viewModel.loadData()
                    }
                }
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            AuthenticationView()
                .environmentObject(authService)
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            if let newItem = newItem {
                Task {
                    await viewModel.loadAndProcessImage(from: newItem)
                }
            }
        }
        .sheet(isPresented: $showQRCodeFullScreen) {
            if let qrImage = viewModel.qrCodeImage {
                 FullScreenQRCodeView(qrCodeImage: qrImage, userId: viewModel.userId)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            // 當用戶從未認證變為已認證（登入成功）時，自動關閉登入畫面
            if !oldValue && newValue && showLoginSheet {
                showLoginSheet = false
                print("📱 用戶登入成功，自動關閉登入畫面")
            }
        }
    }
    
    // MARK: - View Components (將子視圖邏輯移到這裡)

    // 未登入時顯示的區塊
    private var loginSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Text("立即登入")
                .font(.sectionHeader)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            Text("登入以同步您的個人資料、好友列表和訂閱狀態。")
                .font(.bodyText)
                .foregroundColor(.gray600)
                .multilineTextAlignment(.center)
            
            Button(action: { showLoginSheet = true }) {
                Text("登入 / 註冊")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandGreen)
                    .cornerRadius(DesignTokens.cornerRadius)
            }
        }
        .brandCardStyle()
    }

    private var profileSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 頭像顯示區域
            VStack {
                ZStack {
                    if let image = viewModel.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray300, lineWidth: 2))
                    } else {
                        Circle()
                            .fill(Color.brandGreen)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("投")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // 編輯指示器
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        )
                        .offset(x: 25, y: 25)
                }
                
                // 圖片來源選擇器
                ImageSourcePicker(selectedImage: Binding(
                    get: { viewModel.profileImage },
                    set: { newImage in
                        if let newImage = newImage {
                            Task {
                                await viewModel.processSelectedImage(newImage)
                            }
                        }
                    }
                ))
                .padding(.top, 8)
            }
            .accessibilityLabel("修改頭像")
            .accessibilityHint("點擊選擇新的頭像圖片")
            
            // 暱稱
            TextField("顯示名稱", text: $nicknameInput)
                .onChange(of: nicknameInput) { viewModel.nickname = $0 }
                .onAppear { nicknameInput = viewModel.nickname }
                .textFieldStyle(.roundedBorder)
                .font(.bodyText)
                .accessibilityLabel("用戶顯示名稱")
                .accessibilityHint("輸入您想要顯示的暱稱")

            
            // ID 和 QR code
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("用戶 ID")
                        .font(.caption)
                        .foregroundColor(.gray600)
                    Text(viewModel.userId)
                        .font(.bodyText) // 使用自定義字體
                        .fontWeight(.medium)
                        .foregroundColor(.gray900)
                }
                
                Spacer()
                
                Button(action: { showQRCodeFullScreen = true }) {
                    if let qrImage = viewModel.qrCodeImage { // 從 viewModel 獲取
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 50, height: 50)
                            .background(Color(.systemBackground))
                            .cornerRadius(DesignTokens.cornerRadiusSM)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM)
                                    .stroke(Color.gray300, lineWidth: 1)
                            )
                    } else {
                        Rectangle()
                            .fill(Color.gray300)
                            .frame(width: 50, height: 50)
                            .cornerRadius(DesignTokens.cornerRadiusSM)
                    }
                }
                .accessibilityLabel("用戶 QR Code")
                .accessibilityHint("點擊查看完整 QR Code，其他用戶可掃描此碼添加您為好友")
            }
        }
        .brandCardStyle()
    }

    private var friendManagementSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("好友管理")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            HStack(spacing: DesignTokens.spacingSM) {
                TextField("搜尋 ID 或掃描 QR Code", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {}) {
                    Text("添加")
                        .font(.bodyText) // 使用自定義字體
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(Color.brandGreen)
                        .cornerRadius(DesignTokens.cornerRadius)
                }
            }
            
            // 暫時移除好友列表 UI - 等待 Friend 模型衝突解決
            Text("好友功能暫時不可用")
                .font(.bodyText)
                .foregroundColor(.gray600)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DesignTokens.spacingLG)
            
            /*
            if viewModel.friends.isEmpty {
                Text("暫無好友")
                    .font(.bodyText) // 使用自定義字體
                    .foregroundColor(.gray600)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignTokens.spacingLG)
            } else {
                ForEach(viewModel.friends) { friend in
                    HStack(spacing: DesignTokens.spacingSM) {
                        Circle()
                            .fill(Color.gray300)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("投")
                                    .font(.bodyText) // 使用自定義字體
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.gray700)
                            )
                        
                        Text(friend.name)
                            .font(.bodyText) // 使用自定義字體
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.gray600)
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
            */
        }
        .brandCardStyle()
    }
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("通知設定")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            VStack(spacing: DesignTokens.spacingSM) {
                settingRow(
                    title: "推播通知",
                    isOn: $viewModel.notificationsEnabled
                )
                
                settingRow(
                    title: "聊天訊息",
                    isOn: $viewModel.chatNotificationsEnabled
                )
                
                settingRow(
                    title: "投資提醒",
                    isOn: $viewModel.investmentNotificationsEnabled
                )
                
                settingRow(
                    title: "市場更新",
                    isOn: $viewModel.marketUpdatesEnabled
                )
            }
        }
        .brandCardStyle()
    }
    
    #if DEBUG
    private var notificationTestSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("推播通知測試 (開發模式)")
                .font(.sectionHeader)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            Button(action: {
                // 通知測試功能暫時停用
            }) {
                HStack {
                    Image(systemName: "bell.badge")
                        .font(.title3)
                        .foregroundColor(.brandGreen)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("通知功能測試")
                            .font(.bodyText)
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                        
                        Text("測試各種推播通知功能")
                            .font(.caption)
                            .foregroundColor(.gray600)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .brandCardStyle()
    }
    
    private var friendSystemTestSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("好友系統測試 (開發模式)")
                .font(.sectionHeader)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            NavigationLink(destination: FriendsView()) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundColor(.brandGreen)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("好友管理")
                            .font(.bodyText)
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                        
                        Text("管理好友關係和動態")
                            .font(.caption)
                            .foregroundColor(.gray600)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
                .padding(.vertical, DesignTokens.spacingSM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .brandCardStyle()
    }
    #endif
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("應用設定")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .adaptiveTextColor()
            
            VStack(spacing: 0) {
                // 主題設置
                themeSettingRow
                
                Divider()
                    .dividerStyle()
                
                // 錦標賽模式切換
                tournamentModeRow
                
                Divider()
                    .dividerStyle()
                
                // 其他設定項目預留位置
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("其他設定")
                            .font(.bodyText)
                            .adaptiveTextColor()
                        Text("更多功能開發中")
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                }
                .padding(.vertical, DesignTokens.spacingMD)
                .contentShape(Rectangle())
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 主題設置行
    private var themeSettingRow: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("深色模式")
                        .font(.bodyText)
                        .adaptiveTextColor()
                    Text("選擇應用程式的外觀主題")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                }
                Spacer()
                // 當前主題顯示
                Text(ThemeManager.shared.currentMode.displayName)
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
                Image(systemName: ThemeManager.shared.currentMode.iconName)
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
            }
            .padding(.vertical, DesignTokens.spacingMD)
            
            // 主題選擇器
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(ThemeManager.ThemeMode.allCases) { mode in
                    themeOptionButton(for: mode)
                }
            }
        }
    }
    
    // MARK: - 主題選項按鈕
    private func themeOptionButton(for mode: ThemeManager.ThemeMode) -> some View {
        Button(action: {
            withAnimation(DesignTokens.themeTransition) {
                ThemeManager.shared.setTheme(mode)
            }
        }) {
            VStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: mode.iconName)
                    .font(.title3)
                    .foregroundColor(ThemeManager.shared.currentMode == mode ? .white : .systemLabel)
                
                Text(mode.displayName)
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.currentMode == mode ? .white : .systemLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .fill(ThemeManager.shared.currentMode == mode ? Color.brandGreen : Color.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(
                        ThemeManager.shared.currentMode == mode ? Color.brandGreen : DesignTokens.borderColor,
                        lineWidth: DesignTokens.borderWidthThin
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("訂閱管理")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium 會員")
                        .font(.bodyText) // 使用自定義字體
                        .fontWeight(.medium)
                        .foregroundColor(.gray900)
                    
                    Text("每月 3 代幣")
                        .font(.caption)
                        .foregroundColor(.gray600)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isSubscribed ? Color.brandGreen : Color.gray400)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.isSubscribed ? "已訂閱" : "未訂閱")
                        .font(.caption)
                        .foregroundColor(viewModel.isSubscribed ? .brandGreen : .gray600)
                }
            }
            
            if viewModel.isSubscribed {
                Button(action: {}) {
                    Text("管理訂閱")
                        .font(.bodyText) // 使用自定義字體
                        .fontWeight(.semibold)
                        .foregroundColor(.brandOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(Color.brandOrange.opacity(0.1))
                        .cornerRadius(DesignTokens.cornerRadius)
                }
            }
        }
        .brandCardStyle()
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("關於")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            VStack(spacing: DesignTokens.spacingSM) {
                aboutRow(title: "版本", value: "1.0.0")
                aboutRow(title: "服務條款", value: "", hasChevron: true)
                aboutRow(title: "隱私政策", value: "", hasChevron: true)
                aboutRow(title: "客服中心", value: "", hasChevron: true)
            }
        }
        .brandCardStyle()
    }
    
    private var logoutButton: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            Text("登出")
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(DesignTokens.cornerRadius)
        }
        .padding(.top)
        .alert("確定要登出？", isPresented: $showLogoutAlert) {
            Button("確定", role: .destructive) {
                Task {
                    await authService.signOut()
                    // 登出後自動顯示登入畫面並切換到首頁
                    await MainActor.run {
                        showLoginSheet = true
                        // 通知 ContentView 切換到首頁
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("登出後您需要重新登入才能使用完整功能。")
        }
        .accessibilityLabel("登出按鈕")
        .accessibilityHint("點擊後會要求確認是否登出帳戶")
    }
    
    // MARK: - 錦標賽模式切換
    private var tournamentModeRow: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("錦標賽模式")
                        .font(.bodyText)
                        .adaptiveTextColor()
                    Text(tournamentModeDescription)
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                }
                Spacer()
                
                Button(action: {
                    showTournamentSelector = true
                }) {
                    HStack(spacing: 4) {
                        Text(currentModeText)
                            .font(.caption)
                            .foregroundColor(.brandGreen)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.brandGreen)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandGreen.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.vertical, DesignTokens.spacingMD)
        }
        .sheet(isPresented: $showTournamentSelector) {
            TournamentModeSelector()
                .environmentObject(tournamentStateManager)
        }
    }
    
    private var currentModeText: String {
        if tournamentStateManager.isParticipatingInTournament {
            return tournamentStateManager.getCurrentTournamentDisplayName() ?? "錦標賽模式"
        } else {
            return "一般模式"
        }
    }
    
    private var tournamentModeDescription: String {
        if tournamentStateManager.isParticipatingInTournament {
            return "目前使用錦標賽投資組合"
        } else {
            return "選擇投資模式：一般交易或錦標賽"
        }
    }
    
    // MARK: - 輔助方法
    private func settingRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.bodyText) // 使用自定義字體
            .foregroundColor(.gray900)
            .toggleStyle(.switch)
            .tint(.brandGreen)
            .accessibilityLabel("\(title)設定")
            .accessibilityHint(isOn.wrappedValue ? "\(title)目前已開啟，點擊可關閉" : "\(title)目前已關閉，點擊可開啟")
    }
    
    private func aboutRow(title: String, value: String, hasChevron: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.bodyText) // 使用自定義字體
                .foregroundColor(.gray900)
            
            Spacer()
            
            if !value.isEmpty {
                Text(value)
                    .font(.bodyText) // 使用自定義字體
                    .foregroundColor(.gray600)
            }
            
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray600)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if hasChevron {
                // 處理點擊事件
            }
        }
        .accessibilityLabel(hasChevron ? "\(title)，點擊查看詳情" : "\(title): \(value)")
        .accessibilityHint(hasChevron ? "點擊查看\(title)的詳細資訊" : "")
    }
}

// MARK: - 錦標賽模式選擇器
struct TournamentModeSelector: View {
    @EnvironmentObject private var tournamentStateManager: TournamentStateManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tournamentService = TournamentService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 標題說明
                VStack(spacing: 12) {
                    Text("選擇投資模式")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("您可以在一般交易和錦標賽模式之間切換")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 模式選項
                VStack(spacing: 16) {
                    // 一般模式
                    ModeOptionCard(
                        title: "一般模式",
                        description: "使用您的個人投資組合進行交易",
                        icon: "chart.bar.fill",
                        isSelected: !tournamentStateManager.isParticipatingInTournament,
                        action: {
                            Task {
                                await switchToGeneralMode()
                            }
                        }
                    )
                    
                    // 錦標賽模式
                    if !tournamentStateManager.enrolledTournaments.isEmpty {
                        ForEach(availableTournaments, id: \.id) { tournament in
                            ModeOptionCard(
                                title: tournament.name,
                                description: "參與錦標賽：\(formatCurrency(tournament.initialBalance)) 起始資金",
                                icon: "trophy.fill",
                                isSelected: tournamentStateManager.isParticipatingInTournament && 
                                           tournamentStateManager.getCurrentTournamentId() == tournament.id,
                                action: {
                                    Task {
                                        await switchToTournamentMode(tournament)
                                    }
                                }
                            )
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("尚未參加任何錦標賽")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("前往錦標賽頁面參加錦標賽後即可切換模式")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await tournamentService.loadTournaments()
            }
        }
    }
    
    private var availableTournaments: [Tournament] {
        return tournamentService.tournaments.filter { tournament in
            tournamentStateManager.enrolledTournaments.contains(tournament.id)
        }
    }
    
    private func switchToGeneralMode() async {
        await tournamentStateManager.leaveTournament()
        dismiss()
    }
    
    private func switchToTournamentMode(_ tournament: Tournament) async {
        await tournamentStateManager.updateTournamentContext(tournament)
        dismiss()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "NT$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
}

// MARK: - 模式選項卡片
struct ModeOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.brandGreen : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // 內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 選中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.brandGreen)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.brandGreen : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 預覽
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthenticationService.shared)
    }
}
