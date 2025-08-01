# n8n.io 雲端平台部署指南

## 🚀 完整部署流程

本指南將引導您在 n8n.io 官方雲端平台上部署 AI 投資文章自動化系統。

## 📋 前置準備清單

### ✅ 必要帳號和服務
- [ ] n8n.io 雲端帳號
- [ ] OpenAI API 帳號 (GPT-4 存取權限)
- [ ] Supabase 專案 (已建立 articles 表)
- [ ] Slack 工作區和 App
- [ ] iOS App (Invest_V3) 已部署

### ✅ 必要資訊收集
```bash
# 收集以下資訊並記錄：
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
AI_AUTHOR_ID=uuid-of-ai-author-account
OPENAI_API_KEY=your-openai-api-key
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
```

---

## 🔧 第一步：n8n.io 帳號設定

### 1.1 註冊 n8n.io 雲端服務
```bash
# 前往 https://n8n.io
# 點擊 "Get started for free"
# 選擇適合的訂閱方案（建議 Starter 或更高）
```

### 1.2 創建工作空間
```bash
# 登入後創建新的工作空間
# 工作空間名稱: "Invest_V3_AI_Articles"
# 選擇地區: Asia Pacific (最接近台灣)
```

### 1.3 基本設定
```bash
# 設定時區: Asia/Taipei
# 啟用執行記錄保存
# 設定團隊成員（如需要）
```

---

## 🔑 第二步：憑證管理設定

### 2.1 OpenAI API 憑證
```bash
# 在 n8n.io 介面中：
# 1. 前往 Settings > Credentials
# 2. 點擊 "Add Credential"
# 3. 選擇 "OpenAI API"
# 4. 設定：
#    - Name: "OpenAI API"
#    - API Key: [您的 OpenAI API 金鑰]
# 5. 測試連線並儲存
```

### 2.2 Supabase API 憑證
```bash
# 添加 Supabase 憑證：
# 1. 選擇 "Supabase API"
# 2. 設定：
#    - Name: "Supabase API"
#    - URL: https://your-project.supabase.co
#    - Service Role Key: [您的 Supabase Service Role Key]
# 3. 測試連線並儲存
```

### 2.3 Slack API 憑證
```bash
# 添加 Slack 憑證：
# 1. 選擇 "Slack API"
# 2. 設定：
#    - Name: "Slack API"
#    - Bot Token: xoxb-your-slack-bot-token
# 3. 測試連線並儲存
```

---

## 📁 第三步：工作流程匯入

### 3.1 匯入主要工作流程
```bash
# 在 n8n.io 介面中：
# 1. 點擊 "Import from file"
# 2. 上傳 "n8n_simplified_workflow.json"
# 3. 確認所有節點正確連結
# 4. 檢查憑證是否自動關聯
```

### 3.2 匯入 Webhook 處理工作流程
```bash
# 1. 再次點擊 "Import from file"
# 2. 上傳 "n8n_slack_webhook_simplified.json"
# 3. 記錄 Webhook URL（稍後 Slack 設定需要）
# 4. 測試 Webhook 端點可用性
```

### 3.3 設定環境變數
```bash
# 在工作流程設定中添加環境變數：
# 1. 點擊工作流程設定圖示
# 2. 前往 "Settings" > "Environment Variables"
# 3. 添加：
#    - AI_AUTHOR_ID: [您的 AI 作者 UUID]
#    - 其他必要變數
```

---

## 🤖 第四步：Slack App 整合設定

### 4.1 配置 Slack App Interactive Components
```bash
# 在 Slack API 網站 (api.slack.com)：
# 1. 前往您的 Slack App
# 2. 點擊 "Interactivity & Shortcuts"
# 3. 啟用 "Interactivity"
# 4. 設定 Request URL:
#    https://your-n8n-instance.app.n8n.cloud/webhook/slack-review
```

### 4.2 確認 Slack 權限
```bash
# 確認 Bot Token Scopes 包含：
# - chat:write
# - chat:write.public
# - channels:read
# - groups:read
# - users:read
```

### 4.3 安裝 App 到工作區
```bash
# 1. 點擊 "Install App"
# 2. 選擇目標工作區
# 3. 確認權限並安裝
# 4. 複製 Bot User OAuth Token
```

---

## 🧪 第五步：測試和驗證

### 5.1 手動執行測試
```bash
# 在 n8n.io 中：
# 1. 打開主要工作流程
# 2. 點擊 "Execute Workflow" 
# 3. 觀察每個節點的執行結果
# 4. 確認 Slack 通知正常發送
```

### 5.2 Slack 互動測試
```bash
# 1. 在 Slack 中找到機器人發送的訊息
# 2. 點擊 "通過發布" 或 "拒絕發布" 按鈕
# 3. 確認 Webhook 處理正常
# 4. 檢查 Supabase 中文章狀態是否更新
```

### 5.3 iOS App 驗證
```bash
# 1. 打開 Invest_V3 iOS App
# 2. 檢查新發布的 AI 文章是否顯示
# 3. 確認 AI 標識正確顯示
# 4. 測試文章互動功能（按讚、留言等）
```

---

## ⏰ 第六步：排程啟用

### 6.1 啟用自動排程
```bash
# 在主要工作流程中：
# 1. 確認排程觸發器設定正確（每日 7AM）
# 2. 點擊工作流程右上角的開關啟用
# 3. 確認狀態顯示為 "Active"
```

### 6.2 設定通知
```bash
# 設定執行失敗通知：
# 1. 工作流程設定 > Notifications
# 2. 添加失敗通知到 Slack 或 Email
# 3. 設定重試策略
```

---

## 📊 第七步：監控和維護

### 7.1 執行記錄監控
```bash
# 定期檢查：
# 1. Workflow executions 頁面
# 2. 查看成功/失敗執行統計
# 3. 檢查錯誤日誌
```

### 7.2 效能監控指標
```bash
# 關注以下指標：
# - 每日執行成功率 (目標: >95%)
# - 平均執行時間 (目標: <5分鐘)
# - Slack 審核回應率 (目標: >80%)
# - iOS App 文章顯示延遲 (目標: <10分鐘)
```

---

## 🛠️ 故障排除

### 常見問題及解決方案

#### RSS 讀取失敗
```bash
# 症狀: RSS 節點執行失敗
# 解決: 
# 1. 檢查 RSS URL 是否有效
# 2. 嘗試更換新聞來源
# 3. 調整 timeout 設定
```

#### OpenAI API 限制
```bash
# 症狀: OpenAI 節點回傳 429 錯誤
# 解決:
# 1. 檢查 API 配額使用情況
# 2. 降低 token 數量限制
# 3. 增加請求間隔時間
```

#### Slack 通知失敗
```bash
# 症狀: Slack 節點無法發送訊息
# 解決:
# 1. 確認 Bot Token 權限
# 2. 檢查頻道名稱格式
# 3. 驗證 Bot 是否已加入頻道
```

#### Supabase 連線問題
```bash
# 症狀: 無法讀寫 Supabase 資料
# 解決:
# 1. 檢查 API URL 和金鑰
# 2. 確認資料表結構正確
# 3. 檢查 RLS 政策設定
```

---

## 📈 效能優化建議

### 執行效率優化
```bash
# 1. 調整 RSS 限制數量 (建議 3-5 篇)
# 2. 使用 GPT-4o-mini 代替 GPT-4 (更快更便宜)
# 3. 設定適當的 timeout 值
# 4. 啟用結果快取機制
```

### 成本控制
```bash
# 1. 監控 OpenAI API 使用量
# 2. 設定每日執行次數限制
# 3. 使用 n8n.io Starter 方案起步
# 4. 定期檢查並優化不必要的執行
```

---

## 🔄 維護排程

### 每日檢查
- [ ] 確認工作流程正常執行
- [ ] 檢查 Slack 審核訊息
- [ ] 驗證 iOS App 文章更新

### 每週檢查  
- [ ] 檢視執行統計報告
- [ ] 清理舊的執行記錄
- [ ] 更新 RSS 新聞來源（如需要）

### 每月檢查
- [ ] 檢視 API 使用量和成本
- [ ] 更新憑證（如過期）
- [ ] 檢查並更新工作流程版本

---

## 🎯 部署確認清單

### ✅ 最終檢查項目
- [ ] n8n.io 工作流程已匯入並啟用
- [ ] 所有憑證已正確設定並測試
- [ ] Slack App 互動端點已配置
- [ ] 環境變數已設定完成
- [ ] 手動執行測試成功
- [ ] Slack 審核流程測試成功
- [ ] iOS App 顯示文章測試成功
- [ ] 排程觸發器已啟用
- [ ] 監控和通知已設定

### 🎉 部署完成

**恭喜！您的 AI 投資文章自動化系統已成功部署到 n8n.io 雲端平台！**

系統現在將：
- ✅ 每日自動生成高品質投資分析文章
- ✅ 透過 Slack 提供人工審核機制  
- ✅ 自動發布到 Invest_V3 iOS App
- ✅ 提供完整的用戶互動體驗

---

## 📞 支援聯絡

如有任何問題，請參考：
- **n8n.io 官方文檔**: https://docs.n8n.io
- **n8n.io 社群**: https://community.n8n.io
- **技術支援**: 透過 n8n.io 平台提交工單

**🚀 享受您的全自動 AI 內容生成系統！**