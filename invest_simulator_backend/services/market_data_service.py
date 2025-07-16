import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging
import time
from functools import lru_cache

logger = logging.getLogger(__name__)

class MarketDataService:
    def __init__(self):
        self.cache_duration = 10  # seconds
        self.last_cache_time = {}
        self.price_cache = {}
        
        # Taiwan stock market mapping
        self.market_suffixes = {
            'TW': '.TW',    # Taiwan Stock Exchange (上市)
            'TWO': '.TWO'   # Taipei Exchange (上櫃)
        }
    
    def format_ticker(self, symbol: str) -> str:
        """Format Taiwan stock symbol for yfinance"""
        # Remove any existing suffixes
        clean_symbol = symbol.replace('.TW', '').replace('.TWO', '')
        
        # Try to determine market (simplified logic)
        # In production, you'd have a database lookup
        if clean_symbol.isdigit():
            symbol_int = int(clean_symbol)
            if symbol_int >= 1000 and symbol_int <= 9999:
                # Most listed stocks are in 1000-9999 range
                return f"{clean_symbol}.TW"
            elif symbol_int >= 1000:
                # OTC stocks often have different ranges
                return f"{clean_symbol}.TWO"
        
        # Default to listed market
        return f"{clean_symbol}.TW"
    
    def get_realtime_price(self, symbol: str) -> Dict:
        """Get real-time price for a stock"""
        try:
            # Check cache first
            cache_key = symbol
            current_time = time.time()
            
            if (cache_key in self.price_cache and 
                cache_key in self.last_cache_time and 
                current_time - self.last_cache_time[cache_key] < self.cache_duration):
                logger.info(f"Returning cached price for {symbol}")
                return self.price_cache[cache_key]
            
            # Format ticker for yfinance
            ticker = self.format_ticker(symbol)
            
            # Get stock data
            stock = yf.Ticker(ticker)
            
            # Try to get fast info first
            try:
                fast_info = stock.fast_info
                current_price = fast_info.get('lastPrice', 0)
                
                if current_price == 0:
                    # Fallback to info
                    info = stock.info
                    current_price = info.get('regularMarketPrice', 0)
                    
                if current_price == 0:
                    # Last resort: get from history
                    hist = stock.history(period='2d', interval='1m')
                    if not hist.empty:
                        current_price = hist['Close'].iloc[-1]
                
            except Exception as e:
                logger.warning(f"Fast info failed for {symbol}: {e}")
                # Fallback to history
                hist = stock.history(period='1d', interval='1m')
                if not hist.empty:
                    current_price = hist['Close'].iloc[-1]
                else:
                    raise Exception(f"No price data available for {symbol}")
            
            # Get additional info
            try:
                hist_daily = stock.history(period='2d', interval='1d')
                if len(hist_daily) >= 2:
                    prev_close = hist_daily['Close'].iloc[-2]
                    change = current_price - prev_close
                    change_percent = (change / prev_close) * 100
                else:
                    change = 0
                    change_percent = 0
                
                # Get volume
                volume = hist_daily['Volume'].iloc[-1] if not hist_daily.empty else 0
                
            except Exception as e:
                logger.warning(f"Additional info failed for {symbol}: {e}")
                change = 0
                change_percent = 0
                volume = 0
            
            # Prepare result
            result = {
                'symbol': symbol,
                'price': float(current_price),
                'change': float(change),
                'change_percent': float(change_percent),
                'volume': int(volume),
                'timestamp': datetime.now().isoformat(),
                'market': 'TW' if ticker.endswith('.TW') else 'TWO'
            }
            
            # Cache the result
            self.price_cache[cache_key] = result
            self.last_cache_time[cache_key] = current_time
            
            logger.info(f"Retrieved price for {symbol}: {current_price}")
            return result
            
        except Exception as e:
            logger.error(f"Error getting price for {symbol}: {e}")
            return {
                'symbol': symbol,
                'price': 0,
                'change': 0,
                'change_percent': 0,
                'volume': 0,
                'timestamp': datetime.now().isoformat(),
                'error': str(e)
            }
    
    def get_history(self, symbol: str, period: str = '1mo', interval: str = '1d') -> Dict:
        """Get historical price data"""
        try:
            ticker = self.format_ticker(symbol)
            stock = yf.Ticker(ticker)
            
            # Get historical data
            hist = stock.history(period=period, interval=interval)
            
            if hist.empty:
                return {
                    'symbol': symbol,
                    'data': [],
                    'error': 'No historical data available'
                }
            
            # Convert to list of dictionaries
            data = []
            for index, row in hist.iterrows():
                data.append({
                    'date': index.isoformat(),
                    'open': float(row['Open']),
                    'high': float(row['High']),
                    'low': float(row['Low']),
                    'close': float(row['Close']),
                    'volume': int(row['Volume'])
                })
            
            return {
                'symbol': symbol,
                'period': period,
                'interval': interval,
                'data': data
            }
            
        except Exception as e:
            logger.error(f"Error getting history for {symbol}: {e}")
            return {
                'symbol': symbol,
                'data': [],
                'error': str(e)
            }
    
    def get_stock_info(self, symbol: str) -> Dict:
        """Get detailed stock information"""
        try:
            ticker = self.format_ticker(symbol)
            stock = yf.Ticker(ticker)
            
            info = stock.info
            
            return {
                'symbol': symbol,
                'name': info.get('longName', symbol),
                'sector': info.get('sector', ''),
                'industry': info.get('industry', ''),
                'market_cap': info.get('marketCap', 0),
                'pe_ratio': info.get('trailingPE', 0),
                'dividend_yield': info.get('dividendYield', 0),
                'fifty_two_week_high': info.get('fiftyTwoWeekHigh', 0),
                'fifty_two_week_low': info.get('fiftyTwoWeekLow', 0),
                'currency': info.get('currency', 'TWD')
            }
            
        except Exception as e:
            logger.error(f"Error getting stock info for {symbol}: {e}")
            return {
                'symbol': symbol,
                'name': symbol,
                'error': str(e)
            }
    
    def batch_get_prices(self, symbols: List[str]) -> Dict[str, Dict]:
        """Get prices for multiple stocks"""
        results = {}
        
        for symbol in symbols:
            try:
                results[symbol] = self.get_realtime_price(symbol)
                time.sleep(0.1)  # Small delay to avoid rate limiting
            except Exception as e:
                logger.error(f"Error getting price for {symbol}: {e}")
                results[symbol] = {
                    'symbol': symbol,
                    'price': 0,
                    'error': str(e)
                }
        
        return results
    
    def is_market_open(self) -> bool:
        """Check if Taiwan stock market is open"""
        now = datetime.now()
        
        # Taiwan stock market hours: 9:00 AM - 1:30 PM (UTC+8)
        # This is a simplified check
        if now.weekday() >= 5:  # Weekend
            return False
        
        market_open = now.replace(hour=9, minute=0, second=0, microsecond=0)
        market_close = now.replace(hour=13, minute=30, second=0, microsecond=0)
        
        return market_open <= now <= market_close
    
    def get_market_status(self) -> Dict:
        """Get current market status"""
        return {
            'is_open': self.is_market_open(),
            'timezone': 'UTC+8',
            'next_open': self._get_next_market_open(),
            'next_close': self._get_next_market_close()
        }
    
    def _get_next_market_open(self) -> str:
        """Get next market opening time"""
        now = datetime.now()
        
        # Simple calculation for next trading day 9:00 AM
        if now.weekday() >= 5:  # Weekend
            days_ahead = 7 - now.weekday()
            next_open = now + timedelta(days=days_ahead)
        else:
            if now.hour >= 14:  # After market close
                next_open = now + timedelta(days=1)
            else:
                next_open = now
        
        return next_open.replace(hour=9, minute=0, second=0, microsecond=0).isoformat()
    
    def _get_next_market_close(self) -> str:
        """Get next market closing time"""
        now = datetime.now()
        
        if now.weekday() >= 5:  # Weekend
            days_ahead = 7 - now.weekday()
            next_close = now + timedelta(days=days_ahead)
        else:
            if now.hour >= 14:  # After market close
                next_close = now + timedelta(days=1)
            else:
                next_close = now
        
        return next_close.replace(hour=13, minute=30, second=0, microsecond=0).isoformat()
    
    def search_stocks(self, query: str) -> List[Dict]:
        """Search for stocks by name or symbol"""
        # This would typically query a database of stock listings
        # For now, return a simple implementation
        
        # Common Taiwan stocks for demo
        demo_stocks = [
            {'symbol': '2330', 'name': '台積電', 'market': 'TW'},
            {'symbol': '2317', 'name': '鴻海', 'market': 'TW'},
            {'symbol': '2454', 'name': '聯發科', 'market': 'TW'},
            {'symbol': '2881', 'name': '富邦金', 'market': 'TW'},
            {'symbol': '2882', 'name': '國泰金', 'market': 'TW'},
            {'symbol': '2886', 'name': '兆豐金', 'market': 'TW'},
            {'symbol': '2891', 'name': '中信金', 'market': 'TW'},
            {'symbol': '6505', 'name': '台塑化', 'market': 'TW'},
            {'symbol': '3008', 'name': '大立光', 'market': 'TW'},
            {'symbol': '2308', 'name': '台達電', 'market': 'TW'}
        ]
        
        query_lower = query.lower()
        results = []
        
        for stock in demo_stocks:
            if (query_lower in stock['symbol'].lower() or 
                query_lower in stock['name'].lower()):
                results.append(stock)
        
        return results[:10]  # Return top 10 matches
    
    def validate_symbol(self, symbol: str) -> bool:
        """Validate if symbol exists and is tradeable"""
        try:
            ticker = self.format_ticker(symbol)
            stock = yf.Ticker(ticker)
            
            # Try to get basic info
            hist = stock.history(period='1d')
            return not hist.empty
            
        except Exception as e:
            logger.error(f"Error validating symbol {symbol}: {e}")
            return False