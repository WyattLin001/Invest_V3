# 🛠️ 修復加入群組失敗問題

## 問題描述
加入群組時出現 404 錯誤：`portfolios` 表不存在

## ⚡ 快速修復步驟

### 1. 登入 Supabase 控制台
1. 打開 [supabase.com](https://supabase.com)
2. 登入您的帳戶
3. 選擇您的專案

### 2. 執行 SQL 腳本
1. 點擊左側選單的 **"SQL Editor"**
2. 點擊 **"+ New query"** 創建新查詢
3. 複製並貼上以下 SQL 代碼：

```sql
-- 創建 portfolios 表
CREATE TABLE IF NOT EXISTS portfolios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    initial_cash DECIMAL(15,2) NOT NULL DEFAULT 1000000.00,
    available_cash DECIMAL(15,2) NOT NULL DEFAULT 1000000.00,
    total_value DECIMAL(15,2) NOT NULL DEFAULT 1000000.00,
    return_rate DECIMAL(8,4) NOT NULL DEFAULT 0.0000,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 確保每個用戶在每個群組只能有一個投資組合
    UNIQUE(group_id, user_id)
);

-- 創建索引優化查詢性能
CREATE INDEX IF NOT EXISTS idx_portfolios_group_id ON portfolios(group_id);
CREATE INDEX IF NOT EXISTS idx_portfolios_user_id ON portfolios(user_id);
CREATE INDEX IF NOT EXISTS idx_portfolios_group_user ON portfolios(group_id, user_id);

-- 啟用 RLS (Row Level Security)
ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;

-- 創建 RLS 政策
CREATE POLICY "Users can view their own portfolios"
ON portfolios FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own portfolios"
ON portfolios FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own portfolios"
ON portfolios FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);
```

4. 點擊 **"RUN"** 執行 SQL

### 3. 驗證修復
1. 重新啟動 iOS 應用
2. 嘗試加入群組
3. 應該能成功加入而不會出現 404 錯誤

## ✅ 成功標誌
看到以下日誌表示修復成功：
```
✅ 成功創建投資組合
✅ 成功加入群組並扣除 XXX 代幣
```

## 🚨 如果仍有問題
請檢查：
1. SQL 執行是否成功（沒有錯誤訊息）
2. 確認您在正確的 Supabase 專案中執行
3. 檢查 RLS 政策是否正確創建

---
**注意**: 此表格用於存儲每個群組中用戶的投資組合數據，包括初始資金、可用現金和投資回報率。