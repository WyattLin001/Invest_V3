-- ============================================================================
-- 系統功能表格 - Invest_V3 (乾淨版本)
-- ============================================================================
-- 此腳本創建所有系統功能相關表格，已排除分區和 GENERATED 列問題

-- 1. 系統設定表
CREATE TABLE public.system_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  setting_key text NOT NULL UNIQUE,
  setting_value jsonb NOT NULL,
  description text,
  is_public boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT system_settings_pkey PRIMARY KEY (id)
);

-- 2. 應用版本控制表
CREATE TABLE public.app_versions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  version_number text NOT NULL UNIQUE,
  build_number text NOT NULL,
  platform text NOT NULL CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text, 'web'::text])),
  is_required boolean DEFAULT false,
  is_active boolean DEFAULT true,
  release_notes text,
  download_url text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT app_versions_pkey PRIMARY KEY (id)
);

-- 3. 用戶意見反饋表
CREATE TABLE public.user_feedback (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  feedback_type text NOT NULL CHECK (feedback_type = ANY (ARRAY['bug_report'::text, 'feature_request'::text, 'general_feedback'::text, 'complaint'::text, 'compliment'::text])),
  title text NOT NULL,
  description text NOT NULL,
  contact_email text,
  app_version text,
  device_info jsonb,
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'resolved'::text, 'dismissed'::text])),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  admin_response text,
  response_date timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_feedback_pkey PRIMARY KEY (id)
);

-- 4. 系統公告表
CREATE TABLE public.system_announcements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  announcement_type text NOT NULL CHECK (announcement_type = ANY (ARRAY['maintenance'::text, 'feature'::text, 'event'::text, 'warning'::text, 'info'::text])),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])),
  target_audience text NOT NULL DEFAULT 'all' CHECK (target_audience = ANY (ARRAY['all'::text, 'investors'::text, 'hosts'::text, 'premium'::text, 'beta_users'::text])),
  is_active boolean DEFAULT true,
  show_popup boolean DEFAULT false,
  start_date timestamp with time zone DEFAULT now(),
  end_date timestamp with time zone,
  created_by uuid REFERENCES public.user_profiles(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT system_announcements_pkey PRIMARY KEY (id)
);

-- 5. 用戶公告閱讀記錄表
CREATE TABLE public.user_announcement_reads (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  announcement_id uuid NOT NULL REFERENCES public.system_announcements(id) ON DELETE CASCADE,
  read_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_announcement_reads_pkey PRIMARY KEY (id),
  CONSTRAINT user_announcement_reads_unique UNIQUE (user_id, announcement_id)
);

-- 6. 系統日誌表（用於審計和調試）
CREATE TABLE public.system_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  log_level text NOT NULL CHECK (log_level = ANY (ARRAY['debug'::text, 'info'::text, 'warning'::text, 'error'::text, 'critical'::text])),
  category text NOT NULL,
  message text NOT NULL,
  details jsonb,
  user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  ip_address inet,
  user_agent text,
  request_id text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT system_logs_pkey PRIMARY KEY (id)
);

-- 7. API 使用統計表（簡化版，無分區問題）
CREATE TABLE public.api_usage_stats (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  endpoint text NOT NULL,
  method text NOT NULL,
  user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  response_status integer NOT NULL,
  response_time_ms integer,
  request_size_bytes integer,
  response_size_bytes integer,
  ip_address inet,
  user_agent text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT api_usage_stats_pkey PRIMARY KEY (id)
);

-- 8. 系統維護記錄表
CREATE TABLE public.maintenance_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  maintenance_type text NOT NULL CHECK (maintenance_type = ANY (ARRAY['scheduled'::text, 'emergency'::text, 'hotfix'::text, 'upgrade'::text])),
  title text NOT NULL,
  description text NOT NULL,
  affected_services text[],
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone,
  estimated_duration interval,
  actual_duration interval,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status = ANY (ARRAY['scheduled'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text])),
  performed_by uuid REFERENCES public.user_profiles(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT maintenance_records_pkey PRIMARY KEY (id)
);

-- 9. 用戶偏好設定表（擴展）
CREATE TABLE public.user_preferences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  theme text DEFAULT 'auto' CHECK (theme = ANY (ARRAY['light'::text, 'dark'::text, 'auto'::text])),
  language text DEFAULT 'zh-TW' CHECK (language = ANY (ARRAY['zh-TW'::text, 'zh-CN'::text, 'en-US'::text])),
  currency text DEFAULT 'TWD' CHECK (currency = ANY (ARRAY['TWD'::text, 'USD'::text, 'CNY'::text])),
  timezone text DEFAULT 'Asia/Taipei',
  email_notifications jsonb DEFAULT '{"weekly_summary": true, "investment_alerts": true, "social_updates": false}'::jsonb,
  push_notifications jsonb DEFAULT '{"trading_alerts": true, "chat_messages": true, "friend_requests": true}'::jsonb,
  privacy_settings jsonb DEFAULT '{"profile_visibility": "friends", "trading_history_visibility": "private", "allow_friend_requests": true}'::jsonb,
  trading_preferences jsonb DEFAULT '{"default_order_type": "market", "confirmation_required": true, "risk_warnings": true}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_preferences_pkey PRIMARY KEY (id)
);

-- 10. 內容審查記錄表
CREATE TABLE public.content_moderation (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  content_type text NOT NULL CHECK (content_type = ANY (ARRAY['article'::text, 'comment'::text, 'chat_message'::text, 'user_profile'::text, 'group_description'::text])),
  content_id uuid NOT NULL,
  reported_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'requires_edit'::text])),
  moderator_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  moderator_notes text,
  action_taken text,
  reported_at timestamp with time zone DEFAULT now(),
  reviewed_at timestamp with time zone,
  CONSTRAINT content_moderation_pkey PRIMARY KEY (id)
);

-- ============================================================================
-- 索引優化
-- ============================================================================

-- 系統設定索引
CREATE INDEX idx_system_settings_key ON public.system_settings(setting_key);
CREATE INDEX idx_system_settings_public ON public.system_settings(is_public);

-- 應用版本索引
CREATE INDEX idx_app_versions_platform ON public.app_versions(platform);
CREATE INDEX idx_app_versions_active ON public.app_versions(is_active);

-- 用戶意見反饋索引
CREATE INDEX idx_user_feedback_user_id ON public.user_feedback(user_id);
CREATE INDEX idx_user_feedback_status ON public.user_feedback(status);
CREATE INDEX idx_user_feedback_type ON public.user_feedback(feedback_type);
CREATE INDEX idx_user_feedback_created_at ON public.user_feedback(created_at);

-- 系統公告索引
CREATE INDEX idx_system_announcements_active ON public.system_announcements(is_active);
CREATE INDEX idx_system_announcements_dates ON public.system_announcements(start_date, end_date);
CREATE INDEX idx_system_announcements_audience ON public.system_announcements(target_audience);

-- 公告閱讀記錄索引
CREATE INDEX idx_user_announcement_reads_user_id ON public.user_announcement_reads(user_id);
CREATE INDEX idx_user_announcement_reads_announcement_id ON public.user_announcement_reads(announcement_id);

-- 系統日誌索引
CREATE INDEX idx_system_logs_level ON public.system_logs(log_level);
CREATE INDEX idx_system_logs_category ON public.system_logs(category);
CREATE INDEX idx_system_logs_created_at ON public.system_logs(created_at);
CREATE INDEX idx_system_logs_user_id ON public.system_logs(user_id);

-- API 統計索引
CREATE INDEX idx_api_usage_stats_endpoint ON public.api_usage_stats(endpoint);
CREATE INDEX idx_api_usage_stats_user_id ON public.api_usage_stats(user_id);
CREATE INDEX idx_api_usage_stats_created_at ON public.api_usage_stats(created_at);

-- 維護記錄索引
CREATE INDEX idx_maintenance_records_status ON public.maintenance_records(status);
CREATE INDEX idx_maintenance_records_start_time ON public.maintenance_records(start_time);

-- 用戶偏好索引
CREATE INDEX idx_user_preferences_user_id ON public.user_preferences(user_id);

-- 內容審查索引
CREATE INDEX idx_content_moderation_content_type ON public.content_moderation(content_type);
CREATE INDEX idx_content_moderation_status ON public.content_moderation(status);
CREATE INDEX idx_content_moderation_reported_at ON public.content_moderation(reported_at);

-- ============================================================================
-- RLS 政策
-- ============================================================================

-- 啟用 RLS
ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_announcement_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- 公開可讀的表格
CREATE POLICY "Anyone can view public system settings" ON public.system_settings FOR SELECT
USING (is_public = true);

CREATE POLICY "Anyone can view active app versions" ON public.app_versions FOR SELECT
USING (is_active = true);

CREATE POLICY "Anyone can view active announcements" ON public.system_announcements FOR SELECT
USING (is_active = true AND start_date <= now() AND (end_date IS NULL OR end_date >= now()));

-- 用戶意見反饋政策
CREATE POLICY "Users can manage own feedback" ON public.user_feedback FOR ALL
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 公告閱讀記錄政策
CREATE POLICY "Users can manage own announcement reads" ON public.user_announcement_reads FOR ALL
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- 用戶偏好政策
CREATE POLICY "Users can manage own preferences" ON public.user_preferences FOR ALL
USING (user_id IN (SELECT id FROM public.user_profiles WHERE user_id = auth.uid()::text));

-- ============================================================================
-- 觸發器和函數
-- ============================================================================

-- 自動計算維護持續時間
CREATE OR REPLACE FUNCTION update_maintenance_duration()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.end_time IS NOT NULL AND NEW.start_time IS NOT NULL THEN
    NEW.actual_duration = NEW.end_time - NEW.start_time;
  END IF;
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_maintenance_duration
  BEFORE UPDATE ON public.maintenance_records
  FOR EACH ROW EXECUTE FUNCTION update_maintenance_duration();

-- 自動創建用戶偏好設定
CREATE OR REPLACE FUNCTION create_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_user_preferences
  AFTER INSERT ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION create_user_preferences();

-- ============================================================================
-- 初始系統設定
-- ============================================================================

INSERT INTO public.system_settings (setting_key, setting_value, description, is_public) VALUES
('app_name', '"Invest_V3"', '應用程式名稱', true),
('app_version', '"1.0.0"', '當前應用版本', true),
('maintenance_mode', 'false', '維護模式開關', true),
('registration_enabled', 'true', '是否允許新用戶註冊', false),
('max_file_upload_size', '10485760', '最大檔案上傳大小（位元組）', false),
('supported_languages', '["zh-TW", "zh-CN", "en-US"]', '支援的語言', true),
('trading_hours', '{"start": "09:00", "end": "13:30", "timezone": "Asia/Taipei"}', '交易時間設定', true),
('commission_rates', '{"broker_fee": 0.001425, "transaction_tax": 0.003}', '手續費率設定', false),
('tournament_creation_limit', '1', '每月錦標賽建立限制', false);

-- 插入應用版本資訊
INSERT INTO public.app_versions (version_number, build_number, platform, is_required, release_notes) VALUES
('1.0.0', '1', 'ios', false, '初始版本發布：
• 完整的投資組合管理功能
• 錦標賽競賽系統  
• 好友社交功能
• 文章發布與閱讀
• 即時聊天功能'),
('1.0.1', '2', 'ios', false, '錯誤修復：
• 修復交易記錄篩選問題
• 改善 App 圖標顯示
• 優化錦標賽排行榜性能');

-- 插入系統公告
INSERT INTO public.system_announcements (title, content, announcement_type, priority, target_audience, show_popup) VALUES
('歡迎使用 Invest_V3', '歡迎來到台灣最專業的投資社群平台！在這裡您可以：
• 參與模擬交易錦標賽
• 與其他投資者交流學習  
• 閱讀專業投資分析文章
• 建立自己的投資組合

開始您的投資旅程吧！', 'info', 'normal', 'all', true),
('錦標賽系統上線', '錦標賽功能現已正式上線！您可以：
• 參與各類型投資競賽
• 與全台投資高手同台競技
• 贏取豐厚獎金和榮譽稱號
• 提升您的投資技能

立即參加您的第一場錦標賽！', 'feature', 'high', 'all', false);

-- ============================================================================
-- 完成確認
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ 系統功能表格創建完成！';
    RAISE NOTICE '✅ 包含 10 個系統表格';
    RAISE NOTICE '✅ 包含 20 個索引';
    RAISE NOTICE '✅ 包含 6 個 RLS 政策';
    RAISE NOTICE '✅ 包含 2 個觸發器函數';
    RAISE NOTICE '✅ 包含初始設定數據';
    RAISE NOTICE '🎉 Invest_V3 資料庫架構完整建立成功！';
END $$;