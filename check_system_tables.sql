-- 檢查系統功能表格
SELECT 'System Tables' as category, table_name,
       CASE WHEN table_name IS NOT NULL THEN '✅ 存在' ELSE '❌ 不存在' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'system_settings',
    'app_versions',
    'user_feedback',
    'system_announcements',
    'user_announcement_reads',
    'system_logs',
    'api_usage_stats',
    'maintenance_records',
    'user_preferences',
    'content_moderation'
)
ORDER BY table_name;