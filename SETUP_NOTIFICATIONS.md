# 設置推播通知系統

## 1. 在 Supabase 中執行 SQL

1. 登入 Supabase Dashboard
2. 前往 **SQL Editor**
3. 複製 `CREATE_NOTIFICATION_TABLES.sql` 中的所有內容
4. 貼上並執行

## 2. 建立的表格

### notification_settings (通知設定)
- 儲存每個用戶的推播通知偏好
- 包含各種通知類型的開關
- 儲存 Apple 推播用的 device_token

### notifications (通知記錄)  
- 儲存所有發送給用戶的通知
- 支援多種通知類型：主持人訊息、排名更新、股價提醒等
- 追蹤已讀/未讀狀態

### stock_price_alerts (股價提醒)
- 用戶設定的股價到價提醒
- 支援高於/低於目標價格的條件
- 可啟用/停用個別提醒

## 3. 支援的通知類型

- `host_message`: 主持人訊息
- `ranking_update`: 排名更新 
- `stock_price_alert`: 股價到價提醒
- `chat_message`: 聊天訊息
- `investment_update`: 投資更新
- `market_news`: 市場新聞
- `system_alert`: 系統通知

## 4. 自動化功能

- 用戶註冊時自動創建預設通知設定
- 自動清理舊通知（30天已讀，90天未讀）
- 提供通知統計視圖

## 5. 安全性

- 啟用 RLS (Row Level Security)
- 用戶只能存取自己的通知和設定
- 防止資料洩露和未授權存取

## 6. 效能優化

- 建立適當的索引
- 支援分頁查詢
- 提供統計視圖減少複雜查詢