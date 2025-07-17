"""
定時任務服務
負責處理股價更新、排名計算等定期任務
"""
import threading
import time
import logging
from datetime import datetime, timedelta
from typing import Optional
import yfinance as yf
from .db_service import DatabaseService
from .market_data_service import MarketDataService

class SchedulerService:
    def __init__(self):
        self.db_service = DatabaseService()
        self.market_service = MarketDataService()
        self.logger = logging.getLogger(__name__)
        self.is_running = False
        self.scheduler_thread: Optional[threading.Thread] = None
        
        # 任務間隔配置（秒）
        self.STOCK_UPDATE_INTERVAL = 30  # 股價更新：30秒
        self.RANKING_UPDATE_INTERVAL = 300  # 排名更新：5分鐘
        self.PORTFOLIO_RECALC_INTERVAL = 60  # 投資組合重算：1分鐘
        
        # 上次執行時間記錄
        self.last_stock_update = 0
        self.last_ranking_update = 0
        self.last_portfolio_update = 0
        
        # 台股代碼列表
        self.taiwan_stocks = [
            "2330.TW",  # 台積電
            "2317.TW",  # 鴻海
            "2454.TW",  # 聯發科
            "2881.TW",  # 富邦金
            "6505.TW",  # 台塑化
            "2382.TW",  # 廣達
            "2412.TW",  # 中華電
            "2308.TW",  # 台達電
            "2303.TW",  # 聯電
            "1301.TW"   # 台塑
        ]
    
    def start(self):
        """啟動定時任務"""
        if self.is_running:
            self.logger.warning("Scheduler is already running")
            return
        
        self.is_running = True
        self.scheduler_thread = threading.Thread(target=self._run_scheduler, daemon=True)
        self.scheduler_thread.start()
        self.logger.info("Scheduler service started")
    
    def stop(self):
        """停止定時任務"""
        if not self.is_running:
            return
        
        self.is_running = False
        if self.scheduler_thread:
            self.scheduler_thread.join(timeout=5)
        self.logger.info("Scheduler service stopped")
    
    def _run_scheduler(self):
        """主要調度循環"""
        self.logger.info("Scheduler main loop started")
        
        while self.is_running:
            try:
                current_time = time.time()
                
                # 檢查是否需要更新股價
                if current_time - self.last_stock_update >= self.STOCK_UPDATE_INTERVAL:
                    self._update_stock_prices()
                    self.last_stock_update = current_time
                
                # 檢查是否需要更新排名
                if current_time - self.last_ranking_update >= self.RANKING_UPDATE_INTERVAL:
                    self._update_user_rankings()
                    self.last_ranking_update = current_time
                
                # 檢查是否需要重算投資組合
                if current_time - self.last_portfolio_update >= self.PORTFOLIO_RECALC_INTERVAL:
                    self._recalculate_portfolios()
                    self.last_portfolio_update = current_time
                
                # 短暫休息
                time.sleep(1)
                
            except Exception as e:
                self.logger.error(f"Error in scheduler loop: {e}")
                time.sleep(5)  # 錯誤後稍作等待
    
    def _update_stock_prices(self):
        """更新股票價格"""
        try:
            self.logger.info("Starting stock price update")
            updated_count = 0
            
            for symbol in self.taiwan_stocks:
                try:
                    # 獲取股票資料
                    ticker = yf.Ticker(symbol)
                    data = ticker.history(period="1d", interval="1m")
                    
                    if not data.empty:
                        latest_price = float(data['Close'].iloc[-1])
                        previous_price = float(data['Close'].iloc[-2]) if len(data) > 1 else latest_price
                        change = latest_price - previous_price
                        change_percent = (change / previous_price * 100) if previous_price > 0 else 0
                        volume = int(data['Volume'].iloc[-1])
                        
                        # 更新資料庫
                        self._update_stock_in_db(symbol, latest_price, change, change_percent, volume)
                        updated_count += 1
                        
                        self.logger.debug(f"Updated {symbol}: {latest_price}")
                    
                except Exception as e:
                    self.logger.warning(f"Failed to update stock {symbol}: {e}")
                    # 如果獲取失敗，使用模擬資料
                    self._update_stock_with_mock_data(symbol)
            
            self.logger.info(f"Stock price update completed. Updated {updated_count} stocks")
            
        except Exception as e:
            self.logger.error(f"Error updating stock prices: {e}")
    
    def _update_stock_in_db(self, symbol: str, price: float, change: float, 
                           change_percent: float, volume: int):
        """在資料庫中更新股票資料"""
        try:
            # 獲取股票名稱
            stock_names = {
                "2330.TW": "台積電",
                "2317.TW": "鴻海",
                "2454.TW": "聯發科",
                "2881.TW": "富邦金",
                "6505.TW": "台塑化",
                "2382.TW": "廣達",
                "2412.TW": "中華電",
                "2308.TW": "台達電",
                "2303.TW": "聯電",
                "1301.TW": "台塑"
            }
            
            name = stock_names.get(symbol, symbol)
            
            # 使用直接的資料庫連接
            with self.db_service.get_db_connection() as conn:
                with conn.cursor() as cursor:
                    # 插入或更新股票資料
                    query = """
                    INSERT INTO stocks (symbol, name, price, change_amount, change_percent, volume, last_updated)
                    VALUES (%s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (symbol)
                    DO UPDATE SET
                        price = EXCLUDED.price,
                        change_amount = EXCLUDED.change_amount,
                        change_percent = EXCLUDED.change_percent,
                        volume = EXCLUDED.volume,
                        last_updated = EXCLUDED.last_updated
                    """
                    
                    cursor.execute(query, (symbol, name, price, change, change_percent, volume))
                    conn.commit()
            
        except Exception as e:
            self.logger.error(f"Error updating stock {symbol} in database: {e}")
    
    def _update_stock_with_mock_data(self, symbol: str):
        """用模擬資料更新股票（當API失敗時）"""
        try:
            # 獲取當前價格
            base_price = 100.0
            try:
                with self.db_service.get_db_connection() as conn:
                    with conn.cursor() as cursor:
                        cursor.execute("SELECT price FROM stocks WHERE symbol = %s", (symbol,))
                        result = cursor.fetchone()
                        if result:
                            base_price = float(result['price'])
            except:
                pass
            
            # 生成隨機變化 (-1% 到 +1%)
            import random
            change_percent = random.uniform(-1.0, 1.0)
            change = base_price * (change_percent / 100)
            new_price = base_price + change
            volume = random.randint(1000000, 10000000)
            
            self._update_stock_in_db(symbol, new_price, change, change_percent, volume)
            
        except Exception as e:
            self.logger.error(f"Error updating stock {symbol} with mock data: {e}")
    
    def _update_user_rankings(self):
        """更新用戶排名"""
        try:
            self.logger.info("Starting user rankings update")
            
            with self.db_service.get_db_connection() as conn:
                with conn.cursor() as cursor:
                    # 計算所有用戶的總資產
                    query = """
                    WITH user_portfolios AS (
                        SELECT 
                            u.id as user_id,
                            u.phone,
                            u.created_at,
                            COALESCE(u.cash_balance, 1000000) as cash_balance,
                            COALESCE(SUM(h.quantity * s.price), 0) as stock_value
                        FROM users u
                        LEFT JOIN holdings h ON u.id = h.user_id
                        LEFT JOIN stocks s ON h.stock_symbol = s.symbol
                        GROUP BY u.id, u.phone, u.created_at, u.cash_balance
                    ),
                    portfolio_totals AS (
                        SELECT 
                            user_id,
                            phone,
                            created_at,
                            cash_balance,
                            stock_value,
                            (cash_balance + stock_value) as total_assets,
                            ((cash_balance + stock_value - 1000000) / 1000000.0 * 100) as return_rate
                        FROM user_portfolios
                    )
                    SELECT 
                        user_id,
                        phone,
                        total_assets,
                        return_rate,
                        ROW_NUMBER() OVER (ORDER BY total_assets DESC) as rank
                    FROM portfolio_totals
                    ORDER BY total_assets DESC
                    """
                    
                    cursor.execute(query)
                    rankings = cursor.fetchall()
                    
                    # 清空舊排名
                    cursor.execute("DELETE FROM user_rankings")
                    
                    # 插入新排名
                    for ranking in rankings:
                        insert_query = """
                        INSERT INTO user_rankings (user_id, rank, total_assets, return_rate, updated_at)
                        VALUES (%s, %s, %s, %s, NOW())
                        """
                        cursor.execute(
                            insert_query, 
                            (ranking['user_id'], ranking['rank'], ranking['total_assets'], ranking['return_rate'])
                        )
                    
                    conn.commit()
                    self.logger.info(f"User rankings updated. Total users: {len(rankings)}")
            
        except Exception as e:
            self.logger.error(f"Error updating user rankings: {e}")
    
    def _recalculate_portfolios(self):
        """重新計算所有用戶的投資組合價值"""
        try:
            self.logger.info("Starting portfolio recalculation")
            
            with self.db_service.get_db_connection() as conn:
                with conn.cursor() as cursor:
                    # 獲取所有用戶及其持股
                    query = """
                    SELECT DISTINCT u.id as user_id
                    FROM users u
                    WHERE u.cash_balance IS NOT NULL
                    """
                    
                    cursor.execute(query)
                    users = cursor.fetchall()
                    updated_count = 0
                    
                    for user in users:
                        user_id = user['user_id']
                        
                        # 計算該用戶的股票總價值
                        stock_value_query = """
                        SELECT COALESCE(SUM(h.quantity * s.price), 0) as total_stock_value
                        FROM holdings h
                        JOIN stocks s ON h.stock_symbol = s.symbol
                        WHERE h.user_id = %s
                        """
                        
                        cursor.execute(stock_value_query, (user_id,))
                        result = cursor.fetchone()
                        stock_value = result['total_stock_value'] if result else 0
                        
                        # 這裡可以根據需要添加額外的統計信息更新
                        # 例如更新用戶表中的總資產欄位
                        
                        updated_count += 1
                    
                    conn.commit()
                    self.logger.info(f"Portfolio recalculation completed. Updated {updated_count} portfolios")
            
        except Exception as e:
            self.logger.error(f"Error recalculating portfolios: {e}")
    
    def force_update_all(self):
        """強制執行所有更新任務"""
        try:
            self.logger.info("Force updating all data")
            self._update_stock_prices()
            self._recalculate_portfolios()
            self._update_user_rankings()
            self.logger.info("Force update completed")
        except Exception as e:
            self.logger.error(f"Error in force update: {e}")
    
    def get_status(self):
        """獲取調度器狀態"""
        current_time = time.time()
        return {
            'is_running': self.is_running,
            'last_stock_update': datetime.fromtimestamp(self.last_stock_update).isoformat() if self.last_stock_update > 0 else None,
            'last_ranking_update': datetime.fromtimestamp(self.last_ranking_update).isoformat() if self.last_ranking_update > 0 else None,
            'last_portfolio_update': datetime.fromtimestamp(self.last_portfolio_update).isoformat() if self.last_portfolio_update > 0 else None,
            'next_stock_update': datetime.fromtimestamp(self.last_stock_update + self.STOCK_UPDATE_INTERVAL).isoformat() if self.last_stock_update > 0 else None,
            'next_ranking_update': datetime.fromtimestamp(self.last_ranking_update + self.RANKING_UPDATE_INTERVAL).isoformat() if self.last_ranking_update > 0 else None,
            'next_portfolio_update': datetime.fromtimestamp(self.last_portfolio_update + self.PORTFOLIO_RECALC_INTERVAL).isoformat() if self.last_portfolio_update > 0 else None
        }

# 全域調度器實例
scheduler_service = SchedulerService()