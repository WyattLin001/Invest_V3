//
//  LocalNotificationService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/9/19.
//  本地通知服務 - 適用於個人開發者賬號
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class LocalNotificationService: NSObject, ObservableObject {
    static let shared = LocalNotificationService()
    
    @Published var isAuthorized = false
    @Published var unreadCount = 0
    
    private var notificationCenter: UNUserNotificationCenter {
        return UNUserNotificationCenter.current()
    }
    
    private override init() {
        super.init()
        setupNotificationCenter()
    }
    
    // MARK: - 初始設定
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let categories = NotificationCategories.allCategories
        notificationCenter.setNotificationCategories(Set(categories))
    }
    
    // MARK: - 權限管理
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [
                .alert, .sound, .badge
            ])
            
            await MainActor.run {
                isAuthorized = granted
            }
            
            return granted
        } catch {
            print("推送通知權限請求失敗: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - 本地通知
    
    func sendLocalNotification(
        title: String,
        body: String,
        categoryIdentifier: String = "DEFAULT",
        userInfo: [AnyHashable: Any] = [:],
        delay: TimeInterval = 0,
        repeats: Bool = false
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delay, 1), // 最少1秒延遲
            repeats: repeats
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("本地通知已排程: \(title)")
        } catch {
            print("本地通知排程失敗: \(error)")
        }
    }
    
    // MARK: - 股票相關通知
    
    func sendStockPriceAlert(
        stockSymbol: String,
        stockName: String,
        targetPrice: Double,
        currentPrice: Double,
        delay: TimeInterval = 1
    ) async {
        let title = "股價到價提醒"
        let body = "\(stockName) (\(stockSymbol)) 已達到目標價格 $\(targetPrice)，目前價格 $\(currentPrice)"
        
        await sendLocalNotification(
            title: title,
            body: body,
            categoryIdentifier: "STOCK_ALERT",
            userInfo: [
                "type": "stock_price_alert",
                "stock_symbol": stockSymbol,
                "stock_name": stockName,
                "target_price": targetPrice,
                "current_price": currentPrice
            ],
            delay: delay
        )
    }
    
    func sendRankingUpdate(
        newRank: Int,
        previousRank: Int,
        delay: TimeInterval = 1
    ) async {
        let title = "排名更新"
        let body: String
        
        if newRank < previousRank {
            body = "恭喜！您的排名從第 \(previousRank) 名上升到第 \(newRank) 名！"
        } else {
            body = "您的排名更新為第 \(newRank) 名"
        }
        
        await sendLocalNotification(
            title: title,
            body: body,
            categoryIdentifier: "RANKING_UPDATE",
            userInfo: [
                "type": "ranking_update",
                "new_rank": newRank,
                "previous_rank": previousRank
            ],
            delay: delay
        )
    }
    
    func sendSystemAlert(
        title: String,
        message: String,
        alertType: String = "info",
        delay: TimeInterval = 1
    ) async {
        await sendLocalNotification(
            title: title,
            body: message,
            categoryIdentifier: "SYSTEM_ALERT",
            userInfo: [
                "type": "system_alert",
                "alert_type": alertType
            ],
            delay: delay
        )
    }
    
    // MARK: - 通知管理
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    func removeNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func removeAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        
        // 重置應用程式圖標徽章數字
        UIApplication.shared.applicationIconBadgeNumber = 0
        unreadCount = 0
    }
    
    func loadUnreadCount() async {
        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        await MainActor.run {
            unreadCount = deliveredNotifications.count
        }
    }
    
    // MARK: - 診斷功能
    
    func getDiagnosticInfo() async -> [String: Any] {
        let settings = await notificationCenter.notificationSettings()
        let pendingNotifications = await notificationCenter.pendingNotificationRequests()
        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        
        return [
            "authorization_status": settings.authorizationStatus.rawValue,
            "alert_setting": settings.alertSetting.rawValue,
            "sound_setting": settings.soundSetting.rawValue,
            "badge_setting": settings.badgeSetting.rawValue,
            "pending_notifications": pendingNotifications.count,
            "delivered_notifications": deliveredNotifications.count,
            "unread_count": unreadCount,
            "notification_center_enabled": true,
            "remote_notifications_supported": false, // 明確標示不支援遠程推播
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown"
        ]
    }
    
    func testNotificationSystem() async {
        await sendSystemAlert(
            title: "系統測試",
            message: "本地通知系統測試成功 - \(Date().formatted(date: .omitted, time: .shortened))",
            alertType: "test",
            delay: 1
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension LocalNotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前台顯示通知
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationAction(response: response, userInfo: userInfo)
        completionHandler()
    }
    
    private func handleNotificationAction(
        response: UNNotificationResponse,
        userInfo: [AnyHashable: Any]
    ) {
        guard let notificationType = userInfo["type"] as? String else { return }
        
        switch notificationType {
        case "stock_price_alert":
            handleStockAlert(userInfo: userInfo, response: response)
        case "ranking_update":
            handleRankingUpdate(userInfo: userInfo, response: response)
        case "system_alert":
            handleSystemAlert(userInfo: userInfo, response: response)
        default:
            print("未知通知類型: \(notificationType)")
        }
        
        // 更新未讀數量
        Task {
            await loadUnreadCount()
        }
    }
    
    private func handleStockAlert(userInfo: [AnyHashable: Any], response: UNNotificationResponse) {
        if let stockSymbol = userInfo["stock_symbol"] as? String {
            print("處理股價提醒: \(stockSymbol)")
            // 這裡可以導航到股票詳情頁面
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToStock"),
                object: stockSymbol
            )
        }
    }
    
    private func handleRankingUpdate(userInfo: [AnyHashable: Any], response: UNNotificationResponse) {
        print("處理排名更新通知")
        // 這裡可以導航到排行榜頁面
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToRankings"),
            object: nil
        )
    }
    
    private func handleSystemAlert(userInfo: [AnyHashable: Any], response: UNNotificationResponse) {
        if let alertType = userInfo["alert_type"] as? String {
            print("處理系統提醒: \(alertType)")
            // 根據不同的系統提醒類型執行相應操作
        }
    }
}

// MARK: - 通知分類

struct NotificationCategories {
    
    static var allCategories: [UNNotificationCategory] {
        return [
            stockAlertCategory,
            rankingUpdateCategory,
            systemAlertCategory,
            defaultCategory
        ]
    }
    
    static var stockAlertCategory: UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_STOCK",
            title: "查看股票",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_STOCK",
            title: "忽略",
            options: []
        )
        
        return UNNotificationCategory(
            identifier: "STOCK_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
    }
    
    static var rankingUpdateCategory: UNNotificationCategory {
        let viewRankingAction = UNNotificationAction(
            identifier: "VIEW_RANKING",
            title: "查看排名",
            options: [.foreground]
        )
        
        return UNNotificationCategory(
            identifier: "RANKING_UPDATE",
            actions: [viewRankingAction],
            intentIdentifiers: [],
            options: []
        )
    }
    
    static var systemAlertCategory: UNNotificationCategory {
        let okAction = UNNotificationAction(
            identifier: "OK",
            title: "確定",
            options: []
        )
        
        return UNNotificationCategory(
            identifier: "SYSTEM_ALERT",
            actions: [okAction],
            intentIdentifiers: [],
            options: []
        )
    }
    
    static var defaultCategory: UNNotificationCategory {
        return UNNotificationCategory(
            identifier: "DEFAULT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
    }
}