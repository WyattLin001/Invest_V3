-- 添加created_by_name字段到tournaments表
-- 需要在Supabase Dashboard的SQL Editor中执行

-- 1. 添加created_by_name字段
ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(255);

-- 2. 添加索引以优化查询
CREATE INDEX IF NOT EXISTS idx_tournaments_created_by_name ON tournaments(created_by_name);

-- 3. 为现有数据设置默认值（所有现有tournaments设为test03创建）
UPDATE tournaments 
SET created_by_name = 'test03' 
WHERE created_by_name IS NULL;

-- 4. 添加用户创建的示例tournaments
INSERT INTO tournaments (
    name, 
    description, 
    short_description, 
    type, 
    status, 
    start_date, 
    end_date, 
    initial_balance, 
    max_participants,
    current_participants,
    entry_fee,
    prize_pool,
    risk_limit_percentage,
    min_holding_rate,
    max_single_stock_rate,
    rules,
    is_featured,
    created_by_name
) VALUES 
(
    '我的科技股專題賽',
    '我創建的專注於科技股投資的錦標賽，歡迎所有對科技股感興趣的投資者參加。',
    '我創建的科技股投資錦標賽',
    'monthly',
    'ongoing',
    '2025-08-05T00:00:00Z',
    '2025-09-05T23:59:59Z',
    200000.0,
    50,
    15,
    0.0,
    25000.0,
    20.0,
    0.6,
    0.3,
    '["專注科技股", "最大單股持倉30%", "最低持倉率60%", "風險限制20%"]',
    false,
    'd64a0edd-62cc-423a-8ce4-81103b5a9770'
),
(
    '我的價值投資挑戰',
    '我創建的長期價值投資策略錦標賽，適合喜歡價值投資的投資者。',
    '我創建的價值投資策略錦標賽',
    'quarterly',
    'ongoing',
    '2025-08-08T00:00:00Z',
    '2025-11-08T23:59:59Z',
    150000.0,
    30,
    8,
    0.0,
    15000.0,
    15.0,
    0.7,
    0.25,
    '["價值投資策略", "長期持有", "最大單股持倉25%", "最低持倉率70%"]',
    false,
    'd64a0edd-62cc-423a-8ce4-81103b5a9770'
) ON CONFLICT (id) DO NOTHING;

-- 5. 验证结果
SELECT id, name, created_by_name FROM tournaments ORDER BY created_at;