-- Invest_V3 通用數據庫設置 - 適用於所有用戶
-- 請在 Supabase SQL Editor 中執行此腳本

-- 1. 修復字段長度限制
ALTER TABLE user_profiles 
ALTER COLUMN display_name TYPE TEXT,
ALTER COLUMN bio TYPE TEXT,
ALTER COLUMN investment_philosophy TYPE TEXT,
ALTER COLUMN avatar_url TYPE TEXT;

-- 2. 創建觸發器函數：當新用戶註冊時自動初始化數據
CREATE OR REPLACE FUNCTION initialize_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 為新用戶創建初始餘額記錄
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (NEW.id, 10000, 10000)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- 為新用戶創建基本檔案
    INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
    VALUES (
        NEW.id, 
        COALESCE(NEW.email, 'User_' || substring(NEW.id::text, 1, 8)),
        '新用戶',
        '投資理念待完善'
    )
    ON CONFLICT (user_id) DO NOTHING;
    
    -- 為新用戶創建模擬創作者收益數據
    INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
    (NEW.id, 'subscription_share', 5300, '平台訂閱分潤收益'),
    (NEW.id, 'reader_tip', 1800, '讀者抖內收益'),
    (NEW.id, 'group_entry_fee', 1950, '群組入會費收益'),
    (NEW.id, 'group_tip', 800, '群組抖內收益')
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 創建觸發器：在 auth.users 表插入新用戶時自動執行
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION initialize_new_user();

-- 4. 為所有現有用戶初始化數據
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
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000),
            updated_at = now();

        -- 初始化用戶檔案
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            user_record.id, 
            COALESCE(user_record.email, 'User_' || substring(user_record.id::text, 1, 8)),
            '投資專家',
            '價值投資策略'
        )
        ON CONFLICT (user_id) DO UPDATE SET
            display_name = COALESCE(user_profiles.display_name, EXCLUDED.display_name),
            bio = COALESCE(user_profiles.bio, EXCLUDED.bio),
            investment_philosophy = COALESCE(user_profiles.investment_philosophy, EXCLUDED.investment_philosophy),
            updated_at = now();

        -- 檢查是否已有創作者收益數據，如果沒有則創建
        IF NOT EXISTS (SELECT 1 FROM creator_revenues WHERE creator_id = user_record.id) THEN
            INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
            (user_record.id, 'subscription_share', 5300, '平台訂閱分潤收益'),
            (user_record.id, 'reader_tip', 1800, '讀者抖內收益'),
            (user_record.id, 'group_entry_fee', 1950, '群組入會費收益'),
            (user_record.id, 'group_tip', 800, '群組抖內收益');
        END IF;
        
        user_count := user_count + 1;
    END LOOP;
    
    RAISE NOTICE '✅ 已為 % 個用戶初始化數據', user_count;
END $$;

-- 5. 創建函數：讓任何用戶都可以重置自己的創作者收益數據
CREATE OR REPLACE FUNCTION reset_user_creator_revenue()
RETURNS void AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- 獲取當前認證用戶ID
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION '用戶未認證';
    END IF;
    
    -- 清理現有收益記錄
    DELETE FROM creator_revenues WHERE creator_id = current_user_id;
    
    -- 重新創建收益記錄
    INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
    (current_user_id, 'subscription_share', 5300, '平台訂閱分潤收益'),
    (current_user_id, 'reader_tip', 1800, '讀者抖內收益'),
    (current_user_id, 'group_entry_fee', 1950, '群組入會費收益'),
    (current_user_id, 'group_tip', 800, '群組抖內收益');
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 創建 RPC 函數供客戶端調用
CREATE OR REPLACE FUNCTION initialize_current_user_data()
RETURNS json AS $$
DECLARE
    current_user_id UUID;
    result json;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未認證');
    END IF;
    
    -- 確保用戶餘額存在
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (current_user_id, 10000, 10000)
    ON CONFLICT (user_id) DO UPDATE SET
        balance = GREATEST(user_balances.balance, 10000),
        withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000),
        updated_at = now();
    
    -- 確保創作者收益數據存在
    IF NOT EXISTS (SELECT 1 FROM creator_revenues WHERE creator_id = current_user_id) THEN
        PERFORM reset_user_creator_revenue();
    END IF;
    
    -- 返回成功結果
    SELECT json_build_object(
        'success', true,
        'message', '用戶數據初始化完成',
        'user_id', current_user_id,
        'balance', (SELECT balance FROM user_balances WHERE user_id = current_user_id),
        'total_revenue', (SELECT COALESCE(SUM(amount), 0) FROM creator_revenues WHERE creator_id = current_user_id)
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 授予必要權限
GRANT EXECUTE ON FUNCTION reset_user_creator_revenue() TO authenticated;
GRANT EXECUTE ON FUNCTION initialize_current_user_data() TO authenticated;

RAISE NOTICE '🎉 通用用戶數據初始化系統設置完成！';
RAISE NOTICE '📋 新用戶註冊時會自動初始化數據';
RAISE NOTICE '🔧 現有用戶可調用 initialize_current_user_data() 函數初始化數據';