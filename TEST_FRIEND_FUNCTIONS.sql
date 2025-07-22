-- 測試好友系統函數
-- 執行完 COMPLETE_FRIEND_SETUP.sql 後運行此測試腳本

-- 1. 檢查測試用戶是否創建成功
SELECT 
    id, 
    display_name, 
    user_id, 
    created_at
FROM public.user_profiles 
WHERE user_id IN ('123456', '789012', '456789')
ORDER BY display_name;

-- 2. 測試搜尋用戶函數
SELECT * FROM search_users_by_id('123456');
SELECT * FROM search_users_by_id('789012');
SELECT * FROM search_users_by_id('456789');

-- 3. 檢查觸發器是否正常工作
-- 創建一個新測試用戶，看是否自動分配 user_id
INSERT INTO public.user_profiles (id, display_name, bio)
VALUES (gen_random_uuid(), '自動ID測試用戶', '測試自動分配ID功能')
RETURNING id, display_name, user_id;

-- 4. 檢查好友關係表結構
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'friendships' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 5. 檢查 RLS 政策
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'friendships';

-- 6. 測試好友系統函數的基本功能
-- 注意：這些函數需要在已登錄用戶的上下文中執行才能正常工作
-- 在實際 App 中測試時會自動有用戶上下文

-- 顯示完成訊息
SELECT 
    'Friend system setup completed!' as status,
    COUNT(DISTINCT user_id) as total_users_with_id,
    COUNT(*) as total_user_profiles
FROM public.user_profiles 
WHERE user_id IS NOT NULL;