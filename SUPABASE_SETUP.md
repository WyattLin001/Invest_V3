# Supabase 儲存設定指南

## 圖片上傳設定

為了讓圖片上傳功能正常運作，您需要在 Supabase 中設置以下配置：

### 1. 創建儲存桶 (Storage Bucket)

1. 登入您的 Supabase 專案面板
2. 進入 "Storage" 頁面
3. 點擊 "Create bucket"
4. 創建名為 `article_images` 的儲存桶

### 2. 設定儲存桶權限 (Bucket Policies)

在 Supabase Storage 的 "Policies" 頁面，為 `article_images` 儲存桶新增以下政策：

#### 允許已驗證用戶上傳圖片：
```sql
-- Policy: 允許已驗證用戶上傳圖片
CREATE POLICY "Allow authenticated users to upload images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'article_images');
```

#### 允許所有人查看圖片：
```sql
-- Policy: 允許所有人查看圖片
CREATE POLICY "Allow public read access to images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'article_images');
```

#### 允許上傳者刪除自己的圖片：
```sql
-- Policy: 允許用戶刪除自己上傳的圖片
CREATE POLICY "Allow users to delete their own images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'article_images' AND auth.uid()::text = owner);
```

### 3. 驗證設定

完成設定後，您可以：
1. 在應用中測試圖片上傳功能
2. 檢查 Supabase Storage 面板中是否出現上傳的圖片
3. 確認圖片的公開 URL 可以正常訪問

### 4. 故障排除

如果圖片仍然無法上傳或顯示，請檢查：
- [ ] 儲存桶名稱是否正確為 `article_images`
- [ ] 用戶是否已正確驗證（登入）
- [ ] 政策是否正確設置
- [ ] 網路連接是否正常

### 5. 開發者設定

如果您是開發者，可以在 Supabase SQL Editor 中執行以下指令來快速設置：

```sql
-- 創建儲存桶（如果尚未存在）
INSERT INTO storage.buckets (id, name, public)
VALUES ('article_images', 'article_images', true)
ON CONFLICT (id) DO NOTHING;

-- 設置政策
CREATE POLICY IF NOT EXISTS "Allow authenticated users to upload images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'article_images');

CREATE POLICY IF NOT EXISTS "Allow public read access to images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'article_images');

CREATE POLICY IF NOT EXISTS "Allow users to delete their own images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'article_images' AND auth.uid()::text = owner);
```

完成後，您的應用就能夠正常上傳和顯示圖片了！