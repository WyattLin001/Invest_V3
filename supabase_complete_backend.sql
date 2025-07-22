-- Invest_V3 完整後端架構 - 基於應用代碼分析
-- 執行前請備份現有數據！

-- ========================================
-- 第1步：完全清理現有用戶和相關數據
-- ========================================

-- 刪除所有觸發器和函數
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS initialize_new_user() CASCADE;
DROP FUNCTION IF EXISTS initialize_current_user_data() CASCADE;
DROP FUNCTION IF EXISTS test_creator_earnings_for_user(UUID) CASCADE;
DROP FUNCTION IF EXISTS manual_user_initialization(UUID) CASCADE;

-- 刪除現有表（CASCADE 會刪除所有依賴）
DROP TABLE IF EXISTS withdrawal_records CASCADE;
DROP TABLE IF EXISTS creator_revenues CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS group_invitations CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS investment_groups CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS friend_requests CASCADE;
DROP TABLE IF EXISTS app_notifications CASCADE;
DROP TABLE IF EXISTS notification_settings CASCADE;
DROP TABLE IF EXISTS user_balances CASCADE;
DROP TABLE IF EXISTS wallet_transactions CASCADE;
DROP TABLE IF EXISTS trading_rankings CASCADE;
DROP TABLE IF EXISTS articles CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- 清理現有認證用戶（如果需要）
-- UNCOMMENT ONLY IF YOU WANT TO DELETE ALL USERS:
-- DELETE FROM auth.users;

-- ========================================
-- 第2步：創建完整的表結構
-- ========================================

-- 1. 用戶資料表 (匹配 UserProfile.swift)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    username TEXT NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    first_name TEXT,
    last_name TEXT,
    full_name TEXT,
    phone TEXT,
    website TEXT,
    location TEXT,
    social_links JSONB DEFAULT '{}',
    investment_philosophy TEXT,
    specializations TEXT[] DEFAULT '{}',
    years_experience INTEGER DEFAULT 0,
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    article_count INTEGER DEFAULT 0,
    total_return_rate NUMERIC(10,4) DEFAULT 0,
    is_verified BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(email),
    UNIQUE(username)
);

-- 2. 通知設置表 (匹配 NotificationSettings)
CREATE TABLE notification_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    push_notifications_enabled BOOLEAN DEFAULT true,
    market_updates_enabled BOOLEAN DEFAULT true,
    chat_notifications_enabled BOOLEAN DEFAULT true,
    investment_notifications_enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

-- 3. 用戶餘額表
CREATE TABLE user_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    balance INTEGER DEFAULT 0 NOT NULL CHECK (balance >= 0),
    withdrawable_amount INTEGER DEFAULT 0 NOT NULL CHECK (withdrawable_amount >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id)
);

-- 4. 錢包交易記錄表 (匹配 WalletTransaction.swift)
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
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

-- 5. 創作者收益表 (匹配應用邏輯)
CREATE TABLE creator_revenues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    revenue_type TEXT NOT NULL CHECK (revenue_type IN ('subscription_share', 'reader_tip', 'group_entry_fee', 'group_tip')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    source_id UUID,
    source_name TEXT,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 6. 提領記錄表
CREATE TABLE withdrawal_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL CHECK (amount > 0),
    amount_twd INTEGER NOT NULL CHECK (amount_twd > 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    bank_account TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 7. 投資群組表 (匹配 InvestmentGroup.swift)
CREATE TABLE investment_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    host_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    description TEXT,
    return_rate NUMERIC(10,4) DEFAULT 0,
    entry_fee TEXT,
    token_cost INTEGER DEFAULT 0 NOT NULL CHECK (token_cost >= 0),
    member_count INTEGER DEFAULT 0 NOT NULL CHECK (member_count >= 0),
    max_members INTEGER DEFAULT 100 NOT NULL CHECK (max_members > 0),
    category TEXT,
    rules TEXT,
    is_private BOOLEAN DEFAULT false,
    invite_code TEXT,
    portfolio_value NUMERIC(15,2) DEFAULT 0,
    ranking_position INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 8. 群組成員表 (匹配 GroupMember.swift)
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('host', 'admin', 'member')),
    portfolio_value NUMERIC(15,2) DEFAULT 0,
    return_rate NUMERIC(10,4) DEFAULT 0,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(group_id, user_id)
);

-- 9. 群組邀請表
CREATE TABLE group_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 10. 聊天訊息表 (匹配 ChatMessage.swift)
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES investment_groups(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    content TEXT NOT NULL,
    is_investment_command BOOLEAN DEFAULT false,
    user_role TEXT DEFAULT 'member',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 11. 文章表 (匹配 Article.swift)
CREATE TABLE articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    author_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    summary TEXT NOT NULL,
    full_content TEXT NOT NULL,
    body_md TEXT,
    category TEXT NOT NULL,
    read_time TEXT DEFAULT '5 分鐘',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    is_free BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 12. 應用通知表 (匹配 AppNotification.swift)
CREATE TABLE app_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    notification_type TEXT NOT NULL CHECK (notification_type IN ('host_message', 'ranking_update', 'stock_price_alert', 'chat_message', 'investment_update', 'market_news', 'system_alert', 'group_invite', 'trading_alert')),
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 13. 好友關係表 (匹配 FriendModels.swift)
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'blocked')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(requester_id, addressee_id)
);

-- 14. 交易排行榜表 (匹配應用邏輯)
CREATE TABLE trading_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly', 'all')),
    return_rate NUMERIC(10,4) NOT NULL,
    portfolio_value NUMERIC(15,2) NOT NULL,
    rank INTEGER NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 15. 訂閱表 (匹配訂閱功能)
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscriber_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    subscription_type TEXT NOT NULL DEFAULT 'monthly' CHECK (subscription_type IN ('monthly', 'yearly')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired')),
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(subscriber_id, author_id)
);

-- ========================================
-- 第3步：設置 RLS (Row Level Security)
-- ========================================

-- 啟用 RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE creator_revenues ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE investment_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- 創建通用的 RLS 政策 (初期使用寬鬆政策)
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('user_profiles', 'notification_settings', 'user_balances', 'wallet_transactions', 'creator_revenues', 'withdrawal_records', 'investment_groups', 'group_members', 'group_invitations', 'chat_messages', 'articles', 'app_notifications', 'friendships', 'trading_rankings', 'subscriptions')
    LOOP
        EXECUTE format('CREATE POLICY "authenticated_users_all_access" ON %I FOR ALL TO authenticated USING (true) WITH CHECK (true)', tbl);
    END LOOP;
END $$;

-- ========================================
-- 第4步：創建索引以提高性能
-- ========================================

CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_username ON user_profiles(username);
CREATE INDEX idx_user_balances_user_id ON user_balances(user_id);
CREATE INDEX idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_transactions_created_at ON wallet_transactions(created_at DESC);
CREATE INDEX idx_creator_revenues_creator_id ON creator_revenues(creator_id);
CREATE INDEX idx_creator_revenues_created_at ON creator_revenues(created_at DESC);
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_chat_messages_group_id ON chat_messages(group_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_articles_author_id ON articles(author_id);
CREATE INDEX idx_articles_created_at ON articles(created_at DESC);
CREATE INDEX idx_app_notifications_user_id ON app_notifications(user_id);
CREATE INDEX idx_friendships_requester_id ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee_id ON friendships(addressee_id);

-- ========================================
-- 第5步：創建用戶初始化函數
-- ========================================

CREATE OR REPLACE FUNCTION initialize_current_user_data()
RETURNS json AS $$
DECLARE
    current_user_id UUID;
    auth_user_record RECORD;
    display_name_text TEXT;
    username_text TEXT;
    counter INTEGER := 0;
BEGIN
    -- 獲取當前認證用戶
    SELECT * INTO auth_user_record FROM auth.users WHERE id = auth.uid();
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', '用戶未認證');
    END IF;
    
    current_user_id := auth_user_record.id;
    
    BEGIN
        -- 生成顯示名稱和用戶名
        IF auth_user_record.email IS NOT NULL THEN
            display_name_text := split_part(auth_user_record.email, '@', 1);
            username_text := split_part(auth_user_record.email, '@', 1);
        ELSE
            display_name_text := 'User' || substring(replace(current_user_id::text, '-', ''), 1, 8);
            username_text := 'user' || substring(replace(current_user_id::text, '-', ''), 1, 8);
        END IF;
        
        -- 確保用戶名唯一
        WHILE EXISTS (SELECT 1 FROM user_profiles WHERE username = username_text) LOOP
            counter := counter + 1;
            username_text := username_text || counter::text;
        END LOOP;
        
        -- 創建或更新用戶資料
        INSERT INTO user_profiles (
            id, email, username, display_name, bio, investment_philosophy
        ) VALUES (
            current_user_id,
            COALESCE(auth_user_record.email, ''),
            username_text,
            display_name_text,
            '投資專家',
            '價值投資策略'
        ) ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            updated_at = now();
        
        -- 創建通知設置
        INSERT INTO notification_settings (user_id)
        VALUES (current_user_id)
        ON CONFLICT (user_id) DO NOTHING;
        
        -- 創建用戶餘額
        INSERT INTO user_balances (user_id, balance, withdrawable_amount)
        VALUES (current_user_id, 10000, 10000)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = GREATEST(user_balances.balance, 10000),
            withdrawable_amount = GREATEST(user_balances.withdrawable_amount, 10000);
        
        -- 創建創作者收益數據
        DELETE FROM creator_revenues WHERE creator_id = current_user_id;
        INSERT INTO creator_revenues (creator_id, revenue_type, amount, description) VALUES
        (current_user_id, 'subscription_share', 5300, '訂閱分潤'),
        (current_user_id, 'reader_tip', 1800, '讀者抖內'),
        (current_user_id, 'group_entry_fee', 1950, '群組入會費'),
        (current_user_id, 'group_tip', 800, '群組抖內');
        
        RETURN json_build_object(
            'success', true,
            'message', '用戶數據初始化完成',
            'user_id', current_user_id::text,
            'username', username_text,
            'display_name', display_name_text,
            'email', COALESCE(auth_user_record.email, ''),
            'balance', 10000,
            'total_revenue', 9850
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object(
                'success', false, 
                'message', '初始化失敗: ' || SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION initialize_current_user_data() TO authenticated;

-- ========================================
-- 第6步：創建新用戶註冊觸發器
-- ========================================

CREATE OR REPLACE FUNCTION handle_new_user_signup()
RETURNS TRIGGER AS $$
DECLARE
    display_name_text TEXT;
    username_text TEXT;
    counter INTEGER := 0;
BEGIN
    -- 生成基本的用戶名和顯示名稱
    IF NEW.email IS NOT NULL THEN
        display_name_text := split_part(NEW.email, '@', 1);
        username_text := split_part(NEW.email, '@', 1);
    ELSE
        display_name_text := 'User' || substring(replace(NEW.id::text, '-', ''), 1, 8);
        username_text := 'user' || substring(replace(NEW.id::text, '-', ''), 1, 8);
    END IF;
    
    -- 確保用戶名唯一
    WHILE EXISTS (SELECT 1 FROM user_profiles WHERE username = username_text) LOOP
        counter := counter + 1;
        username_text := username_text || counter::text;
    END LOOP;
    
    -- 創建用戶資料
    INSERT INTO user_profiles (
        id, email, username, display_name, bio, investment_philosophy
    ) VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        username_text,
        display_name_text,
        '新用戶',
        '投資理念待完善'
    );
    
    -- 創建通知設置
    INSERT INTO notification_settings (user_id)
    VALUES (NEW.id);
    
    -- 創建初始餘額
    INSERT INTO user_balances (user_id, balance, withdrawable_amount)
    VALUES (NEW.id, 10000, 10000);
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- 記錄錯誤但不阻止用戶註冊
        RAISE WARNING '新用戶初始化失敗: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建觸發器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_signup();

-- ========================================
-- 第7步：最終檢查和驗證
-- ========================================

SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name AND table_schema = 'public') as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_name IN (
    'user_profiles', 'notification_settings', 'user_balances', 'wallet_transactions', 
    'creator_revenues', 'withdrawal_records', 'investment_groups', 'group_members',
    'group_invitations', 'chat_messages', 'articles', 'app_notifications',
    'friendships', 'trading_rankings', 'subscriptions'
)
ORDER BY table_name;

SELECT '🎉 Invest_V3 完整後端架構建立完成！' as status;
SELECT '📝 註冊新用戶將自動初始化所有必要數據' as note;
SELECT '⚙️ 現有用戶請使用 initialize_current_user_data() 函數初始化數據' as instruction;