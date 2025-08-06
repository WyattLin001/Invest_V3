# Invest_V3 Push Notification System

A comprehensive push notification system built with Supabase Edge Functions, supporting iOS APNs with advanced features including analytics, user preferences, bulk messaging, and robust error handling.

## 🚀 Features

- **APNs Integration**: Full iOS push notification support with sandbox and production environments
- **Device Management**: Automatic device token registration and lifecycle management
- **User Preferences**: Granular notification preferences with quiet hours and frequency settings
- **Bulk Notifications**: Campaign-based mass messaging with targeting options
- **Analytics & Reporting**: Comprehensive delivery and engagement metrics
- **Rate Limiting**: Built-in spam prevention and quota management
- **Error Handling**: Automatic retries and failover mechanisms
- **Security**: Row Level Security (RLS) policies and JWT authentication

## 📁 Project Structure

```
supabase/
├── config.toml                          # Supabase project configuration
├── import_map.json                      # Deno import mappings
├── .env.example                         # Environment variables template
├── deployment.yml                       # CI/CD pipeline configuration
│
├── migrations/                          # Database migrations
│   ├── 20250806000001_push_notifications_schema.sql
│   └── 20250806000002_push_notifications_rls.sql
│
├── functions/                           # Edge Functions
│   ├── _shared/                         # Shared utilities
│   │   ├── config.ts                    # Common configuration
│   │   └── supabase.ts                  # Database utilities
│   │
│   ├── send-push-notification/          # Main push notification function
│   │   └── index.ts
│   │
│   ├── register-device-token/           # Device token management
│   │   └── index.ts
│   │
│   ├── send-bulk-notifications/         # Bulk messaging campaigns
│   │   └── index.ts
│   │
│   ├── notification-analytics/          # Analytics and reporting
│   │   └── index.ts
│   │
│   └── manage-user-preferences/         # User preferences management
│       └── index.ts
│
└── README.md                           # This documentation
```

## 🛠️ Setup & Installation

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- [Deno](https://deno.land/) runtime (v1.37+)
- Apple Developer Account with APNs certificates
- Valid iOS app with push notification capability

### 1. Environment Configuration

Copy the environment template and configure your settings:

```bash
cp .env.example .env
```

Configure the following variables:

```bash
# Supabase Configuration
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# APNs Configuration
APNS_KEY_ID=your-apns-key-id
APNS_TEAM_ID=your-apple-team-id
APNS_PRIVATE_KEY=base64-encoded-private-key
APNS_BUNDLE_ID=com.yourcompany.invest-v3
APNS_ENVIRONMENT=sandbox  # or 'production'
```

### 2. Database Setup

Initialize Supabase and run migrations:

```bash
# Initialize Supabase project
supabase init

# Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF

# Run database migrations
supabase db push
```

### 3. Deploy Edge Functions

Deploy all notification functions:

```bash
# Deploy all functions
supabase functions deploy send-push-notification
supabase functions deploy register-device-token
supabase functions deploy send-bulk-notifications
supabase functions deploy notification-analytics
supabase functions deploy manage-user-preferences
```

### 4. Set Environment Secrets

Configure production secrets:

```bash
# APNs Configuration
supabase secrets set APNS_KEY_ID="YOUR_APNS_KEY_ID"
supabase secrets set APNS_TEAM_ID="YOUR_APPLE_TEAM_ID"
supabase secrets set APNS_PRIVATE_KEY="YOUR_BASE64_ENCODED_PRIVATE_KEY"
supabase secrets set APNS_BUNDLE_ID="com.yourcompany.invest-v3"
supabase secrets set APNS_ENVIRONMENT="production"
```

## 📱 iOS Integration

### Device Token Registration

In your iOS app, register device tokens with the system:

```swift
// In AppDelegate or SceneDelegate
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    
    Task {
        await registerDeviceToken(tokenString)
    }
}

private func registerDeviceToken(_ token: String) async {
    let url = URL(string: "\(supabaseURL)/functions/v1/register-device-token/register")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(userAccessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload = [
        "deviceToken": token,
        "deviceType": "ios",
        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        "osVersion": UIDevice.current.systemVersion,
        "deviceModel": UIDevice.current.model
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            print("✅ Device token registered successfully")
        }
    } catch {
        print("❌ Failed to register device token: \(error)")
    }
}
```

### Update Existing NotificationService

Update your existing `NotificationService.swift` to integrate with the new backend:

```swift
// Add this method to your existing NotificationService class
private func saveDeviceTokenToBackend(_ token: String) async {
    let url = URL(string: "\(supabaseURL)/functions/v1/register-device-token/register")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload: [String: Any] = [
        "deviceToken": token,
        "deviceType": "ios",
        "environment": PushNotificationConfig.environment.rawValue
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            print("✅ Device token registered with backend")
        }
    } catch {
        print("❌ Failed to register with backend: \(error)")
    }
}
```

## 🔧 API Reference

### Send Push Notification

Send individual or targeted push notifications.

**Endpoint**: `POST /functions/v1/send-push-notification`

```bash
curl -X POST \
  'https://your-project.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "user-uuid",
    "notificationType": "host_message",
    "title": "New Message",
    "body": "You have a new message from the host",
    "data": {
      "groupId": "group-123",
      "hostName": "John Doe"
    }
  }'
```

### Register Device Token

Register or update device tokens for push notifications.

**Endpoint**: `POST /functions/v1/register-device-token/register`

```bash
curl -X POST \
  'https://your-project.supabase.co/functions/v1/register-device-token/register' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "deviceToken": "64-character-hex-string",
    "deviceType": "ios",
    "appVersion": "1.0.0",
    "osVersion": "17.0",
    "deviceModel": "iPhone15,2"
  }'
```

### Send Bulk Notifications

Create and send bulk notification campaigns.

**Endpoint**: `POST /functions/v1/send-bulk-notifications/send`

```bash
curl -X POST \
  'https://your-project.supabase.co/functions/v1/send-bulk-notifications/send' \
  -H 'Authorization: Bearer YOUR_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "campaignName": "Weekly Tournament Reminder",
    "title": "Tournament Starting Soon!",
    "body": "The weekly investment tournament starts in 1 hour",
    "notificationType": "tournament_reminder",
    "targetCriteria": {
      "deviceTypes": ["ios"],
      "lastActiveAfter": "2025-08-01T00:00:00Z",
      "maxRecipients": 1000
    }
  }'
```

### Manage User Preferences

Update user notification preferences.

**Endpoint**: `PUT /functions/v1/manage-user-preferences/preferences`

```bash
curl -X PUT \
  'https://your-project.supabase.co/functions/v1/manage-user-preferences/preferences' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "notificationType": "stock_alert",
    "isEnabled": true,
    "deliveryMethod": ["push", "email"],
    "frequency": "immediate",
    "quietHoursStart": "22:00",
    "quietHoursEnd": "08:00",
    "timezone": "Asia/Taipei"
  }'
```

### Analytics

Get notification analytics and performance metrics.

**Endpoint**: `GET /functions/v1/notification-analytics/summary`

```bash
curl 'https://your-project.supabase.co/functions/v1/notification-analytics/summary?startDate=2025-08-01&endDate=2025-08-06' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'
```

## 📊 Database Schema

### Core Tables

- **`device_tokens`**: Store user device tokens with metadata
- **`notification_templates`**: Reusable notification templates
- **`user_notification_preferences`**: User-specific notification settings
- **`notification_queue`**: Queued notifications for processing
- **`notification_logs`**: Complete audit log of all notifications
- **`notification_analytics`**: Daily aggregated metrics
- **`bulk_notification_campaigns`**: Bulk messaging campaigns
- **`notification_rate_limits`**: Rate limiting tracking

### Key Relationships

```sql
-- Users can have multiple device tokens
device_tokens.user_id → auth.users.id

-- Users have preferences for each notification type
user_notification_preferences.user_id → auth.users.id

-- Notifications are logged with full context
notification_logs.user_id → auth.users.id
notification_logs.queue_id → notification_queue.id

-- Campaigns track bulk operations
bulk_notification_campaigns.created_by → auth.users.id
```

## 🔒 Security & Permissions

### Row Level Security (RLS)

All tables have RLS enabled with appropriate policies:

- **Users** can only access their own device tokens and preferences
- **Admins** can view system-wide analytics and manage campaigns
- **Service role** has full access for Edge Functions
- **Edge Functions** can manage queues and logs

### Authentication

All endpoints require JWT authentication:

```typescript
// User-level access
Authorization: Bearer <user_access_token>

// Admin-level access (for bulk operations)
Authorization: Bearer <admin_access_token>

// Service-level access (for internal operations)
Authorization: Bearer <service_role_key>
```

## 📈 Monitoring & Analytics

### Available Metrics

- **Delivery Rate**: Percentage of successfully delivered notifications
- **Open Rate**: Percentage of delivered notifications that were opened
- **Failure Rate**: Percentage of failed deliveries
- **Processing Time**: Average time to process notifications
- **Device Analytics**: Performance by device type and environment
- **Error Analytics**: Common failure reasons and trends

### Accessing Analytics

```bash
# Get summary metrics
GET /functions/v1/notification-analytics/summary

# Get time series data
GET /functions/v1/notification-analytics/timeseries?groupBy=day

# Get error analytics
GET /functions/v1/notification-analytics/errors

# Get performance metrics
GET /functions/v1/notification-analytics/performance
```

## 🧪 Testing

### Local Testing

Start Supabase locally:

```bash
supabase start
```

Test functions locally:

```bash
# Test notification sending
curl -X POST \
  'http://localhost:54321/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer YOUR_LOCAL_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "deviceTokens": ["test-token-64-chars"],
    "notificationType": "test",
    "title": "Test Notification",
    "body": "This is a test notification"
  }'
```

### Function Testing

Each function includes built-in testing endpoints:

```bash
# Test device token validation
GET /functions/v1/register-device-token/tokens/{token-id}/test

# Test notification preferences
GET /functions/v1/manage-user-preferences/types

# Test analytics queries
GET /functions/v1/notification-analytics/summary
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Invalid Device Token
```
Error: Invalid device token format for ios
```
**Solution**: Ensure device tokens are 64-character hexadecimal strings for iOS.

#### 2. APNs Authentication Failed
```
Error: HTTP 403 - InvalidProviderToken
```
**Solution**: Check APNs key ID, team ID, and private key configuration.

#### 3. Notification Not Delivered
```
Error: HTTP 400 - BadDeviceToken
```
**Solution**: Device token is invalid or app was uninstalled. Token will be automatically deactivated.

#### 4. Rate Limiting
```
Error: User has exceeded notification rate limit
```
**Solution**: Check rate limiting settings and user notification frequency.

### Debug Mode

Enable debug logging:

```bash
supabase secrets set LOG_LEVEL="debug"
```

### Health Checks

Monitor function health:

```bash
# Check function status
supabase functions list

# View function logs
supabase functions logs send-push-notification
```

## 🔄 Maintenance

### Regular Tasks

#### 1. Cleanup Old Logs (Weekly)
```sql
SELECT cleanup_old_notification_logs(30); -- Keep 30 days
```

#### 2. Update Analytics (Daily)
```sql
SELECT update_notification_analytics();
```

#### 3. Cleanup Inactive Tokens (Monthly)
```bash
curl -X POST \
  'https://your-project.supabase.co/functions/v1/register-device-token/cleanup?days=90' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'
```

### Monitoring Queries

```sql
-- Check recent notification performance
SELECT 
  DATE(sent_at) as date,
  COUNT(*) as total_sent,
  COUNT(*) FILTER (WHERE delivery_status = 'delivered') as delivered,
  COUNT(*) FILTER (WHERE delivery_status = 'failed') as failed
FROM notification_logs 
WHERE sent_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(sent_at)
ORDER BY date DESC;

-- Find most common errors
SELECT 
  error_code,
  COUNT(*) as error_count,
  MAX(sent_at) as last_occurrence
FROM notification_logs 
WHERE delivery_status = 'failed' 
  AND sent_at > NOW() - INTERVAL '24 hours'
GROUP BY error_code
ORDER BY error_count DESC;

-- Check active device tokens by platform
SELECT 
  device_type,
  environment,
  COUNT(*) as active_tokens
FROM device_tokens 
WHERE is_active = true
GROUP BY device_type, environment;
```

## 📚 Additional Resources

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Apple Push Notification Service Documentation](https://developer.apple.com/documentation/usernotifications)
- [APNs Provider API Documentation](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [Deno Runtime Documentation](https://deno.land/manual)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ for the Invest_V3 platform**