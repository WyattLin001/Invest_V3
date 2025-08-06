//
//  AppDelegate.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  處理推播通知和應用生命週期
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - Application Lifecycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("📱 [AppDelegate] 應用啟動完成")
        
        // 設置推播通知代理
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // MARK: - Push Notifications
    
    /// 成功註冊遠程推播通知時的回調
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ [AppDelegate] 成功註冊遠程推播通知")
        
        // 將 device token 傳遞給 NotificationService
        Task {
            await NotificationService.shared.setDeviceToken(deviceToken)
        }
    }
    
    /// 註冊遠程推播通知失敗時的回調
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [AppDelegate] 註冊遠程推播通知失敗: \(error.localizedDescription)")
        
        // 可以在這裡處理註冊失敗的情況
        // 例如：記錄錯誤、顯示用戶提示等
        Task {
            await NotificationService.shared.handleRegistrationFailure(error)
        }
    }
    
    /// 接收到遠程推播通知時的回調（iOS 10以下版本）
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        print("📱 [AppDelegate] 收到遠程推播通知: \(userInfo)")
        
        // 處理推播通知
        Task {
            await NotificationService.shared.handleRemoteNotification(userInfo)
        }
    }
    
    /// 接收到遠程推播通知時的回調（iOS 7以上版本，支持背景刷新）
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📱 [AppDelegate] 收到遠程推播通知 (背景模式): \(userInfo)")
        
        // 處理推播通知
        Task {
            let result = await NotificationService.shared.handleRemoteNotificationWithCompletion(userInfo)
            completionHandler(result)
        }
    }
    
    // MARK: - Background Processing
    
    /// 應用進入背景時的處理
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 [AppDelegate] 應用進入背景")
        
        // 可以在這裡處理背景任務
        // 例如：保存數據、暫停定時器等
    }
    
    /// 應用進入前景時的處理
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 [AppDelegate] 應用進入前景")
        
        // 更新未讀通知數量
        Task {
            await NotificationService.shared.loadUnreadCount()
            await NotificationService.shared.checkAuthorizationStatus()
        }
    }
    
    /// 應用變為活躍狀態時的處理
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 [AppDelegate] 應用變為活躍")
        
        // 清空應用圖標上的 badge 數字
        application.applicationIconBadgeNumber = 0
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 處理推播通知行動
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 [AppDelegate] 處理推播通知點擊: \(userInfo)")
        
        // 處理通知點擊事件 - 一般是打開應用或導航到特定頁面
        Task {
            await NotificationService.shared.handleRemoteNotification(userInfo)
            completionHandler()
        }
    }
    
    /// 當應用程式在前景時收到推播通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📱 [AppDelegate] 前景收到推播通知: \(notification.request.content.title)")
        
        // 在前景也顯示通知
        completionHandler([.banner, .sound, .badge])
    }
}