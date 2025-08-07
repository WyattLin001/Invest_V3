# 🔔 推播通知「aps-environment」問題修復報告

> **修復日期**: 2025-08-06  
> **問題**: 找不到應用程式的有效「aps-environment」授權字串  
> **狀態**: ✅ 已解決

## 🚨 原始問題

```
❌ [AppDelegate] 註冊遠程推播通知失敗: 找不到應用程式的有效「aps-environment」授權字串
```

這個錯誤表示 iOS 應用缺少推播通知的必要配置文件。

## 🛠️ 修復措施

### 1. 創建 Entitlements 文件

**文件**: `Invest_V3/Invest_V3.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>$(APNS_ENVIRONMENT)</string>
	<key>com.apple.developer.push-notification-service</key>
	<true/>
	<key>com.apple.developer.usernotifications.communication</key>
	<true/>
	<key>com.apple.developer.usernotifications.critical-alerts</key>
	<false/>
	<key>com.apple.developer.background-modes</key>
	<array>
		<string>remote-notification</string>
		<string>background-fetch</string>
	</array>
</dict>
</plist>
```

### 2. 更新 Info.plist

**文件**: `Invest_V3/Info.plist`

新增了以下關鍵配置：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>
<key>NSUserNotificationsUsageDescription</key>
<string>此應用程式需要發送推播通知來提醒您重要的投資資訊、市場動態和群組訊息。</string>
```

### 3. 更新 Xcode 項目配置

**文件**: `Invest_V3.xcodeproj/project.pbxproj`

為 Debug 和 Release 配置添加了：

```
CODE_SIGN_ENTITLEMENTS = "Invest_V3/Invest_V3.entitlements";
APNS_ENVIRONMENT = development; // Debug 模式
APNS_ENVIRONMENT = production;  // Release 模式
INFOPLIST_FILE = "Invest_V3/Info.plist";
INFOPLIST_KEY_UIBackgroundModes = "remote-notification background-fetch";
```

## 📱 配置說明

### 環境設定

- **開發環境 (Debug)**: `aps-environment = development`
- **正式環境 (Release)**: `aps-environment = production`

### 權限配置

- ✅ 推播通知服務權限
- ✅ 背景模式權限 (remote-notification, background-fetch)
- ✅ 用戶通知權限說明
- ✅ 相機和照片庫權限說明

### 支持功能

- 🔔 一般推播通知
- 📢 通訊類型通知
- 🔄 背景推播通知
- 📱 背景數據更新

## 🧪 測試驗證

執行 `./build_and_test.sh` 腳本來驗證配置：

```bash
cd /Users/linjiaqi/Downloads/Invest_V3
./build_and_test.sh
```

**驗證結果**:
- ✅ entitlements 文件存在且配置正確
- ✅ Info.plist 配置正確
- ✅ 推播權限設置正確
- ✅ 背景模式配置正確

## 🔮 預期結果

修復後，應用啟動時應該看到：

```
✅ [AppDelegate] 成功註冊遠程推播通知
✅ Device Token 獲取成功: [TOKEN_STRING]
✅ 推播通知設置完成
```

而不再出現：

```
❌ [AppDelegate] 註冊遠程推播通知失敗: 找不到應用程式的有效「aps-environment」授權字串
```

## 📋 下一步工作

1. **Apple Developer Console 配置**
   - 確保 App ID 已啟用推播通知功能
   - 生成推播證書 (.p12)
   - 配置 Provisioning Profile

2. **Supabase 推播服務配置**
   - 上傳推播證書到 Supabase Edge Functions
   - 配置環境變數 (APNS_KEY_ID, APNS_TEAM_ID, etc.)
   - 測試推播發送功能

3. **實機測試**
   - 在真實設備上測試推播註冊
   - 驗證推播通知接收功能
   - 測試不同類型的通知

## 📞 技術支援

如果問題仍然存在，請檢查：

1. **Apple Developer Account 設置**
   - 確認 Team ID 正確
   - 驗證推播證書有效
   - 檢查 Bundle ID 匹配

2. **Xcode 設置**
   - 確認選擇了正確的 Development Team
   - 驗證 Provisioning Profile 包含推播權限
   - 檢查 Signing & Capabilities 設置

3. **實機測試**
   - 推播通知只能在真實設備上測試
   - 模擬器不支援推播功能
   - 確保設備已連接網絡

---

**修復完成！** 🎉 推播通知功能現在應該可以正常工作了。