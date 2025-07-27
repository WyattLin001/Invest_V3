-- ======================================================
-- 好友系統數據庫架構
-- ======================================================

-- 創建好友關係表
CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    friendship_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 確保每對用戶只有一個好友關係
    UNIQUE(user_id, friend_id),
    -- 防止自己加自己為好友
    CHECK (user_id != friend_id)
);

-- 創建好友請求表
CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    from_user_name VARCHAR(50) NOT NULL,
    from_user_display_name VARCHAR(100) NOT NULL,
    from_user_avatar_url TEXT,
    to_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    message TEXT,
    request_date TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 確保同一對用戶只能有一個待處理的請求
    UNIQUE(from_user_id, to_user_id),
    -- 防止向自己發送好友請求
    CHECK (from_user_id != to_user_id)
);

-- 創建好友活動表
CREATE TABLE IF NOT EXISTS friend_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    user_name VARCHAR(50) NOT NULL,
    activity_type VARCHAR(20) NOT NULL CHECK (activity_type IN ('trade', 'achievement', 'milestone', 'group_join')),
    description TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    data JSONB, -- 存儲額外的活動數據
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 更新 user_profiles 表以支持好友系統
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS investment_style VARCHAR(20) CHECK (investment_style IN ('growth', 'value', 'dividend', 'momentum', 'balanced', 'tech', 'healthcare', 'finance')),
ADD COLUMN IF NOT EXISTS performance_score DECIMAL(3,1) DEFAULT 0.0 CHECK (performance_score >= 0 AND performance_score <= 10),
ADD COLUMN IF NOT EXISTS total_return DECIMAL(10,2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS risk_level VARCHAR(20) DEFAULT 'moderate' CHECK (risk_level IN ('conservative', 'moderate', 'aggressive')),
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS last_active_date TIMESTAMPTZ DEFAULT NOW();

-- 創建索引以提高查詢性能
CREATE INDEX IF NOT EXISTS idx_friendships_user_id ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_to_user ON friend_requests(to_user_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON friend_requests(status);
CREATE INDEX IF NOT EXISTS idx_friend_activities_user_id ON friend_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_friend_activities_timestamp ON friend_activities(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_online ON user_profiles(is_online);
CREATE INDEX IF NOT EXISTS idx_user_profiles_investment_style ON user_profiles(investment_style);

-- 創建觸發器以自動更新 updated_at 欄位
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_friend_requests_updated_at 
    BEFORE UPDATE ON friend_requests 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 創建觸發器以自動更新用戶在線狀態
CREATE OR REPLACE FUNCTION update_user_last_active()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE user_profiles 
    SET last_active_date = NOW(), is_online = true 
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 當用戶進行活動時更新最後活躍時間
CREATE TRIGGER update_user_activity_trigger
    AFTER INSERT ON friend_activities
    FOR EACH ROW
    EXECUTE FUNCTION update_user_last_active();

-- 創建 RLS (Row Level Security) 政策
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_activities ENABLE ROW LEVEL SECURITY;

-- 好友關係的 RLS 政策
CREATE POLICY "Users can view their own friendships" ON friendships
    FOR SELECT USING (auth.uid()::uuid = user_id OR auth.uid()::uuid = friend_id);

CREATE POLICY "Users can create friendships" ON friendships
    FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Users can delete their own friendships" ON friendships
    FOR DELETE USING (auth.uid()::uuid = user_id);

-- 好友請求的 RLS 政策
CREATE POLICY "Users can view friend requests involving them" ON friend_requests
    FOR SELECT USING (auth.uid()::uuid = from_user_id OR auth.uid()::uuid = to_user_id);

CREATE POLICY "Users can send friend requests" ON friend_requests
    FOR INSERT WITH CHECK (auth.uid()::uuid = from_user_id);

CREATE POLICY "Users can update requests sent to them" ON friend_requests
    FOR UPDATE USING (auth.uid()::uuid = to_user_id OR auth.uid()::uuid = from_user_id);

-- 好友活動的 RLS 政策
CREATE POLICY "Users can view activities from their friends" ON friend_activities
    FOR SELECT USING (
        auth.uid()::uuid = user_id OR 
        auth.uid()::uuid IN (
            SELECT friend_id FROM friendships WHERE user_id = friend_activities.user_id
            UNION
            SELECT user_id FROM friendships WHERE friend_id = friend_activities.user_id
        )
    );

CREATE POLICY "Users can create their own activities" ON friend_activities
    FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

-- 創建函數以獲取共同好友數量
CREATE OR REPLACE FUNCTION get_mutual_friends_count(user1_id UUID, user2_id UUID)
RETURNS INTEGER AS $$
DECLARE
    mutual_count INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO mutual_count
    FROM (
        SELECT friend_id FROM friendships WHERE user_id = user1_id
        INTERSECT
        SELECT friend_id FROM friendships WHERE user_id = user2_id
    ) AS mutual_friends;
    
    RETURN COALESCE(mutual_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建函數以推薦好友
CREATE OR REPLACE FUNCTION get_friend_recommendations(target_user_id UUID, limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    id UUID,
    user_name VARCHAR(50),
    display_name VARCHAR(100),
    avatar_url TEXT,
    bio TEXT,
    investment_style VARCHAR(20),
    performance_score DECIMAL(3,1),
    total_return DECIMAL(10,2),
    mutual_friends_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id,
        up.user_name,
        up.display_name,
        up.avatar_url,
        up.bio,
        up.investment_style,
        up.performance_score,
        up.total_return,
        get_mutual_friends_count(target_user_id, up.id) as mutual_friends_count
    FROM user_profiles up
    WHERE up.id != target_user_id
    AND up.id NOT IN (
        -- 排除已經是好友的用戶
        SELECT friend_id FROM friendships WHERE user_id = target_user_id
        UNION
        SELECT user_id FROM friendships WHERE friend_id = target_user_id
    )
    AND up.id NOT IN (
        -- 排除已經有待處理請求的用戶
        SELECT to_user_id FROM friend_requests 
        WHERE from_user_id = target_user_id AND status = 'pending'
        UNION
        SELECT from_user_id FROM friend_requests 
        WHERE to_user_id = target_user_id AND status = 'pending'
    )
    ORDER BY 
        mutual_friends_count DESC,
        up.performance_score DESC,
        up.total_return DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建函數以記錄好友活動
CREATE OR REPLACE FUNCTION create_friend_activity(
    user_id UUID,
    user_name VARCHAR(50),
    activity_type VARCHAR(20),
    description TEXT,
    activity_data JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    activity_id UUID;
BEGIN
    INSERT INTO friend_activities (user_id, user_name, activity_type, description, data)
    VALUES (user_id, user_name, activity_type, description, activity_data)
    RETURNING id INTO activity_id;
    
    RETURN activity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 插入一些測試數據（可選）
-- 注意：在生產環境中應該移除或註釋掉這部分

-- 測試用戶數據
INSERT INTO user_profiles (id, user_name, display_name, email, bio, investment_style, performance_score, total_return, risk_level, is_online) VALUES
('11111111-1111-1111-1111-111111111111', 'alice_investor', 'Alice Chen', 'alice@example.com', '專注於科技股投資，喜歡長期持有成長型公司', 'tech', 8.5, 15.2, 'moderate', true),
('22222222-2222-2222-2222-222222222222', 'bob_trader', 'Bob Wang', 'bob@example.com', '價值投資者，尋找被低估的優質股票', 'value', 7.8, 12.8, 'conservative', false),
('33333333-3333-3333-3333-333333333333', 'carol_dividend', 'Carol Liu', 'carol@example.com', '專注於高股息股票，追求穩定的現金流', 'dividend', 9.1, 18.5, 'moderate', true)
ON CONFLICT (id) DO NOTHING;

-- 測試好友關係
INSERT INTO friendships (user_id, friend_id) VALUES
('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'),
('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111'),
('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333'),
('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111')
ON CONFLICT (user_id, friend_id) DO NOTHING;

-- 測試好友活動
INSERT INTO friend_activities (user_id, user_name, activity_type, description, data) VALUES
('11111111-1111-1111-1111-111111111111', 'Alice Chen', 'trade', '買入 AAPL 股票', '{"symbol": "AAPL", "amount": 50000, "returnRate": 5.2}'),
('22222222-2222-2222-2222-222222222222', 'Bob Wang', 'achievement', '獲得價值投資大師成就', '{"achievementName": "價值投資大師"}'),
('33333333-3333-3333-3333-333333333333', 'Carol Liu', 'milestone', '投資組合突破 100 萬', '{"milestoneValue": "1000000"}');

-- 完成設置
SELECT 'Friends system database schema created successfully!' as status;