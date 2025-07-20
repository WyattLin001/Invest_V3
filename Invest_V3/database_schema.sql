-- 創作者收益系統資料庫結構
-- 需要在 Supabase 中創建以下表格

-- 1. 創作者收益記錄表
CREATE TABLE creator_revenues (
    id TEXT PRIMARY KEY,
    creator_id TEXT NOT NULL,
    revenue_type TEXT NOT NULL CHECK (revenue_type IN ('subscription_share', 'reader_tip', 'group_entry_fee', 'group_tip')),
    amount INTEGER NOT NULL,
    source_id TEXT, -- 來源ID (群組ID、文章ID等)
    source_name TEXT, -- 來源名稱
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 群組捐贈記錄表 (已存在，確保結構正確)
CREATE TABLE IF NOT EXISTS group_donations (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    donor_id TEXT NOT NULL,
    donor_name TEXT NOT NULL,
    amount INTEGER NOT NULL,
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 提領記錄表
CREATE TABLE withdrawal_records (
    id TEXT PRIMARY KEY,
    creator_id TEXT NOT NULL,
    amount INTEGER NOT NULL, -- 金幣數量
    amount_twd INTEGER NOT NULL, -- 台幣數量
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    bank_account TEXT, -- 未來功能：銀行帳戶
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引優化
CREATE INDEX idx_creator_revenues_creator_id ON creator_revenues(creator_id);
CREATE INDEX idx_creator_revenues_type ON creator_revenues(revenue_type);
CREATE INDEX idx_creator_revenues_created_at ON creator_revenues(created_at);

CREATE INDEX idx_group_donations_group_id ON group_donations(group_id);
CREATE INDEX idx_group_donations_donor_id ON group_donations(donor_id);
CREATE INDEX idx_group_donations_created_at ON group_donations(created_at);

CREATE INDEX idx_withdrawal_records_creator_id ON withdrawal_records(creator_id);
CREATE INDEX idx_withdrawal_records_status ON withdrawal_records(status);

-- Row Level Security (RLS) 政策
ALTER TABLE creator_revenues ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_records ENABLE ROW LEVEL SECURITY;

-- 創作者只能看到自己的收益記錄
CREATE POLICY "creators_can_view_own_revenues" ON creator_revenues
    FOR SELECT USING (creator_id = auth.uid()::text);

-- 創作者只能看到自己的提領記錄
CREATE POLICY "creators_can_view_own_withdrawals" ON withdrawal_records
    FOR SELECT USING (creator_id = auth.uid()::text);

-- 群組捐贈記錄所有人都可以看到 (用於排行榜)
CREATE POLICY "donations_are_public" ON group_donations
    FOR SELECT TO authenticated USING (true);