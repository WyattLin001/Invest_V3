# Supabase 完整設定指南

## 📋 **檢查清單 - 必須在 Supabase 控制台完成**

### ⚠️ **重要提醒**
根據代碼分析，您的 Supabase 項目配置為：
- **URL**: `https://wujlbjrouqcpnifbakmw.supabase.co`
- **項目ID**: `wujlbjrouqcpnifbakmw`

請在 Supabase 控制台完成以下設定：

## 1. 圖片上傳設定

為了讓圖片上傳功能正常運作，您需要在 Supabase 中設置以下配置：

### 1. 創建儲存桶 (Storage Bucket)

1. 登入您的 Supabase 專案面板
2. 進入 "Storage" 頁面
3. 點擊 "Create bucket"
4. 創建名為 `article-images` 的儲存桶（注意：使用連字符 `-`，不是底線 `_`）
5. 確保 "Public bucket" 選項已啟用

### 2. 設定儲存桶權限 (Bucket Policies)

在 Supabase Storage 的 "Policies" 頁面，為 `article-images` 儲存桶新增以下政策：

#### 允許已驗證用戶上傳圖片：
**⚠️ 重要提醒：請使用您提供的 SQL，它已經包含了正確的設定和多格式支援！**

執行您提供的 SQL 代碼，它包含：
- 自動創建 `article-images` 儲存桶
- 支援多種圖片格式：.jpg, .jpeg, .png, .gif, .webp, .tiff, .bmp, .heic
- 正確的權限政策設定

您的 SQL 設定比我們的更完整，直接使用即可！

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

## 6. 資料庫表格檢查

請確認以下表格在您的 Supabase 資料庫中存在：

### 必要表格清單：
- [ ] `user_profiles` - 用戶資料
- [ ] `investment_groups` - 投資群組  
- [ ] `chat_messages` - 聊天訊息
- [ ] `creator_revenues` - 創作者收益
- [ ] `group_donations` - 群組捐贈
- [ ] `withdrawal_records` - 提領記錄

### 如果表格缺失，請在 SQL Editor 中執行：
```sql
-- 創建投資群組表格
CREATE TABLE IF NOT EXISTS investment_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    return_rate DECIMAL(5,2) DEFAULT 0.0,
    entry_fee TEXT,
    member_count INTEGER DEFAULT 1,
    category TEXT,
    created_at TEXT,
    updated_at TEXT
);

-- 創建用戶資料表格  
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    token_balance INTEGER DEFAULT 1000,
    total_earnings INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 啟用 RLS
ALTER TABLE investment_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 基本權限政策
CREATE POLICY "public_read_groups" ON investment_groups 
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "users_can_read_profiles" ON user_profiles 
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "users_can_update_own_profile" ON user_profiles 
    FOR UPDATE TO authenticated USING (auth.uid() = id);
```

## 7. 認證設定檢查

在 Authentication → Settings 中確認：
- [ ] Email 認證已啟用
- [ ] 確認 URL 已設置
- [ ] 密碼強度設定合適

## 8. 測試檢查清單

完成設定後，請測試以下功能：
- [ ] 用戶可以成功註冊/登入
- [ ] 圖片上傳功能正常運作
- [ ] Supabase Storage 中能看到上傳的圖片
- [ ] 文章發布功能正常
- [ ] 圖片在已發布文章中正常顯示

## 🚨 **立即行動項目**

1. **前往 Supabase 控制台**: https://supabase.com/dashboard/project/wujlbjrouqcpnifbakmw
2. **創建 article_images 儲存桶**
3. **設置儲存桶權限政策**
4. **確認資料庫表格完整性**

完成後，您的應用就能夠正常上傳和顯示圖片了！