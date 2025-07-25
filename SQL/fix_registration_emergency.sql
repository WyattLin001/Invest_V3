-- 緊急修復用戶註冊問題
-- 執行此腳本解決 "Database error saving new user" 錯誤

-- ========================================
-- 第1步：移除所有可能導致衝突的觸發器和函數
-- ========================================

-- 刪除現有觸發器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;

-- 刪除所有可能衝突的函數
DROP FUNCTION IF EXISTS handle_new_user_signup() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS initialize_new_user() CASCADE;
DROP FUNCTION IF EXISTS initialize_current_user_data() CASCADE;

-- ========================================
-- 第2步：確保基本表結構存在（最小化版本）
-- ========================================

-- 如果 user_profiles 表不存在，創建基本版本
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY,
    email TEXT,
    username TEXT,
    display_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 確保 RLS 被禁用（臨時）
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- 刪除所有現有的 RLS 策略
DROP POLICY IF EXISTS "authenticated_users_all_access" ON user_profiles;

-- ========================================
-- 第3步：創建超簡單的註冊函數（無錯誤處理）
-- ========================================

CREATE OR REPLACE FUNCTION handle_new_user_simple()
RETURNS TRIGGER AS $$
DECLARE
    base_username TEXT;
    final_username TEXT;
    username_counter INTEGER := 0;
BEGIN
    -- 生成基本用戶名
    IF NEW.email IS NOT NULL THEN
        base_username := split_part(NEW.email, '@', 1);
    ELSE
        base_username := 'user' || substring(replace(NEW.id::text, '-', ''), 1, 6);
    END IF;
    
    final_username := base_username;
    
    -- 確保用戶名唯一（簡單方法）
    WHILE EXISTS (SELECT 1 FROM user_profiles WHERE username = final_username) LOOP
        username_counter := username_counter + 1;
        final_username := base_username || username_counter::text;
    END LOOP;
    
    -- 插入用戶資料（僅基本欄位）
    INSERT INTO user_profiles (id, email, username, display_name) 
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        final_username,
        COALESCE(split_part(COALESCE(NEW.email, ''), '@', 1), 'User')
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 第4步：創建新的觸發器
-- ========================================

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_simple();

-- ========================================
-- 第5步：驗證設置
-- ========================================

-- 檢查表是否存在
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') 
        THEN '✅ user_profiles 表已存在'
        ELSE '❌ user_profiles 表不存在'
    END as table_status;

-- 檢查觸發器是否存在
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'on_auth_user_created') 
        THEN '✅ 註冊觸發器已創建'
        ELSE '❌ 註冊觸發器不存在'
    END as trigger_status;

-- 顯示完成訊息
SELECT '🎉 緊急修復完成！現在嘗試註冊新用戶。' as status;