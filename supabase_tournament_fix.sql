-- Supabase錦標賽表權限修復腳本
-- 解決用戶創建錦標賽顯示問題

-- 1. 添加created_by字段到tournaments表
ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(255);

-- 2. 為現有數據設置created_by（test03的錦標賽）
-- 注意：這裡使用字符串'test03'，實際應用中應該是真實的UUID
UPDATE tournaments 
SET created_by_name = 'test03'
WHERE created_by_name IS NULL;

-- 3. 創建索引以優化查詢性能
CREATE INDEX IF NOT EXISTS idx_tournaments_created_by ON tournaments(created_by);
CREATE INDEX IF NOT EXISTS idx_tournaments_created_by_name ON tournaments(created_by_name);

-- 4. 更新Row Level Security (RLS)策略

-- 刪除舊的限制性策略
DROP POLICY IF EXISTS "tournaments_are_public" ON tournaments;
DROP POLICY IF EXISTS "admin_can_manage_tournaments" ON tournaments;

-- 創建新的更寬鬆的策略
-- 所有認證用戶都可以查看錦標賽（用於顯示錦標賽列表）
CREATE POLICY "tournaments_are_viewable" ON tournaments 
    FOR SELECT TO authenticated USING (true);

-- 允許認證用戶創建錦標賽
CREATE POLICY "users_can_create_tournaments" ON tournaments 
    FOR INSERT TO authenticated 
    WITH CHECK (created_by = auth.uid() OR created_by_name IS NOT NULL);

-- 用戶可以管理自己創建的錦標賽
CREATE POLICY "users_can_manage_own_tournaments" ON tournaments 
    FOR UPDATE TO authenticated 
    USING (created_by = auth.uid() OR auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin');

-- 用戶可以刪除自己創建的錦標賽（可選）
CREATE POLICY "users_can_delete_own_tournaments" ON tournaments 
    FOR DELETE TO authenticated 
    USING (created_by = auth.uid() OR auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin');

-- 5. 確保其他相關表的RLS策略也正確

-- 確保tournament_participants表允許查看和插入
DROP POLICY IF EXISTS "participants_are_public" ON tournament_participants;
DROP POLICY IF EXISTS "users_can_manage_own_participation" ON tournament_participants;

CREATE POLICY "participants_are_viewable" ON tournament_participants 
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "users_can_join_tournaments" ON tournament_participants 
    FOR INSERT TO authenticated 
    WITH CHECK (user_id = auth.uid()::text OR auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin');

CREATE POLICY "users_can_update_own_participation" ON tournament_participants 
    FOR UPDATE TO authenticated 
    USING (user_id = auth.uid()::text OR auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin');

-- 6. 創建測試用戶錦標賽數據
-- 注意：在實際環境中，created_by應該是真實的user UUID
INSERT INTO tournaments (
    id,
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
    created_by_name,
    created_at,
    updated_at
) VALUES 
(
    'user001-1234-1234-1234-123456789001'::uuid,
    '我的科技股專題賽',
    '我創建的專注於科技股投資的錦標賽，歡迎所有對科技股感興趣的投資者參加。',
    '我創建的科技股投資錦標賽',
    'monthly',
    'ongoing',
    NOW() - INTERVAL '5 days',
    NOW() + INTERVAL '25 days',
    200000.0,
    50,
    15,
    0.0,
    25000.0,
    20.0,
    60.0,
    30.0,
    '["專注科技股", "最大單股持倉30%", "最低持倉率60%", "風險限制20%"]'::jsonb,
    false,
    'd64a0edd-62cc-423a-8ce4-81103b5a9770',
    NOW() - INTERVAL '5 days',
    NOW()
),
(
    'user002-1234-1234-1234-123456789002'::uuid,
    '我的價值投資挑戰',
    '我創建的長期價值投資策略錦標賽，適合喜歡價值投資的投資者。',
    '我創建的價值投資策略錦標賽',
    'quarterly',
    'ongoing',
    NOW() - INTERVAL '2 days',
    NOW() + INTERVAL '88 days',
    150000.0,
    30,
    8,
    0.0,
    15000.0,
    15.0,
    70.0,
    25.0,
    '["價值投資策略", "長期持有", "最大單股持倉25%", "最低持倉率70%"]'::jsonb,
    false,
    'd64a0edd-62cc-423a-8ce4-81103b5a9770',
    NOW() - INTERVAL '2 days',
    NOW()
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    created_by_name = EXCLUDED.created_by_name,
    updated_at = NOW();

-- 7. 驗證修復結果
-- 這些查詢應該成功返回數據
-- SELECT COUNT(*) as total_tournaments FROM tournaments;
-- SELECT COUNT(*) as user_created FROM tournaments WHERE created_by_name = 'd64a0edd-62cc-423a-8ce4-81103b5a9770';
-- SELECT COUNT(*) as test03_created FROM tournaments WHERE created_by_name = 'test03';

-- 8. 確認權限設置
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'tournaments';