-- 修復 user_profiles 表的字段長度限制
-- 請在 Supabase SQL Editor 中執行此腳本

-- 先修改所有字段的長度限制
ALTER TABLE user_profiles 
ALTER COLUMN display_name TYPE TEXT,
ALTER COLUMN bio TYPE TEXT,
ALTER COLUMN investment_philosophy TYPE TEXT;

-- 檢查並修改其他可能有長度限制的字段
ALTER TABLE user_profiles 
ALTER COLUMN avatar_url TYPE TEXT;

-- 確保 specializations 數組字段正確
ALTER TABLE user_profiles 
ALTER COLUMN specializations TYPE TEXT[];

-- 為 test03 用戶初始化數據 (使用較短的文字)
DO $$
DECLARE
    test_user_id UUID := 'be5f2785-741e-455c-8a94-2bb2b510f76b';
BEGIN
    -- 初始化用戶餘額
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (test_user_id, 10000, 10000)
    ON CONFLICT (user_id) DO UPDATE SET
        balance = EXCLUDED.balance,
        withdrawable_amount = EXCLUDED.withdrawable_amount,
        updated_at = now();

    -- 初始化用戶檔案 (使用簡短文字)
    INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
    VALUES (
        test_user_id, 
        'test03', 
        '測試用戶',
        '價值投資'
    )
    ON CONFLICT (user_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        bio = EXCLUDED.bio,
        investment_philosophy = EXCLUDED.investment_philosophy,
        updated_at = now();

    -- 清理並初始化創作者收益數據
    DELETE FROM creator_revenues WHERE creator_id = test_user_id;
    
    INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
    (test_user_id, 'subscription_share', 5300, '訂閱分潤'),
    (test_user_id, 'reader_tip', 1800, '讀者抖內'),
    (test_user_id, 'group_entry_fee', 1950, '群組入會費'),
    (test_user_id, 'group_tip', 800, '群組抖內');

    RAISE NOTICE '✅ test03 用戶數據修復並初始化完成';
END $$;

-- 驗證數據
SELECT 
    'user_balances' as table_name,
    balance,
    withdrawable_amount
FROM user_balances 
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b'

UNION ALL

SELECT 
    'user_profiles' as table_name,
    display_name::text as balance,
    bio as withdrawable_amount
FROM user_profiles 
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b'

UNION ALL

SELECT 
    'creator_revenues' as table_name,
    revenue_type as balance,
    amount::text as withdrawable_amount
FROM creator_revenues 
WHERE creator_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b';