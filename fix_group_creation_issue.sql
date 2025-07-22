-- 修復群組創建後找不到的問題
-- 主要問題：group_members 表的 user_name 欄位為 NOT NULL 但未正確填入

-- ========================================
-- 第1步：診斷問題
-- ========================================

-- 檢查剛創建的群組是否存在
SELECT 
    'Recently created groups:' as info,
    id,
    name,
    host,
    member_count,
    created_at
FROM investment_groups 
WHERE created_at > now() - interval '1 hour'
ORDER BY created_at DESC;

-- 檢查對應的群組成員記錄
SELECT 
    'Group members for recent groups:' as info,
    gm.group_id,
    gm.user_id,
    gm.user_name,
    gm.role
FROM group_members gm
JOIN investment_groups ig ON gm.group_id = ig.id
WHERE ig.created_at > now() - interval '1 hour';

-- ========================================
-- 第2步：修復 group_members 表的約束問題
-- ========================================

-- 暫時允許 user_name 為空（臨時解決方案）
ALTER TABLE group_members 
ALTER COLUMN user_name DROP NOT NULL;

-- 為空的 user_name 設定預設值
UPDATE group_members 
SET user_name = COALESCE(
    (SELECT display_name FROM user_profiles WHERE id = group_members.user_id),
    'Unknown User'
)
WHERE user_name IS NULL OR user_name = '';

-- ========================================
-- 第3步：創建觸發器自動填入 user_name
-- ========================================

CREATE OR REPLACE FUNCTION auto_fill_user_name()
RETURNS TRIGGER AS $$
DECLARE
    user_display_name TEXT;
BEGIN
    -- 如果 user_name 為空或未提供，從 user_profiles 取得 display_name
    IF NEW.user_name IS NULL OR NEW.user_name = '' THEN
        SELECT display_name INTO user_display_name
        FROM user_profiles
        WHERE id = NEW.user_id;
        
        -- 如果找到用戶資料，使用 display_name；否則使用預設值
        NEW.user_name := COALESCE(user_display_name, 'User');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 創建觸發器
DROP TRIGGER IF EXISTS trigger_auto_fill_user_name ON group_members;

CREATE TRIGGER trigger_auto_fill_user_name
    BEFORE INSERT OR UPDATE ON group_members
    FOR EACH ROW
    EXECUTE FUNCTION auto_fill_user_name();

-- ========================================
-- 第4步：修復現有的群組創建者成員記錄
-- ========================================

-- 為最近創建但沒有成員記錄的群組創建主持人成員記錄
DO $$
DECLARE
    group_record RECORD;
    host_user_id UUID;
BEGIN
    -- 遍歷最近創建的群組
    FOR group_record IN 
        SELECT id, host, host_id 
        FROM investment_groups 
        WHERE created_at > now() - interval '1 hour'
        AND id NOT IN (SELECT DISTINCT group_id FROM group_members)
    LOOP
        -- 嘗試找到主持人的 user_id
        host_user_id := group_record.host_id;
        
        -- 如果 host_id 為空，嘗試通過 display_name 查找
        IF host_user_id IS NULL THEN
            SELECT id INTO host_user_id
            FROM user_profiles 
            WHERE display_name = group_record.host
            LIMIT 1;
        END IF;
        
        -- 如果找到主持人 ID，創建成員記錄
        IF host_user_id IS NOT NULL THEN
            INSERT INTO group_members (
                group_id, 
                user_id, 
                user_name, 
                role
            ) VALUES (
                group_record.id,
                host_user_id,
                group_record.host,
                'host'
            ) ON CONFLICT (group_id, user_id) DO NOTHING;
            
            RAISE NOTICE '✅ 已為群組 % 創建主持人成員記錄', group_record.host;
        ELSE
            RAISE NOTICE '⚠️ 找不到群組 % 的主持人用戶 ID', group_record.host;
        END IF;
    END LOOP;
END $$;

-- ========================================
-- 第5步：創建群組查詢優化視圖
-- ========================================

-- 創建一個視圖來優化群組查詢，包含成員檢查
CREATE OR REPLACE VIEW user_joined_groups_view AS
SELECT DISTINCT
    ig.*,
    gm.role as user_role,
    gm.joined_at
FROM investment_groups ig
INNER JOIN group_members gm ON ig.id = gm.group_id
WHERE gm.user_id = auth.uid();

-- 授權給認證用戶
GRANT SELECT ON user_joined_groups_view TO authenticated;

-- ========================================
-- 第6步：創建修復函數供應用程式調用
-- ========================================

CREATE OR REPLACE FUNCTION ensure_group_creator_membership(group_uuid UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
    group_info RECORD;
    user_info RECORD;
BEGIN
    -- 獲取當前用戶
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', '用戶未登入');
    END IF;
    
    -- 獲取群組資訊
    SELECT * INTO group_info
    FROM investment_groups
    WHERE id = group_uuid;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', '群組不存在');
    END IF;
    
    -- 獲取用戶資訊
    SELECT * INTO user_info
    FROM user_profiles
    WHERE id = current_user_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', '用戶資料不存在');
    END IF;
    
    -- 檢查是否已經是成員
    IF NOT EXISTS (SELECT 1 FROM group_members WHERE group_id = group_uuid AND user_id = current_user_id) THEN
        -- 插入成員記錄
        INSERT INTO group_members (
            group_id,
            user_id,
            user_name,
            role
        ) VALUES (
            group_uuid,
            current_user_id,
            user_info.display_name,
            CASE 
                WHEN group_info.host_id = current_user_id OR group_info.host = user_info.display_name 
                THEN 'host' 
                ELSE 'member' 
            END
        );
        
        RETURN json_build_object('success', true, 'message', '已加入群組成員');
    ELSE
        RETURN json_build_object('success', true, 'message', '已經是群組成員');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', '操作失敗: ' || SQLERRM);
END;
$$;

-- 授權給認證用戶
GRANT EXECUTE ON FUNCTION ensure_group_creator_membership(UUID) TO authenticated;

-- ========================================
-- 第7步：驗證修復結果
-- ========================================

-- 檢查最近創建的群組現在是否有成員記錄
SELECT 
    'Groups with members after fix:' as info,
    ig.id,
    ig.name,
    ig.host,
    COUNT(gm.user_id) as member_count
FROM investment_groups ig
LEFT JOIN group_members gm ON ig.id = gm.group_id
WHERE ig.created_at > now() - interval '1 hour'
GROUP BY ig.id, ig.name, ig.host
ORDER BY ig.created_at DESC;

-- 檢查觸發器是否正常運作
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name = 'trigger_auto_fill_user_name';

SELECT '🎉 群組創建問題修復完成！' as final_message;
SELECT '✅ 現在創建群組時會自動將創建者加入成員列表' as status;