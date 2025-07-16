import os
from typing import Dict, Optional
from datetime import datetime
import logging
from services.db_service import DatabaseService
from services.market_data_service import MarketDataService

logger = logging.getLogger(__name__)

class TradingService:
    def __init__(self):
        self.db_service = DatabaseService()
        self.market_service = MarketDataService()
        
        # Trading configuration
        self.broker_fee_rate = float(os.getenv('BROKER_FEE_RATE', 0.001425))
        self.tax_rate = float(os.getenv('TAX_RATE', 0.003))
        self.min_fee = 20  # Minimum broker fee in TWD
        
        # Trading limits
        self.max_quantity_per_trade = 1000  # Maximum shares per trade
        self.min_quantity_per_trade = 1000   # Minimum shares per trade (1 lot)
    
    def execute_trade(self, user_id: str, trade_data: Dict) -> Dict:
        """Execute a trade order"""
        try:
            # Validate trade data
            validation_result = self._validate_trade_data(trade_data)
            if not validation_result['valid']:
                return {
                    'success': False,
                    'error': validation_result['error']
                }
            
            symbol = trade_data['symbol']
            action = trade_data['action'].lower()
            quantity = int(trade_data['quantity'])
            price_type = trade_data.get('price_type', 'market')
            limit_price = trade_data.get('price', 0)
            
            # Get current market price
            quote = self.market_service.get_realtime_price(symbol)
            if 'error' in quote:
                return {
                    'success': False,
                    'error': f'Failed to get market price: {quote["error"]}'
                }
            
            market_price = quote['price']
            
            # Determine execution price
            if price_type == 'market':
                execution_price = market_price
            elif price_type == 'limit':
                if not limit_price:
                    return {
                        'success': False,
                        'error': 'Limit price is required for limit orders'
                    }
                
                # Check if limit order can be executed
                if action == 'buy' and market_price > limit_price:
                    return {
                        'success': False,
                        'error': 'Limit price too low for buy order'
                    }
                elif action == 'sell' and market_price < limit_price:
                    return {
                        'success': False,
                        'error': 'Limit price too high for sell order'
                    }
                
                execution_price = limit_price
            else:
                return {
                    'success': False,
                    'error': 'Invalid price type'
                }
            
            # Execute trade based on action
            if action == 'buy':
                return self._execute_buy(user_id, symbol, quantity, execution_price)
            elif action == 'sell':
                return self._execute_sell(user_id, symbol, quantity, execution_price)
            else:
                return {
                    'success': False,
                    'error': 'Invalid action'
                }
                
        except Exception as e:
            logger.error(f"Error executing trade: {e}")
            return {
                'success': False,
                'error': 'Internal server error'
            }
    
    def _execute_buy(self, user_id: str, symbol: str, quantity: int, price: float) -> Dict:
        """Execute a buy order"""
        try:
            # Calculate trade amount
            trade_amount = price * quantity
            
            # Calculate fees
            broker_fee = max(trade_amount * self.broker_fee_rate, self.min_fee)
            total_cost = trade_amount + broker_fee
            
            # Check user's cash balance
            user_profile = self.db_service.get_user_profile(user_id)
            if 'error' in user_profile:
                return {
                    'success': False,
                    'error': 'User not found'
                }
            
            current_cash = user_profile['cash_balance']
            
            if current_cash < total_cost:
                return {
                    'success': False,
                    'error': f'Insufficient funds. Required: ${total_cost:,.2f}, Available: ${current_cash:,.2f}'
                }
            
            # Update user's cash balance
            new_cash_balance = current_cash - total_cost
            
            if not self.db_service.update_user_balance(user_id, new_cash_balance):
                return {
                    'success': False,
                    'error': 'Failed to update cash balance'
                }
            
            # Update or create position
            existing_position = self.db_service.get_position(user_id, symbol)
            
            if existing_position:
                # Update existing position
                if not self.db_service.update_position(user_id, symbol, quantity, price):
                    # Rollback cash balance
                    self.db_service.update_user_balance(user_id, current_cash)
                    return {
                        'success': False,
                        'error': 'Failed to update position'
                    }
            else:
                # Create new position
                if not self.db_service.create_position(user_id, symbol, quantity, price):
                    # Rollback cash balance
                    self.db_service.update_user_balance(user_id, current_cash)
                    return {
                        'success': False,
                        'error': 'Failed to create position'
                    }
            
            # Log transaction
            if not self.db_service.log_transaction(
                user_id, symbol, 'buy', quantity, price, 
                broker_fee, 0, 0  # No tax or realized PnL for buy
            ):
                logger.warning(f"Failed to log buy transaction for user {user_id}")
            
            return {
                'success': True,
                'message': 'Buy order executed successfully',
                'trade_details': {
                    'symbol': symbol,
                    'action': 'buy',
                    'quantity': quantity,
                    'price': price,
                    'trade_amount': trade_amount,
                    'broker_fee': broker_fee,
                    'total_cost': total_cost,
                    'remaining_cash': new_cash_balance
                }
            }
            
        except Exception as e:
            logger.error(f"Error executing buy order: {e}")
            return {
                'success': False,
                'error': 'Failed to execute buy order'
            }
    
    def _execute_sell(self, user_id: str, symbol: str, quantity: int, price: float) -> Dict:
        """Execute a sell order"""
        try:
            # Check if user has sufficient position
            existing_position = self.db_service.get_position(user_id, symbol)
            
            if not existing_position:
                return {
                    'success': False,
                    'error': f'No position found for {symbol}'
                }
            
            available_quantity = existing_position['quantity']
            
            if available_quantity < quantity:
                return {
                    'success': False,
                    'error': f'Insufficient shares. Available: {available_quantity}, Requested: {quantity}'
                }
            
            # Calculate trade amount
            trade_amount = price * quantity
            
            # Calculate fees and taxes
            broker_fee = max(trade_amount * self.broker_fee_rate, self.min_fee)
            transaction_tax = trade_amount * self.tax_rate
            total_fees = broker_fee + transaction_tax
            
            # Calculate realized PnL
            average_cost = existing_position['average_cost']
            cost_basis = average_cost * quantity
            realized_pnl = trade_amount - cost_basis - total_fees
            
            # Calculate net proceeds
            net_proceeds = trade_amount - total_fees
            
            # Update user's cash balance
            user_profile = self.db_service.get_user_profile(user_id)
            if 'error' in user_profile:
                return {
                    'success': False,
                    'error': 'User not found'
                }
            
            current_cash = user_profile['cash_balance']
            new_cash_balance = current_cash + net_proceeds
            
            if not self.db_service.update_user_balance(user_id, new_cash_balance):
                return {
                    'success': False,
                    'error': 'Failed to update cash balance'
                }
            
            # Update position
            if not self.db_service.reduce_position(user_id, symbol, quantity):
                # Rollback cash balance
                self.db_service.update_user_balance(user_id, current_cash)
                return {
                    'success': False,
                    'error': 'Failed to update position'
                }
            
            # Update user's total profit
            try:
                current_profit = user_profile.get('total_profit', 0)
                new_total_profit = current_profit + realized_pnl
                
                self.db_service.supabase.table('users').update({
                    'total_profit': new_total_profit,
                    'updated_at': datetime.now().isoformat()
                }).eq('id', user_id).execute()
                
            except Exception as e:
                logger.warning(f"Failed to update total profit for user {user_id}: {e}")
            
            # Log transaction
            if not self.db_service.log_transaction(
                user_id, symbol, 'sell', quantity, price, 
                broker_fee, transaction_tax, realized_pnl
            ):
                logger.warning(f"Failed to log sell transaction for user {user_id}")
            
            return {
                'success': True,
                'message': 'Sell order executed successfully',
                'trade_details': {
                    'symbol': symbol,
                    'action': 'sell',
                    'quantity': quantity,
                    'price': price,
                    'trade_amount': trade_amount,
                    'broker_fee': broker_fee,
                    'transaction_tax': transaction_tax,
                    'net_proceeds': net_proceeds,
                    'realized_pnl': realized_pnl,
                    'remaining_cash': new_cash_balance,
                    'remaining_shares': available_quantity - quantity
                }
            }
            
        except Exception as e:
            logger.error(f"Error executing sell order: {e}")
            return {
                'success': False,
                'error': 'Failed to execute sell order'
            }
    
    def _validate_trade_data(self, trade_data: Dict) -> Dict:
        """Validate trade data"""
        required_fields = ['symbol', 'action', 'quantity']
        
        for field in required_fields:
            if field not in trade_data:
                return {
                    'valid': False,
                    'error': f'Missing required field: {field}'
                }
        
        # Validate symbol
        symbol = trade_data['symbol']
        if not symbol or not isinstance(symbol, str):
            return {
                'valid': False,
                'error': 'Invalid symbol'
            }
        
        # Validate action
        action = trade_data['action'].lower()
        if action not in ['buy', 'sell']:
            return {
                'valid': False,
                'error': 'Action must be "buy" or "sell"'
            }
        
        # Validate quantity
        try:
            quantity = int(trade_data['quantity'])
            if quantity <= 0:
                return {
                    'valid': False,
                    'error': 'Quantity must be positive'
                }
            
            if quantity % self.min_quantity_per_trade != 0:
                return {
                    'valid': False,
                    'error': f'Quantity must be in multiples of {self.min_quantity_per_trade} shares'
                }
            
            if quantity > self.max_quantity_per_trade:
                return {
                    'valid': False,
                    'error': f'Quantity cannot exceed {self.max_quantity_per_trade} shares'
                }
                
        except (ValueError, TypeError):
            return {
                'valid': False,
                'error': 'Invalid quantity'
            }
        
        # Validate price type
        price_type = trade_data.get('price_type', 'market')
        if price_type not in ['market', 'limit']:
            return {
                'valid': False,
                'error': 'Price type must be "market" or "limit"'
            }
        
        # Validate limit price if provided
        if price_type == 'limit':
            try:
                limit_price = float(trade_data.get('price', 0))
                if limit_price <= 0:
                    return {
                        'valid': False,
                        'error': 'Limit price must be positive'
                    }
            except (ValueError, TypeError):
                return {
                    'valid': False,
                    'error': 'Invalid limit price'
                }
        
        return {'valid': True}
    
    def get_trade_preview(self, user_id: str, trade_data: Dict) -> Dict:
        """Get trade preview without executing"""
        try:
            # Validate trade data
            validation_result = self._validate_trade_data(trade_data)
            if not validation_result['valid']:
                return {
                    'success': False,
                    'error': validation_result['error']
                }
            
            symbol = trade_data['symbol']
            action = trade_data['action'].lower()
            quantity = int(trade_data['quantity'])
            price_type = trade_data.get('price_type', 'market')
            limit_price = trade_data.get('price', 0)
            
            # Get current market price
            quote = self.market_service.get_realtime_price(symbol)
            if 'error' in quote:
                return {
                    'success': False,
                    'error': f'Failed to get market price: {quote["error"]}'
                }
            
            market_price = quote['price']
            
            # Determine execution price
            if price_type == 'market':
                execution_price = market_price
            else:
                execution_price = limit_price
            
            # Calculate trade amount
            trade_amount = execution_price * quantity
            
            # Calculate fees
            broker_fee = max(trade_amount * self.broker_fee_rate, self.min_fee)
            
            if action == 'buy':
                total_cost = trade_amount + broker_fee
                
                return {
                    'success': True,
                    'preview': {
                        'symbol': symbol,
                        'action': action,
                        'quantity': quantity,
                        'price': execution_price,
                        'market_price': market_price,
                        'trade_amount': trade_amount,
                        'broker_fee': broker_fee,
                        'total_cost': total_cost,
                        'fees_breakdown': {
                            'broker_fee': broker_fee,
                            'transaction_tax': 0
                        }
                    }
                }
            else:  # sell
                transaction_tax = trade_amount * self.tax_rate
                total_fees = broker_fee + transaction_tax
                net_proceeds = trade_amount - total_fees
                
                # Calculate potential PnL if position exists
                existing_position = self.db_service.get_position(user_id, symbol)
                potential_pnl = 0
                
                if existing_position:
                    average_cost = existing_position['average_cost']
                    cost_basis = average_cost * quantity
                    potential_pnl = trade_amount - cost_basis - total_fees
                
                return {
                    'success': True,
                    'preview': {
                        'symbol': symbol,
                        'action': action,
                        'quantity': quantity,
                        'price': execution_price,
                        'market_price': market_price,
                        'trade_amount': trade_amount,
                        'broker_fee': broker_fee,
                        'transaction_tax': transaction_tax,
                        'net_proceeds': net_proceeds,
                        'potential_pnl': potential_pnl,
                        'fees_breakdown': {
                            'broker_fee': broker_fee,
                            'transaction_tax': transaction_tax
                        }
                    }
                }
                
        except Exception as e:
            logger.error(f"Error getting trade preview: {e}")
            return {
                'success': False,
                'error': 'Failed to get trade preview'
            }
    
    def get_trading_limits(self, user_id: str) -> Dict:
        """Get trading limits for user"""
        try:
            user_profile = self.db_service.get_user_profile(user_id)
            if 'error' in user_profile:
                return {
                    'success': False,
                    'error': 'User not found'
                }
            
            return {
                'success': True,
                'limits': {
                    'max_quantity_per_trade': self.max_quantity_per_trade,
                    'min_quantity_per_trade': self.min_quantity_per_trade,
                    'available_cash': user_profile['cash_balance'],
                    'broker_fee_rate': self.broker_fee_rate,
                    'tax_rate': self.tax_rate,
                    'min_fee': self.min_fee
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting trading limits: {e}")
            return {
                'success': False,
                'error': 'Failed to get trading limits'
            }
    
    def cancel_order(self, user_id: str, order_id: str) -> Dict:
        """Cancel pending order (placeholder for future implementation)"""
        return {
            'success': False,
            'error': 'Order cancellation not yet implemented'
        }
    
    def get_order_history(self, user_id: str, limit: int = 50) -> Dict:
        """Get order history for user"""
        try:
            transactions = self.db_service.get_user_transactions(user_id, limit)
            
            return {
                'success': True,
                'orders': transactions
            }
            
        except Exception as e:
            logger.error(f"Error getting order history: {e}")
            return {
                'success': False,
                'error': 'Failed to get order history'
            }