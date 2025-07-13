

//
//  SettingsView.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//


import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel = SettingsViewModel()
    
    @State private var showImagePicker = false
    @State private var showQRCodeFullScreen = false
    @State private var showLoginSheet = false // 用於顯示登入畫面

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
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.gray600)
                    }
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
                            
                            // 應用設定
                            appSettingsSection
                            
                            // 訂閱管理
                            subscriptionSection
                            
                            // 創作者收益
                            creatorRevenueSection
                            
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
        .sheet(isPresented: $showImagePicker) {
            // 暫時移除 ImagePickerView，因為還沒有實現
            Text("圖片選擇器")
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
            // 頭像
            Button(action: { showImagePicker = true }) {
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
            }
            
            // 暱稱
            TextField("顯示名稱", text: $viewModel.nickname)
                .textFieldStyle(.roundedBorder)
                .font(.bodyText) // 使用自定義字體
            
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
            }
        }
        .brandCardStyle()
    }
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("應用設定")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            VStack(spacing: DesignTokens.spacingSM) {
                settingRow(
                    title: "深色模式",
                    isOn: $viewModel.darkModeEnabled
                )
                
                HStack {
                    Text("語言")
                        .font(.bodyText) // 使用自定義字體
                        .foregroundColor(.gray900)
                    
                    Spacer()
                    
                    Picker("語言", selection: $viewModel.selectedLanguage) {
                        Text("繁體中文").tag("zh-TW")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .brandCardStyle()
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
    
    private var creatorRevenueSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("創作者收益")
                .font(.sectionHeader)
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            VStack(spacing: DesignTokens.spacingSM) {
                NavigationLink(destination: CreatorRevenueDashboardView(authorId: getCurrentUserId())) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundColor(.brandGreen)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("收益儀表板")
                                .font(.bodyText)
                                .fontWeight(.medium)
                                .foregroundColor(.gray900)
                            
                            Text("查看您的創作收益統計")
                                .font(.caption)
                                .foregroundColor(.gray600)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray600)
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: EarningsStatisticsView(authorId: getCurrentUserId())) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundColor(.brandOrange)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("收益統計")
                                .font(.bodyText)
                                .fontWeight(.medium)
                                .foregroundColor(.gray900)
                            
                            Text("詳細的收益分析和趨勢")
                                .font(.caption)
                                .foregroundColor(.gray600)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray600)
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: WithdrawalRequestView(authorId: getCurrentUserId(), availableBalance: 500000)) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.title3)
                            .foregroundColor(.brandBlue)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("提領申請")
                                .font(.bodyText)
                                .fontWeight(.medium)
                                .foregroundColor(.gray900)
                            
                            Text("申請提領您的收益")
                                .font(.caption)
                                .foregroundColor(.gray600)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray600)
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
                .buttonStyle(PlainButtonStyle())
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
            Task {
                await authService.signOut()
            }
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
    }
    
    // MARK: - 輔助方法
    private func getCurrentUserId() -> UUID {
        // 這裡應該從 AuthenticationService 獲取當前用戶 ID
        // 暫時返回一個示例 UUID
        return UUID()
    }
    
    private func settingRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.bodyText) // 使用自定義字體
            .foregroundColor(.gray900)
            .toggleStyle(.switch)
            .tint(.brandGreen)
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
    }
}

// MARK: - 預覽
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthenticationService())
    }
}
