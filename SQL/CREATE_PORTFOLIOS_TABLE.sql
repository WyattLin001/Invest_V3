-- 創建投資組合表
-- 在 Supabase SQL Editor 中執行

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
CREATE INDEX IF NOT EXISTS idx_portfolios_return_rate ON portfolios(return_rate DESC);

-- 啟用 RLS (Row Level Security)
ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;

-- 創建 RLS 政策
-- 用戶只能查看自己的投資組合
CREATE POLICY "Users can view their own portfolios"
ON portfolios FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 用戶只能創建自己的投資組合
CREATE POLICY "Users can create their own portfolios"
ON portfolios FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 用戶只能更新自己的投資組合
CREATE POLICY "Users can update their own portfolios"
ON portfolios FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- 驗證表格創建成功
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'portfolios' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 驗證索引創建成功
SELECT 
    indexname, 
    indexdef
FROM pg_indexes 
WHERE tablename = 'portfolios' 
AND schemaname = 'public';