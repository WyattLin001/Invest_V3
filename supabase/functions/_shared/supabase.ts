/**
 * Shared Supabase utilities for Edge Functions
 * 
 * This file contains common Supabase client setup and database
 * interaction utilities used across notification functions.
 */

import { createClient } from 'supabase'
import { CONFIG, Logger } from './config.ts'

// Create Supabase client with service role
export const supabase = createClient(
  CONFIG.supabaseUrl,
  CONFIG.supabaseServiceKey
)

// Database interaction utilities
export class DatabaseService {
  
  // Device token operations
  static async getActiveDeviceTokens(userIds: string[]): Promise<any[]> {
    const { data, error } = await supabase
      .from('device_tokens')
      .select('id, device_token, device_type, environment, user_id')
      .in('user_id', userIds)
      .eq('is_active', true)
      .eq('environment', CONFIG.apns.environment)
      .gte('last_used_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())

    if (error) {
      Logger.error('Failed to get device tokens', error)
      throw new Error(`Failed to get device tokens: ${error.message}`)
    }

    return data || []
  }

  static async updateDeviceTokenLastUsed(deviceTokenId: string): Promise<void> {
    const { error } = await supabase
      .from('device_tokens')
      .update({ 
        last_used_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', deviceTokenId)

    if (error) {
      Logger.error('Failed to update device token last used', error)
    }
  }

  static async deactivateDeviceToken(deviceTokenId: string): Promise<void> {
    const { error } = await supabase
      .from('device_tokens')
      .update({ 
        is_active: false,
        updated_at: new Date().toISOString()
      })
      .eq('id', deviceTokenId)

    if (error) {
      Logger.error('Failed to deactivate device token', error)
    }
  }

  // Notification preferences
  static async getUserNotificationPreferences(
    userId: string, 
    notificationType: string
  ): Promise<any> {
    const { data, error } = await supabase
      .from('user_notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .eq('notification_type', notificationType)
      .single()

    if (error && error.code !== 'PGRST116') { // Not found error
      Logger.error('Failed to get user preferences', error)
      throw new Error(`Failed to get user preferences: ${error.message}`)
    }

    return data
  }

  static async canUserReceiveNotification(
    userId: string, 
    notificationType: string
  ): Promise<boolean> {
    try {
      const { data } = await supabase.rpc('can_user_receive_notification', {
        target_user_id: userId,
        notification_type_param: notificationType
      })
      
      return data === true
    } catch (error) {
      Logger.error('Failed to check notification permissions', error)
      return false // Default to not sending if check fails
    }
  }

  // Notification templates
  static async getNotificationTemplate(templateKey: string): Promise<any> {
    const { data, error } = await supabase
      .from('notification_templates')
      .select('*')
      .eq('template_key', templateKey)
      .eq('is_active', true)
      .single()

    if (error) {
      Logger.error('Failed to get notification template', error)
      return null
    }

    return data
  }

  // Notification logging
  static async logNotification(logEntry: {
    queue_id?: string
    user_id: string
    device_token: string
    notification_type: string
    title: string
    body: string
    payload: any
    apns_response?: any
    http_status_code?: number
    delivery_status: 'sent' | 'delivered' | 'failed' | 'expired'
    error_code?: string
    error_message?: string
    retry_attempt?: number
    processing_time_ms?: number
  }): Promise<void> {
    const { error } = await supabase
      .from('notification_logs')
      .insert({
        ...logEntry,
        sent_at: new Date().toISOString()
      })

    if (error) {
      Logger.error('Failed to log notification', error)
      // Don't throw error for logging failures
    }
  }

  // Queue management
  static async addToNotificationQueue(queueEntry: {
    user_id: string
    device_token_id?: string
    template_key?: string
    notification_type: string
    title: string
    body: string
    payload: any
    priority?: number
    scheduled_for?: string
    max_retry_attempts?: number
  }): Promise<string> {
    const { data, error } = await supabase
      .from('notification_queue')
      .insert(queueEntry)
      .select('id')
      .single()

    if (error) {
      Logger.error('Failed to add to notification queue', error)
      throw new Error(`Failed to add to notification queue: ${error.message}`)
    }

    return data.id
  }

  static async updateQueueStatus(
    queueId: string, 
    status: 'pending' | 'processing' | 'sent' | 'failed' | 'cancelled',
    errorMessage?: string
  ): Promise<void> {
    const updates: any = {
      status,
      updated_at: new Date().toISOString()
    }

    if (status === 'sent') {
      updates.sent_at = new Date().toISOString()
    }

    if (errorMessage) {
      updates.error_message = errorMessage
    }

    const { error } = await supabase
      .from('notification_queue')
      .update(updates)
      .eq('id', queueId)

    if (error) {
      Logger.error('Failed to update queue status', error)
    }
  }

  static async incrementRetryCount(queueId: string): Promise<void> {
    const { error } = await supabase
      .rpc('increment_retry_count', { queue_id: queueId })

    if (error) {
      Logger.error('Failed to increment retry count', error)
    }
  }

  static async getPendingNotifications(limit: number = 100): Promise<any[]> {
    const { data, error } = await supabase
      .from('notification_queue')
      .select('*')
      .eq('status', 'pending')
      .lte('scheduled_for', new Date().toISOString())
      .order('priority', { ascending: true })
      .order('created_at', { ascending: true })
      .limit(limit)

    if (error) {
      Logger.error('Failed to get pending notifications', error)
      throw new Error(`Failed to get pending notifications: ${error.message}`)
    }

    return data || []
  }

  // Rate limiting
  static async checkRateLimit(
    userId: string, 
    notificationType: string,
    maxNotifications: number = 100,
    windowHours: number = 1
  ): Promise<{ allowed: boolean; currentCount: number; resetTime: Date }> {
    const windowStart = new Date()
    windowStart.setHours(windowStart.getHours() - windowHours)

    // Check current count in the window
    const { data, error } = await supabase
      .from('notification_logs')
      .select('id', { count: 'exact' })
      .eq('user_id', userId)
      .eq('notification_type', notificationType)
      .gte('sent_at', windowStart.toISOString())

    if (error) {
      Logger.error('Failed to check rate limit', error)
      return { allowed: true, currentCount: 0, resetTime: new Date() }
    }

    const currentCount = data?.length || 0
    const resetTime = new Date()
    resetTime.setHours(resetTime.getHours() + 1)

    return {
      allowed: currentCount < maxNotifications,
      currentCount,
      resetTime
    }
  }

  // Analytics
  static async getNotificationStats(
    startDate: string,
    endDate: string,
    userId?: string
  ): Promise<{
    totalSent: number
    totalDelivered: number
    totalOpened: number
    totalFailed: number
  }> {
    let query = supabase
      .from('notification_logs')
      .select('delivery_status, opened_at')
      .gte('sent_at', startDate)
      .lte('sent_at', endDate)

    if (userId) {
      query = query.eq('user_id', userId)
    }

    const { data, error } = await query

    if (error) {
      Logger.error('Failed to get notification stats', error)
      throw new Error(`Failed to get notification stats: ${error.message}`)
    }

    const stats = {
      totalSent: data?.length || 0,
      totalDelivered: 0,
      totalOpened: 0,
      totalFailed: 0
    }

    data?.forEach(log => {
      if (log.delivery_status === 'delivered') {
        stats.totalDelivered++
      } else if (log.delivery_status === 'failed') {
        stats.totalFailed++
      }
      
      if (log.opened_at) {
        stats.totalOpened++
      }
    })

    return stats
  }

  // Bulk operations
  static async createBulkCampaign(campaign: {
    campaign_name: string
    template_key?: string
    target_criteria: any
    title: string
    body: string
    payload: any
    scheduled_for?: string
    total_recipients: number
    created_by: string
  }): Promise<string> {
    const { data, error } = await supabase
      .from('bulk_notification_campaigns')
      .insert({
        ...campaign,
        status: campaign.scheduled_for ? 'scheduled' : 'processing'
      })
      .select('id')
      .single()

    if (error) {
      Logger.error('Failed to create bulk campaign', error)
      throw new Error(`Failed to create bulk campaign: ${error.message}`)
    }

    return data.id
  }

  static async updateCampaignProgress(
    campaignId: string,
    updates: {
      status?: string
      total_sent?: number
      total_failed?: number
      completed_at?: string
    }
  ): Promise<void> {
    const { error } = await supabase
      .from('bulk_notification_campaigns')
      .update({
        ...updates,
        updated_at: new Date().toISOString()
      })
      .eq('id', campaignId)

    if (error) {
      Logger.error('Failed to update campaign progress', error)
    }
  }

  // Cleanup operations
  static async cleanupOldLogs(daysToKeep: number = 30): Promise<number> {
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep)

    const { data, error } = await supabase
      .from('notification_logs')
      .delete()
      .lt('sent_at', cutoffDate.toISOString())
      .select('id')

    if (error) {
      Logger.error('Failed to cleanup old logs', error)
      return 0
    }

    return data?.length || 0
  }

  static async cleanupInactiveDeviceTokens(daysInactive: number = 90): Promise<number> {
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - daysInactive)

    const { data, error } = await supabase
      .from('device_tokens')
      .update({ is_active: false })
      .lt('last_used_at', cutoffDate.toISOString())
      .eq('is_active', true)
      .select('id')

    if (error) {
      Logger.error('Failed to cleanup inactive device tokens', error)
      return 0
    }

    return data?.length || 0
  }
}

// Helper function to execute raw SQL queries
export async function executeSQL(query: string, params?: any[]): Promise<any[]> {
  try {
    const { data, error } = await supabase.rpc('execute_sql', {
      query,
      params: params || []
    })

    if (error) {
      Logger.error('SQL execution failed', error)
      throw new Error(`SQL execution failed: ${error.message}`)
    }

    return data || []
  } catch (error) {
    Logger.error('Failed to execute SQL', error)
    throw error
  }
}