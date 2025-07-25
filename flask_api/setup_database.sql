-- 設置股票交易平台所需的數據表
-- 在 Supabase SQL Editor 中執行此腳本

-- 1. 用戶餘額表
CREATE TABLE IF NOT EXISTS user_balances (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    balance DECIMAL(15,2) DEFAULT 100000.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 交易記錄表
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('buy', 'sell')),
    shares DECIMAL(10,4) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    fee DECIMAL(10,2) DEFAULT 0,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 股價快取表 (可選，主要用 Redis)
CREATE TABLE IF NOT EXISTS stock_prices_cache (
    symbol TEXT PRIMARY KEY,
    name TEXT,
    current_price DECIMAL(10,2),
    previous_close DECIMAL(10,2),
    change_amount DECIMAL(10,2),
    change_percent DECIMAL(5,2),
    currency TEXT DEFAULT 'USD',
    cached_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 用戶投資組合快照表 (用於歷史記錄)
CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    total_value DECIMAL(15,2),
    cash_balance DECIMAL(15,2),
    market_value DECIMAL(15,2),
    total_return DECIMAL(15,2),
    total_return_percent DECIMAL(5,2),
    snapshot_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_symbol ON transactions(symbol);
CREATE INDEX IF NOT EXISTS idx_transactions_executed_at ON transactions(executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_portfolio_snapshots_user_id ON portfolio_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_snapshots_date ON portfolio_snapshots(snapshot_date DESC);

-- 設定 Row Level Security (RLS) 政策
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_snapshots ENABLE ROW LEVEL SECURITY;

-- 用戶只能存取自己的資料
CREATE POLICY "Users can only access their own balance" 
ON user_balances FOR ALL 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own transactions" 
ON transactions FOR ALL 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own portfolio snapshots" 
ON portfolio_snapshots FOR ALL 
USING (auth.uid() = user_id);

-- 股價快取表所有人都可以讀取，但只有後端服務可以寫入
CREATE POLICY "Anyone can read stock prices" 
ON stock_prices_cache FOR SELECT 
USING (true);

-- 創建觸發器自動更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_balances_updated_at 
BEFORE UPDATE ON user_balances 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入一些測試用戶的初始餘額 (僅用於開發測試)
-- 注意：在生產環境中應該通過註冊流程自動創建
INSERT INTO user_balances (user_id, balance) 
VALUES ('user_demo_001', 100000.00)
ON CONFLICT (user_id) DO NOTHING;

-- 創建視圖來簡化常用查詢
CREATE OR REPLACE VIEW user_portfolio_summary AS
SELECT 
    ub.user_id,
    ub.balance as cash_balance,
    COALESCE(SUM(CASE WHEN t.action = 'buy' THEN t.total_amount ELSE -t.total_amount END), 0) as total_invested,
    COUNT(DISTINCT t.symbol) as stocks_held,
    MAX(t.executed_at) as last_trade_date
FROM user_balances ub
LEFT JOIN transactions t ON ub.user_id = t.user_id
GROUP BY ub.user_id, ub.balance;

-- 創建函數來計算用戶持倉
CREATE OR REPLACE FUNCTION get_user_positions(p_user_id UUID)
RETURNS TABLE (
    symbol TEXT,
    total_shares DECIMAL,
    average_cost DECIMAL,
    total_cost DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.symbol,
        SUM(CASE WHEN t.action = 'buy' THEN t.shares ELSE -t.shares END) as total_shares,
        CASE 
            WHEN SUM(CASE WHEN t.action = 'buy' THEN t.shares ELSE -t.shares END) > 0 
            THEN SUM(CASE WHEN t.action = 'buy' THEN t.total_amount ELSE 0 END) / 
                 SUM(CASE WHEN t.action = 'buy' THEN t.shares ELSE 0 END)
            ELSE 0 
        END as average_cost,
        SUM(CASE WHEN t.action = 'buy' THEN t.total_amount ELSE -t.total_amount END) as total_cost
    FROM transactions t
    WHERE t.user_id = p_user_id
    GROUP BY t.symbol
    HAVING SUM(CASE WHEN t.action = 'buy' THEN t.shares ELSE -t.shares END) > 0.001;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE user_balances IS '用戶現金餘額表';
COMMENT ON TABLE transactions IS '股票交易記錄表';
COMMENT ON TABLE stock_prices_cache IS '股價快取表';
COMMENT ON TABLE portfolio_snapshots IS '投資組合歷史快照表';
COMMENT ON FUNCTION get_user_positions IS '計算用戶當前持倉的函數';