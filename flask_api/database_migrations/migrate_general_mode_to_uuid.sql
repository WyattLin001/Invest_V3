-- 錦標賽統一架構遷移腳本
-- 將一般模式的 NULL tournament_id 轉換為固定 UUID
-- 執行前請備份數據庫

-- 遷移常量定義
-- GENERAL_MODE_TOURNAMENT_ID = '00000000-0000-0000-0000-000000000000'

-- ====================================================================
-- 第一階段：數據備份與驗證
-- ====================================================================

-- 1. 查詢當前 NULL 記錄數量（執行前檢查）
SELECT 
    'portfolio_transactions' as table_name,
    COUNT(*) as null_tournament_id_records
FROM public.portfolio_transactions 
WHERE tournament_id IS NULL

UNION ALL

SELECT 
    'portfolios' as table_name,
    COUNT(*) as null_tournament_id_records  
FROM public.portfolios 
WHERE tournament_id IS NULL

UNION ALL

SELECT 
    'user_portfolios' as table_name,
    COUNT(*) as null_tournament_id_records
FROM public.user_portfolios 
WHERE tournament_id IS NULL;

-- 2. 備份現有 NULL 記錄（可選，用於回滾）
CREATE TABLE IF NOT EXISTS migration_backup_portfolio_transactions AS
SELECT * FROM public.portfolio_transactions WHERE tournament_id IS NULL;

CREATE TABLE IF NOT EXISTS migration_backup_portfolios AS  
SELECT * FROM public.portfolios WHERE tournament_id IS NULL;

CREATE TABLE IF NOT EXISTS migration_backup_user_portfolios AS
SELECT * FROM public.user_portfolios WHERE tournament_id IS NULL;

-- ====================================================================
-- 第二階段：執行遷移
-- ====================================================================

-- 3. 更新 portfolio_transactions 表的 NULL 記錄
UPDATE public.portfolio_transactions 
SET tournament_id = '00000000-0000-0000-0000-000000000000'
WHERE tournament_id IS NULL;

-- 4. 更新 portfolios 表的 NULL 記錄
UPDATE public.portfolios 
SET tournament_id = '00000000-0000-0000-0000-000000000000'
WHERE tournament_id IS NULL;

-- 5. 更新 user_portfolios 表的 NULL 記錄
UPDATE public.user_portfolios 
SET tournament_id = '00000000-0000-0000-0000-000000000000'
WHERE tournament_id IS NULL;

-- ====================================================================
-- 第三階段：驗證遷移結果
-- ====================================================================

-- 6. 驗證遷移後的記錄數量
SELECT 
    'portfolio_transactions' as table_name,
    COUNT(*) as general_mode_records,
    COUNT(DISTINCT user_id) as affected_users
FROM public.portfolio_transactions 
WHERE tournament_id = '00000000-0000-0000-0000-000000000000'

UNION ALL

SELECT 
    'portfolios' as table_name,
    COUNT(*) as general_mode_records,
    COUNT(DISTINCT user_id) as affected_users
FROM public.portfolios 
WHERE tournament_id = '00000000-0000-0000-0000-000000000000'

UNION ALL

SELECT 
    'user_portfolios' as table_name,
    COUNT(*) as general_mode_records,
    COUNT(DISTINCT user_id) as affected_users
FROM public.user_portfolios 
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

-- 7. 驗證是否還有 NULL 記錄（應該為 0）
SELECT 
    'Remaining NULL records check' as status,
    (SELECT COUNT(*) FROM public.portfolio_transactions WHERE tournament_id IS NULL) +
    (SELECT COUNT(*) FROM public.portfolios WHERE tournament_id IS NULL) +
    (SELECT COUNT(*) FROM public.user_portfolios WHERE tournament_id IS NULL) as remaining_null_count;

-- ====================================================================
-- 第四階段：創建一般模式錦標賽記錄（可選）
-- ====================================================================

-- 8. 在 tournaments 表中創建一般模式錦標賽記錄
INSERT INTO public.tournaments (
    id,
    name,
    description,
    status,
    start_date,
    end_date,
    initial_balance,
    max_participants,
    created_by,
    created_at,
    updated_at
)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    '一般投資模式',
    '系統內建的一般投資模式，無時間限制的永久投資環境',
    'ongoing',
    '2000-01-01T00:00:00Z',
    '2099-12-31T23:59:59Z',
    1000000.00,
    999999,
    'system',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = NOW();

-- ====================================================================
-- 第五階段：索引優化
-- ====================================================================

-- 9. 更新索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_portfolio_transactions_general_mode 
ON public.portfolio_transactions(user_id, tournament_id) 
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

CREATE INDEX IF NOT EXISTS idx_portfolios_general_mode
ON public.portfolios(user_id, tournament_id)
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

CREATE INDEX IF NOT EXISTS idx_user_portfolios_general_mode
ON public.user_portfolios(user_id, tournament_id)
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

-- ====================================================================
-- 第六階段：創建輔助函數
-- ====================================================================

-- 10. 創建檢查函數
CREATE OR REPLACE FUNCTION check_tournament_data_integrity()
RETURNS TABLE(
    table_name text,
    total_records bigint,
    general_mode_records bigint,
    tournament_records bigint,
    null_records bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'portfolio_transactions'::text,
        COUNT(*)::bigint,
        COUNT(*) FILTER (WHERE pt.tournament_id = '00000000-0000-0000-0000-000000000000')::bigint,
        COUNT(*) FILTER (WHERE pt.tournament_id != '00000000-0000-0000-0000-000000000000')::bigint,
        COUNT(*) FILTER (WHERE pt.tournament_id IS NULL)::bigint
    FROM public.portfolio_transactions pt
    
    UNION ALL
    
    SELECT 
        'portfolios'::text,
        COUNT(*)::bigint,
        COUNT(*) FILTER (WHERE p.tournament_id = '00000000-0000-0000-0000-000000000000')::bigint,
        COUNT(*) FILTER (WHERE p.tournament_id != '00000000-0000-0000-0000-000000000000')::bigint,
        COUNT(*) FILTER (WHERE p.tournament_id IS NULL)::bigint
    FROM public.portfolios p
    
    UNION ALL
    
    SELECT 
        'user_portfolios'::text,
        COUNT(*)::bigint,
        COUNT(*) FILTER (WHERE up.tournament_id = '00000000-0000-0000-0000-000000000000')::bigint,
        COUNT(*) FILTER (WHERE up.tournament_id != '00000000-0000-0000-0000-000000000000')::bigint,
        COUNT(*) FILTER (WHERE up.tournament_id IS NULL)::bigint
    FROM public.user_portfolios up;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 執行完成報告
-- ====================================================================

-- 11. 執行數據完整性檢查
SELECT * FROM check_tournament_data_integrity();

-- 12. 顯示遷移完成消息
SELECT 
    '遷移完成' as status,
    '一般模式已統一使用 UUID: 00000000-0000-0000-0000-000000000000' as message,
    NOW() as completed_at;

-- ====================================================================
-- 回滾腳本（僅在需要時執行）
-- ====================================================================

/*
-- 如果需要回滾到 NULL 模式，執行以下腳本：

-- 回滾 portfolio_transactions
UPDATE public.portfolio_transactions 
SET tournament_id = NULL
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

-- 回滾 portfolios  
UPDATE public.portfolios 
SET tournament_id = NULL
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

-- 回滾 user_portfolios
UPDATE public.user_portfolios 
SET tournament_id = NULL
WHERE tournament_id = '00000000-0000-0000-0000-000000000000';

-- 刪除一般模式錦標賽記錄
DELETE FROM public.tournaments 
WHERE id = '00000000-0000-0000-0000-000000000000';

-- 刪除備份表
DROP TABLE IF EXISTS migration_backup_portfolio_transactions;
DROP TABLE IF EXISTS migration_backup_portfolios;
DROP TABLE IF EXISTS migration_backup_user_portfolios;
*/