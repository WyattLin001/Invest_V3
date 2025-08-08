-- 為 portfolio_transactions 表添加 tournament_id 支持
-- 這樣統一架構：同一表格用 tournament_id 區分錦標賽和一般模式

-- 1. 添加 tournament_id 欄位
ALTER TABLE public.portfolio_transactions 
ADD COLUMN tournament_id uuid REFERENCES public.tournaments(id);

-- 2. 添加索引提高查詢效率
CREATE INDEX idx_portfolio_transactions_tournament_id ON public.portfolio_transactions(tournament_id);
CREATE INDEX idx_portfolio_transactions_user_tournament ON public.portfolio_transactions(user_id, tournament_id);

-- 3. 添加註釋
COMMENT ON COLUMN public.portfolio_transactions.tournament_id IS '錦標賽 ID，為 NULL 表示一般模式交易';

-- 4. 更新 RLS 政策（如果需要）
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.portfolio_transactions;
CREATE POLICY "Users can view their own transactions" ON public.portfolio_transactions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own transactions" ON public.portfolio_transactions;    
CREATE POLICY "Users can insert their own transactions" ON public.portfolio_transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 5. 驗證遷移結果
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'portfolio_transactions' 
ORDER BY ordinal_position;