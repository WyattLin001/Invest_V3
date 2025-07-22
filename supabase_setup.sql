-- Invest_V3 完整數據庫表結構
-- 請在 Supabase SQL Editor 中執行此腳本

-- 1. 用戶餘額表
CREATE TABLE IF NOT EXISTS user_balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    balance INTEGER DEFAULT 0 NOT NULL CHECK (balance >= 0),
    withdrawable_amount INTEGER DEFAULT 0 NOT NULL CHECK (withdrawable_amount >= 0),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

-- 2. 錢包交易記錄表
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdrawal', 'gift_purchase', 'subscription', 'tip', 'bonus', 'group_entry_fee', 'group_tip')),
    amount INTEGER NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'failed', 'cancelled')),
    payment_method TEXT,
    blockchain_id TEXT,
    recipient_id UUID,
    group_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 3. 創作者收益表
CREATE TABLE IF NOT EXISTS creator_revenues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    revenue_type TEXT NOT NULL CHECK (revenue_type IN ('subscription_share', 'reader_tip', 'group_entry_fee', 'group_tip')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    source_id UUID,
    source_name TEXT,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 4. 提領記錄表
CREATE TABLE IF NOT EXISTS withdrawal_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL CHECK (amount > 0),
    amount_twd INTEGER NOT NULL CHECK (amount_twd > 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    bank_account TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 5. 投資群組表
CREATE TABLE IF NOT EXISTS investment_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    description TEXT,
    token_cost INTEGER DEFAULT 0 NOT NULL CHECK (token_cost >= 0),
    member_count INTEGER DEFAULT 0 NOT NULL CHECK (member_count >= 0),
    max_members INTEGER DEFAULT 100 NOT NULL CHECK (max_members > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 6. 群組成員表
CREATE TABLE IF NOT EXISTS group_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(group_id, user_id)
);

-- 7. 群組邀請表
CREATE TABLE IF NOT EXISTS group_invitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 8. 聊天訊息表
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_command BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 9. 用戶檔案表
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    investment_philosophy TEXT,
    specializations TEXT[],
    years_experience INTEGER DEFAULT 0,
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    article_count INTEGER DEFAULT 0,
    total_return_rate NUMERIC(10,4) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id),
    UNIQUE(display_name)
);

-- 10. 交易排行榜表
CREATE TABLE IF NOT EXISTS trading_rankings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly', 'all')),
    return_rate NUMERIC(10,4) NOT NULL,
    portfolio_value NUMERIC(15,2) NOT NULL,
    rank INTEGER NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 為 test03 用戶初始化基礎數據
DO $$
DECLARE
    test_user_id UUID := 'be5f2785-741e-455c-8a94-2bb2b510f76b';
BEGIN
    -- 初始化用戶餘額
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (test_user_id, 10000, 10000)
    ON CONFLICT (user_id) DO UPDATE SET
        balance = EXCLUDED.balance,
        withdrawable_amount = EXCLUDED.withdrawable_amount,
        updated_at = now();

    -- 初始化用戶檔案
    INSERT INTO user_profiles (user_id, display_name, bio, investment_philosophy)
    VALUES (
        test_user_id, 
        'test03', 
        '測試用戶 - 投資專家',
        '價值投資與長期持有策略'
    )
    ON CONFLICT (user_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        bio = EXCLUDED.bio,
        investment_philosophy = EXCLUDED.investment_philosophy,
        updated_at = now();

    -- 初始化創作者收益數據
    DELETE FROM creator_revenues WHERE creator_id = test_user_id;
    
    INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
    (test_user_id, 'subscription_share', 5300, '平台訂閱分潤收益'),
    (test_user_id, 'reader_tip', 1800, '讀者抖內收益'),
    (test_user_id, 'group_entry_fee', 1950, '群組入會費收益'),
    (test_user_id, 'group_tip', 800, '群組抖內收益');

    RAISE NOTICE '✅ test03 用戶數據初始化完成';
END $$;

-- 啟用 Row Level Security (RLS)
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE creator_revenues ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 創建 RLS 政策
-- 用戶餘額：用戶只能看到自己的餘額
CREATE POLICY "Users can view own balance" ON user_balances
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own balance" ON user_balances
    FOR UPDATE USING (auth.uid() = user_id);

-- 錢包交易：用戶只能看到自己的交易
CREATE POLICY "Users can view own transactions" ON wallet_transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions" ON wallet_transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 創作者收益：創作者只能看到自己的收益
CREATE POLICY "Creators can view own revenue" ON creator_revenues
    FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "System can insert creator revenue" ON creator_revenues
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Creators can delete own revenue" ON creator_revenues
    FOR DELETE USING (auth.uid() = creator_id);

-- 提領記錄：創作者只能看到自己的提領記錄
CREATE POLICY "Creators can view own withdrawals" ON withdrawal_records
    FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Creators can insert own withdrawals" ON withdrawal_records
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

-- 用戶檔案：用戶可以看到所有檔案，但只能修改自己的
CREATE POLICY "Anyone can view profiles" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 創建索引以提高查詢性能
CREATE INDEX IF NOT EXISTS idx_user_balances_user_id ON user_balances(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_creator_revenues_creator_id ON creator_revenues(creator_id);
CREATE INDEX IF NOT EXISTS idx_creator_revenues_created_at ON creator_revenues(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_withdrawal_records_creator_id ON withdrawal_records(creator_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON user_profiles(display_name);

RAISE NOTICE '🎉 Invest_V3 數據庫表結構建立完成！';