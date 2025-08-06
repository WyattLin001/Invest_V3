/**
 * Notification Analytics Edge Function
 * 
 * Provides comprehensive analytics and reporting for push notification system
 * including delivery rates, open rates, performance metrics, and insights.
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'supabase'

// Types and Interfaces
interface AnalyticsQuery {
  startDate?: string
  endDate?: string
  notificationType?: string
  templateKey?: string
  userId?: string
  groupBy?: 'day' | 'week' | 'month' | 'type' | 'template'
  limit?: number
}

interface AnalyticsSummary {
  totalSent: number
  totalDelivered: number
  totalOpened: number
  totalFailed: number
  deliveryRate: number
  openRate: number
  failureRate: number
  avgProcessingTime: number
}

interface AnalyticsData extends AnalyticsSummary {
  period: string
  notificationType?: string
  templateKey?: string
}

interface DeviceAnalytics {
  deviceType: string
  environment: string
  totalSent: number
  deliveryRate: number
  avgProcessingTime: number
}

interface NotificationTypeAnalytics {
  notificationType: string
  templateKey?: string
  totalSent: number
  deliveryRate: number
  openRate: number
  failureRate: number
  avgProcessingTime: number
  trendData?: AnalyticsData[]
}

interface ErrorAnalytics {
  errorCode: string
  errorMessage: string
  count: number
  percentage: number
  lastOccurred: string
}

interface PerformanceMetrics {
  averageProcessingTime: number
  p95ProcessingTime: number
  p99ProcessingTime: number
  slowestNotifications: {
    id: string
    notificationType: string
    processingTime: number
    sentAt: string
  }[]
}

// Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Get authenticated user and check admin role
function getAuthenticatedUser(req: Request): { userId: string | null; isAdmin: boolean } {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return { userId: null, isAdmin: false }

  try {
    const token = authHeader.replace('Bearer ', '')
    const parts = token.split('.')
    if (parts.length !== 3) return { userId: null, isAdmin: false }
    
    const payload = JSON.parse(atob(parts[1]))
    const userId = payload.sub || null
    const role = payload.app_metadata?.role || payload.role
    const isAdmin = role === 'admin' || payload.role === 'service_role'
    
    return { userId, isAdmin }
  } catch {
    return { userId: null, isAdmin: false }
  }
}

// Get default date range (last 30 days)
function getDefaultDateRange(): { startDate: string; endDate: string } {
  const endDate = new Date()
  const startDate = new Date()
  startDate.setDate(startDate.getDate() - 30)
  
  return {
    startDate: startDate.toISOString().split('T')[0],
    endDate: endDate.toISOString().split('T')[0]
  }
}

// Get analytics summary
async function getAnalyticsSummary(
  query: AnalyticsQuery,
  userId?: string
): Promise<AnalyticsSummary> {
  const { startDate = getDefaultDateRange().startDate, endDate = getDefaultDateRange().endDate } = query
  
  let sqlQuery = `
    SELECT 
      COUNT(*) as total_sent,
      COUNT(*) FILTER (WHERE delivery_status = 'delivered') as total_delivered,
      COUNT(*) FILTER (WHERE opened_at IS NOT NULL) as total_opened,
      COUNT(*) FILTER (WHERE delivery_status = 'failed') as total_failed,
      AVG(processing_time_ms) as avg_processing_time
    FROM notification_logs 
    WHERE DATE(sent_at) BETWEEN $1 AND $2
  `
  
  const params: any[] = [startDate, endDate]
  let paramIndex = 3

  if (query.notificationType) {
    sqlQuery += ` AND notification_type = $${paramIndex}`
    params.push(query.notificationType)
    paramIndex++
  }

  if (query.templateKey) {
    sqlQuery += ` AND payload->>'template_key' = $${paramIndex}`
    params.push(query.templateKey)
    paramIndex++
  }

  if (userId && !query.userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(userId)
    paramIndex++
  } else if (query.userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(query.userId)
    paramIndex++
  }

  const { data, error } = await supabase.rpc('execute_sql', {
    query: sqlQuery,
    params
  })

  if (error) {
    throw new Error(`Failed to get analytics summary: ${error.message}`)
  }

  const result = data[0] || {}
  const totalSent = parseInt(result.total_sent) || 0
  const totalDelivered = parseInt(result.total_delivered) || 0
  const totalOpened = parseInt(result.total_opened) || 0
  const totalFailed = parseInt(result.total_failed) || 0

  return {
    totalSent,
    totalDelivered,
    totalOpened,
    totalFailed,
    deliveryRate: totalSent > 0 ? (totalDelivered / totalSent) : 0,
    openRate: totalDelivered > 0 ? (totalOpened / totalDelivered) : 0,
    failureRate: totalSent > 0 ? (totalFailed / totalSent) : 0,
    avgProcessingTime: Math.round(parseFloat(result.avg_processing_time) || 0)
  }
}

// Get time series analytics data
async function getTimeSeriesAnalytics(
  query: AnalyticsQuery,
  userId?: string
): Promise<AnalyticsData[]> {
  const { 
    startDate = getDefaultDateRange().startDate, 
    endDate = getDefaultDateRange().endDate,
    groupBy = 'day',
    limit = 100
  } = query
  
  let dateFormat = 'YYYY-MM-DD'
  let dateInterval = '1 day'
  
  switch (groupBy) {
    case 'week':
      dateFormat = 'YYYY-"W"WW'
      dateInterval = '1 week'
      break
    case 'month':
      dateFormat = 'YYYY-MM'
      dateInterval = '1 month'
      break
  }

  let sqlQuery = `
    SELECT 
      TO_CHAR(DATE_TRUNC('${groupBy}', sent_at), '${dateFormat}') as period,
      COUNT(*) as total_sent,
      COUNT(*) FILTER (WHERE delivery_status = 'delivered') as total_delivered,
      COUNT(*) FILTER (WHERE opened_at IS NOT NULL) as total_opened,
      COUNT(*) FILTER (WHERE delivery_status = 'failed') as total_failed,
      AVG(processing_time_ms) as avg_processing_time
    FROM notification_logs 
    WHERE DATE(sent_at) BETWEEN $1 AND $2
  `
  
  const params: any[] = [startDate, endDate]
  let paramIndex = 3

  if (query.notificationType) {
    sqlQuery += ` AND notification_type = $${paramIndex}`
    params.push(query.notificationType)
    paramIndex++
  }

  if (query.templateKey) {
    sqlQuery += ` AND payload->>'template_key' = $${paramIndex}`
    params.push(query.templateKey)
    paramIndex++
  }

  if (userId && !query.userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(userId)
    paramIndex++
  } else if (query.userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(query.userId)
    paramIndex++
  }

  sqlQuery += ` GROUP BY DATE_TRUNC('${groupBy}', sent_at) ORDER BY DATE_TRUNC('${groupBy}', sent_at) DESC LIMIT $${paramIndex}`
  params.push(limit)

  const { data, error } = await supabase.rpc('execute_sql', {
    query: sqlQuery,
    params
  })

  if (error) {
    throw new Error(`Failed to get time series analytics: ${error.message}`)
  }

  return (data || []).map((row: any) => {
    const totalSent = parseInt(row.total_sent) || 0
    const totalDelivered = parseInt(row.total_delivered) || 0
    const totalOpened = parseInt(row.total_opened) || 0
    const totalFailed = parseInt(row.total_failed) || 0

    return {
      period: row.period,
      totalSent,
      totalDelivered,
      totalOpened,
      totalFailed,
      deliveryRate: totalSent > 0 ? (totalDelivered / totalSent) : 0,
      openRate: totalDelivered > 0 ? (totalOpened / totalDelivered) : 0,
      failureRate: totalSent > 0 ? (totalFailed / totalSent) : 0,
      avgProcessingTime: Math.round(parseFloat(row.avg_processing_time) || 0)
    }
  })
}

// Get notification type analytics
async function getNotificationTypeAnalytics(
  query: AnalyticsQuery,
  userId?: string
): Promise<NotificationTypeAnalytics[]> {
  const { startDate = getDefaultDateRange().startDate, endDate = getDefaultDateRange().endDate } = query
  
  let sqlQuery = `
    SELECT 
      notification_type,
      payload->>'template_key' as template_key,
      COUNT(*) as total_sent,
      COUNT(*) FILTER (WHERE delivery_status = 'delivered') as total_delivered,
      COUNT(*) FILTER (WHERE opened_at IS NOT NULL) as total_opened,
      COUNT(*) FILTER (WHERE delivery_status = 'failed') as total_failed,
      AVG(processing_time_ms) as avg_processing_time
    FROM notification_logs 
    WHERE DATE(sent_at) BETWEEN $1 AND $2
  `
  
  const params: any[] = [startDate, endDate]
  let paramIndex = 3

  if (userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(userId)
    paramIndex++
  }

  sqlQuery += ` GROUP BY notification_type, payload->>'template_key' ORDER BY total_sent DESC`

  const { data, error } = await supabase.rpc('execute_sql', {
    query: sqlQuery,
    params
  })

  if (error) {
    throw new Error(`Failed to get notification type analytics: ${error.message}`)
  }

  return (data || []).map((row: any) => {
    const totalSent = parseInt(row.total_sent) || 0
    const totalDelivered = parseInt(row.total_delivered) || 0
    const totalOpened = parseInt(row.total_opened) || 0
    const totalFailed = parseInt(row.total_failed) || 0

    return {
      notificationType: row.notification_type,
      templateKey: row.template_key,
      totalSent,
      deliveryRate: totalSent > 0 ? (totalDelivered / totalSent) : 0,
      openRate: totalDelivered > 0 ? (totalOpened / totalDelivered) : 0,
      failureRate: totalSent > 0 ? (totalFailed / totalSent) : 0,
      avgProcessingTime: Math.round(parseFloat(row.avg_processing_time) || 0)
    }
  })
}

// Get device analytics
async function getDeviceAnalytics(
  query: AnalyticsQuery,
  userId?: string
): Promise<DeviceAnalytics[]> {
  const { startDate = getDefaultDateRange().startDate, endDate = getDefaultDateRange().endDate } = query
  
  let sqlQuery = `
    SELECT 
      dt.device_type,
      dt.environment,
      COUNT(nl.*) as total_sent,
      COUNT(nl.*) FILTER (WHERE nl.delivery_status = 'delivered') as total_delivered,
      AVG(nl.processing_time_ms) as avg_processing_time
    FROM notification_logs nl
    JOIN device_tokens dt ON nl.device_token = dt.device_token
    WHERE DATE(nl.sent_at) BETWEEN $1 AND $2
  `
  
  const params: any[] = [startDate, endDate]
  let paramIndex = 3

  if (userId) {
    sqlQuery += ` AND nl.user_id = $${paramIndex}`
    params.push(userId)
    paramIndex++
  }

  sqlQuery += ` GROUP BY dt.device_type, dt.environment ORDER BY total_sent DESC`

  const { data, error } = await supabase.rpc('execute_sql', {
    query: sqlQuery,
    params
  })

  if (error) {
    throw new Error(`Failed to get device analytics: ${error.message}`)
  }

  return (data || []).map((row: any) => {
    const totalSent = parseInt(row.total_sent) || 0
    const totalDelivered = parseInt(row.total_delivered) || 0

    return {
      deviceType: row.device_type,
      environment: row.environment,
      totalSent,
      deliveryRate: totalSent > 0 ? (totalDelivered / totalSent) : 0,
      avgProcessingTime: Math.round(parseFloat(row.avg_processing_time) || 0)
    }
  })
}

// Get error analytics
async function getErrorAnalytics(
  query: AnalyticsQuery,
  userId?: string
): Promise<ErrorAnalytics[]> {
  const { startDate = getDefaultDateRange().startDate, endDate = getDefaultDateRange().endDate } = query
  
  let sqlQuery = `
    SELECT 
      error_code,
      error_message,
      COUNT(*) as count,
      MAX(sent_at) as last_occurred
    FROM notification_logs 
    WHERE DATE(sent_at) BETWEEN $1 AND $2
    AND delivery_status = 'failed'
    AND error_code IS NOT NULL
  `
  
  const params: any[] = [startDate, endDate]
  let paramIndex = 3

  if (userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(userId)
    paramIndex++
  }

  sqlQuery += ` GROUP BY error_code, error_message ORDER BY count DESC LIMIT 20`

  const { data, error } = await supabase.rpc('execute_sql', {
    query: sqlQuery,
    params
  })

  if (error) {
    throw new Error(`Failed to get error analytics: ${error.message}`)
  }

  // Calculate total errors for percentage
  const totalErrors = (data || []).reduce((sum: number, row: any) => sum + parseInt(row.count), 0)

  return (data || []).map((row: any) => ({
    errorCode: row.error_code,
    errorMessage: row.error_message,
    count: parseInt(row.count),
    percentage: totalErrors > 0 ? (parseInt(row.count) / totalErrors) * 100 : 0,
    lastOccurred: row.last_occurred
  }))
}

// Get performance metrics
async function getPerformanceMetrics(
  query: AnalyticsQuery,
  userId?: string
): Promise<PerformanceMetrics> {
  const { startDate = getDefaultDateRange().startDate, endDate = getDefaultDateRange().endDate } = query
  
  let sqlQuery = `
    SELECT 
      AVG(processing_time_ms) as avg_processing_time,
      PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_time_ms) as p95_processing_time,
      PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY processing_time_ms) as p99_processing_time
    FROM notification_logs 
    WHERE DATE(sent_at) BETWEEN $1 AND $2
    AND processing_time_ms IS NOT NULL
  `
  
  const params: any[] = [startDate, endDate]
  let paramIndex = 3

  if (userId) {
    sqlQuery += ` AND user_id = $${paramIndex}`
    params.push(userId)
    paramIndex++
  }

  const { data: perfData, error: perfError } = await supabase.rpc('execute_sql', {
    query: sqlQuery,
    params
  })

  if (perfError) {
    throw new Error(`Failed to get performance metrics: ${perfError.message}`)
  }

  // Get slowest notifications
  let slowestQuery = `
    SELECT 
      id,
      notification_type,
      processing_time_ms,
      sent_at
    FROM notification_logs 
    WHERE DATE(sent_at) BETWEEN $1 AND $2
    AND processing_time_ms IS NOT NULL
  `
  
  const slowestParams = [startDate, endDate]
  let slowestParamIndex = 3

  if (userId) {
    slowestQuery += ` AND user_id = $${slowestParamIndex}`
    slowestParams.push(userId)
    slowestParamIndex++
  }

  slowestQuery += ` ORDER BY processing_time_ms DESC LIMIT 10`

  const { data: slowestData, error: slowestError } = await supabase.rpc('execute_sql', {
    query: slowestQuery,
    params: slowestParams
  })

  if (slowestError) {
    throw new Error(`Failed to get slowest notifications: ${slowestError.message}`)
  }

  const perfResult = perfData[0] || {}
  
  return {
    averageProcessingTime: Math.round(parseFloat(perfResult.avg_processing_time) || 0),
    p95ProcessingTime: Math.round(parseFloat(perfResult.p95_processing_time) || 0),
    p99ProcessingTime: Math.round(parseFloat(perfResult.p99_processing_time) || 0),
    slowestNotifications: (slowestData || []).map((row: any) => ({
      id: row.id,
      notificationType: row.notification_type,
      processingTime: parseInt(row.processing_time_ms),
      sentAt: row.sent_at
    }))
  }
}

// Update daily analytics (can be called via cron)
async function updateDailyAnalytics(date?: string): Promise<void> {
  const targetDate = date || new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  
  await supabase.rpc('update_notification_analytics')
}

// Main handler
serve(async (req) => {
  const url = new URL(req.url)
  const method = req.method
  const path = url.pathname

  try {
    // Get authenticated user and check admin role
    const { userId, isAdmin } = getAuthenticatedUser(req)
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Authentication required' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Parse query parameters
    const query: AnalyticsQuery = {
      startDate: url.searchParams.get('startDate') || undefined,
      endDate: url.searchParams.get('endDate') || undefined,
      notificationType: url.searchParams.get('notificationType') || undefined,
      templateKey: url.searchParams.get('templateKey') || undefined,
      userId: url.searchParams.get('userId') || undefined,
      groupBy: (url.searchParams.get('groupBy') as any) || 'day',
      limit: parseInt(url.searchParams.get('limit') || '100')
    }

    // Non-admin users can only see their own analytics
    const analyticsUserId = isAdmin ? undefined : userId

    // Route handling
    if (method === 'GET' && path.endsWith('/summary')) {
      const summary = await getAnalyticsSummary(query, analyticsUserId)
      return new Response(
        JSON.stringify({ success: true, data: summary }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/timeseries')) {
      const timeseries = await getTimeSeriesAnalytics(query, analyticsUserId)
      return new Response(
        JSON.stringify({ success: true, data: timeseries }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/types')) {
      const types = await getNotificationTypeAnalytics(query, analyticsUserId)
      return new Response(
        JSON.stringify({ success: true, data: types }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/devices')) {
      const devices = await getDeviceAnalytics(query, analyticsUserId)
      return new Response(
        JSON.stringify({ success: true, data: devices }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/errors')) {
      const errors = await getErrorAnalytics(query, analyticsUserId)
      return new Response(
        JSON.stringify({ success: true, data: errors }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/performance')) {
      const performance = await getPerformanceMetrics(query, analyticsUserId)
      return new Response(
        JSON.stringify({ success: true, data: performance }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'POST' && path.endsWith('/update-daily') && isAdmin) {
      const { date } = await req.json()
      await updateDailyAnalytics(date)
      return new Response(
        JSON.stringify({ success: true, message: 'Daily analytics updated' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Default response for unmatched routes
    return new Response(
      JSON.stringify({ 
        error: 'Not found',
        availableEndpoints: [
          'GET /summary - Get analytics summary',
          'GET /timeseries - Get time series data',
          'GET /types - Get notification type analytics',
          'GET /devices - Get device analytics',
          'GET /errors - Get error analytics',
          'GET /performance - Get performance metrics',
          'POST /update-daily - Update daily analytics (admin only)'
        ]
      }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Analytics error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})