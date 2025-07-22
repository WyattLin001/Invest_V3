-- 為現有用戶重新創建數據
-- 因為重建表時清空了所有數據

-- 1. 檢查現有用戶
SELECT 
    '現有用戶檢查' as step,
    id::text as user_id,
    email,
    created_at
FROM auth.users
ORDER BY created_at;

-- 2. 為所有現有用戶重新創建數據
DO $$
DECLARE
    user_record RECORD;
    display_name_text TEXT;
    counter INTEGER := 0;
BEGIN
    -- 遍歷所有現有用戶
    FOR user_record IN 
        SELECT id, email FROM auth.users
    LOOP
        counter := counter + 1;
        
        -- 生成顯示名稱
        IF user_record.email IS NOT NULL THEN
            display_name_text := split_part(user_record.email, '@', 1);
        ELSE
            display_name_text := 'User' || counter::text;
        END IF;
        
        -- 特殊處理 test03 用戶
        IF user_record.id::text = 'be5f2785-741e-455c-8a94-2bb2b510f76b' THEN
            display_name_text := 'test03';
        END IF;
        
        -- 確保顯示名稱唯一
        WHILE EXISTS (SELECT 1 FROM user_profiles WHERE display_name = display_name_text) LOOP
            display_name_text := display_name_text || '_' || floor(random() * 1000)::text;
        END LOOP;
        
        -- 創建用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (user_record.id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);
        
        -- 創建用戶檔案
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            user_record.id,
            display_name_text,
            '投資專家',
            '價值投資策略'
        )
        ON CONFLICT (user_id) DO UPDATE SET
            display_name = EXCLUDED.display_name,
            updated_at = now();
        
        -- 清理並重新創建收益數據
        DELETE FROM creator_revenues WHERE creator_id = user_record.id;
        
        INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
        (user_record.id, 'subscription_share', 5300, '訂閱分潤'),
        (user_record.id, 'reader_tip', 1800, '讀者抖內'),
        (user_record.id, 'group_entry_fee', 1950, '群組入會費'),
        (user_record.id, 'group_tip', 800, '群組抖內');
        
        RAISE NOTICE '✅ 為用戶 % (%) 重新創建數據完成', display_name_text, user_record.id;
    END LOOP;
    
    RAISE NOTICE '=== 為 % 個現有用戶重新創建數據完成 ===', counter;
END $$;

-- 3. 驗證數據創建結果
SELECT 
    'user_balances' as table_name,
    COUNT(*) as record_count
FROM user_balances

UNION ALL

SELECT 
    'user_profiles' as table_name,
    COUNT(*) as record_count
FROM user_profiles

UNION ALL

SELECT 
    'creator_revenues' as table_name,
    COUNT(*) as record_count
FROM creator_revenues;

-- 4. 檢查 test03 用戶的具體數據
SELECT 
    'test03 用戶檢查' as check_type,
    'user_balances' as table_name,
    balance::text as value
FROM user_balances 
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b'

UNION ALL

SELECT 
    'test03 用戶檢查' as check_type,
    'user_profiles' as table_name,
    display_name as value
FROM user_profiles 
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b'

UNION ALL

SELECT 
    'test03 用戶檢查' as check_type,
    'creator_revenues' as table_name,
    COUNT(*)::text || ' 條收益記錄' as value
FROM creator_revenues 
WHERE creator_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b';

-- 5. 創建一個簡化的註冊後初始化函數（不依賴觸發器）
CREATE OR REPLACE FUNCTION manual_user_initialization(target_user_id UUID)
RETURNS json AS $$
DECLARE
    display_name_text TEXT;
BEGIN
    IF target_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶ID不能為空');
    END IF;
    
    -- 生成顯示名稱
    display_name_text := 'User' || substring(replace(target_user_id::text, '-', ''), 1, 8);
    
    -- 創建基礎數據
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (target_user_id, 10000, 10000)
    ON CONFLICT DO NOTHING;
    
    INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
    VALUES (target_user_id, display_name_text, '新用戶', '投資理念待完善')
    ON CONFLICT DO NOTHING;
    
    RETURN json_build_object(
        'success', true,
        'message', '用戶初始化完成',
        'user_id', target_user_id::text
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', '初始化失敗: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION manual_user_initialization(UUID) TO authenticated;

SELECT '✅ 現有用戶數據重建完成！現在可以測試功能了。' as final_status;