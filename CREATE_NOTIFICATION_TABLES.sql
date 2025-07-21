-- 建立通知設定表
CREATE TABLE IF NOT EXISTS public.notification_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    push_notifications_enabled BOOLEAN DEFAULT true,
    market_updates_enabled BOOLEAN DEFAULT true,
    chat_notifications_enabled BOOLEAN DEFAULT true,
    investment_notifications_enabled BOOLEAN DEFAULT true,
    stock_price_alerts_enabled BOOLEAN DEFAULT true,
    ranking_updates_enabled BOOLEAN DEFAULT true,
    host_messages_enabled BOOLEAN DEFAULT true,
    device_token TEXT, -- Apple推播用的device token
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 建立通知記錄表
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL CHECK (
        notification_type IN (
            'host_message',       -- 主持人訊息
            'ranking_update',     -- 排名更新
            'stock_price_alert',  -- 股價到價提醒
            'chat_message',       -- 聊天訊息
            'investment_update',  -- 投資更新
            'market_news',        -- 市場新聞
            'system_alert'        -- 系統通知
        )
    ),
    data JSONB, -- 額外的通知資料
    read_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    INDEX(user_id, created_at DESC),
    INDEX(notification_type, created_at DESC)
);

-- 建立股價提醒表
CREATE TABLE IF NOT EXISTS public.stock_price_alerts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stock_symbol VARCHAR(20) NOT NULL, -- 股票代碼
    stock_name TEXT NOT NULL, -- 股票名稱
    target_price DECIMAL(10,2) NOT NULL, -- 目標價格
    condition VARCHAR(10) NOT NULL CHECK (condition IN ('above', 'below')), -- 條件：高於或低於
    is_active BOOLEAN DEFAULT true,
    triggered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    INDEX(user_id, is_active),
    INDEX(stock_symbol, is_active)
);

-- 啟用 RLS (Row Level Security)
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_price_alerts ENABLE ROW LEVEL SECURITY;

-- 建立 RLS 政策
CREATE POLICY "用戶只能存取自己的通知設定" ON public.notification_settings
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "用戶只能存取自己的通知" ON public.notifications
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "用戶只能存取自己的股價提醒" ON public.stock_price_alerts
    FOR ALL USING (auth.uid() = user_id);

-- 建立更新時間的觸發器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_notification_settings_updated_at BEFORE UPDATE
    ON public.notification_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stock_price_alerts_updated_at BEFORE UPDATE
    ON public.stock_price_alerts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
    ON public.notifications(user_id, read_at) WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_type_created 
    ON public.notifications(notification_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stock_alerts_active 
    ON public.stock_price_alerts(user_id, is_active, stock_symbol) WHERE is_active = true;

-- 插入預設通知設定（當用戶註冊時自動觸發）
CREATE OR REPLACE FUNCTION create_default_notification_settings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notification_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 在用戶表上建立觸發器（假設用戶註冊會在auth.users表中創建記錄）
-- 注意: 這個觸發器可能需要根據實際的用戶註冊流程調整
CREATE OR REPLACE TRIGGER create_user_notification_settings
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_default_notification_settings();

-- 建立通知統計視圖
CREATE OR REPLACE VIEW user_notification_stats AS
SELECT 
    ns.user_id,
    COUNT(n.id) as total_notifications,
    COUNT(CASE WHEN n.read_at IS NULL THEN 1 END) as unread_count,
    COUNT(CASE WHEN n.notification_type = 'host_message' THEN 1 END) as host_message_count,
    COUNT(CASE WHEN n.notification_type = 'ranking_update' THEN 1 END) as ranking_update_count,
    COUNT(CASE WHEN n.notification_type = 'stock_price_alert' THEN 1 END) as stock_alert_count,
    MAX(n.created_at) as latest_notification_at
FROM public.notification_settings ns
LEFT JOIN public.notifications n ON ns.user_id = n.user_id
GROUP BY ns.user_id;

-- 建立清理舊通知的函數
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- 刪除30天前的已讀通知
    DELETE FROM public.notifications 
    WHERE read_at IS NOT NULL 
    AND read_at < NOW() - INTERVAL '30 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- 刪除90天前的未讀通知
    DELETE FROM public.notifications 
    WHERE read_at IS NULL 
    AND created_at < NOW() - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = deleted_count + ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ language 'plpgsql';

COMMENT ON TABLE public.notification_settings IS '用戶推播通知設定表';
COMMENT ON TABLE public.notifications IS '通知記錄表，儲存所有發送給用戶的通知';
COMMENT ON TABLE public.stock_price_alerts IS '股價到價提醒設定表';
COMMENT ON FUNCTION cleanup_old_notifications() IS '清理舊通知的維護函數';