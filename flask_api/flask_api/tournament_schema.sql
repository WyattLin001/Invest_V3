-- 錦標賽系統高併發數據庫架構
-- 設計目標：支援 10場錦標賽 x 100人 = 1000人同時交易

-- ========================================
-- 1. 錦標賽基本表
-- ========================================

CREATE TABLE tournaments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text DEFAULT '',
    status text DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'ended', 'cancelled')),
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    entry_capital numeric NOT NULL DEFAULT 1000000,
    max_participants int DEFAULT 100,
    current_participants int DEFAULT 0,
    fee_tokens int NOT NULL DEFAULT 0,
    return_metric text NOT NULL DEFAULT 'twr',
    reset_mode text NOT NULL DEFAULT 'monthly',
    created_by uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 錦標賽索引優化
CREATE INDEX idx_tournaments_status_time ON tournaments(status, starts_at, ends_at);
CREATE INDEX idx_tournaments_created_by ON tournaments(created_by);

-- ========================================
-- 2. 錦標賽參與者表
-- ========================================

CREATE TABLE tournament_members (
    tournament_id uuid REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    joined_at timestamptz DEFAULT now(),
    status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'disqualified')),
    initial_balance numeric DEFAULT 1000000,
    PRIMARY KEY (tournament_id, user_id)
);

-- 參與者索引
CREATE INDEX idx_tournament_members_user ON tournament_members(user_id);
CREATE INDEX idx_tournament_members_status ON tournament_members(tournament_id, status);

-- ========================================
-- 3. 錦標賽專用投資組合表
-- ========================================

CREATE TABLE tournament_portfolios (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    cash_balance numeric NOT NULL DEFAULT 1000000,
    equity_value numeric DEFAULT 0,
    total_assets numeric GENERATED ALWAYS AS (cash_balance + equity_value) STORED,
    last_trade_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    version integer DEFAULT 1, -- 樂觀鎖版本號
    UNIQUE(tournament_id, user_id)
);

-- 投資組合索引優化（支援高併發查詢）
CREATE INDEX idx_tournament_portfolios_lookup ON tournament_portfolios(tournament_id, user_id);
CREATE INDEX idx_tournament_portfolios_value ON tournament_portfolios(tournament_id, total_assets DESC);
CREATE INDEX idx_tournament_portfolios_updated ON tournament_portfolios(tournament_id, updated_at DESC);

-- ========================================
-- 4. 錦標賽專用交易表（分區表，支援高頻交易）
-- ========================================

CREATE TABLE tournament_trades (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    symbol text NOT NULL,
    side text CHECK (side IN ('buy','sell')) NOT NULL,
    qty numeric NOT NULL CHECK (qty > 0),
    price numeric NOT NULL CHECK (price > 0),
    total_amount numeric NOT NULL,
    executed_at timestamptz DEFAULT now(),
    status text DEFAULT 'executed' CHECK (status IN ('pending', 'executed', 'cancelled', 'rejected')),
    trade_ref text, -- 外部交易參考號
    created_at timestamptz DEFAULT now()
) PARTITION BY RANGE (executed_at);

-- 創建按月分區表（提升查詢效能）
CREATE TABLE tournament_trades_2025_01 PARTITION OF tournament_trades
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE tournament_trades_2025_02 PARTITION OF tournament_trades
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE tournament_trades_2025_03 PARTITION OF tournament_trades
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
-- 根據需要添加更多分區

-- 交易表高效能索引
CREATE INDEX idx_tournament_trades_user_time ON tournament_trades(tournament_id, user_id, executed_at DESC);
CREATE INDEX idx_tournament_trades_symbol_time ON tournament_trades(tournament_id, symbol, executed_at DESC);
CREATE INDEX idx_tournament_trades_status ON tournament_trades(tournament_id, status);
CREATE INDEX idx_tournament_trades_side_time ON tournament_trades(tournament_id, side, executed_at DESC);

-- ========================================
-- 5. 錦標賽持倉表（支援實時更新）
-- ========================================

CREATE TABLE tournament_positions (
    tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    symbol text NOT NULL,
    qty numeric NOT NULL DEFAULT 0,
    avg_cost numeric NOT NULL DEFAULT 0,
    market_value numeric DEFAULT 0,
    last_trade_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    version integer DEFAULT 1, -- 樂觀鎖版本號
    PRIMARY KEY (tournament_id, user_id, symbol)
);

-- 持倉表索引優化
CREATE INDEX idx_tournament_positions_user ON tournament_positions(tournament_id, user_id);
CREATE INDEX idx_tournament_positions_symbol ON tournament_positions(tournament_id, symbol);
CREATE INDEX idx_tournament_positions_value ON tournament_positions(tournament_id, market_value DESC);

-- ========================================
-- 6. 錦標賽快照表（用於排行榜和統計）
-- ========================================

CREATE TABLE tournament_snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    as_of_date date NOT NULL,
    cash_balance numeric NOT NULL,
    equity_value numeric NOT NULL,
    total_assets numeric NOT NULL,
    daily_return numeric DEFAULT 0,
    twr_return numeric DEFAULT 0, -- 時間加權報酬率
    max_dd numeric DEFAULT 0, -- 最大回撤
    sharpe_ratio numeric DEFAULT 0,
    win_rate numeric DEFAULT 0,
    total_trades integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    UNIQUE(tournament_id, user_id, as_of_date)
);

-- 快照表索引（支援排行榜查詢）
CREATE INDEX idx_tournament_snapshots_leaderboard ON tournament_snapshots(tournament_id, as_of_date DESC, twr_return DESC);
CREATE INDEX idx_tournament_snapshots_user_history ON tournament_snapshots(tournament_id, user_id, as_of_date DESC);
CREATE INDEX idx_tournament_snapshots_daily_return ON tournament_snapshots(tournament_id, as_of_date DESC, daily_return DESC);

-- ========================================
-- 7. 審計日誌表（合規和監控）
-- ========================================

CREATE TABLE tournament_audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id uuid,
    user_id uuid,
    action text NOT NULL,
    details jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamptz DEFAULT now()
) PARTITION BY RANGE (created_at);

-- 審計日誌分區（按週分區）
CREATE TABLE tournament_audit_logs_2025_w01 PARTITION OF tournament_audit_logs
    FOR VALUES FROM ('2025-01-01') TO ('2025-01-08');
-- 根據需要添加更多分區

-- 審計索引
CREATE INDEX idx_tournament_audit_logs_tournament ON tournament_audit_logs(tournament_id, created_at DESC);
CREATE INDEX idx_tournament_audit_logs_user ON tournament_audit_logs(user_id, created_at DESC);
CREATE INDEX idx_tournament_audit_logs_action ON tournament_audit_logs(action, created_at DESC);

-- ========================================
-- 8. 高併發支援函數
-- ========================================

-- 原子性更新投資組合（買入）
CREATE OR REPLACE FUNCTION update_tournament_portfolio_buy(
    p_tournament_id uuid,
    p_user_id uuid,
    p_amount numeric
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tournament_portfolios 
    SET 
        cash_balance = cash_balance - p_amount,
        equity_value = equity_value + p_amount,
        updated_at = now(),
        version = version + 1
    WHERE tournament_id = p_tournament_id 
      AND user_id = p_user_id;
      
    -- 檢查是否更新成功
    IF NOT FOUND THEN
        RAISE EXCEPTION '投資組合更新失敗：用戶 % 在錦標賽 % 中不存在', p_user_id, p_tournament_id;
    END IF;
END;
$$;

-- 原子性更新投資組合（賣出）
CREATE OR REPLACE FUNCTION update_tournament_portfolio_sell(
    p_tournament_id uuid,
    p_user_id uuid,
    p_amount numeric
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tournament_portfolios 
    SET 
        cash_balance = cash_balance + p_amount,
        equity_value = equity_value - p_amount,
        updated_at = now(),
        version = version + 1
    WHERE tournament_id = p_tournament_id 
      AND user_id = p_user_id;
      
    -- 檢查是否更新成功
    IF NOT FOUND THEN
        RAISE EXCEPTION '投資組合更新失敗：用戶 % 在錦標賽 % 中不存在', p_user_id, p_tournament_id;
    END IF;
END;
$$;

-- 原子性更新持倉
CREATE OR REPLACE FUNCTION update_tournament_position(
    p_tournament_id uuid,
    p_user_id uuid,
    p_symbol text,
    p_side text,
    p_qty numeric,
    p_price numeric
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    current_qty numeric := 0;
    current_avg_cost numeric := 0;
    new_qty numeric;
    new_avg_cost numeric;
BEGIN
    -- 獲取當前持倉
    SELECT qty, avg_cost 
    INTO current_qty, current_avg_cost
    FROM tournament_positions
    WHERE tournament_id = p_tournament_id 
      AND user_id = p_user_id 
      AND symbol = p_symbol;
    
    -- 計算新的數量和成本
    IF p_side = 'buy' THEN
        new_qty := COALESCE(current_qty, 0) + p_qty;
        -- 加權平均成本計算
        IF COALESCE(current_qty, 0) > 0 THEN
            new_avg_cost := ((COALESCE(current_qty, 0) * COALESCE(current_avg_cost, 0)) + (p_qty * p_price)) / new_qty;
        ELSE
            new_avg_cost := p_price;
        END IF;
    ELSE -- sell
        new_qty := COALESCE(current_qty, 0) - p_qty;
        new_avg_cost := COALESCE(current_avg_cost, 0); -- 賣出時成本不變
        
        -- 檢查持股是否充足
        IF new_qty < 0 THEN
            RAISE EXCEPTION '持股不足：當前持股 %，嘗試賣出 %', COALESCE(current_qty, 0), p_qty;
        END IF;
    END IF;
    
    -- 更新或插入持倉記錄
    INSERT INTO tournament_positions (tournament_id, user_id, symbol, qty, avg_cost, last_trade_at, updated_at, version)
    VALUES (p_tournament_id, p_user_id, p_symbol, new_qty, new_avg_cost, now(), now(), 1)
    ON CONFLICT (tournament_id, user_id, symbol)
    DO UPDATE SET
        qty = new_qty,
        avg_cost = new_avg_cost,
        last_trade_at = now(),
        updated_at = now(),
        version = tournament_positions.version + 1;
        
    -- 清理零持倉記錄
    DELETE FROM tournament_positions 
    WHERE tournament_id = p_tournament_id 
      AND user_id = p_user_id 
      AND symbol = p_symbol 
      AND qty <= 0;
END;
$$;

-- 獲取錦標賽實時統計
CREATE OR REPLACE FUNCTION get_tournament_stats(p_tournament_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    stats jsonb;
BEGIN
    SELECT jsonb_build_object(
        'tournament_id', p_tournament_id,
        'total_participants', COUNT(DISTINCT tp.user_id),
        'total_trades', (
            SELECT COUNT(*) FROM tournament_trades tt 
            WHERE tt.tournament_id = p_tournament_id 
              AND tt.status = 'executed'
        ),
        'total_volume', (
            SELECT COALESCE(SUM(total_amount), 0) FROM tournament_trades tt 
            WHERE tt.tournament_id = p_tournament_id 
              AND tt.status = 'executed'
        ),
        'avg_portfolio_value', COALESCE(AVG(tp.total_assets), 0),
        'top_performer', (
            SELECT user_id FROM tournament_portfolios tp2
            WHERE tp2.tournament_id = p_tournament_id
            ORDER BY tp2.total_assets DESC
            LIMIT 1
        ),
        'last_updated', now()
    )
    INTO stats
    FROM tournament_portfolios tp
    WHERE tp.tournament_id = p_tournament_id;
    
    RETURN COALESCE(stats, '{}'::jsonb);
END;
$$;

-- ========================================
-- 9. 性能優化設置
-- ========================================

-- 啟用行級安全性（可選）
-- ALTER TABLE tournament_trades ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE tournament_portfolios ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE tournament_positions ENABLE ROW LEVEL SECURITY;

-- 設置表的統計信息收集
ALTER TABLE tournament_trades SET (autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE tournament_portfolios SET (autovacuum_analyze_scale_factor = 0.1);
ALTER TABLE tournament_positions SET (autovacuum_analyze_scale_factor = 0.1);

-- 設置並發級別（根據實際需求調整）
-- SET max_connections = 200;
-- SET shared_buffers = '256MB';
-- SET effective_cache_size = '1GB';

-- ========================================
-- 10. 初始數據和測試
-- ========================================

-- 插入測試錦標賽
INSERT INTO tournaments (
    id, 
    name, 
    description, 
    status, 
    starts_at, 
    ends_at, 
    entry_capital,
    max_participants,
    created_by
) VALUES (
    '12345678-1234-1234-1234-123456789001',
    '高併發測試錦標賽',
    '支援1000人同時交易的錦標賽',
    'active',
    now() - interval '1 day',
    now() + interval '30 days',
    1000000,
    1000,
    'test03'
), (
    '12345678-1234-1234-1234-123456789002',
    '科技股專項賽',
    '專注科技股投資的錦標賽',
    'active',
    now() - interval '1 day',
    now() + interval '30 days',
    500000,
    100,
    'test03'
);

-- 創建性能監控視圖
CREATE OR REPLACE VIEW tournament_performance_monitor AS
SELECT 
    t.id as tournament_id,
    t.name as tournament_name,
    t.status,
    COUNT(DISTINCT tm.user_id) as participants,
    COUNT(tt.id) as total_trades,
    SUM(CASE WHEN tt.executed_at > now() - interval '1 minute' THEN 1 ELSE 0 END) as trades_last_minute,
    SUM(CASE WHEN tt.executed_at > now() - interval '5 minutes' THEN 1 ELSE 0 END) as trades_last_5min,
    AVG(tp.total_assets) as avg_portfolio_value,
    MAX(tp.total_assets) as max_portfolio_value,
    MIN(tp.total_assets) as min_portfolio_value
FROM tournaments t
LEFT JOIN tournament_members tm ON t.id = tm.tournament_id
LEFT JOIN tournament_trades tt ON t.id = tt.tournament_id AND tt.status = 'executed'
LEFT JOIN tournament_portfolios tp ON t.id = tp.tournament_id
WHERE t.status = 'active'
GROUP BY t.id, t.name, t.status;

COMMENT ON TABLE tournaments IS '錦標賽基本信息表';
COMMENT ON TABLE tournament_trades IS '錦標賽交易表（按月分區，支援高併發）';
COMMENT ON TABLE tournament_portfolios IS '錦標賽投資組合表（樂觀鎖版本控制）';
COMMENT ON TABLE tournament_positions IS '錦標賽持倉表（實時更新）';
COMMENT ON TABLE tournament_snapshots IS '錦標賽快照表（排行榜和統計）';
COMMENT ON VIEW tournament_performance_monitor IS '錦標賽性能監控視圖';

-- 完成
SELECT '✅ 錦標賽高併發數據庫架構創建完成' as status;