-- 投資模擬交易平台 - 分步驟資料庫設置
-- 第1步：基礎設置

-- 確保 UUID 擴展已啟用
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 建立交易用戶資料表
CREATE TABLE IF NOT EXISTS trading_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    cash_balance DECIMAL(15, 2) DEFAULT 1000000.00,
    total_assets DECIMAL(15, 2) DEFAULT 1000000.00,
    total_profit DECIMAL(15, 2) DEFAULT 0.00,
    cumulative_return DECIMAL(8, 4) DEFAULT 0.00,
    invite_code VARCHAR(10) UNIQUE NOT NULL,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    risk_tolerance VARCHAR(20) DEFAULT 'moderate',
    investment_experience VARCHAR(20) DEFAULT 'beginner',
    preferred_sectors TEXT[],
    notification_preferences JSONB DEFAULT '{"email": true, "push": true, "sms": false}'
);

-- 建立持倉資料表
CREATE TABLE IF NOT EXISTS trading_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    stock_name VARCHAR(100),
    quantity INTEGER NOT NULL,
    average_cost DECIMAL(10, 4) NOT NULL,
    market VARCHAR(10) DEFAULT 'TW',
    sector VARCHAR(50),
    industry VARCHAR(100),
    first_buy_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_update_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, symbol)
);

-- 建立交易紀錄資料表
CREATE TABLE IF NOT EXISTS trading_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    stock_name VARCHAR(100),
    action VARCHAR(20) NOT NULL CHECK (action IN ('buy', 'sell', 'dividend', 'bonus', 'referral')),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 4) NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL,
    broker_fee DECIMAL(10, 4) DEFAULT 0.00,
    tax DECIMAL(10, 4) DEFAULT 0.00,
    realized_pnl DECIMAL(15, 2) DEFAULT 0.00,
    order_type VARCHAR(20) DEFAULT 'market',
    order_status VARCHAR(20) DEFAULT 'executed',
    market VARCHAR(10) DEFAULT 'TW',
    notes TEXT,
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立股票基本資料表
CREATE TABLE IF NOT EXISTS trading_stocks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(10) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    market VARCHAR(10) NOT NULL DEFAULT 'TW',
    sector VARCHAR(50),
    industry VARCHAR(100),
    market_cap BIGINT,
    outstanding_shares BIGINT,
    listing_date DATE,
    currency VARCHAR(3) DEFAULT 'TWD',
    is_etf BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT,
    website VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立績效快照資料表
CREATE TABLE IF NOT EXISTS trading_performance_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    total_assets DECIMAL(15, 2) NOT NULL,
    cash_balance DECIMAL(15, 2) NOT NULL,
    position_value DECIMAL(15, 2) NOT NULL,
    daily_return DECIMAL(8, 4) DEFAULT 0.00,
    cumulative_return DECIMAL(8, 4) DEFAULT 0.00,
    benchmark_return DECIMAL(8, 4) DEFAULT 0.00,
    alpha DECIMAL(8, 4) DEFAULT 0.00,
    beta DECIMAL(8, 4) DEFAULT 1.00,
    sharpe_ratio DECIMAL(8, 4) DEFAULT 0.00,
    volatility DECIMAL(8, 4) DEFAULT 0.00,
    max_drawdown DECIMAL(8, 4) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, snapshot_date)
);

-- 建立邀請關係資料表
CREATE TABLE IF NOT EXISTS trading_referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    invite_code VARCHAR(10) NOT NULL,
    bonus_amount DECIMAL(15, 2) DEFAULT 100000.00,
    bonus_awarded BOOLEAN DEFAULT FALSE,
    bonus_awarded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(inviter_id, invitee_id)
);

-- 建立關注股票清單
CREATE TABLE IF NOT EXISTS trading_watchlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    stock_name VARCHAR(100),
    target_price DECIMAL(10, 4),
    stop_loss_price DECIMAL(10, 4),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, symbol)
);

-- 建立交易提醒資料表
CREATE TABLE IF NOT EXISTS trading_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES trading_users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    alert_type VARCHAR(20) NOT NULL CHECK (alert_type IN ('price_above', 'price_below', 'volume_surge', 'news')),
    threshold_value DECIMAL(10, 4),
    message TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    triggered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_trading_users_phone ON trading_users(phone);
CREATE INDEX IF NOT EXISTS idx_trading_users_invite_code ON trading_users(invite_code);
CREATE INDEX IF NOT EXISTS idx_trading_users_created_at ON trading_users(created_at);
CREATE INDEX IF NOT EXISTS idx_trading_positions_user_id ON trading_positions(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_positions_symbol ON trading_positions(symbol);
CREATE INDEX IF NOT EXISTS idx_trading_transactions_user_id ON trading_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_transactions_symbol ON trading_transactions(symbol);
CREATE INDEX IF NOT EXISTS idx_trading_transactions_time ON trading_transactions(transaction_time);
CREATE INDEX IF NOT EXISTS idx_trading_transactions_action ON trading_transactions(action);
CREATE INDEX IF NOT EXISTS idx_trading_stocks_symbol ON trading_stocks(symbol);
CREATE INDEX IF NOT EXISTS idx_trading_stocks_market ON trading_stocks(market);
CREATE INDEX IF NOT EXISTS idx_trading_stocks_sector ON trading_stocks(sector);
CREATE INDEX IF NOT EXISTS idx_trading_stocks_active ON trading_stocks(is_active);
CREATE INDEX IF NOT EXISTS idx_trading_performance_user_id ON trading_performance_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_performance_date ON trading_performance_snapshots(snapshot_date);
CREATE INDEX IF NOT EXISTS idx_trading_performance_return ON trading_performance_snapshots(cumulative_return);
CREATE INDEX IF NOT EXISTS idx_trading_referrals_inviter ON trading_referrals(inviter_id);
CREATE INDEX IF NOT EXISTS idx_trading_referrals_invitee ON trading_referrals(invitee_id);
CREATE INDEX IF NOT EXISTS idx_trading_referrals_code ON trading_referrals(invite_code);
CREATE INDEX IF NOT EXISTS idx_trading_watchlist_user_id ON trading_watchlists(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_watchlist_symbol ON trading_watchlists(symbol);
CREATE INDEX IF NOT EXISTS idx_trading_alerts_user_id ON trading_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_alerts_symbol ON trading_alerts(symbol);
CREATE INDEX IF NOT EXISTS idx_trading_alerts_active ON trading_alerts(is_active);

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

COMMIT;