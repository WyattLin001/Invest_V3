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
                self.isAuthorized = settings.authorizationStatus == .authorized ||
                                 settings.authorizationStatus == .provisional
                print("📱 [NotificationService] 權限狀態: \(settings.authorizationStatus.rawValue)")
            }
        }
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
            
            try await supabaseService.client
                .from("notification_settings")
                .upsert([
                    "user_id": user.id.uuidString,
                    "device_token": token,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            
            print("✅ [NotificationService] Device Token 已儲存到後端")
            
        } catch {
            print("❌ [NotificationService] 儲存 Device Token 失敗: \(error)")
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
