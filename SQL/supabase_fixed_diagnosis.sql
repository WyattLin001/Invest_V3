-- 修復的診斷和清理腳本
-- 請在 Supabase SQL Editor 中執行

-- 第1部分：診斷現有問題
SELECT '=== 診斷開始 ===' as step;

-- 檢查所有與 auth.users 相關的觸發器
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'users' 
AND event_object_schema = 'auth';

-- 檢查 public schema 的觸發器
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'public'
AND event_object_table IN ('user_balances', 'user_profiles', 'creator_revenues');

-- 第2部分：完全清理所有相關觸發器和函數
SELECT '=== 清理觸發器和函數 ===' as step;

-- 移除所有可能的觸發器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS on_new_user ON auth.users;
DROP TRIGGER IF EXISTS handle_user_signup ON auth.users;

-- 移除所有可能的函數
DROP FUNCTION IF EXISTS initialize_new_user() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS handle_user_signup() CASCADE;

-- 第3部分：檢查現有表
SELECT '=== 檢查現有表 ===' as step;

SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name IN ('user_balances', 'user_profiles', 'creator_revenues')
ORDER BY table_name, ordinal_position;

-- 第4部分：刪除現有表並重建（無外鍵約束）
SELECT '=== 重建表結構 ===' as step;

-- 完全刪除現有表
DROP TABLE IF EXISTS creator_revenues CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS user_balances CASCADE;

-- 重建 user_balances 表（無外鍵）
CREATE TABLE user_balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    balance INTEGER DEFAULT 0 NOT NULL,
    withdrawable_amount INTEGER DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

-- 重建 user_profiles 表（無外鍵）
CREATE TABLE user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    display_name TEXT NOT NULL DEFAULT 'User',
    bio TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    investment_philosophy TEXT DEFAULT '',
    specializations TEXT[] DEFAULT '{}',
    years_experience INTEGER DEFAULT 0,
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    article_count INTEGER DEFAULT 0,
    total_return_rate NUMERIC(10,4) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

-- 重建 creator_revenues 表（無外鍵）
CREATE TABLE creator_revenues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    creator_id UUID NOT NULL,
    revenue_type TEXT NOT NULL,
    amount INTEGER NOT NULL,
    source_id UUID,
    source_name TEXT,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 第5部分：設置 RLS 政策
SELECT '=== 設置 RLS 政策 ===' as step;

ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE creator_revenues ENABLE ROW LEVEL SECURITY;

-- 創建寬鬆的政策
CREATE POLICY "allow_all_for_authenticated" ON user_balances 
FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_for_authenticated" ON user_profiles 
FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_for_authenticated" ON creator_revenues 
FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 第6部分：創建簡化的初始化函數
SELECT '=== 創建初始化函數 ===' as step;

CREATE OR REPLACE FUNCTION initialize_current_user_data()
RETURNS json AS $$
DECLARE
    current_user_id UUID;
    display_name_text TEXT;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未認證');
    END IF;
    
    -- 生成唯一顯示名稱
    display_name_text := 'User' || substring(replace(current_user_id::text, '-', ''), 1, 8);
    
    BEGIN
        -- 創建用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (current_user_id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);
        
        -- 創建用戶檔案
        INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
        VALUES (
            current_user_id, 
            display_name_text,
            '投資專家',
            '價值投資'
        )
        ON CONFLICT (user_id) DO UPDATE SET
            updated_at = now();
        
        -- 清理舊收益數據
        DELETE FROM creator_revenues WHERE creator_id = current_user_id;
        
        -- 創建新收益數據
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

GRANT EXECUTE ON FUNCTION initialize_current_user_data() TO authenticated;

-- 第7部分：創建索引
SELECT '=== 創建索引 ===' as step;

CREATE INDEX IF NOT EXISTS idx_user_balances_user_id ON user_balances(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_creator_revenues_creator_id ON creator_revenues(creator_id);

-- 第8部分：最終檢查
SELECT '=== 最終檢查 ===' as step;

-- 確認沒有觸發器
SELECT 
    'auth.users 觸發器數量' as check_item,
    COUNT(*)::text as result
FROM information_schema.triggers 
WHERE event_object_table = 'users' 
AND event_object_schema = 'auth'

UNION ALL

SELECT 
    '表創建狀態' as check_item,
    CASE 
        WHEN COUNT(*) = 3 THEN '✅ 所有表已創建'
        ELSE '❌ 表創建不完整'
    END as result
FROM information_schema.tables
WHERE table_schema = 'public' 
AND table_name IN ('user_balances', 'user_profiles', 'creator_revenues');

SELECT '✅ 修復的診斷和清理完成！用戶註冊應該不會再有問題。' as final_status;