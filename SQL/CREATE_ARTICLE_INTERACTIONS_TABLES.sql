-- =====================================================
-- 文章互動系統數據庫表結構
-- 創建日期: 2025-07-22
-- 目的: 支援文章按讚、留言、分享功能
-- =====================================================

-- 1. 文章按讚表
CREATE TABLE IF NOT EXISTS article_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 確保同一用戶對同一文章只能按讚一次
    UNIQUE(article_id, user_id)
);

-- 為 article_likes 表創建索引以優化查詢性能
CREATE INDEX IF NOT EXISTS idx_article_likes_article_id ON article_likes(article_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_user_id ON article_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_created_at ON article_likes(created_at);

-- 2. 文章留言表
CREATE TABLE IF NOT EXISTS article_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 為 article_comments 表創建索引
CREATE INDEX IF NOT EXISTS idx_article_comments_article_id ON article_comments(article_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_user_id ON article_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_created_at ON article_comments(created_at DESC);

-- 3. 文章分享表
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

-- 為 article_shares 表創建索引
CREATE INDEX IF NOT EXISTS idx_article_shares_article_id ON article_shares(article_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_user_id ON article_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_group_id ON article_shares(group_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_created_at ON article_shares(created_at);

-- =====================================================
-- 設置行級安全策略 (RLS)
-- =====================================================

-- 啟用行級安全
ALTER TABLE article_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_shares ENABLE ROW LEVEL SECURITY;

-- article_likes 安全策略
-- 用戶可以查看所有按讚記錄
CREATE POLICY "Anyone can view article likes" ON article_likes
    FOR SELECT USING (true);

-- 用戶只能為自己的按讚進行插入和刪除
CREATE POLICY "Users can insert own likes" ON article_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own likes" ON article_likes
    FOR DELETE USING (auth.uid() = user_id);

-- article_comments 安全策略  
-- 用戶可以查看所有留言
CREATE POLICY "Anyone can view article comments" ON article_comments
    FOR SELECT USING (true);

-- 用戶只能插入自己的留言
CREATE POLICY "Users can insert own comments" ON article_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 用戶可以更新自己的留言
CREATE POLICY "Users can update own comments" ON article_comments
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 用戶可以刪除自己的留言
CREATE POLICY "Users can delete own comments" ON article_comments
    FOR DELETE USING (auth.uid() = user_id);

-- article_shares 安全策略
-- 用戶可以查看所有分享記錄
CREATE POLICY "Anyone can view article shares" ON article_shares
    FOR SELECT USING (true);

-- 用戶只能插入自己的分享記錄
CREATE POLICY "Users can insert own shares" ON article_shares
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 用戶可以刪除自己的分享記錄
CREATE POLICY "Users can delete own shares" ON article_shares
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 創建觸發器以自動更新 updated_at 欄位
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
CREATE TRIGGER update_article_comments_updated_at
    BEFORE UPDATE ON article_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 創建統計視圖（可選，用於性能優化）
-- =====================================================

-- 創建文章互動統計視圖
CREATE OR REPLACE VIEW article_interaction_stats AS
SELECT 
    a.id as article_id,
    a.title,
    a.author,
    COALESCE(likes_count, 0) as likes_count,
    COALESCE(comments_count, 0) as comments_count,
    COALESCE(shares_count, 0) as shares_count
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
-- 測試數據插入（可選）
-- =====================================================

-- 注意：以下插入語句僅用於測試，生產環境請謹慎使用

-- 插入測試按讚數據（需要先有有效的 article_id 和 user_id）
-- INSERT INTO article_likes (article_id, user_id, user_name) 
-- VALUES (
--     '你的文章ID',
--     '你的用戶ID',
--     '測試用戶'
-- );

-- 插入測試留言數據
-- INSERT INTO article_comments (article_id, user_id, user_name, content)
-- VALUES (
--     '你的文章ID',
--     '你的用戶ID', 
--     '測試用戶',
--     '這是一條測試留言'
-- );

-- =====================================================
-- 完成
-- =====================================================

-- 檢查表是否創建成功
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name IN ('article_likes', 'article_comments', 'article_shares')
    AND table_schema = 'public';

-- 檢查索引是否創建成功
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes 
WHERE tablename IN ('article_likes', 'article_comments', 'article_shares')
ORDER BY tablename, indexname;

COMMIT;

-- =====================================================
-- 使用說明
-- =====================================================

/*
執行順序：
1. 確保 articles 表和 investment_groups 表已存在
2. 確保 auth.users 表可用（Supabase 自動創建）
3. 執行此 SQL 腳本
4. 驗證表結構和權限設置
5. 測試 iOS 應用的互動功能

注意事項：
- 所有表都啟用了行級安全 (RLS)
- 用戶只能操作自己的按讚、留言和分享記錄
- 有適當的外鍵約束確保數據完整性
- 創建了索引以優化查詢性能
- article_comments 表有自動更新 updated_at 的觸發器

性能優化：
- 使用了複合索引和單列索引
- 創建了統計視圖用於快速獲取互動數據
- 設置了適當的約束條件避免重複數據
*/