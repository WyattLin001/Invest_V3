-- 簡單直接的解決方案：重建 user_profiles 表
-- 請在 Supabase SQL Editor 中執行

-- 1. 完全刪除現有表（包括所有約束和依賴）
DROP TABLE IF EXISTS user_profiles CASCADE;

-- 2. 重新創建表，使用 TEXT 類型（無長度限制）
CREATE TABLE user_profiles (
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
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 4. 重新創建 RLS 政策
CREATE POLICY "Anyone can view profiles" ON user_profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON user_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 5. 創建索引
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);

-- 6. 創建 RPC 函數供客戶端調用
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 授予權限
GRANT EXECUTE ON FUNCTION initialize_current_user_data() TO authenticated;

-- 8. 為所有現有用戶初始化基本數據（只初始化餘額，讓用戶自己點擊初始化其他數據）
INSERT INTO user_balances (user_id, balance, withdrawable_amount)
SELECT 
    id as user_id, 
    10000 as balance, 
    10000 as withdrawable_amount
FROM auth.users
ON CONFLICT (user_id) DO UPDATE SET
    balance = GREATEST(user_balances.balance, 10000),
    withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);

-- 9. 創建新用戶自動初始化觸發器
CREATE OR REPLACE FUNCTION initialize_new_user()
RETURNS TRIGGER AS $$
DECLARE
    display_name_text TEXT;
BEGIN
    -- 生成顯示名稱
    IF NEW.email IS NOT NULL THEN
        display_name_text := split_part(NEW.email, '@', 1);
    ELSE
        display_name_text := 'User_' || substring(NEW.id::text, 1, 8);
    END IF;

    -- 為新用戶創建初始餘額記錄
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (NEW.id, 10000, 10000)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. 創建觸發器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION initialize_new_user();

SELECT 'user_profiles 表重建完成！' as status;