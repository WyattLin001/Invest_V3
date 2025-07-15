# Supabase Database Schema for Competition System

## 競賽系統資料庫結構

### 1. competitions (競賽表)
```sql
CREATE TABLE competitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed')),
    prize_pool DECIMAL(15,2),
    participant_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_competitions_status ON competitions(status);
CREATE INDEX idx_competitions_start_date ON competitions(start_date);
CREATE INDEX idx_competitions_end_date ON competitions(end_date);
```

### 2. competition_participations (競賽參與表)
```sql
CREATE TABLE competition_participations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id UUID NOT NULL REFERENCES competitions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    initial_cash DECIMAL(15,2) DEFAULT 1000000,
    current_value DECIMAL(15,2) DEFAULT 1000000,
    return_rate DECIMAL(8,4) DEFAULT 0,
    rank INTEGER DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(competition_id, user_id)
);

-- 索引
CREATE INDEX idx_competition_participations_competition_id ON competition_participations(competition_id);
CREATE INDEX idx_competition_participations_user_id ON competition_participations(user_id);
CREATE INDEX idx_competition_participations_return_rate ON competition_participations(return_rate DESC);
```

### 3. 更新現有 user_portfolios 表
```sql
-- 添加 group_id 欄位以關聯競賽
ALTER TABLE user_portfolios ADD COLUMN group_id UUID REFERENCES competitions(id) ON DELETE CASCADE;

-- 添加索引
CREATE INDEX idx_user_portfolios_group_id ON user_portfolios(group_id);
```

### 4. 更新現有 portfolio_transactions 表
```sql
-- 確保交易記錄表有正確的結構
ALTER TABLE portfolio_transactions 
ADD COLUMN IF NOT EXISTS competition_id UUID REFERENCES competitions(id) ON DELETE CASCADE;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_portfolio_transactions_competition_id ON portfolio_transactions(competition_id);
```

### 5. competition_rankings (競賽排名視圖)
```sql
CREATE OR REPLACE VIEW competition_rankings AS
SELECT 
    cp.id,
    cp.competition_id,
    cp.user_id,
    up.username,
    up.avatar_url,
    ROW_NUMBER() OVER (PARTITION BY cp.competition_id ORDER BY cp.return_rate DESC) as rank,
    cp.return_rate,
    cp.current_value,
    cp.last_updated
FROM competition_participations cp
LEFT JOIN user_profiles up ON cp.user_id = up.id
WHERE cp.competition_id IS NOT NULL
ORDER BY cp.competition_id, cp.return_rate DESC;
```

### 6. 觸發器和函數

#### 自動更新競賽參與人數
```sql
CREATE OR REPLACE FUNCTION update_competition_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE competitions 
        SET participant_count = participant_count + 1 
        WHERE id = NEW.competition_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE competitions 
        SET participant_count = participant_count - 1 
        WHERE id = OLD.competition_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_participant_count
    AFTER INSERT OR DELETE ON competition_participations
    FOR EACH ROW
    EXECUTE FUNCTION update_competition_participant_count();
```

#### 自動更新競賽狀態
```sql
CREATE OR REPLACE FUNCTION update_competition_status()
RETURNS TRIGGER AS $$
BEGIN
    -- 更新即將開始的競賽為進行中
    UPDATE competitions 
    SET status = 'active' 
    WHERE status = 'upcoming' 
    AND start_date <= NOW();
    
    -- 更新已結束的競賽
    UPDATE competitions 
    SET status = 'completed' 
    WHERE status = 'active' 
    AND end_date <= NOW();
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 每分鐘檢查一次競賽狀態
SELECT cron.schedule('update-competition-status', '* * * * *', 'SELECT update_competition_status();');
```

### 7. 行級安全性 (RLS) 政策

#### competitions 表
```sql
ALTER TABLE competitions ENABLE ROW LEVEL SECURITY;

-- 允許所有已認證用戶查看競賽
CREATE POLICY "Allow authenticated users to view competitions" ON competitions
    FOR SELECT TO authenticated
    USING (true);

-- 只允許管理員創建和修改競賽
CREATE POLICY "Allow admins to manage competitions" ON competitions
    FOR ALL TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');
```

#### competition_participations 表
```sql
ALTER TABLE competition_participations ENABLE ROW LEVEL SECURITY;

-- 允許用戶查看所有參與記錄
CREATE POLICY "Allow users to view participations" ON competition_participations
    FOR SELECT TO authenticated
    USING (true);

-- 允許用戶管理自己的參與記錄
CREATE POLICY "Allow users to manage own participations" ON competition_participations
    FOR ALL TO authenticated
    USING (auth.uid() = user_id);
```

### 8. 存儲過程

#### 更新競賽排名
```sql
CREATE OR REPLACE FUNCTION update_competition_rankings(competition_uuid UUID)
RETURNS VOID AS $$
BEGIN
    -- 更新指定競賽的排名
    WITH ranked_participants AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (ORDER BY return_rate DESC) as new_rank
        FROM competition_participations
        WHERE competition_id = competition_uuid
    )
    UPDATE competition_participations 
    SET rank = rp.new_rank
    FROM ranked_participants rp
    WHERE competition_participations.id = rp.id;
END;
$$ LANGUAGE plpgsql;
```

#### 計算用戶在競賽中的收益率
```sql
CREATE OR REPLACE FUNCTION calculate_competition_return_rate(
    user_uuid UUID, 
    competition_uuid UUID
)
RETURNS DECIMAL(8,4) AS $$
DECLARE
    initial_cash DECIMAL(15,2) := 1000000;
    current_value DECIMAL(15,2) := 0;
    return_rate DECIMAL(8,4) := 0;
BEGIN
    -- 獲取用戶在競賽中的投資組合價值
    SELECT 
        COALESCE(p.total_value, initial_cash) INTO current_value
    FROM user_portfolios p
    WHERE p.user_id = user_uuid 
    AND p.group_id = competition_uuid;
    
    -- 計算收益率
    return_rate := ((current_value - initial_cash) / initial_cash) * 100;
    
    RETURN return_rate;
END;
$$ LANGUAGE plpgsql;
```

### 9. 索引優化
```sql
-- 複合索引用於常見查詢
CREATE INDEX idx_participations_competition_user ON competition_participations(competition_id, user_id);
CREATE INDEX idx_participations_user_competition ON competition_participations(user_id, competition_id);

-- 用於排名查詢的索引
CREATE INDEX idx_participations_competition_rank ON competition_participations(competition_id, return_rate DESC);

-- 用於時間範圍查詢的索引
CREATE INDEX idx_competitions_time_range ON competitions(start_date, end_date);
```

### 10. 測試數據
```sql
-- 插入測試競賽
INSERT INTO competitions (title, description, start_date, end_date, status, prize_pool) VALUES
('週末投資挑戰賽', '為期一週的投資競賽，考驗您的投資眼光', NOW(), NOW() + INTERVAL '7 days', 'active', 50000),
('月度投資大師賽', '長期投資競賽，適合穩健投資者', NOW() + INTERVAL '1 day', NOW() + INTERVAL '30 days', 'upcoming', 100000),
('新手投資體驗賽', '專為投資新手設計的友善競賽', NOW() - INTERVAL '1 day', NOW() + INTERVAL '6 days', 'active', 25000);
```

## 使用說明

1. **創建競賽**: 使用 `competitions` 表創建新的投資競賽
2. **用戶參與**: 通過 `competition_participations` 表記錄用戶參與情況
3. **投資組合**: 利用現有的 `user_portfolios` 表，通過 `group_id` 關聯到競賽
4. **交易記錄**: 使用 `portfolio_transactions` 表記錄競賽中的交易
5. **排名計算**: 通過觸發器和存儲過程自動維護排名
6. **權限控制**: 使用 RLS 確保數據安全

## 性能優化建議

1. 定期清理過期的競賽數據
2. 使用分區表處理大量交易記錄
3. 實現數據緩存減少數據庫查詢
4. 批量更新排名而不是實時更新
5. 使用物化視圖快取複雜查詢結果