//
//  PushNotificationConfig.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  推播通知系統配置
//

import Foundation

// MARK: - 推播通知配置

struct PushNotificationConfig {
    
    // MARK: - APNs 環境配置
    
    /// 當前 APNs 環境
    static var environment: APNsEnvironment {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }
    
    /// APNs 伺服器端點
    static var apnsServer: String {
        switch environment {
        case .sandbox:
            return "https://api.sandbox.push.apple.com"
        case .production:
            return "https://api.push.apple.com"
        }
    }
    
    // MARK: - 應用程式配置
    
    /// Bundle Identifier
    static let bundleId = "com.yourcompany.invest-v3"
    
    /// Team ID (需要從 Apple Developer Console 獲取)
    static let teamId = "YOUR_TEAM_ID"
    
    /// Key ID (如果使用 APNs Auth Key)
    static let keyId = "YOUR_KEY_ID"
    
    // MARK: - 推播設定
    
    /// 預設推播音效
    static let defaultSound = "default"
    
    /// 推播有效期限 (秒)
    static let expiration: TimeInterval = 3600 // 1 小時
    
    /// 推播優先級
    static let priority = 10 // 立即傳送
    
    /// 最大重試次數
    static let maxRetryAttempts = 3
    
    /// 重試延遲 (秒)
    static let retryDelay: TimeInterval = 5
    
    // MARK: - Payload 限制
    
    /// 推播 Payload 最大大小
    static let maxPayloadSize = 4096 // 4KB
    
    /// 標題最大長度
    static let maxTitleLength = 50
    
    /// 內容最大長度
    static let maxBodyLength = 200
    
    // MARK: - 環境檢查
    
    /// 檢查是否為開發環境
    static var isDevelopment: Bool {
        return environment == .sandbox
    }
    
    /// 檢查是否為生產環境
    static var isProduction: Bool {
        return environment == .production
    }
}

// MARK: - APNs 環境枚舉

enum APNsEnvironment: String {
    case sandbox = "sandbox"
    case production = "production"
    
    var displayName: String {
        switch self {
        case .sandbox:
            return "開發環境"
        case .production:
            return "生產環境"
        }
    }
}

// MARK: - 推播通知模板

struct PushNotificationTemplate {
    let title: String
    let body: String
    let sound: String
    let badge: Int?
    let category: String?
    let userInfo: [AnyHashable: Any]
    
    init(
        title: String,
        body: String,
        sound: String = PushNotificationConfig.defaultSound,
        badge: Int? = nil,
        category: String? = nil,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        self.title = title
        self.body = body
        self.sound = sound
        self.badge = badge
        self.category = category
        self.userInfo = userInfo
    }
    
    /// 轉換為 APNs payload
    func toPayload() -> [AnyHashable: Any] {
        var aps: [String: Any] = [
            "alert": [
                "title": title,
                "body": body
            ],
            "sound": sound
        ]
        
        if let badge = badge {
            aps["badge"] = badge
        }
        
        if let category = category {
            aps["category"] = category
        }
        
        var payload: [AnyHashable: Any] = ["aps": aps]
        
        // 添加自定義資料
        for (key, value) in userInfo {
            payload[key] = value
        }
        
        return payload
    }
    
    /// 檢查 payload 大小是否符合限制
    func validatePayloadSize() -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: toPayload(), options: [])
            return data.count <= PushNotificationConfig.maxPayloadSize
        } catch {
            return false
        }
    }
}

// MARK: - 常用推播模板

extension PushNotificationTemplate {
    
    /// 主持人訊息推播
    static func hostMessage(hostName: String, message: String, groupId: String) -> PushNotificationTemplate {
        return PushNotificationTemplate(
            title: "來自 \(hostName) 的訊息",
            body: message,
            category: "HOST_MESSAGE",
            userInfo: [
                "type": "host_message",
                "group_id": groupId,
                "host_name": hostName
            ]
        )
    }
    
    /// 排名更新推播
    static func rankingUpdate(newRank: Int, previousRank: Int) -> PushNotificationTemplate {
        let title = "排名更新"
        let body: String
        
        if newRank < previousRank {
            body = "恭喜！您的排名從第 \(previousRank) 名上升到第 \(newRank) 名！"
        } else {
            body = "您的排名更新為第 \(newRank) 名"
        }
        
        return PushNotificationTemplate(
            title: title,
            body: body,
            category: "RANKING_UPDATE",
            userInfo: [
                "type": "ranking_update",
                "new_rank": newRank,
                "previous_rank": previousRank
            ]
        )
    }
    
    /// 股價提醒推播
    static func stockPriceAlert(
        stockSymbol: String,
        stockName: String,
        targetPrice: Double,
        currentPrice: Double
    ) -> PushNotificationTemplate {
        return PushNotificationTemplate(
            title: "股價到價提醒",
            body: "\(stockName) (\(stockSymbol)) 已達到目標價格 $\(targetPrice)，目前價格 $\(currentPrice)",
            category: "STOCK_ALERT",
            userInfo: [
                "type": "stock_price_alert",
                "stock_symbol": stockSymbol,
                "stock_name": stockName,
                "target_price": targetPrice,
                "current_price": currentPrice
            ]
        )
    }
    
    /// 聊天訊息推播
    static func chatMessage(senderName: String, message: String, chatId: String) -> PushNotificationTemplate {
        return PushNotificationTemplate(
            title: senderName,
            body: message,
            category: "CHAT_MESSAGE",
            userInfo: [
                "type": "chat_message",
                "chat_id": chatId,
                "sender_name": senderName
            ]
        )
    }
    
    /// 系統通知推播
    static func systemAlert(title: String, message: String, alertType: String = "info") -> PushNotificationTemplate {
        return PushNotificationTemplate(
            title: title,
            body: message,
            category: "SYSTEM_ALERT",
            userInfo: [
                "type": "system_alert",
                "alert_type": alertType
            ]
        )
    }
}

// MARK: - 推播統計

struct PushNotificationStats {
    var sent: Int = 0
    var delivered: Int = 0
    var opened: Int = 0
    var failed: Int = 0
    
    var deliveryRate: Double {
        return sent > 0 ? Double(delivered) / Double(sent) : 0
    }
    
    var openRate: Double {
        return delivered > 0 ? Double(opened) / Double(delivered) : 0
    }
    
    var failureRate: Double {
        return sent > 0 ? Double(failed) / Double(sent) : 0
    }
}

// MARK: - 推播錯誤處理

enum PushNotificationError: Error, LocalizedError {
    case invalidDeviceToken
    case payloadTooLarge
    case quotaExceeded
    case serverError(Int)
    case certificateError
    case networkError(Error)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidDeviceToken:
            return "無效的設備 Token"
        case .payloadTooLarge:
            return "推播內容過大"
        case .quotaExceeded:
            return "推播配額已用盡"
        case .serverError(let code):
            return "伺服器錯誤 (代碼: \(code))"
        case .certificateError:
            return "推播憑證錯誤"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .unknownError:
            return "未知錯誤"
        }
    }
    
    var shouldRetry: Bool {
        switch self {
        case .serverError(let code):
            return code >= 500
        case .quotaExceeded, .networkError:
            return true
        default:
            return false
        }
    }
}