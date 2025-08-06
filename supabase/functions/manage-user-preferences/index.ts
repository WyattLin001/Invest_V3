/**
 * Manage User Preferences Edge Function
 * 
 * Handles user notification preferences including delivery methods,
 * quiet hours, frequency settings, and notification type toggles.
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'supabase'

// Types and Interfaces
interface UserNotificationPreference {
  id: string
  userId: string
  notificationType: string
  isEnabled: boolean
  deliveryMethod: string[]
  quietHoursStart?: string
  quietHoursEnd?: string
  timezone: string
  frequency: 'immediate' | 'hourly' | 'daily' | 'weekly'
  customSettings: Record<string, any>
  createdAt: string
  updatedAt: string
}

interface UpdatePreferenceRequest {
  notificationType: string
  isEnabled?: boolean
  deliveryMethod?: string[]
  quietHoursStart?: string
  quietHoursEnd?: string
  timezone?: string
  frequency?: 'immediate' | 'hourly' | 'daily' | 'weekly'
  customSettings?: Record<string, any>
}

interface BulkUpdateRequest {
  preferences: UpdatePreferenceRequest[]
}

interface GlobalSettingsRequest {
  quietHoursStart?: string
  quietHoursEnd?: string
  timezone?: string
  defaultFrequency?: 'immediate' | 'hourly' | 'daily' | 'weekly'
  globallyDisabled?: boolean
}

interface NotificationTypeInfo {
  type: string
  displayName: string
  description: string
  defaultEnabled: boolean
  allowedDeliveryMethods: string[]
  allowedFrequencies: string[]
}

// Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Get authenticated user ID
function getAuthenticatedUserId(req: Request): string | null {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return null

  try {
    const token = authHeader.replace('Bearer ', '')
    const parts = token.split('.')
    if (parts.length !== 3) return null
    
    const payload = JSON.parse(atob(parts[1]))
    return payload.sub || null
  } catch {
    return null
  }
}

// Available notification types with metadata
const NOTIFICATION_TYPES: NotificationTypeInfo[] = [
  {
    type: 'host_message',
    displayName: '主持人訊息',
    description: '來自群組主持人的重要訊息',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push', 'email'],
    allowedFrequencies: ['immediate']
  },
  {
    type: 'stock_alert',
    displayName: '股價提醒',
    description: '股票價格到達設定目標時的提醒',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push', 'email', 'sms'],
    allowedFrequencies: ['immediate']
  },
  {
    type: 'ranking_update',
    displayName: '排名更新',
    description: '投資競賽排名變化通知',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push'],
    allowedFrequencies: ['immediate', 'hourly', 'daily']
  },
  {
    type: 'chat_message',
    displayName: '聊天訊息',
    description: '群組聊天新訊息通知',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push'],
    allowedFrequencies: ['immediate', 'hourly']
  },
  {
    type: 'system_alert',
    displayName: '系統通知',
    description: '重要系統公告和維護通知',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push', 'email'],
    allowedFrequencies: ['immediate']
  },
  {
    type: 'tournament_reminder',
    displayName: '錦標賽提醒',
    description: '錦標賽開始、結束等重要時間提醒',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push', 'email'],
    allowedFrequencies: ['immediate', 'daily']
  },
  {
    type: 'article_update',
    displayName: '文章更新',
    description: '關注作者發佈新文章的通知',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push', 'email'],
    allowedFrequencies: ['immediate', 'hourly', 'daily', 'weekly']
  },
  {
    type: 'friend_request',
    displayName: '好友邀請',
    description: '新的好友邀請請求',
    defaultEnabled: true,
    allowedDeliveryMethods: ['push'],
    allowedFrequencies: ['immediate']
  }
]

// Validate timezone
function isValidTimezone(timezone: string): boolean {
  try {
    Intl.DateTimeFormat(undefined, { timeZone: timezone })
    return true
  } catch {
    return false
  }
}

// Validate time format (HH:MM)
function isValidTime(time: string): boolean {
  return /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(time)
}

// Get user's notification preferences
async function getUserPreferences(userId: string): Promise<UserNotificationPreference[]> {
  const { data, error } = await supabase
    .from('user_notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .order('notification_type')

  if (error) {
    throw new Error(`Failed to get user preferences: ${error.message}`)
  }

  return (data || []).map(pref => ({
    id: pref.id,
    userId: pref.user_id,
    notificationType: pref.notification_type,
    isEnabled: pref.is_enabled,
    deliveryMethod: pref.delivery_method || ['push'],
    quietHoursStart: pref.quiet_hours_start,
    quietHoursEnd: pref.quiet_hours_end,
    timezone: pref.timezone || 'Asia/Taipei',
    frequency: pref.frequency || 'immediate',
    customSettings: pref.custom_settings || {},
    createdAt: pref.created_at,
    updatedAt: pref.updated_at
  }))
}

// Update single notification preference
async function updateNotificationPreference(
  userId: string,
  request: UpdatePreferenceRequest
): Promise<UserNotificationPreference> {
  const { notificationType, ...updates } = request

  // Validate notification type
  const typeInfo = NOTIFICATION_TYPES.find(t => t.type === notificationType)
  if (!typeInfo) {
    throw new Error(`Invalid notification type: ${notificationType}`)
  }

  // Validate delivery methods
  if (updates.deliveryMethod) {
    const invalidMethods = updates.deliveryMethod.filter(
      method => !typeInfo.allowedDeliveryMethods.includes(method)
    )
    if (invalidMethods.length > 0) {
      throw new Error(`Invalid delivery methods for ${notificationType}: ${invalidMethods.join(', ')}`)
    }
  }

  // Validate frequency
  if (updates.frequency && !typeInfo.allowedFrequencies.includes(updates.frequency)) {
    throw new Error(`Invalid frequency for ${notificationType}: ${updates.frequency}`)
  }

  // Validate timezone
  if (updates.timezone && !isValidTimezone(updates.timezone)) {
    throw new Error(`Invalid timezone: ${updates.timezone}`)
  }

  // Validate quiet hours
  if (updates.quietHoursStart && !isValidTime(updates.quietHoursStart)) {
    throw new Error(`Invalid quiet hours start time: ${updates.quietHoursStart}`)
  }
  if (updates.quietHoursEnd && !isValidTime(updates.quietHoursEnd)) {
    throw new Error(`Invalid quiet hours end time: ${updates.quietHoursEnd}`)
  }

  // Prepare update object
  const updateData: any = {
    updated_at: new Date().toISOString()
  }

  if (updates.isEnabled !== undefined) updateData.is_enabled = updates.isEnabled
  if (updates.deliveryMethod) updateData.delivery_method = updates.deliveryMethod
  if (updates.quietHoursStart) updateData.quiet_hours_start = updates.quietHoursStart
  if (updates.quietHoursEnd) updateData.quiet_hours_end = updates.quietHoursEnd
  if (updates.timezone) updateData.timezone = updates.timezone
  if (updates.frequency) updateData.frequency = updates.frequency
  if (updates.customSettings) updateData.custom_settings = updates.customSettings

  // Upsert preference
  const { data, error } = await supabase
    .from('user_notification_preferences')
    .upsert({
      user_id: userId,
      notification_type: notificationType,
      ...updateData
    }, {
      onConflict: 'user_id, notification_type'
    })
    .select()
    .single()

  if (error) {
    throw new Error(`Failed to update preference: ${error.message}`)
  }

  return {
    id: data.id,
    userId: data.user_id,
    notificationType: data.notification_type,
    isEnabled: data.is_enabled,
    deliveryMethod: data.delivery_method || ['push'],
    quietHoursStart: data.quiet_hours_start,
    quietHoursEnd: data.quiet_hours_end,
    timezone: data.timezone || 'Asia/Taipei',
    frequency: data.frequency || 'immediate',
    customSettings: data.custom_settings || {},
    createdAt: data.created_at,
    updatedAt: data.updated_at
  }
}

// Bulk update preferences
async function bulkUpdatePreferences(
  userId: string,
  request: BulkUpdateRequest
): Promise<UserNotificationPreference[]> {
  const results: UserNotificationPreference[] = []
  
  for (const prefUpdate of request.preferences) {
    try {
      const result = await updateNotificationPreference(userId, prefUpdate)
      results.push(result)
    } catch (error) {
      console.error(`Failed to update preference ${prefUpdate.notificationType}:`, error)
      // Continue with other preferences
    }
  }
  
  return results
}

// Apply global settings to all preferences
async function updateGlobalSettings(
  userId: string,
  request: GlobalSettingsRequest
): Promise<void> {
  const updates: any = {
    updated_at: new Date().toISOString()
  }

  if (request.quietHoursStart) {
    if (!isValidTime(request.quietHoursStart)) {
      throw new Error(`Invalid quiet hours start time: ${request.quietHoursStart}`)
    }
    updates.quiet_hours_start = request.quietHoursStart
  }

  if (request.quietHoursEnd) {
    if (!isValidTime(request.quietHoursEnd)) {
      throw new Error(`Invalid quiet hours end time: ${request.quietHoursEnd}`)
    }
    updates.quiet_hours_end = request.quietHoursEnd
  }

  if (request.timezone) {
    if (!isValidTimezone(request.timezone)) {
      throw new Error(`Invalid timezone: ${request.timezone}`)
    }
    updates.timezone = request.timezone
  }

  if (request.defaultFrequency) {
    updates.frequency = request.defaultFrequency
  }

  if (request.globallyDisabled !== undefined) {
    updates.is_enabled = !request.globallyDisabled
  }

  const { error } = await supabase
    .from('user_notification_preferences')
    .update(updates)
    .eq('user_id', userId)

  if (error) {
    throw new Error(`Failed to update global settings: ${error.message}`)
  }
}

// Reset preferences to default
async function resetPreferencesToDefault(userId: string): Promise<UserNotificationPreference[]> {
  // Delete existing preferences
  await supabase
    .from('user_notification_preferences')
    .delete()
    .eq('user_id', userId)

  // Insert default preferences
  const defaultPreferences = NOTIFICATION_TYPES.map(type => ({
    user_id: userId,
    notification_type: type.type,
    is_enabled: type.defaultEnabled,
    delivery_method: [type.allowedDeliveryMethods[0]], // Use first allowed method as default
    timezone: 'Asia/Taipei',
    frequency: type.allowedFrequencies.includes('immediate') ? 'immediate' : type.allowedFrequencies[0],
    custom_settings: {}
  }))

  const { data, error } = await supabase
    .from('user_notification_preferences')
    .insert(defaultPreferences)
    .select()

  if (error) {
    throw new Error(`Failed to reset preferences: ${error.message}`)
  }

  return (data || []).map(pref => ({
    id: pref.id,
    userId: pref.user_id,
    notificationType: pref.notification_type,
    isEnabled: pref.is_enabled,
    deliveryMethod: pref.delivery_method || ['push'],
    quietHoursStart: pref.quiet_hours_start,
    quietHoursEnd: pref.quiet_hours_end,
    timezone: pref.timezone || 'Asia/Taipei',
    frequency: pref.frequency || 'immediate',
    customSettings: pref.custom_settings || {},
    createdAt: pref.created_at,
    updatedAt: pref.updated_at
  }))
}

// Export preferences
async function exportUserPreferences(userId: string): Promise<{
  preferences: UserNotificationPreference[]
  exportedAt: string
}> {
  const preferences = await getUserPreferences(userId)
  
  return {
    preferences,
    exportedAt: new Date().toISOString()
  }
}

// Import preferences
async function importUserPreferences(
  userId: string,
  preferences: Partial<UserNotificationPreference>[]
): Promise<UserNotificationPreference[]> {
  const results: UserNotificationPreference[] = []
  
  for (const pref of preferences) {
    if (!pref.notificationType) continue
    
    try {
      const result = await updateNotificationPreference(userId, {
        notificationType: pref.notificationType,
        isEnabled: pref.isEnabled,
        deliveryMethod: pref.deliveryMethod,
        quietHoursStart: pref.quietHoursStart,
        quietHoursEnd: pref.quietHoursEnd,
        timezone: pref.timezone,
        frequency: pref.frequency,
        customSettings: pref.customSettings
      })
      results.push(result)
    } catch (error) {
      console.error(`Failed to import preference ${pref.notificationType}:`, error)
    }
  }
  
  return results
}

// Main handler
serve(async (req) => {
  const url = new URL(req.url)
  const method = req.method
  const path = url.pathname

  try {
    // Get authenticated user
    const userId = getAuthenticatedUserId(req)
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Authentication required' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Route handling
    if (method === 'GET' && path.endsWith('/preferences')) {
      // Get user preferences
      const preferences = await getUserPreferences(userId)
      return new Response(
        JSON.stringify({ 
          success: true, 
          data: preferences 
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/types')) {
      // Get available notification types
      return new Response(
        JSON.stringify({ 
          success: true, 
          data: NOTIFICATION_TYPES 
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'PUT' && path.endsWith('/preferences')) {
      // Update single preference
      const request: UpdatePreferenceRequest = await req.json()
      
      if (!request.notificationType) {
        return new Response(
          JSON.stringify({ error: 'notificationType is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const result = await updateNotificationPreference(userId, request)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Preference updated successfully',
          data: result
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'PUT' && path.endsWith('/preferences/bulk')) {
      // Bulk update preferences
      const request: BulkUpdateRequest = await req.json()
      
      if (!request.preferences || !Array.isArray(request.preferences)) {
        return new Response(
          JSON.stringify({ error: 'preferences array is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const results = await bulkUpdatePreferences(userId, request)
      return new Response(
        JSON.stringify({
          success: true,
          message: `Updated ${results.length} preferences`,
          data: results
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'PUT' && path.endsWith('/global-settings')) {
      // Update global settings
      const request: GlobalSettingsRequest = await req.json()
      
      await updateGlobalSettings(userId, request)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Global settings updated successfully'
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'POST' && path.endsWith('/reset')) {
      // Reset to defaults
      const result = await resetPreferencesToDefault(userId)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Preferences reset to defaults',
          data: result
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/export')) {
      // Export preferences
      const result = await exportUserPreferences(userId)
      return new Response(
        JSON.stringify({
          success: true,
          data: result
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'POST' && path.endsWith('/import')) {
      // Import preferences
      const { preferences } = await req.json()
      
      if (!preferences || !Array.isArray(preferences)) {
        return new Response(
          JSON.stringify({ error: 'preferences array is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const results = await importUserPreferences(userId, preferences)
      return new Response(
        JSON.stringify({
          success: true,
          message: `Imported ${results.length} preferences`,
          data: results
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Default response for unmatched routes
    return new Response(
      JSON.stringify({ 
        error: 'Not found',
        availableEndpoints: [
          'GET /preferences - Get user preferences',
          'GET /types - Get available notification types',
          'PUT /preferences - Update single preference',
          'PUT /preferences/bulk - Bulk update preferences',
          'PUT /global-settings - Update global settings',
          'POST /reset - Reset to defaults',
          'GET /export - Export preferences',
          'POST /import - Import preferences'
        ]
      }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('User preferences error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})