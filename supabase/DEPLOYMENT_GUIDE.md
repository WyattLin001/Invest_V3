# Push Notification System Deployment Guide

This guide provides step-by-step instructions for deploying the Invest_V3 push notification system to production.

## 🚀 Pre-Deployment Checklist

### 1. Apple Developer Setup
- [ ] Apple Developer Program membership active
- [ ] APNs Key created and downloaded
- [ ] App ID configured with push notification capability
- [ ] Production APNs certificate generated
- [ ] Bundle ID matches your app configuration

### 2. Supabase Project Setup
- [ ] Supabase project created
- [ ] Project URL and keys obtained
- [ ] Service role key secured
- [ ] Database accessible

### 3. Environment Preparation
- [ ] Production environment variables ready
- [ ] APNs private key converted to base64
- [ ] All secrets securely stored
- [ ] CI/CD pipeline configured (if using)

## 📋 Step-by-Step Deployment

### Step 1: Prepare APNs Certificate

1. **Generate APNs Auth Key** (if not already done):
   ```bash
   # In Apple Developer Console:
   # 1. Go to Certificates, Identifiers & Profiles
   # 2. Select Keys
   # 3. Create new key with APNs enabled
   # 4. Download the .p8 file
   ```

2. **Convert Private Key to Base64**:
   ```bash
   # Convert your .p8 key file to base64
   base64 -i AuthKey_XXXXXXXXXX.p8 -o apns_private_key.txt
   ```

3. **Extract Key Information**:
   ```bash
   # Note down:
   # - Key ID (from filename: AuthKey_XXXXXXXXXX.p8)
   # - Team ID (from Apple Developer Console)
   # - Bundle ID (your app's bundle identifier)
   ```

### Step 2: Configure Environment Variables

1. **Create production environment file**:
   ```bash
   cp .env.example .env.production
   ```

2. **Update production variables**:
   ```bash
   # Supabase Configuration
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-production-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-production-service-role-key
   
   # APNs Configuration (Production)
   APNS_KEY_ID=ABCDEFGHIJ
   APNS_TEAM_ID=1234567890
   APNS_PRIVATE_KEY=LS0tLS1CRUdJTi... # base64 encoded key
   APNS_BUNDLE_ID=com.yourcompany.invest-v3
   APNS_ENVIRONMENT=production
   ```

### Step 3: Deploy Database Schema

1. **Connect to your Supabase project**:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

2. **Deploy migrations**:
   ```bash
   supabase db push
   ```

3. **Verify schema deployment**:
   ```bash
   # Check if tables exist
   supabase db dump --data-only --table device_tokens
   ```

### Step 4: Deploy Edge Functions

1. **Deploy all functions**:
   ```bash
   # Deploy main push notification function
   supabase functions deploy send-push-notification --no-verify-jwt
   
   # Deploy device management function
   supabase functions deploy register-device-token --no-verify-jwt
   
   # Deploy bulk notification function
   supabase functions deploy send-bulk-notifications --no-verify-jwt
   
   # Deploy analytics function
   supabase functions deploy notification-analytics --no-verify-jwt
   
   # Deploy user preferences function
   supabase functions deploy manage-user-preferences --no-verify-jwt
   ```

2. **Verify function deployment**:
   ```bash
   supabase functions list
   ```

### Step 5: Configure Secrets

1. **Set production secrets**:
   ```bash
   # APNs Configuration
   supabase secrets set APNS_KEY_ID="ABCDEFGHIJ"
   supabase secrets set APNS_TEAM_ID="1234567890"
   supabase secrets set APNS_PRIVATE_KEY="LS0tLS1CRUdJTi..."
   supabase secrets set APNS_BUNDLE_ID="com.yourcompany.invest-v3"
   supabase secrets set APNS_ENVIRONMENT="production"
   
   # Rate Limiting
   supabase secrets set MAX_NOTIFICATIONS_PER_HOUR="1000"
   supabase secrets set MAX_BULK_RECIPIENTS="10000"
   ```

2. **Verify secrets**:
   ```bash
   supabase secrets list
   ```

### Step 6: Test Deployment

1. **Test device token registration**:
   ```bash
   curl -X POST \
     'https://your-project.supabase.co/functions/v1/register-device-token/register' \
     -H 'Authorization: Bearer YOUR_USER_TOKEN' \
     -H 'Content-Type: application/json' \
     -d '{
       "deviceToken": "test-token-64-characters-hex-string-for-testing-only",
       "deviceType": "ios",
       "environment": "production"
     }'
   ```

2. **Test notification sending**:
   ```bash
   curl -X POST \
     'https://your-project.supabase.co/functions/v1/send-push-notification' \
     -H 'Authorization: Bearer YOUR_USER_TOKEN' \
     -H 'Content-Type: application/json' \
     -d '{
       "deviceTokens": ["your-actual-device-token"],
       "notificationType": "test",
       "title": "Test Notification",
       "body": "Deployment test successful!"
     }'
   ```

3. **Test analytics**:
   ```bash
   curl 'https://your-project.supabase.co/functions/v1/notification-analytics/summary' \
     -H 'Authorization: Bearer YOUR_USER_TOKEN'
   ```

## 🔧 Post-Deployment Configuration

### 1. iOS App Integration

Update your iOS app with production endpoints:

```swift
// Update SupabaseManager.swift or equivalent
struct SupabaseConfig {
    static let url = "https://your-project.supabase.co"
    static let anonKey = "your-production-anon-key"
    
    #if DEBUG
    static let environment = "sandbox"
    #else
    static let environment = "production"
    #endif
}
```

### 2. Admin User Setup

1. **Create admin user**:
   ```sql
   -- In Supabase SQL Editor
   UPDATE auth.users 
   SET raw_app_meta_data = raw_app_meta_data || '{"role": "admin"}'::jsonb
   WHERE email = 'admin@yourcompany.com';
   ```

2. **Verify admin access**:
   ```bash
   # Test bulk notification access
   curl -X GET \
     'https://your-project.supabase.co/functions/v1/send-bulk-notifications/campaigns' \
     -H 'Authorization: Bearer ADMIN_USER_TOKEN'
   ```

### 3. Monitoring Setup

1. **Create monitoring dashboard** (recommended tools):
   - Supabase Dashboard for basic metrics
   - Custom analytics dashboard using the analytics API
   - External monitoring (Datadog, New Relic, etc.)

2. **Set up alerts**:
   ```bash
   # Example: Monitor error rates
   # Set up alerts for:
   # - High failure rates (>5%)
   # - Low delivery rates (<95%)
   # - Function errors
   # - Database connection issues
   ```

## 🏥 Health Checks & Monitoring

### Automated Health Checks

Create a monitoring script:

```bash
#!/bin/bash
# health_check.sh

PROJECT_URL="https://your-project.supabase.co"
ADMIN_TOKEN="your-admin-token"

echo "🏥 Health Check: $(date)"

# Test each function
FUNCTIONS=("send-push-notification" "register-device-token" "notification-analytics")

for func in "${FUNCTIONS[@]}"; do
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        "${PROJECT_URL}/functions/v1/${func}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    if [ "$response" -eq 200 ] || [ "$response" -eq 404 ]; then
        echo "✅ $func: OK"
    else
        echo "❌ $func: HTTP $response"
    fi
done

# Check database connectivity
db_response=$(curl -s -o /dev/null -w "%{http_code}" \
    "${PROJECT_URL}/rest/v1/device_tokens?select=count" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if [ "$db_response" -eq 200 ]; then
    echo "✅ Database: OK"
else
    echo "❌ Database: HTTP $db_response"
fi

echo "Health check completed."
```

### Performance Monitoring

Monitor key metrics:

```sql
-- Daily notification summary
SELECT 
    DATE(sent_at) as date,
    COUNT(*) as total_sent,
    COUNT(*) FILTER (WHERE delivery_status = 'delivered') as delivered,
    COUNT(*) FILTER (WHERE delivery_status = 'failed') as failed,
    ROUND(AVG(processing_time_ms), 2) as avg_processing_time
FROM notification_logs 
WHERE sent_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(sent_at)
ORDER BY date DESC;

-- Error analysis
SELECT 
    error_code,
    COUNT(*) as count,
    MAX(sent_at) as last_seen
FROM notification_logs 
WHERE delivery_status = 'failed' 
    AND sent_at > NOW() - INTERVAL '24 hours'
GROUP BY error_code
ORDER BY count DESC;

-- Device token health
SELECT 
    device_type,
    environment,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE is_active = true) as active
FROM device_tokens
GROUP BY device_type, environment;
```

## 🔄 Rollback Procedures

### Function Rollback

If you need to rollback a function:

```bash
# Redeploy previous version
git checkout PREVIOUS_COMMIT
supabase functions deploy FUNCTION_NAME --no-verify-jwt

# Or deploy a specific version
supabase functions deploy FUNCTION_NAME --no-verify-jwt --import-map ./previous_import_map.json
```

### Database Rollback

For schema changes:

```bash
# Create rollback migration
supabase migration new rollback_push_notifications

# Write rollback SQL in the new migration file
# Then apply
supabase db push
```

### Emergency Procedures

1. **Disable all notifications**:
   ```sql
   -- Temporarily disable all notification processing
   UPDATE notification_templates SET is_active = false;
   ```

2. **Stop campaigns**:
   ```sql
   -- Cancel all running campaigns
   UPDATE bulk_notification_campaigns 
   SET status = 'cancelled' 
   WHERE status IN ('scheduled', 'processing');
   ```

3. **Clear queue**:
   ```sql
   -- Clear pending notifications
   DELETE FROM notification_queue WHERE status = 'pending';
   ```

## 📊 Performance Optimization

### Database Optimization

1. **Regular maintenance**:
   ```sql
   -- Run weekly
   SELECT cleanup_old_notification_logs(30);
   
   -- Run monthly
   SELECT cleanup_old_notification_logs(7); -- Keep only 7 days for detailed logs
   ```

2. **Index monitoring**:
   ```sql
   -- Check index usage
   SELECT 
       schemaname,
       tablename,
       indexname,
       idx_tup_read,
       idx_tup_fetch
   FROM pg_stat_user_indexes
   WHERE schemaname = 'public'
   ORDER BY idx_tup_read DESC;
   ```

### Function Optimization

1. **Monitor function performance**:
   ```bash
   supabase functions logs send-push-notification --limit 100
   ```

2. **Optimize batch sizes**:
   ```typescript
   // Adjust in bulk notification function
   const BATCH_SIZE = 50; // Reduce if timeout issues
   const PROCESSING_DELAY_MS = 200; // Increase if rate limiting
   ```

## 🚨 Troubleshooting Common Issues

### Issue: High Failure Rate

**Symptoms**: Many notifications showing as failed
**Causes**: Invalid device tokens, certificate issues
**Solutions**:
1. Check APNs certificate validity
2. Verify device token format
3. Monitor error codes in logs

### Issue: Slow Processing

**Symptoms**: Long processing times, timeouts
**Causes**: Large batch sizes, network issues
**Solutions**:
1. Reduce batch sizes
2. Increase processing delays
3. Optimize database queries

### Issue: Database Locks

**Symptoms**: Function timeouts, connection errors
**Causes**: Long-running queries, concurrent operations
**Solutions**:
1. Optimize queries
2. Add connection pooling
3. Implement queue processing delays

## 📚 Maintenance Schedule

### Daily
- [ ] Monitor error rates
- [ ] Check function logs
- [ ] Verify notification delivery rates

### Weekly  
- [ ] Clean up old notification logs
- [ ] Review performance metrics
- [ ] Update analytics

### Monthly
- [ ] Clean up inactive device tokens
- [ ] Review and optimize database indexes
- [ ] Update documentation
- [ ] Security audit

### Quarterly
- [ ] Review APNs certificate expiration
- [ ] Performance optimization review
- [ ] Capacity planning
- [ ] Disaster recovery testing

---

**Deployment completed! 🎉**

Your push notification system is now ready for production use. Monitor the system closely for the first few days to ensure everything is working correctly.