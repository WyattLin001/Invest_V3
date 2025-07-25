-- =====================================================
-- 逐步創建文章互動系統表結構
-- 創建日期: 2025-07-23
-- 目的: 按順序創建所有必要的表，避免依賴關係錯誤
-- =====================================================

-- 開始事務
BEGIN;

-- =====================================================
-- 步驟 1: 檢查並創建前置依賴表
-- =====================================================

-- 檢查 articles 表是否存在，如果不存在則創建基本結構
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'articles' AND table_schema = 'public') THEN
        RAISE NOTICE '創建 articles 表...';
        CREATE TABLE articles (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            author_id UUID REFERENCES auth.users(id),
            summary TEXT NOT NULL,
            full_content TEXT NOT NULL,
            body_md TEXT,
            category TEXT NOT NULL DEFAULT '投資分析',
            read_time TEXT DEFAULT '5 分鐘',
            likes_count INTEGER DEFAULT 0,
            comments_count INTEGER DEFAULT 0,
            shares_count INTEGER DEFAULT 0,
            is_free BOOLEAN DEFAULT true,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            keywords TEXT[] DEFAULT '{}'
        );
        
        -- 啟用 RLS
        ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
        
        -- 基本策略：所有人都可以查看文章
        CREATE POLICY "Anyone can view articles" ON articles FOR SELECT USING (true);
        
        RAISE NOTICE '✅ articles 表已創建';
    ELSE
        RAISE NOTICE '✅ articles 表已存在';
    END IF;
END $$;

-- 檢查 investment_groups 表是否存在，如果不存在則創建基本結構
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'investment_groups' AND table_schema = 'public') THEN
        RAISE NOTICE '創建 investment_groups 表...';
        CREATE TABLE investment_groups (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            name TEXT NOT NULL,
            description TEXT,
            host_id UUID NOT NULL REFERENCES auth.users(id),
            host_name TEXT NOT NULL,
            is_premium BOOLEAN DEFAULT false,
            monthly_fee DECIMAL(10,2) DEFAULT 0,
            member_count INTEGER DEFAULT 0,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- 啟用 RLS
        ALTER TABLE investment_groups ENABLE ROW LEVEL SECURITY;
        
        -- 基本策略：所有人都可以查看群組
        CREATE POLICY "Anyone can view groups" ON investment_groups FOR SELECT USING (true);
        
        RAISE NOTICE '✅ investment_groups 表已創建';
    ELSE
        RAISE NOTICE '✅ investment_groups 表已存在';
    END IF;
END $$;

-- =====================================================
-- 步驟 2: 創建文章按讚表
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_likes' AND table_schema = 'public') THEN
        RAISE NOTICE '創建 article_likes 表...';
        
        CREATE TABLE article_likes (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            user_name TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            
            -- 確保同一用戶對同一文章只能按讚一次
            UNIQUE(article_id, user_id)
        );
        
        -- 創建索引
        CREATE INDEX idx_article_likes_article_id ON article_likes(article_id);
        CREATE INDEX idx_article_likes_user_id ON article_likes(user_id);
        CREATE INDEX idx_article_likes_created_at ON article_likes(created_at);
        
        -- 啟用 RLS
        ALTER TABLE article_likes ENABLE ROW LEVEL SECURITY;
        
        RAISE NOTICE '✅ article_likes 表已創建';
    ELSE
        RAISE NOTICE '✅ article_likes 表已存在';
    END IF;
END $$;

-- =====================================================
-- 步驟 3: 創建文章留言表
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_comments' AND table_schema = 'public') THEN
        RAISE NOTICE '創建 article_comments 表...';
        
        CREATE TABLE article_comments (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            user_name TEXT NOT NULL,
            content TEXT NOT NULL CHECK (length(trim(content)) > 0),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- 創建索引
        CREATE INDEX idx_article_comments_article_id ON article_comments(article_id);
        CREATE INDEX idx_article_comments_user_id ON article_comments(user_id);
        CREATE INDEX idx_article_comments_created_at ON article_comments(created_at DESC);
        
        -- 啟用 RLS
        ALTER TABLE article_comments ENABLE ROW LEVEL SECURITY;
        
        RAISE NOTICE '✅ article_comments 表已創建';
    ELSE
        RAISE NOTICE '✅ article_comments 表已存在';
    END IF;
END $$;

-- =====================================================
-- 步驟 4: 創建文章分享表
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_shares' AND table_schema = 'public') THEN
        RAISE NOTICE '創建 article_shares 表...';
        
        CREATE TABLE article_shares (
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
        
        -- 創建索引
        CREATE INDEX idx_article_shares_article_id ON article_shares(article_id);
        CREATE INDEX idx_article_shares_user_id ON article_shares(user_id);
        CREATE INDEX idx_article_shares_group_id ON article_shares(group_id);
        CREATE INDEX idx_article_shares_created_at ON article_shares(created_at);
        
        -- 啟用 RLS
        ALTER TABLE article_shares ENABLE ROW LEVEL SECURITY;
        
        RAISE NOTICE '✅ article_shares 表已創建';
    ELSE
        RAISE NOTICE '✅ article_shares 表已存在';
    END IF;
END $$;

-- =====================================================
-- 步驟 5: 創建 RLS 策略
-- =====================================================

-- article_likes 策略
DROP POLICY IF EXISTS "Anyone can view article likes" ON article_likes;
DROP POLICY IF EXISTS "Users can insert own likes" ON article_likes;
DROP POLICY IF EXISTS "Users can delete own likes" ON article_likes;

CREATE POLICY "Anyone can view article likes" ON article_likes FOR SELECT USING (true);
CREATE POLICY "Users can insert own likes" ON article_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own likes" ON article_likes FOR DELETE USING (auth.uid() = user_id);

-- article_comments 策略
DROP POLICY IF EXISTS "Anyone can view article comments" ON article_comments;
DROP POLICY IF EXISTS "Users can insert own comments" ON article_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON article_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON article_comments;

CREATE POLICY "Anyone can view article comments" ON article_comments FOR SELECT USING (true);
CREATE POLICY "Users can insert own comments" ON article_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own comments" ON article_comments FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments" ON article_comments FOR DELETE USING (auth.uid() = user_id);

-- article_shares 策略
DROP POLICY IF EXISTS "Anyone can view article shares" ON article_shares;
DROP POLICY IF EXISTS "Users can insert own shares" ON article_shares;
DROP POLICY IF EXISTS "Users can delete own shares" ON article_shares;

CREATE POLICY "Anyone can view article shares" ON article_shares FOR SELECT USING (true);
CREATE POLICY "Users can insert own shares" ON article_shares FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own shares" ON article_shares FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 步驟 6: 創建觸發器函數和觸發器
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

-- =====================================================
-- 步驟 7: 創建統計視圖（只有在所有表都存在時才創建）
-- =====================================================

DO $$
BEGIN
    -- 檢查所有表是否都存在
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'articles' AND table_schema = 'public') AND
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_likes' AND table_schema = 'public') AND
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_comments' AND table_schema = 'public') AND
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_shares' AND table_schema = 'public') THEN
        
        RAISE NOTICE '創建統計視圖...';
        
        -- 刪除可能已存在的視圖
        DROP VIEW IF EXISTS article_interaction_stats;
        
        -- 創建統計視圖
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
        
        RAISE NOTICE '✅ 統計視圖已創建';
    ELSE
        RAISE NOTICE '⚠️ 部分表不存在，跳過統計視圖創建';
    END IF;
END $$;

-- =====================================================
-- 步驟 8: 最終驗證
-- =====================================================

-- 檢查所有表是否成功創建
SELECT 
    '=== 最終檢查結果 ===' as info;

SELECT 
    table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t.table_name AND table_schema = 'public') 
        THEN '✅ 已創建'
        ELSE '❌ 缺失'
    END as status
FROM (VALUES 
    ('articles'),
    ('investment_groups'),
    ('article_likes'),
    ('article_comments'),
    ('article_shares')
) AS t(table_name);

-- 檢查視圖
SELECT 
    'article_interaction_stats' as view_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'article_interaction_stats' AND table_schema = 'public') 
        THEN '✅ 已創建'
        ELSE '❌ 缺失'
    END as status;

-- 提交事務
COMMIT;

RAISE NOTICE '=== 創建完成 ===';
RAISE NOTICE '如果所有項目都顯示 ✅ 已創建，則表示數據庫結構創建成功';
RAISE NOTICE '可以開始測試 iOS 應用的文章互動功能';

-- =====================================================
-- 使用說明
-- =====================================================

/*
此腳本的特點：
1. 逐步檢查和創建所有必要的表
2. 自動創建缺失的依賴表 (articles, investment_groups)
3. 使用 DO 塊避免部分創建失敗
4. 包含完整的錯誤處理和狀態檢查
5. 只有在所有表都存在時才創建統計視圖

執行後請檢查：
- 所有表的狀態都是 ✅ 已創建
- 統計視圖狀態是 ✅ 已創建
- 沒有錯誤訊息

如果有錯誤：
- 檢查 auth.users 表是否存在（Supabase 自動提供）
- 檢查資料庫用戶權限
- 檢查 uuid_generate_v4() 函數是否可用
*/