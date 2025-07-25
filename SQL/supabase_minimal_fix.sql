-- 最小化修復方案：移除所有可能導致註冊失敗的觸發器
-- 讓用戶註冊成功，數據初始化改為手動

-- 1. 完全移除觸發器，避免註冊時出錯
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS initialize_new_user() CASCADE;

-- 2. 簡化 RPC 函數，加強錯誤處理
CREATE OR REPLACE FUNCTION initialize_current_user_data()
RETURNS json AS $$
DECLARE
    current_user_id UUID;
    current_email TEXT;
    display_name_text TEXT;
    counter INTEGER := 0;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未認證');
    END IF;
    
    BEGIN
        -- 獲取用戶信息
        SELECT email INTO current_email FROM auth.users WHERE id = current_user_id;
        
        -- 生成顯示名稱
        IF current_email IS NOT NULL THEN
            display_name_text := substring(split_part(current_email, '@', 1), 1, 50);
        ELSE
            display_name_text := 'User' || substring(replace(current_user_id::text, '-', ''), 1, 8);
        END IF;
        
        -- 確保顯示名稱唯一
        WHILE EXISTS (SELECT 1 FROM user_profiles WHERE display_name = display_name_text) LOOP
            counter := counter + 1;
            display_name_text := display_name_text || counter::text;
            IF counter > 100 THEN -- 防止無限循環
                EXIT;
            END IF;
        END LOOP;
        
        -- 步驟1: 創建用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (current_user_id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);
        
        -- 步驟2: 創建用戶檔案
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            current_user_id, 
            display_name_text,
            '投資專家',
            '價值投資'
        )
        ON CONFLICT (user_id) DO UPDATE SET
            display_name = EXCLUDED.display_name,
            updated_at = now();
        
        -- 步驟3: 清理舊收益數據
        DELETE FROM creator_revenues WHERE creator_id = current_user_id;
        
        -- 步驟4: 創建新收益數據
        INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
        (current_user_id, 'subscription_share', 5300, '訂閱分潤'),
        (current_user_id, 'reader_tip', 1800, '讀者抖內'),
        (current_user_id, 'group_entry_fee', 1950, '群組入會費'),
        (current_user_id, 'group_tip', 800, '群組抖內');
        
        -- 返回成功結果
        RETURN json_build_object(
            'success', true,
            'message', '數據初始化完成',
            'user_id', current_user_id::text,
            'display_name', display_name_text,
            'balance', 10000,
            'total_revenue', 9850
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            -- 詳細錯誤信息
            RETURN json_build_object(
                'success', false, 
                'message', '初始化失敗: ' || SQLERRM,
                'error_detail', SQLSTATE
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 授予權限
GRANT EXECUTE ON FUNCTION initialize_current_user_data() TO authenticated;

SELECT '註冊修復完成！觸發器已移除，用戶需手動初始化數據。' as status;