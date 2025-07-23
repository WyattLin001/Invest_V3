-- =====================================================
-- 文章互動系統數據庫表結構 (修復版本)
-- 創建日期: 2025-07-23
-- 目的: 支援文章按讚、留言、分享功能
-- 修復: 處理已存在的策略和表結構
-- =====================================================

-- 開始事務
BEGIN;

-- =====================================================
-- 1. 檢查並創建文章按讚表
-- =====================================================

CREATE TABLE IF NOT EXISTS article_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 確保同一用戶對同一文章只能按讚一次
    UNIQUE(article_id, user_id)
);

-- 為 article_likes 表創建索引 (如果不存在)
CREATE INDEX IF NOT EXISTS idx_article_likes_article_id ON article_likes(article_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_user_id ON article_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_created_at ON article_likes(created_at);

-- =====================================================
-- 2. 檢查並創建文章留言表
-- =====================================================

CREATE TABLE IF NOT EXISTS article_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 為 article_comments 表創建索引 (如果不存在)
CREATE INDEX IF NOT EXISTS idx_article_comments_article_id ON article_comments(article_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_user_id ON article_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_created_at ON article_comments(created_at DESC);

-- =====================================================
-- 3. 檢查並創建文章分享表
-- =====================================================

CREATE TABLE IF NOT EXISTS article_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    group_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 確保同一用戶不會重複分享同一文章到同一群組
    UNIQUE(article_id, user_id, group_id)
);

-- 為 article_shares 表創建索引 (如果不存在)
CREATE INDEX IF NOT EXISTS idx_article_shares_article_id ON article_shares(article_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_user_id ON article_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_group_id ON article_shares(group_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_created_at ON article_shares(created_at);

-- =====================================================
-- 4. 設置行級安全策略 (RLS) - 安全處理已存在的策略
-- =====================================================

-- 啟用行級安全
ALTER TABLE article_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_shares ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- article_likes 安全策略 (先檢查是否存在，不存在才創建)
-- =====================================================

-- 刪除可能已存在的策略 (如果存在)
DROP POLICY IF EXISTS "Anyone can view article likes" ON article_likes;
DROP POLICY IF EXISTS "Users can insert own likes" ON article_likes;
DROP POLICY IF EXISTS "Users can delete own likes" ON article_likes;

-- 重新創建策略
CREATE POLICY "Anyone can view article likes" ON article_likes
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own likes" ON article_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own likes" ON article_likes
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- article_comments 安全策略
-- =====================================================

-- 刪除可能已存在的策略
DROP POLICY IF EXISTS "Anyone can view article comments" ON article_comments;
DROP POLICY IF EXISTS "Users can insert own comments" ON article_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON article_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON article_comments;

-- 重新創建策略
CREATE POLICY "Anyone can view article comments" ON article_comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own comments" ON article_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own comments" ON article_comments
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments" ON article_comments
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- article_shares 安全策略
-- =====================================================

-- 刪除可能已存在的策略
DROP POLICY IF EXISTS "Anyone can view article shares" ON article_shares;
DROP POLICY IF EXISTS "Users can insert own shares" ON article_shares;
DROP POLICY IF EXISTS "Users can delete own shares" ON article_shares;

-- 重新創建策略
CREATE POLICY "Anyone can view article shares" ON article_shares
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own shares" ON article_shares
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own shares" ON article_shares
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 5. 創建或替換觸發器函數
-- =====================================================

-- 創建更新 updated_at 的函數 (如果已存在會替換)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language plpgsql;

-- 刪除可能已存在的觸發器，然後重新創建
DROP TRIGGER IF EXISTS update_article_comments_updated_at ON article_comments;

CREATE TRIGGER update_article_comments_updated_at
    BEFORE UPDATE ON article_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. 創建或替換統計視圖
-- =====================================================

-- 刪除可能已存在的視圖，然後重新創建
DROP VIEW IF EXISTS article_interaction_stats;

CREATE VIEW article_interaction_stats AS
SELECT 
    a.id as article_id,
    a.title,
    a.author,
    COALESCE(likes.likes_count, 0) as likes_count,
    COALESCE(comments.comments_count, 0) as comments_count,
    COALESCE(shares.shares_count, 0) as shares_count
FROM articles a
LEFT JOIN (
    SELECT article_id, COUNT(*) as likes_count
    FROM article_likes
    GROUP BY article_id
) likes ON a.id = likes.article_id
LEFT JOIN (
    SELECT article_id, COUNT(*) as comments_count
    FROM article_comments
    GROUP BY article_id
) comments ON a.id = comments.article_id
LEFT JOIN (
    SELECT article_id, COUNT(*) as shares_count
    FROM article_shares
    GROUP BY article_id
) shares ON a.id = shares.article_id;

-- =====================================================
-- 7. 驗證創建結果
-- =====================================================

-- 檢查表是否創建成功
DO $$
BEGIN
    RAISE NOTICE '=== 檢查表結構 ===';
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_likes' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ article_likes 表已存在';
    ELSE
        RAISE NOTICE '❌ article_likes 表不存在';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_comments' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ article_comments 表已存在';
    ELSE
        RAISE NOTICE '❌ article_comments 表不存在';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_shares' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ article_shares 表已存在';
    ELSE
        RAISE NOTICE '❌ article_shares 表不存在';
    END IF;
    
    RAISE NOTICE '=== 表結構檢查完成 ===';
END $$;

-- 檢查策略是否創建成功
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename IN ('article_likes', 'article_comments', 'article_shares')
ORDER BY tablename, policyname;

-- 提交事務
COMMIT;

-- =====================================================
-- 使用說明和注意事項
-- =====================================================

/*
修復說明：
1. 使用 DROP POLICY IF EXISTS 來避免策略重複創建錯誤
2. 使用 CREATE TABLE IF NOT EXISTS 來避免表重複創建
3. 使用 CREATE INDEX IF NOT EXISTS 來避免索引重複創建
4. 使用 CREATE OR REPLACE 來處理函數和視圖
5. 添加了驗證步驟來確認創建結果

執行順序：
1. 確保 articles 表和 investment_groups 表已存在
2. 確保 auth.users 表可用（Supabase 自動創建）
3. 執行此修復版 SQL 腳本
4. 檢查輸出信息確認創建成功
5. 測試 iOS 應用的互動功能

如果仍有錯誤：
- 檢查 articles 表是否存在
- 檢查 investment_groups 表是否存在
- 確認數據庫用戶有足夠權限
- 檢查是否有其他外鍵約束問題

性能優化：
- 所有必要的索引都已創建
- RLS 策略已正確設置
- 統計視圖可用於快速查詢
- 觸發器確保 updated_at 自動更新
*/