# iOS 推播通知配置指南

## 問題解決方案

您遇到的問題是典型的iOS開發配置問題。根據截圖顯示：

### 問題1：個人開發者賬號限制
**錯誤訊息**：Cannot create a iOS App Development provisioning profile for "wyatt.com.Invest-V3". Personal development teams, including "JIAQI LIN", do not support the Communication Notifications and Push Notifications capabilities.

**解決方案**：
- 個人開發者賬號（免費）不支援推播通知功能
- 需要升級到付費Apple Developer Program（每年$99 USD）

### 問題2：Bundle ID不匹配
**錯誤訊息**：No profiles for 'wyatt.com.Invest-V3' were found

## 立即解決方案

### 選項A：使用本地通知（推薦給個人開發者）

1. **移除推播通知能力**：
   - 在Xcode中選擇您的project
   - 選擇target → Signing & Capabilities
   - 移除"Push Notifications"能力
   - 移除"Background Modes"中的"Remote notifications"

2. **使用本地通知替代**：
   - 使用我們創建的`LocalNotificationService`
   - 本地通知在應用程式關閉時仍可工作
   - 適合股價提醒、排名更新等功能

3. **更新Bundle ID配置**：
   ```swift
   // 在 PushNotificationConfig.swift 中
   static let bundleId = "wyatt.com.Invest-V3"  // 確保匹配您的實際Bundle ID
   ```

### 選項B：升級到付費開發者賬號

如果您需要遠程推播功能：

1. **升級Apple Developer Program**：
   - 訪問 https://developer.apple.com/programs/
   - 註冊付費開發者賬號（$99/年）

2. **配置App ID**：
   - 在Apple Developer Portal中創建App ID
   - Bundle ID: `wyatt.com.Invest-V3`
   - 啟用"Push Notifications"能力

3. **創建憑證**：
   - 選項1：創建APNs憑證（推薦用於測試）
   - 選項2：創建APNs Auth Key（推薦用於生產）

4. **配置Provisioning Profile**：
   - 創建Development Provisioning Profile
   - 包含推播通知能力
   - 下載並安裝到Xcode

## Xcode項目設定

### 1. Bundle Identifier
確保在Xcode中的Bundle Identifier與您在Apple Developer Portal中設定的完全一致：
```
wyatt.com.Invest-V3
```

### 2. Team設定
在Signing & Capabilities中：
- 選擇正確的Team
- 確保Automatically manage signing已啟用

### 3. Capabilities（如果使用付費賬號）
添加以下能力：
- Push Notifications
- Background Modes → Remote notifications

## 程式碼更新

### 使用本地通知（當前推薦）
```swift
// 在你的ViewModel或Service中
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }
    
    func sendLocalNotification(title: String, body: String, delay: Double = 1) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

### 如果升級到付費賬號後使用遠程推播
```swift
// 在 AppDelegate 或 App.swift 中
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 註冊推播通知
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return true
}

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    // 將token發送到您的伺服器
    print("Device Token: \(token)")
}
```

## 測試步驟

1. **清理項目**：
   - Product → Clean Build Folder
   - 刪除 DerivedData

2. **重新建置**：
   - 確保沒有build錯誤
   - 檢查Bundle ID正確

3. **測試本地通知**：
   - 使用提供的`LocalNotificationTestView`
   - 測試各種通知類型

4. **部署測試**：
   - 在真實設備上測試
   - 確保通知權限正常

## 常見問題解決

### Q: 為什麼個人開發者賬號不能使用推播？
A: Apple的政策限制，個人免費賬號只能使用基本功能，推播通知需要付費賬號。

### Q: 本地通知夠用嗎？
A: 對於大多數應用是夠用的：
- ✅ 股價到價提醒
- ✅ 排名更新
- ✅ 系統通知
- ❌ 無法在應用完全關閉時接收即時訊息

### Q: 如何測試通知？
A: 使用提供的`LocalNotificationTestView`，可以測試各種通知場景。

## 建議

對於您的投資應用，建議：

1. **短期**：使用本地通知解決當前問題
2. **長期**：考慮升級付費開發者賬號以支援更多功能
3. **用戶體驗**：本地通知已能滿足大部分需求，如股價提醒、排名更新等

使用提供的程式碼，您可以立即解決配置問題並繼續開發。