-- 針對您的數據庫結構精確修復 group_invitations 表
-- 解決錯誤：column group_invitations.invitee_email does not exist

-- ========================================
-- 現有的 group_invitations 表結構：
-- - id, group_id, inviter_id, invitee_id (必需), status, created_at, updated_at
-- 問題：缺少 invitee_email 欄位，但應用程式需要此欄位來支持 Email 邀請
-- ========================================

-- 第1步：添加缺失的 invitee_email 欄位
ALTER TABLE group_invitations 
ADD COLUMN invitee_email TEXT;

-- 第2步：添加邀請訊息欄位
ALTER TABLE group_invitations 
ADD COLUMN message TEXT DEFAULT '邀請您加入我們的投資群組';

-- 第3步：添加邀請過期時間
ALTER TABLE group_invitations 
ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '7 days');

-- 第4步：修改 invitee_id 約束，允許 NULL（因為可能只有 Email）
ALTER TABLE group_invitations 
ALTER COLUMN invitee_id DROP NOT NULL;

-- 第5步：添加約束確保 invitee_id 或 invitee_email 至少有一個
ALTER TABLE group_invitations 
ADD CONSTRAINT check_invitee_exists 
CHECK (invitee_id IS NOT NULL OR invitee_email IS NOT NULL);

-- 第6步：擴展 status 檢查約束，添加 'expired' 狀態
ALTER TABLE group_invitations 
DROP CONSTRAINT IF EXISTS group_invitations_status_check;

ALTER TABLE group_invitations 
ADD CONSTRAINT group_invitations_status_check 
CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'expired'::text]));

-- 第7步：創建性能優化索引
CREATE INDEX IF NOT EXISTS idx_group_invitations_invitee_email 
ON group_invitations(invitee_email) WHERE invitee_email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_group_invitations_status_pending 
ON group_invitations(status) WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_group_invitations_expires_at 
ON group_invitations(expires_at) WHERE expires_at IS NOT NULL;

-- 第8步：為現有記錄設定過期時間（如果是 NULL）
UPDATE group_invitations 
SET expires_at = created_at + interval '7 days'
WHERE expires_at IS NULL;

-- 第9步：創建自動過期清理函數（可選）
CREATE OR REPLACE FUNCTION cleanup_expired_invitations()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE group_invitations 
    SET status = 'expired'
    WHERE status = 'pending' 
    AND expires_at < now();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- 第10步：驗證修復結果
SELECT 'group_invitations 表修復後的結構:' as info;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'group_invitations' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 檢查重要欄位
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_invitations' 
            AND column_name = 'invitee_email'
        ) 
        THEN '✅ invitee_email 欄位已添加'
        ELSE '❌ invitee_email 欄位仍缺失'
    END as invitee_email_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_invitations' 
            AND column_name = 'message'
        ) 
        THEN '✅ message 欄位已添加'
        ELSE '❌ message 欄位缺失'
    END as message_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_invitations' 
            AND column_name = 'expires_at'
        ) 
        THEN '✅ expires_at 欄位已添加'
        ELSE '❌ expires_at 欄位缺失'
    END as expires_at_status;

-- 測試查詢（應該不再出現錯誤）
SELECT 'Testing query with invitee_email field:' as test_info;

SELECT 
    id, 
    group_id, 
    inviter_id, 
    invitee_id, 
    invitee_email,  -- 這個欄位現在應該存在
    message,
    status, 
    expires_at,
    created_at 
FROM group_invitations 
LIMIT 1;

-- 檢查約束
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'group_invitations' 
AND table_schema = 'public'
ORDER BY constraint_name;

SELECT '🎉 group_invitations 表修復完成！' as final_message;
SELECT '✅ 現在支持通過 Email 或 user_id 發送群組邀請' as feature_update;
SELECT '✅ 群組邀請功能應該可以正常使用了' as status;