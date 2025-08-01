# AI 投資文章自動化系統

## 🤖 系統概述

AI 投資文章自動化系統整合了 n8n 工作流程、Slack 審核機制、和 iOS App，實現了完整的 AI 內容生產到發布的自動化流程。

## 📋 系統架構

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   RSS 新聞源    │───▶│   n8n 工作流程   │───▶│   AI 文章生成    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Slack 審核     │◀───│   Supabase DB   │◀───│   內容審核系統   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
┌─────────────────┐    ┌─────────────────┐
│   iOS App 顯示   │◀───│   用戶互動系統   │
└─────────────────┘    └─────────────────┘
```

## 🔧 核心組件

### 1. 資料庫結構更新
- **Articles 表**: 新增 `status` 和 `source` 欄位
- **AI 作者帳號**: 專用的系統作者身份
- **向後兼容**: 支援現有文章數據

### 2. AI 作者服務 (`AIAuthorService`)
- 自動創建和管理 AI 系統帳號
- 統計和更新 AI 作者數據
- 提供作者身份驗證

### 3. 內容管理服務 (`SupabaseService` 擴展)
- `createAIArticle()`: 創建 AI 文章（草稿狀態）
- `updateArticleStatus()`: 更新文章發布狀態
- `reviewAndPublishAIArticle()`: 審核並發布流程
- `getPendingAIArticles()`: 獲取待審核文章

### 4. Slack 審核系統 (`SlackWebhookService`)
- 互動式審核界面
- 一鍵通過/拒絕功能
- 審核記錄和追蹤
- Webhook 處理機制

### 5. 內容審核服務 (`AIContentModerationService`)
- 多層次安全檢查
- 風險等級評估
- 自動發布條件判斷
- 合規性驗證

### 6. iOS App 集成
- AI 文章標識顯示
- 來源篩選功能
- 狀態管理界面
- 完整互動支援

## 🚀 工作流程

### 1. 自動生成階段
```bash
# 每日 7AM 自動觸發
RSS 新聞抓取 → AI 內容分析 → 文章生成 → 草稿儲存
```

### 2. 審核發布階段
```bash
# Slack 通知審核
內容審核 → Slack 通知 → 人工審核 → 狀態更新 → App 顯示
```

### 3. 用戶互動階段
```bash
# iOS App 中的完整體驗
文章閱讀 → 按讚留言 → 分享收藏 → 統計更新
```

## ⚙️ 配置說明

### 環境變數配置
```bash
# n8n 環境變數
AI_AUTHOR_ID="uuid-of-ai-author"
APP_URL="https://your-app.com"
SUPABASE_URL="https://your-project.supabase.co"
SUPABASE_ANON_KEY="your-anon-key"

# Slack 配置
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
SLACK_CHANNEL="#股圈-內容審核"
```

### 資料表結構
```sql
-- 更新 articles 表
ALTER TABLE articles ADD COLUMN status TEXT DEFAULT 'published';
ALTER TABLE articles ADD COLUMN source TEXT DEFAULT 'human';

-- 創建 AI 作者帳號
INSERT INTO user_profiles (
    email, username, display_name, bio, 
    is_verified, specializations, investment_philosophy
) VALUES (
    'ai-analyst@invest.app',
    'ai_analyst',
    'AI 投資分析師',
    '每日為您提供專業的投資市場分析和建議',
    true,
    ARRAY['市場分析', '技術分析', '風險評估'],
    '基於數據驅動的投資分析，結合技術指標和基本面研究'
);
```

## 🔒 安全性措施

### 1. 內容審核
- **關鍵字檢查**: 敏感詞彙和風險內容過濾
- **合規檢查**: 金融法規和投資建議風險評估
- **品質檢查**: 內容長度、結構和完整性驗證

### 2. 權限控制
- **審核權限**: 僅授權用戶可進行 Slack 審核
- **API 安全**: Webhook 請求驗證和防重放攻擊
- **資料保護**: 敏感資訊加密和存取控制

### 3. 監控告警
- **異常檢測**: 自動監控生成內容的異常模式
- **審核追蹤**: 完整的審核決策記錄和追溯
- **效能監控**: 系統性能和可用性監控

## 📊 監控指標

### 業務指標
- **生成成功率**: AI 文章生成的成功比例
- **審核通過率**: 人工審核的通過比例
- **自動發布率**: 符合自動發布條件的比例
- **用戶互動率**: AI 文章的用戶參與度

### 技術指標
- **系統可用性**: 各組件的正常運行時間
- **響應時間**: API 和 Webhook 的響應延遲
- **錯誤率**: 系統錯誤和異常的發生頻率
- **資源使用**: CPU、記憶體和資料庫使用情況

## 🧪 測試清單

### 功能測試
- [ ] AI 文章生成流程
- [ ] Slack 審核互動
- [ ] iOS App 顯示效果
- [ ] 資料庫操作正確性

### 整合測試
- [ ] n8n 到 Supabase 流程
- [ ] Slack 到 iOS App 同步
- [ ] 審核狀態更新傳遞
- [ ] 用戶互動功能完整性

### 安全測試
- [ ] 內容審核機制效果
- [ ] 權限控制有效性
- [ ] API 安全防護
- [ ] 資料隱私保護

## 🚀 部署步驟

### 1. 資料庫遷移
```bash
# 執行資料表結構更新
psql -h your-db-host -d your-db -f database_migration.sql
```

### 2. n8n 工作流程部署
```bash
# 匯入更新的工作流程
n8n import:workflow 股圈每日投資文章自動生成_完整版.json
```

### 3. iOS App 更新
```bash
# 編譯並部署更新的 iOS 應用
xcodebuild -project Invest_V3.xcodeproj -scheme Invest_V3 build
```

### 4. Slack 整合配置
```bash
# 配置 Slack App 和 Webhook URL
# 設定互動端點: https://your-api.com/slack/webhook
```

## 📈 效益預期

### 內容生產效益
- **生產效率**: 提高 300% 的內容產出速度
- **內容品質**: 保持專業水準的投資分析內容
- **成本節約**: 減少 70% 的人工內容創作成本

### 用戶體驗提升
- **內容更新**: 每日穩定的高品質內容供應
- **閱讀體驗**: AI 和人工內容的無縫整合
- **互動參與**: 完整的社交互動功能支援

### 運營管理優化
- **審核效率**: 簡化的 Slack 一鍵審核流程
- **品質控制**: 多層次的自動化內容審核
- **監控透明**: 完整的生產和審核流程追蹤

---

## 🎯 下一階段規劃

1. **智能推薦**: 基於用戶偏好的個性化內容推薦
2. **多語言支援**: 擴展到其他語言市場
3. **影片內容**: AI 生成的影片解說內容
4. **即時分析**: 市場事件的即時 AI 分析和推送

---

**💡 提示**: 系統已完成開發並準備部署。請按照上述步驟進行配置和測試。