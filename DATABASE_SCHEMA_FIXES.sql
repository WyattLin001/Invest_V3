-- =====================================================
-- 資料庫 Schema 修復腳本
-- 創建日期: 2025-07-23
-- 目的: 修正現有 schema 中的問題和缺失
-- =====================================================

-- 問題 1: article_comments 和 article_likes 缺少外鍵約束
-- 現有的表沒有引用 articles 表，這會導致數據完整性問題

-- 修復 article_comments 表
ALTER TABLE public.article_comments 
ADD CONSTRAINT article_comments_article_id_fkey 
FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;

ALTER TABLE public.article_comments 
ADD CONSTRAINT article_comments_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 修復 article_likes 表
ALTER TABLE public.article_likes 
ADD CONSTRAINT article_likes_article_id_fkey 
FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;

ALTER TABLE public.article_likes 
ADD CONSTRAINT article_likes_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 問題 2: article_likes 缺少 user_name 欄位
-- 根據 iOS 應用的需求，需要這個欄位來顯示按讚用戶名稱
ALTER TABLE public.article_likes 
ADD COLUMN user_name text NOT NULL DEFAULT '';

-- 問題 3: articles 表缺少重要欄位
-- 缺少 shares_count 和 keywords 欄位，這些在 iOS 應用中是必需的
ALTER TABLE public.articles 
ADD COLUMN shares_count integer DEFAULT 0;

ALTER TABLE public.articles 
ADD COLUMN keywords text[] DEFAULT '{}';

-- 問題 4: 添加缺少的唯一約束
-- 防止重複按讚
ALTER TABLE public.article_likes 
ADD CONSTRAINT article_likes_unique_user_article 
UNIQUE(article_id, user_id);

-- 問題 5: 添加缺少的索引來優化查詢性能
CREATE INDEX IF NOT EXISTS idx_article_likes_article_id ON public.article_likes(article_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_user_id ON public.article_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_article_likes_created_at ON public.article_likes(created_at);

CREATE INDEX IF NOT EXISTS idx_article_comments_article_id ON public.article_comments(article_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_user_id ON public.article_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_article_comments_created_at ON public.article_comments(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_article_shares_article_id ON public.article_shares(article_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_user_id ON public.article_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_group_id ON public.article_shares(group_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_created_at ON public.article_shares(created_at);

-- 問題 6: 添加 article_comments 表的 updated_at 欄位
-- 這在 iOS 應用中用於編輯留言功能
ALTER TABLE public.article_comments 
ADD COLUMN updated_at timestamp with time zone DEFAULT now();

-- 問題 7: 添加內容檢查約束
-- 確保留言內容不為空
ALTER TABLE public.article_comments 
ADD CONSTRAINT article_comments_content_check 
CHECK (length(trim(content)) > 0);

-- 問題 8: 創建 updated_at 觸發器
-- 為 article_comments 表添加自動更新 updated_at 的觸發器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language plpgsql;

DROP TRIGGER IF EXISTS update_article_comments_updated_at ON public.article_comments;
CREATE TRIGGER update_article_comments_updated_at
    BEFORE UPDATE ON public.article_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 問題 9: 修復 article_shares 表的約束
-- 確保同一用戶不會重複分享同一文章到同一群組
ALTER TABLE public.article_shares 
ADD CONSTRAINT article_shares_unique_user_article_group 
UNIQUE(article_id, user_id, group_id);

-- 問題 10: 添加 RLS 策略（如果還沒有的話）
-- 為文章互動表啟用行級安全

-- 檢查並啟用 RLS
ALTER TABLE public.article_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_shares ENABLE ROW LEVEL SECURITY;

-- 創建安全策略（先刪除可能存在的策略）
DROP POLICY IF EXISTS "Anyone can view article likes" ON public.article_likes;
DROP POLICY IF EXISTS "Users can insert own likes" ON public.article_likes;
DROP POLICY IF EXISTS "Users can delete own likes" ON public.article_likes;

CREATE POLICY "Anyone can view article likes" ON public.article_likes FOR SELECT USING (true);
CREATE POLICY "Users can insert own likes" ON public.article_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own likes" ON public.article_likes FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view article comments" ON public.article_comments;
DROP POLICY IF EXISTS "Users can insert own comments" ON public.article_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON public.article_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.article_comments;

CREATE POLICY "Anyone can view article comments" ON public.article_comments FOR SELECT USING (true);
CREATE POLICY "Users can insert own comments" ON public.article_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own comments" ON public.article_comments FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments" ON public.article_comments FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view article shares" ON public.article_shares;
DROP POLICY IF EXISTS "Users can insert own shares" ON public.article_shares;
DROP POLICY IF EXISTS "Users can delete own shares" ON public.article_shares;

CREATE POLICY "Anyone can view article shares" ON public.article_shares FOR SELECT USING (true);
CREATE POLICY "Users can insert own shares" ON public.article_shares FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own shares" ON public.article_shares FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 驗證修復結果
-- =====================================================

-- 檢查外鍵約束
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN ('article_likes', 'article_comments', 'article_shares')
ORDER BY tc.table_name, tc.constraint_name;

-- 檢查唯一約束
SELECT 
    tc.table_name,
    tc.constraint_name,
    array_agg(kcu.column_name ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
    AND tc.table_name IN ('article_likes', 'article_comments', 'article_shares')
GROUP BY tc.table_name, tc.constraint_name
ORDER BY tc.table_name;

-- 檢查索引
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('article_likes', 'article_comments', 'article_shares')
    AND schemaname = 'public'
ORDER BY tablename, indexname;

-- 檢查新增的欄位
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public'
    AND table_name IN ('articles', 'article_likes', 'article_comments')
    AND column_name IN ('shares_count', 'keywords', 'user_name', 'updated_at')
ORDER BY table_name, column_name;

COMMIT;

-- =====================================================
-- 修復說明
-- =====================================================

/*
主要修復內容：

1. ✅ 添加缺少的外鍵約束
   - article_likes -> articles
   - article_comments -> articles  
   - 確保引用完整性

2. ✅ 添加缺少的欄位
   - articles.shares_count (分享數量)
   - articles.keywords (關鍵字陣列)
   - article_likes.user_name (按讚用戶名稱)
   - article_comments.updated_at (留言更新時間)

3. ✅ 添加唯一約束
   - 防止重複按讚
   - 防止重複分享到同一群組

4. ✅ 優化索引
   - 提高查詢性能
   - 支援排序和篩選

5. ✅ 完善 RLS 策略
   - 確保數據安全
   - 用戶只能操作自己的數據

6. ✅ 添加觸發器
   - 自動更新 updated_at 欄位

執行後請檢查：
- 所有外鍵約束都已創建
- 新欄位都已添加
- 索引創建成功
- RLS 策略正常運作
*/