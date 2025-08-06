/**
 * Send Push Notification Edge Function
 * 
 * Handles sending push notifications via APNs with comprehensive error handling,
 * retry logic, and logging capabilities.
 * 
 * Environment Variables Required:
 * - APNS_KEY_ID: APNs Auth Key ID
 * - APNS_TEAM_ID: Apple Developer Team ID
 * - APNS_PRIVATE_KEY: APNs Private Key (base64 encoded)
 * - APNS_BUNDLE_ID: App Bundle Identifier
 * - APNS_ENVIRONMENT: 'sandbox' or 'production'
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'supabase'
import { SignJWT } from 'jose'

// Types and Interfaces
interface NotificationPayload {
  userId?: string
  userIds?: string[]
  deviceTokens?: string[]
  notificationType: string
  templateKey?: string
  title: string
  body: string
  data?: Record<string, any>
  priority?: number
  sound?: string
  badge?: number
  category?: string
  expiration?: number
  collapseId?: string
}

interface APNsPayload {
  aps: {
    alert?: {
      title: string
      body: string
    }
    sound?: string
    badge?: number
    category?: string
    'content-available'?: number
    'mutable-content'?: number
  }
  [key: string]: any
}

interface DeviceToken {
  id: string
  device_token: string
  device_type: string
  environment: string
  user_id: string
}

interface NotificationResult {
  success: boolean
  deviceToken: string
  userId: string
  messageId?: string
  error?: string
  httpStatus?: number
  retryAfter?: number
}

// Configuration
const APNS_CONFIG = {
  keyId: Deno.env.get('APNS_KEY_ID') || '',
  teamId: Deno.env.get('APNS_TEAM_ID') || '',
  privateKey: Deno.env.get('APNS_PRIVATE_KEY') || '',
  bundleId: Deno.env.get('APNS_BUNDLE_ID') || 'com.yourcompany.invest-v3',
  environment: (Deno.env.get('APNS_ENVIRONMENT') || 'sandbox') as 'sandbox' | 'production'
}

const APNS_ENDPOINTS = {
  sandbox: 'https://api.sandbox.push.apple.com',
  production: 'https://api.push.apple.com'
}

const MAX_RETRY_ATTEMPTS = 3
const MAX_PAYLOAD_SIZE = 4096
const RETRY_DELAYS = [1000, 2000, 4000] // ms

// Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

// JWT Token generation for APNs
async function generateAPNsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  // Decode base64 private key
  const privateKeyData = atob(APNS_CONFIG.privateKey)
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    new TextEncoder().encode(privateKeyData),
    {
      name: 'ECDSA',
      namedCurve: 'P-256'
    },
    false,
    ['sign']
  )

  const jwt = await new SignJWT({})
    .setProtectedHeader({
      alg: 'ES256',
      kid: APNS_CONFIG.keyId
    })
    .setIssuer(APNS_CONFIG.teamId)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600) // 1 hour
    .sign(privateKey)

  return jwt
}

// Build APNs payload
function buildAPNsPayload(payload: NotificationPayload): APNsPayload {
  const apsPayload: APNsPayload = {
    aps: {
      alert: {
        title: payload.title,
        body: payload.body
      }
    }
  }

  if (payload.sound) apsPayload.aps.sound = payload.sound
  if (payload.badge !== undefined) apsPayload.aps.badge = payload.badge
  if (payload.category) apsPayload.aps.category = payload.category

  // Add custom data
  if (payload.data) {
    Object.keys(payload.data).forEach(key => {
      apsPayload[key] = payload.data![key]
    })
  }

  // Add notification metadata
  apsPayload.notification_type = payload.notificationType
  if (payload.templateKey) apsPayload.template_key = payload.templateKey

  return apsPayload
}

// Validate payload size
function validatePayloadSize(payload: APNsPayload): boolean {
  try {
    const payloadString = JSON.stringify(payload)
    const payloadSize = new TextEncoder().encode(payloadString).length
    return payloadSize <= MAX_PAYLOAD_SIZE
  } catch {
    return false
  }
}

// Send notification to APNs
async function sendToAPNs(
  deviceToken: string,
  payload: APNsPayload,
  options: {
    priority?: number
    expiration?: number
    collapseId?: string
  } = {}
): Promise<{ success: bool; error?: string; httpStatus?: number; messageId?: string; retryAfter?: number }> {
  try {
    const jwt = await generateAPNsJWT()
    const endpoint = APNS_ENDPOINTS[APNS_CONFIG.environment]
    const url = `${endpoint}/3/device/${deviceToken}`

    const headers: Record<string, string> = {
      'authorization': `bearer ${jwt}`,
      'apns-topic': APNS_CONFIG.bundleId,
      'apns-push-type': 'alert',
      'content-type': 'application/json'
    }

    if (options.priority) headers['apns-priority'] = options.priority.toString()
    if (options.expiration) headers['apns-expiration'] = options.expiration.toString()
    if (options.collapseId) headers['apns-collapse-id'] = options.collapseId

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload)
    })

    const responseText = await response.text()
    const httpStatus = response.status

    if (response.ok) {
      return {
        success: true,
        httpStatus,
        messageId: response.headers.get('apns-id') || undefined
      }
    } else {
      let retryAfter: number | undefined
      const retryAfterHeader = response.headers.get('retry-after')
      if (retryAfterHeader) {
        retryAfter = parseInt(retryAfterHeader) * 1000 // Convert to ms
      }

      let errorMessage = `HTTP ${httpStatus}`
      try {
        const errorData = JSON.parse(responseText)
        errorMessage = errorData.reason || errorMessage
      } catch {
        errorMessage = responseText || errorMessage
      }

      return {
        success: false,
        httpStatus,
        error: errorMessage,
        retryAfter
      }
    }
  } catch (error) {
    return {
      success: false,
      error: `Network error: ${error.message}`
    }
  }
}

// Get device tokens for users
async function getDeviceTokens(userIds: string[]): Promise<DeviceToken[]> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('id, device_token, device_type, environment, user_id')
    .in('user_id', userIds)
    .eq('is_active', true)
    .eq('environment', APNS_CONFIG.environment)
    .gte('last_used_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()) // Last 30 days

  if (error) {
    throw new Error(`Failed to get device tokens: ${error.message}`)
  }

  return data || []
}

// Check user notification preferences
async function checkUserNotificationPreferences(userId: string, notificationType: string): Promise<boolean> {
  const { data } = await supabase
    .rpc('can_user_receive_notification', {
      target_user_id: userId,
      notification_type_param: notificationType
    })

  return data === true
}

// Log notification attempt
async function logNotification(
  queueId: string | null,
  userId: string,
  deviceToken: string,
  payload: NotificationPayload,
  result: NotificationResult,
  processingTimeMs: number,
  retryAttempt: number = 0
): Promise<void> {
  const logEntry = {
    queue_id: queueId,
    user_id: userId,
    device_token: deviceToken,
    notification_type: payload.notificationType,
    title: payload.title,
    body: payload.body,
    payload: {
      template_key: payload.templateKey,
      data: payload.data,
      priority: payload.priority
    },
    apns_response: result.messageId ? { message_id: result.messageId } : null,
    http_status_code: result.httpStatus,
    delivery_status: result.success ? 'sent' : 'failed',
    error_code: result.error ? result.error.split(':')[0] : null,
    error_message: result.error,
    retry_attempt: retryAttempt,
    processing_time_ms: processingTimeMs
  }

  const { error } = await supabase
    .from('notification_logs')
    .insert(logEntry)

  if (error) {
    console.error('Failed to log notification:', error)
  }
}

// Update device token status if invalid
async function handleInvalidDeviceToken(deviceTokenId: string): Promise<void> {
  const { error } = await supabase
    .from('device_tokens')
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq('id', deviceTokenId)

  if (error) {
    console.error('Failed to deactivate device token:', error)
  }
}

// Process single notification with retries
async function processNotificationWithRetry(
  deviceToken: DeviceToken,
  payload: NotificationPayload,
  queueId: string | null = null
): Promise<NotificationResult> {
  const apnsPayload = buildAPNsPayload(payload)
  
  if (!validatePayloadSize(apnsPayload)) {
    return {
      success: false,
      deviceToken: deviceToken.device_token,
      userId: deviceToken.user_id,
      error: 'Payload too large'
    }
  }

  let lastError = 'Unknown error'
  let lastHttpStatus = 0

  for (let attempt = 0; attempt < MAX_RETRY_ATTEMPTS; attempt++) {
    const startTime = Date.now()
    
    const result = await sendToAPNs(deviceToken.device_token, apnsPayload, {
      priority: payload.priority || 10,
      expiration: payload.expiration,
      collapseId: payload.collapseId
    })

    const processingTime = Date.now() - startTime

    // Log the attempt
    await logNotification(
      queueId,
      deviceToken.user_id,
      deviceToken.device_token,
      payload,
      {
        success: result.success,
        deviceToken: deviceToken.device_token,
        userId: deviceToken.user_id,
        messageId: result.messageId,
        error: result.error,
        httpStatus: result.httpStatus
      },
      processingTime,
      attempt
    )

    if (result.success) {
      return {
        success: true,
        deviceToken: deviceToken.device_token,
        userId: deviceToken.user_id,
        messageId: result.messageId,
        httpStatus: result.httpStatus
      }
    }

    lastError = result.error || 'Unknown error'
    lastHttpStatus = result.httpStatus || 0

    // Handle specific error cases
    if (result.httpStatus === 400 || result.httpStatus === 410) {
      // Invalid device token - don't retry
      await handleInvalidDeviceToken(deviceToken.id)
      break
    }

    if (result.httpStatus === 413) {
      // Payload too large - don't retry
      break
    }

    // Wait before retry if not the last attempt
    if (attempt < MAX_RETRY_ATTEMPTS - 1) {
      const delay = result.retryAfter || RETRY_DELAYS[attempt] || 1000
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }

  return {
    success: false,
    deviceToken: deviceToken.device_token,
    userId: deviceToken.user_id,
    error: lastError,
    httpStatus: lastHttpStatus
  }
}

// Main notification processing function
async function processNotification(payload: NotificationPayload): Promise<{
  success: boolean
  results: NotificationResult[]
  totalSent: number
  totalFailed: number
}> {
  const results: NotificationResult[] = []
  
  try {
    // Determine target users
    let targetUserIds: string[] = []
    
    if (payload.userId) {
      targetUserIds = [payload.userId]
    } else if (payload.userIds) {
      targetUserIds = payload.userIds
    } else if (payload.deviceTokens) {
      // Direct device token mode - create fake device token objects
      const deviceTokens = payload.deviceTokens.map(token => ({
        id: '',
        device_token: token,
        device_type: 'ios',
        environment: APNS_CONFIG.environment,
        user_id: 'unknown'
      }))
      
      for (const deviceToken of deviceTokens) {
        const result = await processNotificationWithRetry(deviceToken, payload)
        results.push(result)
      }
    } else {
      throw new Error('No target users or device tokens specified')
    }

    // Process user-based notifications
    if (targetUserIds.length > 0) {
      // Check user preferences
      const validUserIds: string[] = []
      for (const userId of targetUserIds) {
        const canReceive = await checkUserNotificationPreferences(userId, payload.notificationType)
        if (canReceive) {
          validUserIds.push(userId)
        } else {
          results.push({
            success: false,
            deviceToken: 'N/A',
            userId,
            error: 'User has disabled this notification type'
          })
        }
      }

      if (validUserIds.length > 0) {
        // Get device tokens
        const deviceTokens = await getDeviceTokens(validUserIds)
        
        if (deviceTokens.length === 0) {
          validUserIds.forEach(userId => {
            results.push({
              success: false,
              deviceToken: 'N/A',
              userId,
              error: 'No active device tokens found'
            })
          })
        } else {
          // Send notifications
          for (const deviceToken of deviceTokens) {
            const result = await processNotificationWithRetry(deviceToken, payload)
            results.push(result)
          }
        }
      }
    }

    const totalSent = results.filter(r => r.success).length
    const totalFailed = results.filter(r => !r.success).length

    return {
      success: totalSent > 0,
      results,
      totalSent,
      totalFailed
    }
  } catch (error) {
    console.error('Error processing notification:', error)
    return {
      success: false,
      results: [{
        success: false,
        deviceToken: 'N/A',
        userId: payload.userId || 'unknown',
        error: error.message
      }],
      totalSent: 0,
      totalFailed: 1
    }
  }
}

// Main handler
serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }), 
      { status: 405, headers: { 'Content-Type': 'application/json' } }
    )
  }

  try {
    // Validate configuration
    if (!APNS_CONFIG.keyId || !APNS_CONFIG.teamId || !APNS_CONFIG.privateKey) {
      throw new Error('Missing APNs configuration')
    }

    const payload: NotificationPayload = await req.json()

    // Validate required fields
    if (!payload.notificationType || !payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: notificationType, title, body' 
        }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Process the notification
    const result = await processNotification(payload)

    return new Response(
      JSON.stringify({
        success: result.success,
        message: `Sent ${result.totalSent} notifications, ${result.totalFailed} failed`,
        totalSent: result.totalSent,
        totalFailed: result.totalFailed,
        results: result.results
      }),
      { 
        status: result.success ? 200 : 207, // 207 Multi-Status for partial success
        headers: { 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('Push notification error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})