//
//  NotificationService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  iPhone推播通知服務管理
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    @Published var unreadCount = 0
    
    private let supabaseService = SupabaseService.shared
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
    }
    
    // MARK: - 權限管理
    
    func requestPermission() async -> Bool {
        do {
            // 1. 詢問系統是否授權
            let granted = try await notificationCenter.requestAuthorization(options: [
                .alert, .sound, .badge
            ])

            // 2. 印出目前權限狀態
            let settings = await notificationCenter.notificationSettings()
            print("🔍 [NotificationService] 現在通知授權狀態: \(settings.authorizationStatus.rawValue)")

            // 3. 若授權成功，註冊 remote 通知（不能少）
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            // 4. 為了避免 SwiftUI ViewModel 爆炸，我們延遲更新 isAuthorized
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isAuthorized = granted
                }
            }

            return granted

        } catch {
            print("❌ [NotificationService] 請求推播權限失敗: \(error)")
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isAuthorized = false
                }
            }
            return false
        }
    }

    
    /// 檢查當前權限狀態
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                let wasAuthorized = self.isAuthorized
                self.isAuthorized = settings.authorizationStatus == .authorized ||
                                 settings.authorizationStatus == .provisional
                
                // 如果權限狀態發生變化，進行相應處理
                if wasAuthorized != self.isAuthorized {
                    self.handleAuthorizationStatusChange(
                        from: wasAuthorized,
                        to: self.isAuthorized,
                        settings: settings
                    )
                }
                
                print("📱 [NotificationService] 權限狀態: \(settings.authorizationStatus.rawValue)")
                print("📱 [NotificationService] Alert設定: \(settings.alertSetting.rawValue)")
                print("📱 [NotificationService] Sound設定: \(settings.soundSetting.rawValue)")
                print("📱 [NotificationService] Badge設定: \(settings.badgeSetting.rawValue)")
            }
        }
    }
    
    /// 處理權限狀態變化
    private func handleAuthorizationStatusChange(from wasAuthorized: Bool, to isAuthorized: Bool, settings: UNNotificationSettings) {
        if !wasAuthorized && isAuthorized {
            // 用戶剛授權了推播通知
            print("✅ [NotificationService] 用戶授權了推播通知")
            Task {
                // 重新註冊遠程推播
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } else if wasAuthorized && !isAuthorized {
            // 用戶取消了推播通知授權
            print("⚠️ [NotificationService] 用戶取消了推播通知授權")
            self.deviceToken = nil
        }
    }
    
    /// 獲取詳細的權限狀態
    func getNotificationSettings() async -> UNNotificationSettings {
        return await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
    
    /// 檢查是否可以發送特定類型的通知
    func canSendNotifications(requireSound: Bool = false, requireAlert: Bool = true, requireBadge: Bool = false) async -> Bool {
        let settings = await getNotificationSettings()
        
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return false
        }
        
        if requireAlert && settings.alertSetting != .enabled {
            return false
        }
        
        if requireSound && settings.soundSetting != .enabled {
            return false
        }
        
        if requireBadge && settings.badgeSetting != .enabled {
            return false
        }
        
        return true
    }
    

    
    /// 設定 Device Token
    func setDeviceToken(_ tokenData: Data) {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        print("✅ [NotificationService] Device Token: \(tokenString)")
        
        // 儲存到後端
        Task {
            await saveDeviceTokenToBackend(tokenString)
        }
    }
    
    /// 儲存 Device Token 到後端
    private func saveDeviceTokenToBackend(_ token: String) async {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                print("⚠️ [NotificationService] 用戶未登入，無法儲存 Device Token")
                return
            }
            
            // 使用新的 Edge Function 來註冊設備 Token
            let deviceInfo = [
                "device_token": token,
                "user_id": user.id.uuidString,
                "device_type": "ios",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                "os_version": UIDevice.current.systemVersion,
                "device_model": UIDevice.current.model,
                "environment": PushNotificationConfig.environment.rawValue
            ]
            
            let response = try await supabaseService.client.functions
                .invoke("register-device-token", options: FunctionInvokeOptions(
                    body: deviceInfo
                ))
            
            if let responseData = response.data,
               let jsonObject = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                print("✅ [NotificationService] Device Token 註冊成功: \(jsonObject)")
            } else {
                print("✅ [NotificationService] Device Token 已註冊")
            }
            
        } catch {
            print("❌ [NotificationService] 儲存 Device Token 失敗: \(error)")
            
            // 降級到直接資料庫操作
            await saveDeviceTokenDirectly(token)
        }
    }
    
    /// 直接儲存到資料庫（降級方案）
    private func saveDeviceTokenDirectly(_ token: String) async {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                return
            }
            
            try await supabaseService.client
                .from("device_tokens")
                .upsert([
                    "user_id": user.id.uuidString,
                    "device_token": token,
                    "device_type": "ios",
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                    "os_version": UIDevice.current.systemVersion,
                    "device_model": UIDevice.current.model,
                    "environment": PushNotificationConfig.environment.rawValue,
                    "is_active": true,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            
            print("✅ [NotificationService] Device Token 直接儲存成功")
            
        } catch {
            print("❌ [NotificationService] 直接儲存 Device Token 也失敗: \(error)")
        }
    }
    
    // MARK: - 本地通知
    
    /// 發送本地通知
    func sendLocalNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        categoryIdentifier: String? = nil,
        userInfo: [AnyHashable: Any]? = nil,
        delay: TimeInterval = 0
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        
        if let userInfo = userInfo {
            content.userInfo = userInfo
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("✅ [NotificationService] 本地通知已排程: \(title)")
        } catch {
            print("❌ [NotificationService] 發送本地通知失敗: \(error)")
        }
    }
    
    // MARK: - 通知記錄管理
    
    /// 載入未讀通知數量
    func loadUnreadCount() async {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                await MainActor.run {
                    self.unreadCount = 0
                }
                return
            }
            
            // 使用正確的計數查詢方式
            let result = try await supabaseService.client
                .from("notifications")
                .select("*", head: false, count: .exact)
                .eq("user_id", value: user.id)
                .is("read_at", value: nil)
                .execute()
            
            // 從 count 屬性獲取數量
            await MainActor.run {
                self.unreadCount = result.count ?? 0
                print("✅ [NotificationService] 載入未讀數量: \(self.unreadCount)")
            }
            
        } catch {
            print("❌ [NotificationService] 載入未讀通知數量失敗: \(error)")
            await MainActor.run {
                self.unreadCount = 0
            }
        }
    }
    
    /// 標記通知為已讀
    func markNotificationAsRead(_ notificationId: String) async {
        do {
            try await supabaseService.client
                .from("notifications")
                .update([
                    "read_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: notificationId)
                .execute()
            
            // 更新未讀數量
            await loadUnreadCount()
            
        } catch {
            print("❌ [NotificationService] 標記通知已讀失敗: \(error)")
        }
    }
    
    /// 清除所有通知
    func clearAllNotifications() async {
        // 清除通知中心的通知
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        
        // 重置 badge
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        print("✅ [NotificationService] 已清除所有通知")
    }
    
    // MARK: - 通知類型管理
    
    /// 創建通知記錄
    func createNotificationRecord(
        title: String,
        body: String,
        type: AppNotificationType,
        data: [String: Any]? = nil,
        userId: String? = nil
    ) async {
        do {
            let targetUserId: String
            if let userId = userId {
                targetUserId = userId
            } else if let user = try? await supabaseService.client.auth.user() {
                targetUserId = user.id.uuidString
            } else {
                print("⚠️ [NotificationService] 無法確定目標用戶，跳過創建通知記錄")
                return
            }
            
            // 創建可編碼的結構體
            struct NotificationInsert: Encodable {
                let user_id: String
                let title: String
                let body: String
                let notification_type: String
                let data: String?
                let created_at: String
                
                enum CodingKeys: String, CodingKey {
                    case user_id, title, body, notification_type, data, created_at
                }
            }
            
            let notificationInsert = NotificationInsert(
                user_id: targetUserId,
                title: title,
                body: body,
                notification_type: type.rawValue,
                data: data != nil ? try? JSONSerialization.data(withJSONObject: data!, options: []).base64EncodedString() : nil,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabaseService.client
                .from("notifications")
                .insert(notificationInsert)
                .execute()
            
            print("✅ [NotificationService] 通知記錄已創建: \(type.rawValue)")
            
            // 更新未讀數量
            if userId == nil { // 只有當前用戶才更新未讀數量
                await loadUnreadCount()
            }
            
        } catch {
            print("❌ [NotificationService] 創建通知記錄失敗: \(error)")
        }
    }
    
    // MARK: - 特定通知類型
    
    /// 發送主持人訊息通知
    func sendHostMessageNotification(hostName: String, message: String, groupId: String) async {
        let title = "來自 \(hostName) 的訊息"
        let body = message
        
        await sendLocalNotification(
            title: title,
            body: body,
            categoryIdentifier: "HOST_MESSAGE",
            userInfo: [
                "type": "host_message",
                "group_id": groupId,
                "host_name": hostName
            ]
        )
        
        await createNotificationRecord(
            title: title,
            body: body,
            type: .hostMessage,
            data: [
                "group_id": groupId,
                "host_name": hostName
            ]
        )
    }
    
    /// 發送排名更新通知
    func sendRankingUpdateNotification(newRank: Int, previousRank: Int) async {
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
            ]
        )
        
        await createNotificationRecord(
            title: title,
            body: body,
            type: .rankingUpdate,
            data: [
                "new_rank": newRank,
                "previous_rank": previousRank
            ]
        )
    }
    
    /// 發送股價到價提醒
    func sendStockPriceAlert(stockSymbol: String, stockName: String, targetPrice: Double, currentPrice: Double) async {
        let title = "股價到價提醒"
        let body = "\(stockName) (\(stockSymbol)) 已達到目標價格 $\(targetPrice)，目前價格 $\(currentPrice)"
        
        await sendLocalNotification(
            title: title,
            body: body,
            categoryIdentifier: "STOCK_ALERT",
            userInfo: [
                "type": "stock_price_alert",
                "stock_symbol": stockSymbol,
                "target_price": targetPrice,
                "current_price": currentPrice
            ]
        )
        
        await createNotificationRecord(
            title: title,
            body: body,
            type: .stockPriceAlert,
            data: [
                "stock_symbol": stockSymbol,
                "stock_name": stockName,
                "target_price": targetPrice,
                "current_price": currentPrice
            ]
        )
    }
    
    // MARK: - Push Notification Management
    
    /// 發送推播通知給指定用戶
    func sendPushNotification(
        to userId: String,
        title: String,
        body: String,
        category: String? = nil,
        data: [String: Any]? = nil
    ) async -> Bool {
        do {
            guard let currentUser = try? await supabaseService.client.auth.user() else {
                print("⚠️ [NotificationService] 用戶未登入，無法發送推播")
                return false
            }
            
            let pushData: [String: Any] = [
                "title": title,
                "body": body,
                "category": category ?? "",
                "data": data ?? [:],
                "target_user_id": userId,
                "sender_user_id": currentUser.id.uuidString
            ]
            
            let response = try await supabaseService.client.functions
                .invoke("send-push-notification", options: FunctionInvokeOptions(
                    body: pushData
                ))
            
            if let responseData = response.data,
               let result = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let success = result["success"] as? Bool {
                if success {
                    print("✅ [NotificationService] 推播通知發送成功")
                    return true
                } else {
                    print("❌ [NotificationService] 推播通知發送失敗: \(result)")
                    return false
                }
            }
            
            return true
            
        } catch {
            print("❌ [NotificationService] 發送推播通知異常: \(error)")
            return false
        }
    }
    
    /// 發送批量推播通知
    func sendBulkPushNotification(
        to userIds: [String],
        title: String,
        body: String,
        category: String? = nil,
        data: [String: Any]? = nil
    ) async -> Bool {
        do {
            guard let currentUser = try? await supabaseService.client.auth.user() else {
                print("⚠️ [NotificationService] 用戶未登入，無法發送批量推播")
                return false
            }
            
            let pushData: [String: Any] = [
                "title": title,
                "body": body,
                "category": category ?? "",
                "data": data ?? [:],
                "target_user_ids": userIds,
                "sender_user_id": currentUser.id.uuidString
            ]
            
            let response = try await supabaseService.client.functions
                .invoke("send-bulk-notifications", options: FunctionInvokeOptions(
                    body: pushData
                ))
            
            if let responseData = response.data,
               let result = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let success = result["success"] as? Bool {
                print(success ? "✅ [NotificationService] 批量推播發送成功" : "❌ [NotificationService] 批量推播發送失敗: \(result)")
                return success
            }
            
            return true
            
        } catch {
            print("❌ [NotificationService] 發送批量推播異常: \(error)")
            return false
        }
    }
    
    /// 獲取用戶推播偏好設定
    func getUserPushPreferences() async -> [String: Any]? {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                return nil
            }
            
            let response = try await supabaseService.client.functions
                .invoke("manage-user-preferences", options: FunctionInvokeOptions(
                    body: [
                        "action": "get",
                        "user_id": user.id.uuidString
                    ]
                ))
            
            if let responseData = response.data,
               let preferences = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                return preferences
            }
            
            return nil
            
        } catch {
            print("❌ [NotificationService] 獲取推播偏好失敗: \(error)")
            return nil
        }
    }
    
    /// 更新用戶推播偏好設定
    func updateUserPushPreferences(_ preferences: [String: Any]) async -> Bool {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                return false
            }
            
            var updateData = preferences
            updateData["action"] = "update"
            updateData["user_id"] = user.id.uuidString
            
            let response = try await supabaseService.client.functions
                .invoke("manage-user-preferences", options: FunctionInvokeOptions(
                    body: updateData
                ))
            
            if let responseData = response.data,
               let result = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let success = result["success"] as? Bool {
                print(success ? "✅ [NotificationService] 推播偏好更新成功" : "❌ [NotificationService] 推播偏好更新失敗")
                return success
            }
            
            return false
            
        } catch {
            print("❌ [NotificationService] 更新推播偏好異常: \(error)")
            return false
        }
    }
    
    /// 獲取推播通知分析數據
    func getNotificationAnalytics(days: Int = 7) async -> [String: Any]? {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                return nil
            }
            
            let response = try await supabaseService.client.functions
                .invoke("notification-analytics", options: FunctionInvokeOptions(
                    body: [
                        "user_id": user.id.uuidString,
                        "days": days,
                        "metrics": ["delivery_rate", "open_rate", "notification_types"]
                    ]
                ))
            
            if let responseData = response.data,
               let analytics = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                return analytics
            }
            
            return nil
            
        } catch {
            print("❌ [NotificationService] 獲取推播分析失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - Testing and Debug
    
    /// 測試推播通知功能
    func testNotificationSystem() async {
        print("🧪 [NotificationService] 開始測試推播通知系統")
        
        // 1. 檢查權限狀態
        let settings = await getNotificationSettings()
        print("📱 權限狀態: \(settings.authorizationStatus.rawValue)")
        print("📱 Device Token: \(deviceToken ?? "未設置")")
        
        // 2. 測試本地通知
        await sendLocalNotification(
            title: "測試通知",
            body: "這是一個測試推播通知，用於驗證系統功能",
            categoryIdentifier: "SYSTEM_ALERT",
            userInfo: ["type": "test"],
            delay: 2.0
        )
        
        // 3. 測試推播偏好獲取
        let preferences = await getUserPushPreferences()
        print("📱 用戶推播偏好: \(preferences ?? [:])")
        
        // 4. 測試設備 Token 註冊
        if let token = deviceToken {
            await saveDeviceTokenToBackend(token)
        }
        
        // 5. 測試遠程推播（發送給自己）
        if let user = try? await supabaseService.client.auth.user() {
            let success = await sendPushNotification(
                to: user.id.uuidString,
                title: "遠程推播測試",
                body: "這是一個遠程推播通知測試",
                category: "SYSTEM_ALERT",
                data: ["test": true, "timestamp": Date().timeIntervalSince1970]
            )
            print("📱 遠程推播測試結果: \(success ? "成功" : "失敗")")
        }
        
        // 6. 創建測試通知記錄
        await createNotificationRecord(
            title: "系統測試完成",
            body: "推播通知系統測試完成，包含本地和遠程推播",
            type: .systemAlert,
            data: ["test": true, "completed_at": ISO8601DateFormatter().string(from: Date())]
        )
        
        print("✅ [NotificationService] 推播通知系統測試完成")
    }
    
    /// 獲取系統診斷信息
    func getDiagnosticInfo() async -> [String: Any] {
        let settings = await getNotificationSettings()
        let preferences = await getUserPushPreferences()
        let analytics = await getNotificationAnalytics()
        
        var diagnosticInfo: [String: Any] = [
            "isAuthorized": isAuthorized,
            "authorizationStatus": settings.authorizationStatus.rawValue,
            "alertSetting": settings.alertSetting.rawValue,
            "soundSetting": settings.soundSetting.rawValue,
            "badgeSetting": settings.badgeSetting.rawValue,
            "deviceToken": deviceToken ?? "未設置",
            "unreadCount": unreadCount,
            "canSendNotifications": await canSendNotifications(),
            "environment": PushNotificationConfig.environment.displayName,
            "apnsServer": PushNotificationConfig.apnsServer,
            "bundleId": PushNotificationConfig.bundleId
        ]
        
        if let preferences = preferences {
            diagnosticInfo["userPreferences"] = preferences
        }
        
        if let analytics = analytics {
            diagnosticInfo["analytics"] = analytics
        }
        
        // 檢查後端連接狀態
        diagnosticInfo["backendConnected"] = await checkBackendConnection()
        
        return diagnosticInfo
    }
    
    /// 檢查後端連接狀態
    private func checkBackendConnection() async -> Bool {
        do {
            // 嘗試調用一個簡單的 Edge Function 來測試連接
            let response = try await supabaseService.client.functions
                .invoke("notification-analytics", options: FunctionInvokeOptions(
                    body: ["action": "health_check"]
                ))
            
            return response.data != nil
        } catch {
            print("❌ [NotificationService] 後端連接檢查失敗: \(error)")
            return false
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// 在前景收到通知時的處理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 [NotificationService] 前景收到通知: \(notification.request.content.title)")
        
        // 在前景也顯示通知
        completionHandler([.alert, .sound, .badge])
    }
    
    /// 用戶點擊通知時的處理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 [NotificationService] 用戶點擊通知: \(userInfo)")
        
        // 處理不同類型的通知點擊
        if let type = userInfo["type"] as? String {
            handleNotificationTap(type: type, userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    /// 處理通知點擊事件
    private func handleNotificationTap(type: String, userInfo: [AnyHashable: Any]) {
        Task {
            switch type {
            case "host_message":
                // 跳轉到聊天群組
                if let groupId = userInfo["group_id"] as? String {
                    await navigateToChat(groupId: groupId)
                }
                
            case "ranking_update":
                // 跳轉到排行榜
                await navigateToRanking()
                
            case "stock_price_alert":
                // 跳轉到股票詳情或投資組合
                if let stockSymbol = userInfo["stock_symbol"] as? String {
                    await navigateToStock(symbol: stockSymbol)
                }
                
            default:
                print("⚠️ [NotificationService] 未知的通知類型: \(type)")
            }
        }
    }
    
    // MARK: - Remote Notification Handling
    
    /// 處理註冊失敗
    func handleRegistrationFailure(_ error: Error) async {
        await MainActor.run {
            self.isAuthorized = false
            self.deviceToken = nil
        }
        print("❌ [NotificationService] 推播註冊失敗處理完成")
    }
    
    /// 處理遠程推播通知
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        print("📱 [NotificationService] 處理遠程推播通知: \(userInfo)")
        
        // 解析通知類型
        if let typeString = userInfo["type"] as? String,
           let type = AppNotificationType(rawValue: typeString) {
            
            // 創建通知記錄
            let title = userInfo["title"] as? String ?? "新通知"
            let body = userInfo["body"] as? String ?? ""
            
            await createNotificationRecord(
                title: title,
                body: body,
                type: type,
                data: userInfo as? [String: Any]
            )
        }
        
        // 更新未讀數量
        await loadUnreadCount()
    }
    
    /// 處理帶完成回調的遠程推播通知
    func handleRemoteNotificationWithCompletion(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        print("📱 [NotificationService] 處理背景遠程推播通知: \(userInfo)")
        
        await handleRemoteNotification(userInfo)
        
        // 根據處理結果返回相應的狀態
        return .newData
    }
    
    // MARK: - 導航處理
    
    private func navigateToChat(groupId: String) async {
        // TODO: 實現跳轉到聊天群組
        print("📱 [NotificationService] 導航到聊天群組: \(groupId)")
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToChat"),
            object: nil,
            userInfo: ["groupId": groupId]
        )
    }
    
    private func navigateToRanking() async {
        // TODO: 實現跳轉到排行榜
        print("📱 [NotificationService] 導航到排行榜")
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToRanking"),
            object: nil
        )
    }
    
    private func navigateToStock(symbol: String) async {
        // TODO: 實現跳轉到股票詳情
        print("📱 [NotificationService] 導航到股票: \(symbol)")
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToStock"),
            object: nil,
            userInfo: ["stockSymbol": symbol]
        )
    }
}

// 已移動到 AppNotification.swift 文件中
