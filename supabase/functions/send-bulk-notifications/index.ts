/**
 * Send Bulk Notifications Edge Function
 * 
 * Handles sending bulk push notifications for announcements, campaigns,
 * and mass messaging with advanced targeting and scheduling capabilities.
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'supabase'

// Types and Interfaces
interface BulkNotificationRequest {
  campaignName: string
  templateKey?: string
  title: string
  body: string
  notificationType: string
  targetCriteria: {
    userIds?: string[]
    tags?: string[]
    deviceTypes?: ('ios' | 'android' | 'web')[]
    environment?: 'sandbox' | 'production'
    lastActiveAfter?: string // ISO date
    excludeUserIds?: string[]
    maxRecipients?: number
  }
  scheduledFor?: string // ISO date - if not provided, send immediately
  priority?: number
  data?: Record<string, any>
  sound?: string
  badge?: number
  category?: string
  collapseId?: string
}

interface CampaignResponse {
  campaignId: string
  status: 'draft' | 'scheduled' | 'processing' | 'completed' | 'failed'
  totalRecipients: number
  estimatedCost?: number
  scheduledFor?: string
}

interface CampaignStatus {
  id: string
  campaignName: string
  status: string
  totalRecipients: number
  totalSent: number
  totalFailed: number
  createdAt: string
  completedAt?: string
  progress?: number
}

// Configuration
const MAX_BULK_RECIPIENTS = 10000
const BATCH_SIZE = 100
const PROCESSING_DELAY_MS = 100 // Delay between batches to avoid rate limiting

// Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Get authenticated user ID and check admin role
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

// Get target users based on criteria
async function getTargetUsers(criteria: BulkNotificationRequest['targetCriteria']): Promise<string[]> {
  let query = supabase
    .from('device_tokens')
    .select('user_id')
    .eq('is_active', true)

  // Apply device type filter
  if (criteria.deviceTypes && criteria.deviceTypes.length > 0) {
    query = query.in('device_type', criteria.deviceTypes)
  }

  // Apply environment filter
  if (criteria.environment) {
    query = query.eq('environment', criteria.environment)
  }

  // Apply last active filter
  if (criteria.lastActiveAfter) {
    query = query.gte('last_used_at', criteria.lastActiveAfter)
  }

  const { data: deviceTokenData, error } = await query

  if (error) {
    throw new Error(`Failed to get device tokens: ${error.message}`)
  }

  let userIds = [...new Set((deviceTokenData || []).map(dt => dt.user_id))]

  // Apply direct user ID filter
  if (criteria.userIds && criteria.userIds.length > 0) {
    userIds = userIds.filter(id => criteria.userIds!.includes(id))
  }

  // Apply exclude user IDs filter
  if (criteria.excludeUserIds && criteria.excludeUserIds.length > 0) {
    userIds = userIds.filter(id => !criteria.excludeUserIds!.includes(id))
  }

  // Apply max recipients limit
  if (criteria.maxRecipients && userIds.length > criteria.maxRecipients) {
    userIds = userIds.slice(0, criteria.maxRecipients)
  }

  // Overall safety limit
  if (userIds.length > MAX_BULK_RECIPIENTS) {
    userIds = userIds.slice(0, MAX_BULK_RECIPIENTS)
  }

  return userIds
}

// Create bulk notification campaign
async function createBulkCampaign(
  request: BulkNotificationRequest,
  createdBy: string,
  targetUserIds: string[]
): Promise<CampaignResponse> {
  const now = new Date().toISOString()
  const scheduledFor = request.scheduledFor || now

  const campaign = {
    campaign_name: request.campaignName,
    template_key: request.templateKey,
    target_criteria: request.targetCriteria,
    title: request.title,
    body: request.body,
    payload: {
      notification_type: request.notificationType,
      priority: request.priority,
      sound: request.sound,
      badge: request.badge,
      category: request.category,
      collapse_id: request.collapseId,
      data: request.data
    },
    scheduled_for: scheduledFor,
    status: request.scheduledFor ? 'scheduled' : 'processing',
    total_recipients: targetUserIds.length,
    created_by: createdBy
  }

  const { data, error } = await supabase
    .from('bulk_notification_campaigns')
    .insert(campaign)
    .select()
    .single()

  if (error) {
    throw new Error(`Failed to create campaign: ${error.message}`)
  }

  return {
    campaignId: data.id,
    status: data.status,
    totalRecipients: data.total_recipients,
    scheduledFor: data.scheduled_for
  }
}

// Process immediate bulk notification
async function processImmediateBulkNotification(
  campaignId: string,
  request: BulkNotificationRequest,
  targetUserIds: string[]
): Promise<void> {
  try {
    // Update campaign status to processing
    await supabase
      .from('bulk_notification_campaigns')
      .update({ 
        status: 'processing',
        updated_at: new Date().toISOString()
      })
      .eq('id', campaignId)

    let totalSent = 0
    let totalFailed = 0

    // Process in batches
    for (let i = 0; i < targetUserIds.length; i += BATCH_SIZE) {
      const batch = targetUserIds.slice(i, i + BATCH_SIZE)
      
      try {
        // Call the send-push-notification function
        const response = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            userIds: batch,
            notificationType: request.notificationType,
            templateKey: request.templateKey,
            title: request.title,
            body: request.body,
            priority: request.priority,
            sound: request.sound,
            badge: request.badge,
            category: request.category,
            collapseId: request.collapseId,
            data: {
              ...request.data,
              campaign_id: campaignId,
              is_bulk: true
            }
          })
        })

        if (response.ok) {
          const result = await response.json()
          totalSent += result.totalSent || 0
          totalFailed += result.totalFailed || 0
        } else {
          console.error(`Batch ${i / BATCH_SIZE + 1} failed:`, await response.text())
          totalFailed += batch.length
        }
      } catch (error) {
        console.error(`Batch ${i / BATCH_SIZE + 1} error:`, error)
        totalFailed += batch.length
      }

      // Update progress
      const progress = Math.round(((i + BATCH_SIZE) / targetUserIds.length) * 100)
      await supabase
        .from('bulk_notification_campaigns')
        .update({ 
          total_sent: totalSent,
          total_failed: totalFailed,
          updated_at: new Date().toISOString()
        })
        .eq('id', campaignId)

      // Small delay to avoid overwhelming the system
      if (i + BATCH_SIZE < targetUserIds.length) {
        await new Promise(resolve => setTimeout(resolve, PROCESSING_DELAY_MS))
      }
    }

    // Mark campaign as completed
    await supabase
      .from('bulk_notification_campaigns')
      .update({ 
        status: 'completed',
        total_sent: totalSent,
        total_failed: totalFailed,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', campaignId)

  } catch (error) {
    console.error(`Campaign ${campaignId} failed:`, error)
    
    // Mark campaign as failed
    await supabase
      .from('bulk_notification_campaigns')
      .update({ 
        status: 'failed',
        updated_at: new Date().toISOString()
      })
      .eq('id', campaignId)
  }
}

// Get campaign status
async function getCampaignStatus(campaignId: string, userId: string, isAdmin: boolean): Promise<CampaignStatus> {
  let query = supabase
    .from('bulk_notification_campaigns')
    .select('*')
    .eq('id', campaignId)

  // Non-admin users can only see their own campaigns
  if (!isAdmin) {
    query = query.eq('created_by', userId)
  }

  const { data, error } = await query.single()

  if (error) {
    throw new Error(`Failed to get campaign status: ${error.message}`)
  }

  const progress = data.total_recipients > 0 ? 
    Math.round(((data.total_sent + data.total_failed) / data.total_recipients) * 100) : 0

  return {
    id: data.id,
    campaignName: data.campaign_name,
    status: data.status,
    totalRecipients: data.total_recipients,
    totalSent: data.total_sent || 0,
    totalFailed: data.total_failed || 0,
    createdAt: data.created_at,
    completedAt: data.completed_at,
    progress
  }
}

// Get user's campaigns
async function getUserCampaigns(userId: string, isAdmin: boolean): Promise<CampaignStatus[]> {
  let query = supabase
    .from('bulk_notification_campaigns')
    .select('*')
    .order('created_at', { ascending: false })

  // Non-admin users can only see their own campaigns
  if (!isAdmin) {
    query = query.eq('created_by', userId)
  }

  const { data, error } = await query

  if (error) {
    throw new Error(`Failed to get campaigns: ${error.message}`)
  }

  return (data || []).map(campaign => ({
    id: campaign.id,
    campaignName: campaign.campaign_name,
    status: campaign.status,
    totalRecipients: campaign.total_recipients,
    totalSent: campaign.total_sent || 0,
    totalFailed: campaign.total_failed || 0,
    createdAt: campaign.created_at,
    completedAt: campaign.completed_at,
    progress: campaign.total_recipients > 0 ? 
      Math.round(((campaign.total_sent + campaign.total_failed) / campaign.total_recipients) * 100) : 0
  }))
}

// Cancel campaign
async function cancelCampaign(campaignId: string, userId: string, isAdmin: boolean): Promise<void> {
  let query = supabase
    .from('bulk_notification_campaigns')
    .update({ 
      status: 'cancelled',
      updated_at: new Date().toISOString()
    })
    .eq('id', campaignId)

  // Non-admin users can only cancel their own campaigns
  if (!isAdmin) {
    query = query.eq('created_by', userId)
  }

  const { error } = await query

  if (error) {
    throw new Error(`Failed to cancel campaign: ${error.message}`)
  }
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

    // Only admins can create bulk campaigns
    if ((method === 'POST' && path.endsWith('/send')) && !isAdmin) {
      return new Response(
        JSON.stringify({ error: 'Admin privileges required' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Route handling
    if (method === 'POST' && path.endsWith('/send')) {
      // Create and send bulk notification
      const request: BulkNotificationRequest = await req.json()
      
      // Validate required fields
      if (!request.campaignName || !request.title || !request.body || !request.notificationType) {
        return new Response(
          JSON.stringify({ 
            error: 'Missing required fields: campaignName, title, body, notificationType' 
          }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      // Get target users
      const targetUserIds = await getTargetUsers(request.targetCriteria)
      
      if (targetUserIds.length === 0) {
        return new Response(
          JSON.stringify({ 
            error: 'No target users found matching the criteria' 
          }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      // Create campaign
      const campaign = await createBulkCampaign(request, userId, targetUserIds)
      
      // If not scheduled, process immediately in background
      if (!request.scheduledFor) {
        // Process in background - don't await
        processImmediateBulkNotification(campaign.campaignId, request, targetUserIds)
          .catch(error => console.error('Background processing error:', error))
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: request.scheduledFor ? 'Campaign scheduled successfully' : 'Campaign started successfully',
          data: campaign
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/campaigns')) {
      // Get user's campaigns
      const campaigns = await getUserCampaigns(userId, isAdmin)
      return new Response(
        JSON.stringify({ 
          success: true,
          data: campaigns 
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.includes('/campaigns/')) {
      // Get specific campaign status
      const pathParts = path.split('/')
      const campaignId = pathParts[pathParts.length - 1]
      
      if (!campaignId) {
        return new Response(
          JSON.stringify({ error: 'Campaign ID is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const status = await getCampaignStatus(campaignId, userId, isAdmin)
      
      return new Response(
        JSON.stringify({
          success: true,
          data: status
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'DELETE' && path.includes('/campaigns/')) {
      // Cancel campaign
      const pathParts = path.split('/')
      const campaignId = pathParts[pathParts.length - 1]
      
      if (!campaignId) {
        return new Response(
          JSON.stringify({ error: 'Campaign ID is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      await cancelCampaign(campaignId, userId, isAdmin)
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Campaign cancelled successfully'
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Default response for unmatched routes
    return new Response(
      JSON.stringify({ 
        error: 'Not found',
        availableEndpoints: [
          'POST /send - Create and send bulk notification',
          'GET /campaigns - Get user campaigns',
          'GET /campaigns/{id} - Get campaign status',
          'DELETE /campaigns/{id} - Cancel campaign'
        ]
      }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Bulk notification error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})