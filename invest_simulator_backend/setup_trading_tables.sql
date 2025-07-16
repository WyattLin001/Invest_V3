-- 投資模擬交易平台 - 資料庫設置腳本
-- 使用現有的 Supabase 專案建立交易相關資料表

-- 確保 UUID 擴展已啟用
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 建立交易用戶資料表 (擴展現有的 user_profiles 或建立新的)
CREATE TABLE IF NOT EXISTS trading_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255), -- 可選，與現有系統整合
    cash_balance DECIMAL(15, 2) DEFAULT 1000000.00, -- 初始模擬資金
    total_assets DECIMAL(15, 2) DEFAULT 1000000.00, -- 總資產
    total_profit DECIMAL(15, 2) DEFAULT 0.00, -- 累計實現損益
    cumulative_return DECIMAL(8, 4) DEFAULT 0.00, -- 累計報酬率 (%)
    invite_code VARCHAR(10) UNIQUE NOT NULL, -- 邀請碼
    avatar_url TEXT, -- 頭像 URL
    is_active BOOLEAN DEFAULT TRUE, -- 帳戶是否啟用
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 額外的投資相關欄位
    risk_tolerance VARCHAR(20) DEFAULT 'moderate', -- 風險承受度: conservative, moderate, aggressive
    investment_experience VARCHAR(20) DEFAULT 'beginner', -- 投資經驗: beginner, intermediate, advanced
    preferred_sectors TEXT[], -- 偏好的投資板塊
    notification_preferences JSONB DEFAULT '{"email": true, "push": true, "sms": false}' -- 通知偏好
);

-- 持倉資料表
CREATE TABLE IF NOT EXISTS trading_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL, -- 股票代號
    stock_name VARCHAR(100), -- 股票名稱
    quantity INTEGER NOT NULL, -- 持有股數
    average_cost DECIMAL(10, 4) NOT NULL, -- 平均成本
    market VARCHAR(10) DEFAULT 'TW', -- 市場別: TW, TWO, US 等
    sector VARCHAR(50), -- 板塊
    industry VARCHAR(100), -- 產業
    first_buy_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(), -- 首次買入日期
    last_update_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(), -- 最後更新日期
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 唯一約束：每個用戶的每個股票只能有一個持倉記錄
    UNIQUE(user_id, symbol)
);

-- 交易紀錄資料表
CREATE TABLE IF NOT EXISTS trading_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL, -- 股票代號
    stock_name VARCHAR(100), -- 股票名稱
    action VARCHAR(20) NOT NULL CHECK (action IN ('buy', 'sell', 'dividend', 'bonus', 'referral')), -- 交易類型
    quantity INTEGER NOT NULL, -- 交易股數
    price DECIMAL(10, 4) NOT NULL, -- 交易價格
    total_amount DECIMAL(15, 2) NOT NULL, -- 交易總金額
    broker_fee DECIMAL(10, 4) DEFAULT 0.00, -- 手續費
    tax DECIMAL(10, 4) DEFAULT 0.00, -- 交易稅
    realized_pnl DECIMAL(15, 2) DEFAULT 0.00, -- 實現損益
    order_type VARCHAR(20) DEFAULT 'market', -- 訂單類型: market, limit
    order_status VARCHAR(20) DEFAULT 'executed', -- 訂單狀態: executed, pending, cancelled
    market VARCHAR(10) DEFAULT 'TW', -- 市場別
    notes TEXT, -- 備註
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 索引
    INDEX idx_transactions_user_id (user_id),
    INDEX idx_transactions_symbol (symbol),
    INDEX idx_transactions_time (transaction_time),
    INDEX idx_transactions_action (action)
);

-- 股票基本資料表
CREATE TABLE IF NOT EXISTS trading_stocks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(10) UNIQUE NOT NULL, -- 股票代號
    name VARCHAR(100) NOT NULL, -- 股票名稱
    name_en VARCHAR(100), -- 英文名稱
    market VARCHAR(10) NOT NULL DEFAULT 'TW', -- 市場別
    sector VARCHAR(50), -- 板塊
    industry VARCHAR(100), -- 產業
    market_cap BIGINT, -- 市值
    outstanding_shares BIGINT, -- 流通股數
    listing_date DATE, -- 上市日期
    currency VARCHAR(3) DEFAULT 'TWD', -- 幣別
    is_etf BOOLEAN DEFAULT FALSE, -- 是否為 ETF
    is_active BOOLEAN DEFAULT TRUE, -- 是否可交易
    description TEXT, -- 公司描述
    website VARCHAR(255), -- 官網
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 索引
    INDEX idx_stocks_symbol (symbol),
    INDEX idx_stocks_market (market),
    INDEX idx_stocks_sector (sector),
    INDEX idx_stocks_active (is_active)
);

-- 績效快照資料表 (用於排行榜計算)
CREATE TABLE IF NOT EXISTS trading_performance_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL, -- 快照日期
    total_assets DECIMAL(15, 2) NOT NULL, -- 總資產
    cash_balance DECIMAL(15, 2) NOT NULL, -- 現金餘額
    position_value DECIMAL(15, 2) NOT NULL, -- 持倉市值
    daily_return DECIMAL(8, 4) DEFAULT 0.00, -- 當日報酬率
    cumulative_return DECIMAL(8, 4) DEFAULT 0.00, -- 累計報酬率
    benchmark_return DECIMAL(8, 4) DEFAULT 0.00, -- 基準報酬率 (如台灣加權指數)
    alpha DECIMAL(8, 4) DEFAULT 0.00, -- Alpha 值
    beta DECIMAL(8, 4) DEFAULT 1.00, -- Beta 值
    sharpe_ratio DECIMAL(8, 4) DEFAULT 0.00, -- 夏普比率
    volatility DECIMAL(8, 4) DEFAULT 0.00, -- 波動率
    max_drawdown DECIMAL(8, 4) DEFAULT 0.00, -- 最大回撤
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 唯一約束：每個用戶每天只能有一個快照
    UNIQUE(user_id, snapshot_date),
    
    -- 索引
    INDEX idx_performance_user_id (user_id),
    INDEX idx_performance_date (snapshot_date),
    INDEX idx_performance_return (cumulative_return)
);

-- 邀請關係資料表
CREATE TABLE IF NOT EXISTS trading_referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    invite_code VARCHAR(10) NOT NULL, -- 使用的邀請碼
    bonus_amount DECIMAL(15, 2) DEFAULT 100000.00, -- 獎勵金額
    bonus_awarded BOOLEAN DEFAULT FALSE, -- 是否已發放獎勵
    bonus_awarded_at TIMESTAMP WITH TIME ZONE, -- 獎勵發放時間
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 唯一約束：每個邀請關係只能存在一次
    UNIQUE(inviter_id, invitee_id),
    
    -- 索引
    INDEX idx_referrals_inviter (inviter_id),
    INDEX idx_referrals_invitee (invitee_id),
    INDEX idx_referrals_code (invite_code)
);

-- 用戶關注股票清單
CREATE TABLE IF NOT EXISTS trading_watchlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL, -- 股票代號
    stock_name VARCHAR(100), -- 股票名稱
    target_price DECIMAL(10, 4), -- 目標價格
    stop_loss_price DECIMAL(10, 4), -- 停損價格
    notes TEXT, -- 備註
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 唯一約束：每個用戶每檔股票只能關注一次
    UNIQUE(user_id, symbol),
    
    -- 索引
    INDEX idx_watchlist_user_id (user_id),
    INDEX idx_watchlist_symbol (symbol)
);

-- 交易提醒資料表
CREATE TABLE IF NOT EXISTS trading_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL, -- 股票代號
    alert_type VARCHAR(20) NOT NULL CHECK (alert_type IN ('price_above', 'price_below', 'volume_surge', 'news')), -- 提醒類型
    threshold_value DECIMAL(10, 4), -- 閾值
    message TEXT, -- 提醒訊息
    is_active BOOLEAN DEFAULT TRUE, -- 是否啟用
    triggered_at TIMESTAMP WITH TIME ZONE, -- 觸發時間
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 索引
    INDEX idx_alerts_user_id (user_id),
    INDEX idx_alerts_symbol (symbol),
    INDEX idx_alerts_active (is_active)
);

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_trading_users_phone ON trading_users(phone);
CREATE INDEX IF NOT EXISTS idx_trading_users_invite_code ON trading_users(invite_code);
CREATE INDEX IF NOT EXISTS idx_trading_users_created_at ON trading_users(created_at);

-- 建立視圖以便查詢
CREATE OR REPLACE VIEW trading_user_portfolio_summary AS
SELECT 
    tu.id,
    tu.name,
    tu.phone,
    tu.cash_balance,
    tu.total_assets,
    tu.total_profit,
    tu.cumulative_return,
    tu.created_at,
    COUNT(tp.id) as position_count,
    COALESCE(SUM(tp.quantity * tp.average_cost), 0) as total_investment,
    COALESCE(SUM(tp.quantity * tp.average_cost), 0) + tu.cash_balance as calculated_total_assets
FROM trading_users tu
LEFT JOIN trading_positions tp ON tu.id = tp.user_id
GROUP BY tu.id, tu.name, tu.phone, tu.cash_balance, tu.total_assets, tu.total_profit, tu.cumulative_return, tu.created_at;

-- 交易統計視圖
CREATE OR REPLACE VIEW trading_user_statistics AS
SELECT 
    tu.id,
    tu.name,
    COUNT(tt.id) as total_trades,
    COUNT(CASE WHEN tt.action = 'buy' THEN 1 END) as buy_trades,
    COUNT(CASE WHEN tt.action = 'sell' THEN 1 END) as sell_trades,
    COUNT(CASE WHEN tt.realized_pnl > 0 THEN 1 END) as profitable_trades,
    COUNT(CASE WHEN tt.realized_pnl < 0 THEN 1 END) as loss_trades,
    COALESCE(SUM(tt.realized_pnl), 0) as total_realized_pnl,
    COALESCE(SUM(tt.broker_fee + tt.tax), 0) as total_fees,
    COALESCE(AVG(tt.realized_pnl), 0) as avg_pnl_per_trade,
    CASE 
        WHEN COUNT(CASE WHEN tt.action = 'sell' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN tt.realized_pnl > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN tt.action = 'sell' THEN 1 END)
        ELSE 0 
    END as win_rate
FROM trading_users tu
LEFT JOIN trading_transactions tt ON tu.id = tt.user_id
WHERE tt.action IN ('buy', 'sell') OR tt.action IS NULL
GROUP BY tu.id, tu.name;

-- 排行榜視圖
CREATE OR REPLACE VIEW trading_leaderboard AS
SELECT 
    tu.id,
    tu.name,
    tu.total_assets,
    tu.cumulative_return,
    tu.created_at,
    ROW_NUMBER() OVER (ORDER BY tu.cumulative_return DESC) as rank_by_return,
    ROW_NUMBER() OVER (ORDER BY tu.total_assets DESC) as rank_by_assets,
    ROW_NUMBER() OVER (ORDER BY tu.total_profit DESC) as rank_by_profit
FROM trading_users tu
WHERE tu.is_active = TRUE
ORDER BY tu.cumulative_return DESC;

-- 建立更新時間觸發器函數
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 建立觸發器
DROP TRIGGER IF EXISTS update_trading_users_updated_at ON trading_users;
CREATE TRIGGER update_trading_users_updated_at
    BEFORE UPDATE ON trading_users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_trading_positions_updated_at ON trading_positions;
CREATE TRIGGER update_trading_positions_updated_at
    BEFORE UPDATE ON trading_positions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_trading_stocks_updated_at ON trading_stocks;
CREATE TRIGGER update_trading_stocks_updated_at
    BEFORE UPDATE ON trading_stocks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_trading_watchlists_updated_at ON trading_watchlists;
CREATE TRIGGER update_trading_watchlists_updated_at
    BEFORE UPDATE ON trading_watchlists
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 插入示例股票資料
INSERT INTO trading_stocks (symbol, name, name_en, market, sector, industry, is_active) VALUES
    ('2330', '台灣積體電路製造股份有限公司', 'Taiwan Semiconductor Manufacturing Company Limited', 'TW', 'Technology', 'Semiconductors', TRUE),
    ('2317', '鴻海精密工業股份有限公司', 'Hon Hai Precision Industry Co., Ltd.', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('2454', '聯發科技股份有限公司', 'MediaTek Inc.', 'TW', 'Technology', 'Semiconductors', TRUE),
    ('2881', '富邦金融控股股份有限公司', 'Fubon Financial Holding Co., Ltd.', 'TW', 'Financial Services', 'Banks', TRUE),
    ('2882', '國泰金融控股股份有限公司', 'Cathay Financial Holding Co., Ltd.', 'TW', 'Financial Services', 'Banks', TRUE),
    ('2886', '兆豐金融控股股份有限公司', 'Mega Financial Holding Co., Ltd.', 'TW', 'Financial Services', 'Banks', TRUE),
    ('2891', '中國信託金融控股股份有限公司', 'CTBC Financial Holding Co., Ltd.', 'TW', 'Financial Services', 'Banks', TRUE),
    ('6505', '台灣化學纖維股份有限公司', 'Formosa Petrochemical Corporation', 'TW', 'Energy', 'Oil & Gas Refining', TRUE),
    ('3008', '大立光電股份有限公司', 'Largan Precision Co., Ltd.', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('2308', '台達電子工業股份有限公司', 'Delta Electronics, Inc.', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('1303', '南亞塑膠工業股份有限公司', 'Nan Ya Plastics Corporation', 'TW', 'Basic Materials', 'Chemicals', TRUE),
    ('1301', '台灣塑膠工業股份有限公司', 'Formosa Plastics Corporation', 'TW', 'Basic Materials', 'Chemicals', TRUE),
    ('2412', '中華電信股份有限公司', 'Chunghwa Telecom Co., Ltd.', 'TW', 'Communication Services', 'Telecom Services', TRUE),
    ('2603', '長榮海運股份有限公司', 'Evergreen Marine Corporation', 'TW', 'Industrials', 'Marine Shipping', TRUE),
    ('2609', '陽明海運股份有限公司', 'Yang Ming Marine Transport Corporation', 'TW', 'Industrials', 'Marine Shipping', TRUE),
    ('2618', '長榮航空股份有限公司', 'EVA Airways Corporation', 'TW', 'Industrials', 'Airlines', TRUE),
    ('2002', '中國鋼鐵股份有限公司', 'China Steel Corporation', 'TW', 'Basic Materials', 'Steel', TRUE),
    ('2207', '和泰汽車股份有限公司', 'Hotai Motor Co., Ltd.', 'TW', 'Consumer Cyclical', 'Auto Manufacturers', TRUE),
    ('2474', '可成科技股份有限公司', 'Catcher Technology Co., Ltd.', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('2892', '第一金融控股股份有限公司', 'First Financial Holding Co., Ltd.', 'TW', 'Financial Services', 'Banks', TRUE),
    ('0050', '元大台灣卓越50證券投資信託基金', 'Yuanta Taiwan Top 50 ETF', 'TW', 'Financial Services', 'ETF', TRUE),
    ('0056', '元大台灣高股息證券投資信託基金', 'Yuanta Taiwan Dividend Plus ETF', 'TW', 'Financial Services', 'ETF', TRUE)
ON CONFLICT (symbol) DO UPDATE SET
    name = EXCLUDED.name,
    name_en = EXCLUDED.name_en,
    market = EXCLUDED.market,
    sector = EXCLUDED.sector,
    industry = EXCLUDED.industry,
    updated_at = NOW();

-- 建立 RLS (Row Level Security) 策略
-- 確保用戶只能看到自己的資料
ALTER TABLE trading_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_performance_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_alerts ENABLE ROW LEVEL SECURITY;

-- 建立政策 (這些政策可以根據需要調整)
-- 允許用戶查看和更新自己的資料
CREATE POLICY "Users can view their own data" ON trading_users
    FOR SELECT USING (auth.uid()::text = id::text);

CREATE POLICY "Users can update their own data" ON trading_users
    FOR UPDATE USING (auth.uid()::text = id::text);

-- 持倉資料政策
CREATE POLICY "Users can view their own positions" ON trading_positions
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can manage their own positions" ON trading_positions
    FOR ALL USING (auth.uid()::text = user_id::text);

-- 交易記錄政策
CREATE POLICY "Users can view their own transactions" ON trading_transactions
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can create their own transactions" ON trading_transactions
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

-- 股票資料是公開的
CREATE POLICY "Anyone can view stocks" ON trading_stocks
    FOR SELECT USING (true);

-- 排行榜相關資料可以公開查看（但不顯示敏感資訊）
CREATE POLICY "Anyone can view leaderboard" ON trading_performance_snapshots
    FOR SELECT USING (true);

-- 建立服務角色的政策，允許後端服務完全訪問
CREATE POLICY "Service role can do anything" ON trading_users
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can do anything" ON trading_positions
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can do anything" ON trading_transactions
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can do anything" ON trading_performance_snapshots
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can do anything" ON trading_referrals
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can do anything" ON trading_watchlists
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can do anything" ON trading_alerts
    FOR ALL USING (auth.role() = 'service_role');

-- 建立功能函數
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
BEGIN
    RETURN upper(substring(md5(random()::text) from 1 for 8));
END;
$$ LANGUAGE plpgsql;

-- 建立計算用戶總資產的函數
CREATE OR REPLACE FUNCTION calculate_user_total_assets(user_uuid UUID)
RETURNS DECIMAL AS $$
DECLARE
    cash_balance DECIMAL;
    position_value DECIMAL;
    total_assets DECIMAL;
BEGIN
    -- 獲取現金餘額
    SELECT tu.cash_balance INTO cash_balance
    FROM trading_users tu
    WHERE tu.id = user_uuid;
    
    -- 計算持倉市值 (這裡使用平均成本，實際應用中需要即時價格)
    SELECT COALESCE(SUM(tp.quantity * tp.average_cost), 0) INTO position_value
    FROM trading_positions tp
    WHERE tp.user_id = user_uuid;
    
    total_assets := COALESCE(cash_balance, 0) + COALESCE(position_value, 0);
    
    RETURN total_assets;
END;
$$ LANGUAGE plpgsql;

-- 建立績效計算函數
CREATE OR REPLACE FUNCTION calculate_user_performance(user_uuid UUID)
RETURNS TABLE(
    total_assets DECIMAL,
    total_profit DECIMAL,
    cumulative_return DECIMAL,
    position_count INTEGER,
    total_trades INTEGER,
    win_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        calculate_user_total_assets(user_uuid) as total_assets,
        COALESCE(SUM(tt.realized_pnl), 0) as total_profit,
        CASE 
            WHEN calculate_user_total_assets(user_uuid) > 0 
            THEN ((calculate_user_total_assets(user_uuid) - 1000000) / 1000000 * 100)
            ELSE 0 
        END as cumulative_return,
        COUNT(DISTINCT tp.symbol)::INTEGER as position_count,
        COUNT(tt.id)::INTEGER as total_trades,
        CASE 
            WHEN COUNT(CASE WHEN tt.action = 'sell' THEN 1 END) > 0 
            THEN COUNT(CASE WHEN tt.realized_pnl > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN tt.action = 'sell' THEN 1 END)
            ELSE 0 
        END as win_rate
    FROM trading_users tu
    LEFT JOIN trading_positions tp ON tu.id = tp.user_id
    LEFT JOIN trading_transactions tt ON tu.id = tt.user_id
    WHERE tu.id = user_uuid AND (tt.action IN ('buy', 'sell') OR tt.action IS NULL)
    GROUP BY tu.id;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- 建立測試資料 (可選，用於開發測試)
-- INSERT INTO trading_users (phone, name, cash_balance, total_assets, invite_code)
-- VALUES ('+886912345678', '測試用戶', 1000000.00, 1000000.00, generate_invite_code())
-- ON CONFLICT (phone) DO NOTHING;