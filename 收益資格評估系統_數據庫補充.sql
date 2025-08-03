-- 收益資格評估系統 - 缺少的數據庫表格和函數
-- 執行此 SQL 以完成測試環境設置

-- 1. 作者資格狀態表
CREATE TABLE public.author_eligibility_status (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  is_eligible boolean NOT NULL DEFAULT false,
  last_90_days_articles integer NOT NULL DEFAULT 0,
  last_30_days_unique_readers integer NOT NULL DEFAULT 0,
  has_violations boolean NOT NULL DEFAULT false,
  has_wallet_setup boolean NOT NULL DEFAULT false,
  eligibility_score numeric NOT NULL DEFAULT 0,
  last_evaluated_at timestamp with time zone DEFAULT now(),
  next_evaluation_at timestamp with time zone DEFAULT (now() + interval '1 day'),
  notifications jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT author_eligibility_status_pkey PRIMARY KEY (id),
  CONSTRAINT author_eligibility_status_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.user_profiles(id),
  CONSTRAINT author_eligibility_status_author_id_unique UNIQUE (author_id)
);

-- 2. 用戶錢包餘額表 (與 user_balances 類似但用於測試)
CREATE TABLE public.user_wallet_balances (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
  withdrawable_amount integer NOT NULL DEFAULT 0 CHECK (withdrawable_amount >= 0),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_wallet_balances_pkey PRIMARY KEY (id),
  CONSTRAINT user_wallet_balances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id),
  CONSTRAINT user_wallet_balances_user_id_unique UNIQUE (user_id)
);

-- 3. 文章閱讀詳細記錄表 (用於追蹤閱讀行為)
CREATE TABLE public.article_read_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  article_id uuid NOT NULL,
  author_id uuid NOT NULL,
  reading_duration integer NOT NULL DEFAULT 0, -- 閱讀持續時間（秒）
  scroll_percentage numeric NOT NULL DEFAULT 0 CHECK (scroll_percentage >= 0 AND scroll_percentage <= 100),
  is_completed boolean NOT NULL DEFAULT false,
  reading_date date NOT NULL DEFAULT CURRENT_DATE,
  session_start timestamp with time zone DEFAULT now(),
  session_end timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT article_read_logs_pkey PRIMARY KEY (id),
  CONSTRAINT article_read_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id),
  CONSTRAINT article_read_logs_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id),
  CONSTRAINT article_read_logs_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.user_profiles(id)
);

-- 4. 創建索引以提高查詢性能
CREATE INDEX idx_author_eligibility_status_author_id ON public.author_eligibility_status(author_id);
CREATE INDEX idx_author_eligibility_status_last_evaluated ON public.author_eligibility_status(last_evaluated_at);
CREATE INDEX idx_user_wallet_balances_user_id ON public.user_wallet_balances(user_id);
CREATE INDEX idx_article_read_logs_author_id ON public.article_read_logs(author_id);
CREATE INDEX idx_article_read_logs_reading_date ON public.article_read_logs(reading_date);
CREATE INDEX idx_article_read_logs_user_article ON public.article_read_logs(user_id, article_id);

-- 5. 創建 RPC 函數：獲取作者閱讀分析數據
CREATE OR REPLACE FUNCTION public.get_author_reading_analytics(author_id uuid)
RETURNS TABLE(
  author_id uuid,
  total_articles integer,
  total_reads integer,
  unique_readers integer,
  last_30_days_unique_readers integer,
  last_90_days_articles integer,
  average_read_time numeric,
  completion_rate numeric,
  created_at timestamp with time zone
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  analytics_data RECORD;
  current_date_val date := CURRENT_DATE;
  thirty_days_ago date := current_date_val - INTERVAL '30 days';
  ninety_days_ago date := current_date_val - INTERVAL '90 days';
BEGIN
  -- 計算統計數據
  SELECT 
    COALESCE(COUNT(DISTINCT a.id), 0) as total_articles,
    COALESCE(COUNT(DISTINCT arl.id), 0) as total_reads,
    COALESCE(COUNT(DISTINCT arl.user_id), 0) as unique_readers,
    COALESCE(COUNT(DISTINCT CASE 
      WHEN arl.reading_date >= thirty_days_ago THEN arl.user_id 
      ELSE NULL 
    END), 0) as last_30_days_unique_readers,
    COALESCE(COUNT(DISTINCT CASE 
      WHEN a.created_at::date >= ninety_days_ago THEN a.id 
      ELSE NULL 
    END), 0) as last_90_days_articles,
    COALESCE(AVG(arl.reading_duration), 0) as average_read_time,
    COALESCE(
      CASE 
        WHEN COUNT(arl.id) > 0 THEN 
          (COUNT(CASE WHEN arl.is_completed THEN 1 ELSE NULL END)::numeric / COUNT(arl.id)::numeric) * 100
        ELSE 0 
      END, 0
    ) as completion_rate
  INTO analytics_data
  FROM public.user_profiles up
  LEFT JOIN public.articles a ON a.author_id = up.id
  LEFT JOIN public.article_read_logs arl ON arl.article_id = a.id
  WHERE up.id = get_author_reading_analytics.author_id;

  -- 返回結果
  RETURN QUERY
  SELECT 
    get_author_reading_analytics.author_id,
    analytics_data.total_articles,
    analytics_data.total_reads,
    analytics_data.unique_readers,
    analytics_data.last_30_days_unique_readers,
    analytics_data.last_90_days_articles,
    analytics_data.average_read_time,
    analytics_data.completion_rate,
    now();
END;
$$;

-- 6. 插入一些測試數據
INSERT INTO public.user_wallet_balances (user_id, balance, withdrawable_amount)
SELECT 
  id as user_id, 
  FLOOR(RANDOM() * 50000 + 10000)::integer as balance,
  FLOOR(RANDOM() * 20000 + 5000)::integer as withdrawable_amount
FROM public.user_profiles 
WHERE id IN (
  SELECT DISTINCT author_id 
  FROM public.articles 
  WHERE author_id IS NOT NULL
  LIMIT 10
)
ON CONFLICT (user_id) DO UPDATE SET
  balance = EXCLUDED.balance,
  withdrawable_amount = EXCLUDED.withdrawable_amount;

-- 7. 插入一些測試閱讀記錄
INSERT INTO public.article_read_logs (user_id, article_id, author_id, reading_duration, scroll_percentage, is_completed, reading_date)
SELECT 
  (SELECT id FROM public.user_profiles ORDER BY RANDOM() LIMIT 1) as user_id,
  a.id as article_id,
  a.author_id,
  FLOOR(RANDOM() * 300 + 30)::integer as reading_duration, -- 30-330秒
  RANDOM() * 100 as scroll_percentage,
  RANDOM() > 0.3 as is_completed, -- 70% 完成率
  CURRENT_DATE - FLOOR(RANDOM() * 30)::integer as reading_date -- 過去30天
FROM public.articles a
WHERE a.author_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.user_profiles WHERE id = a.author_id)
ORDER BY RANDOM()
LIMIT 200; -- 創建200條測試閱讀記錄

-- 8. 創建一些初始的作者資格狀態記錄
INSERT INTO public.author_eligibility_status (
  author_id, 
  is_eligible, 
  last_90_days_articles, 
  last_30_days_unique_readers, 
  has_violations, 
  has_wallet_setup, 
  eligibility_score
)
SELECT 
  DISTINCT a.author_id,
  CASE 
    WHEN COUNT(DISTINCT a.id) >= 1 
         AND COUNT(DISTINCT arl.user_id) >= 100 
         AND EXISTS (SELECT 1 FROM public.user_wallet_balances uwb WHERE uwb.user_id = a.author_id)
    THEN true 
    ELSE false 
  END as is_eligible,
  COUNT(DISTINCT a.id) as last_90_days_articles,
  COUNT(DISTINCT arl.user_id) as last_30_days_unique_readers,
  false as has_violations, -- 假設沒有違規
  EXISTS (SELECT 1 FROM public.user_wallet_balances uwb WHERE uwb.user_id = a.author_id) as has_wallet_setup,
  CASE 
    WHEN COUNT(DISTINCT a.id) >= 1 THEN 25.0 ELSE 0.0 END +
    CASE 
      WHEN COUNT(DISTINCT arl.user_id) >= 100 THEN 25.0 
      WHEN COUNT(DISTINCT arl.user_id) >= 50 THEN 15.0
      WHEN COUNT(DISTINCT arl.user_id) >= 10 THEN 5.0
      ELSE 0.0 
    END +
    25.0 + -- 無違規獎勵
    CASE 
      WHEN EXISTS (SELECT 1 FROM public.user_wallet_balances uwb WHERE uwb.user_id = a.author_id) THEN 25.0 
      ELSE 0.0 
    END as eligibility_score
FROM public.articles a
LEFT JOIN public.article_read_logs arl ON arl.article_id = a.id AND arl.reading_date >= CURRENT_DATE - INTERVAL '30 days'
WHERE a.author_id IS NOT NULL
  AND a.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY a.author_id
ON CONFLICT (author_id) DO UPDATE SET
  is_eligible = EXCLUDED.is_eligible,
  last_90_days_articles = EXCLUDED.last_90_days_articles,
  last_30_days_unique_readers = EXCLUDED.last_30_days_unique_readers,
  has_wallet_setup = EXCLUDED.has_wallet_setup,
  eligibility_score = EXCLUDED.eligibility_score,
  updated_at = now();

-- 9. 設置 RLS (Row Level Security) 政策
ALTER TABLE public.author_eligibility_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_wallet_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_read_logs ENABLE ROW LEVEL SECURITY;

-- 允許用戶查看自己的資格狀態
CREATE POLICY "Users can view own eligibility status" ON public.author_eligibility_status
  FOR SELECT USING (auth.uid() = author_id OR auth.role() = 'service_role');

-- 允許用戶查看自己的錢包餘額
CREATE POLICY "Users can view own wallet balance" ON public.user_wallet_balances
  FOR SELECT USING (auth.uid() = user_id OR auth.role() = 'service_role');

-- 允許創建閱讀記錄
CREATE POLICY "Users can create read logs" ON public.article_read_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

-- 允許查看閱讀記錄
CREATE POLICY "Users can view read logs" ON public.article_read_logs
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = author_id OR auth.role() = 'service_role');

-- 10. 創建觸發器來自動更新時間戳
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_author_eligibility_status_updated_at
  BEFORE UPDATE ON public.author_eligibility_status
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_user_wallet_balances_updated_at
  BEFORE UPDATE ON public.user_wallet_balances
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 完成！
SELECT 'Database setup completed successfully!' as status;