# Apple 推播通知完整配置指南

> **文件版本**: 1.0  
> **更新日期**: 2025-08-05  
> **適用項目**: Invest_V3  
> **作者**: Claude Code Assistant

## 🎯 配置目標

為 Invest_V3 iOS 應用程式配置完整的 Apple 推播通知服務，包含：
- Apple Developer Console 推播證書設置
- Xcode 項目推播功能啟用
- APNs 生產和開發環境配置
- 推播通知測試和驗證

## 📋 前置要求

### 必需條件
- ✅ Apple Developer Program 會員資格 ($99/年)
- ✅ Xcode 最新版本
- ✅ macOS 開發環境
- ✅ Invest_V3 項目完整代碼

### 技術要求
- iOS 10.0+ 目標版本
- Swift 5.0+
- 有效的 Bundle Identifier

## 🍎 步驟一：Apple Developer Console 配置

### 1.1 登入 Apple Developer Console

1. 前往 [Apple Developer](https://developer.apple.com/account/)
2. 使用您的 Apple Developer 帳號登入
3. 選擇 "Certificates, Identifiers & Profiles"

### 1.2 創建/配置 App ID

#### 創建新的 App ID（如果尚未存在）：

```bash
# 建議的 Bundle ID 格式
com.yourcompany.invest-v3
```

1. 點擊 "Identifiers" → "+" 按鈕
2. 選擇 "App IDs" → "App"
3. 填寫以下資訊：
   - **Description**: Invest_V3 - 投資知識分享平台
   - **Bundle ID**: `com.yourcompany.invest-v3`
   - **Platform**: iOS, tvOS

#### 啟用推播通知功能：

4. 在 "Capabilities" 區段中：
   - ✅ 勾選 "Push Notifications"
   - ✅ 勾選 "App Groups" (如需群組通知)
   - ✅ 勾選 "Background Modes" (如需背景推播)

5. 點擊 "Continue" → "Register"

### 1.3 生成推播通知證書

#### 開發環境證書 (Development):

1. 選擇 "Certificates" → "+" 按鈕
2. 選擇 "Apple Push Notification service SSL (Sandbox & Production)"
3. 選擇您的 App ID
4. 上傳 Certificate Signing Request (CSR) 文件

#### 生成 CSR 文件：
```bash
# 在 Mac 上打開 "鑰匙圈存取"
1. 選擇 "鑰匙圈存取" > "憑證輔助程式" > "從憑證機構要求憑證"
2. 填寫電子信箱地址
3. 常用名稱：Invest_V3 Push Notifications
4. 存儲到磁碟機
```

5. 下載生成的 `.cer` 文件
6. 雙擊安裝到 macOS 鑰匙圈

#### 匯出 .p12 憑證文件：
1. 在鑰匙圈中找到安裝的推播憑證
2. 右擊 → "Export"
3. 選擇格式 "Personal Information Exchange (.p12)"
4. 設置密碼並記住（後面會用到）
5. 保存 `.p12` 文件

### 1.4 生產環境證書 (Production)

重複上述步驟，但選擇：
- "Apple Push Notification service SSL (Sandbox & Production)"
- 用於 App Store 發布的生產憑證

## 📱 步驟二：Xcode 項目配置

### 2.1 啟用推播通知功能

1. 在 Xcode 中打開 Invest_V3 項目
2. 選擇項目名稱 → "TARGETS" → "Invest_V3"
3. 選擇 "Signing & Capabilities" 標籤
4. 點擊 "+ Capability"
5. 搜索並添加 "Push Notifications"

### 2.2 配置 Bundle Identifier

確保 Bundle Identifier 與 Apple Developer Console 中的完全一致：
```
com.yourcompany.invest-v3
```

### 2.3 配置 Team 和 Signing

1. 在 "Signing" 區段選擇您的開發團隊
2. 確保 "Automatically manage signing" 已啟用
3. 驗證 Provisioning Profile 包含推播通知權限

### 2.4 添加推播通知權限到 Info.plist

雖然 Xcode 會自動添加，但請確認以下設置：

```xml
<!-- 在 Info.plist 中添加 -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>
```

## 🔧 步驟三：推播通知配置檔案

### 3.1 創建推播通知配置

創建推播通知配置文件：

```swift
// File: PushNotificationConfig.swift
import Foundation

struct PushNotificationConfig {
    // APNs 環境配置
    static var environment: APNsEnvironment {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }
    
    // 推播伺服器配置
    static let apnsServer = environment == .sandbox ? 
        "https://api.sandbox.push.apple.com" : 
        "https://api.push.apple.com"
    
    // 應用程式相關設定
    static let bundleId = "com.yourcompany.invest-v3"
    static let teamId = "YOUR_TEAM_ID" // 從 Apple Developer 獲取
}

enum APNsEnvironment {
    case sandbox
    case production
}
```

### 3.2 推播通知類別定義

```swift
// File: NotificationCategories.swift
import UserNotifications

extension UNNotificationCategory {
    // 主持人訊息類別
    static let hostMessage = UNNotificationCategory(
        identifier: "HOST_MESSAGE",
        actions: [
            UNNotificationAction(
                identifier: "REPLY",
                title: "回覆",
                options: [.foreground, .authenticationRequired]
            ),
            UNNotificationAction(
                identifier: "VIEW",
                title: "查看",
                options: [.foreground]
            )
        ],
        intentIdentifiers: [],
        options: []
    )
    
    // 股價提醒類別
    static let stockAlert = UNNotificationCategory(
        identifier: "STOCK_ALERT",
        actions: [
            UNNotificationAction(
                identifier: "VIEW_STOCK",
                title: "查看股票",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "SET_ALERT",
                title: "設置提醒",
                options: [.foreground]
            )
        ],
        intentIdentifiers: [],
        options: []
    )
    
    // 所有推播類別
    static var all: Set<UNNotificationCategory> {
        return [hostMessage, stockAlert]
    }
}
```

## 🧪 步驟四：測試推播通知

### 4.1 使用 Xcode 模擬器測試

1. 運行應用程式在實機上（模擬器不支援推播）
2. 同意推播通知權限
3. 查看 Console 日誌確認 Device Token

### 4.2 使用 Push Notification Console 測試

Apple 提供的官方測試工具：

1. 下載 [Push Notification Console](https://developer.apple.com/documentation/usernotifications/testing_notifications_using_the_push_notification_console)
2. 導入您的 .p12 憑證
3. 使用獲取的 Device Token 發送測試通知

### 4.3 命令行測試 (進階)

使用 curl 命令測試推播：

```bash
# 使用 curl 發送測試推播 (需要 JWT token)
curl -v \
-d '{"aps":{"alert":"Test notification","sound":"default"}}' \
-H "apns-topic: com.yourcompany.invest-v3" \
-H "apns-push-type: alert" \
-H "authorization: bearer [JWT_TOKEN]" \
--http2 \
https://api.sandbox.push.apple.com/3/device/[DEVICE_TOKEN]
```

## 📊 步驟五：推播分析和監控

### 5.1 推播成功率監控

在應用程式中添加推播統計：

```swift
// 推播統計結構
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
}
```

### 5.2 錯誤處理和重試機制

```swift
// 推播失敗處理
enum PushNotificationError: Error {
    case invalidDeviceToken
    case payloadTooLarge
    case quotaExceeded
    case serverError(Int)
    
    var shouldRetry: Bool {
        switch self {
        case .serverError(let code):
            return code >= 500
        case .quotaExceeded:
            return true
        default:
            return false
        }
    }
}
```

## ⚠️ 常見問題和解決方案

### Q1: Device Token 為空或無效
**解決方案**:
1. 確認推播權限已授權
2. 檢查 Bundle ID 是否正確
3. 驗證推播憑證是否有效
4. 確保在實機上測試（非模擬器）

### Q2: 推播通知無法顯示
**解決方案**:
1. 檢查通知權限設定
2. 驗證 payload 格式正確
3. 確認憑證環境（sandbox vs production）
4. 檢查應用程式是否在前景/背景

### Q3: 憑證過期或無效
**解決方案**:
1. 重新生成推播憑證
2. 更新 .p12 文件
3. 重新配置伺服器端憑證

## 📝 檢查清單

在完成配置後，請確認以下項目：

### Apple Developer Console
- [ ] App ID 已創建並啟用推播通知
- [ ] 推播憑證已生成 (開發 + 生產)
- [ ] .p12 憑證文件已匯出並記住密碼

### Xcode 項目
- [ ] Push Notifications capability 已添加
- [ ] Bundle ID 正確設置
- [ ] Team 和 Signing 已配置
- [ ] Background Modes 已啟用

### 應用程式代碼
- [ ] AppDelegate 已集成
- [ ] NotificationService 已完善
- [ ] 推播權限請求已實現
- [ ] Device Token 註冊已實現

### 測試驗證
- [ ] 實機測試推播權限請求
- [ ] Device Token 成功獲取
- [ ] 本地通知功能正常
- [ ] 推播通知測試成功

## 🚀 下一步：Supabase 整合

完成 Apple 配置後，下一步將是：
1. 配置 Supabase Edge Functions 推播服務
2. 實現伺服器端推播發送邏輯
3. 建立推播通知管理後台

---

**配置完成後，您將擁有完整的 Apple 推播通知基礎架構！** 🎉

有任何問題歡迎詢問，我會協助您完成每個步驟。