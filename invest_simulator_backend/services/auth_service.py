import os
import random
import string
from datetime import datetime, timedelta
from typing import Dict, Optional
import logging
from flask_jwt_extended import create_access_token
from twilio.rest import Client
from services.db_service import DatabaseService

logger = logging.getLogger(__name__)

class AuthService:
    def __init__(self):
        self.db_service = DatabaseService()
        
        # Twilio configuration
        self.twilio_account_sid = os.getenv('TWILIO_ACCOUNT_SID')
        self.twilio_auth_token = os.getenv('TWILIO_AUTH_TOKEN')
        self.twilio_phone_number = os.getenv('TWILIO_PHONE_NUMBER')
        
        # Initialize Twilio client if credentials are provided
        if self.twilio_account_sid and self.twilio_auth_token:
            self.twilio_client = Client(self.twilio_account_sid, self.twilio_auth_token)
        else:
            self.twilio_client = None
            logger.warning("Twilio credentials not configured. OTP will be logged instead of sent.")
        
        # OTP storage (in production, use Redis or database)
        self.otp_storage = {}
        self.otp_expiry = 300  # 5 minutes
    
    def generate_otp(self) -> str:
        """Generate a 6-digit OTP"""
        return ''.join(random.choices(string.digits, k=6))
    
    def send_otp(self, phone: str) -> Dict:
        """Send OTP to phone number"""
        try:
            # Clean phone number
            phone = self._clean_phone_number(phone)
            
            # Generate OTP
            otp = self.generate_otp()
            
            # Store OTP with expiry
            self.otp_storage[phone] = {
                'otp': otp,
                'created_at': datetime.now(),
                'expires_at': datetime.now() + timedelta(seconds=self.otp_expiry)
            }
            
            # Send OTP via SMS
            if self.twilio_client:
                try:
                    message = self.twilio_client.messages.create(
                        body=f"Your verification code is: {otp}. This code will expire in 5 minutes.",
                        from_=self.twilio_phone_number,
                        to=phone
                    )
                    logger.info(f"OTP sent to {phone}: {message.sid}")
                    
                    return {
                        'success': True,
                        'message': 'OTP sent successfully',
                        'expires_in': self.otp_expiry
                    }
                except Exception as e:
                    logger.error(f"Twilio error: {e}")
                    return {
                        'success': False,
                        'error': 'Failed to send SMS'
                    }
            else:
                # Development mode - log OTP
                logger.info(f"OTP for {phone}: {otp}")
                return {
                    'success': True,
                    'message': 'OTP sent successfully (check logs in development mode)',
                    'expires_in': self.otp_expiry,
                    'otp': otp  # Include OTP in response for development
                }
                
        except Exception as e:
            logger.error(f"Error sending OTP: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }
    
    def verify_otp(self, phone: str, otp: str, invite_code: str = None) -> Dict:
        """Verify OTP and create/login user"""
        try:
            # Clean phone number
            phone = self._clean_phone_number(phone)
            
            # Check if OTP exists and is valid
            if phone not in self.otp_storage:
                return {
                    'success': False,
                    'error': 'OTP not found or expired'
                }
            
            stored_otp = self.otp_storage[phone]
            
            # Check if OTP is expired
            if datetime.now() > stored_otp['expires_at']:
                del self.otp_storage[phone]
                return {
                    'success': False,
                    'error': 'OTP has expired'
                }
            
            # Verify OTP
            if stored_otp['otp'] != otp:
                return {
                    'success': False,
                    'error': 'Invalid OTP'
                }
            
            # OTP is valid, remove from storage
            del self.otp_storage[phone]
            
            # Check if user exists
            existing_user = self.db_service.get_user_by_phone(phone)
            
            if existing_user:
                # User exists, create JWT token
                access_token = create_access_token(identity=existing_user['id'])
                
                return {
                    'success': True,
                    'message': 'Login successful',
                    'access_token': access_token,
                    'user': {
                        'id': existing_user['id'],
                        'phone': existing_user['phone'],
                        'name': existing_user['name'],
                        'cash_balance': existing_user['cash_balance'],
                        'total_assets': existing_user['total_assets'],
                        'invite_code': existing_user['invite_code']
                    },
                    'is_new_user': False
                }
            else:
                # New user, create account
                user_result = self.db_service.create_user(phone, invite_code=invite_code)
                
                if user_result['success']:
                    user_data = user_result['user']
                    access_token = create_access_token(identity=user_data['id'])
                    
                    return {
                        'success': True,
                        'message': 'Registration successful',
                        'access_token': access_token,
                        'user': {
                            'id': user_data['id'],
                            'phone': user_data['phone'],
                            'name': user_data['name'],
                            'cash_balance': user_data['cash_balance'],
                            'total_assets': user_data['total_assets'],
                            'invite_code': user_data['invite_code']
                        },
                        'is_new_user': True,
                        'referral_bonus': user_result.get('referral_bonus', 0)
                    }
                else:
                    return {
                        'success': False,
                        'error': user_result.get('error', 'Failed to create user')
                    }
                    
        except Exception as e:
            logger.error(f"Error verifying OTP: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }
    
    def refresh_token(self, user_id: str) -> Dict:
        """Refresh JWT token"""
        try:
            # Verify user exists
            user = self.db_service.get_user_profile(user_id)
            
            if 'error' in user:
                return {
                    'success': False,
                    'error': 'User not found'
                }
            
            # Create new token
            access_token = create_access_token(identity=user_id)
            
            return {
                'success': True,
                'access_token': access_token,
                'user': user
            }
            
        except Exception as e:
            logger.error(f"Error refreshing token: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }
    
    def validate_invite_code(self, invite_code: str) -> Dict:
        """Validate invite code"""
        try:
            # Check if invite code exists
            result = self.db_service.supabase.table('users').select('id, name').eq('invite_code', invite_code).execute()
            
            if result.data:
                return {
                    'valid': True,
                    'inviter_name': result.data[0]['name']
                }
            else:
                return {
                    'valid': False,
                    'error': 'Invalid invite code'
                }
                
        except Exception as e:
            logger.error(f"Error validating invite code: {e}")
            return {
                'valid': False,
                'error': 'Internal server error'
            }
    
    def resend_otp(self, phone: str) -> Dict:
        """Resend OTP to phone number"""
        try:
            # Check if there's a recent OTP request
            phone = self._clean_phone_number(phone)
            
            if phone in self.otp_storage:
                stored_otp = self.otp_storage[phone]
                # Only allow resend if more than 60 seconds have passed
                if datetime.now() - stored_otp['created_at'] < timedelta(seconds=60):
                    return {
                        'success': False,
                        'error': 'Please wait before requesting another OTP'
                    }
            
            # Send new OTP
            return self.send_otp(phone)
            
        except Exception as e:
            logger.error(f"Error resending OTP: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }
    
    def _clean_phone_number(self, phone: str) -> str:
        """Clean and format phone number"""
        # Remove all non-digit characters
        clean_phone = ''.join(filter(str.isdigit, phone))
        
        # Add country code for Taiwan if not present
        if len(clean_phone) == 10 and clean_phone.startswith('09'):
            clean_phone = '886' + clean_phone[1:]
        elif len(clean_phone) == 9 and clean_phone.startswith('9'):
            clean_phone = '886' + clean_phone
        
        # Add + prefix for international format
        if not clean_phone.startswith('+'):
            clean_phone = '+' + clean_phone
        
        return clean_phone
    
    def get_user_by_token(self, user_id: str) -> Optional[Dict]:
        """Get user information by user ID from token"""
        try:
            return self.db_service.get_user_profile(user_id)
        except Exception as e:
            logger.error(f"Error getting user by token: {e}")
            return None
    
    def update_user_profile(self, user_id: str, data: Dict) -> Dict:
        """Update user profile"""
        try:
            # Only allow updating certain fields
            allowed_fields = ['name']
            update_data = {}
            
            for field in allowed_fields:
                if field in data:
                    update_data[field] = data[field]
            
            if not update_data:
                return {
                    'success': False,
                    'error': 'No valid fields to update'
                }
            
            update_data['updated_at'] = datetime.now().isoformat()
            
            # Update user
            result = self.db_service.supabase.table('users').update(update_data).eq('id', user_id).execute()
            
            if result.data:
                return {
                    'success': True,
                    'message': 'Profile updated successfully',
                    'user': result.data[0]
                }
            else:
                return {
                    'success': False,
                    'error': 'Failed to update profile'
                }
                
        except Exception as e:
            logger.error(f"Error updating profile: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }
    
    def delete_user(self, user_id: str) -> Dict:
        """Delete user account"""
        try:
            # Delete user's positions
            self.db_service.supabase.table('positions').delete().eq('user_id', user_id).execute()
            
            # Delete user's transactions
            self.db_service.supabase.table('transactions').delete().eq('user_id', user_id).execute()
            
            # Delete user's performance snapshots
            self.db_service.supabase.table('performance_snapshots').delete().eq('user_id', user_id).execute()
            
            # Delete user's referrals
            self.db_service.supabase.table('referrals').delete().eq('inviter_id', user_id).execute()
            self.db_service.supabase.table('referrals').delete().eq('invitee_id', user_id).execute()
            
            # Delete user
            result = self.db_service.supabase.table('users').delete().eq('id', user_id).execute()
            
            return {
                'success': True,
                'message': 'Account deleted successfully'
            }
            
        except Exception as e:
            logger.error(f"Error deleting user: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }