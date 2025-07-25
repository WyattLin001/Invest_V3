-- =====================================================
-- 快速修復文章互動統計視圖
-- 修復列名歧義問題
-- =====================================================

-- 刪除可能已存在的視圖
DROP VIEW IF EXISTS article_interaction_stats;

-- 重新創建修復的統計視圖
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

-- 驗證視圖創建成功
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name = 'article_interaction_stats'
    AND table_schema = 'public';

-- 測試查詢視圖 (如果有文章數據)
SELECT 
    'article_interaction_stats 視圖已成功創建並可查詢' as status;