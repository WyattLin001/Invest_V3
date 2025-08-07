-- 錦標賽投資組合統一架構遷移腳本
-- 為現有的投資組合表添加錦標賽支持
-- 執行前請備份數據庫

-- 1. 為 user_portfolios 表添加 tournament_id 欄位
ALTER TABLE public.user_portfolios 
ADD COLUMN tournament_id uuid DEFAULT NULL,
ADD COLUMN group_id uuid DEFAULT NULL;

-- 2. 為 portfolios 表添加 tournament_id 欄位
ALTER TABLE public.portfolios 
ADD COLUMN tournament_id uuid DEFAULT NULL;

-- 3. 添加外鍵約束，確保數據完整性
ALTER TABLE public.user_portfolios
ADD CONSTRAINT fk_user_portfolios_tournament
FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE;

ALTER TABLE public.user_portfolios
ADD CONSTRAINT fk_user_portfolios_group
FOREIGN KEY (group_id) REFERENCES public.investment_groups(id) ON DELETE CASCADE;

ALTER TABLE public.portfolios
ADD CONSTRAINT fk_portfolios_tournament
FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE;

-- 4. 創建複合索引提升查詢效能
CREATE INDEX idx_user_portfolios_user_tournament 
ON public.user_portfolios(user_id, tournament_id);

CREATE INDEX idx_user_portfolios_tournament 
ON public.user_portfolios(tournament_id);

CREATE INDEX idx_user_portfolios_group 
ON public.user_portfolios(group_id);

CREATE INDEX idx_portfolios_user_tournament 
ON public.portfolios(user_id, tournament_id);

CREATE INDEX idx_portfolios_tournament 
ON public.portfolios(tournament_id);

-- 5. 創建視圖，統一查詢接口
CREATE OR REPLACE VIEW portfolio_summary AS
SELECT 
    p.id,
    p.user_id,
    p.group_id,
    p.tournament_id,
    p.initial_cash,
    p.available_cash,
    p.total_value,
    p.return_rate,
    p.last_updated,
    p.created_at,
    CASE 
        WHEN p.tournament_id IS NOT NULL THEN 'tournament'
        WHEN p.group_id IS NOT NULL THEN 'group'
        ELSE 'general'
    END as portfolio_type,
    t.name as tournament_name,
    ig.name as group_name
FROM public.portfolios p
LEFT JOIN public.tournaments t ON p.tournament_id = t.id
LEFT JOIN public.investment_groups ig ON p.group_id = ig.id;

-- 6. 創建持股明細視圖
CREATE OR REPLACE VIEW user_holdings_summary AS
SELECT 
    up.id,
    up.user_id,
    up.group_id,
    up.tournament_id,
    up.symbol,
    up.shares,
    up.average_price,
    up.current_value,
    up.return_rate,
    up.updated_at,
    CASE 
        WHEN up.tournament_id IS NOT NULL THEN 'tournament'
        WHEN up.group_id IS NOT NULL THEN 'group'
        ELSE 'general'
    END as holding_type,
    t.name as tournament_name,
    ig.name as group_name
FROM public.user_portfolios up
LEFT JOIN public.tournaments t ON up.tournament_id = t.id
LEFT JOIN public.investment_groups ig ON up.group_id = ig.id;

-- 7. 創建輔助函數：獲取用戶在特定錦標賽的投資組合
CREATE OR REPLACE FUNCTION get_user_tournament_portfolio(
    p_user_id uuid,
    p_tournament_id uuid
)
RETURNS TABLE(
    portfolio_id uuid,
    initial_cash numeric,
    available_cash numeric,
    total_value numeric,
    return_rate numeric,
    holdings_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as portfolio_id,
        p.initial_cash,
        p.available_cash,
        p.total_value,
        p.return_rate,
        COUNT(up.id) as holdings_count
    FROM public.portfolios p
    LEFT JOIN public.user_portfolios up ON p.user_id = up.user_id AND p.tournament_id = up.tournament_id
    WHERE p.user_id = p_user_id 
      AND p.tournament_id = p_tournament_id
    GROUP BY p.id, p.initial_cash, p.available_cash, p.total_value, p.return_rate;
END;
$$ LANGUAGE plpgsql;

-- 8. 創建輔助函數：創建新的錦標賽投資組合
CREATE OR REPLACE FUNCTION create_tournament_portfolio(
    p_user_id uuid,
    p_tournament_id uuid,
    p_initial_balance numeric DEFAULT 1000000.00
)
RETURNS uuid AS $$
DECLARE
    new_portfolio_id uuid;
BEGIN
    -- 檢查是否已存在該用戶在該錦標賽的投資組合
    SELECT id INTO new_portfolio_id
    FROM public.portfolios
    WHERE user_id = p_user_id AND tournament_id = p_tournament_id;
    
    -- 如果不存在，則創建新的投資組合
    IF new_portfolio_id IS NULL THEN
        INSERT INTO public.portfolios (
            user_id,
            tournament_id,
            initial_cash,
            available_cash,
            total_value,
            return_rate,
            created_at,
            last_updated
        ) VALUES (
            p_user_id,
            p_tournament_id,
            p_initial_balance,
            p_initial_balance,
            p_initial_balance,
            0.0,
            NOW(),
            NOW()
        )
        RETURNING id INTO new_portfolio_id;
        
        -- 記錄日誌
        INSERT INTO public.system_logs (
            log_level,
            category,
            message,
            details,
            user_id,
            created_at
        ) VALUES (
            'info',
            'tournament_portfolio',
            'Created new tournament portfolio',
            jsonb_build_object(
                'user_id', p_user_id,
                'tournament_id', p_tournament_id,
                'portfolio_id', new_portfolio_id,
                'initial_balance', p_initial_balance
            ),
            p_user_id,
            NOW()
        );
    END IF;
    
    RETURN new_portfolio_id;
END;
$$ LANGUAGE plpgsql;

-- 9. 添加觸發器：自動更新投資組合總價值
CREATE OR REPLACE FUNCTION update_portfolio_total_value()
RETURNS TRIGGER AS $$
BEGIN
    -- 更新對應的投資組合總價值
    UPDATE public.portfolios
    SET 
        total_value = available_cash + (
            SELECT COALESCE(SUM(current_value), 0)
            FROM public.user_portfolios
            WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
              AND COALESCE(tournament_id, '') = COALESCE(COALESCE(NEW.tournament_id, OLD.tournament_id), '')
              AND COALESCE(group_id, '') = COALESCE(COALESCE(NEW.group_id, OLD.group_id), '')
        ),
        return_rate = (
            (available_cash + (
                SELECT COALESCE(SUM(current_value), 0)
                FROM public.user_portfolios
                WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
                  AND COALESCE(tournament_id, '') = COALESCE(COALESCE(NEW.tournament_id, OLD.tournament_id), '')
                  AND COALESCE(group_id, '') = COALESCE(COALESCE(NEW.group_id, OLD.group_id), '')
            ) - initial_cash) / initial_cash
        ) * 100,
        last_updated = NOW()
    WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
      AND COALESCE(tournament_id, '') = COALESCE(COALESCE(NEW.tournament_id, OLD.tournament_id), '')
      AND COALESCE(group_id, '') = COALESCE(COALESCE(NEW.group_id, OLD.group_id), '');
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_portfolio_value
    AFTER INSERT OR UPDATE OR DELETE ON public.user_portfolios
    FOR EACH ROW EXECUTE FUNCTION update_portfolio_total_value();

-- 10. 創建 RLS 政策確保數據安全
-- user_portfolios 表的 RLS 政策
ALTER TABLE public.user_portfolios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own portfolio holdings" ON public.user_portfolios
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can manage own portfolio holdings" ON public.user_portfolios
    FOR ALL USING (user_id = auth.uid());

-- portfolios 表的 RLS 政策  
ALTER TABLE public.portfolios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own portfolios" ON public.portfolios
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can manage own portfolios" ON public.portfolios
    FOR ALL USING (user_id = auth.uid());

-- 11. 插入測試數據的範例 (可選，僅用於開發測試)
/*
-- 範例：為現有錦標賽創建測試投資組合
DO $$
DECLARE
    test_user_id uuid := '00000000-0000-0000-0000-000000000001'; -- 替換為實際用戶ID
    test_tournament_id uuid;
    new_portfolio_id uuid;
BEGIN
    -- 獲取第一個可用的錦標賽ID
    SELECT id INTO test_tournament_id FROM public.tournaments LIMIT 1;
    
    IF test_tournament_id IS NOT NULL THEN
        -- 創建錦標賽投資組合
        SELECT create_tournament_portfolio(test_user_id, test_tournament_id) INTO new_portfolio_id;
        
        -- 添加一些測試持股
        INSERT INTO public.user_portfolios (user_id, tournament_id, symbol, shares, average_price, current_value, return_rate)
        VALUES 
            (test_user_id, test_tournament_id, '2330', 100, 580.0, 62000.0, 6.90),
            (test_user_id, test_tournament_id, '2454', 50, 800.0, 42500.0, 6.25);
        
        RAISE NOTICE '測試錦標賽投資組合創建成功: %', new_portfolio_id;
    END IF;
END $$;
*/

-- 完成遷移
SELECT 'Tournament portfolio migration completed successfully!' as result;