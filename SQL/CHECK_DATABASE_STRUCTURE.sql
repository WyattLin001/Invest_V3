-- =====================================================
-- 資料庫結構檢查腳本
-- 創建日期: 2025-07-23
-- 目的: 檢查文章互動系統相關的資料庫結構
-- =====================================================

-- 1. 檢查相關表是否存在
SELECT 
    '=== 檢查表結構 ===' as info;

SELECT 
    table_name,
    table_type,
    CASE 
        WHEN table_name IN ('article_likes', 'article_comments', 'article_shares') THEN '✅ 互動表'
        WHEN table_name = 'articles' THEN '✅ 主表'
        WHEN table_name = 'investment_groups' THEN '✅ 群組表'
        ELSE '📋 其他表'
    END as table_status
FROM information_schema.tables 
WHERE table_schema = 'public'
    AND table_name IN ('articles', 'investment_groups', 'article_likes', 'article_comments', 'article_shares')
ORDER BY 
    CASE 
        WHEN table_name = 'articles' THEN 1
        WHEN table_name = 'investment_groups' THEN 2
        WHEN table_name = 'article_likes' THEN 3
        WHEN table_name = 'article_comments' THEN 4
        WHEN table_name = 'article_shares' THEN 5
        ELSE 6
    END;

-- 2. 檢查表的列結構
SELECT 
    '=== 檢查列結構 ===' as info;

SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public'
    AND table_name IN ('article_likes', 'article_comments', 'article_shares')
ORDER BY table_name, ordinal_position;

-- 3. 檢查外鍵約束
SELECT 
    '=== 檢查外鍵約束 ===' as info;

SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN ('article_likes', 'article_comments', 'article_shares')
ORDER BY tc.table_name, tc.constraint_name;

-- 4. 檢查唯一約束
SELECT 
    '=== 檢查唯一約束 ===' as info;

SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    array_agg(kcu.column_name ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
    AND tc.table_name IN ('article_likes', 'article_comments', 'article_shares')
GROUP BY tc.table_name, tc.constraint_name, tc.constraint_type
ORDER BY tc.table_name;

-- 5. 檢查索引
SELECT 
    '=== 檢查索引 ===' as info;

SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('article_likes', 'article_comments', 'article_shares')
    AND schemaname = 'public'
ORDER BY tablename, indexname;

-- 6. 檢查RLS策略
SELECT 
    '=== 檢查RLS策略 ===' as info;

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
WHERE tablename IN ('article_likes', 'article_comments', 'article_shares')
ORDER BY tablename, policyname;

-- 7. 檢查觸發器
SELECT 
    '=== 檢查觸發器 ===' as info;

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('article_likes', 'article_comments', 'article_shares')
    AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 8. 檢查視圖
SELECT 
    '=== 檢查視圖 ===' as info;

SELECT 
    table_name,
    view_definition
FROM information_schema.views
WHERE table_schema = 'public'
    AND table_name LIKE '%article%interaction%'
ORDER BY table_name;

-- 9. 檢查函數
SELECT 
    '=== 檢查相關函數 ===' as info;

SELECT 
    routine_name,
    routine_type,
    data_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name LIKE '%update%updated%at%'
ORDER BY routine_name;

-- 10. 檢查表的行級安全狀態
SELECT 
    '=== 檢查RLS狀態 ===' as info;

SELECT 
    schemaname,
    tablename,
    rowsecurity,
    CASE 
        WHEN rowsecurity THEN '✅ RLS已啟用'
        ELSE '❌ RLS未啟用'
    END as rls_status
FROM pg_tables 
WHERE tablename IN ('article_likes', 'article_comments', 'article_shares')
    AND schemaname = 'public'
ORDER BY tablename;

-- 11. 統計現有數據量（如果表存在）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_likes' AND table_schema = 'public') THEN
        RAISE NOTICE '=== 數據統計 ===';
        EXECUTE 'SELECT ''article_likes: '' || COUNT(*) || '' 條記錄'' FROM article_likes';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_comments' AND table_schema = 'public') THEN
        EXECUTE 'SELECT ''article_comments: '' || COUNT(*) || '' 條記錄'' FROM article_comments';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'article_shares' AND table_schema = 'public') THEN
        EXECUTE 'SELECT ''article_shares: '' || COUNT(*) || '' 條記錄'' FROM article_shares';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '統計數據時發生錯誤: %', SQLERRM;
END $$;

-- 12. 檢查依賴表
SELECT 
    '=== 檢查依賴表狀態 ===' as info;

SELECT 
    table_name,
    CASE 
        WHEN table_name = 'articles' THEN '📰 文章主表'
        WHEN table_name = 'investment_groups' THEN '👥 投資群組表'
        WHEN table_name LIKE 'auth%users' THEN '👤 用戶認證表'
        ELSE '📋 其他表'
    END as table_purpose,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t.table_name AND table_schema = 'public') THEN '✅ 存在'
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t.table_name AND table_schema = 'auth') THEN '✅ 存在(auth schema)'
        ELSE '❌ 不存在'
    END as table_status
FROM (VALUES 
    ('articles'),
    ('investment_groups'),
    ('users')
) AS t(table_name);

-- =====================================================
-- 結果說明
-- =====================================================

SELECT 
    '=== 檢查完成 ===' as info,
    '請檢查上述輸出結果，確認所有必要的表、索引、策略都已正確創建' as instruction;

/*
檢查重點：
1. 確認 article_likes、article_comments、article_shares 三個表都存在
2. 確認外鍵約束指向正確的父表
3. 確認唯一約束防止重複記錄
4. 確認索引已創建用於查詢優化
5. 確認RLS策略已正確設置
6. 確認觸發器用於自動更新 updated_at
7. 確認統計視圖可用於快速查詢

如果發現問題：
- 缺少表：執行 CREATE_ARTICLE_INTERACTIONS_TABLES_FIXED.sql
- 缺少索引：單獨執行索引創建語句
- 缺少策略：單獨執行策略創建語句
- 父表不存在：先創建 articles 和 investment_groups 表
*/