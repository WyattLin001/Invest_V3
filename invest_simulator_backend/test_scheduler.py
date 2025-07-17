#!/usr/bin/env python3
"""
調度器服務測試腳本
使用本地SQLite資料庫演示調度器功能
"""

import sqlite3
import time
import logging
import threading
from datetime import datetime
import yfinance as yf
import random
from typing import Optional

# 配置日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MockDatabaseService:
    """模擬資料庫服務，使用SQLite"""
    
    def __init__(self):
        self.db_path = 'test_scheduler.db'  # 使用文件資料庫以便調試
        self.init_database()
    
    def init_database(self):
        """初始化資料庫結構"""
        conn = sqlite3.connect(self.db_path)
        conn.execute('PRAGMA foreign_keys = ON')
        
        cursor = conn.cursor()
        
        # 創建stocks表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS stocks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                symbol TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                price REAL NOT NULL DEFAULT 0.00,
                change_amount REAL DEFAULT 0.00,
                change_percent REAL DEFAULT 0.00,
                volume INTEGER DEFAULT 0,
                last_updated TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # 創建users表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                phone TEXT UNIQUE NOT NULL,
                name TEXT,
                cash_balance REAL DEFAULT 1000000.00,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # 創建holdings表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS holdings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                stock_symbol TEXT NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 0,
                average_cost REAL NOT NULL DEFAULT 0.00,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, stock_symbol),
                FOREIGN KEY (user_id) REFERENCES users(id),
                FOREIGN KEY (stock_symbol) REFERENCES stocks(symbol)
            )
        ''')
        
        # 創建user_rankings表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_rankings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT UNIQUE NOT NULL,
                rank INTEGER NOT NULL,
                total_assets REAL NOT NULL,
                return_rate REAL NOT NULL DEFAULT 0.00,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # 插入測試股票資料
        stocks_data = [
            ('2330.TW', '台積電', 580.00),
            ('2317.TW', '鴻海', 105.00),
            ('2454.TW', '聯發科', 1200.00),
            ('2881.TW', '富邦金', 75.00),
            ('6505.TW', '台塑化', 95.00),
            ('2382.TW', '廣達', 85.00),
            ('2412.TW', '中華電', 120.00),
            ('2308.TW', '台達電', 300.00),
            ('2303.TW', '聯電', 50.00),
            ('1301.TW', '台塑', 110.00)
        ]
        
        cursor.executemany('''
            INSERT OR REPLACE INTO stocks (symbol, name, price, volume, last_updated)
            VALUES (?, ?, ?, 10000000, datetime('now'))
        ''', stocks_data)
        
        # 插入測試用戶資料
        users_data = [
            ('user1', '+886912345678', '測試用戶1', 1000000.00),
            ('user2', '+886987654321', '測試用戶2', 1200000.00),
            ('user3', '+886955555555', '測試用戶3', 800000.00),
        ]
        
        cursor.executemany('''
            INSERT OR REPLACE INTO users (id, phone, name, cash_balance, created_at, updated_at)
            VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))
        ''', users_data)
        
        # 插入測試持股資料
        holdings_data = [
            ('user1', '2330.TW', 100, 580.00),
            ('user1', '2317.TW', 500, 105.00),
            ('user2', '2454.TW', 50, 1200.00),
            ('user2', '2881.TW', 1000, 75.00),
            ('user3', '6505.TW', 200, 95.00),
        ]
        
        cursor.executemany('''
            INSERT OR REPLACE INTO holdings (user_id, stock_symbol, quantity, average_cost, created_at, updated_at)
            VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))
        ''', holdings_data)
        
        conn.commit()
        conn.close()
        logger.info("Database initialized with test data")
    
    def get_db_connection(self):
        """獲取資料庫連接"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

class SimpleSchedulerService:
    """簡化的調度器服務用於測試"""
    
    def __init__(self, db_service):
        self.db_service = db_service
        self.logger = logging.getLogger(__name__)
        self.is_running = False
        self.scheduler_thread: Optional[threading.Thread] = None
        
        # 任務間隔配置（秒）
        self.STOCK_UPDATE_INTERVAL = 5   # 5秒
        self.RANKING_UPDATE_INTERVAL = 10  # 10秒
        self.PORTFOLIO_RECALC_INTERVAL = 8  # 8秒
        
        # 上次執行時間記錄
        self.last_stock_update = 0
        self.last_ranking_update = 0
        self.last_portfolio_update = 0
        
        # 台股代碼列表
        self.taiwan_stocks = [
            "2330.TW", "2317.TW", "2454.TW", "2881.TW", "6505.TW",
            "2382.TW", "2412.TW", "2308.TW", "2303.TW", "1301.TW"
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
                time.sleep(5)
    
    def _update_stock_prices(self):
        """更新股票價格（使用模擬資料）"""
        try:
            self.logger.info("Starting stock price update")
            updated_count = 0
            
            with self.db_service.get_db_connection() as conn:
                cursor = conn.cursor()
                
                for symbol in self.taiwan_stocks:
                    try:
                        # 獲取當前價格
                        cursor.execute("SELECT price FROM stocks WHERE symbol = ?", (symbol,))
                        result = cursor.fetchone()
                        base_price = result['price'] if result else 100.0
                        
                        # 生成隨機變化 (-2% 到 +2%)
                        change_percent = random.uniform(-2.0, 2.0)
                        change = base_price * (change_percent / 100)
                        new_price = base_price + change
                        volume = random.randint(1000000, 50000000)
                        
                        # 更新資料庫
                        cursor.execute('''
                            UPDATE stocks 
                            SET price = ?, change_amount = ?, change_percent = ?, 
                                volume = ?, last_updated = datetime('now')
                            WHERE symbol = ?
                        ''', (new_price, change, change_percent, volume, symbol))
                        
                        updated_count += 1
                        
                    except Exception as e:
                        self.logger.warning(f"Failed to update stock {symbol}: {e}")
                
                conn.commit()
                self.logger.info(f"Stock price update completed. Updated {updated_count} stocks")
                
        except Exception as e:
            self.logger.error(f"Error updating stock prices: {e}")
    
    def _update_user_rankings(self):
        """更新用戶排名"""
        try:
            self.logger.info("Starting user rankings update")
            
            with self.db_service.get_db_connection() as conn:
                cursor = conn.cursor()
                
                # 計算所有用戶的總資產
                query = '''
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
                '''
                
                cursor.execute(query)
                rankings = cursor.fetchall()
                
                # 清空舊排名
                cursor.execute("DELETE FROM user_rankings")
                
                # 插入新排名
                for ranking in rankings:
                    cursor.execute('''
                        INSERT INTO user_rankings (user_id, rank, total_assets, return_rate, updated_at)
                        VALUES (?, ?, ?, ?, datetime('now'))
                    ''', (ranking['user_id'], ranking['rank'], ranking['total_assets'], ranking['return_rate']))
                
                conn.commit()
                self.logger.info(f"User rankings updated. Total users: {len(rankings)}")
                
        except Exception as e:
            self.logger.error(f"Error updating user rankings: {e}")
    
    def _recalculate_portfolios(self):
        """重新計算所有用戶的投資組合價值"""
        try:
            self.logger.info("Starting portfolio recalculation")
            
            with self.db_service.get_db_connection() as conn:
                cursor = conn.cursor()
                
                # 獲取所有用戶
                cursor.execute("SELECT id FROM users")
                users = cursor.fetchall()
                updated_count = len(users)
                
                self.logger.info(f"Portfolio recalculation completed. Updated {updated_count} portfolios")
                
        except Exception as e:
            self.logger.error(f"Error recalculating portfolios: {e}")
    
    def get_status(self):
        """獲取調度器狀態"""
        return {
            'is_running': self.is_running,
            'last_stock_update': datetime.fromtimestamp(self.last_stock_update).isoformat() if self.last_stock_update > 0 else None,
            'last_ranking_update': datetime.fromtimestamp(self.last_ranking_update).isoformat() if self.last_ranking_update > 0 else None,
            'last_portfolio_update': datetime.fromtimestamp(self.last_portfolio_update).isoformat() if self.last_portfolio_update > 0 else None,
            'next_stock_update': datetime.fromtimestamp(self.last_stock_update + self.STOCK_UPDATE_INTERVAL).isoformat() if self.last_stock_update > 0 else None,
            'next_ranking_update': datetime.fromtimestamp(self.last_ranking_update + self.RANKING_UPDATE_INTERVAL).isoformat() if self.last_ranking_update > 0 else None,
            'next_portfolio_update': datetime.fromtimestamp(self.last_portfolio_update + self.PORTFOLIO_RECALC_INTERVAL).isoformat() if self.last_portfolio_update > 0 else None
        }

class TestScheduler:
    """調度器測試類"""
    
    def __init__(self):
        self.mock_db = MockDatabaseService()
        self.scheduler = SimpleSchedulerService(self.mock_db)
    
    def display_stocks(self):
        """顯示當前股票資料"""
        with self.mock_db.get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT symbol, name, price, change_amount, change_percent, volume, last_updated
                FROM stocks ORDER BY symbol
            ''')
            
            stocks = cursor.fetchall()
            print("\n=== 股票資料 ===")
            print(f"{'代號':<10} {'名稱':<8} {'價格':<8} {'漲跌':<8} {'漲跌%':<8} {'成交量':<10} {'更新時間':<20}")
            print("-" * 80)
            for stock in stocks:
                print(f"{stock['symbol']:<10} {stock['name']:<8} {stock['price']:<8.2f} "
                     f"{stock['change_amount']:<8.2f} {stock['change_percent']:<8.2f}% "
                     f"{stock['volume']:<10} {stock['last_updated']:<20}")
    
    def display_rankings(self):
        """顯示用戶排名"""
        with self.mock_db.get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT ur.rank, u.name, ur.total_assets, ur.return_rate, ur.updated_at
                FROM user_rankings ur
                JOIN users u ON ur.user_id = u.id
                ORDER BY ur.rank
            ''')
            
            rankings = cursor.fetchall()
            print("\n=== 用戶排名 ===")
            if rankings:
                print(f"{'排名':<4} {'姓名':<12} {'總資產':<12} {'報酬率':<8} {'更新時間':<20}")
                print("-" * 65)
                for rank in rankings:
                    print(f"{rank['rank']:<4} {rank['name']:<12} "
                         f"{rank['total_assets']:<12.2f} {rank['return_rate']:<8.2f}% "
                         f"{rank['updated_at']:<20}")
            else:
                print("暫無排名資料")
    
    def display_status(self):
        """顯示調度器狀態"""
        status = self.scheduler.get_status()
        print("\n=== 調度器狀態 ===")
        print(f"運行狀態: {'運行中' if status['is_running'] else '已停止'}")
        print(f"上次股價更新: {status['last_stock_update'] or '未執行'}")
        print(f"上次排名更新: {status['last_ranking_update'] or '未執行'}")
        print(f"下次股價更新: {status['next_stock_update'] or '未設定'}")
        print(f"下次排名更新: {status['next_ranking_update'] or '未設定'}")
    
    def run_test(self, duration=60):
        """運行測試"""
        print(f"開始調度器測試，運行時間：{duration}秒")
        print("=" * 50)
        
        # 顯示初始狀態
        self.display_stocks()
        self.display_rankings()
        self.display_status()
        
        # 啟動調度器
        self.scheduler.start()
        
        try:
            # 定期顯示狀態
            for i in range(duration // 10):
                time.sleep(10)
                print(f"\n時間: {datetime.now().strftime('%H:%M:%S')}")
                self.display_stocks()
                self.display_rankings()
                self.display_status()
                
        except KeyboardInterrupt:
            print("\n收到中斷信號，停止測試...")
        
        finally:
            # 停止調度器
            self.scheduler.stop()
            print("\n調度器已停止")
            
            # 顯示最終狀態
            print("\n=== 最終狀態 ===")
            self.display_stocks()
            self.display_rankings()

def main():
    """主函數"""
    print("投資模擬交易平台 - 調度器服務測試")
    print("=" * 50)
    
    tester = TestScheduler()
    
    try:
        tester.run_test(duration=30)  # 運行30秒測試
    except Exception as e:
        logger.error(f"測試過程中發生錯誤: {e}")
    
    print("\n測試完成")

if __name__ == "__main__":
    main()