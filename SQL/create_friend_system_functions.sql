-- 創建好友系統所需的 Supabase 函數
-- 修復 FriendService 中調用的函數

-- ========================================
-- 第1步：創建搜尋用戶函數
-- ========================================

CREATE OR REPLACE FUNCTION search_users_by_id(search_user_id TEXT)
RETURNS TABLE (
    user_id TEXT,
    username TEXT,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id::TEXT as user_id,
        up.username,
        up.display_name,
        up.avatar_url,
        up.bio,
        up.created_at
    FROM user_profiles up
    WHERE up.username ILIKE '%' || search_user_id || '%'
       OR up.display_name ILIKE '%' || search_user_id || '%'
    LIMIT 10;
END;
$$;

-- 授權給認證用戶
GRANT EXECUTE ON FUNCTION search_users_by_id(TEXT) TO authenticated;

-- ========================================
-- 第2步：創建發送好友請求函數
-- ========================================

CREATE OR REPLACE FUNCTION send_friend_request(target_user_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_uuid UUID;
    target_user_uuid UUID;
    existing_request_count INTEGER;
    result_json JSON;
BEGIN
    -- 獲取當前用戶
    current_user_uuid := auth.uid();
    
    IF current_user_uuid IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未登入');
    END IF;
    
    -- 查找目標用戶
    SELECT id INTO target_user_uuid
    FROM user_profiles
    WHERE username = target_user_id OR id::TEXT = target_user_id
    LIMIT 1;
    
    IF target_user_uuid IS NULL THEN
        RETURN json_build_object('success', false, 'message', '找不到目標用戶');
    END IF;
    
    -- 檢查是否為自己
    IF current_user_uuid = target_user_uuid THEN
        RETURN json_build_object('success', false, 'message', '不能添加自己為好友');
    END IF;
    
    -- 檢查是否已經是好友或有待處理請求
    SELECT COUNT(*) INTO existing_request_count
    FROM friendships
    WHERE (requester_id = current_user_uuid AND addressee_id = target_user_uuid)
       OR (requester_id = target_user_uuid AND addressee_id = current_user_uuid);
    
    IF existing_request_count > 0 THEN
        RETURN json_build_object('success', false, 'message', '已經是好友或有待處理的請求');
    END IF;
    
    -- 創建好友請求
    INSERT INTO friendships (requester_id, addressee_id, status)
    VALUES (current_user_uuid, target_user_uuid, 'pending');
    
    RETURN json_build_object('success', true, 'message', '好友請求已發送');
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', '發送失敗: ' || SQLERRM);
END;
$$;

-- 授權給認證用戶
GRANT EXECUTE ON FUNCTION send_friend_request(TEXT) TO authenticated;

-- ========================================
-- 第3步：創建接受好友請求函數
-- ========================================

CREATE OR REPLACE FUNCTION accept_friend_request(requester_user_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_uuid UUID;
    requester_uuid UUID;
    updated_count INTEGER;
BEGIN
    -- 獲取當前用戶
    current_user_uuid := auth.uid();
    
    IF current_user_uuid IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未登入');
    END IF;
    
    -- 查找請求者
    SELECT id INTO requester_uuid
    FROM user_profiles
    WHERE username = requester_user_id OR id::TEXT = requester_user_id
    LIMIT 1;
    
    IF requester_uuid IS NULL THEN
        RETURN json_build_object('success', false, 'message', '找不到請求者');
    END IF;
    
    -- 更新好友請求狀態
    UPDATE friendships
    SET status = 'accepted', updated_at = now()
    WHERE requester_id = requester_uuid 
      AND addressee_id = current_user_uuid 
      AND status = 'pending';
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    IF updated_count = 0 THEN
        RETURN json_build_object('success', false, 'message', '沒有找到待處理的好友請求');
    END IF;
    
    RETURN json_build_object('success', true, 'message', '已接受好友請求');
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', '接受失敗: ' || SQLERRM);
END;
$$;

-- 授權給認證用戶
GRANT EXECUTE ON FUNCTION accept_friend_request(TEXT) TO authenticated;

-- ========================================
-- 第4步：創建獲取好友列表的視圖或函數
-- ========================================

CREATE OR REPLACE VIEW user_friends_view AS
SELECT 
    f.id,
    CASE 
        WHEN f.requester_id = auth.uid() THEN f.addressee_id
        ELSE f.requester_id 
    END as friend_id,
    CASE 
        WHEN f.requester_id = auth.uid() THEN ap.username
        ELSE rp.username 
    END as friend_username,
    CASE 
        WHEN f.requester_id = auth.uid() THEN ap.display_name
        ELSE rp.display_name 
    END as friend_display_name,
    CASE 
        WHEN f.requester_id = auth.uid() THEN ap.avatar_url
        ELSE rp.avatar_url 
    END as friend_avatar_url,
    f.created_at,
    f.updated_at
FROM friendships f
LEFT JOIN user_profiles rp ON f.requester_id = rp.id
LEFT JOIN user_profiles ap ON f.addressee_id = ap.id
WHERE f.status = 'accepted'
  AND (f.requester_id = auth.uid() OR f.addressee_id = auth.uid());

-- ========================================
-- 第5步：測試函數
-- ========================================

-- 測試搜尋用戶函數
SELECT 'Testing search_users_by_id function:' as test_info;
SELECT * FROM search_users_by_id('test') LIMIT 1;

-- 顯示所有創建的函數
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('search_users_by_id', 'send_friend_request', 'accept_friend_request')
ORDER BY routine_name;

-- 檢查視圖
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name = 'user_friends_view'
AND table_schema = 'public';

SELECT '🎉 好友系統函數創建完成！' as final_message;
SELECT '✅ FriendService 現在應該可以正常運作了' as status;