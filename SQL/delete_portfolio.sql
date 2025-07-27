-- 安全刪除特定投資組合的 SQL 腳本
-- 目標：刪除 portfolio ID be5f2785-741e-455c-8a94-2bb2b510f76b 的所有相關數據
-- 執行前請在 Supabase SQL 編輯器中確認數據

-- 設置要刪除的投資組合 ID
-- 替換下面的 UUID 為實際要刪除的投資組合 ID
\set target_portfolio_id 'be5f2785-741e-455c-8a94-2bb2b510f76b'

-- 開始事務以確保操作原子性
BEGIN;

-- 步驟 1: 檢查投資組合是否存在
SELECT 
    id,
    user_id,
    initial_cash,
    available_cash,
    total_value,
    return_rate,
    last_updated
FROM user_portfolios 
WHERE id = :'target_portfolio_id';

-- 步驟 2: 刪除持倉記錄 (user_positions)
-- 必須先刪除子表記錄以避免外鍵約束錯誤
DELETE FROM user_positions 
WHERE portfolio_id = :'target_portfolio_id';

-- 檢查刪除的持倉記錄數量
SELECT 'user_positions' as table_name, 
       0 as remaining_records,
       'Deleted positions for portfolio ' || :'target_portfolio_id' as status;

-- 步驟 3: 獲取用戶 ID 並刪除交易記錄 (portfolio_transactions)
DELETE FROM portfolio_transactions 
WHERE user_id = (
    SELECT user_id 
    FROM user_portfolios 
    WHERE id = :'target_portfolio_id'
);

-- 檢查刪除的交易記錄數量
SELECT 'portfolio_transactions' as table_name,
       COUNT(*) as remaining_records,
       'Deleted transactions for user' as status
FROM portfolio_transactions 
WHERE user_id = (
    SELECT user_id 
    FROM user_portfolios 
    WHERE id = :'target_portfolio_id'
);

-- 步驟 4: 刪除投資組合主記錄 (user_portfolios)
DELETE FROM user_portfolios 
WHERE id = :'target_portfolio_id';

-- 最終確認：檢查是否已完全刪除
SELECT 
    (SELECT COUNT(*) FROM user_positions WHERE portfolio_id = :'target_portfolio_id') as remaining_positions,
    (SELECT COUNT(*) FROM user_portfolios WHERE id = :'target_portfolio_id') as remaining_portfolios,
    'Deletion completed' as status;

-- 提交事務
COMMIT;

-- 如果需要回滾，請使用 ROLLBACK; 
-- ROLLBACK;
EOF < /dev/null