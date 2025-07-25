-- 修復現有 group_invitations 表 - 只添加缺失的欄位
-- 解決錯誤：column group_invitations.invitee_email does not exist

-- ========================================
-- 第1步：檢查現有表結構
-- ========================================

SELECT 'Current group_invitations table structure:' as info;

SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'group_invitations' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- ========================================
-- 第2步：安全地添加缺失欄位
-- ========================================

-- 添加 invitee_email 欄位（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'group_invitations' 
        AND column_name = 'invitee_email'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE group_invitations ADD COLUMN invitee_email TEXT;
        RAISE NOTICE '✅ 已添加 invitee_email 欄位';
    ELSE
        RAISE NOTICE '⚠️ invitee_email 欄位已存在';
    END IF;
END $$;

-- 添加 message 欄位（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'group_invitations' 
        AND column_name = 'message'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE group_invitations ADD COLUMN message TEXT DEFAULT '邀請您加入我們的投資群組';
        RAISE NOTICE '✅ 已添加 message 欄位';
    ELSE
        RAISE NOTICE '⚠️ message 欄位已存在';
    END IF;
END $$;

-- 添加 expires_at 欄位（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'group_invitations' 
        AND column_name = 'expires_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE group_invitations ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '7 days');
        RAISE NOTICE '✅ 已添加 expires_at 欄位';
    ELSE
        RAISE NOTICE '⚠️ expires_at 欄位已存在';
    END IF;
END $$;

-- 添加 invitee_id 欄位（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'group_invitations' 
        AND column_name = 'invitee_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE group_invitations ADD COLUMN invitee_id UUID;
        RAISE NOTICE '✅ 已添加 invitee_id 欄位';
    ELSE
        RAISE NOTICE '⚠️ invitee_id 欄位已存在';
    END IF;
END $$;

-- ========================================
-- 第3步：確保現有資料的完整性
-- ========================================

-- 更新現有記錄的 expires_at（如果是 NULL）
UPDATE group_invitations 
SET expires_at = created_at + interval '7 days'
WHERE expires_at IS NULL AND created_at IS NOT NULL;

-- 更新現有記錄的 message（如果是 NULL）
UPDATE group_invitations 
SET message = '邀請您加入我們的投資群組'
WHERE message IS NULL;

-- ========================================
-- 第4步：添加約束（如果需要）
-- ========================================

-- 確保 invitee_id 或 invitee_email 至少有一個
DO $$
BEGIN
    -- 檢查約束是否已存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'group_invitations' 
        AND constraint_name = 'check_invitee'
    ) THEN
        ALTER TABLE group_invitations 
        ADD CONSTRAINT check_invitee 
        CHECK (invitee_id IS NOT NULL OR invitee_email IS NOT NULL);
        RAISE NOTICE '✅ 已添加 check_invitee 約束';
    ELSE
        RAISE NOTICE '⚠️ check_invitee 約束已存在';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ 無法添加約束: %', SQLERRM;
END $$;

-- ========================================
-- 第5步：添加索引以提升性能
-- ========================================

-- 為 invitee_email 創建索引
CREATE INDEX IF NOT EXISTS idx_group_invitations_invitee_email 
ON group_invitations(invitee_email);

-- 為 invitee_id 創建索引
CREATE INDEX IF NOT EXISTS idx_group_invitations_invitee_id 
ON group_invitations(invitee_id);

-- 為 status 創建索引
CREATE INDEX IF NOT EXISTS idx_group_invitations_status 
ON group_invitations(status);

-- 為 expires_at 創建索引
CREATE INDEX IF NOT EXISTS idx_group_invitations_expires_at 
ON group_invitations(expires_at);

-- ========================================
-- 第6步：驗證修復結果
-- ========================================

SELECT 'Updated group_invitations table structure:' as info;

SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'group_invitations' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 檢查重要欄位是否都存在
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_invitations' 
            AND column_name = 'invitee_email'
        ) 
        THEN '✅ invitee_email 欄位已就緒'
        ELSE '❌ invitee_email 欄位仍然缺失'
    END as invitee_email_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_invitations' 
            AND column_name = 'message'
        ) 
        THEN '✅ message 欄位已就緒'
        ELSE '❌ message 欄位仍然缺失'
    END as message_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'group_invitations' 
            AND column_name = 'expires_at'
        ) 
        THEN '✅ expires_at 欄位已就緒'
        ELSE '❌ expires_at 欄位仍然缺失'
    END as expires_at_status;

-- 顯示當前資料數量
SELECT 
    COUNT(*) as total_invitations,
    COUNT(invitee_email) as invitations_with_email,
    COUNT(invitee_id) as invitations_with_id
FROM group_invitations;

SELECT '🎉 group_invitations 表修復完成！現在應該可以正常使用群組邀請功能了。' as final_message;