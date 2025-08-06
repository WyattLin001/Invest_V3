/**
 * Shared configuration for Supabase Edge Functions
 * 
 * This file contains common configuration and utility functions
 * used across all notification-related Edge Functions.
 */

// Environment configuration
export const CONFIG = {
  // Supabase
  supabaseUrl: Deno.env.get('SUPABASE_URL')!,
  supabaseServiceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  
  // APNs Configuration
  apns: {
    keyId: Deno.env.get('APNS_KEY_ID') || '',
    teamId: Deno.env.get('APNS_TEAM_ID') || '',
    privateKey: Deno.env.get('APNS_PRIVATE_KEY') || '',
    bundleId: Deno.env.get('APNS_BUNDLE_ID') || 'com.yourcompany.invest-v3',
    environment: (Deno.env.get('APNS_ENVIRONMENT') || 'sandbox') as 'sandbox' | 'production'
  },
  
  // FCM Configuration (for Android)
  fcm: {
    serverKey: Deno.env.get('FCM_SERVER_KEY') || '',
    projectId: Deno.env.get('FCM_PROJECT_ID') || ''
  },
  
  // Rate Limiting
  rateLimits: {
    maxNotificationsPerHour: parseInt(Deno.env.get('MAX_NOTIFICATIONS_PER_HOUR') || '100'),
    maxBulkRecipients: parseInt(Deno.env.get('MAX_BULK_RECIPIENTS') || '10000')
  },
  
  // Payload Limits
  limits: {
    maxPayloadSize: 4096, // 4KB for APNs
    maxTitleLength: 50,
    maxBodyLength: 200,
    maxRetryAttempts: 3
  },
  
  // Timing Configuration
  timing: {
    retryDelays: [1000, 2000, 4000], // ms
    batchProcessingDelay: 100, // ms between batches
    defaultTimeout: 30000 // 30 seconds
  }
}

// APNs Endpoints
export const APNS_ENDPOINTS = {
  sandbox: 'https://api.sandbox.push.apple.com',
  production: 'https://api.push.apple.com'
}

// FCM Endpoint
export const FCM_ENDPOINT = 'https://fcm.googleapis.com/fcm/send'

// Standard HTTP headers
export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
}

// Standard response headers
export const JSON_HEADERS = {
  'Content-Type': 'application/json',
  ...CORS_HEADERS
}

// Utility functions
export class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code?: string
  ) {
    super(message)
    this.name = 'AppError'
  }
}

export function createResponse(
  data: any,
  status: number = 200,
  headers: Record<string, string> = JSON_HEADERS
): Response {
  return new Response(
    JSON.stringify(data),
    { status, headers }
  )
}

export function createErrorResponse(
  error: string | Error,
  status: number = 500,
  code?: string
): Response {
  const message = error instanceof Error ? error.message : error
  return createResponse(
    { 
      error: message,
      code: code || (error instanceof AppError ? error.code : undefined),
      timestamp: new Date().toISOString()
    },
    status
  )
}

// JWT utilities
export function parseJWT(token: string): any {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) throw new Error('Invalid JWT format')
    return JSON.parse(atob(parts[1]))
  } catch {
    throw new AppError('Invalid JWT token', 401)
  }
}

export function getAuthenticatedUser(req: Request): { userId: string; isAdmin: boolean } {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    throw new AppError('Authorization header required', 401)
  }

  const token = authHeader.replace('Bearer ', '')
  const payload = parseJWT(token)
  
  const userId = payload.sub
  if (!userId) {
    throw new AppError('Invalid user ID in token', 401)
  }

  const role = payload.app_metadata?.role || payload.role
  const isAdmin = role === 'admin' || payload.role === 'service_role'

  return { userId, isAdmin }
}

// Validation utilities
export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  return emailRegex.test(email)
}

export function validateTimezone(timezone: string): boolean {
  try {
    Intl.DateTimeFormat(undefined, { timeZone: timezone })
    return true
  } catch {
    return false
  }
}

export function validateTime(time: string): boolean {
  return /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(time)
}

export function validateDeviceToken(token: string, deviceType: string): boolean {
  if (!token || typeof token !== 'string') return false

  switch (deviceType) {
    case 'ios':
      return /^[a-fA-F0-9]{64}$/.test(token)
    case 'android':
      return token.length > 20 && token.length < 200
    case 'web':
      return token.length > 20
    default:
      return false
  }
}

// Date utilities
export function getDateRange(days: number = 30): { startDate: string; endDate: string } {
  const endDate = new Date()
  const startDate = new Date()
  startDate.setDate(startDate.getDate() - days)
  
  return {
    startDate: startDate.toISOString().split('T')[0],
    endDate: endDate.toISOString().split('T')[0]
  }
}

export function isWithinQuietHours(
  quietStart?: string,
  quietEnd?: string,
  timezone: string = 'Asia/Taipei'
): boolean {
  if (!quietStart || !quietEnd) return false

  try {
    const now = new Date()
    const userTime = new Date(now.toLocaleString('en-US', { timeZone: timezone }))
    const currentTime = userTime.getHours() * 60 + userTime.getMinutes()
    
    const [startHour, startMin] = quietStart.split(':').map(Number)
    const [endHour, endMin] = quietEnd.split(':').map(Number)
    const startTime = startHour * 60 + startMin
    const endTime = endHour * 60 + endMin

    if (startTime <= endTime) {
      // Normal case: quiet hours within same day
      return currentTime >= startTime && currentTime <= endTime
    } else {
      // Quiet hours span midnight
      return currentTime >= startTime || currentTime <= endTime
    }
  } catch {
    return false
  }
}

// Logging utilities
export const Logger = {
  info: (message: string, data?: any) => {
    console.log(`[INFO] ${message}`, data ? JSON.stringify(data) : '')
  },
  
  warn: (message: string, data?: any) => {
    console.warn(`[WARN] ${message}`, data ? JSON.stringify(data) : '')
  },
  
  error: (message: string, error?: any) => {
    console.error(`[ERROR] ${message}`, error?.stack || error || '')
  },
  
  debug: (message: string, data?: any) => {
    if (Deno.env.get('LOG_LEVEL') === 'debug') {
      console.log(`[DEBUG] ${message}`, data ? JSON.stringify(data) : '')
    }
  }
}

// Rate limiting utilities
export class RateLimiter {
  private static instance: RateLimiter
  private limits: Map<string, { count: number; resetTime: number }> = new Map()

  static getInstance(): RateLimiter {
    if (!RateLimiter.instance) {
      RateLimiter.instance = new RateLimiter()
    }
    return RateLimiter.instance
  }

  checkLimit(
    key: string, 
    maxRequests: number, 
    windowMs: number = 3600000 // 1 hour
  ): { allowed: boolean; resetTime: number } {
    const now = Date.now()
    const limit = this.limits.get(key)

    if (!limit || now > limit.resetTime) {
      // Reset window
      this.limits.set(key, { count: 1, resetTime: now + windowMs })
      return { allowed: true, resetTime: now + windowMs }
    }

    if (limit.count >= maxRequests) {
      return { allowed: false, resetTime: limit.resetTime }
    }

    limit.count++
    return { allowed: true, resetTime: limit.resetTime }
  }
}

// Notification type definitions
export interface NotificationPayload {
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

export interface NotificationResult {
  success: boolean
  deviceToken: string
  userId: string
  messageId?: string
  error?: string
  httpStatus?: number
  retryAfter?: number
}

// Template validation
export function validateNotificationPayload(payload: NotificationPayload): void {
  if (!payload.notificationType) {
    throw new AppError('notificationType is required', 400)
  }
  
  if (!payload.title) {
    throw new AppError('title is required', 400)
  }
  
  if (!payload.body) {
    throw new AppError('body is required', 400)
  }
  
  if (payload.title.length > CONFIG.limits.maxTitleLength) {
    throw new AppError(`Title too long (max ${CONFIG.limits.maxTitleLength} characters)`, 400)
  }
  
  if (payload.body.length > CONFIG.limits.maxBodyLength) {
    throw new AppError(`Body too long (max ${CONFIG.limits.maxBodyLength} characters)`, 400)
  }
  
  if (payload.priority && (payload.priority < 1 || payload.priority > 10)) {
    throw new AppError('Priority must be between 1 and 10', 400)
  }
}

// Metrics collection
export class MetricsCollector {
  private static metrics: Map<string, number> = new Map()
  
  static increment(metric: string, value: number = 1): void {
    const current = this.metrics.get(metric) || 0
    this.metrics.set(metric, current + value)
  }
  
  static getMetrics(): Record<string, number> {
    return Object.fromEntries(this.metrics)
  }
  
  static reset(): void {
    this.metrics.clear()
  }
}