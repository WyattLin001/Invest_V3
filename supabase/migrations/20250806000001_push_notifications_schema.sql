-- =====================================================
-- Push Notifications Database Schema
-- Created: 2025-08-06
-- Description: Comprehensive schema for push notification system
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. Device Tokens Table
-- =====================================================
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    device_type TEXT NOT NULL CHECK (device_type IN ('ios', 'android', 'web')),
    app_version TEXT,
    os_version TEXT,
    device_model TEXT,
    environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')) DEFAULT 'sandbox',
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique device token per user
    UNIQUE(user_id, device_token)
);

-- =====================================================
-- 2. Notification Templates Table
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_key TEXT NOT NULL UNIQUE,
    template_name TEXT NOT NULL,
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    category TEXT,
    sound TEXT DEFAULT 'default',
    badge_increment INTEGER DEFAULT 1,
    action_url TEXT,
    custom_data JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. User Notification Preferences Table
-- =====================================================
CREATE TABLE IF NOT EXISTS user_notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    delivery_method TEXT[] DEFAULT ARRAY['push'], -- push, email, sms
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    timezone TEXT DEFAULT 'Asia/Taipei',
    frequency TEXT DEFAULT 'immediate' CHECK (frequency IN ('immediate', 'hourly', 'daily', 'weekly')),
    custom_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique preference per user per type
    UNIQUE(user_id, notification_type)
);

-- =====================================================
-- 4. Notification Queue Table
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token_id UUID REFERENCES device_tokens(id) ON DELETE SET NULL,
    template_key TEXT REFERENCES notification_templates(template_key),
    notification_type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10), -- 1 = highest, 10 = lowest
    scheduled_for TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    max_retry_attempts INTEGER DEFAULT 3,
    retry_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')),
    error_message TEXT,
    sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. Notification Logs Table
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    queue_id UUID REFERENCES notification_queue(id) ON DELETE SET NULL,
    user_id UUID NOT NULL,
    device_token TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    apns_response JSONB,
    http_status_code INTEGER,
    delivery_status TEXT NOT NULL CHECK (delivery_status IN ('sent', 'delivered', 'failed', 'expired')),
    error_code TEXT,
    error_message TEXT,
    retry_attempt INTEGER DEFAULT 0,
    processing_time_ms INTEGER,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE,
    opened_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 6. Notification Analytics Table
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL,
    notification_type TEXT NOT NULL,
    template_key TEXT,
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_failed INTEGER DEFAULT 0,
    delivery_rate DECIMAL(5,4),
    open_rate DECIMAL(5,4),
    failure_rate DECIMAL(5,4),
    avg_processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique analytics per date per type
    UNIQUE(date, notification_type, template_key)
);

-- =====================================================
-- 7. Bulk Notification Campaigns Table
-- =====================================================
CREATE TABLE IF NOT EXISTS bulk_notification_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_name TEXT NOT NULL,
    template_key TEXT REFERENCES notification_templates(template_key),
    target_criteria JSONB NOT NULL DEFAULT '{}', -- JSON criteria for targeting users
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB DEFAULT '{}',
    scheduled_for TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'processing', 'completed', 'failed', 'cancelled')),
    total_recipients INTEGER DEFAULT 0,
    total_sent INTEGER DEFAULT 0,
    total_failed INTEGER DEFAULT 0,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- 8. Rate Limiting Table
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    window_duration INTERVAL NOT NULL DEFAULT '1 hour',
    max_notifications INTEGER NOT NULL DEFAULT 100,
    current_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique rate limit per user per type per window
    UNIQUE(user_id, notification_type, window_start)
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Device Tokens Indexes
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX idx_device_tokens_device_token ON device_tokens(device_token);
CREATE INDEX idx_device_tokens_is_active ON device_tokens(is_active) WHERE is_active = true;
CREATE INDEX idx_device_tokens_last_used ON device_tokens(last_used_at);

-- Notification Templates Indexes
CREATE INDEX idx_notification_templates_template_key ON notification_templates(template_key);
CREATE INDEX idx_notification_templates_is_active ON notification_templates(is_active) WHERE is_active = true;

-- User Preferences Indexes
CREATE INDEX idx_user_preferences_user_id ON user_notification_preferences(user_id);
CREATE INDEX idx_user_preferences_type ON user_notification_preferences(notification_type);
CREATE INDEX idx_user_preferences_enabled ON user_notification_preferences(is_enabled) WHERE is_enabled = true;

-- Notification Queue Indexes
CREATE INDEX idx_notification_queue_user_id ON notification_queue(user_id);
CREATE INDEX idx_notification_queue_status ON notification_queue(status);
CREATE INDEX idx_notification_queue_scheduled ON notification_queue(scheduled_for);
CREATE INDEX idx_notification_queue_priority ON notification_queue(priority);
CREATE INDEX idx_notification_queue_type ON notification_queue(notification_type);
CREATE INDEX idx_notification_queue_processing ON notification_queue(status, scheduled_for, priority) 
    WHERE status IN ('pending', 'processing');

-- Notification Logs Indexes
CREATE INDEX idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX idx_notification_logs_type ON notification_logs(notification_type);
CREATE INDEX idx_notification_logs_status ON notification_logs(delivery_status);
CREATE INDEX idx_notification_logs_sent_at ON notification_logs(sent_at);
CREATE INDEX idx_notification_logs_queue_id ON notification_logs(queue_id);

-- Analytics Indexes
CREATE INDEX idx_notification_analytics_date ON notification_analytics(date);
CREATE INDEX idx_notification_analytics_type ON notification_analytics(notification_type);
CREATE INDEX idx_notification_analytics_template ON notification_analytics(template_key);

-- Campaign Indexes
CREATE INDEX idx_bulk_campaigns_status ON bulk_notification_campaigns(status);
CREATE INDEX idx_bulk_campaigns_scheduled ON bulk_notification_campaigns(scheduled_for);
CREATE INDEX idx_bulk_campaigns_created_by ON bulk_notification_campaigns(created_by);

-- Rate Limiting Indexes
CREATE INDEX idx_rate_limits_user_type ON notification_rate_limits(user_id, notification_type);
CREATE INDEX idx_rate_limits_window ON notification_rate_limits(window_start, window_duration);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to tables with updated_at columns
CREATE TRIGGER update_device_tokens_updated_at 
    BEFORE UPDATE ON device_tokens 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_templates_updated_at 
    BEFORE UPDATE ON notification_templates 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at 
    BEFORE UPDATE ON user_notification_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_queue_updated_at 
    BEFORE UPDATE ON notification_queue 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_updated_at 
    BEFORE UPDATE ON notification_analytics 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campaigns_updated_at 
    BEFORE UPDATE ON bulk_notification_campaigns 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rate_limits_updated_at 
    BEFORE UPDATE ON notification_rate_limits 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- INITIAL DATA - NOTIFICATION TEMPLATES
-- =====================================================

INSERT INTO notification_templates (template_key, template_name, title_template, body_template, category, custom_data) VALUES
-- Host Message Template
('host_message', 'Host Message', '來自 {{host_name}} 的訊息', '{{message}}', 'HOST_MESSAGE', '{"actions": [{"action": "reply", "title": "回覆"}, {"action": "view", "title": "查看"}]}'),

-- Stock Alert Template  
('stock_alert', 'Stock Price Alert', '股價到價提醒', '{{stock_name}} ({{stock_symbol}}) 已達到目標價格 ${{target_price}}，目前價格 ${{current_price}}', 'STOCK_ALERT', '{"actions": [{"action": "view_stock", "title": "查看股票"}, {"action": "set_alert", "title": "設置提醒"}]}'),

-- Ranking Update Template
('ranking_update', 'Ranking Update', '排名更新', '{{ranking_message}}', 'RANKING_UPDATE', '{"actions": [{"action": "view_ranking", "title": "查看排行榜"}]}'),

-- Chat Message Template
('chat_message', 'Chat Message', '{{sender_name}}', '{{message}}', 'CHAT_MESSAGE', '{"actions": [{"action": "reply", "title": "回覆"}, {"action": "view_chat", "title": "查看對話"}]}'),

-- System Alert Template
('system_alert', 'System Alert', '{{title}}', '{{message}}', 'SYSTEM_ALERT', '{"actions": [{"action": "dismiss", "title": "確認"}]}'),

-- Tournament Reminder Template
('tournament_reminder', 'Tournament Reminder', '錦標賽提醒', '{{tournament_name}} 即將開始，請準備參加！', 'TOURNAMENT_REMINDER', '{"actions": [{"action": "join", "title": "參加"}, {"action": "view_details", "title": "查看詳情"}]}'),

-- Article Update Template
('article_update', 'Article Update', '文章更新', '您關注的作者 {{author_name}} 發佈了新文章：{{article_title}}', 'ARTICLE_UPDATE', '{"actions": [{"action": "read", "title": "閱讀"}, {"action": "save", "title": "收藏"}]}'),

-- Friend Request Template
('friend_request', 'Friend Request', '好友邀請', '{{sender_name}} 想要加您為好友', 'FRIEND_REQUEST', '{"actions": [{"action": "accept", "title": "接受"}, {"action": "decline", "title": "拒絕"}]}');

-- =====================================================
-- DEFAULT USER NOTIFICATION PREFERENCES
-- =====================================================

-- Function to create default notification preferences for new users
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert default preferences for all notification types
    INSERT INTO user_notification_preferences (user_id, notification_type, is_enabled) VALUES
    (NEW.id, 'host_message', true),
    (NEW.id, 'stock_alert', true),
    (NEW.id, 'ranking_update', true),
    (NEW.id, 'chat_message', true),
    (NEW.id, 'system_alert', true),
    (NEW.id, 'tournament_reminder', true),
    (NEW.id, 'article_update', true),
    (NEW.id, 'friend_request', true);
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to create default preferences when a new user signs up
CREATE TRIGGER create_user_notification_preferences_trigger
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to clean up old notification logs (run this periodically)
CREATE OR REPLACE FUNCTION cleanup_old_notification_logs(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notification_logs 
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ language 'plpgsql';

-- Function to update notification analytics
CREATE OR REPLACE FUNCTION update_notification_analytics()
RETURNS void AS $$
BEGIN
    INSERT INTO notification_analytics (
        date, 
        notification_type, 
        template_key,
        total_sent, 
        total_delivered, 
        total_opened, 
        total_failed,
        delivery_rate,
        open_rate,
        failure_rate,
        avg_processing_time_ms
    )
    SELECT 
        DATE(sent_at) as date,
        notification_type,
        (payload->>'template_key')::TEXT as template_key,
        COUNT(*) as total_sent,
        COUNT(*) FILTER (WHERE delivery_status = 'delivered') as total_delivered,
        COUNT(*) FILTER (WHERE opened_at IS NOT NULL) as total_opened,
        COUNT(*) FILTER (WHERE delivery_status = 'failed') as total_failed,
        ROUND(
            COUNT(*) FILTER (WHERE delivery_status = 'delivered')::DECIMAL / 
            NULLIF(COUNT(*), 0), 4
        ) as delivery_rate,
        ROUND(
            COUNT(*) FILTER (WHERE opened_at IS NOT NULL)::DECIMAL / 
            NULLIF(COUNT(*) FILTER (WHERE delivery_status = 'delivered'), 0), 4
        ) as open_rate,
        ROUND(
            COUNT(*) FILTER (WHERE delivery_status = 'failed')::DECIMAL / 
            NULLIF(COUNT(*), 0), 4
        ) as failure_rate,
        AVG(processing_time_ms)::INTEGER as avg_processing_time_ms
    FROM notification_logs
    WHERE DATE(sent_at) = CURRENT_DATE - INTERVAL '1 day'
    GROUP BY DATE(sent_at), notification_type, (payload->>'template_key')::TEXT
    ON CONFLICT (date, notification_type, template_key) 
    DO UPDATE SET
        total_sent = EXCLUDED.total_sent,
        total_delivered = EXCLUDED.total_delivered,
        total_opened = EXCLUDED.total_opened,
        total_failed = EXCLUDED.total_failed,
        delivery_rate = EXCLUDED.delivery_rate,
        open_rate = EXCLUDED.open_rate,
        failure_rate = EXCLUDED.failure_rate,
        avg_processing_time_ms = EXCLUDED.avg_processing_time_ms,
        updated_at = NOW();
END;
$$ language 'plpgsql';

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE device_tokens IS 'Stores device tokens for push notifications with device metadata';
COMMENT ON TABLE notification_templates IS 'Reusable templates for different types of notifications';
COMMENT ON TABLE user_notification_preferences IS 'User preferences for notification types and delivery settings';
COMMENT ON TABLE notification_queue IS 'Queue for pending notifications to be sent';
COMMENT ON TABLE notification_logs IS 'Complete log of all sent notifications with delivery status';
COMMENT ON TABLE notification_analytics IS 'Daily analytics and metrics for notification performance';
COMMENT ON TABLE bulk_notification_campaigns IS 'Bulk notification campaigns for announcements';
COMMENT ON TABLE notification_rate_limits IS 'Rate limiting to prevent notification spam';

COMMENT ON FUNCTION cleanup_old_notification_logs(INTEGER) IS 'Cleans up old notification logs older than specified days';
COMMENT ON FUNCTION update_notification_analytics() IS 'Updates daily analytics from notification logs';
COMMENT ON FUNCTION create_default_notification_preferences() IS 'Creates default notification preferences for new users';