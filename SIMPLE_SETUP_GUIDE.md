# 🚀 Supabase 簡單設定指南

## ⚠️ **重要：請按順序執行以下步驟**

### 步驟 1: 手動創建儲存桶
1. 前往 Supabase 控制台 → Storage
2. 點擊 "New bucket"
3. 輸入名稱：`article-images`
4. 勾選 "Public bucket"
5. 點擊 "Create bucket"

### 步驟 2: 設定政策（使用簡化 SQL）

在 Supabase SQL Editor 中**分別執行**以下 SQL：

#### A. 刪除舊政策（如果有）
```sql
DROP POLICY IF EXISTS "Allow authenticated users to upload images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access to images" ON storage.objects;
```

#### B. 創建上傳政策
```sql
CREATE POLICY "Allow authenticated users to upload images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'article-images');
```

#### C. 創建讀取政策
```sql
CREATE POLICY "Allow public read access to images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'article-images');
```

#### D. 啟用 RLS
```sql
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
```

### 步驟 3: 驗證設定
執行此 SQL 檢查政策是否正確：
```sql
SELECT policyname, cmd, roles 
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND (qual LIKE '%article-images%' OR with_check LIKE '%article-images%');
```

### 步驟 4: 測試上傳
1. 運行您的 iOS 應用
2. 登入用戶帳號
3. 嘗試上傳圖片
4. 檢查 Xcode 控制台日誌

## ✅ 成功標準
- 儲存桶 `article-images` 已創建且為 public
- 至少 2 個政策已創建
- 應用能成功上傳圖片
- 圖片 URL 可正常訪問

## 🐛 如果還是有問題
請回報具體的錯誤訊息，我會進一步協助！