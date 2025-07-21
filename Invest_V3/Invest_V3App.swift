//
//  Invest_V3App.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/7/9.
//

import SwiftUI
import UserNotifications

@main
struct Invest_V3App: App {
    // 添加 NotificationService
    @StateObject private var notificationService = NotificationService.shared
    
    init() {
        // 在 app 啟動時初始化 Supabase 和通知服務
        Task { @MainActor in
            do {
                try await SupabaseManager.shared.initialize()
                print("✅ App 啟動：Supabase 初始化完成")
                
                // 初始化推播通知
                await setupNotifications()
                
            } catch {
                print("❌ App 啟動：Supabase 初始化失敗 - \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(AuthenticationService.shared)
                .environmentObject(UserProfileService.shared)
                .environmentObject(PortfolioService.shared)
                .environmentObject(StockService.shared)
                .environmentObject(notificationService)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // App 變為活躍時更新未讀數量
                    Task {
                        await notificationService.loadUnreadCount()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // App 進入背景時清理通知
                    Task {
                        await notificationService.clearAllNotifications()
                    }
                }
        }
    }
    
    // MARK: - 設置推播通知
    
    @MainActor
    private func setupNotifications() async {
        // 請求推播通知權限
        let granted = await notificationService.requestPermission()
        
        if granted {
            print("✅ App 啟動：推播通知權限已授權")
            
            // 載入未讀通知數量
            await notificationService.loadUnreadCount()
            
            // 設置通知類別和操作
            setupNotificationCategories()
            
        } else {
            print("⚠️ App 啟動：推播通知權限未授權")
        }
    }
    
    /// 設置通知類別和快速操作
    private func setupNotificationCategories() {
        let notificationCenter = UNUserNotificationCenter.current()
        
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
    }
}

// MARK: - Remote Notifications

extension Invest_V3App {
    
    /// 處理遠端推播註冊成功
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await notificationService.setDeviceToken(deviceToken)
        }
    }
    
    /// 處理遠端推播註冊失敗
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ 遠端推播註冊失敗: \(error.localizedDescription)")
    }
}
