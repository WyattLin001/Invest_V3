-- 錦標賽歷史績效數據庫架構
-- 用於存儲錦標賽參與者的每日績效快照數據

-- 錦標賽每日績效快照表
CREATE TABLE tournament_daily_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    snapshot_date DATE NOT NULL,
    
    -- 投資組合數據
    portfolio_value DECIMAL(15,2) NOT NULL,      -- 投資組合總價值
    cash_balance DECIMAL(15,2) NOT NULL,         -- 現金餘額
    invested_value DECIMAL(15,2) NOT NULL,       -- 投資價值
    total_return DECIMAL(15,2) NOT NULL,         -- 累計收益金額
    total_return_percentage DECIMAL(8,4) NOT NULL, -- 累計收益率
    daily_return DECIMAL(15,2) NOT NULL DEFAULT 0, -- 當日收益金額
    daily_return_percentage DECIMAL(8,4) NOT NULL DEFAULT 0, -- 當日收益率
    
    -- 績效指標
    max_drawdown DECIMAL(15,2) NOT NULL DEFAULT 0, -- 最大回撤金額
    max_drawdown_percentage DECIMAL(8,4) NOT NULL DEFAULT 0, -- 最大回撤百分比
    sharpe_ratio DECIMAL(8,4), -- 夏普比率
    volatility DECIMAL(8,4) NOT NULL DEFAULT 0,    -- 波動率
    
    -- 交易統計
    total_trades INTEGER NOT NULL DEFAULT 0,       -- 累計交易次數
    daily_trades INTEGER NOT NULL DEFAULT 0,       -- 當日交易次數
    win_rate DECIMAL(5,4) NOT NULL DEFAULT 0,      -- 勝率
    
    -- 排名資訊
    rank INTEGER NOT NULL,                          -- 當日排名
    total_participants INTEGER NOT NULL,           -- 總參與人數
    percentile DECIMAL(5,2) NOT NULL DEFAULT 0,    -- 百分位數
    
    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 唯一約束：每個用戶在每個錦標賽的每一天只能有一個快照
    UNIQUE(tournament_id, user_id, snapshot_date)
);

-- 錦標賽績效摘要表（可選，用於快速查詢最新狀態）
CREATE TABLE tournament_performance_summary (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    
    -- 最新績效數據
    latest_portfolio_value DECIMAL(15,2) NOT NULL,
    latest_return_percentage DECIMAL(8,4) NOT NULL,
    current_rank INTEGER NOT NULL,
    peak_portfolio_value DECIMAL(15,2) NOT NULL,     -- 歷史最高價值
    peak_return_percentage DECIMAL(8,4) NOT NULL,    -- 歷史最高收益率
    best_rank INTEGER NOT NULL,                      -- 最佳排名
    
    -- 統計數據
    total_snapshots INTEGER NOT NULL DEFAULT 0,
    first_snapshot_date DATE,
    latest_snapshot_date DATE,
    
    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 唯一約束
    UNIQUE(tournament_id, user_id)
);

-- 索引優化
CREATE INDEX idx_daily_snapshots_tournament_user ON tournament_daily_snapshots(tournament_id, user_id);
CREATE INDEX idx_daily_snapshots_date ON tournament_daily_snapshots(snapshot_date);
CREATE INDEX idx_daily_snapshots_tournament_date ON tournament_daily_snapshots(tournament_id, snapshot_date);
CREATE INDEX idx_daily_snapshots_rank ON tournament_daily_snapshots(tournament_id, snapshot_date, rank);

CREATE INDEX idx_performance_summary_tournament ON tournament_performance_summary(tournament_id);
CREATE INDEX idx_performance_summary_user ON tournament_performance_summary(user_id);
CREATE INDEX idx_performance_summary_rank ON tournament_performance_summary(tournament_id, current_rank);

-- Row Level Security (RLS) 政策
ALTER TABLE tournament_daily_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_performance_summary ENABLE ROW LEVEL SECURITY;

-- 用戶只能查看自己的績效快照
CREATE POLICY "users_can_view_own_snapshots" ON tournament_daily_snapshots
    FOR SELECT TO authenticated USING (user_id = auth.uid()::text);

-- 用戶只能創建自己的績效快照
CREATE POLICY "users_can_create_own_snapshots" ON tournament_daily_snapshots
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid()::text);

-- 用戶只能更新自己的績效快照
CREATE POLICY "users_can_update_own_snapshots" ON tournament_daily_snapshots
    FOR UPDATE TO authenticated USING (user_id = auth.uid()::text);

-- 管理員可以查看所有快照（用於排名計算）
CREATE POLICY "admin_can_view_all_snapshots" ON tournament_daily_snapshots
    FOR SELECT TO authenticated USING (
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin'
    );

-- 績效摘要類似政策
CREATE POLICY "users_can_view_own_summary" ON tournament_performance_summary
    FOR SELECT TO authenticated USING (user_id = auth.uid()::text);

CREATE POLICY "users_can_manage_own_summary" ON tournament_performance_summary
    FOR ALL TO authenticated USING (user_id = auth.uid()::text);

CREATE POLICY "admin_can_view_all_summary" ON tournament_performance_summary
    FOR SELECT TO authenticated USING (
        auth.jwt() ->> 'role' = 'admin' OR
        auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin'
    );

-- 觸發器：自動更新 updated_at 欄位
CREATE TRIGGER update_daily_snapshots_updated_at 
    BEFORE UPDATE ON tournament_daily_snapshots 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_performance_summary_updated_at 
    BEFORE UPDATE ON tournament_performance_summary 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 觸發器：自動更新績效摘要
CREATE OR REPLACE FUNCTION update_performance_summary()
RETURNS TRIGGER AS $$
BEGIN
    -- 當插入新的快照時，更新或創建績效摘要
    INSERT INTO tournament_performance_summary (
        tournament_id,
        user_id,
        latest_portfolio_value,
        latest_return_percentage,
        current_rank,
        peak_portfolio_value,
        peak_return_percentage,
        best_rank,
        total_snapshots,
        first_snapshot_date,
        latest_snapshot_date
    ) VALUES (
        NEW.tournament_id,
        NEW.user_id,
        NEW.portfolio_value,
        NEW.total_return_percentage,
        NEW.rank,
        NEW.portfolio_value,
        NEW.total_return_percentage,
        NEW.rank,
        1,
        NEW.snapshot_date,
        NEW.snapshot_date
    )
    ON CONFLICT (tournament_id, user_id) 
    DO UPDATE SET
        latest_portfolio_value = NEW.portfolio_value,
        latest_return_percentage = NEW.total_return_percentage,
        current_rank = NEW.rank,
        peak_portfolio_value = GREATEST(tournament_performance_summary.peak_portfolio_value, NEW.portfolio_value),
        peak_return_percentage = GREATEST(tournament_performance_summary.peak_return_percentage, NEW.total_return_percentage),
        best_rank = LEAST(tournament_performance_summary.best_rank, NEW.rank),
        total_snapshots = tournament_performance_summary.total_snapshots + 1,
        latest_snapshot_date = NEW.snapshot_date,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_performance_summary_trigger
    AFTER INSERT ON tournament_daily_snapshots
    FOR EACH ROW EXECUTE FUNCTION update_performance_summary();

-- 數據清理函數（可選，用於清理過舊的快照數據）
CREATE OR REPLACE FUNCTION cleanup_old_snapshots(days_to_keep INTEGER DEFAULT 365)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM tournament_daily_snapshots 
    WHERE snapshot_date < CURRENT_DATE - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 創建定期清理的計劃任務（需要 pg_cron 擴展）
-- SELECT cron.schedule('cleanup-tournament-snapshots', '0 2 * * 0', 'SELECT cleanup_old_snapshots(730);'); -- 每週清理2年前的數據

-- 範例查詢：獲取用戶在特定錦標賽的績效歷史
/*
SELECT 
    snapshot_date,
    portfolio_value,
    total_return_percentage,
    daily_return_percentage,
    rank,
    total_participants
FROM tournament_daily_snapshots 
WHERE tournament_id = 'your-tournament-id' 
AND user_id = 'your-user-id' 
ORDER BY snapshot_date ASC;
*/

-- 範例查詢：獲取錦標賽的排行榜（特定日期）
/*
SELECT 
    user_id,
    portfolio_value,
    total_return_percentage,
    rank,
    percentile
FROM tournament_daily_snapshots 
WHERE tournament_id = 'your-tournament-id' 
AND snapshot_date = '2024-12-01'
ORDER BY rank ASC;
*/