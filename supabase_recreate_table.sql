-- 重新創建 user_profiles 表以解決字段長度問題
-- 這是最安全的方法

-- 步驟 1: 備份現有數據（如果有的話）
CREATE TEMP TABLE user_profiles_backup AS 
SELECT * FROM user_profiles;

-- 步驟 2: 刪除現有表
DROP TABLE IF EXISTS user_profiles CASCADE;

-- 步驟 3: 重新創建表，所有文本字段都使用 TEXT 類型
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
    UNIQUE(user_id),
    UNIQUE(display_name)
);

-- 步驟 4: 設置 RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 步驟 5: 重新創建 RLS 政策
CREATE POLICY "Anyone can view profiles" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 步驟 6: 創建索引
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_display_name ON user_profiles(display_name);

-- 步驟 7: 為所有用戶初始化數據
DO $$
DECLARE
    user_record RECORD;
    user_count INTEGER := 0;
    display_name_text TEXT;
BEGIN
    FOR user_record IN 
        SELECT id, email FROM auth.users
    LOOP
        -- 生成顯示名稱
        IF user_record.email IS NOT NULL THEN
            display_name_text := split_part(user_record.email, '@', 1);
        ELSE
            display_name_text := 'User_' || substring(user_record.id::text, 1, 8);
        END IF;
        
        -- 確保顯示名稱唯一
        WHILE EXISTS (SELECT 1 FROM user_profiles WHERE display_name = display_name_text) LOOP
            display_name_text := display_name_text || '_' || floor(random() * 1000)::text;
        END LOOP;

        -- 初始化用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (user_record.id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);

        -- 初始化用戶檔案
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            user_record.id, 
            display_name_text,
            '投資專家',
            '價值投資策略'
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

-- 步驟 8: 創建觸發器函數用於新用戶註冊
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
    
    -- 確保顯示名稱唯一
    WHILE EXISTS (SELECT 1 FROM user_profiles WHERE display_name = display_name_text) LOOP
        display_name_text := display_name_text || '_' || floor(random() * 1000)::text;
    END LOOP;

    -- 為新用戶創建初始餘額記錄
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (NEW.id, 10000, 10000)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- 為新用戶創建基本檔案
    INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
    VALUES (
        NEW.id, 
        display_name_text,
        '新用戶',
        '投資理念待完善'
    )
    ON CONFLICT (user_id) DO NOTHING;
    
    -- 為新用戶創建模擬創作者收益數據
    INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
    (NEW.id, 'subscription_share', 5300, '訂閱分潤'),
    (NEW.id, 'reader_tip', 1800, '讀者抖內'),
    (NEW.id, 'group_entry_fee', 1950, '群組入會費'),
    (NEW.id, 'group_tip', 800, '群組抖內')
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 步驟 9: 創建觸發器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION initialize_new_user();

-- 步驟 10: 驗證最終結果
SELECT 
    'users' as type,
    COUNT(*) as count
FROM auth.users

UNION ALL

SELECT 
    'user_balances' as type,
    COUNT(*) as count
FROM user_balances

UNION ALL

SELECT 
    'user_profiles' as type,
    COUNT(*) as count
FROM user_profiles

UNION ALL

SELECT 
    'creator_revenues' as type,
    COUNT(*) as count
FROM creator_revenues;

RAISE NOTICE '🎉 用戶數據表重建並初始化完成！';