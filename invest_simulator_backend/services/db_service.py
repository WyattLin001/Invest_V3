import os
import psycopg2
from psycopg2.extras import RealDictCursor
from supabase import create_client, Client
from typing import Dict, List, Optional
import uuid
import hashlib
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class DatabaseService:
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        self.database_url = os.getenv('DATABASE_URL')
        
        # Initialize Supabase client
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        
        # Initial capital configuration
        self.initial_capital = float(os.getenv('INITIAL_CAPITAL', 1000000))
        self.referral_bonus = float(os.getenv('REFERRAL_BONUS', 100000))
    
    def get_db_connection(self):
        """Get direct PostgreSQL connection for complex queries"""
        return psycopg2.connect(
            self.database_url,
            cursor_factory=RealDictCursor
        )
    
    def create_user(self, phone: str, name: str = None, invite_code: str = None) -> Dict:
        """Create a new user account"""
        try:
            # Generate user ID and invite code
            user_id = str(uuid.uuid4())
            user_invite_code = self._generate_invite_code(user_id)
            
            # Set default name if not provided
            if not name:
                name = f"用戶{phone[-4:]}"
            
            # Initial cash balance
            cash_balance = self.initial_capital
            
            # Process referral if provided
            if invite_code:
                referral_result = self._process_referral_registration(invite_code)
                if referral_result['success']:
                    cash_balance += self.referral_bonus
            
            # Create user record
            user_data = {
                'id': user_id,
                'phone': phone,
                'name': name,
                'cash_balance': cash_balance,
                'total_assets': cash_balance,
                'total_profit': 0,
                'cumulative_return': 0,
                'invite_code': user_invite_code,
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
            
            result = self.supabase.table('trading_users').insert(user_data).execute()
            
            if result.data:
                # Create initial performance snapshot
                self._create_performance_snapshot(user_id, cash_balance)
                
                # Process referral bonus for inviter
                if invite_code:
                    self._award_referral_bonus(invite_code, user_id)
                
                return {
                    'success': True,
                    'user': result.data[0],
                    'referral_bonus': self.referral_bonus if invite_code else 0
                }
            
            return {'success': False, 'error': 'Failed to create user'}
            
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            return {'success': False, 'error': str(e)}
    
    def get_user_by_phone(self, phone: str) -> Optional[Dict]:
        """Get user by phone number"""
        try:
            result = self.supabase.table('trading_users').select('*').eq('phone', phone).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting user by phone: {e}")
            return None
    
    def get_user_profile(self, user_id: str) -> Dict:
        """Get user profile with calculated totals"""
        try:
            user = self.supabase.table('trading_users').select('*').eq('id', user_id).execute()
            if not user.data:
                return {'error': 'User not found'}
            
            user_data = user.data[0]
            
            # Calculate current total assets
            portfolio = self.get_user_portfolio(user_id)
            total_assets = user_data['cash_balance'] + portfolio.get('total_market_value', 0)
            
            # Calculate return rate
            return_rate = ((total_assets - self.initial_capital) / self.initial_capital) * 100
            
            # Update user record with current totals
            self.supabase.table('trading_users').update({
                'total_assets': total_assets,
                'cumulative_return': return_rate,
                'updated_at': datetime.now().isoformat()
            }).eq('id', user_id).execute()
            
            return {
                'id': user_data['id'],
                'phone': user_data['phone'],
                'name': user_data['name'],
                'cash_balance': user_data['cash_balance'],
                'total_assets': total_assets,
                'total_profit': user_data['total_profit'],
                'cumulative_return': return_rate,
                'invite_code': user_data['invite_code'],
                'created_at': user_data['created_at']
            }
            
        except Exception as e:
            logger.error(f"Error getting user profile: {e}")
            return {'error': str(e)}
    
    def update_user_balance(self, user_id: str, amount: float) -> bool:
        """Update user cash balance"""
        try:
            result = self.supabase.table('trading_users').update({
                'cash_balance': amount,
                'updated_at': datetime.now().isoformat()
            }).eq('id', user_id).execute()
            
            return bool(result.data)
        except Exception as e:
            logger.error(f"Error updating user balance: {e}")
            return False
    
    def get_user_portfolio(self, user_id: str) -> Dict:
        """Get user's current portfolio"""
        try:
            # Get all positions
            positions = self.supabase.table('trading_positions').select('*').eq('user_id', user_id).execute()
            
            if not positions.data:
                return {
                    'positions': [],
                    'total_market_value': 0,
                    'total_cost': 0,
                    'unrealized_pnl': 0
                }
            
            # Import market service for current prices
            from services.market_data_service import MarketDataService
            market_service = MarketDataService()
            
            portfolio_positions = []
            total_market_value = 0
            total_cost = 0
            
            for position in positions.data:
                # Get current price
                quote = market_service.get_realtime_price(position['symbol'])
                current_price = quote.get('price', position['average_cost'])
                
                # Calculate values
                market_value = current_price * position['quantity']
                cost_value = position['average_cost'] * position['quantity']
                unrealized_pnl = market_value - cost_value
                unrealized_pnl_percent = (unrealized_pnl / cost_value) * 100 if cost_value > 0 else 0
                
                portfolio_positions.append({
                    'symbol': position['symbol'],
                    'quantity': position['quantity'],
                    'average_cost': position['average_cost'],
                    'current_price': current_price,
                    'market_value': market_value,
                    'cost_value': cost_value,
                    'unrealized_pnl': unrealized_pnl,
                    'unrealized_pnl_percent': unrealized_pnl_percent,
                    'market': position.get('market', 'TW')
                })
                
                total_market_value += market_value
                total_cost += cost_value
            
            return {
                'positions': portfolio_positions,
                'total_market_value': total_market_value,
                'total_cost': total_cost,
                'unrealized_pnl': total_market_value - total_cost
            }
            
        except Exception as e:
            logger.error(f"Error getting portfolio: {e}")
            return {'error': str(e)}
    
    def create_position(self, user_id: str, symbol: str, quantity: int, price: float, market: str = 'TW') -> bool:
        """Create a new position"""
        try:
            position_data = {
                'user_id': user_id,
                'symbol': symbol,
                'quantity': quantity,
                'average_cost': price,
                'market': market,
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
            
            result = self.supabase.table('trading_positions').insert(position_data).execute()
            return bool(result.data)
            
        except Exception as e:
            logger.error(f"Error creating position: {e}")
            return False
    
    def update_position(self, user_id: str, symbol: str, quantity: int, price: float) -> bool:
        """Update existing position with new purchase"""
        try:
            # Get current position
            current = self.supabase.table('trading_positions').select('*').eq('user_id', user_id).eq('symbol', symbol).execute()
            
            if not current.data:
                return False
            
            position = current.data[0]
            
            # Calculate new average cost
            old_quantity = position['quantity']
            old_cost = position['average_cost']
            
            new_quantity = old_quantity + quantity
            new_average_cost = ((old_cost * old_quantity) + (price * quantity)) / new_quantity
            
            # Update position
            result = self.supabase.table('trading_positions').update({
                'quantity': new_quantity,
                'average_cost': new_average_cost,
                'updated_at': datetime.now().isoformat()
            }).eq('user_id', user_id).eq('symbol', symbol).execute()
            
            return bool(result.data)
            
        except Exception as e:
            logger.error(f"Error updating position: {e}")
            return False
    
    def reduce_position(self, user_id: str, symbol: str, quantity: int) -> bool:
        """Reduce position quantity (for selling)"""
        try:
            # Get current position
            current = self.supabase.table('trading_positions').select('*').eq('user_id', user_id).eq('symbol', symbol).execute()
            
            if not current.data:
                return False
            
            position = current.data[0]
            new_quantity = position['quantity'] - quantity
            
            if new_quantity <= 0:
                # Remove position entirely
                result = self.supabase.table('trading_positions').delete().eq('user_id', user_id).eq('symbol', symbol).execute()
            else:
                # Update quantity
                result = self.supabase.table('trading_positions').update({
                    'quantity': new_quantity,
                    'updated_at': datetime.now().isoformat()
                }).eq('user_id', user_id).eq('symbol', symbol).execute()
            
            return True
            
        except Exception as e:
            logger.error(f"Error reducing position: {e}")
            return False
    
    def log_transaction(self, user_id: str, symbol: str, action: str, quantity: int, price: float, 
                       fee: float, tax: float = 0, realized_pnl: float = 0) -> bool:
        """Log a transaction"""
        try:
            transaction_data = {
                'user_id': user_id,
                'symbol': symbol,
                'action': action,
                'quantity': quantity,
                'price': price,
                'fee': fee,
                'tax': tax,
                'realized_pnl': realized_pnl,
                'transaction_time': datetime.now().isoformat()
            }
            
            result = self.supabase.table('trading_transactions').insert(transaction_data).execute()
            return bool(result.data)
            
        except Exception as e:
            logger.error(f"Error logging transaction: {e}")
            return False
    
    def get_user_transactions(self, user_id: str, limit: int = 50, offset: int = 0) -> List[Dict]:
        """Get user's transaction history"""
        try:
            result = self.supabase.table('trading_transactions').select('*').eq('user_id', user_id).order('transaction_time', desc=True).limit(limit).offset(offset).execute()
            return result.data
        except Exception as e:
            logger.error(f"Error getting transactions: {e}")
            return []
    
    def get_position(self, user_id: str, symbol: str) -> Optional[Dict]:
        """Get specific position"""
        try:
            result = self.supabase.table('positions').select('*').eq('user_id', user_id).eq('symbol', symbol).execute()
            return result.data[0] if result.data else None
        except Exception as e:
            logger.error(f"Error getting position: {e}")
            return None
    
    def _generate_invite_code(self, user_id: str) -> str:
        """Generate invite code for user"""
        hash_object = hashlib.md5(user_id.encode())
        return hash_object.hexdigest()[:8].upper()
    
    def _process_referral_registration(self, invite_code: str) -> Dict:
        """Process referral during registration"""
        try:
            # Find inviter
            inviter = self.supabase.table('trading_users').select('*').eq('invite_code', invite_code).execute()
            
            if not inviter.data:
                return {'success': False, 'error': 'Invalid invite code'}
            
            return {'success': True, 'inviter_id': inviter.data[0]['id']}
            
        except Exception as e:
            logger.error(f"Error processing referral: {e}")
            return {'success': False, 'error': str(e)}
    
    def _award_referral_bonus(self, invite_code: str, new_user_id: str) -> bool:
        """Award referral bonus to inviter"""
        try:
            # Get inviter
            inviter = self.supabase.table('trading_users').select('*').eq('invite_code', invite_code).execute()
            
            if not inviter.data:
                return False
            
            inviter_data = inviter.data[0]
            
            # Update inviter's balance
            new_balance = inviter_data['cash_balance'] + self.referral_bonus
            self.supabase.table('trading_users').update({
                'cash_balance': new_balance,
                'updated_at': datetime.now().isoformat()
            }).eq('id', inviter_data['id']).execute()
            
            # Log referral transaction for both users
            self.log_transaction(
                inviter_data['id'], 'REFERRAL', 'referral_bonus', 
                1, self.referral_bonus, 0, 0, self.referral_bonus
            )
            
            self.log_transaction(
                new_user_id, 'REFERRAL', 'referral_bonus', 
                1, self.referral_bonus, 0, 0, self.referral_bonus
            )
            
            # Record referral relationship
            referral_data = {
                'inviter_id': inviter_data['id'],
                'invitee_id': new_user_id,
                'bonus_awarded': True,
                'created_at': datetime.now().isoformat()
            }
            
            self.supabase.table('trading_referrals').insert(referral_data).execute()
            
            return True
            
        except Exception as e:
            logger.error(f"Error awarding referral bonus: {e}")
            return False
    
    def _create_performance_snapshot(self, user_id: str, total_assets: float) -> bool:
        """Create performance snapshot"""
        try:
            snapshot_data = {
                'user_id': user_id,
                'date': datetime.now().date().isoformat(),
                'total_assets': total_assets,
                'return_rate': 0,
                'created_at': datetime.now().isoformat()
            }
            
            result = self.supabase.table('trading_performance_snapshots').insert(snapshot_data).execute()
            return bool(result.data)
            
        except Exception as e:
            logger.error(f"Error creating performance snapshot: {e}")
            return False
    
    def get_rankings(self, period: str = 'all', limit: int = 10) -> Dict:
        """Get user rankings for specified period"""
        try:
            # 從 trading_users 表格獲取排名資料
            result = self.supabase.table('trading_users').select(
                'id, name, cumulative_return, total_assets, total_profit, avatar_url, created_at'
            ).eq('is_active', True).order('cumulative_return', desc=True).limit(limit).execute()
            
            if not result.data:
                # 如果沒有資料，自動初始化測試資料
                init_result = self.initialize_test_trading_data()
                if init_result['success']:
                    # 重新查詢資料
                    result = self.supabase.table('trading_users').select(
                        'id, name, cumulative_return, total_assets, total_profit, avatar_url, created_at'
                    ).eq('is_active', True).order('cumulative_return', desc=True).limit(limit).execute()
                else:
                    return {
                        'success': False,
                        'error': '無法初始化測試資料',
                        'rankings': [],
                        'period': period
                    }
            
            # 轉換資料格式
            rankings = []
            for i, user in enumerate(result.data):
                rankings.append({
                    'rank': i + 1,
                    'userId': user['id'],
                    'name': user['name'],
                    'returnRate': user['cumulative_return'],
                    'totalAssets': user['total_assets'], 
                    'totalProfit': user['total_profit'],
                    'avatarUrl': user.get('avatar_url'),
                    'period': period
                })
            
            return {
                'success': True,
                'period': period,
                'rankings': rankings,
                'totalUsers': len(rankings),
                'message': 'Rankings loaded successfully'
            }
            
        except Exception as e:
            logger.error(f"Error getting rankings: {e}")
            return {
                'success': False,
                'error': str(e),
                'rankings': [],
                'period': period
            }
    
    def get_user_performance(self, user_id: str) -> Dict:
        """Get user performance metrics"""
        try:
            user_profile = self.get_user_profile(user_id)
            transactions = self.get_user_transactions(user_id, limit=100)
            
            # Calculate performance metrics
            total_trades = len(transactions)
            profitable_trades = len([t for t in transactions if t['realized_pnl'] > 0])
            win_rate = (profitable_trades / total_trades * 100) if total_trades > 0 else 0
            
            return {
                'total_assets': user_profile.get('total_assets', 0),
                'total_profit': user_profile.get('total_profit', 0),
                'cumulative_return': user_profile.get('cumulative_return', 0),
                'total_trades': total_trades,
                'win_rate': win_rate,
                'profitable_trades': profitable_trades
            }
            
        except Exception as e:
            logger.error(f"Error getting user performance: {e}")
            return {'error': str(e)}
    
    def process_referral(self, user_id: str, invite_code: str) -> Dict:
        """Process referral code submission"""
        try:
            # Check if user already used a referral code
            existing = self.supabase.table('trading_referrals').select('*').eq('invitee_id', user_id).execute()
            
            if existing.data:
                return {'success': False, 'error': 'You have already used a referral code'}
            
            # Process referral
            result = self._process_referral_registration(invite_code)
            
            if result['success']:
                # Award bonus to both users
                self._award_referral_bonus(invite_code, user_id)
                
                # Update user's balance
                user = self.supabase.table('trading_users').select('*').eq('id', user_id).execute()
                if user.data:
                    new_balance = user.data[0]['cash_balance'] + self.referral_bonus
                    self.update_user_balance(user_id, new_balance)
                
                return {
                    'success': True,
                    'bonus_amount': self.referral_bonus,
                    'message': f'Referral bonus of ${self.referral_bonus:,.0f} has been added to your account'
                }
            
            return result
            
        except Exception as e:
            logger.error(f"Error processing referral: {e}")
            return {'success': False, 'error': str(e)}
    
    def clear_all_trading_test_data(self) -> Dict:
        """清除所有交易測試資料"""
        try:
            # 清除 trading_performance_snapshots
            self.supabase.table('trading_performance_snapshots').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
            
            # 清除 trading_leaderboard  
            self.supabase.table('trading_leaderboard').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
            
            # 清除 trading_users (除了有真實用戶 ID 的)
            self.supabase.table('trading_users').delete().like('id', 'test%').execute()
            
            logger.info("✅ 已清除所有交易測試資料")
            return {'success': True, 'message': '成功清除所有測試資料'}
            
        except Exception as e:
            logger.error(f"❌ 清除測試資料失敗: {e}")
            return {'success': False, 'error': str(e)}
    
    def create_test_trading_users(self) -> Dict:
        """創建標準化的測試交易用戶"""
        try:
            test_users = [
                {
                    'id': 'test_user_001',
                    'name': 'test王',
                    'phone': '+886900000001', 
                    'email': 'test.wang@example.com',
                    'cumulative_return': 25.8,
                    'total_assets': 1258000,
                    'total_profit': 258000,
                    'cash_balance': 300000,
                    'is_active': True,
                    'created_at': datetime.now().isoformat()
                },
                {
                    'id': 'test_user_002',
                    'name': 'test徐',
                    'phone': '+886900000002',
                    'email': 'test.xu@example.com', 
                    'cumulative_return': 22.3,
                    'total_assets': 1223000,
                    'total_profit': 223000,
                    'cash_balance': 280000,
                    'is_active': True,
                    'created_at': datetime.now().isoformat()
                },
                {
                    'id': 'test_user_003',
                    'name': 'test張',
                    'phone': '+886900000003',
                    'email': 'test.zhang@example.com',
                    'cumulative_return': 19.7,
                    'total_assets': 1197000,
                    'total_profit': 197000,
                    'cash_balance': 250000,
                    'is_active': True,
                    'created_at': datetime.now().isoformat()
                },
                {
                    'id': 'test_user_004',
                    'name': 'test林',
                    'phone': '+886900000004',
                    'email': 'test.lin@example.com',
                    'cumulative_return': 17.2,
                    'total_assets': 1172000,
                    'total_profit': 172000,
                    'cash_balance': 220000,
                    'is_active': True,
                    'created_at': datetime.now().isoformat()
                },
                {
                    'id': 'test_user_005',
                    'name': 'test黃',
                    'phone': '+886900000005',
                    'email': 'test.huang@example.com',
                    'cumulative_return': 15.6,
                    'total_assets': 1156000,
                    'total_profit': 156000,
                    'cash_balance': 200000,
                    'is_active': True,
                    'created_at': datetime.now().isoformat()
                }
            ]
            
            # 插入測試用戶
            result = self.supabase.table('trading_users').upsert(test_users).execute()
            
            # 為每個用戶創建績效快照
            for user in test_users:
                self._create_performance_snapshots(user)
            
            logger.info(f"✅ 成功創建 {len(test_users)} 個測試交易用戶")
            return {
                'success': True, 
                'message': f'成功創建 {len(test_users)} 個測試用戶',
                'users_created': len(test_users)
            }
            
        except Exception as e:
            logger.error(f"❌ 創建測試用戶失敗: {e}")
            return {'success': False, 'error': str(e)}
    
    def _create_performance_snapshots(self, user_data: Dict):
        """為用戶創建30天的績效快照資料"""
        try:
            snapshots = []
            base_return = user_data['cumulative_return']
            
            # 創建過去30天的資料
            for i in range(30, 0, -1):
                snapshot_date = (datetime.now() - timedelta(days=i)).date()
                
                # 模擬漸進式的回報率增長
                daily_return = base_return * (30 - i + 1) / 30
                daily_assets = 1000000 + (daily_return / 100 * 1000000)
                daily_profit = daily_assets - 1000000
                
                snapshots.append({
                    'user_id': user_data['id'],
                    'snapshot_date': snapshot_date.isoformat(),
                    'total_assets': daily_assets,
                    'total_profit': daily_profit,
                    'cumulative_return': daily_return,
                    'cash_balance': user_data['cash_balance'],
                    'created_at': datetime.now().isoformat()
                })
            
            # 插入績效快照
            self.supabase.table('trading_performance_snapshots').upsert(snapshots).execute()
            logger.info(f"✅ 為用戶 {user_data['name']} 創建了 {len(snapshots)} 天的績效資料")
            
        except Exception as e:
            logger.error(f"❌ 創建績效快照失敗: {e}")
    
    def initialize_test_trading_data(self) -> Dict:
        """完整初始化測試交易資料 - 清除舊資料並創建新資料"""
        try:
            # 1. 清除所有舊的測試資料
            clear_result = self.clear_all_trading_test_data()
            if not clear_result['success']:
                return clear_result
            
            # 2. 創建新的測試用戶
            create_result = self.create_test_trading_users()
            if not create_result['success']:
                return create_result
            
            logger.info("🎉 排名系統測試資料初始化完成！")
            return {
                'success': True,
                'message': '排名系統測試資料初始化完成！已創建5個標準測試用戶',
                'details': {
                    'users_created': 5,
                    'snapshots_created': 150,  # 5 users × 30 days
                    'test_users': [
                        'test王 (25.8%)', 'test徐 (22.3%)', 'test張 (19.7%)', 
                        'test林 (17.2%)', 'test黃 (15.6%)'
                    ]
                }
            }
            
        except Exception as e:
            logger.error(f"❌ 初始化測試資料失敗: {e}")
            return {'success': False, 'error': str(e)}