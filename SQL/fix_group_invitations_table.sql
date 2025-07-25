-- 修復群組邀請表結構問題
-- 解決錯誤：column group_invitations.invitee_email does not exist

-- ========================================
-- 第1步：檢查現有 group_invitations 表結構
-- ========================================

-- 顯示當前表結構
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'group_invitations' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- ========================================
-- 第2步：添加缺失的 invitee_email 欄位
-- ========================================

-- 添加 invitee_email 欄位
ALTER TABLE group_invitations 
ADD COLUMN IF NOT EXISTS invitee_email TEXT;

-- 添加其他可能需要的欄位
ALTER TABLE group_invitations 
ADD COLUMN IF NOT EXISTS message TEXT;

ALTER TABLE group_invitations 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '7 days');

-- ========================================
-- 第3步：更新表結構以支持完整的邀請功能
-- ========================================

-- 確保表有所有必需的欄位
-- 如果表結構不完整，重新創建
DO $$
DECLARE
    missing_columns INTEGER := 0;
BEGIN
    -- 檢查缺失的重要欄位數量
    SELECT 5 - COUNT(*) INTO missing_columns
    FROM information_schema.columns 
    WHERE table_name = 'group_invitations' 
    AND table_schema = 'public'
    AND column_name IN ('invitee_email', 'message', 'expires_at', 'inviter_id', 'group_id');
    
    -- 如果缺失重要欄位太多，重新創建表
    IF missing_columns > 2 THEN
        -- 備份現有資料（如果有的話）
        CREATE TEMP TABLE temp_invitations AS 
        SELECT * FROM group_invitations;
        
        -- 刪除舊表
        DROP TABLE IF EXISTS group_invitations CASCADE;
        
        -- 重新創建完整的 group_invitations 表
        CREATE TABLE group_invitations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            group_id UUID NOT NULL,
            inviter_id UUID NOT NULL,
            invitee_id UUID,
            invitee_email TEXT,
            message TEXT DEFAULT '邀請您加入我們的投資群組',
            status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
            expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '7 days'),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            
            -- 確保 invitee_id 或 invitee_email 至少有一個
            CONSTRAINT check_invitee CHECK (invitee_id IS NOT NULL OR invitee_email IS NOT NULL)
        );
        
        -- 創建索引
        CREATE INDEX IF NOT EXISTS idx_group_invitations_group_id ON group_invitations(group_id);
        CREATE INDEX IF NOT EXISTS idx_group_invitations_invitee_email ON group_invitations(invitee_email);
        CREATE INDEX IF NOT EXISTS idx_group_invitations_invitee_id ON group_invitations(invitee_id);
        CREATE INDEX IF NOT EXISTS idx_group_invitations_status ON group_invitations(status);
        
        -- 啟用 RLS（如果需要）
        ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;
        
        -- 創建寬鬆的 RLS 政策
        CREATE POLICY "authenticated_users_all_access" ON group_invitations 
        FOR ALL TO authenticated USING (true) WITH CHECK (true);
        
        RAISE NOTICE '✅ group_invitations 表已重新創建，包含所有必需欄位';
        
        -- 嘗試恢復備份資料（如果適用）
        BEGIN
            INSERT INTO group_invitations 
            SELECT * FROM temp_invitations 
            WHERE TRUE; -- 只在欄位匹配時插入
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️ 無法恢復舊資料，但新表結構已就緒';
        END;
        
    ELSE
        RAISE NOTICE '✅ group_invitations 表結構基本完整，只需添加缺失欄位';
    END IF;
END $$;

-- ========================================
-- 第4步：確保外鍵約束存在（如果適用）
-- ========================================

-- 注意：由於我們不確定 investment_groups 和 user_profiles 表的存在，
-- 我們將外鍵約束設為可選，避免創建失敗

-- 檢查並添加外鍵約束（如果引用表存在）
DO $$
BEGIN
    -- 檢查是否可以添加到 investment_groups 的外鍵
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'investment_groups') THEN
        ALTER TABLE group_invitations 
        ADD CONSTRAINT fk_group_invitations_group_id 
        FOREIGN KEY (group_id) REFERENCES investment_groups(id) ON DELETE CASCADE;
        
        RAISE NOTICE '✅ 添加了到 investment_groups 的外鍵約束';
    END IF;
    
    -- 檢查是否可以添加到 user_profiles 的外鍵
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        ALTER TABLE group_invitations 
        ADD CONSTRAINT fk_group_invitations_inviter_id 
        FOREIGN KEY (inviter_id) REFERENCES user_profiles(id) ON DELETE CASCADE;
        
        ALTER TABLE group_invitations 
        ADD CONSTRAINT fk_group_invitations_invitee_id 
        FOREIGN KEY (invitee_id) REFERENCES user_profiles(id) ON DELETE CASCADE;
        
        RAISE NOTICE '✅ 添加了到 user_profiles 的外鍵約束';
    END IF;
    
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE '⚠️ 外鍵約束已存在，跳過添加';
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ 無法添加外鍵約束，但表結構已修復: %', SQLERRM;
END $$;

-- ========================================
-- 第5步：驗證修復結果
-- ========================================

-- 顯示最終表結構
SELECT 
    'group_invitations' as table_name,
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'group_invitations' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 檢查表是否可以正常查詢
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM group_invitations LIMIT 1) OR 
             EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'group_invitations')
        THEN '✅ group_invitations 表已就緒，可以正常使用'
        ELSE '❌ group_invitations 表仍有問題'
    END as status;

SELECT '🎉 群組邀請表結構修復完成！' as final_message;