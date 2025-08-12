-- 錦標賽系統完整數據庫架構 V2.0
-- 完全隔離的賽事數據管理，與日常交易分離
-- 基於用戶需求設計：每張表都有 tournament_id，自然隔離

-- ============================================================================
-- 1. tournaments（賽事主表）
-- ============================================================================
CREATE TABLE tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
    entry_capital DECIMAL(15,2) NOT NULL DEFAULT 1000000, -- 起始資金
    fee_tokens INTEGER NOT NULL DEFAULT 0, -- 入場費代幣
    return_metric VARCHAR(50) NOT NULL DEFAULT 'twr', -- 報酬率計算方式 (twr, simple, etc.)
    reset_mode VARCHAR(20) NOT NULL DEFAULT 'monthly', -- 重置模式 (monthly, quarterly, yearly)
    
    -- 錦標賽基本資訊
    description TEXT,
    short_description VARCHAR(500),
    type VARCHAR(50) NOT NULL DEFAULT 'monthly',
    status VARCHAR(20) NOT NULL DEFAULT 'upcoming',
    max_participants INTEGER NOT NULL DEFAULT 100,
    current_participants INTEGER NOT NULL DEFAULT 0,
    
    -- 交易規則
    risk_limit_percentage DECIMAL(5,2) DEFAULT 20.0,
    min_holding_rate DECIMAL(5,2) DEFAULT 60.0,
    max_single_stock_rate DECIMAL(5,2) DEFAULT 30.0,
    rules JSONB DEFAULT '[]',
    
    -- 獎勵設定
    prize_pool DECIMAL(15,2) DEFAULT 0,
    is_featured BOOLEAN DEFAULT FALSE,
    
    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE tournaments IS '錦標賽主表 - 存儲所有賽事的基本資訊和規則';
COMMENT ON COLUMN tournaments.entry_capital IS '參賽者起始資金額';
COMMENT ON COLUMN tournaments.fee_tokens IS '參賽入場費（代幣數量）';
COMMENT ON COLUMN tournaments.return_metric IS '報酬率計算方式：twr=時間加權報酬率, simple=簡單報酬率';
COMMENT ON COLUMN tournaments.reset_mode IS '重置週期：monthly=月度, quarterly=季度, yearly=年度';

-- ============================================================================
-- 2. tournament_members（參賽名單）
-- ============================================================================
CREATE TABLE tournament_members (
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, eliminated, withdrawn
    elimination_reason VARCHAR(500),
    
    PRIMARY KEY (tournament_id, user_id)
);

COMMENT ON TABLE tournament_members IS '錦標賽參賽名單 - 記錄誰參加了哪個錦標賽';
COMMENT ON COLUMN tournament_members.status IS '參賽狀態：active=活躍, eliminated=淘汰, withdrawn=退出';

-- ============================================================================
-- 3. tournament_portfolios（賽事錢包/資產帳）
-- ============================================================================
CREATE TABLE tournament_portfolios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    
    -- 資產狀況
    cash_balance DECIMAL(15,2) NOT NULL, -- 現金餘額
    equity_value DECIMAL(15,2) NOT NULL DEFAULT 0, -- 股票市值
    total_assets DECIMAL(15,2) GENERATED ALWAYS AS (cash_balance + equity_value) STORED, -- 總資產
    
    -- 績效指標
    initial_balance DECIMAL(15,2) NOT NULL, -- 初始資金（用於計算報酬率）
    total_return DECIMAL(15,2) GENERATED ALWAYS AS (cash_balance + equity_value - initial_balance) STORED,
    return_percentage DECIMAL(10,6) GENERATED ALWAYS AS (
        CASE WHEN initial_balance > 0 
        THEN ((cash_balance + equity_value - initial_balance) / initial_balance) * 100 
        ELSE 0 END
    ) STORED,
    
    -- 統計資訊
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    max_drawdown DECIMAL(10,6) DEFAULT 0,
    
    -- 時間戳
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(tournament_id, user_id)
);

COMMENT ON TABLE tournament_portfolios IS '錦標賽投資組合 - 每個參賽者在每個錦標賽中的資產狀況';
COMMENT ON COLUMN tournament_portfolios.cash_balance IS '現金餘額';
COMMENT ON COLUMN tournament_portfolios.equity_value IS '持股市值';
COMMENT ON COLUMN tournament_portfolios.total_assets IS '總資產 = 現金 + 股票市值';

-- ============================================================================
-- 4. tournament_trades（賽事內交易記錄）
-- ============================================================================
CREATE TABLE tournament_trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    
    -- 交易基本資訊
    symbol VARCHAR(20) NOT NULL, -- 股票代碼
    side VARCHAR(10) NOT NULL CHECK (side IN ('buy', 'sell')), -- 買賣方向
    qty DECIMAL(15,4) NOT NULL, -- 數量
    price DECIMAL(15,4) NOT NULL, -- 價格
    amount DECIMAL(15,2) GENERATED ALWAYS AS (qty * price) STORED, -- 交易金額
    
    -- 費用
    fees DECIMAL(15,2) NOT NULL DEFAULT 0, -- 手續費
    net_amount DECIMAL(15,2) GENERATED ALWAYS AS (
        CASE WHEN side = 'buy' 
        THEN (qty * price) + fees 
        ELSE (qty * price) - fees END
    ) STORED, -- 淨金額
    
    -- 損益（僅賣出時計算）
    realized_pnl DECIMAL(15,2), -- 已實現損益
    realized_pnl_percentage DECIMAL(10,6), -- 已實現損益百分比
    
    -- 交易狀態
    status VARCHAR(20) DEFAULT 'executed', -- executed, cancelled, pending
    
    -- 時間戳
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE tournament_trades IS '錦標賽交易記錄 - 所有賽事內的買賣交易，與一般 trading_transactions 完全分離';
COMMENT ON COLUMN tournament_trades.side IS '交易方向：buy=買入, sell=賣出';
COMMENT ON COLUMN tournament_trades.net_amount IS '淨交易金額：買入時加手續費，賣出時扣手續費';

-- ============================================================================
-- 5. tournament_positions（賽事持倉彙總）
-- ============================================================================
CREATE TABLE tournament_positions (
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    
    -- 持倉資訊
    qty DECIMAL(15,4) NOT NULL DEFAULT 0, -- 持有數量
    avg_cost DECIMAL(15,4) NOT NULL DEFAULT 0, -- 平均成本
    total_cost DECIMAL(15,2) GENERATED ALWAYS AS (qty * avg_cost) STORED, -- 總成本
    
    -- 市值資訊
    current_price DECIMAL(15,4) NOT NULL DEFAULT 0, -- 當前價格
    market_value DECIMAL(15,2) GENERATED ALWAYS AS (qty * current_price) STORED, -- 市值
    
    -- 損益資訊
    unrealized_pnl DECIMAL(15,2) GENERATED ALWAYS AS (
        (qty * current_price) - (qty * avg_cost)
    ) STORED, -- 未實現損益
    unrealized_pnl_percentage DECIMAL(10,6) GENERATED ALWAYS AS (
        CASE WHEN avg_cost > 0 
        THEN ((current_price - avg_cost) / avg_cost) * 100 
        ELSE 0 END
    ) STORED, -- 未實現損益百分比
    
    -- 時間戳
    first_buy_at TIMESTAMP WITH TIME ZONE, -- 首次買入時間
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (tournament_id, user_id, symbol)
);

COMMENT ON TABLE tournament_positions IS '錦標賽持倉彙總 - 每個參賽者在每個錦標賽中的持股狀況';
COMMENT ON COLUMN tournament_positions.avg_cost IS '平均持倉成本';
COMMENT ON COLUMN tournament_positions.market_value IS '當前市值';

-- ============================================================================
-- 6. tournament_snapshots（排行榜快照）
-- ============================================================================
CREATE TABLE tournament_snapshots (
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    as_of_date DATE NOT NULL,
    
    -- 資產快照
    cash DECIMAL(15,2) NOT NULL,
    position_value DECIMAL(15,2) NOT NULL, -- 持股價值
    total_assets DECIMAL(15,2) NOT NULL,
    
    -- 績效快照
    return_rate DECIMAL(10,6) NOT NULL, -- 報酬率
    daily_return DECIMAL(10,6), -- 日報酬率
    cumulative_return DECIMAL(15,2), -- 累計收益
    
    -- 風險指標
    max_dd DECIMAL(10,6), -- 最大回撤
    volatility DECIMAL(10,6), -- 波動率
    sharpe DECIMAL(10,6), -- 夏普比率
    
    -- 交易統計
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    win_rate DECIMAL(5,4) DEFAULT 0,
    
    -- 排名資訊
    rank INTEGER, -- 當日排名
    total_participants INTEGER, -- 總參賽人數
    percentile DECIMAL(5,2), -- 百分位數
    
    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (tournament_id, user_id, as_of_date)
);

COMMENT ON TABLE tournament_snapshots IS '錦標賽績效快照 - 用於排行榜計算和歷史追蹤';
COMMENT ON COLUMN tournament_snapshots.return_rate IS '報酬率（小數形式，如 0.05 代表 5%）';
COMMENT ON COLUMN tournament_snapshots.rank IS '當日排名（1 = 第一名）';

-- ============================================================================
-- 索引建立
-- ============================================================================

-- tournaments 表索引
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_starts_at ON tournaments(starts_at);
CREATE INDEX idx_tournaments_type ON tournaments(type);
CREATE INDEX idx_tournaments_featured ON tournaments(is_featured) WHERE is_featured = TRUE;

-- tournament_members 表索引
CREATE INDEX idx_tournament_members_user_id ON tournament_members(user_id);
CREATE INDEX idx_tournament_members_joined_at ON tournament_members(joined_at);
CREATE INDEX idx_tournament_members_status ON tournament_members(status);

-- tournament_portfolios 表索引
CREATE INDEX idx_tournament_portfolios_user_id ON tournament_portfolios(user_id);
CREATE INDEX idx_tournament_portfolios_return_rate ON tournament_portfolios(return_percentage DESC);
CREATE INDEX idx_tournament_portfolios_total_assets ON tournament_portfolios(total_assets DESC);

-- tournament_trades 表索引
CREATE INDEX idx_tournament_trades_user_id ON tournament_trades(user_id);
CREATE INDEX idx_tournament_trades_symbol ON tournament_trades(symbol);
CREATE INDEX idx_tournament_trades_executed_at ON tournament_trades(executed_at);
CREATE INDEX idx_tournament_trades_tournament_user ON tournament_trades(tournament_id, user_id);
CREATE INDEX idx_tournament_trades_tournament_symbol ON tournament_trades(tournament_id, symbol);

-- tournament_positions 表索引
CREATE INDEX idx_tournament_positions_user_id ON tournament_positions(user_id);
CREATE INDEX idx_tournament_positions_symbol ON tournament_positions(symbol);
CREATE INDEX idx_tournament_positions_market_value ON tournament_positions(market_value DESC);

-- tournament_snapshots 表索引
CREATE INDEX idx_tournament_snapshots_date ON tournament_snapshots(as_of_date);
CREATE INDEX idx_tournament_snapshots_rank ON tournament_snapshots(tournament_id, as_of_date, rank);
CREATE INDEX idx_tournament_snapshots_return_rate ON tournament_snapshots(tournament_id, as_of_date, return_rate DESC);
CREATE INDEX idx_tournament_snapshots_user_date ON tournament_snapshots(user_id, as_of_date);

-- ============================================================================
-- 觸發器和自動更新函數
-- ============================================================================

-- 更新 tournaments 表的 updated_at 欄位
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tournaments_updated_at 
    BEFORE UPDATE ON tournaments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 自動更新錦標賽參與人數
CREATE OR REPLACE FUNCTION update_tournament_participants()
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

CREATE TRIGGER tournament_members_count_trigger
    AFTER INSERT OR DELETE ON tournament_members
    FOR EACH ROW EXECUTE FUNCTION update_tournament_participants();

-- ============================================================================
-- Row Level Security (RLS) 設定
-- ============================================================================

-- 啟用 RLS
ALTER TABLE tournament_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_snapshots ENABLE ROW LEVEL SECURITY;

-- 用戶只能查看和修改自己的數據
CREATE POLICY user_own_trades ON tournament_trades 
    FOR ALL USING (user_id = auth.uid()::text);

CREATE POLICY user_own_portfolios ON tournament_portfolios 
    FOR ALL USING (user_id = auth.uid()::text);

CREATE POLICY user_own_positions ON tournament_positions 
    FOR ALL USING (user_id = auth.uid()::text);

CREATE POLICY user_own_snapshots ON tournament_snapshots 
    FOR ALL USING (user_id = auth.uid()::text);

-- 管理員可以查看所有數據
CREATE POLICY admin_view_all_trades ON tournament_trades 
    FOR SELECT USING (
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin'
    );

CREATE POLICY admin_view_all_portfolios ON tournament_portfolios 
    FOR SELECT USING (
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin'
    );

-- ============================================================================
-- 排行榜視圖
-- ============================================================================

-- 即時排行榜視圖
CREATE OR REPLACE VIEW tournament_leaderboard AS
SELECT 
    p.tournament_id,
    p.user_id,
    p.total_assets,
    p.return_percentage,
    p.total_trades,
    p.last_updated,
    ROW_NUMBER() OVER (
        PARTITION BY p.tournament_id 
        ORDER BY p.return_percentage DESC, p.total_assets DESC
    ) as current_rank,
    COUNT(*) OVER (PARTITION BY p.tournament_id) as total_participants
FROM tournament_portfolios p
JOIN tournament_members m ON p.tournament_id = m.tournament_id AND p.user_id = m.user_id
WHERE m.status = 'active'
ORDER BY p.tournament_id, current_rank;

COMMENT ON VIEW tournament_leaderboard IS '錦標賽即時排行榜視圖';

-- 歷史排行榜視圖
CREATE OR REPLACE VIEW tournament_historical_rankings AS
SELECT 
    tournament_id,
    user_id,
    as_of_date,
    total_assets,
    return_rate,
    rank,
    total_participants,
    LAG(rank) OVER (
        PARTITION BY tournament_id, user_id 
        ORDER BY as_of_date
    ) as previous_rank
FROM tournament_snapshots
ORDER BY tournament_id, as_of_date, rank;

COMMENT ON VIEW tournament_historical_rankings IS '錦標賽歷史排行榜視圖';

-- ============================================================================
-- 範例查詢
-- ============================================================================

/*
-- 建立新錦標賽
INSERT INTO tournaments (name, starts_at, ends_at, entry_capital, fee_tokens) 
VALUES ('春季投資挑戰賽', '2024-03-01 09:00:00+08', '2024-03-31 15:00:00+08', 1000000, 100);

-- 用戶參賽
INSERT INTO tournament_members (tournament_id, user_id) 
VALUES ('tournament-uuid', 'user-uuid');

-- 初始化投資組合
INSERT INTO tournament_portfolios (tournament_id, user_id, cash_balance, initial_balance) 
VALUES ('tournament-uuid', 'user-uuid', 1000000, 1000000);

-- 記錄交易
INSERT INTO tournament_trades (tournament_id, user_id, symbol, side, qty, price, fees) 
VALUES ('tournament-uuid', 'user-uuid', '2330', 'buy', 1000, 580.0, 150.0);

-- 查詢排行榜
SELECT * FROM tournament_leaderboard WHERE tournament_id = 'tournament-uuid';

-- 查詢用戶績效歷史
SELECT * FROM tournament_snapshots 
WHERE tournament_id = 'tournament-uuid' AND user_id = 'user-uuid' 
ORDER BY as_of_date;
*/