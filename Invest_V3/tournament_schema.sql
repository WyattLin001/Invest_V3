-- 錦標賽系統資料庫架構
-- 需要在 Supabase 中創建以下表格

-- 1. 錦標賽主表
CREATE TABLE tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    short_description VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'special')),
    status VARCHAR(50) NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'enrolling', 'ongoing', 'finished', 'cancelled')),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    initial_balance DECIMAL(15,2) NOT NULL DEFAULT 1000000,
    max_participants INTEGER NOT NULL DEFAULT 1000,
    current_participants INTEGER NOT NULL DEFAULT 0,
    entry_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    prize_pool DECIMAL(15,2) NOT NULL DEFAULT 0,
    risk_limit_percentage DECIMAL(5,2) NOT NULL DEFAULT 10.0,
    min_holding_rate DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    max_single_stock_rate DECIMAL(5,2) NOT NULL DEFAULT 30.0,
    rules JSONB NOT NULL DEFAULT '[]',
    is_featured BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 錦標賽參與者表
CREATE TABLE tournament_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    user_avatar VARCHAR(500),
    current_rank INTEGER NOT NULL DEFAULT 999999,
    previous_rank INTEGER NOT NULL DEFAULT 999999,
    virtual_balance DECIMAL(15,2) NOT NULL,
    initial_balance DECIMAL(15,2) NOT NULL,
    return_rate DECIMAL(8,4) NOT NULL DEFAULT 0.0,
    total_trades INTEGER NOT NULL DEFAULT 0,
    profitable_trades INTEGER NOT NULL DEFAULT 0,
    win_rate DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    max_drawdown DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    sharpe_ratio DECIMAL(8,4),
    is_eliminated BOOLEAN NOT NULL DEFAULT false,
    elimination_reason VARCHAR(500),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tournament_id, user_id)
);

-- 3. 錦標賽活動記錄表
CREATE TABLE tournament_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    activity_type VARCHAR(50) NOT NULL CHECK (activity_type IN ('trade', 'rank_change', 'elimination', 'milestone', 'violation')),
    description TEXT NOT NULL,
    amount DECIMAL(15,2),
    symbol VARCHAR(20),
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 錦標賽交易記錄表
CREATE TABLE tournament_trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES tournament_participants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    trade_type VARCHAR(10) NOT NULL CHECK (trade_type IN ('buy', 'sell')),
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(255),
    quantity INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    commission DECIMAL(10,2) NOT NULL DEFAULT 0,
    trade_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. 錦標賽持股表
CREATE TABLE tournament_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES tournament_participants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(255),
    quantity INTEGER NOT NULL DEFAULT 0,
    average_price DECIMAL(10,2) NOT NULL DEFAULT 0,
    current_price DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_cost DECIMAL(15,2) NOT NULL DEFAULT 0,
    market_value DECIMAL(15,2) NOT NULL DEFAULT 0,
    unrealized_pnl DECIMAL(15,2) NOT NULL DEFAULT 0,
    unrealized_pnl_percentage DECIMAL(8,4) NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tournament_id, participant_id, symbol)
);

-- 6. 用戶成就表
CREATE TABLE user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    achievement_type VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    icon VARCHAR(100) NOT NULL,
    rarity VARCHAR(50) NOT NULL CHECK (rarity IN ('bronze', 'silver', 'gold', 'platinum', 'diamond')),
    progress DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    tournament_id UUID REFERENCES tournaments(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. 錦標賽排行榜快照表（用於歷史記錄）
CREATE TABLE tournament_leaderboard_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES tournament_participants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    rank INTEGER NOT NULL,
    virtual_balance DECIMAL(15,2) NOT NULL,
    return_rate DECIMAL(8,4) NOT NULL,
    snapshot_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引優化
CREATE INDEX idx_tournaments_type ON tournaments(type);
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_featured ON tournaments(is_featured);
CREATE INDEX idx_tournaments_dates ON tournaments(start_date, end_date);

CREATE INDEX idx_tournament_participants_tournament ON tournament_participants(tournament_id);
CREATE INDEX idx_tournament_participants_user ON tournament_participants(user_id);
CREATE INDEX idx_tournament_participants_rank ON tournament_participants(current_rank);

CREATE INDEX idx_tournament_activities_tournament ON tournament_activities(tournament_id);
CREATE INDEX idx_tournament_activities_user ON tournament_activities(user_id);
CREATE INDEX idx_tournament_activities_type ON tournament_activities(activity_type);
CREATE INDEX idx_tournament_activities_timestamp ON tournament_activities(timestamp);

CREATE INDEX idx_tournament_trades_tournament ON tournament_trades(tournament_id);
CREATE INDEX idx_tournament_trades_participant ON tournament_trades(participant_id);
CREATE INDEX idx_tournament_trades_user ON tournament_trades(user_id);
CREATE INDEX idx_tournament_trades_symbol ON tournament_trades(symbol);
CREATE INDEX idx_tournament_trades_date ON tournament_trades(trade_date);

CREATE INDEX idx_tournament_holdings_tournament ON tournament_holdings(tournament_id);
CREATE INDEX idx_tournament_holdings_participant ON tournament_holdings(participant_id);
CREATE INDEX idx_tournament_holdings_symbol ON tournament_holdings(symbol);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_type ON user_achievements(achievement_type);
CREATE INDEX idx_user_achievements_unlocked ON user_achievements(is_unlocked);

CREATE INDEX idx_leaderboard_snapshots_tournament ON tournament_leaderboard_snapshots(tournament_id);
CREATE INDEX idx_leaderboard_snapshots_date ON tournament_leaderboard_snapshots(snapshot_date);

-- Row Level Security (RLS) 政策
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_leaderboard_snapshots ENABLE ROW LEVEL SECURITY;

-- 錦標賽資訊所有認證用戶都可以查看
CREATE POLICY "tournaments_are_public" ON tournaments
    FOR SELECT TO authenticated USING (true);

-- 管理員可以管理錦標賽
CREATE POLICY "admin_can_manage_tournaments" ON tournaments
    FOR ALL TO authenticated USING (
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin'
    );

-- 參與者資訊所有認證用戶都可以查看（用於排行榜）
CREATE POLICY "participants_are_public" ON tournament_participants
    FOR SELECT TO authenticated USING (true);

-- 用戶只能修改自己的參與記錄
CREATE POLICY "users_can_manage_own_participation" ON tournament_participants
    FOR ALL TO authenticated USING (user_id = auth.uid()::text);

-- 活動記錄所有認證用戶都可以查看
CREATE POLICY "activities_are_public" ON tournament_activities
    FOR SELECT TO authenticated USING (true);

-- 用戶只能查看自己的交易記錄
CREATE POLICY "users_can_view_own_trades" ON tournament_trades
    FOR SELECT TO authenticated USING (user_id = auth.uid()::text);

-- 用戶只能管理自己的交易記錄
CREATE POLICY "users_can_manage_own_trades" ON tournament_trades
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid()::text);

-- 用戶只能查看自己的持股
CREATE POLICY "users_can_view_own_holdings" ON tournament_holdings
    FOR SELECT TO authenticated USING (user_id = auth.uid()::text);

-- 用戶只能管理自己的持股
CREATE POLICY "users_can_manage_own_holdings" ON tournament_holdings
    FOR ALL TO authenticated USING (user_id = auth.uid()::text);

-- 用戶只能查看自己的成就
CREATE POLICY "users_can_view_own_achievements" ON user_achievements
    FOR SELECT TO authenticated USING (user_id = auth.uid()::text);

-- 排行榜快照所有認證用戶都可以查看
CREATE POLICY "leaderboard_snapshots_are_public" ON tournament_leaderboard_snapshots
    FOR SELECT TO authenticated USING (true);

-- 觸發器：自動更新 updated_at 欄位
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tournaments_updated_at 
    BEFORE UPDATE ON tournaments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tournament_participants_updated_at 
    BEFORE UPDATE ON tournament_participants 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 觸發器：更新錦標賽參與者數量
CREATE OR REPLACE FUNCTION update_tournament_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE tournaments 
        SET current_participants = current_participants + 1
        WHERE id = NEW.tournament_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE tournaments 
        SET current_participants = current_participants - 1
        WHERE id = OLD.tournament_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tournament_participant_count_trigger
    AFTER INSERT OR DELETE ON tournament_participants
    FOR EACH ROW EXECUTE FUNCTION update_tournament_participant_count();

-- 範例數據插入
INSERT INTO tournaments (
    name, description, short_description, type, status, 
    start_date, end_date, initial_balance, max_participants, 
    prize_pool, is_featured, rules
) VALUES
(
    'Monthly Masters Championship',
    'The premier monthly trading competition featuring professional traders from across Taiwan. Test your strategies against the best and win substantial prizes.',
    'The premier monthly trading competition. Compete with the best traders!',
    'monthly',
    'enrolling',
    NOW() + INTERVAL '5 days',
    NOW() + INTERVAL '35 days',
    1000000,
    2000,
    500000,
    true,
    '["30-day duration", "Max 25% single stock allocation", "Min 70% position requirement", "Risk limit: 15% max drawdown"]'
),
(
    'Weekly Warriors',
    'One week to prove your trading strategy. Perfect for swing traders looking for quick action.',
    'One week to prove your trading strategy. Perfect for swing traders.',
    'weekly',
    'ongoing',
    NOW() - INTERVAL '2 days',
    NOW() + INTERVAL '5 days',
    1000000,
    300,
    100000,
    false,
    '["7-day duration", "Max 30% single stock allocation", "Min 60% position requirement"]'
),
(
    'Daily Lightning Challenge',
    'Fast-paced single day trading competition designed for day traders who thrive under pressure.',
    'Fast-paced single day trading competition. Test your day trading skills!',
    'daily',
    'finished',
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '1 day',
    1000000,
    500,
    50000,
    false,
    '["Single day duration", "Max 10% single stock allocation", "No overnight positions"]'
),
(
    'Fed Decision Flash Tournament',
    'Special 2-hour tournament during Fed interest rate announcement. High volatility, high rewards.',
    'Special 2-hour tournament during Fed interest rate announcement.',
    'special',
    'enrolling',
    NOW() + INTERVAL '2 hours',
    NOW() + INTERVAL '4 hours',
    1000000,
    1000,
    200000,
    true,
    '["2-hour duration only", "High volatility event", "No position limits", "All positions must close before end"]'
),
(
    'Annual Championship 2024',
    'The ultimate year-long trading championship. Prove your long-term strategy and compete for the biggest prizes.',
    'The ultimate year-long trading championship. Prove your long-term strategy.',
    'yearly',
    'ongoing',
    NOW() - INTERVAL '6 months',
    NOW() + INTERVAL '6 months',
    1000000,
    5000,
    5000000,
    true,
    '["Full year duration", "Quarterly checkpoint evaluations", "Progressive elimination system", "Max 20% single stock allocation"]'
);