//
//  NotificationCategories.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  推播通知類別和行動按鈕定義
//

import UserNotifications
import Foundation

// MARK: - 推播通知類別擴展

extension UNNotificationCategory {
    
    // MARK: - 主持人訊息類別
    
    /// 主持人訊息推播類別
    static let hostMessage = UNNotificationCategory(
        identifier: "HOST_MESSAGE",
        actions: [
            UNNotificationAction(
                identifier: "REPLY",
                title: "回覆",
                options: [.foreground, .authenticationRequired],
                icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left")
            ),
            UNNotificationAction(
                identifier: "VIEW_GROUP",
                title: "查看群組",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "person.2")
            ),
            UNNotificationAction(
                identifier: "MUTE",
                title: "靜音",
                options: [],
                icon: UNNotificationActionIcon(systemImageName: "speaker.slash")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "主持人發送了一條訊息",
        options: [.customDismissAction]
    )
    
    // MARK: - 股價提醒類別
    
    /// 股價提醒推播類別
    static let stockAlert = UNNotificationCategory(
        identifier: "STOCK_ALERT",
        actions: [
            UNNotificationAction(
                identifier: "VIEW_STOCK",
                title: "查看股票",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "chart.line.uptrend.xyaxis")
            ),
            UNNotificationAction(
                identifier: "SET_NEW_ALERT",
                title: "設新提醒",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "bell.badge.plus")
            ),
            UNNotificationAction(
                identifier: "DISMISS_ALERT",
                title: "關閉提醒",
                options: [.destructive],
                icon: UNNotificationActionIcon(systemImageName: "bell.slash")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "股價到達目標價格",
        options: []
    )
    
    // MARK: - 排名更新類別
    
    /// 排名更新推播類別
    static let rankingUpdate = UNNotificationCategory(
        identifier: "RANKING_UPDATE",
        actions: [
            UNNotificationAction(
                identifier: "VIEW_RANKING",
                title: "查看排行榜",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "trophy")
            ),
            UNNotificationAction(
                identifier: "VIEW_PORTFOLIO",
                title: "查看投資組合",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "chart.pie")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "您的排名發生了變化",
        options: []
    )
    
    // MARK: - 聊天訊息類別
    
    /// 聊天訊息推播類別
    static let chatMessage = UNNotificationCategory(
        identifier: "CHAT_MESSAGE",
        actions: [
            UNNotificationAction(
                identifier: "QUICK_REPLY",
                title: "快速回覆",
                options: [.foreground, .authenticationRequired],
                icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left")
            ),
            UNNotificationAction(
                identifier: "VIEW_CHAT",
                title: "查看對話",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "message")
            ),
            UNNotificationAction(
                identifier: "MARK_AS_READ",
                title: "標記已讀",
                options: [],
                icon: UNNotificationActionIcon(systemImageName: "checkmark")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "您收到了一條新訊息",
        options: []
    )
    
    // MARK: - 投資更新類別
    
    /// 投資更新推播類別
    static let investmentUpdate = UNNotificationCategory(
        identifier: "INVESTMENT_UPDATE",
        actions: [
            UNNotificationAction(
                identifier: "VIEW_PORTFOLIO",
                title: "查看投資組合",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "chart.pie")
            ),
            UNNotificationAction(
                identifier: "VIEW_PERFORMANCE",
                title: "查看績效",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "chart.line.uptrend.xyaxis")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "您的投資組合有更新",
        options: []
    )
    
    // MARK: - 市場新聞類別
    
    /// 市場新聞推播類別
    static let marketNews = UNNotificationCategory(
        identifier: "MARKET_NEWS",
        actions: [
            UNNotificationAction(
                identifier: "READ_NEWS",
                title: "閱讀新聞",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "newspaper")
            ),
            UNNotificationAction(
                identifier: "SAVE_FOR_LATER",
                title: "稍後閱讀",
                options: [],
                icon: UNNotificationActionIcon(systemImageName: "bookmark")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "市場有重要新聞更新",
        options: []
    )
    
    // MARK: - 系統通知類別
    
    /// 系統通知推播類別
    static let systemAlert = UNNotificationCategory(
        identifier: "SYSTEM_ALERT",
        actions: [
            UNNotificationAction(
                identifier: "VIEW_DETAILS",
                title: "查看詳情",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "info.circle")
            ),
            UNNotificationAction(
                identifier: "DISMISS",
                title: "知道了",
                options: [],
                icon: UNNotificationActionIcon(systemImageName: "checkmark")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "系統通知",
        options: []
    )
    
    // MARK: - 群組邀請類別
    
    /// 群組邀請推播類別
    static let groupInvite = UNNotificationCategory(
        identifier: "GROUP_INVITE",
        actions: [
            UNNotificationAction(
                identifier: "ACCEPT_INVITE",
                title: "接受邀請",
                options: [.foreground, .authenticationRequired],
                icon: UNNotificationActionIcon(systemImageName: "checkmark.circle")
            ),
            UNNotificationAction(
                identifier: "DECLINE_INVITE",
                title: "拒絕邀請",
                options: [.destructive],
                icon: UNNotificationActionIcon(systemImageName: "xmark.circle")
            ),
            UNNotificationAction(
                identifier: "VIEW_GROUP_INFO",
                title: "查看群組",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "info.circle")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "您收到群組邀請",
        options: []
    )
    
    // MARK: - 交易提醒類別
    
    /// 交易提醒推播類別
    static let tradingAlert = UNNotificationCategory(
        identifier: "TRADING_ALERT",
        actions: [
            UNNotificationAction(
                identifier: "EXECUTE_TRADE",
                title: "執行交易",
                options: [.foreground, .authenticationRequired],
                icon: UNNotificationActionIcon(systemImageName: "dollarsign.circle")
            ),
            UNNotificationAction(
                identifier: "VIEW_MARKET",
                title: "查看市場",
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: "chart.bar")
            ),
            UNNotificationAction(
                identifier: "SNOOZE_ALERT",
                title: "稍後提醒",
                options: [],
                icon: UNNotificationActionIcon(systemImageName: "clock")
            )
        ],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "交易提醒",
        options: []
    )
    
    // MARK: - 所有推播類別
    
    /// 獲取所有推播通知類別
    static var all: Set<UNNotificationCategory> {
        return [
            hostMessage,
            stockAlert,
            rankingUpdate,
            chatMessage,
            investmentUpdate,
            marketNews,
            systemAlert,
            groupInvite,
            tradingAlert
        ]
    }
}

// MARK: - 推播行動處理器

class NotificationActionHandler {
    
    /// 處理推播行動
    static func handleAction(
        identifier: String,
        notification: UNNotification,
        completionHandler: @escaping () -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📱 [NotificationActionHandler] 處理行動: \(identifier)")
        print("📱 [NotificationActionHandler] 用戶資訊: \(userInfo)")
        
        Task {
            await processAction(identifier: identifier, userInfo: userInfo)
            completionHandler()
        }
    }
    
    /// 非同步處理行動
    private static func processAction(identifier: String, userInfo: [AnyHashable: Any]) async {
        switch identifier {
        // 主持人訊息行動
        case "REPLY":
            await handleReplyAction(userInfo: userInfo)
        case "VIEW_GROUP":
            await handleViewGroupAction(userInfo: userInfo)
        case "MUTE":
            await handleMuteAction(userInfo: userInfo)
            
        // 股價提醒行動
        case "VIEW_STOCK":
            await handleViewStockAction(userInfo: userInfo)
        case "SET_NEW_ALERT":
            await handleSetNewAlertAction(userInfo: userInfo)
        case "DISMISS_ALERT":
            await handleDismissAlertAction(userInfo: userInfo)
            
        // 排名更新行動
        case "VIEW_RANKING":
            await handleViewRankingAction(userInfo: userInfo)
        case "VIEW_PORTFOLIO":
            await handleViewPortfolioAction(userInfo: userInfo)
            
        // 聊天訊息行動
        case "QUICK_REPLY":
            await handleQuickReplyAction(userInfo: userInfo)
        case "VIEW_CHAT":
            await handleViewChatAction(userInfo: userInfo)
        case "MARK_AS_READ":
            await handleMarkAsReadAction(userInfo: userInfo)
            
        // 通用行動
        case "VIEW_DETAILS":
            await handleViewDetailsAction(userInfo: userInfo)
        case "DISMISS":
            await handleDismissAction(userInfo: userInfo)
            
        default:
            print("⚠️ [NotificationActionHandler] 未處理的行動: \(identifier)")
        }
    }
    
    // MARK: - 行動處理方法
    
    private static func handleReplyAction(userInfo: [AnyHashable: Any]) async {
        if let groupId = userInfo["group_id"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowReplyInterface"),
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }
    
    private static func handleViewGroupAction(userInfo: [AnyHashable: Any]) async {
        if let groupId = userInfo["group_id"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToGroup"),
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }
    
    private static func handleMuteAction(userInfo: [AnyHashable: Any]) async {
        if let groupId = userInfo["group_id"] as? String {
            // 實現群組靜音邏輯
            print("🔇 靜音群組: \(groupId)")
        }
    }
    
    private static func handleViewStockAction(userInfo: [AnyHashable: Any]) async {
        if let stockSymbol = userInfo["stock_symbol"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToStock"),
                object: nil,
                userInfo: ["stockSymbol": stockSymbol]
            )
        }
    }
    
    private static func handleSetNewAlertAction(userInfo: [AnyHashable: Any]) async {
        if let stockSymbol = userInfo["stock_symbol"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowStockAlertInterface"),
                object: nil,
                userInfo: ["stockSymbol": stockSymbol]
            )
        }
    }
    
    private static func handleDismissAlertAction(userInfo: [AnyHashable: Any]) async {
        // 實現關閉股價提醒邏輯
        print("🔕 關閉股價提醒")
    }
    
    private static func handleViewRankingAction(userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToRanking"),
            object: nil
        )
    }
    
    private static func handleViewPortfolioAction(userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToPortfolio"),
            object: nil
        )
    }
    
    private static func handleQuickReplyAction(userInfo: [AnyHashable: Any]) async {
        if let chatId = userInfo["chat_id"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowQuickReplyInterface"),
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
    }
    
    private static func handleViewChatAction(userInfo: [AnyHashable: Any]) async {
        if let chatId = userInfo["chat_id"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToChat"),
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
    }
    
    private static func handleMarkAsReadAction(userInfo: [AnyHashable: Any]) async {
        // 實現標記訊息為已讀的邏輯
        if let chatId = userInfo["chat_id"] as? String {
            print("✅ 標記對話已讀: \(chatId)")
        }
    }
    
    private static func handleViewDetailsAction(userInfo: [AnyHashable: Any]) async {
        // 實現查看詳情邏輯
        print("🔍 查看通知詳情")
    }
    
    private static func handleDismissAction(userInfo: [AnyHashable: Any]) async {
        // 實現關閉通知邏輯
        print("✅ 關閉通知")
    }
}