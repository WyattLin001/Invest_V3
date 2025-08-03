-- 測試數據初始化腳本
-- 為收益資格評估系統創建必要的測試數據

-- 1. 首先檢查現有數據
DO $$
BEGIN
    RAISE NOTICE '========== 數據庫測試環境初始化 ==========';
    RAISE NOTICE '檢查現有數據...';
    RAISE NOTICE '用戶數量: %', (SELECT COUNT(*) FROM public.user_profiles);
    RAISE NOTICE '文章數量: %', (SELECT COUNT(*) FROM public.articles);
    RAISE NOTICE '現有閱讀記錄: %', (SELECT COUNT(*) FROM public.article_read_logs);
    RAISE NOTICE '現有資格記錄: %', (SELECT COUNT(*) FROM public.author_eligibility_status);
END $$;

-- 2. 為現有用戶創建錢包餘額記錄（如果不存在）
INSERT INTO public.user_wallet_balances (user_id, balance, withdrawable_amount)
SELECT 
    id as user_id,
    FLOOR(RANDOM() * 50000 + 10000)::integer as balance,
    FLOOR(RANDOM() * 20000 + 5000)::integer as withdrawable_amount
FROM public.user_profiles 
WHERE id NOT IN (SELECT user_id FROM public.user_wallet_balances)
ON CONFLICT (user_id) DO NOTHING;

-- 3. 為現有文章創建閱讀記錄（模擬過去30天的閱讀活動）
WITH article_sample AS (
    SELECT 
        a.id as article_id,
        a.author_id,
        ROW_NUMBER() OVER (ORDER BY a.created_at DESC) as rn
    FROM public.articles a 
    WHERE a.author_id IS NOT NULL
    LIMIT 20  -- 只為前20篇文章創建測試數據
),
user_sample AS (
    SELECT 
        id as user_id,
        ROW_NUMBER() OVER (ORDER BY created_at) as rn
    FROM public.user_profiles 
    LIMIT 50  -- 使用前50個用戶
)
INSERT INTO public.article_read_logs (
    user_id, 
    article_id, 
    author_id, 
    reading_duration, 
    scroll_percentage, 
    is_completed, 
    reading_date,
    session_start,
    session_end
)
SELECT 
    u.user_id,
    a.article_id,
    a.author_id,
    FLOOR(RANDOM() * 300 + 30)::integer as reading_duration, -- 30-330秒
    ROUND((RANDOM() * 100)::numeric, 2) as scroll_percentage,
    RANDOM() > 0.3 as is_completed, -- 70% 完成率
    CURRENT_DATE - FLOOR(RANDOM() * 30)::integer as reading_date, -- 過去30天
    now() - (FLOOR(RANDOM() * 30)::text || ' days')::interval as session_start,
    now() - (FLOOR(RANDOM() * 30)::text || ' days')::interval + (FLOOR(RANDOM() * 300 + 30)::text || ' seconds')::interval as session_end
FROM article_sample a
CROSS JOIN user_sample u
WHERE RANDOM() > 0.7  -- 30% 的用戶會閱讀每篇文章
ON CONFLICT DO NOTHING;

-- 4. 為有文章的作者創建額外的閱讀記錄（確保有足夠的獨立讀者）
WITH active_authors AS (
    SELECT DISTINCT author_id, COUNT(*) as article_count
    FROM public.articles 
    WHERE author_id IS NOT NULL
    GROUP BY author_id
    HAVING COUNT(*) >= 1
    LIMIT 10
),
additional_readers AS (
    SELECT 
        id as user_id,
        ROW_NUMBER() OVER (ORDER BY RANDOM()) as rn
    FROM public.user_profiles
    LIMIT 120  -- 確保有足夠的獨立讀者
)
INSERT INTO public.article_read_logs (
    user_id, 
    article_id, 
    author_id, 
    reading_duration, 
    scroll_percentage, 
    is_completed, 
    reading_date
)
SELECT 
    ar.user_id,
    a.id as article_id,
    a.author_id,
    FLOOR(RANDOM() * 200 + 60)::integer as reading_duration,
    ROUND((RANDOM() * 40 + 60)::numeric, 2) as scroll_percentage, -- 60-100%
    RANDOM() > 0.2 as is_completed, -- 80% 完成率
    CURRENT_DATE - FLOOR(RANDOM() * 30)::integer as reading_date
FROM active_authors aa
JOIN public.articles a ON a.author_id = aa.author_id
CROSS JOIN additional_readers ar
WHERE ar.rn <= (aa.article_count * 15)  -- 每篇文章約15個額外讀者
AND RANDOM() > 0.4  -- 60% 的機率會創建記錄
ON CONFLICT DO NOTHING;

-- 5. 使用 RPC 函數為每個作者計算並插入資格狀態
DO $$
DECLARE
    author_record RECORD;
    analytics_result RECORD;
    eligibility_score NUMERIC;
    is_eligible BOOLEAN;
BEGIN
    RAISE NOTICE '開始計算作者資格狀態...';
    
    FOR author_record IN 
        SELECT DISTINCT author_id 
        FROM public.articles 
        WHERE author_id IS NOT NULL
    LOOP
        -- 調用 RPC 函數獲取分析數據
        SELECT * FROM public.get_author_reading_analytics(author_record.author_id) 
        INTO analytics_result;
        
        -- 計算資格分數
        eligibility_score := 0;
        
        -- 文章條件 (25分)
        IF analytics_result.last_90_days_articles >= 1 THEN
            eligibility_score := eligibility_score + 25;
        END IF;
        
        -- 讀者條件 (25分)
        IF analytics_result.last_30_days_unique_readers >= 100 THEN
            eligibility_score := eligibility_score + 25;
        ELSIF analytics_result.last_30_days_unique_readers >= 50 THEN
            eligibility_score := eligibility_score + 15;
        ELSIF analytics_result.last_30_days_unique_readers >= 10 THEN
            eligibility_score := eligibility_score + 5;
        END IF;
        
        -- 無違規條件 (25分) - 假設都沒有違規
        eligibility_score := eligibility_score + 25;
        
        -- 錢包設置條件 (25分)
        IF EXISTS (SELECT 1 FROM public.user_wallet_balances WHERE user_id = author_record.author_id) THEN
            eligibility_score := eligibility_score + 25;
        END IF;
        
        -- 判斷是否符合資格
        is_eligible := analytics_result.last_90_days_articles >= 1 
                      AND analytics_result.last_30_days_unique_readers >= 100 
                      AND EXISTS (SELECT 1 FROM public.user_wallet_balances WHERE user_id = author_record.author_id);
        
        -- 插入或更新資格狀態
        INSERT INTO public.author_eligibility_status (
            author_id,
            is_eligible,
            last_90_days_articles,
            last_30_days_unique_readers,
            has_violations,
            has_wallet_setup,
            eligibility_score,
            last_evaluated_at,
            next_evaluation_at
        )
        VALUES (
            author_record.author_id,
            is_eligible,
            analytics_result.last_90_days_articles,
            analytics_result.last_30_days_unique_readers,
            false, -- 假設沒有違規
            EXISTS (SELECT 1 FROM public.user_wallet_balances WHERE user_id = author_record.author_id),
            eligibility_score,
            now(),
            now() + interval '1 day'
        )
        ON CONFLICT (author_id) DO UPDATE SET
            is_eligible = EXCLUDED.is_eligible,
            last_90_days_articles = EXCLUDED.last_90_days_articles,
            last_30_days_unique_readers = EXCLUDED.last_30_days_unique_readers,
            has_wallet_setup = EXCLUDED.has_wallet_setup,
            eligibility_score = EXCLUDED.eligibility_score,
            last_evaluated_at = EXCLUDED.last_evaluated_at,
            next_evaluation_at = EXCLUDED.next_evaluation_at,
            updated_at = now();
            
        RAISE NOTICE '處理作者 %: 符合資格=%, 分數=%, 90天文章=%, 30天讀者=%', 
                    author_record.author_id, is_eligible, eligibility_score, 
                    analytics_result.last_90_days_articles, analytics_result.last_30_days_unique_readers;
    END LOOP;
END $$;

-- 6. 為符合資格的作者創建一些收益記錄
INSERT INTO public.creator_revenues (
    creator_id,
    revenue_type,
    amount,
    source_id,
    source_name,
    description
)
SELECT 
    aes.author_id,
    CASE 
        WHEN RANDOM() > 0.5 THEN 'subscription_share'
        ELSE 'reader_tip'
    END as revenue_type,
    FLOOR(RANDOM() * 500 + 100)::integer as amount,
    gen_random_uuid() as source_id,
    '測試收益來源' as source_name,
    '測試環境模擬收益' as description
FROM public.author_eligibility_status aes
WHERE aes.is_eligible = true
AND RANDOM() > 0.6  -- 40% 的符合資格作者會有收益記錄
ON CONFLICT DO NOTHING;

-- 7. 顯示最終統計
DO $$
BEGIN
    RAISE NOTICE '========== 測試數據初始化完成 ==========';
    RAISE NOTICE '總用戶數: %', (SELECT COUNT(*) FROM public.user_profiles);
    RAISE NOTICE '總文章數: %', (SELECT COUNT(*) FROM public.articles);
    RAISE NOTICE '總閱讀記錄: %', (SELECT COUNT(*) FROM public.article_read_logs);
    RAISE NOTICE '有錢包的用戶: %', (SELECT COUNT(*) FROM public.user_wallet_balances);
    RAISE NOTICE '作者資格記錄: %', (SELECT COUNT(*) FROM public.author_eligibility_status);
    RAISE NOTICE '符合資格的作者: %', (SELECT COUNT(*) FROM public.author_eligibility_status WHERE is_eligible = true);
    RAISE NOTICE '創作者收益記錄: %', (SELECT COUNT(*) FROM public.creator_revenues);
    RAISE NOTICE '==========================================';
END $$;

-- 8. 查詢一些示例數據以驗證
SELECT 
    up.username,
    aes.is_eligible,
    aes.last_90_days_articles,
    aes.last_30_days_unique_readers,
    aes.eligibility_score,
    aes.has_wallet_setup
FROM public.author_eligibility_status aes
JOIN public.user_profiles up ON up.id = aes.author_id
ORDER BY aes.eligibility_score DESC
LIMIT 10;