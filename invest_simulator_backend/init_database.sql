-- Stock Trading Simulator Database Schema
-- This script creates the necessary tables for the trading simulator

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    cash_balance DECIMAL(15, 2) DEFAULT 1000000.00,
    total_assets DECIMAL(15, 2) DEFAULT 1000000.00,
    total_profit DECIMAL(15, 2) DEFAULT 0.00,
    cumulative_return DECIMAL(8, 4) DEFAULT 0.00,
    invite_code VARCHAR(8) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Positions table (user's current stock holdings)
CREATE TABLE IF NOT EXISTS positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    quantity INTEGER NOT NULL,
    average_cost DECIMAL(10, 4) NOT NULL,
    market VARCHAR(10) DEFAULT 'TW',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, symbol)
);

-- Transactions table (trading history)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('buy', 'sell', 'referral_bonus')),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 4) NOT NULL,
    fee DECIMAL(10, 4) DEFAULT 0.00,
    tax DECIMAL(10, 4) DEFAULT 0.00,
    realized_pnl DECIMAL(15, 2) DEFAULT 0.00,
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Stocks table (stock information)
CREATE TABLE IF NOT EXISTS stocks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(10) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    market VARCHAR(10) NOT NULL DEFAULT 'TW',
    sector VARCHAR(50),
    industry VARCHAR(50),
    market_cap BIGINT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance snapshots table (for rankings calculation)
CREATE TABLE IF NOT EXISTS performance_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_assets DECIMAL(15, 2) NOT NULL,
    return_rate DECIMAL(8, 4) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, date)
);

-- Referrals table (friend invitation tracking)
CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bonus_awarded BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(inviter_id, invitee_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_invite_code ON users(invite_code);
CREATE INDEX IF NOT EXISTS idx_positions_user_id ON positions(user_id);
CREATE INDEX IF NOT EXISTS idx_positions_symbol ON positions(symbol);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_symbol ON transactions(symbol);
CREATE INDEX IF NOT EXISTS idx_transactions_time ON transactions(transaction_time);
CREATE INDEX IF NOT EXISTS idx_stocks_symbol ON stocks(symbol);
CREATE INDEX IF NOT EXISTS idx_stocks_market ON stocks(market);
CREATE INDEX IF NOT EXISTS idx_performance_user_id ON performance_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_performance_date ON performance_snapshots(date);
CREATE INDEX IF NOT EXISTS idx_referrals_inviter ON referrals(inviter_id);
CREATE INDEX IF NOT EXISTS idx_referrals_invitee ON referrals(invitee_id);

-- Insert sample stock data
INSERT INTO stocks (symbol, name, market, sector, industry, is_active) VALUES
    ('2330', '台積電', 'TW', 'Technology', 'Semiconductors', TRUE),
    ('2317', '鴻海', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('2454', '聯發科', 'TW', 'Technology', 'Semiconductors', TRUE),
    ('2881', '富邦金', 'TW', 'Financial Services', 'Banks', TRUE),
    ('2882', '國泰金', 'TW', 'Financial Services', 'Banks', TRUE),
    ('2886', '兆豐金', 'TW', 'Financial Services', 'Banks', TRUE),
    ('2891', '中信金', 'TW', 'Financial Services', 'Banks', TRUE),
    ('6505', '台塑化', 'TW', 'Energy', 'Oil & Gas Refining', TRUE),
    ('3008', '大立光', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('2308', '台達電', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('1303', '南亞', 'TW', 'Basic Materials', 'Chemicals', TRUE),
    ('1301', '台塑', 'TW', 'Basic Materials', 'Chemicals', TRUE),
    ('2412', '中華電', 'TW', 'Communication Services', 'Telecom Services', TRUE),
    ('2603', '長榮', 'TW', 'Industrials', 'Marine Shipping', TRUE),
    ('2609', '陽明', 'TW', 'Industrials', 'Marine Shipping', TRUE),
    ('2618', '長榮航', 'TW', 'Industrials', 'Airlines', TRUE),
    ('2002', '中鋼', 'TW', 'Basic Materials', 'Steel', TRUE),
    ('2207', '和泰車', 'TW', 'Consumer Cyclical', 'Auto Manufacturers', TRUE),
    ('2474', '可成', 'TW', 'Technology', 'Electronic Equipment', TRUE),
    ('2892', '第一金', 'TW', 'Financial Services', 'Banks', TRUE)
ON CONFLICT (symbol) DO UPDATE SET
    name = EXCLUDED.name,
    market = EXCLUDED.market,
    sector = EXCLUDED.sector,
    industry = EXCLUDED.industry,
    updated_at = NOW();

-- Create functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamp updates
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_positions_updated_at ON positions;
CREATE TRIGGER update_positions_updated_at
    BEFORE UPDATE ON positions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_stocks_updated_at ON stocks;
CREATE TRIGGER update_stocks_updated_at
    BEFORE UPDATE ON stocks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create views for common queries
CREATE OR REPLACE VIEW user_portfolio_summary AS
SELECT 
    u.id,
    u.name,
    u.phone,
    u.cash_balance,
    u.total_assets,
    u.total_profit,
    u.cumulative_return,
    COUNT(p.id) as position_count,
    COALESCE(SUM(p.quantity * p.average_cost), 0) as total_investment
FROM users u
LEFT JOIN positions p ON u.id = p.user_id
GROUP BY u.id, u.name, u.phone, u.cash_balance, u.total_assets, u.total_profit, u.cumulative_return;

CREATE OR REPLACE VIEW trading_summary AS
SELECT 
    u.id,
    u.name,
    COUNT(t.id) as total_trades,
    COUNT(CASE WHEN t.action = 'buy' THEN 1 END) as buy_trades,
    COUNT(CASE WHEN t.action = 'sell' THEN 1 END) as sell_trades,
    COUNT(CASE WHEN t.realized_pnl > 0 THEN 1 END) as profitable_trades,
    COALESCE(SUM(t.realized_pnl), 0) as total_realized_pnl,
    COALESCE(SUM(t.fee + t.tax), 0) as total_fees
FROM users u
LEFT JOIN transactions t ON u.id = t.user_id
WHERE t.action IN ('buy', 'sell')
GROUP BY u.id, u.name;

-- Grant permissions (adjust as needed for your setup)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_app_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_app_user;

-- Create sample admin user for testing (optional)
-- INSERT INTO users (phone, name, cash_balance, total_assets, invite_code)
-- VALUES ('+886900000000', 'Admin User', 10000000.00, 10000000.00, 'ADMIN001')
-- ON CONFLICT (phone) DO NOTHING;

COMMIT;