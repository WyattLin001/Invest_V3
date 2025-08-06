/**
 * Register Device Token Edge Function
 * 
 * Handles registration, updating, and management of device tokens for push notifications.
 * Includes automatic cleanup of old/invalid tokens and device metadata management.
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'supabase'

// Types and Interfaces
interface RegisterTokenRequest {
  deviceToken: string
  deviceType: 'ios' | 'android' | 'web'
  appVersion?: string
  osVersion?: string
  deviceModel?: string
  environment?: 'sandbox' | 'production'
}

interface UpdateTokenRequest {
  deviceToken: string
  isActive?: boolean
  deviceType?: 'ios' | 'android' | 'web'
  appVersion?: string
  osVersion?: string
  deviceModel?: string
}

interface DeviceTokenResponse {
  id: string
  deviceToken: string
  deviceType: string
  environment: string
  isActive: boolean
  lastUsedAt: string
  createdAt: string
  updatedAt: string
}

// Configuration
const DEFAULT_ENVIRONMENT = (Deno.env.get('APNS_ENVIRONMENT') || 'sandbox') as 'sandbox' | 'production'

// Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Validate device token format
function validateDeviceToken(token: string, deviceType: string): boolean {
  if (!token || typeof token !== 'string') {
    return false
  }

  switch (deviceType) {
    case 'ios':
      // APNs device tokens are 64 characters hex string (32 bytes)
      return /^[a-fA-F0-9]{64}$/.test(token)
    case 'android':
      // FCM tokens are variable length but typically longer
      return token.length > 20 && token.length < 200
    case 'web':
      // Web push tokens are typically much longer
      return token.length > 20
    default:
      return false
  }
}

// Get authenticated user ID
function getAuthenticatedUserId(req: Request): string | null {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return null

  try {
    // Extract JWT token from Authorization header
    const token = authHeader.replace('Bearer ', '')
    
    // Decode JWT (basic decode, not verifying signature as Supabase handles that)
    const parts = token.split('.')
    if (parts.length !== 3) return null
    
    const payload = JSON.parse(atob(parts[1]))
    return payload.sub || null
  } catch {
    return null
  }
}

// Register or update device token
async function registerDeviceToken(
  userId: string, 
  request: RegisterTokenRequest
): Promise<DeviceTokenResponse> {
  const {
    deviceToken,
    deviceType,
    appVersion,
    osVersion,
    deviceModel,
    environment = DEFAULT_ENVIRONMENT
  } = request

  // Validate device token
  if (!validateDeviceToken(deviceToken, deviceType)) {
    throw new Error(`Invalid device token format for ${deviceType}`)
  }

  const now = new Date().toISOString()

  // First, try to update existing token
  const { data: existingTokens, error: findError } = await supabase
    .from('device_tokens')
    .select('id, is_active')
    .eq('user_id', userId)
    .eq('device_token', deviceToken)

  if (findError) {
    throw new Error(`Failed to check existing tokens: ${findError.message}`)
  }

  if (existingTokens && existingTokens.length > 0) {
    // Update existing token
    const { data, error } = await supabase
      .from('device_tokens')
      .update({
        device_type: deviceType,
        app_version: appVersion,
        os_version: osVersion,
        device_model: deviceModel,
        environment,
        is_active: true,
        last_used_at: now,
        updated_at: now
      })
      .eq('id', existingTokens[0].id)
      .select()
      .single()

    if (error) {
      throw new Error(`Failed to update device token: ${error.message}`)
    }

    return {
      id: data.id,
      deviceToken: data.device_token,
      deviceType: data.device_type,
      environment: data.environment,
      isActive: data.is_active,
      lastUsedAt: data.last_used_at,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    }
  } else {
    // Insert new token
    const { data, error } = await supabase
      .from('device_tokens')
      .insert({
        user_id: userId,
        device_token: deviceToken,
        device_type: deviceType,
        app_version: appVersion,
        os_version: osVersion,
        device_model: deviceModel,
        environment,
        is_active: true,
        last_used_at: now
      })
      .select()
      .single()

    if (error) {
      throw new Error(`Failed to register device token: ${error.message}`)
    }

    return {
      id: data.id,
      deviceToken: data.device_token,
      deviceType: data.device_type,
      environment: data.environment,
      isActive: data.is_active,
      lastUsedAt: data.last_used_at,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    }
  }
}

// Update device token
async function updateDeviceToken(
  userId: string,
  tokenId: string,
  request: UpdateTokenRequest
): Promise<DeviceTokenResponse> {
  const updates: any = {
    updated_at: new Date().toISOString()
  }

  if (request.deviceToken) {
    if (!validateDeviceToken(request.deviceToken, request.deviceType || 'ios')) {
      throw new Error('Invalid device token format')
    }
    updates.device_token = request.deviceToken
  }

  if (request.isActive !== undefined) {
    updates.is_active = request.isActive
  }

  if (request.deviceType) {
    updates.device_type = request.deviceType
  }

  if (request.appVersion) {
    updates.app_version = request.appVersion
  }

  if (request.osVersion) {
    updates.os_version = request.osVersion
  }

  if (request.deviceModel) {
    updates.device_model = request.deviceModel
  }

  // Update last used time if activating
  if (request.isActive === true) {
    updates.last_used_at = new Date().toISOString()
  }

  const { data, error } = await supabase
    .from('device_tokens')
    .update(updates)
    .eq('id', tokenId)
    .eq('user_id', userId)
    .select()
    .single()

  if (error) {
    throw new Error(`Failed to update device token: ${error.message}`)
  }

  return {
    id: data.id,
    deviceToken: data.device_token,
    deviceType: data.device_type,
    environment: data.environment,
    isActive: data.is_active,
    lastUsedAt: data.last_used_at,
    createdAt: data.created_at,
    updatedAt: data.updated_at
  }
}

// Get user's device tokens
async function getUserDeviceTokens(userId: string): Promise<DeviceTokenResponse[]> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('*')
    .eq('user_id', userId)
    .order('last_used_at', { ascending: false })

  if (error) {
    throw new Error(`Failed to get device tokens: ${error.message}`)
  }

  return (data || []).map(token => ({
    id: token.id,
    deviceToken: token.device_token,
    deviceType: token.device_type,
    environment: token.environment,
    isActive: token.is_active,
    lastUsedAt: token.last_used_at,
    createdAt: token.created_at,
    updatedAt: token.updated_at
  }))
}

// Delete device token
async function deleteDeviceToken(userId: string, tokenId: string): Promise<void> {
  const { error } = await supabase
    .from('device_tokens')
    .delete()
    .eq('id', tokenId)
    .eq('user_id', userId)

  if (error) {
    throw new Error(`Failed to delete device token: ${error.message}`)
  }
}

// Cleanup old device tokens
async function cleanupOldDeviceTokens(userId: string, daysOld: number = 90): Promise<number> {
  const cutoffDate = new Date()
  cutoffDate.setDate(cutoffDate.getDate() - daysOld)

  const { data, error } = await supabase
    .from('device_tokens')
    .delete()
    .eq('user_id', userId)
    .lt('last_used_at', cutoffDate.toISOString())
    .select('id')

  if (error) {
    throw new Error(`Failed to cleanup old device tokens: ${error.message}`)
  }

  return data?.length || 0
}

// Test device token validity (for debugging)
async function testDeviceToken(userId: string, tokenId: string): Promise<{
  valid: boolean
  lastUsed: string
  environment: string
  errors?: string[]
}> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('*')
    .eq('id', tokenId)
    .eq('user_id', userId)
    .single()

  if (error || !data) {
    return {
      valid: false,
      lastUsed: '',
      environment: '',
      errors: ['Device token not found']
    }
  }

  const errors: string[] = []
  
  // Check if token is active
  if (!data.is_active) {
    errors.push('Device token is inactive')
  }

  // Check if token was used recently (within 30 days)
  const lastUsed = new Date(data.last_used_at)
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
  
  if (lastUsed < thirtyDaysAgo) {
    errors.push('Device token has not been used recently')
  }

  // Validate token format
  if (!validateDeviceToken(data.device_token, data.device_type)) {
    errors.push('Device token format is invalid')
  }

  return {
    valid: errors.length === 0,
    lastUsed: data.last_used_at,
    environment: data.environment,
    errors: errors.length > 0 ? errors : undefined
  }
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
    if (method === 'POST' && path.endsWith('/register')) {
      // Register new device token
      const request: RegisterTokenRequest = await req.json()
      
      if (!request.deviceToken || !request.deviceType) {
        return new Response(
          JSON.stringify({ error: 'deviceToken and deviceType are required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const result = await registerDeviceToken(userId, request)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Device token registered successfully',
          data: result
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.endsWith('/tokens')) {
      // Get user's device tokens
      const tokens = await getUserDeviceTokens(userId)
      return new Response(
        JSON.stringify({ 
          success: true,
          data: tokens 
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'PUT' && path.includes('/tokens/')) {
      // Update specific device token
      const pathParts = path.split('/')
      const tokenId = pathParts[pathParts.length - 1]
      
      if (!tokenId) {
        return new Response(
          JSON.stringify({ error: 'Token ID is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const request: UpdateTokenRequest = await req.json()
      const result = await updateDeviceToken(userId, tokenId, request)
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Device token updated successfully',
          data: result
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'DELETE' && path.includes('/tokens/')) {
      // Delete specific device token
      const pathParts = path.split('/')
      const tokenId = pathParts[pathParts.length - 1]
      
      if (!tokenId) {
        return new Response(
          JSON.stringify({ error: 'Token ID is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      await deleteDeviceToken(userId, tokenId)
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Device token deleted successfully'
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'POST' && path.endsWith('/cleanup')) {
      // Cleanup old device tokens
      const daysOld = parseInt(url.searchParams.get('days') || '90')
      const deletedCount = await cleanupOldDeviceTokens(userId, daysOld)
      
      return new Response(
        JSON.stringify({
          success: true,
          message: `Cleaned up ${deletedCount} old device tokens`,
          deletedCount
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (method === 'GET' && path.includes('/tokens/') && path.endsWith('/test')) {
      // Test device token validity
      const pathParts = path.split('/')
      const tokenId = pathParts[pathParts.indexOf('tokens') + 1]
      
      if (!tokenId) {
        return new Response(
          JSON.stringify({ error: 'Token ID is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const result = await testDeviceToken(userId, tokenId)
      
      return new Response(
        JSON.stringify({
          success: true,
          data: result
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Default response for unmatched routes
    return new Response(
      JSON.stringify({ 
        error: 'Not found',
        availableEndpoints: [
          'POST /register - Register device token',
          'GET /tokens - Get user device tokens',
          'PUT /tokens/{id} - Update device token',
          'DELETE /tokens/{id} - Delete device token',
          'POST /cleanup - Cleanup old tokens',
          'GET /tokens/{id}/test - Test token validity'
        ]
      }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Device token management error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})