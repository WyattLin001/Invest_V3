-- ============================================================================
-- 好友系統補充表格 - Invest_V3
-- ============================================================================

-- 1. 好友請求表（補充到現有的 friendships 表）
CREATE TABLE public.friend_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  from_user_name text NOT NULL,
  from_user_display_name text NOT NULL,
  from_user_avatar_url text,
  message text DEFAULT '想要加您為好友',
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'cancelled'::text])),
  request_date timestamp with time zone DEFAULT now(),
  response_date timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT friend_requests_pkey PRIMARY KEY (id),
  CONSTRAINT friend_requests_unique UNIQUE (from_user_id, to_user_id)
);

-- 2. 好友活動記錄表
CREATE TABLE public.friend_activities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  friend_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  friend_name text NOT NULL,
  activity_type text NOT NULL CHECK (activity_type = ANY (ARRAY['trade'::text, 'achievement'::text, 'milestone'::text, 'group_join'::text, 'tournament_join'::text])),
  description text NOT NULL,
  data jsonb DEFAULT '{}',
  timestamp timestamp with time zone DEFAULT now(),
  CONSTRAINT friend_activities_pkey PRIMARY KEY (id)
);

-- 3. 好友搜尋結果緩存表（可選，用於提升搜尋性能）
CREATE TABLE public.friend_search_cache (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  search_query text NOT NULL,
  results jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone DEFAULT (now() + INTERVAL '1 hour'),
  CONSTRAINT friend_search_cache_pkey PRIMARY KEY (id)
);

-- 4. 好友推薦表
CREATE TABLE public.friend_recommendations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  recommended_user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  recommendation_type text NOT NULL CHECK (recommendation_type = ANY (ARRAY['mutual_friends'::text, 'similar_interests'::text, 'same_groups'::text, 'location'::text, 'activity'::text])),
  score numeric NOT NULL DEFAULT 0,
  reason text,
  is_dismissed boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT friend_recommendations_pkey PRIMARY KEY (id),
  CONSTRAINT friend_recommendations_unique UNIQUE (user_id, recommended_user_id)
);

-- 5. 黑名單表
CREATE TABLE public.blocked_users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  reason text,
  blocked_at timestamp with time zone DEFAULT now(),
  CONSTRAINT blocked_users_pkey PRIMARY KEY (id),
  CONSTRAINT blocked_users_unique UNIQUE (blocker_id, blocked_id)
);

-- ============================================================================
-- 修改現有 friendships 表（如果需要）
-- ============================================================================

-- 為現有 friendships 表添加額外字段（如果沒有的話）
-- ALTER TABLE public.friendships ADD COLUMN IF NOT EXISTS friendship_date timestamp with time zone DEFAULT now();
-- ALTER TABLE public.friendships ADD COLUMN IF NOT EXISTS last_interaction timestamp with time zone DEFAULT now();

-- ============================================================================
-- 索引優化
-- ============================================================================

-- 好友請求索引
CREATE INDEX idx_friend_requests_to_user_id ON public.friend_requests(to_user_id);
CREATE INDEX idx_friend_requests_from_user_id ON public.friend_requests(from_user_id);
CREATE INDEX idx_friend_requests_status ON public.friend_requests(status);
CREATE INDEX idx_friend_requests_request_date ON public.friend_requests(request_date);

-- 好友活動索引
CREATE INDEX idx_friend_activities_friend_id ON public.friend_activities(friend_id);
CREATE INDEX idx_friend_activities_timestamp ON public.friend_activities(timestamp);
CREATE INDEX idx_friend_activities_type ON public.friend_activities(activity_type);

-- 好友推薦索引
CREATE INDEX idx_friend_recommendations_user_id ON public.friend_recommendations(user_id);
CREATE INDEX idx_friend_recommendations_score ON public.friend_recommendations(score DESC);
CREATE INDEX idx_friend_recommendations_dismissed ON public.friend_recommendations(is_dismissed);

-- 黑名單索引
CREATE INDEX idx_blocked_users_blocker_id ON public.blocked_users(blocker_id);
CREATE INDEX idx_blocked_users_blocked_id ON public.blocked_users(blocked_id);

-- 現有 friendships 表索引
CREATE INDEX IF NOT EXISTS idx_friendships_requester_id ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee_id ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);

-- ============================================================================
-- RLS (Row Level Security) 政策
-- ============================================================================

-- 啟用 RLS
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_search_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- 好友請求政策
CREATE POLICY "Users can view friend requests sent to them" ON public.friend_requests FOR SELECT
USING (to_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

CREATE POLICY "Users can view friend requests they sent" ON public.friend_requests FOR SELECT
USING (from_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

CREATE POLICY "Users can send friend requests" ON public.friend_requests FOR INSERT
WITH CHECK (from_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

CREATE POLICY "Users can update friend requests sent to them" ON public.friend_requests FOR UPDATE
USING (to_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 好友活動政策（只能查看好友的活動）
CREATE POLICY "Users can view friends activities" ON public.friend_activities FOR SELECT
USING (
  friend_id IN (
    SELECT CASE 
      WHEN requester_id = (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text) THEN addressee_id
      WHEN addressee_id = (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text) THEN requester_id
    END
    FROM public.friendships 
    WHERE status = 'accepted'
    AND (requester_id = (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text) 
         OR addressee_id = (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text))
  )
);

-- 搜尋緩存政策
CREATE POLICY "Users can manage own search cache" ON public.friend_search_cache FOR ALL
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 好友推薦政策
CREATE POLICY "Users can view own friend recommendations" ON public.friend_recommendations FOR ALL
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 黑名單政策
CREATE POLICY "Users can manage own blocked users" ON public.blocked_users FOR ALL
USING (blocker_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- ============================================================================
-- 觸發器和函數
-- ============================================================================

-- 自動接受好友請求時建立好友關係
CREATE OR REPLACE FUNCTION handle_friend_request_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  -- 當好友請求被接受時，建立雙向好友關係
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    -- 建立好友關係
    INSERT INTO public.friendships (requester_id, addressee_id, status, created_at, updated_at)
    VALUES (NEW.from_user_id, NEW.to_user_id, 'accepted', now(), now());
    
    -- 更新回應時間
    NEW.response_date = now();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_handle_friend_request_acceptance
  BEFORE UPDATE ON public.friend_requests
  FOR EACH ROW 
  EXECUTE FUNCTION handle_friend_request_acceptance();

-- 自動清理過期的搜尋緩存
CREATE OR REPLACE FUNCTION cleanup_expired_search_cache()
RETURNS void AS $$
BEGIN
  DELETE FROM public.friend_search_cache 
  WHERE expires_at < now();
END;
$$ LANGUAGE plpgsql;

-- 建立定期清理任務（需要 pg_cron 擴展）
-- SELECT cron.schedule('cleanup-search-cache', '0 * * * *', 'SELECT cleanup_expired_search_cache();');

-- 自動生成好友推薦
CREATE OR REPLACE FUNCTION generate_friend_recommendations(target_user_id uuid)
RETURNS void AS $$
BEGIN
  -- 清除舊的推薦
  DELETE FROM public.friend_recommendations WHERE user_id = target_user_id;
  
  -- 基於共同好友推薦
  INSERT INTO public.friend_recommendations (user_id, recommended_user_id, recommendation_type, score, reason)
  SELECT DISTINCT
    target_user_id,
    potential_friend.user_id,
    'mutual_friends',
    COUNT(*) * 10, -- 共同好友數 × 10 作為分數
    CONCAT('你們有 ', COUNT(*), ' 位共同好友')
  FROM (
    -- 獲取目標用戶的好友
    SELECT CASE 
      WHEN requester_id = target_user_id THEN addressee_id
      ELSE requester_id
    END as friend_id
    FROM public.friendships
    WHERE (requester_id = target_user_id OR addressee_id = target_user_id)
    AND status = 'accepted'
  ) user_friends
  JOIN (
    -- 獲取好友的好友
    SELECT 
      CASE 
        WHEN requester_id = user_friends.friend_id THEN addressee_id
        ELSE requester_id
      END as user_id,
      user_friends.friend_id as mutual_friend_id
    FROM public.friendships
    WHERE (requester_id = user_friends.friend_id OR addressee_id = user_friends.friend_id)
    AND status = 'accepted'
  ) potential_friend ON user_friends.friend_id = potential_friend.mutual_friend_id
  WHERE potential_friend.user_id != target_user_id
  AND potential_friend.user_id NOT IN (
    -- 排除已經是好友的用戶
    SELECT CASE 
      WHEN requester_id = target_user_id THEN addressee_id
      ELSE requester_id
    END
    FROM public.friendships
    WHERE (requester_id = target_user_id OR addressee_id = target_user_id)
    AND status = 'accepted'
  )
  AND potential_friend.user_id NOT IN (
    -- 排除已發送好友請求的用戶
    SELECT to_user_id FROM public.friend_requests 
    WHERE from_user_id = target_user_id AND status = 'pending'
  )
  AND potential_friend.user_id NOT IN (
    -- 排除黑名單用戶
    SELECT blocked_id FROM public.blocked_users WHERE blocker_id = target_user_id
  )
  GROUP BY potential_friend.user_id
  HAVING COUNT(*) >= 2 -- 至少有2個共同好友
  ORDER BY COUNT(*) DESC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 初始數據和測試數據
-- ============================================================================

-- 插入一些測試好友請求（可選）
-- INSERT INTO public.friend_requests (from_user_id, to_user_id, from_user_name, from_user_display_name, message) 
-- SELECT 
--   (SELECT id FROM public.user_profiles WHERE username = 'test01'),
--   (SELECT id FROM public.user_profiles WHERE username = 'test02'),
--   'test01',
--   'Test User 1',
--   '嗨！我想和您成為投資夥伴，一起學習交流！'
-- WHERE EXISTS (SELECT 1 FROM public.user_profiles WHERE username = 'test01')
-- AND EXISTS (SELECT 1 FROM public.user_profiles WHERE username = 'test02');