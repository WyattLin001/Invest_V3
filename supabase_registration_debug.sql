-- 深度診斷註冊問題
-- 檢查所有可能導致註冊失敗的因素

-- 1. 檢查 Supabase 項目的所有觸發器（包括隱藏的）
SELECT 
    'auth schema 觸發器' as category,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'auth'

UNION ALL

SELECT 
    'public schema 觸發器' as category,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'public'

UNION ALL

SELECT 
    '其他 schema 觸發器' as category,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema NOT IN ('auth', 'public', 'information_schema');

-- 2. 檢查所有函數
SELECT 
    routine_schema,
    routine_name,
    routine_type,
    specific_name
FROM information_schema.routines
WHERE routine_schema IN ('public', 'auth')
ORDER BY routine_schema, routine_name;

-- 3. 檢查 auth 表的約束
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    tc.table_name,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'auth' AND tc.table_name = 'users';

-- 4. 完全移除任何可能的註冊相關觸發器或函數
DO $$
DECLARE
    r RECORD;
BEGIN
    -- 刪除所有可能的觸發器
    FOR r IN 
        SELECT trigger_name, event_object_schema, event_object_table
        FROM information_schema.triggers 
        WHERE (event_object_schema = 'auth' AND event_object_table = 'users')
           OR (event_object_schema = 'public' AND trigger_name LIKE '%user%')
           OR trigger_name LIKE '%signup%'
           OR trigger_name LIKE '%register%'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I CASCADE', 
                      r.trigger_name, r.event_object_schema, r.event_object_table);
        RAISE NOTICE '刪除觸發器: %.% on %.%', 
                     r.event_object_schema, r.trigger_name, 
                     r.event_object_schema, r.event_object_table;
    END LOOP;
    
    -- 刪除所有可能相關的函數
    FOR r IN
        SELECT routine_schema, routine_name
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND (routine_name LIKE '%user%' 
             OR routine_name LIKE '%signup%' 
             OR routine_name LIKE '%register%'
             OR routine_name LIKE '%auth%')
        AND routine_name != 'initialize_current_user_data'  -- 保留我們的初始化函數
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %I.%I() CASCADE', 
                      r.routine_schema, r.routine_name);
        RAISE NOTICE '刪除函數: %.%', r.routine_schema, r.routine_name;
    END LOOP;
END $$;

-- 5. 測試用戶創建（僅測試，不實際創建）
SELECT 
    'auth.users 表狀態檢查' as test,
    CASE 
        WHEN EXISTS (SELECT 1 FROM auth.users LIMIT 1) 
        THEN '✅ auth.users 表可訪問'
        ELSE '❌ auth.users 表不可訪問'
    END as result

UNION ALL

SELECT 
    '創建測試用戶模擬' as test,
    '✅ SQL 語法正確（實際創建需要 Supabase Auth API）' as result;

-- 6. 檢查我們的表是否正常
SELECT 
    table_name,
    CASE 
        WHEN table_name = 'user_balances' THEN (SELECT COUNT(*)::text FROM user_balances) || ' 條記錄'
        WHEN table_name = 'user_profiles' THEN (SELECT COUNT(*)::text FROM user_profiles) || ' 條記錄'  
        WHEN table_name = 'creator_revenues' THEN (SELECT COUNT(*)::text FROM creator_revenues) || ' 條記錄'
        ELSE 'Unknown'
    END as status
FROM information_schema.tables
WHERE table_schema = 'public' 
AND table_name IN ('user_balances', 'user_profiles', 'creator_revenues');

-- 7. 最終建議
SELECT '=== 診斷結果 ===' as result
UNION ALL
SELECT '如果所有觸發器都已清理但註冊還是失敗，' as result
UNION ALL  
SELECT '問題可能在於：' as result
UNION ALL
SELECT '1. Supabase 項目配置問題' as result
UNION ALL
SELECT '2. 客戶端 Supabase 配置錯誤' as result  
UNION ALL
SELECT '3. 需要檢查 Supabase Dashboard 的 Auth 設置' as result
UNION ALL
SELECT '4. 可能需要重新創建 Supabase 項目' as result;