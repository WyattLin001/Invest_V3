//
//  AppNotification.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  App通知數據模型
//

import Foundation

// MARK: - 應用通知模型

struct AppNotification: Identifiable, Codable {
    let id: String
    let title: String
    let message: String
    let type: AppNotificationType
    let isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message = "body"
        case type = "notification_type"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    init(id: String = UUID().uuidString, title: String, message: String, type: AppNotificationType, isRead: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

// MARK: - 通知類型定義

enum AppNotificationType: String, CaseIterable, Codable {
    case hostMessage = "host_message"
    case rankingUpdate = "ranking_update"
    case stockPriceAlert = "stock_price_alert"
    case chatMessage = "chat_message"
    case investmentUpdate = "investment_update"
    case marketNews = "market_news"
    case systemAlert = "system_alert"
    case groupInvite = "group_invite"
    case tradingAlert = "trading_alert"
    
    var displayName: String {
        switch self {
        case .hostMessage: return "主持人訊息"
        case .rankingUpdate: return "排名更新"
        case .stockPriceAlert: return "股價提醒"
        case .chatMessage: return "聊天訊息"
        case .investmentUpdate: return "投資更新"
        case .marketNews: return "市場新聞"
        case .systemAlert: return "系統通知"
        case .groupInvite: return "群組邀請"
        case .tradingAlert: return "交易提醒"
        }
    }
    
    var iconName: String {
        switch self {
        case .hostMessage: return "person.wave.2"
        case .rankingUpdate: return "trophy"
        case .stockPriceAlert: return "chart.line.uptrend.xyaxis"
        case .chatMessage: return "message"
        case .investmentUpdate: return "dollarsign.circle"
        case .marketNews: return "newspaper"
        case .systemAlert: return "exclamationmark.circle"
        case .groupInvite: return "person.2.badge.plus"
        case .tradingAlert: return "bell.badge"
        }
    }
    
    var categoryIdentifier: String {
        switch self {
        case .hostMessage: return "HOST_MESSAGE"
        case .rankingUpdate: return "RANKING_UPDATE"
        case .stockPriceAlert: return "STOCK_ALERT"
        case .chatMessage: return "CHAT_MESSAGE"
        case .investmentUpdate: return "INVESTMENT_UPDATE"
        case .marketNews: return "MARKET_NEWS"
        case .systemAlert: return "SYSTEM_ALERT"
        case .groupInvite: return "GROUP_INVITE"
        case .tradingAlert: return "TRADING_ALERT"
        }
    }
}