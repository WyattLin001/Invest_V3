-- =====================================================
-- Row Level Security (RLS) Policies for Push Notifications
-- Created: 2025-08-06
-- Description: Comprehensive security policies for push notification system
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_notification_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_rate_limits ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- DEVICE TOKENS POLICIES
-- =====================================================

-- Users can view and manage their own device tokens
CREATE POLICY "users_can_view_own_device_tokens" ON device_tokens
    FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "users_can_insert_own_device_tokens" ON device_tokens
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_update_own_device_tokens" ON device_tokens
    FOR UPDATE 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_delete_own_device_tokens" ON device_tokens
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Service role can manage all device tokens
CREATE POLICY "service_role_can_manage_device_tokens" ON device_tokens
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- NOTIFICATION TEMPLATES POLICIES
-- =====================================================

-- All authenticated users can view active templates
CREATE POLICY "authenticated_users_can_view_active_templates" ON notification_templates
    FOR SELECT 
    TO authenticated
    USING (is_active = true);

-- Only admins can manage templates
CREATE POLICY "admins_can_manage_templates" ON notification_templates
    FOR ALL 
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        (auth.jwt() -> 'app_metadata' ->> 'role')::text = 'admin'
    );

-- =====================================================
-- USER NOTIFICATION PREFERENCES POLICIES
-- =====================================================

-- Users can view and manage their own preferences
CREATE POLICY "users_can_view_own_preferences" ON user_notification_preferences
    FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "users_can_insert_own_preferences" ON user_notification_preferences
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_update_own_preferences" ON user_notification_preferences
    FOR UPDATE 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_delete_own_preferences" ON user_notification_preferences
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Service role can manage all preferences
CREATE POLICY "service_role_can_manage_preferences" ON user_notification_preferences
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- NOTIFICATION QUEUE POLICIES
-- =====================================================

-- Users can view their own queued notifications
CREATE POLICY "users_can_view_own_queue" ON notification_queue
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Only service role can manage the queue
CREATE POLICY "service_role_can_manage_queue" ON notification_queue
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Edge functions can manage the queue
CREATE POLICY "edge_functions_can_manage_queue" ON notification_queue
    FOR ALL 
    USING (auth.jwt() ->> 'iss' = 'supabase');

-- =====================================================
-- NOTIFICATION LOGS POLICIES
-- =====================================================

-- Users can view their own notification logs
CREATE POLICY "users_can_view_own_logs" ON notification_logs
    FOR SELECT 
    USING (auth.uid()::text = user_id);

-- Service role can manage all logs
CREATE POLICY "service_role_can_manage_logs" ON notification_logs
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Edge functions can insert logs
CREATE POLICY "edge_functions_can_insert_logs" ON notification_logs
    FOR INSERT 
    WITH CHECK (auth.jwt() ->> 'iss' = 'supabase');

-- =====================================================
-- NOTIFICATION ANALYTICS POLICIES
-- =====================================================

-- Admins can view all analytics
CREATE POLICY "admins_can_view_analytics" ON notification_analytics
    FOR SELECT 
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        (auth.jwt() -> 'app_metadata' ->> 'role')::text = 'admin'
    );

-- Service role can manage analytics
CREATE POLICY "service_role_can_manage_analytics" ON notification_analytics
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Edge functions can update analytics
CREATE POLICY "edge_functions_can_update_analytics" ON notification_analytics
    FOR ALL 
    USING (auth.jwt() ->> 'iss' = 'supabase');

-- =====================================================
-- BULK NOTIFICATION CAMPAIGNS POLICIES
-- =====================================================

-- Admins can view all campaigns
CREATE POLICY "admins_can_view_campaigns" ON bulk_notification_campaigns
    FOR SELECT 
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        (auth.jwt() -> 'app_metadata' ->> 'role')::text = 'admin'
    );

-- Admins can create campaigns
CREATE POLICY "admins_can_create_campaigns" ON bulk_notification_campaigns
    FOR INSERT 
    WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR
        (auth.jwt() -> 'app_metadata' ->> 'role')::text = 'admin'
    );

-- Campaign creators can update their own campaigns
CREATE POLICY "creators_can_update_own_campaigns" ON bulk_notification_campaigns
    FOR UPDATE 
    USING (
        auth.uid() = created_by OR
        auth.jwt() ->> 'role' = 'service_role' OR
        (auth.jwt() -> 'app_metadata' ->> 'role')::text = 'admin'
    );

-- Service role can manage all campaigns
CREATE POLICY "service_role_can_manage_campaigns" ON bulk_notification_campaigns
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- RATE LIMITING POLICIES
-- =====================================================

-- Users can view their own rate limits
CREATE POLICY "users_can_view_own_rate_limits" ON notification_rate_limits
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Service role can manage all rate limits
CREATE POLICY "service_role_can_manage_rate_limits" ON notification_rate_limits
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Edge functions can manage rate limits
CREATE POLICY "edge_functions_can_manage_rate_limits" ON notification_rate_limits
    FOR ALL 
    USING (auth.jwt() ->> 'iss' = 'supabase');

-- =====================================================
-- ADDITIONAL SECURITY FUNCTIONS
-- =====================================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        auth.jwt() ->> 'role' = 'service_role' OR
        (auth.jwt() -> 'app_metadata' ->> 'role')::text = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if request is from edge function
CREATE OR REPLACE FUNCTION is_edge_function()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN auth.jwt() ->> 'iss' = 'supabase';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's notification preferences
CREATE OR REPLACE FUNCTION get_user_notification_preferences(notification_type_filter TEXT DEFAULT NULL)
RETURNS TABLE (
    notification_type TEXT,
    is_enabled BOOLEAN,
    delivery_method TEXT[],
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    timezone TEXT,
    frequency TEXT,
    custom_settings JSONB
) 
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    RETURN QUERY
    SELECT 
        unp.notification_type,
        unp.is_enabled,
        unp.delivery_method,
        unp.quiet_hours_start,
        unp.quiet_hours_end,
        unp.timezone,
        unp.frequency,
        unp.custom_settings
    FROM user_notification_preferences unp
    WHERE unp.user_id = current_user_id
    AND (notification_type_filter IS NULL OR unp.notification_type = notification_type_filter);
END;
$$ LANGUAGE plpgsql;

-- Function to check if user can receive notifications at current time
CREATE OR REPLACE FUNCTION can_user_receive_notification(
    target_user_id UUID,
    notification_type_param TEXT
)
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
DECLARE
    user_prefs RECORD;
    current_time_in_user_tz TIME;
    current_day_of_week INTEGER;
BEGIN
    -- Get user preferences
    SELECT * INTO user_prefs
    FROM user_notification_preferences
    WHERE user_id = target_user_id 
    AND notification_type = notification_type_param;
    
    -- If no preferences found or notifications disabled, return false
    IF user_prefs IS NULL OR NOT user_prefs.is_enabled THEN
        RETURN FALSE;
    END IF;
    
    -- Convert current time to user's timezone
    current_time_in_user_tz := (NOW() AT TIME ZONE user_prefs.timezone)::TIME;
    
    -- Check quiet hours
    IF user_prefs.quiet_hours_start IS NOT NULL AND user_prefs.quiet_hours_end IS NOT NULL THEN
        -- Handle quiet hours that span midnight
        IF user_prefs.quiet_hours_start <= user_prefs.quiet_hours_end THEN
            -- Normal case: quiet hours within same day
            IF current_time_in_user_tz BETWEEN user_prefs.quiet_hours_start AND user_prefs.quiet_hours_end THEN
                RETURN FALSE;
            END IF;
        ELSE
            -- Quiet hours span midnight
            IF current_time_in_user_tz >= user_prefs.quiet_hours_start OR current_time_in_user_tz <= user_prefs.quiet_hours_end THEN
                RETURN FALSE;
            END IF;
        END IF;
    END IF;
    
    -- Additional frequency checks can be added here
    -- For now, assuming immediate delivery for all notification types
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to safely get device tokens for user
CREATE OR REPLACE FUNCTION get_user_active_device_tokens(target_user_id UUID)
RETURNS TABLE (
    id UUID,
    device_token TEXT,
    device_type TEXT,
    environment TEXT
)
SECURITY DEFINER
AS $$
BEGIN
    -- Only allow service role or the user themselves to access device tokens
    IF NOT (auth.jwt() ->> 'role' = 'service_role' OR auth.uid() = target_user_id) THEN
        RAISE EXCEPTION 'Insufficient permissions to access device tokens';
    END IF;
    
    RETURN QUERY
    SELECT 
        dt.id,
        dt.device_token,
        dt.device_type,
        dt.environment
    FROM device_tokens dt
    WHERE dt.user_id = target_user_id 
    AND dt.is_active = true
    AND dt.last_used_at > NOW() - INTERVAL '30 days'; -- Only include recently used tokens
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant necessary permissions to authenticated users
GRANT SELECT ON notification_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notification_preferences TO authenticated;
GRANT SELECT ON device_tokens TO authenticated;
GRANT SELECT ON notification_logs TO authenticated;

-- Grant permissions to service role (for edge functions)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- =====================================================
-- COMMENTS ON POLICIES
-- =====================================================

COMMENT ON POLICY "users_can_view_own_device_tokens" ON device_tokens IS 'Users can only view their own device tokens for privacy';
COMMENT ON POLICY "authenticated_users_can_view_active_templates" ON notification_templates IS 'All authenticated users can view active notification templates';
COMMENT ON POLICY "users_can_view_own_preferences" ON user_notification_preferences IS 'Users can manage their own notification preferences';
COMMENT ON POLICY "service_role_can_manage_queue" ON notification_queue IS 'Only service role can manage the notification queue for security';
COMMENT ON POLICY "users_can_view_own_logs" ON notification_logs IS 'Users can view their own notification history';
COMMENT ON POLICY "admins_can_view_analytics" ON notification_analytics IS 'Only admins can view system-wide analytics';

COMMENT ON FUNCTION is_admin() IS 'Helper function to check if current user is an admin';
COMMENT ON FUNCTION is_edge_function() IS 'Helper function to check if request comes from an edge function';
COMMENT ON FUNCTION get_user_notification_preferences(TEXT) IS 'Securely retrieve user notification preferences';
COMMENT ON FUNCTION can_user_receive_notification(UUID, TEXT) IS 'Check if user can receive notifications based on preferences and quiet hours';
COMMENT ON FUNCTION get_user_active_device_tokens(UUID) IS 'Securely retrieve active device tokens for a user';