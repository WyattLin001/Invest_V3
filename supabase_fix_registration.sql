-- 修復用戶註冊時的數據庫錯誤
-- 請在 Supabase SQL Editor 中執行此腳本

-- 1. 檢查並刪除可能有問題的觸發器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS initialize_new_user() CASCADE;

-- 2. 檢查表是否存在，如果不存在則創建
CREATE TABLE IF NOT EXISTS user_balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    balance INTEGER DEFAULT 0 NOT NULL CHECK (balance >= 0),
    withdrawable_amount INTEGER DEFAULT 0 NOT NULL CHECK (withdrawable_amount >= 0),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS creator_revenues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    revenue_type TEXT NOT NULL CHECK (revenue_type IN ('subscription_share', 'reader_tip', 'group_entry_fee', 'group_tip')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    source_id UUID,
    source_name TEXT,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    investment_philosophy TEXT,
    specializations TEXT[],
    years_experience INTEGER DEFAULT 0,
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    article_count INTEGER DEFAULT 0,
    total_return_rate NUMERIC(10,4) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

-- 3. 重新啟用 RLS
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE creator_revenues ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 4. 重新創建 RLS 政策（如果不存在）
DROP POLICY IF EXISTS "Users can view own balance" ON user_balances;
CREATE POLICY "Users can view own balance" ON user_balances FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own balance" ON user_balances;
CREATE POLICY "Users can update own balance" ON user_balances FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own balance" ON user_balances;
CREATE POLICY "Users can insert own balance" ON user_balances FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Creators can view own revenue" ON creator_revenues;
CREATE POLICY "Creators can view own revenue" ON creator_revenues FOR SELECT USING (auth.uid() = creator_id);

DROP POLICY IF EXISTS "System can insert creator revenue" ON creator_revenues;
CREATE POLICY "System can insert creator revenue" ON creator_revenues FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Creators can delete own revenue" ON creator_revenues;
CREATE POLICY "Creators can delete own revenue" ON creator_revenues FOR DELETE USING (auth.uid() = creator_id);

DROP POLICY IF EXISTS "Anyone can view profiles" ON user_profiles;
CREATE POLICY "Anyone can view profiles" ON user_profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
CREATE POLICY "Users can insert own profile" ON user_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 5. 創建一個簡單且安全的新用戶觸發器函數
CREATE OR REPLACE FUNCTION initialize_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 只為新用戶創建初始餘額記錄，其他數據讓用戶手動初始化
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (NEW.id, 10000, 10000)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- 如果出現任何錯誤，記錄但不阻止用戶註冊
        RAISE WARNING '初始化新用戶數據時出現錯誤: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 重新創建觸發器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION initialize_new_user();

-- 7. 確保 RPC 函數存在且正確
CREATE OR REPLACE FUNCTION initialize_current_user_data()
RETURNS json AS $$
DECLARE
    current_user_id UUID;
    current_email TEXT;
    display_name_text TEXT;
    result json;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未認證');
    END IF;
    
    BEGIN
        -- 獲取用戶 email
        SELECT email INTO current_email FROM auth.users WHERE id = current_user_id;
        
        -- 生成顯示名稱
        IF current_email IS NOT NULL THEN
            display_name_text := split_part(current_email, '@', 1);
        ELSE
            display_name_text := 'User_' || substring(current_user_id::text, 1, 8);
        END IF;
        
        -- 確保用戶餘額存在
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (current_user_id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000),
            updated_at = now();
        
        -- 確保用戶檔案存在
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            current_user_id, 
            display_name_text,
            '投資專家',
            '價值投資策略'
        )
        ON CONFLICT (user_id) DO UPDATE SET
            display_name = COALESCE(user_profiles.display_name, EXCLUDED.display_name),
            bio = COALESCE(user_profiles.bio, EXCLUDED.bio),
            investment_philosophy = COALESCE(user_profiles.investment_philosophy, EXCLUDED.investment_philosophy),
            updated_at = now();
        
        -- 清理並重新創建創作者收益數據
        DELETE FROM creator_revenues WHERE creator_id = current_user_id;
        
        INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
        (current_user_id, 'subscription_share', 5300, '訂閱分潤'),
        (current_user_id, 'reader_tip', 1800, '讀者抖內'),
        (current_user_id, 'group_entry_fee', 1950, '群組入會費'),
        (current_user_id, 'group_tip', 800, '群組抖內');
        
        -- 返回成功結果
        SELECT json_build_object(
            'success', true,
            'message', '用戶數據初始化完成',
            'user_id', current_user_id,
            'display_name', display_name_text,
            'balance', (SELECT balance FROM user_balances WHERE user_id = current_user_id),
            'total_revenue', (SELECT COALESCE(SUM(amount), 0) FROM creator_revenues WHERE creator_id = current_user_id)
        ) INTO result;
        
        RETURN result;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object(
                'success', false, 
                'message', '初始化失敗: ' || SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. 授予權限
GRANT EXECUTE ON FUNCTION initialize_current_user_data() TO authenticated;

-- 9. 創建索引以提高性能
CREATE INDEX IF NOT EXISTS idx_user_balances_user_id ON user_balances(user_id);
CREATE INDEX IF NOT EXISTS idx_creator_revenues_creator_id ON creator_revenues(creator_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

SELECT '用戶註冊修復完成！新用戶註冊應該不會再出現數據庫錯誤。' as status;