-- 修復 user_profiles 表缺少 email 欄位的問題
-- 應用代碼期望有 email 欄位

-- 1. 檢查 user_profiles 表現有結構
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_profiles'
ORDER BY ordinal_position;

-- 2. 添加缺少的 email 欄位
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS email TEXT;

-- 3. 為現有用戶填充 email 數據
UPDATE user_profiles 
SET email = auth_users.email
FROM auth.users AS auth_users
WHERE user_profiles.user_id = auth_users.id
AND user_profiles.email IS NULL;

-- 4. 檢查其他可能缺少的常見欄位，並添加它們
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS website TEXT,
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS social_links JSONB DEFAULT '{}';

-- 5. 確保 test03 用戶數據完整
INSERT INTO user_profiles (
    user_id, 
    display_name, 
    email,
    bio, 
    investment_philosophy
)
SELECT 
    'be5f2785-741e-455c-8a94-2bb2b510f76b'::uuid,
    'test03',
    'test03@gmail.com',
    '投資專家',
    '價值投資策略'
WHERE NOT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b'
)
ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    updated_at = now();

-- 6. 為所有其他現有用戶確保有 user_profiles 記錄
INSERT INTO user_profiles (user_id, display_name, email, bio, investment_philosophy)
SELECT 
    au.id,
    COALESCE(split_part(au.email, '@', 1), 'User' || substring(replace(au.id::text, '-', ''), 1, 6)),
    au.email,
    '投資專家',
    '價值投資策略'
FROM auth.users au
LEFT JOIN user_profiles up ON au.id = up.user_id
WHERE up.user_id IS NULL
ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    updated_at = now();

-- 7. 檢查修復後的結果
SELECT 
    'user_profiles 記錄數' as check_item,
    COUNT(*)::text as count
FROM user_profiles

UNION ALL

SELECT 
    'test03 用戶檢查' as check_item,
    CASE 
        WHEN display_name IS NOT NULL AND email IS NOT NULL 
        THEN '✅ test03 數據完整 (' || display_name || ', ' || email || ')'
        ELSE '❌ test03 數據不完整'
    END as count
FROM user_profiles 
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b'

UNION ALL

SELECT 
    'email 欄位檢查' as check_item,
    COUNT(*) || ' 個用戶有 email' as count
FROM user_profiles 
WHERE email IS NOT NULL;

-- 8. 更新我們的初始化函數，包含 email 欄位
CREATE OR REPLACE FUNCTION initialize_current_user_data()
RETURNS json AS $$
DECLARE
    current_user_id UUID;
    current_email TEXT;
    display_name_text TEXT;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未認證');
    END IF;
    
    -- 從 auth.users 獲取 email
    SELECT email INTO current_email FROM auth.users WHERE id = current_user_id;
    
    -- 生成顯示名稱
    IF current_email IS NOT NULL THEN
        display_name_text := split_part(current_email, '@', 1);
    ELSE
        display_name_text := 'User' || substring(replace(current_user_id::text, '-', ''), 1, 8);
    END IF;
    
    BEGIN
        -- 創建用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (current_user_id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);
        
        -- 創建用戶檔案（包含 email）
        INSERT INTO user_profiles (user_id, display_name, email, bio, investment_philosophy)
        VALUES (
            current_user_id, 
            display_name_text,
            current_email,
            '投資專家',
            '價值投資'
        )
        ON CONFLICT (user_id) DO UPDATE SET
            email = COALESCE(user_profiles.email, EXCLUDED.email),
            display_name = COALESCE(user_profiles.display_name, EXCLUDED.display_name),
            updated_at = now();
        
        -- 清理並重新創建收益數據
        DELETE FROM creator_revenues WHERE creator_id = current_user_id;
        
        INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
        (current_user_id, 'subscription_share', 5300, '訂閱分潤'),
        (current_user_id, 'reader_tip', 1800, '讀者抖內'),
        (current_user_id, 'group_entry_fee', 1950, '群組入會費'),
        (current_user_id, 'group_tip', 800, '群組抖內');
        
        RETURN json_build_object(
            'success', true,
            'message', '數據初始化完成',
            'user_id', current_user_id::text,
            'display_name', display_name_text,
            'email', current_email,
            'balance', 10000,
            'total_revenue', 9850
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object(
                'success', false, 
                'message', '初始化失敗: ' || SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. 檢查修復後的表結構
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_profiles'
ORDER BY ordinal_position;

SELECT '✅ user_profiles 表修復完成！email 欄位已添加並填充數據。' as final_status;