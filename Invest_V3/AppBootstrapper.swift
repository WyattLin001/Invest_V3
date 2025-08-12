//
//  AppBootstrapper.swift
//  Invest_V3
//
//  Created by Claude on 2025/7/23.
//

import Foundation
import SwiftUI
import UserNotifications

/// App 啟動管理器 - 負責應用初始化
@MainActor
class AppBootstrapper: ObservableObject {
    static let shared = AppBootstrapper()
    
    @Published var isInitialized = false
    @Published var initializationError: String?
    
    private init() {}
    
    /// 執行應用啟動初始化
    func bootstrap() async {
        print("🚀 AppBootstrapper 開始初始化...")
        
        // Preview 安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("🔍 Preview 模式：跳過真實初始化")
            await MainActor.run {
                self.isInitialized = true
                self.initializationError = nil
            }
            print("✅ AppBootstrapper 初始化完成 (Preview 模式)")
            return
        }
        #endif
        
        do {
            // 1. 初始化 Supabase
            print("🔄 開始初始化 Supabase...")
            try await SupabaseManager.shared.initialize()
            print("✅ Supabase 初始化完成")
            
            // 2. 初始化推播通知
            await setupNotifications()
            print("✅ 推播通知設置完成")
            
            // 3. 可以在這裡添加其他初始化任務
            // 例如：用戶偏好設定、緩存清理等
            
            await MainActor.run {
                self.isInitialized = true
                self.initializationError = nil
            }
            
            print("✅ AppBootstrapper 初始化完成")
            
        } catch {
            print("❌ AppBootstrapper 初始化失敗: \(error)")
            await MainActor.run {
                self.isInitialized = false
                self.initializationError = error.localizedDescription
            }
        }
    }
    
    /// 重試初始化
    func retry() async {
        await bootstrap()
    }
    
    // MARK: - 私有方法
    
    /// 設置推播通知
    private func setupNotifications() async {
        // 請求推播通知權限
        let granted = await NotificationService.shared.requestPermission()
        
        if granted {
            print("✅ 推播通知權限已授權")
            
            // 載入未讀通知數量
            await NotificationService.shared.loadUnreadCount()
            
            // 設置通知類別和操作
            setupNotificationCategories()
            
        } else {
            print("⚠️ 推播通知權限未授權")
        }
    }
    
    /// 設置通知類別和快速操作
    private func setupNotificationCategories() {
        let notificationCenter = UNUserNotificationCenter.current()
        
        // 註冊所有推播通知類別
        notificationCenter.setNotificationCategories(UNNotificationCategory.all)
        
        print("✅ 已註冊 \(UNNotificationCategory.all.count) 個推播通知類別")
        
        // 舊的實現，保留註釋作為參考
        /*
        // 主持人訊息通知類別
        let hostMessageCategory = UNNotificationCategory(
            identifier: "HOST_MESSAGE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_MESSAGE",
                    title: "查看訊息",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "稍後處理",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // 排名更新通知類別
        let rankingUpdateCategory = UNNotificationCategory(
            identifier: "RANKING_UPDATE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_RANKING",
                    title: "查看排行榜",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        // 股價提醒通知類別
        let stockAlertCategory = UNNotificationCategory(
            identifier: "STOCK_ALERT",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_STOCK",
                    title: "查看股票",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SET_NEW_ALERT",
                    title: "設定新提醒",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        // 註冊通知類別
        notificationCenter.setNotificationCategories([
            hostMessageCategory,
            rankingUpdateCategory,
            stockAlertCategory
        ])
        
        print("✅ 通知類別設置完成")
        */
    }
}

/// 啟動畫面 - 顯示初始化進度
struct BootstrapView: View {
    @StateObject private var bootstrapper = AppBootstrapper.shared
    
    var body: some View {
        ZStack {
            // 使用明確的背景色來診斷問題
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Logo 或品牌圖標
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Invest V3")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                // 添加調試信息
                Text("初始化狀態: \(bootstrapper.isInitialized ? "已完成" : "進行中")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let error = bootstrapper.initializationError {
                    Text("錯誤: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if bootstrapper.isInitialized {
                    // 初始化完成
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.brandGreen)
                        Text("初始化完成")
                            .foregroundColor(.gray700)
                    }
                } else if let error = bootstrapper.initializationError {
                    // 初始化失敗
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.danger)
                            Text("初始化失敗")
                                .foregroundColor(.danger)
                        }
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray600)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("重試") {
                            Task {
                                await bootstrapper.retry()
                            }
                        }
                        .brandButtonStyle()
                    }
                } else {
                    // 初始化中
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.brandGreen)
                        
                        Text("正在初始化應用...")
                            .foregroundColor(.gray600)
                    }
                }
            }
        }
        .task {
            if !bootstrapper.isInitialized && bootstrapper.initializationError == nil {
                await bootstrapper.bootstrap()
            }
        }
    }
}

/// 主應用容器 - 根據初始化狀態顯示不同內容
struct AppContainer: View {
    @StateObject private var bootstrapper = AppBootstrapper.shared
    
    var body: some View {
        Group {
            if bootstrapper.isInitialized {
                // 初始化完成，顯示主應用
                MainAppView()
                    .environmentObject(AuthenticationService.shared)
                    .environmentObject(UserProfileService.shared)
                    .environmentObject(PortfolioService.shared)
                    .environmentObject(ThemeManager.shared)
                    .environmentObject(StockService.shared)
                    .environmentObject(NotificationService.shared)
                    .environmentObject(makeTournamentWorkflowService())
            } else {
                // 顯示啟動畫面
                BootstrapView()
            }
        }
    }
}

// MARK: - Service Factory

/// 創建完整配置的錦標賽工作流程服務
private func makeTournamentWorkflowService() -> TournamentWorkflowService {
    return TournamentWorkflowService(
        tournamentService: TournamentService(),
        tradeService: TournamentTradeService(),
        walletService: TournamentWalletService(),
        rankingService: TournamentRankingService(),
        businessService: TournamentBusinessService()
    )
}
