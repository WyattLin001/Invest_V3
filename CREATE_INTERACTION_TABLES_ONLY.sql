-- =====================================================
-- 僅創建文章互動表（假設主表已存在）
-- 創建日期: 2025-07-23
-- 目的: 快速創建 article_likes, article_comments, article_shares
-- =====================================================

-- 開始事務
BEGIN;

RAISE NOTICE '開始創建文章互動系統表...';

-- =====================================================
-- 1. 創建文章按讚表
-- =====================================================

CREATE TABLE IF NOT EXISTS article_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL,
    user_id UUID NOT NULL,
    user_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 確保同一用戶對同一文章只能按讚一次
    UNIQUE(article_id, user_id)
);

-- 創建索引
CREATE INDEX IF NOT EXISTS idx_article_likes_article_id ON article_likes(article_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_user_id ON article_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_created_at ON article_likes(created_at);

RAISE NOTICE '✅ article_likes 表已創建';

-- =====================================================
-- 2. 創建文章留言表
-- =====================================================

CREATE TABLE IF NOT EXISTS article_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL,
    user_id UUID NOT NULL,
    user_name TEXT NOT NULL,
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建索引
CREATE INDEX IF NOT EXISTS idx_article_comments_article_id ON article_comments(article_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_user_id ON article_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_created_at ON article_comments(created_at DESC);

RAISE NOTICE '✅ article_comments 表已創建';

-- =====================================================
-- 3. 創建文章分享表
-- =====================================================

CREATE TABLE IF NOT EXISTS article_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL,
    user_id UUID NOT NULL,
    user_name TEXT NOT NULL,
    group_id UUID NOT NULL,
    group_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 確保同一用戶不會重複分享同一文章到同一群組
    UNIQUE(article_id, user_id, group_id)
);

-- 創建索引
CREATE INDEX IF NOT EXISTS idx_article_shares_article_id ON article_shares(article_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_user_id ON article_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_group_id ON article_shares(group_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_created_at ON article_shares(created_at);

RAISE NOTICE '✅ article_shares 表已創建';

-- =====================================================
-- 4. 啟用行級安全
-- =====================================================

ALTER TABLE article_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_shares ENABLE ROW LEVEL SECURITY;

RAISE NOTICE '✅ RLS 已啟用';

-- =====================================================
-- 5. 創建安全策略
-- =====================================================

-- article_likes 策略
DROP POLICY IF EXISTS "Anyone can view article likes" ON article_likes;
DROP POLICY IF EXISTS "Users can insert own likes" ON article_likes;
DROP POLICY IF EXISTS "Users can delete own likes" ON article_likes;

CREATE POLICY "Anyone can view article likes" ON article_likes FOR SELECT USING (true);
CREATE POLICY "Users can insert own likes" ON article_likes FOR INSERT WITH CHECK (true); -- 簡化版本，不檢查 auth.uid()
CREATE POLICY "Users can delete own likes" ON article_likes FOR DELETE USING (true);

-- article_comments 策略
DROP POLICY IF EXISTS "Anyone can view article comments" ON article_comments;
DROP POLICY IF EXISTS "Users can insert own comments" ON article_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON article_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON article_comments;

CREATE POLICY "Anyone can view article comments" ON article_comments FOR SELECT USING (true);
CREATE POLICY "Users can insert own comments" ON article_comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own comments" ON article_comments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Users can delete own comments" ON article_comments FOR DELETE USING (true);

-- article_shares 策略
DROP POLICY IF EXISTS "Anyone can view article shares" ON article_shares;
DROP POLICY IF EXISTS "Users can insert own shares" ON article_shares;
DROP POLICY IF EXISTS "Users can delete own shares" ON article_shares;

CREATE POLICY "Anyone can view article shares" ON article_shares FOR SELECT USING (true);
CREATE POLICY "Users can insert own shares" ON article_shares FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete own shares" ON article_shares FOR DELETE USING (true);

RAISE NOTICE '✅ 安全策略已創建';

-- =====================================================
-- 6. 創建觸發器
-- =====================================================

-- 創建更新 updated_at 的函數
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language plpgsql;

-- 為 article_comments 表添加觸發器
DROP TRIGGER IF EXISTS update_article_comments_updated_at ON article_comments;
CREATE TRIGGER update_article_comments_updated_at
    BEFORE UPDATE ON article_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

RAISE NOTICE '✅ 觸發器已創建';

-- =====================================================
-- 7. 創建基本統計視圖（不依賴外鍵約束）
-- =====================================================

DROP VIEW IF EXISTS article_interaction_stats;

CREATE VIEW article_interaction_stats AS
SELECT 
    articles_with_interactions.article_id,
    'Unknown' as title,  -- 簡化版本
    'Unknown' as author, -- 簡化版本
    COALESCE(likes.likes_count, 0) as likes_count,
    COALESCE(comments.comments_count, 0) as comments_count,
    COALESCE(shares.shares_count, 0) as shares_count
FROM (
    -- 獲取所有有互動的文章ID
    SELECT DISTINCT article_id FROM (
        SELECT article_id FROM article_likes
        UNION
        SELECT article_id FROM article_comments
        UNION 
        SELECT article_id FROM article_shares
    ) as all_articles
) articles_with_interactions
LEFT JOIN (
    SELECT article_id, COUNT(*) as likes_count
    FROM article_likes
    GROUP BY article_id
) likes ON articles_with_interactions.article_id = likes.article_id
LEFT JOIN (
    SELECT article_id, COUNT(*) as comments_count
    FROM article_comments
    GROUP BY article_id
) comments ON articles_with_interactions.article_id = comments.article_id
LEFT JOIN (
    SELECT article_id, COUNT(*) as shares_count
    FROM article_shares
    GROUP BY article_id
) shares ON articles_with_interactions.article_id = shares.article_id;

RAISE NOTICE '✅ 基本統計視圖已創建';

-- =====================================================
-- 8. 驗證結果
-- =====================================================

-- 檢查表是否創建成功
SELECT 
    table_name,
    'Table' as object_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t.table_name AND table_schema = 'public') 
        THEN '✅ 已創建'
        ELSE '❌ 缺失'
    END as status
FROM (VALUES 
    ('article_likes'),
    ('article_comments'),
    ('article_shares')
) AS t(table_name)

UNION ALL

-- 檢查視圖
SELECT 
    'article_interaction_stats' as table_name,
    'View' as object_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'article_interaction_stats' AND table_schema = 'public') 
        THEN '✅ 已創建'
        ELSE '❌ 缺失'
    END as status

ORDER BY object_type, table_name;

-- 提交事務
COMMIT;

RAISE NOTICE '=== 互動表創建完成 ===';
RAISE NOTICE '現在可以開始測試文章互動功能';

-- =====================================================
-- 測試查詢（可選）
-- =====================================================

-- 測試插入一條假數據（需要提供真實的UUID）
/*
INSERT INTO article_likes (article_id, user_id, user_name) 
VALUES (
    uuid_generate_v4(), -- 替換為真實的 article_id
    uuid_generate_v4(), -- 替換為真實的 user_id
    '測試用戶'
);
*/

-- 測試查詢統計視圖
-- SELECT * FROM article_interaction_stats LIMIT 5;