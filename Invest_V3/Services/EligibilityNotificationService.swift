//
//  EligibilityNotificationService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/2.
//  收益資格通知提醒系統
//

import Foundation
import UserNotifications
import Combine

@MainActor
class EligibilityNotificationService: NSObject, ObservableObject {
    static let shared = EligibilityNotificationService()
    
    @Published var hasNotificationPermission = false
    @Published var unreadNotifications: [EligibilityNotification] = []
    @Published var allNotifications: [EligibilityNotification] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseService = SupabaseService.shared
    
    private override init() {
        super.init()
        checkNotificationPermission()
        loadNotifications()
        
        // 監聽閱讀記錄更新事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(readingLogSaved),
            name: NSNotification.Name("ReadingLogSaved"),
            object: nil
        )
    }
    
    // MARK: - 通知權限管理
    
    /// 檢查通知權限
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.hasNotificationPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// 請求通知權限
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            hasNotificationPermission = granted
            
            if granted {
                print("✅ [EligibilityNotificationService] 通知權限已授予")
            } else {
                print("❌ [EligibilityNotificationService] 通知權限被拒絕")
            }
            
            return granted
        } catch {
            print("❌ [EligibilityNotificationService] 請求通知權限失敗: \(error)")
            return false
        }
    }
    
    // MARK: - 通知發送
    
    /// 發送資格達成通知
    func sendEligibilityAchievedNotification() async {
        guard hasNotificationPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 恭喜！收益資格已達成"
        content.body = "您已符合所有條件，現在可以開始獲得收益分潤！"
        content.sound = .default
        content.badge = NSNumber(value: unreadNotifications.count + 1)
        
        let request = UNNotificationRequest(
            identifier: "eligibility_achieved_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // 添加到本地通知列表
            let notification = EligibilityNotification(
                type: .qualified,
                title: content.title,
                message: content.body
            )
            
            addNotification(notification)
            
            print("✅ [EligibilityNotificationService] 資格達成通知已發送")
        } catch {
            print("❌ [EligibilityNotificationService] 發送通知失敗: \(error)")
        }
    }
    
    /// 發送接近門檻通知
    func sendNearThresholdNotification(condition: EligibilityCondition, currentValue: Int, requiredValue: Int) async {
        guard hasNotificationPermission else { return }
        
        let remaining = requiredValue - currentValue
        let content = UNMutableNotificationContent()
        content.title = "⚡ 即將達成條件"
        content.body = "您的「\(condition.displayName)」還差 \(remaining) 就能達成收益資格！"
        content.sound = .default
        content.badge = NSNumber(value: unreadNotifications.count + 1)
        
        let request = UNNotificationRequest(
            identifier: "near_threshold_\(condition.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // 添加到本地通知列表
            let notification = EligibilityNotification(
                type: .nearThreshold,
                title: content.title,
                message: content.body,
                condition: condition,
                currentValue: currentValue,
                requiredValue: requiredValue
            )
            
            addNotification(notification)
            
            print("✅ [EligibilityNotificationService] 接近門檻通知已發送")
        } catch {
            print("❌ [EligibilityNotificationService] 發送通知失敗: \(error)")
        }
    }
    
    /// 發送資格失效通知
    func sendEligibilityLostNotification() async {
        guard hasNotificationPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 收益資格已失效"
        content.body = "您的收益資格已失效，請檢查條件並重新達成。"
        content.sound = .default
        content.badge = NSNumber(value: unreadNotifications.count + 1)
        
        let request = UNNotificationRequest(
            identifier: "eligibility_lost_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // 添加到本地通知列表
            let notification = EligibilityNotification(
                type: .disqualified,
                title: content.title,
                message: content.body
            )
            
            addNotification(notification)
            
            print("✅ [EligibilityNotificationService] 資格失效通知已發送")
        } catch {
            print("❌ [EligibilityNotificationService] 發送通知失敗: \(error)")
        }
    }
    
    /// 發送每日提醒通知
    func scheduleDaily條件檢查Reminder() async {
        guard hasNotificationPermission else { return }
        
        // 取消之前的每日提醒
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_eligibility_check"]
        )
        
        let content = UNMutableNotificationContent()
        content.title = "📊 收益資格檢查"
        content.body = "記得查看您的收益資格進度，繼續努力達成條件！"
        content.sound = .default
        
        // 設置每天上午10點提醒
        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily_eligibility_check",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ [EligibilityNotificationService] 每日提醒已設置")
        } catch {
            print("❌ [EligibilityNotificationService] 設置每日提醒失敗: \(error)")
        }
    }
    
    // MARK: - 通知管理
    
    /// 添加通知到列表
    private func addNotification(_ notification: EligibilityNotification) {
        allNotifications.insert(notification, at: 0) // 最新的在前面
        unreadNotifications.insert(notification, at: 0)
        
        // 保存到本地
        saveNotificationsToLocal()
        
        // 限制通知數量（最多保存100條）
        if allNotifications.count > 100 {
            allNotifications = Array(allNotifications.prefix(100))
        }
        if unreadNotifications.count > 50 {
            unreadNotifications = Array(unreadNotifications.prefix(50))
        }
    }
    
    /// 標記通知為已讀
    func markNotificationAsRead(_ notificationId: UUID) {
        // 從未讀列表中移除
        unreadNotifications.removeAll { $0.id == notificationId }
        
        // 在全部通知中標記為已讀
        if let index = allNotifications.firstIndex(where: { $0.id == notificationId }) {
            var notification = allNotifications[index]
            allNotifications[index] = EligibilityNotification(
                type: notification.type,
                title: notification.title,
                message: notification.message,
                condition: notification.condition,
                currentValue: notification.currentValue,
                requiredValue: notification.requiredValue
            )
        }
        
        // 保存到本地
        saveNotificationsToLocal()
        
        // 更新應用圖標徽章
        updateAppBadge()
    }
    
    /// 標記所有通知為已讀
    func markAllNotificationsAsRead() {
        unreadNotifications.removeAll()
        saveNotificationsToLocal()
        updateAppBadge()
    }
    
    /// 清除所有通知
    func clearAllNotifications() {
        allNotifications.removeAll()
        unreadNotifications.removeAll()
        saveNotificationsToLocal()
        updateAppBadge()
    }
    
    // MARK: - 本地存儲
    
    /// 保存通知到本地
    private func saveNotificationsToLocal() {
        if let encoded = try? JSONEncoder().encode(allNotifications) {
            UserDefaults.standard.set(encoded, forKey: "eligibility_notifications_all")
        }
        
        if let encodedUnread = try? JSONEncoder().encode(unreadNotifications) {
            UserDefaults.standard.set(encodedUnread, forKey: "eligibility_notifications_unread")
        }
    }
    
    /// 從本地載入通知
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: "eligibility_notifications_all"),
           let notifications = try? JSONDecoder().decode([EligibilityNotification].self, from: data) {
            allNotifications = notifications
        }
        
        if let data = UserDefaults.standard.data(forKey: "eligibility_notifications_unread"),
           let notifications = try? JSONDecoder().decode([EligibilityNotification].self, from: data) {
            unreadNotifications = notifications
        }
        
        updateAppBadge()
    }
    
    /// 更新應用圖標徽章
    private func updateAppBadge() {
        UNUserNotificationCenter.current().setBadgeCount(unreadNotifications.count)
    }
    
    // MARK: - 事件監聽
    
    @objc private func readingLogSaved(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let authorId = userInfo["authorId"] as? UUID else { return }
        
        // 檢查是否需要發送接近門檻通知
        Task {
            await checkAndSendThresholdNotifications(for: authorId)
        }
    }
    
    /// 檢查並發送門檻通知
    private func checkAndSendThresholdNotifications(for authorId: UUID) async {
        // 獲取當前用戶ID
        guard let currentUser = supabaseService.getCurrentUser(),
              currentUser.id == authorId else { return }
        
        // 獲取最新的資格狀態
        if let status = await EligibilityEvaluationService.shared.getAuthorEligibilityStatus(authorId) {
            
            // 檢查獨立讀者數是否接近門檻
            let readersRemaining = 100 - status.last30DaysUniqueReaders
            if readersRemaining > 0 && readersRemaining <= 10 {
                await sendNearThresholdNotification(
                    condition: .uniqueReaders30Days,
                    currentValue: status.last30DaysUniqueReaders,
                    requiredValue: 100
                )
            }
            
            // 檢查是否剛達成資格
            if status.isEligible {
                // 檢查是否是第一次達成（可以通過檢查通知歷史來判斷）
                let hasQualifiedBefore = allNotifications.contains { $0.type == .qualified }
                if !hasQualifiedBefore {
                    await sendEligibilityAchievedNotification()
                }
            }
        }
    }
    
    // MARK: - 清理
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}