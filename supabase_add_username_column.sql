-- 快速修復：添加缺少的 username 欄位和其他可能需要的欄位

-- 1. 添加 username 欄位
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS username TEXT;

-- 2. 為現有用戶填充 username（使用 display_name 作為 username）
UPDATE user_profiles 
SET username = display_name
WHERE username IS NULL;

-- 3. 為 test03 用戶確保所有必要欄位都存在
UPDATE user_profiles 
SET 
    username = 'test03',
    display_name = 'test03',
    email = 'test03@gmail.com',
    bio = '投資專家',
    investment_philosophy = '價值投資策略'
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b';

-- 4. 如果 test03 記錄不存在，則創建它
INSERT INTO user_profiles (
    user_id,
    username,
    display_name,
    email,
    bio,
    investment_philosophy
) VALUES (
    'be5f2785-741e-455c-8a94-2bb2b510f76b',
    'test03',
    'test03',
    'test03@gmail.com',
    '投資專家',
    '價值投資策略'
) ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    email = EXCLUDED.email,
    updated_at = now();

-- 5. 檢查並添加其他應用可能需要的常見欄位
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- 6. 為 test03 填充這些欄位
UPDATE user_profiles 
SET 
    first_name = 'Test',
    last_name = '03',
    full_name = 'Test 03',
    is_verified = true,
    status = 'active'
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b';

-- 7. 檢查最終的表結構
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_profiles'
ORDER BY ordinal_position;

-- 8. 驗證 test03 用戶的完整數據
SELECT 
    user_id,
    username,
    display_name,
    email,
    bio,
    investment_philosophy,
    first_name,
    last_name,
    full_name,
    is_verified,
    status
FROM user_profiles 
WHERE user_id = 'be5f2785-741e-455c-8a94-2bb2b510f76b';

-- 9. 確保其他用戶也有 username
UPDATE user_profiles 
SET username = display_name
WHERE username IS NULL OR username = '';

SELECT '✅ username 欄位已添加，test03 用戶數據已完整設置！' as status;