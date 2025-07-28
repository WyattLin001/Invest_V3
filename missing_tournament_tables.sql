-- ============================================================================
-- 錦標賽系統補充表格 - Invest_V3
-- ============================================================================

-- 1. 錦標賽主表
CREATE TABLE public.tournaments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'quarterly'::text, 'yearly'::text, 'special'::text])),
  status text NOT NULL DEFAULT 'upcoming'::text CHECK (status = ANY (ARRAY['upcoming'::text, 'enrolling'::text, 'ongoing'::text, 'finished'::text, 'cancelled'::text])),
  start_date timestamp with time zone NOT NULL,
  end_date timestamp with time zone NOT NULL,
  description text NOT NULL,
  short_description text NOT NULL,
  initial_balance numeric NOT NULL DEFAULT 1000000.00,
  max_participants integer NOT NULL DEFAULT 100,
  current_participants integer NOT NULL DEFAULT 0,
  entry_fee numeric NOT NULL DEFAULT 0,
  prize_pool numeric NOT NULL DEFAULT 0,
  risk_limit_percentage numeric NOT NULL DEFAULT 0.20,
  min_holding_rate numeric NOT NULL DEFAULT 0.50,
  max_single_stock_rate numeric NOT NULL DEFAULT 0.30,
  rules text[] NOT NULL DEFAULT '{}',
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  is_featured boolean DEFAULT false,
  created_by uuid REFERENCES public.user_profiles(id),
  CONSTRAINT tournaments_pkey PRIMARY KEY (id)
);

-- 2. 錦標賽參與者表
CREATE TABLE public.tournament_participants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  user_name text NOT NULL,
  user_avatar text,
  current_rank integer DEFAULT 999999,
  previous_rank integer DEFAULT 999999,
  virtual_balance numeric NOT NULL DEFAULT 1000000.00,
  initial_balance numeric NOT NULL DEFAULT 1000000.00,
  return_rate numeric NOT NULL DEFAULT 0.00,
  total_trades integer NOT NULL DEFAULT 0,
  win_rate numeric NOT NULL DEFAULT 0.00,
  max_drawdown numeric NOT NULL DEFAULT 0.00,
  sharpe_ratio numeric,
  is_eliminated boolean DEFAULT false,
  elimination_reason text,
  joined_at timestamp with time zone DEFAULT now(),
  last_updated timestamp with time zone DEFAULT now(),
  CONSTRAINT tournament_participants_pkey PRIMARY KEY (id),
  CONSTRAINT tournament_participants_unique UNIQUE (tournament_id, user_id)
);

-- 3. 錦標賽交易記錄表（擴展現有 trading_transactions）
CREATE TABLE public.tournament_trading_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id),
  tournament_id uuid REFERENCES public.tournaments(id) ON DELETE SET NULL,
  symbol text NOT NULL,
  stock_name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['buy'::text, 'sell'::text])),
  shares numeric NOT NULL,
  price numeric NOT NULL,
  timestamp timestamp with time zone DEFAULT now(),
  total_amount numeric NOT NULL,
  fee numeric NOT NULL DEFAULT 0,
  net_amount numeric NOT NULL,
  average_cost numeric,
  realized_gain_loss numeric,
  realized_gain_loss_percent numeric,
  notes text,
  CONSTRAINT tournament_trading_records_pkey PRIMARY KEY (id)
);

-- 4. 錦標賽持倉表
CREATE TABLE public.tournament_positions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  symbol text NOT NULL,
  stock_name text NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  average_cost numeric NOT NULL DEFAULT 0,
  current_price numeric NOT NULL DEFAULT 0,
  market_value numeric NOT NULL DEFAULT 0,
  unrealized_gain_loss numeric NOT NULL DEFAULT 0,
  unrealized_gain_loss_percent numeric NOT NULL DEFAULT 0,
  first_buy_date timestamp with time zone,
  last_updated timestamp with time zone DEFAULT now(),
  CONSTRAINT tournament_positions_pkey PRIMARY KEY (id),
  CONSTRAINT tournament_positions_unique UNIQUE (tournament_id, user_id, symbol)
);

-- 5. 錦標賽活動記錄表
CREATE TABLE public.tournament_activities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id),
  user_name text NOT NULL,
  activity_type text NOT NULL CHECK (activity_type = ANY (ARRAY['trade'::text, 'rank_change'::text, 'elimination'::text, 'milestone'::text, 'violation'::text])),
  description text NOT NULL,
  amount numeric,
  symbol text,
  timestamp timestamp with time zone DEFAULT now(),
  CONSTRAINT tournament_activities_pkey PRIMARY KEY (id)
);

-- 6. 錦標賽排行榜快照表
CREATE TABLE public.tournament_ranking_snapshots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id),
  snapshot_date date NOT NULL,
  rank integer NOT NULL,
  virtual_balance numeric NOT NULL,
  return_rate numeric NOT NULL,
  daily_change numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT tournament_ranking_snapshots_pkey PRIMARY KEY (id),
  CONSTRAINT tournament_ranking_snapshots_unique UNIQUE (tournament_id, user_id, snapshot_date)
);

-- 7. 錦標賽成就表
CREATE TABLE public.tournament_achievements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  icon text NOT NULL,
  rarity text NOT NULL CHECK (rarity = ANY (ARRAY['common'::text, 'rare'::text, 'epic'::text, 'legendary'::text, 'mythic'::text])),
  requirements jsonb NOT NULL,
  reward_amount integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT tournament_achievements_pkey PRIMARY KEY (id)
);

-- 8. 用戶錦標賽成就記錄表
CREATE TABLE public.user_tournament_achievements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  tournament_id uuid REFERENCES public.tournaments(id) ON DELETE SET NULL,
  achievement_id uuid NOT NULL REFERENCES public.tournament_achievements(id),
  progress numeric NOT NULL DEFAULT 0,
  is_unlocked boolean DEFAULT false,
  earned_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_tournament_achievements_pkey PRIMARY KEY (id),
  CONSTRAINT user_tournament_achievements_unique UNIQUE (user_id, achievement_id)
);

-- 9. 錦標賽稱號表
CREATE TABLE public.tournament_titles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  icon text NOT NULL,
  color text NOT NULL DEFAULT '#FFD700',
  rarity text NOT NULL CHECK (rarity = ANY (ARRAY['bronze'::text, 'silver'::text, 'gold'::text, 'platinum'::text, 'diamond'::text])),
  requirements text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT tournament_titles_pkey PRIMARY KEY (id)
);

-- 10. 用戶錦標賽稱號記錄表
CREATE TABLE public.user_tournament_titles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  title_id uuid NOT NULL REFERENCES public.tournament_titles(id),
  tournament_id uuid REFERENCES public.tournaments(id) ON DELETE SET NULL,
  earned_at timestamp with time zone DEFAULT now(),
  is_active boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_tournament_titles_pkey PRIMARY KEY (id),
  CONSTRAINT user_tournament_titles_unique UNIQUE (user_id, title_id)
);

-- ============================================================================
-- 索引優化
-- ============================================================================

-- 錦標賽查詢索引
CREATE INDEX idx_tournaments_status ON public.tournaments(status);
CREATE INDEX idx_tournaments_type ON public.tournaments(type);
CREATE INDEX idx_tournaments_start_date ON public.tournaments(start_date);
CREATE INDEX idx_tournaments_is_featured ON public.tournaments(is_featured);

-- 參與者查詢索引
CREATE INDEX idx_tournament_participants_tournament_id ON public.tournament_participants(tournament_id);
CREATE INDEX idx_tournament_participants_user_id ON public.tournament_participants(user_id);
CREATE INDEX idx_tournament_participants_rank ON public.tournament_participants(current_rank);

-- 交易記錄查詢索引
CREATE INDEX idx_tournament_trading_records_user_id ON public.tournament_trading_records(user_id);
CREATE INDEX idx_tournament_trading_records_tournament_id ON public.tournament_trading_records(tournament_id);
CREATE INDEX idx_tournament_trading_records_timestamp ON public.tournament_trading_records(timestamp);

-- 持倉查詢索引
CREATE INDEX idx_tournament_positions_tournament_user ON public.tournament_positions(tournament_id, user_id);
CREATE INDEX idx_tournament_positions_symbol ON public.tournament_positions(symbol);

-- 活動記錄查詢索引
CREATE INDEX idx_tournament_activities_tournament_id ON public.tournament_activities(tournament_id);
CREATE INDEX idx_tournament_activities_timestamp ON public.tournament_activities(timestamp);

-- 排行榜快照查詢索引
CREATE INDEX idx_tournament_ranking_snapshots_tournament_date ON public.tournament_ranking_snapshots(tournament_id, snapshot_date);
CREATE INDEX idx_tournament_ranking_snapshots_rank ON public.tournament_ranking_snapshots(rank);

-- ============================================================================
-- RLS (Row Level Security) 政策
-- ============================================================================

-- 啟用 RLS
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_trading_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_ranking_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tournament_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tournament_titles ENABLE ROW LEVEL SECURITY;

-- 錦標賽讀取政策（所有人可讀）
CREATE POLICY "Anyone can view tournaments" ON public.tournaments FOR SELECT USING (true);

-- 錦標賽建立政策（只有 test03 可建立）
CREATE POLICY "Only test03 can create tournaments" ON public.tournaments FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND username = 'test03'
  )
);

-- 參與者數據政策（用戶可查看所有，但只能修改自己的）
CREATE POLICY "Anyone can view tournament participants" ON public.tournament_participants FOR SELECT USING (true);
CREATE POLICY "Users can manage own tournament participation" ON public.tournament_participants FOR ALL 
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 交易記錄政策（用戶只能查看和建立自己的）
CREATE POLICY "Users can manage own tournament trading records" ON public.tournament_trading_records FOR ALL 
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 持倉政策（用戶只能查看和管理自己的）
CREATE POLICY "Users can manage own tournament positions" ON public.tournament_positions FOR ALL 
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 活動記錄政策（所有人可讀，系統建立）
CREATE POLICY "Anyone can view tournament activities" ON public.tournament_activities FOR SELECT USING (true);

-- 排行榜快照政策（所有人可讀）
CREATE POLICY "Anyone can view tournament ranking snapshots" ON public.tournament_ranking_snapshots FOR SELECT USING (true);

-- 成就政策（用戶只能查看和管理自己的）
CREATE POLICY "Users can manage own tournament achievements" ON public.user_tournament_achievements FOR ALL 
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 稱號政策（用戶只能查看和管理自己的）
CREATE POLICY "Users can manage own tournament titles" ON public.user_tournament_titles FOR ALL 
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- ============================================================================
-- 觸發器和函數
-- ============================================================================

-- 自動更新錦標賽參與者數量
CREATE OR REPLACE FUNCTION update_tournament_participant_count()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_tournament_participant_count
  AFTER INSERT OR DELETE ON public.tournament_participants
  FOR EACH ROW EXECUTE FUNCTION update_tournament_participant_count();

-- 自動計算錦標賽排名
CREATE OR REPLACE FUNCTION calculate_tournament_rankings(tournament_uuid uuid)
RETURNS void AS $$
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 初始數據
-- ============================================================================

-- 插入錦標賽成就
INSERT INTO public.tournament_achievements (name, description, icon, rarity, requirements, reward_amount) VALUES
('首次交易', '完成第一筆交易', 'chart.line.uptrend.xyaxis', 'common', '{"trades": 1}', 1000),
('活躍交易者', '單日完成10筆交易', 'flame.fill', 'rare', '{"daily_trades": 10}', 5000),
('獲利高手', '單筆交易獲利超過10%', 'dollarsign.circle.fill', 'epic', '{"single_trade_profit": 0.1}', 10000),
('排行榜前三', '進入錦標賽前三名', 'crown.fill', 'legendary', '{"rank": 3}', 50000),
('錦標賽冠軍', '獲得錦標賽第一名', 'trophy.fill', 'mythic', '{"rank": 1}', 100000);

-- 插入錦標賽稱號
INSERT INTO public.tournament_titles (name, description, icon, color, rarity, requirements) VALUES
('新手交易員', '完成首次錦標賽參與', 'graduationcap.fill', '#CD7F32', 'bronze', '參與任意錦標賽'),
('銀級投資者', '在錦標賽中獲得前10名', 'medal.fill', '#C0C0C0', 'silver', '錦標賽排名前10'),
('金級操盤手', '在錦標賽中獲得前3名', 'crown.fill', '#FFD700', 'gold', '錦標賽排名前3'),
('白金策略師', '連續3次錦標賽獲得前5名', 'star.fill', '#E5E4E2', 'platinum', '連續3次前5名'),
('鑽石大師', '獲得錦標賽冠軍', 'diamond.fill', '#B9F2FF', 'diamond', '錦標賽第1名');