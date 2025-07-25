-- 修復 wallet_transactions 表的交易類型約束
-- 在 Supabase SQL Editor 中執行

-- 1. 首先檢查現有表格結構
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'wallet_transactions' 
AND table_schema = 'public';

-- 2. 如果表格不存在，創建完整的 wallet_transactions 表
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    transaction_type TEXT NOT NULL CHECK (
        transaction_type IN (
            'deposit',
            'withdrawal', 
            'gift_purchase',
            'subscription',
            'tip',
            'bonus',
            'group_entry_fee',
            'group_tip'
        )
    ),
    amount INTEGER NOT NULL, -- 正數為收入，負數為支出
    description TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'failed', 'cancelled')),
    related_id TEXT, -- 相關的ID（群組ID、用戶ID等）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 如果表格已存在但約束不正確，需要先刪除舊約束再添加新約束
-- 查看現有約束
SELECT conname, contype, pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'wallet_transactions'::regclass 
AND contype = 'c'; -- check constraint

-- 4. 刪除舊的 transaction_type 約束（如果存在）
-- 注意：需要替換 'wallet_transactions_transaction_type_check' 為實際的約束名稱
ALTER TABLE wallet_transactions 
DROP CONSTRAINT IF EXISTS wallet_transactions_transaction_type_check;

-- 5. 添加新的正確約束
ALTER TABLE wallet_transactions 
ADD CONSTRAINT wallet_transactions_transaction_type_check 
CHECK (transaction_type IN (
    'deposit',
    'withdrawal',
    'gift_purchase', 
    'subscription',
    'tip',
    'bonus',
    'group_entry_fee',
    'group_tip'
));

-- 6. 確保 status 約束也正確
ALTER TABLE wallet_transactions 
DROP CONSTRAINT IF EXISTS wallet_transactions_status_check;

ALTER TABLE wallet_transactions 
ADD CONSTRAINT wallet_transactions_status_check 
CHECK (status IN ('pending', 'confirmed', 'failed', 'cancelled'));

-- 7. 創建必要的索引
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);

-- 8. 啟用 RLS (Row Level Security)
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 9. 創建 RLS 政策
CREATE POLICY "Users can view their own transactions"
ON wallet_transactions FOR SELECT
TO authenticated
USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert their own transactions"
ON wallet_transactions FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = user_id);

-- 10. 驗證表格結構
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'wallet_transactions' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 11. 驗證約束
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'wallet_transactions'::regclass
ORDER BY conname;