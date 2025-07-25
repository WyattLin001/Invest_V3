-- Supabase Storage 圖片上傳配置
-- 創建必要的 Storage Buckets 和 RLS 策略

-- ========================================
-- 第1步：創建 Storage Buckets
-- ========================================

-- 1. 創建用戶頭像存儲桶
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars', 
    'avatars', 
    true, 
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
);

-- 2. 創建文章圖片存儲桶
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'article-images', 
    'article-images', 
    true, 
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/tiff', 'image/bmp']
);

-- 3. 創建群組頭像存儲桶
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'group-avatars', 
    'group-avatars', 
    true, 
    3145728, -- 3MB
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
);

-- ========================================
-- 第2步：設定 RLS 策略
-- ========================================

-- 用戶頭像 RLS 策略
-- 1. 允許所有人查看頭像
CREATE POLICY "Public Avatar Access" ON storage.objects FOR SELECT 
USING (bucket_id = 'avatars');

-- 2. 只允許認證用戶上傳自己的頭像
CREATE POLICY "Authenticated Avatar Upload" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 3. 只允許用戶更新自己的頭像
CREATE POLICY "User Avatar Update" ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 4. 只允許用戶刪除自己的頭像
CREATE POLICY "User Avatar Delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 文章圖片 RLS 策略
-- 1. 允許所有人查看文章圖片
CREATE POLICY "Public Article Image Access" ON storage.objects FOR SELECT 
USING (bucket_id = 'article-images');

-- 2. 只允許認證用戶上傳文章圖片
CREATE POLICY "Authenticated Article Image Upload" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'article-images' 
    AND auth.role() = 'authenticated'
);

-- 3. 只允許上傳者更新自己的文章圖片
CREATE POLICY "Author Article Image Update" ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'article-images' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- 4. 只允許上傳者刪除自己的文章圖片
CREATE POLICY "Author Article Image Delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'article-images' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- 群組頭像 RLS 策略
-- 1. 允許所有人查看群組頭像
CREATE POLICY "Public Group Avatar Access" ON storage.objects FOR SELECT 
USING (bucket_id = 'group-avatars');

-- 2. 只允許認證用戶上傳群組頭像
CREATE POLICY "Authenticated Group Avatar Upload" ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'group-avatars' 
    AND auth.role() = 'authenticated'
);

-- 3. 只允許群組創建者更新群組頭像
CREATE POLICY "Group Creator Avatar Update" ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'group-avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- 4. 只允許群組創建者刪除群組頭像
CREATE POLICY "Group Creator Avatar Delete" ON storage.objects FOR DELETE 
USING (
    bucket_id = 'group-avatars' 
    AND auth.role() = 'authenticated'
    AND auth.uid() = owner
);

-- ========================================
-- 第3步：創建輔助函數
-- ========================================

-- 1. 清理過期的臨時圖片
CREATE OR REPLACE FUNCTION cleanup_old_images()
RETURNS void AS $$
BEGIN
    -- 刪除超過 30 天的未使用圖片
    DELETE FROM storage.objects 
    WHERE bucket_id IN ('avatars', 'article-images', 'group-avatars')
    AND created_at < NOW() - INTERVAL '30 days'
    AND metadata->>'referenced' IS NULL;
    
    RAISE NOTICE 'Cleaned up old unused images';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 獲取圖片統計信息
CREATE OR REPLACE FUNCTION get_storage_stats()
RETURNS TABLE(
    bucket_name text,
    file_count bigint,
    total_size_mb numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.name as bucket_name,
        COUNT(o.id) as file_count,
        ROUND((SUM(o.metadata->>'size')::bigint / 1024.0 / 1024.0)::numeric, 2) as total_size_mb
    FROM storage.buckets b
    LEFT JOIN storage.objects o ON b.id = o.bucket_id
    WHERE b.id IN ('avatars', 'article-images', 'group-avatars')
    GROUP BY b.name
    ORDER BY b.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 第4步：設定定時任務（可選）
-- ========================================

-- 創建定時清理任務（需要 pg_cron 擴展）
-- SELECT cron.schedule('cleanup-images', '0 2 * * *', 'SELECT cleanup_old_images();');

-- ========================================
-- 第5步：測試配置
-- ========================================

-- 查看創建的 buckets
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id IN ('avatars', 'article-images', 'group-avatars');

-- 查看 RLS 策略
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';

-- 查看存儲統計
-- SELECT * FROM get_storage_stats();

-- ========================================
-- 第6步：配置 CORS（在 Supabase Dashboard 中設置）
-- ========================================

-- 在 Supabase Dashboard > Settings > API 中添加 CORS 配置：
-- {
--   "allowedOrigins": ["*"],
--   "allowedMethods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
--   "allowedHeaders": ["authorization", "x-client-info", "apikey", "content-type"]
-- }

-- ========================================
-- 故障排除
-- ========================================

-- 如果遇到權限問題，檢查 RLS 策略：
-- SELECT * FROM pg_policies WHERE tablename = 'objects';

-- 如果上傳失敗，檢查 bucket 配置：
-- SELECT * FROM storage.buckets WHERE id = 'avatars';

-- 檢查用戶認證狀態：
-- SELECT auth.uid(), auth.role();

NOTIFY storage_setup_complete, 'Supabase Storage setup completed successfully!';