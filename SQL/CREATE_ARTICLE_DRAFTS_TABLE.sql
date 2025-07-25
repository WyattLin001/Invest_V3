-- 創建文章草稿表 (article_drafts)
-- 用於存儲用戶的文章草稿

-- 檢查表是否已存在，如果存在則先刪除
DROP TABLE IF EXISTS article_drafts CASCADE;

-- 創建文章草稿表
CREATE TABLE article_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL DEFAULT '',
    subtitle TEXT,
    body_md TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT '投資分析',
    keywords TEXT[] DEFAULT '{}',
    slug TEXT DEFAULT '',
    is_free BOOLEAN DEFAULT true,
    is_unlisted BOOLEAN DEFAULT false,
    author_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    -- 外鍵約束：關聯到 user_profiles 表
    CONSTRAINT fk_article_drafts_author 
        FOREIGN KEY (author_id) 
        REFERENCES user_profiles(id) 
        ON DELETE CASCADE
);

-- 創建索引以提高查詢性能
CREATE INDEX idx_article_drafts_author_id ON article_drafts(author_id);
CREATE INDEX idx_article_drafts_updated_at ON article_drafts(updated_at DESC);
CREATE INDEX idx_article_drafts_category ON article_drafts(category);

-- 設置 RLS (Row Level Security)
ALTER TABLE article_drafts ENABLE ROW LEVEL SECURITY;

-- 創建 RLS 策略：用戶只能查看和編輯自己的草稿
CREATE POLICY "Users can view their own drafts" ON article_drafts
    FOR SELECT USING (
        author_id IN (
            SELECT id FROM user_profiles 
            WHERE id = (
                SELECT up.id FROM user_profiles up 
                WHERE up.id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can insert their own drafts" ON article_drafts
    FOR INSERT WITH CHECK (
        author_id IN (
            SELECT id FROM user_profiles 
            WHERE id = (
                SELECT up.id FROM user_profiles up 
                WHERE up.id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can update their own drafts" ON article_drafts
    FOR UPDATE USING (
        author_id IN (
            SELECT id FROM user_profiles 
            WHERE id = (
                SELECT up.id FROM user_profiles up 
                WHERE up.id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can delete their own drafts" ON article_drafts
    FOR DELETE USING (
        author_id IN (
            SELECT id FROM user_profiles 
            WHERE id = (
                SELECT up.id FROM user_profiles up 
                WHERE up.id = auth.uid()
            )
        )
    );

-- 創建觸發器來自動更新 updated_at 欄位
CREATE OR REPLACE FUNCTION update_article_drafts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_article_drafts_updated_at
    BEFORE UPDATE ON article_drafts
    FOR EACH ROW
    EXECUTE FUNCTION update_article_drafts_updated_at();

-- 插入一些測試數據（可選）
-- 注意：這需要 user_profiles 表中有對應的用戶數據
/*
INSERT INTO article_drafts (title, subtitle, body_md, category, keywords, author_id) 
VALUES 
    ('測試草稿 1', '這是一個測試草稿', '# 測試內容\n\n這是測試草稿的內容。', '投資分析', ARRAY['測試', '草稿'], 
     (SELECT id FROM user_profiles LIMIT 1)),
    ('投資心得草稿', '我的投資經驗分享', '## 投資心得\n\n分享一些投資經驗...', '投資心得', ARRAY['投資', '經驗', '分享'], 
     (SELECT id FROM user_profiles LIMIT 1));
*/

-- 顯示創建結果
SELECT 'article_drafts 表創建成功！' AS result;

-- 檢查表結構
\d article_drafts;