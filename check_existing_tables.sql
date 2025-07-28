-- ============================================================================
-- 檢查現有表格狀態 - Invest_V3
-- ============================================================================

-- 檢查錦標賽相關表格
SELECT 'Tournament Tables' as category, table_name, 
       CASE WHEN table_name IS NOT NULL THEN '✅ 存在' ELSE '❌ 不存在' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'tournaments',
    'tournament_participants', 
    'tournament_trading_records',
    'tournament_positions',
    'tournament_activities',
    'tournament_ranking_snapshots',
    'tournament_achievements',
    'user_tournament_achievements',
    'tournament_titles',
    'user_tournament_titles'
)
UNION ALL

-- 檢查好友系統表格
SELECT 'Friend Tables' as category, table_name,
       CASE WHEN table_name IS NOT NULL THEN '✅ 存在' ELSE '❌ 不存在' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'friend_requests',
    'friend_activities',
    'friend_search_cache',
    'friend_recommendations', 
    'blocked_users',
    'friendships'
)
UNION ALL

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
ORDER BY category, table_name;