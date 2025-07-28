-- ============================================================================
-- 修復現有好友系統表格 - Invest_V3
-- ============================================================================
-- 此腳本用於修復已存在的好友系統表格，確保索引、RLS政策和觸發器正確設置

-- 1. 確保所有必要的索引都存在（只創建不存在的）
DO $$
BEGIN
    RAISE NOTICE '開始修復好友系統索引...';
    
    -- 好友請求索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_requests_to_user_id') THEN
        CREATE INDEX idx_friend_requests_to_user_id ON public.friend_requests(to_user_id);
        RAISE NOTICE '已創建 idx_friend_requests_to_user_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_requests_from_user_id') THEN
        CREATE INDEX idx_friend_requests_from_user_id ON public.friend_requests(from_user_id);
        RAISE NOTICE '已創建 idx_friend_requests_from_user_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_requests_status') THEN
        CREATE INDEX idx_friend_requests_status ON public.friend_requests(status);
        RAISE NOTICE '已創建 idx_friend_requests_status 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_requests_request_date') THEN
        CREATE INDEX idx_friend_requests_request_date ON public.friend_requests(request_date);
        RAISE NOTICE '已創建 idx_friend_requests_request_date 索引';
    END IF;
    
    -- 好友活動索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_activities_friend_id') THEN
        CREATE INDEX idx_friend_activities_friend_id ON public.friend_activities(friend_id);
        RAISE NOTICE '已創建 idx_friend_activities_friend_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_activities_timestamp') THEN
        CREATE INDEX idx_friend_activities_timestamp ON public.friend_activities(timestamp);
        RAISE NOTICE '已創建 idx_friend_activities_timestamp 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_activities_type') THEN
        CREATE INDEX idx_friend_activities_type ON public.friend_activities(activity_type);
        RAISE NOTICE '已創建 idx_friend_activities_type 索引';
    END IF;
    
    -- 好友推薦索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_recommendations_user_id') THEN
        CREATE INDEX idx_friend_recommendations_user_id ON public.friend_recommendations(user_id);
        RAISE NOTICE '已創建 idx_friend_recommendations_user_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_recommendations_score') THEN
        CREATE INDEX idx_friend_recommendations_score ON public.friend_recommendations(score DESC);
        RAISE NOTICE '已創建 idx_friend_recommendations_score 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friend_recommendations_dismissed') THEN
        CREATE INDEX idx_friend_recommendations_dismissed ON public.friend_recommendations(is_dismissed);
        RAISE NOTICE '已創建 idx_friend_recommendations_dismissed 索引';
    END IF;
    
    -- 黑名單索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_blocked_users_blocker_id') THEN
        CREATE INDEX idx_blocked_users_blocker_id ON public.blocked_users(blocker_id);
        RAISE NOTICE '已創建 idx_blocked_users_blocker_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_blocked_users_blocked_id') THEN
        CREATE INDEX idx_blocked_users_blocked_id ON public.blocked_users(blocked_id);
        RAISE NOTICE '已創建 idx_blocked_users_blocked_id 索引';
    END IF;
    
    -- 現有 friendships 表索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friendships_requester_id') THEN
        CREATE INDEX idx_friendships_requester_id ON public.friendships(requester_id);
        RAISE NOTICE '已創建 idx_friendships_requester_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friendships_addressee_id') THEN
        CREATE INDEX idx_friendships_addressee_id ON public.friendships(addressee_id);
        RAISE NOTICE '已創建 idx_friendships_addressee_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_friendships_status') THEN
        CREATE INDEX idx_friendships_status ON public.friendships(status);
        RAISE NOTICE '已創建 idx_friendships_status 索引';
    END IF;
    
    RAISE NOTICE '✅ 好友系統索引修復完成！';
    
END $$;

-- 2. 確保 RLS 政策正確設置
DO $$
BEGIN
    RAISE NOTICE '開始修復好友系統 RLS 政策...';
    
    -- 啟用 RLS（如果尚未啟用）
    ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.friend_activities ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.friend_search_cache ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.friend_recommendations ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
    
    -- 好友請求政策
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_requests' 
        AND policyname = 'Users can view friend requests sent to them'
    ) THEN
        CREATE POLICY "Users can view friend requests sent to them" ON public.friend_requests FOR SELECT
        USING (to_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建好友請求接收查看政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_requests' 
        AND policyname = 'Users can view friend requests they sent'
    ) THEN
        CREATE POLICY "Users can view friend requests they sent" ON public.friend_requests FOR SELECT
        USING (from_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建好友請求發送查看政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_requests' 
        AND policyname = 'Users can send friend requests'
    ) THEN
        CREATE POLICY "Users can send friend requests" ON public.friend_requests FOR INSERT
        WITH CHECK (from_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建好友請求發送政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_requests' 
        AND policyname = 'Users can update friend requests sent to them'
    ) THEN
        CREATE POLICY "Users can update friend requests sent to them" ON public.friend_requests FOR UPDATE
        USING (to_user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建好友請求更新政策';
    END IF;
    
    -- 好友活動政策（只能查看好友的活動）
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_activities' 
        AND policyname = 'Users can view friends activities'
    ) THEN
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
        RAISE NOTICE '已創建好友活動查看政策';
    END IF;
    
    -- 搜尋緩存政策
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_search_cache' 
        AND policyname = 'Users can manage own search cache'
    ) THEN
        CREATE POLICY "Users can manage own search cache" ON public.friend_search_cache FOR ALL
        USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建搜尋緩存政策';
    END IF;
    
    -- 好友推薦政策
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'friend_recommendations' 
        AND policyname = 'Users can view own friend recommendations'
    ) THEN
        CREATE POLICY "Users can view own friend recommendations" ON public.friend_recommendations FOR ALL
        USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建好友推薦政策';
    END IF;
    
    -- 黑名單政策
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'blocked_users' 
        AND policyname = 'Users can manage own blocked users'
    ) THEN
        CREATE POLICY "Users can manage own blocked users" ON public.blocked_users FOR ALL
        USING (blocker_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建黑名單政策';
    END IF;
    
    RAISE NOTICE '✅ 好友系統 RLS 政策修復完成！';
    
END $$;

-- 3. 確保觸發器和函數存在
DO $$
BEGIN
    RAISE NOTICE '開始修復好友系統觸發器...';
    
    -- 檢查好友請求接受觸發器
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_handle_friend_request_acceptance'
    ) THEN
        -- 創建好友請求處理函數
        CREATE OR REPLACE FUNCTION handle_friend_request_acceptance()
        RETURNS TRIGGER AS $func$
        BEGIN
          -- 當好友請求被接受時，建立雙向好友關係
          IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
            -- 建立好友關係
            INSERT INTO public.friendships (requester_id, addressee_id, status, created_at, updated_at)
            VALUES (NEW.from_user_id, NEW.to_user_id, 'accepted', now(), now())
            ON CONFLICT (requester_id, addressee_id) DO NOTHING;
            
            -- 更新回應時間
            NEW.response_date = now();
          END IF;
          
          RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;
        
        -- 創建觸發器
        CREATE TRIGGER trigger_handle_friend_request_acceptance
          BEFORE UPDATE ON public.friend_requests
          FOR EACH ROW 
          EXECUTE FUNCTION handle_friend_request_acceptance();
          
        RAISE NOTICE '已創建好友請求接受觸發器';
    END IF;
    
    -- 檢查搜尋緩存清理函數
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'cleanup_expired_search_cache'
    ) THEN
        CREATE OR REPLACE FUNCTION cleanup_expired_search_cache()
        RETURNS void AS $func$
        BEGIN
          DELETE FROM public.friend_search_cache 
          WHERE expires_at < now();
        END;
        $func$ LANGUAGE plpgsql;
        
        RAISE NOTICE '已創建搜尋緩存清理函數';
    END IF;
    
    -- 檢查好友推薦生成函數
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'generate_friend_recommendations'
    ) THEN
        CREATE OR REPLACE FUNCTION generate_friend_recommendations(target_user_id uuid)
        RETURNS void AS $func$
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
        $func$ LANGUAGE plpgsql;
        
        RAISE NOTICE '已創建好友推薦生成函數';
    END IF;
    
    RAISE NOTICE '✅ 好友系統觸發器修復完成！';
    
END $$;

-- 4. 最終檢查：確認所有關鍵表格都存在且正常
DO $$
BEGIN
    RAISE NOTICE '開始最終檢查...';
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'friend_requests') THEN
        RAISE EXCEPTION '錯誤：friend_requests 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'friend_activities') THEN
        RAISE EXCEPTION '錯誤：friend_activities 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'friend_search_cache') THEN
        RAISE EXCEPTION '錯誤：friend_search_cache 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'friend_recommendations') THEN
        RAISE EXCEPTION '錯誤：friend_recommendations 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'blocked_users') THEN
        RAISE EXCEPTION '錯誤：blocked_users 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'friendships') THEN
        RAISE EXCEPTION '錯誤：friendships 表格不存在！';
    END IF;
    
    RAISE NOTICE '✅ 所有好友系統表格檢查完成！';
    RAISE NOTICE '✅ 好友系統索引和政策修復完成！';
    RAISE NOTICE '✅ 好友系統已準備就緒！';
    
END $$;