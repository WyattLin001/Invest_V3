-- 分步驟修復 user_profiles 表字段長度問題
-- 請按順序執行每個步驟

-- 步驟 1: 檢查當前表結構
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND table_schema = 'public';

-- 步驟 2: 刪除所有現有數據（如果有的話）
TRUNCATE TABLE user_profiles CASCADE;

-- 步驟 3: 修改字段類型為 TEXT（無長度限制）
ALTER TABLE user_profiles ALTER COLUMN display_name TYPE TEXT;
ALTER TABLE user_profiles ALTER COLUMN bio TYPE TEXT;
ALTER TABLE user_profiles ALTER COLUMN investment_philosophy TYPE TEXT;
ALTER TABLE user_profiles ALTER COLUMN avatar_url TYPE TEXT;

-- 步驟 4: 再次檢查表結構確認修改成功
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND table_schema = 'public';

-- 步驟 5: 為所有用戶初始化數據（使用短文本）
DO $$
DECLARE
    user_record RECORD;
    user_count INTEGER := 0;
BEGIN
    -- 遍歷所有現有用戶
    FOR user_record IN 
        SELECT id, email FROM auth.users
    LOOP
        -- 初始化用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (user_record.id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);

        -- 初始化用戶檔案（使用最短文本）
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            user_record.id, 
            COALESCE(substring(user_record.email from 1 for 20), 'User'),
            '用戶',
            '投資'
        );

        -- 清理並重新創建收益數據
        DELETE FROM creator_revenues WHERE creator_id = user_record.id;
        
        INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
        (user_record.id, 'subscription_share', 5300, '訂閱分潤'),
        (user_record.id, 'reader_tip', 1800, '讀者抖內'),
        (user_record.id, 'group_entry_fee', 1950, '群組入會費'),
        (user_record.id, 'group_tip', 800, '群組抖內');
        
        user_count := user_count + 1;
    END LOOP;
    
    RAISE NOTICE '✅ 已為 % 個用戶初始化數據', user_count;
END $$;

-- 步驟 6: 驗證數據
SELECT 
    u.id,
    u.email,
    ub.balance,
    up.display_name,
    up.bio,
    COUNT(cr.id) as revenue_count
FROM auth.users u
LEFT JOIN user_balances ub ON u.id = ub.user_id
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN creator_revenues cr ON u.id = cr.creator_id
GROUP BY u.id, u.email, ub.balance, up.display_name, up.bio
ORDER BY u.created_at;

RAISE NOTICE '🎉 所有用戶數據初始化完成！';