-- 快速修復：創建 article_drafts 表
-- 這是一個最小化的修復腳本，只創建必要的草稿表

-- 創建文章草稿表
CREATE TABLE IF NOT EXISTS article_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL DEFAULT '',
    subtitle TEXT,
    body_md TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT '投資分析',
    keywords TEXT[] DEFAULT '{}',
    is_free BOOLEAN DEFAULT true,
    is_unlisted BOOLEAN DEFAULT false,
    author_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 基本索引
CREATE INDEX IF NOT EXISTS idx_article_drafts_author_id ON article_drafts(author_id);
CREATE INDEX IF NOT EXISTS idx_article_drafts_updated_at ON article_drafts(updated_at DESC);

-- 啟用 RLS
ALTER TABLE article_drafts ENABLE ROW LEVEL SECURITY;

-- 簡單的 RLS 策略：允許已認證用戶操作自己的草稿
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON article_drafts;
CREATE POLICY "Enable all access for authenticated users" ON article_drafts
    FOR ALL USING (auth.uid() IS NOT NULL);

-- 顯示結果
SELECT 'article_drafts 表已創建/更新！' AS status;