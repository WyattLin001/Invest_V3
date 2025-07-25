-- 修正後的 Supabase 設定 SQL
-- 請在 Supabase SQL Editor 中執行

-- 1. 確保儲存桶 'article-images' 已存在，若不存在則創建
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM storage.buckets 
        WHERE name = 'article-images'
    ) THEN
        INSERT INTO storage.buckets (id, name, public)
        VALUES ('article-images', 'article-images', true);
    END IF;
END $$;

-- 2. 刪除現有政策（避免衝突）
DROP POLICY IF EXISTS "Allow authenticated users to upload images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access to images" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own images" ON storage.objects;

-- 3. 創建政策：允許已驗證用戶上傳指定格式的圖片
CREATE POLICY "Allow authenticated users to upload images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'article-images' 
    AND (name ~* '\.(jpg|jpeg|png|gif|webp|tiff|bmp|heic)$')
);

-- 4. 創建政策：允許所有人查看圖片
CREATE POLICY "Allow public read access to images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'article-images');

-- 5. 創建政策：允許用戶刪除自己上傳的圖片
CREATE POLICY "Allow users to delete their own images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'article-images' AND auth.uid()::text = owner);

-- 6. 確保 RLS 已啟用
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 7. 驗證政策（查看結果）
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
ORDER BY policyname;