# 投資模擬交易平台 - Supabase 設置指南

## 🎯 概述

本指南將幫助您在現有的 Supabase 專案中建立投資模擬交易平台所需的資料庫結構。

## 📋 設置步驟

### 第1步：登入 Supabase

1. 前往 [Supabase Dashboard](https://supabase.com/dashboard)
2. 登入您的帳戶
3. 選擇您的專案：`wujlbjrouqcpnifbakmw`

### 第2步：執行資料庫設置

1. 在 Supabase 儀表板中，點擊左側選單的 **"SQL Editor"**
2. 點擊 **"New Query"** 建立新的查詢
3. 複製並貼上 `setup_trading_tables.sql` 檔案的完整內容
4. 點擊 **"Run"** 執行腳本

### 第3步：驗證資料表建立

執行完成後，您應該會看到以下資料表：

#### 主要資料表：
- ✅ `trading_users` - 交易用戶資料
- ✅ `trading_positions` - 持倉記錄
- ✅ `trading_transactions` - 交易記錄
- ✅ `trading_stocks` - 股票基本資料
- ✅ `trading_performance_snapshots` - 績效快照
- ✅ `trading_referrals` - 邀請關係
- ✅ `trading_watchlists` - 關注清單
- ✅ `trading_alerts` - 交易提醒

#### 視圖 (Views)：
- ✅ `trading_user_portfolio_summary` - 用戶投資組合摘要
- ✅ `trading_user_statistics` - 用戶交易統計
- ✅ `trading_leaderboard` - 排行榜

#### 函數 (Functions)：
- ✅ `generate_invite_code()` - 生成邀請碼
- ✅ `calculate_user_total_assets()` - 計算用戶總資產
- ✅ `calculate_user_performance()` - 計算用戶績效

### 第4步：檢查 Row Level Security (RLS)

確認以下 RLS 政策已啟用：
- 用戶只能查看自己的資料
- 股票資料公開可見
- 服務角色 (service_role) 有完整權限

### 第5步：測試資料庫連線

1. 確保 `invest_simulator_backend/.env` 檔案包含正確的設定：

```env
SUPABASE_URL=https://wujlbjrouqcpnifbakmw.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.3zDbKVwOLZNLUDvEsKmkM7fWQEkGEWjJvfhFnMmxBlY
```

2. 執行後端測試：

```bash
cd invest_simulator_backend
python -m venv venv
source venv/bin/activate  # Mac/Linux
# 或 venv\Scripts\activate  # Windows
pip install -r requirements.txt
python run.py
```

3. 測試健康檢查：
   - 訪問 `http://localhost:5000/health`
   - 應該看到 JSON 回應確認服務正常運行

## 🎮 內建測試資料

資料庫設置已包含以下測試資料：

### 股票資料
- 台積電 (2330)
- 鴻海 (2317)
- 聯發科 (2454)
- 富邦金 (2881)
- 國泰金 (2882)
- 兆豐金 (2886)
- 中信金 (2891)
- 台塑化 (6505)
- 大立光 (3008)
- 台達電 (2308)
- 以及其他熱門股票...

### 初始設定
- 初始模擬資金：$1,000,000
- 邀請獎勵：$100,000
- 手續費率：0.1425%
- 證券交易稅：0.3%
- 最低手續費：$20

## 🔧 進階設定

### 自訂初始資金
如需修改初始資金，請更新 `.env` 檔案：

```env
INITIAL_CAPITAL=1000000
REFERRAL_BONUS=100000
```

### 新增股票資料
可以在 `trading_stocks` 資料表中新增更多股票：

```sql
INSERT INTO trading_stocks (symbol, name, market, sector, industry, is_active)
VALUES ('股票代號', '股票名稱', 'TW', '板塊', '產業', TRUE);
```

### 手續費設定
在 `.env` 檔案中調整：

```env
BROKER_FEE_RATE=0.001425  # 0.1425%
TAX_RATE=0.003           # 0.3%
MIN_BROKER_FEE=20        # 最低手續費
```

## 📊 資料庫查詢範例

### 查看用戶投資組合
```sql
SELECT * FROM trading_user_portfolio_summary WHERE id = 'user_id';
```

### 查看排行榜
```sql
SELECT * FROM trading_leaderboard LIMIT 10;
```

### 查看交易統計
```sql
SELECT * FROM trading_user_statistics WHERE id = 'user_id';
```

### 計算用戶績效
```sql
SELECT * FROM calculate_user_performance('user_id');
```

## 🛠️ 故障排除

### 常見問題

1. **權限錯誤**
   - 確認使用的是 `service_role` 密鑰
   - 檢查 RLS 政策是否正確設定

2. **資料表不存在**
   - 重新執行 `setup_trading_tables.sql`
   - 檢查 SQL 執行是否有錯誤

3. **連線失敗**
   - 確認 `SUPABASE_URL` 和 `SUPABASE_SERVICE_KEY` 正確
   - 檢查網路連線

4. **函數執行錯誤**
   - 確認 PostgreSQL 版本支援
   - 檢查函數語法是否正確

### 重置資料庫
如需重置，可以執行：

```sql
-- 刪除所有交易相關資料表
DROP TABLE IF EXISTS trading_alerts CASCADE;
DROP TABLE IF EXISTS trading_watchlists CASCADE;
DROP TABLE IF EXISTS trading_referrals CASCADE;
DROP TABLE IF EXISTS trading_performance_snapshots CASCADE;
DROP TABLE IF EXISTS trading_transactions CASCADE;
DROP TABLE IF EXISTS trading_positions CASCADE;
DROP TABLE IF EXISTS trading_users CASCADE;
DROP TABLE IF EXISTS trading_stocks CASCADE;
```

然後重新執行 `setup_trading_tables.sql`。

## 📞 支援

如遇到問題，請檢查：
1. Supabase 專案狀態
2. 資料庫連線設定
3. 後端服務日誌
4. 防火牆設定

設置完成後，您就可以開始使用投資模擬交易平台了！