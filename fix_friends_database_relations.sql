-- ======================================================
-- 修復好友系統資料庫關聯關係
-- ======================================================

-- 首先確保 user_profiles 表存在
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID, -- Supabase auth.users 的 ID
    user_name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 好友系統相關欄位
    investment_style VARCHAR(20) CHECK (investment_style IN ('growth', 'value', 'dividend', 'momentum', 'balanced', 'tech', 'healthcare', 'finance')),
    performance_score DECIMAL(3,1) DEFAULT 0.0 CHECK (performance_score >= 0 AND performance_score <= 10),
    total_return DECIMAL(10,2) DEFAULT 0.0,
    risk_level VARCHAR(20) DEFAULT 'moderate' CHECK (risk_level IN ('conservative', 'moderate', 'aggressive')),
    is_online BOOLEAN DEFAULT false,
    last_active_date TIMESTAMPTZ DEFAULT NOW()
);

-- 如果 user_profiles 表已存在，添加缺少的欄位
DO $$ 
BEGIN
    -- 檢查並添加好友系統相關欄位
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'investment_style') THEN
        ALTER TABLE user_profiles ADD COLUMN investment_style VARCHAR(20) CHECK (investment_style IN ('growth', 'value', 'dividend', 'momentum', 'balanced', 'tech', 'healthcare', 'finance'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'performance_score') THEN
        ALTER TABLE user_profiles ADD COLUMN performance_score DECIMAL(3,1) DEFAULT 0.0 CHECK (performance_score >= 0 AND performance_score <= 10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'total_return') THEN
        ALTER TABLE user_profiles ADD COLUMN total_return DECIMAL(10,2) DEFAULT 0.0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'risk_level') THEN
        ALTER TABLE user_profiles ADD COLUMN risk_level VARCHAR(20) DEFAULT 'moderate' CHECK (risk_level IN ('conservative', 'moderate', 'aggressive'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'is_online') THEN
        ALTER TABLE user_profiles ADD COLUMN is_online BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'last_active_date') THEN
        ALTER TABLE user_profiles ADD COLUMN last_active_date TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 刪除現有的好友相關表以重新創建（如果存在）
DROP TABLE IF EXISTS friend_activities CASCADE;
DROP TABLE IF EXISTS friend_requests CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;

-- 重新創建好友關係表
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    friend_id UUID NOT NULL,
    friendship_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 外鍵約束
    CONSTRAINT fk_friendships_user_id FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_friendships_friend_id FOREIGN KEY (friend_id) REFERENCES user_profiles(id) ON DELETE CASCADE,
    
    -- 確保每對用戶只有一個好友關係
    UNIQUE(user_id, friend_id),
    -- 防止自己加自己為好友
    CHECK (user_id != friend_id)
);

-- 重新創建好友請求表
CREATE TABLE friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL,
    from_user_name VARCHAR(50) NOT NULL,
    from_user_display_name VARCHAR(100) NOT NULL,
    from_user_avatar_url TEXT,
    to_user_id UUID NOT NULL,
    message TEXT,
    request_date TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 外鍵約束
    CONSTRAINT fk_friend_requests_from_user FOREIGN KEY (from_user_id) REFERENCES user_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_friend_requests_to_user FOREIGN KEY (to_user_id) REFERENCES user_profiles(id) ON DELETE CASCADE,
    
    -- 確保同一對用戶只能有一個待處理的請求
    UNIQUE(from_user_id, to_user_id),
    -- 防止向自己發送好友請求
    CHECK (from_user_id != to_user_id)
);

-- 重新創建好友活動表
CREATE TABLE friend_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    user_name VARCHAR(50) NOT NULL,
    activity_type VARCHAR(20) NOT NULL CHECK (activity_type IN ('trade', 'achievement', 'milestone', 'group_join')),
    description TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 外鍵約束
    CONSTRAINT fk_friend_activities_user FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE
);

-- 創建索引
CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX idx_friend_requests_to_user ON friend_requests(to_user_id);
CREATE INDEX idx_friend_requests_status ON friend_requests(status);
CREATE INDEX idx_friend_activities_user_id ON friend_activities(user_id);
CREATE INDEX idx_friend_activities_timestamp ON friend_activities(timestamp DESC);
CREATE INDEX idx_user_profiles_online ON user_profiles(is_online);
CREATE INDEX idx_user_profiles_investment_style ON user_profiles(investment_style);
CREATE INDEX idx_user_profiles_user_name ON user_profiles(user_name);

-- 創建或替換觸發器函數
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 創建觸發器
DROP TRIGGER IF EXISTS update_friend_requests_updated_at ON friend_requests;
CREATE TRIGGER update_friend_requests_updated_at 
    BEFORE UPDATE ON friend_requests 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 啟用 RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_activities ENABLE ROW LEVEL SECURITY;

-- 創建 RLS 政策
-- user_profiles 的 RLS 政策
DROP POLICY IF EXISTS "Users can view all profiles" ON user_profiles;
CREATE POLICY "Users can view all profiles" ON user_profiles
    FOR SELECT USING (true); -- 允許查看所有用戶資料

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid()::uuid = user_id OR auth.uid()::uuid = id);

-- 好友關係的 RLS 政策
DROP POLICY IF EXISTS "Users can view their own friendships" ON friendships;
CREATE POLICY "Users can view their own friendships" ON friendships
    FOR SELECT USING (auth.uid()::uuid = user_id OR auth.uid()::uuid = friend_id);

DROP POLICY IF EXISTS "Users can create friendships" ON friendships;
CREATE POLICY "Users can create friendships" ON friendships
    FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

DROP POLICY IF EXISTS "Users can delete their own friendships" ON friendships;
CREATE POLICY "Users can delete their own friendships" ON friendships
    FOR DELETE USING (auth.uid()::uuid = user_id);

-- 好友請求的 RLS 政策
DROP POLICY IF EXISTS "Users can view friend requests involving them" ON friend_requests;
CREATE POLICY "Users can view friend requests involving them" ON friend_requests
    FOR SELECT USING (auth.uid()::uuid = from_user_id OR auth.uid()::uuid = to_user_id);

DROP POLICY IF EXISTS "Users can send friend requests" ON friend_requests;
CREATE POLICY "Users can send friend requests" ON friend_requests
    FOR INSERT WITH CHECK (auth.uid()::uuid = from_user_id);

DROP POLICY IF EXISTS "Users can update requests sent to them" ON friend_requests;
CREATE POLICY "Users can update requests sent to them" ON friend_requests
    FOR UPDATE USING (auth.uid()::uuid = to_user_id OR auth.uid()::uuid = from_user_id);

-- 好友活動的 RLS 政策
DROP POLICY IF EXISTS "Users can view activities from their friends" ON friend_activities;
CREATE POLICY "Users can view activities from their friends" ON friend_activities
    FOR SELECT USING (
        auth.uid()::uuid = user_id OR 
        auth.uid()::uuid IN (
            SELECT friend_id FROM friendships WHERE user_id = friend_activities.user_id
            UNION
            SELECT user_id FROM friendships WHERE friend_id = friend_activities.user_id
        )
    );

DROP POLICY IF EXISTS "Users can create their own activities" ON friend_activities;
CREATE POLICY "Users can create their own activities" ON friend_activities
    FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

-- 插入一些測試用戶資料
INSERT INTO user_profiles (id, user_name, display_name, email, bio, investment_style, performance_score, total_return, risk_level, is_online) VALUES
('11111111-1111-1111-1111-111111111111', 'alice_investor', 'Alice Chen', 'alice@example.com', '專注於科技股投資，喜歡長期持有成長型公司', 'tech', 8.5, 15.2, 'moderate', true),
('22222222-2222-2222-2222-222222222222', 'bob_trader', 'Bob Wang', 'bob@example.com', '價值投資者，尋找被低估的優質股票', 'value', 7.8, 12.8, 'conservative', false),
('33333333-3333-3333-3333-333333333333', 'carol_dividend', 'Carol Liu', 'carol@example.com', '專注於高股息股票，追求穩定的現金流', 'dividend', 9.1, 18.5, 'moderate', true),
('44444444-4444-4444-4444-444444444444', 'david_growth', 'David Zhang', 'david@example.com', '成長股投資專家，專注於新興科技領域', 'growth', 9.3, 22.1, 'aggressive', true),
('55555555-5555-5555-5555-555555555555', 'emily_balanced', 'Emily Wu', 'emily@example.com', '平衡型投資者，追求穩健收益', 'balanced', 7.2, 10.5, 'moderate', false)
ON CONFLICT (id) DO UPDATE SET
    user_name = EXCLUDED.user_name,
    display_name = EXCLUDED.display_name,
    email = EXCLUDED.email,
    bio = EXCLUDED.bio,
    investment_style = EXCLUDED.investment_style,
    performance_score = EXCLUDED.performance_score,
    total_return = EXCLUDED.total_return,
    risk_level = EXCLUDED.risk_level,
    is_online = EXCLUDED.is_online,
    updated_at = NOW();

-- 插入一些測試好友關係
INSERT INTO friendships (user_id, friend_id) VALUES
('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'),
('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111'),
('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333'),
('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111'),
('44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555'),
('55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444')
ON CONFLICT (user_id, friend_id) DO NOTHING;

-- 插入一些測試好友活動
INSERT INTO friend_activities (user_id, user_name, activity_type, description, data) VALUES
('11111111-1111-1111-1111-111111111111', 'Alice Chen', 'trade', '買入 AAPL 股票 100 股', '{"symbol": "AAPL", "shares": 100, "amount": 15000, "returnRate": 5.2}'),
('22222222-2222-2222-2222-222222222222', 'Bob Wang', 'achievement', '獲得價值投資大師成就', '{"achievementName": "價值投資大師", "description": "連續3個月獲得正收益"}'),
('33333333-3333-3333-3333-333333333333', 'Carol Liu', 'milestone', '投資組合突破 100 萬', '{"milestoneValue": 1000000, "milestoneType": "portfolio_value"}'),
('44444444-4444-4444-4444-444444444444', 'David Zhang', 'trade', '賣出 TSLA 股票獲利 8%', '{"symbol": "TSLA", "shares": 50, "amount": 25000, "returnRate": 8.0}'),
('55555555-5555-5555-5555-555555555555', 'Emily Wu', 'achievement', '獲得穩健投資者徽章', '{"achievementName": "穩健投資者", "description": "風險控制優秀"}');

-- 驗證表關聯
SELECT 
    'friendships' as table_name,
    COUNT(*) as row_count
FROM friendships
UNION ALL
SELECT 
    'friend_requests' as table_name,
    COUNT(*) as row_count
FROM friend_requests
UNION ALL
SELECT 
    'friend_activities' as table_name,
    COUNT(*) as row_count
FROM friend_activities
UNION ALL
SELECT 
    'user_profiles' as table_name,
    COUNT(*) as row_count
FROM user_profiles;

-- 測試關聯查詢
SELECT 
    f.id,
    u1.display_name as user_name,
    u2.display_name as friend_name,
    f.friendship_date
FROM friendships f
JOIN user_profiles u1 ON f.user_id = u1.id
JOIN user_profiles u2 ON f.friend_id = u2.id
LIMIT 5;

SELECT 'Friends database relations fixed successfully!' as status;