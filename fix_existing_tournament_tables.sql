-- ============================================================================
-- 修復現有錦標賽表格中的 PostgreSQL 錯誤 - Invest_V3
-- ============================================================================
-- 此腳本用於修復已存在的錦標賽表格中的 GENERATED ALWAYS AS 問題

-- 1. 檢查並修復可能存在的 GENERATED ALWAYS AS 列
-- 如果原始腳本中有這些問題列，需要先移除再重新添加

-- 檢查 tournament_participants 表是否有 generated 列問題
DO $$
BEGIN
    -- 檢查是否存在 return_rate_display 這類可能有問題的列
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tournament_participants' 
        AND column_name = 'return_rate_display'
        AND table_schema = 'public'
    ) THEN
        -- 如果存在有問題的 generated 列，先刪除
        ALTER TABLE public.tournament_participants DROP COLUMN IF EXISTS return_rate_display;
        RAISE NOTICE '已移除有問題的 return_rate_display 列';
    END IF;
    
    -- 檢查其他可能有問題的 generated 列
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tournament_participants' 
        AND column_name = 'rank_display'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.tournament_participants DROP COLUMN IF EXISTS rank_display;
        RAISE NOTICE '已移除有問題的 rank_display 列';
    END IF;
END $$;

-- 2. 檢查並修復 tournament_trading_records 表
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tournament_trading_records' 
        AND column_name = 'trade_summary'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.tournament_trading_records DROP COLUMN IF EXISTS trade_summary;
        RAISE NOTICE '已移除有問題的 trade_summary 列';
    END IF;
END $$;

-- 3. 檢查並修復 tournament_positions 表
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tournament_positions' 
        AND column_name = 'position_summary'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.tournament_positions DROP COLUMN IF EXISTS position_summary;
        RAISE NOTICE '已移除有問題的 position_summary 列';
    END IF;
END $$;

-- 4. 確保所有必要的索引都存在（只創建不存在的）
DO $$
BEGIN
    -- 檢查並創建缺失的索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournaments_status') THEN
        CREATE INDEX idx_tournaments_status ON public.tournaments(status);
        RAISE NOTICE '已創建 idx_tournaments_status 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournaments_type') THEN
        CREATE INDEX idx_tournaments_type ON public.tournaments(type);
        RAISE NOTICE '已創建 idx_tournaments_type 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournaments_start_date') THEN
        CREATE INDEX idx_tournaments_start_date ON public.tournaments(start_date);
        RAISE NOTICE '已創建 idx_tournaments_start_date 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournaments_is_featured') THEN
        CREATE INDEX idx_tournaments_is_featured ON public.tournaments(is_featured);
        RAISE NOTICE '已創建 idx_tournaments_is_featured 索引';
    END IF;
    
    -- 參與者索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_participants_tournament_id') THEN
        CREATE INDEX idx_tournament_participants_tournament_id ON public.tournament_participants(tournament_id);
        RAISE NOTICE '已創建 idx_tournament_participants_tournament_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_participants_user_id') THEN
        CREATE INDEX idx_tournament_participants_user_id ON public.tournament_participants(user_id);
        RAISE NOTICE '已創建 idx_tournament_participants_user_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_participants_rank') THEN
        CREATE INDEX idx_tournament_participants_rank ON public.tournament_participants(current_rank);
        RAISE NOTICE '已創建 idx_tournament_participants_rank 索引';
    END IF;
    
    -- 交易記錄索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_trading_records_user_id') THEN
        CREATE INDEX idx_tournament_trading_records_user_id ON public.tournament_trading_records(user_id);
        RAISE NOTICE '已創建 idx_tournament_trading_records_user_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_trading_records_tournament_id') THEN
        CREATE INDEX idx_tournament_trading_records_tournament_id ON public.tournament_trading_records(tournament_id);
        RAISE NOTICE '已創建 idx_tournament_trading_records_tournament_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_trading_records_timestamp') THEN
        CREATE INDEX idx_tournament_trading_records_timestamp ON public.tournament_trading_records(timestamp);
        RAISE NOTICE '已創建 idx_tournament_trading_records_timestamp 索引';
    END IF;
    
    -- 持倉索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_positions_tournament_user') THEN
        CREATE INDEX idx_tournament_positions_tournament_user ON public.tournament_positions(tournament_id, user_id);
        RAISE NOTICE '已創建 idx_tournament_positions_tournament_user 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_positions_symbol') THEN
        CREATE INDEX idx_tournament_positions_symbol ON public.tournament_positions(symbol);
        RAISE NOTICE '已創建 idx_tournament_positions_symbol 索引';
    END IF;
    
    -- 活動記錄索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_activities_tournament_id') THEN
        CREATE INDEX idx_tournament_activities_tournament_id ON public.tournament_activities(tournament_id);
        RAISE NOTICE '已創建 idx_tournament_activities_tournament_id 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_activities_timestamp') THEN
        CREATE INDEX idx_tournament_activities_timestamp ON public.tournament_activities(timestamp);
        RAISE NOTICE '已創建 idx_tournament_activities_timestamp 索引';
    END IF;
    
    -- 排行榜快照索引
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_ranking_snapshots_tournament_date') THEN
        CREATE INDEX idx_tournament_ranking_snapshots_tournament_date ON public.tournament_ranking_snapshots(tournament_id, snapshot_date);
        RAISE NOTICE '已創建 idx_tournament_ranking_snapshots_tournament_date 索引';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_tournament_ranking_snapshots_rank') THEN
        CREATE INDEX idx_tournament_ranking_snapshots_rank ON public.tournament_ranking_snapshots(rank);
        RAISE NOTICE '已創建 idx_tournament_ranking_snapshots_rank 索引';
    END IF;
    
END $$;

-- 5. 確保 RLS 政策正確設置
DO $$
BEGIN
    -- 啟用 RLS（如果尚未啟用）
    ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.tournament_trading_records ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.tournament_positions ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.tournament_activities ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.tournament_ranking_snapshots ENABLE ROW LEVEL SECURITY;
    
    -- 檢查並創建缺失的 RLS 政策
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournaments' 
        AND policyname = 'Anyone can view tournaments'
    ) THEN
        CREATE POLICY "Anyone can view tournaments" ON public.tournaments FOR SELECT USING (true);
        RAISE NOTICE '已創建錦標賽查看政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournaments' 
        AND policyname = 'Only test03 can create tournaments'
    ) THEN
        CREATE POLICY "Only test03 can create tournaments" ON public.tournaments FOR INSERT 
        WITH CHECK (
          EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = created_by AND username = 'test03'
          )
        );
        RAISE NOTICE '已創建錦標賽建立政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournament_participants' 
        AND policyname = 'Anyone can view tournament participants'
    ) THEN
        CREATE POLICY "Anyone can view tournament participants" ON public.tournament_participants FOR SELECT USING (true);
        RAISE NOTICE '已創建參與者查看政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournament_participants' 
        AND policyname = 'Users can manage own tournament participation'
    ) THEN
        CREATE POLICY "Users can manage own tournament participation" ON public.tournament_participants FOR ALL 
        USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建參與者管理政策';
    END IF;
    
    -- 其他重要政策
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournament_trading_records' 
        AND policyname = 'Users can manage own tournament trading records'
    ) THEN
        CREATE POLICY "Users can manage own tournament trading records" ON public.tournament_trading_records FOR ALL 
        USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建交易記錄政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournament_positions' 
        AND policyname = 'Users can manage own tournament positions'
    ) THEN
        CREATE POLICY "Users can manage own tournament positions" ON public.tournament_positions FOR ALL 
        USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));
        RAISE NOTICE '已創建持倉政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournament_activities' 
        AND policyname = 'Anyone can view tournament activities'
    ) THEN
        CREATE POLICY "Anyone can view tournament activities" ON public.tournament_activities FOR SELECT USING (true);
        RAISE NOTICE '已創建活動記錄政策';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tournament_ranking_snapshots' 
        AND policyname = 'Anyone can view tournament ranking snapshots'
    ) THEN
        CREATE POLICY "Anyone can view tournament ranking snapshots" ON public.tournament_ranking_snapshots FOR SELECT USING (true);
        RAISE NOTICE '已創建排行榜政策';
    END IF;
    
END $$;

-- 6. 確保觸發器存在
DO $$
BEGIN
    -- 檢查參與者計數觸發器
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_update_tournament_participant_count'
    ) THEN
        -- 創建參與者計數更新函數
        CREATE OR REPLACE FUNCTION update_tournament_participant_count()
        RETURNS TRIGGER AS $func$
        BEGIN
          IF TG_OP = 'INSERT' THEN
            UPDATE public.tournaments 
            SET current_participants = current_participants + 1,
                updated_at = now()
            WHERE id = NEW.tournament_id;
            RETURN NEW;
          ELSIF TG_OP = 'DELETE' THEN
            UPDATE public.tournaments 
            SET current_participants = current_participants - 1,
                updated_at = now()
            WHERE id = OLD.tournament_id;
            RETURN OLD;
          END IF;
          RETURN NULL;
        END;
        $func$ LANGUAGE plpgsql;
        
        -- 創建觸發器
        CREATE TRIGGER trigger_update_tournament_participant_count
          AFTER INSERT OR DELETE ON public.tournament_participants
          FOR EACH ROW EXECUTE FUNCTION update_tournament_participant_count();
          
        RAISE NOTICE '已創建參與者計數觸發器';
    END IF;
    
    -- 檢查排名計算函數
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'calculate_tournament_rankings'
    ) THEN
        CREATE OR REPLACE FUNCTION calculate_tournament_rankings(tournament_uuid uuid)
        RETURNS void AS $func$
        BEGIN
          WITH ranked_participants AS (
            SELECT 
              id,
              ROW_NUMBER() OVER (ORDER BY virtual_balance DESC, return_rate DESC) as new_rank
            FROM public.tournament_participants 
            WHERE tournament_id = tournament_uuid 
            AND is_eliminated = false
          )
          UPDATE public.tournament_participants tp
          SET 
            previous_rank = current_rank,
            current_rank = rp.new_rank,
            last_updated = now()
          FROM ranked_participants rp
          WHERE tp.id = rp.id;
        END;
        $func$ LANGUAGE plpgsql;
        
        RAISE NOTICE '已創建排名計算函數';
    END IF;
    
END $$;

-- 7. 最終檢查：確認所有關鍵表格都存在
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tournaments') THEN
        RAISE EXCEPTION '錯誤：tournaments 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tournament_participants') THEN
        RAISE EXCEPTION '錯誤：tournament_participants 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tournament_trading_records') THEN
        RAISE EXCEPTION '錯誤：tournament_trading_records 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tournament_positions') THEN
        RAISE EXCEPTION '錯誤：tournament_positions 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tournament_activities') THEN
        RAISE EXCEPTION '錯誤：tournament_activities 表格不存在！';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tournament_ranking_snapshots') THEN
        RAISE EXCEPTION '錯誤：tournament_ranking_snapshots 表格不存在！';
    END IF;
    
    RAISE NOTICE '✅ 所有錦標賽表格檢查完成！';
    RAISE NOTICE '✅ PostgreSQL 錯誤修復完成！';
    RAISE NOTICE '✅ 錦標賽系統已準備就緒！';
    
END $$;