-- 用戶排名表 (簡化版本，用於調度器服務)
CREATE TABLE IF NOT EXISTS user_rankings (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    rank INTEGER NOT NULL,
    total_assets DECIMAL(15, 2) NOT NULL,
    return_rate DECIMAL(8, 4) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 外鍵約束（如果users表存在）
    -- FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- 唯一約束
    UNIQUE(user_id),
    
    -- 索引
    INDEX idx_rankings_user_id (user_id),
    INDEX idx_rankings_rank (rank),
    INDEX idx_rankings_assets (total_assets),
    INDEX idx_rankings_return_rate (return_rate)
);

-- 股票價格表 (簡化版本，用於調度器服務)
CREATE TABLE IF NOT EXISTS stocks (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 4) NOT NULL DEFAULT 0.00,
    change_amount DECIMAL(10, 4) DEFAULT 0.00,
    change_percent DECIMAL(8, 4) DEFAULT 0.00,
    volume BIGINT DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 索引
    INDEX idx_stocks_symbol (symbol),
    INDEX idx_stocks_updated (last_updated)
);

-- 用戶持股表 (簡化版本，用於調度器服務)
CREATE TABLE IF NOT EXISTS holdings (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    stock_symbol VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    average_cost DECIMAL(10, 4) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 外鍵約束
    -- FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (stock_symbol) REFERENCES stocks(symbol) ON DELETE CASCADE,
    
    -- 唯一約束
    UNIQUE(user_id, stock_symbol),
    
    -- 索引
    INDEX idx_holdings_user_id (user_id),
    INDEX idx_holdings_symbol (stock_symbol)
);

-- 用戶表 (簡化版本，用於調度器服務)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100),
    cash_balance DECIMAL(15, 2) DEFAULT 1000000.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 索引
    INDEX idx_users_phone (phone),
    INDEX idx_users_created (created_at)
);

-- 插入初始股票資料
INSERT INTO stocks (symbol, name, price, change_amount, change_percent, volume) VALUES
    ('2330.TW', '台積電', 580.00, 0.00, 0.00, 10000000),
    ('2317.TW', '鴻海', 105.00, 0.00, 0.00, 15000000),
    ('2454.TW', '聯發科', 1200.00, 0.00, 0.00, 5000000),
    ('2881.TW', '富邦金', 75.00, 0.00, 0.00, 8000000),
    ('6505.TW', '台塑化', 95.00, 0.00, 0.00, 6000000),
    ('2382.TW', '廣達', 85.00, 0.00, 0.00, 7000000),
    ('2412.TW', '中華電', 120.00, 0.00, 0.00, 4000000),
    ('2308.TW', '台達電', 300.00, 0.00, 0.00, 3000000),
    ('2303.TW', '聯電', 50.00, 0.00, 0.00, 12000000),
    ('1301.TW', '台塑', 110.00, 0.00, 0.00, 5500000)
ON CONFLICT (symbol) DO UPDATE SET
    name = EXCLUDED.name,
    last_updated = NOW();

-- 更新時間觸發器函數
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 為holdings表建立更新觸發器
DROP TRIGGER IF EXISTS update_holdings_updated_at ON holdings;
CREATE TRIGGER update_holdings_updated_at
    BEFORE UPDATE ON holdings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 為users表建立更新觸發器
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();