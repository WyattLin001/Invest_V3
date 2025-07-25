-- 安全的 Supabase Storage 設置腳本
-- 檢查現有配置並只創建缺失的部分

-- ========================================
-- 第1步：檢查現有 Buckets
-- ========================================

-- 查看現有的 Storage Buckets
SELECT 'Current buckets:' as info;
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id IN ('avatars', 'article-images', 'group-avatars');

-- ========================================
-- 第2步：安全創建 Buckets（只創建不存在的）
-- ========================================

-- 1. 創建用戶頭像存儲桶（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'avatars') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'avatars', 
            'avatars', 
            true, 
            5242880, -- 5MB
            ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
        );
        RAISE NOTICE 'Created avatars bucket';
    ELSE
        RAISE NOTICE 'avatars bucket already exists';
    END IF;
END $$;

-- 2. 檢查並更新 article-images bucket 配置（如果存在）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'article-images') THEN
        -- 更新現有 bucket 的配置
        UPDATE storage.buckets 
        SET 
            file_size_limit = 10485760, -- 10MB
            allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/tiff', 'image/bmp']
        WHERE id = 'article-images';
        RAISE NOTICE 'Updated article-images bucket configuration';
    ELSE
        -- 創建新的 bucket
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'article-images', 
            'article-images', 
            true, 
            10485760, -- 10MB
            ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/tiff', 'image/bmp']
        );
        RAISE NOTICE 'Created article-images bucket';
    END IF;
END $$;

-- 3. 創建群組頭像存儲桶（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'group-avatars') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'group-avatars', 
            'group-avatars', 
            true, 
            3145728, -- 3MB
            ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
        );
        RAISE NOTICE 'Created group-avatars bucket';
    ELSE
        RAISE NOTICE 'group-avatars bucket already exists';
    END IF;
END $$;

-- ========================================
-- 第3步：安全設定 RLS 策略
-- ========================================

-- 刪除可能重複的策略
DROP POLICY IF EXISTS "Public Avatar Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Avatar Upload" ON storage.objects;
DROP POLICY IF EXISTS "User Avatar Update" ON storage.objects;
DROP POLICY IF EXISTS "User Avatar Delete" ON storage.objects;

DROP POLICY IF EXISTS "Public Article Image Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Article Image Upload" ON storage.objects;
DROP POLICY IF EXISTS "Author Article Image Update" ON storage.objects;
DROP POLICY IF EXISTS "Author Article Image Delete" ON storage.objects;

DROP POLICY IF EXISTS "Public Group Avatar Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Group Avatar Upload" ON storage.objects;
DROP POLICY IF EXISTS "Group Creator Avatar Update" ON storage.objects;
DROP POLICY IF EXISTS "Group Creator Avatar Delete" ON storage.objects;

-- 用戶頭像 RLS 策略
CREATE POLICY "Public Avatar Access" ON storage.objects FOR SELECT 
USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated Avatar Upload" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
);

CREATE POLICY "User Avatar Update" ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

CREATE POLICY "User Avatar Delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- 文章圖片 RLS 策略
CREATE POLICY "Public Article Image Access" ON storage.objects FOR SELECT 
USING (bucket_id = 'article-images');

CREATE POLICY "Authenticated Article Image Upload" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'article-images' 
    AND auth.role() = 'authenticated'
);

CREATE POLICY "Author Article Image Update" ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'article-images' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

CREATE POLICY "Author Article Image Delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'article-images' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- 群組頭像 RLS 策略
CREATE POLICY "Public Group Avatar Access" ON storage.objects FOR SELECT 
USING (bucket_id = 'group-avatars');

CREATE POLICY "Authenticated Group Avatar Upload" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'group-avatars' 
    AND auth.role() = 'authenticated'
);

CREATE POLICY "Group Creator Avatar Update" ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'group-avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

CREATE POLICY "Group Creator Avatar Delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'group-avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- ========================================
-- 第4步：檢查 article_drafts 表
-- ========================================

-- 檢查 article_drafts 表是否存在並添加缺失的約束
DO $$
BEGIN
    -- 檢查表是否存在
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_drafts') THEN
        RAISE NOTICE 'article_drafts table already exists';
        
        -- 檢查並添加外鍵約束（如果不存在）
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_article_drafts_author' 
            AND table_name = 'article_drafts'
        ) THEN
            -- 嘗試添加外鍵約束
            BEGIN
                ALTER TABLE article_drafts 
                ADD CONSTRAINT fk_article_drafts_author 
                FOREIGN KEY (author_id) 
                REFERENCES user_profiles(id) 
                ON DELETE CASCADE;
                RAISE NOTICE 'Added foreign key constraint to article_drafts';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Could not add foreign key constraint: %', SQLERRM;
            END;
        END IF;
        
    ELSE
        RAISE NOTICE 'article_drafts table does not exist - run QUICK_FIX_DRAFTS_TABLE.sql first';
    END IF;
END $$;

-- ========================================
-- 第5步：創建索引（如果不存在）
-- ========================================

-- article_drafts 表索引
CREATE INDEX IF NOT EXISTS idx_article_drafts_author_id ON article_drafts(author_id);
CREATE INDEX IF NOT EXISTS idx_article_drafts_updated_at ON article_drafts(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_article_drafts_category ON article_drafts(category);

-- ========================================
-- 第6步：最終檢查
-- ========================================

-- 顯示最終配置
SELECT 'Final bucket configuration:' as info;
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id IN ('avatars', 'article-images', 'group-avatars')
ORDER BY id;

-- 檢查 RLS 策略
SELECT 'RLS policies:' as info;
SELECT schemaname, tablename, policyname, permissive, cmd 
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%Avatar%' OR policyname LIKE '%Article%'
ORDER BY policyname;

-- 檢查 article_drafts 表
SELECT 'article_drafts table status:' as info;
SELECT 
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'article_drafts') as table_exists,
    EXISTS(SELECT 1 FROM information_schema.table_constraints 
           WHERE constraint_name = 'fk_article_drafts_author' 
           AND table_name = 'article_drafts') as foreign_key_exists;

NOTIFY storage_setup_complete, 'Safe storage setup completed successfully!';