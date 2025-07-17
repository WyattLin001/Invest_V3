#!/usr/bin/env python3
"""
投資模擬交易平台 - 系統整合測試
測試所有後端API端點和功能
"""

import requests
import json
import time
import logging
from datetime import datetime
from typing import Dict, List, Optional

# 配置日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class IntegrationTester:
    """系統整合測試類"""
    
    def __init__(self, base_url: str = "http://localhost:5001"):
        self.base_url = base_url
        self.session = requests.Session()
        self.access_token = None
        self.test_phone = "+886912345678"
        self.test_otp = None  # 將從send_otp響應中獲取
        self.results = {
            'passed': 0,
            'failed': 0,
            'errors': []
        }
    
    def log_result(self, test_name: str, success: bool, message: str = ""):
        """記錄測試結果"""
        if success:
            self.results['passed'] += 1
            logger.info(f"✅ {test_name}: PASSED {message}")
        else:
            self.results['failed'] += 1
            self.results['errors'].append(f"{test_name}: {message}")
            logger.error(f"❌ {test_name}: FAILED {message}")
    
    def make_request(self, method: str, endpoint: str, data: dict = None, 
                    headers: dict = None, auth_required: bool = False) -> Optional[requests.Response]:
        """發送HTTP請求"""
        url = f"{self.base_url}{endpoint}"
        
        # 設置默認標頭
        default_headers = {'Content-Type': 'application/json'}
        if headers:
            default_headers.update(headers)
        
        # 添加認證標頭
        if auth_required and self.access_token:
            default_headers['Authorization'] = f'Bearer {self.access_token}'
        
        try:
            if method.upper() == 'GET':
                response = self.session.get(url, headers=default_headers)
            elif method.upper() == 'POST':
                response = self.session.post(url, json=data, headers=default_headers)
            elif method.upper() == 'PUT':
                response = self.session.put(url, json=data, headers=default_headers)
            elif method.upper() == 'DELETE':
                response = self.session.delete(url, headers=default_headers)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            return response
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Request failed: {e}")
            return None
    
    def test_health_check(self):
        """測試健康檢查端點"""
        logger.info("Testing health check endpoint...")
        
        response = self.make_request('GET', '/health')
        if response and response.status_code == 200:
            data = response.json()
            if data.get('status') == 'healthy':
                self.log_result("Health Check", True, f"Version: {data.get('version')}")
            else:
                self.log_result("Health Check", False, "Invalid health status")
        else:
            self.log_result("Health Check", False, f"Status code: {response.status_code if response else 'No response'}")
    
    def test_scheduler_status(self):
        """測試調度器狀態"""
        logger.info("Testing scheduler status...")
        
        response = self.make_request('GET', '/admin/scheduler/status')
        if response and response.status_code == 200:
            data = response.json()
            if 'is_running' in data:
                status = "running" if data['is_running'] else "stopped"
                self.log_result("Scheduler Status", True, f"Status: {status}")
            else:
                self.log_result("Scheduler Status", False, "Invalid status response")
        else:
            self.log_result("Scheduler Status", False, f"Status code: {response.status_code if response else 'No response'}")
    
    def test_scheduler_force_update(self):
        """測試調度器強制更新"""
        logger.info("Testing scheduler force update...")
        
        response = self.make_request('POST', '/admin/scheduler/force_update')
        if response and response.status_code == 200:
            data = response.json()
            if 'message' in data:
                self.log_result("Scheduler Force Update", True, data['message'])
            else:
                self.log_result("Scheduler Force Update", False, "Invalid response format")
        else:
            self.log_result("Scheduler Force Update", False, f"Status code: {response.status_code if response else 'No response'}")
    
    def test_send_otp(self):
        """測試發送OTP"""
        logger.info("Testing send OTP...")
        
        data = {'phone': self.test_phone}
        response = self.make_request('POST', '/auth/send_otp', data)
        
        if response and response.status_code == 200:
            result = response.json()
            if result.get('success'):
                # 在開發模式下，從響應中獲取OTP
                if 'otp' in result:
                    self.test_otp = result['otp']
                    self.log_result("Send OTP", True, f"OTP sent successfully: {self.test_otp}")
                else:
                    self.log_result("Send OTP", True, "OTP sent successfully")
                return True
            else:
                self.log_result("Send OTP", False, result.get('message', 'Unknown error'))
        else:
            self.log_result("Send OTP", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_verify_otp(self):
        """測試驗證OTP"""
        logger.info("Testing verify OTP...")
        
        data = {
            'phone': self.test_phone,
            'otp': self.test_otp,
            'invite_code': None
        }
        response = self.make_request('POST', '/auth/verify_otp', data)
        
        if response and response.status_code == 200:
            result = response.json()
            if result.get('success') and 'access_token' in result:
                self.access_token = result['access_token']
                self.log_result("Verify OTP", True, "Login successful")
                return True
            else:
                self.log_result("Verify OTP", False, f"Response: {result}")
        else:
            error_msg = f"Status code: {response.status_code if response else 'No response'}"
            if response:
                try:
                    error_detail = response.json()
                    error_msg += f", Response: {error_detail}"
                except:
                    error_msg += f", Text: {response.text}"
            self.log_result("Verify OTP", False, error_msg)
        return False
    
    def test_get_profile(self):
        """測試獲取用戶資料"""
        logger.info("Testing get user profile...")
        
        response = self.make_request('GET', '/api/profile', auth_required=True)
        
        if response and response.status_code == 200:
            data = response.json()
            if 'user' in data:
                user = data['user']
                self.log_result("Get Profile", True, f"User: {user.get('name', 'Unknown')}")
                return True
            else:
                self.log_result("Get Profile", False, "Invalid profile response")
        else:
            self.log_result("Get Profile", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_get_stocks(self):
        """測試獲取股票列表"""
        logger.info("Testing get stocks...")
        
        response = self.make_request('GET', '/api/stocks', auth_required=True)
        
        if response and response.status_code == 200:
            data = response.json()
            if 'stocks' in data:
                stocks = data['stocks']
                self.log_result("Get Stocks", True, f"Found {len(stocks)} stocks")
                return True
            else:
                self.log_result("Get Stocks", False, "Invalid stocks response")
        else:
            self.log_result("Get Stocks", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_get_portfolio(self):
        """測試獲取投資組合"""
        logger.info("Testing get portfolio...")
        
        response = self.make_request('GET', '/api/portfolio', auth_required=True)
        
        if response and response.status_code == 200:
            data = response.json()
            if 'portfolio' in data:
                portfolio = data['portfolio']
                total_assets = portfolio.get('total_assets', 0)
                self.log_result("Get Portfolio", True, f"Total assets: {total_assets}")
                return True
            else:
                self.log_result("Get Portfolio", False, "Invalid portfolio response")
        else:
            self.log_result("Get Portfolio", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_buy_stock(self):
        """測試買入股票"""
        logger.info("Testing buy stock...")
        
        data = {
            'symbol': '2330.TW',
            'quantity': 1,
            'order_type': 'market'
        }
        response = self.make_request('POST', '/api/trading/buy', data, auth_required=True)
        
        if response and response.status_code == 200:
            result = response.json()
            if result.get('success'):
                self.log_result("Buy Stock", True, f"Bought {data['quantity']} shares of {data['symbol']}")
                return True
            else:
                self.log_result("Buy Stock", False, result.get('message', 'Unknown error'))
        else:
            self.log_result("Buy Stock", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_get_transactions(self):
        """測試獲取交易記錄"""
        logger.info("Testing get transactions...")
        
        response = self.make_request('GET', '/api/transactions', auth_required=True)
        
        if response and response.status_code == 200:
            data = response.json()
            if 'transactions' in data:
                transactions = data['transactions']
                self.log_result("Get Transactions", True, f"Found {len(transactions)} transactions")
                return True
            else:
                self.log_result("Get Transactions", False, "Invalid transactions response")
        else:
            self.log_result("Get Transactions", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_get_rankings(self):
        """測試獲取排行榜"""
        logger.info("Testing get rankings...")
        
        response = self.make_request('GET', '/api/rankings', auth_required=True)
        
        if response and response.status_code == 200:
            data = response.json()
            if 'rankings' in data:
                rankings = data['rankings']
                self.log_result("Get Rankings", True, f"Found {len(rankings)} rankings")
                return True
            else:
                self.log_result("Get Rankings", False, "Invalid rankings response")
        else:
            self.log_result("Get Rankings", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def test_stock_search(self):
        """測試股票搜尋"""
        logger.info("Testing stock search...")
        
        response = self.make_request('GET', '/api/stocks/search?q=台積電', auth_required=True)
        
        if response and response.status_code == 200:
            data = response.json()
            if 'stocks' in data:
                stocks = data['stocks']
                self.log_result("Stock Search", True, f"Found {len(stocks)} matching stocks")
                return True
            else:
                self.log_result("Stock Search", False, "Invalid search response")
        else:
            self.log_result("Stock Search", False, f"Status code: {response.status_code if response else 'No response'}")
        return False
    
    def run_load_test(self, duration: int = 30, concurrent_requests: int = 5):
        """執行負載測試"""
        logger.info(f"Running load test for {duration} seconds with {concurrent_requests} concurrent requests...")
        
        import threading
        import time
        
        start_time = time.time()
        request_count = 0
        error_count = 0
        
        def make_requests():
            nonlocal request_count, error_count
            while time.time() - start_time < duration:
                try:
                    response = self.make_request('GET', '/health')
                    request_count += 1
                    if not response or response.status_code != 200:
                        error_count += 1
                except:
                    error_count += 1
                time.sleep(0.1)  # 100ms間隔
        
        # 啟動多個線程
        threads = []
        for _ in range(concurrent_requests):
            thread = threading.Thread(target=make_requests)
            thread.start()
            threads.append(thread)
        
        # 等待所有線程完成
        for thread in threads:
            thread.join()
        
        success_rate = ((request_count - error_count) / request_count * 100) if request_count > 0 else 0
        rps = request_count / duration
        
        if success_rate >= 95:  # 95%成功率閾值
            self.log_result("Load Test", True, f"RPS: {rps:.1f}, Success Rate: {success_rate:.1f}%")
        else:
            self.log_result("Load Test", False, f"RPS: {rps:.1f}, Success Rate: {success_rate:.1f}%")
    
    def run_all_tests(self):
        """執行所有測試"""
        logger.info("="*60)
        logger.info("投資模擬交易平台 - 系統整合測試開始")
        logger.info("="*60)
        
        # 基礎服務測試
        self.test_health_check()
        self.test_scheduler_status()
        self.test_scheduler_force_update()
        
        # 認證流程測試
        if self.test_send_otp():
            # 立即驗證OTP，不等待以避免過期
            if self.test_verify_otp():
                # 需要認證的API測試
                self.test_get_profile()
                self.test_get_stocks()
                self.test_get_portfolio()
                self.test_buy_stock()
                self.test_get_transactions()
                self.test_get_rankings()
                self.test_stock_search()
        
        # 性能測試
        self.run_load_test(duration=15, concurrent_requests=3)
        
        # 打印測試結果
        logger.info("="*60)
        logger.info("測試結果摘要")
        logger.info("="*60)
        logger.info(f"通過測試: {self.results['passed']}")
        logger.info(f"失敗測試: {self.results['failed']}")
        logger.info(f"總成功率: {self.results['passed']/(self.results['passed']+self.results['failed'])*100:.1f}%")
        
        if self.results['errors']:
            logger.info("\n失敗的測試:")
            for error in self.results['errors']:
                logger.info(f"  - {error}")
        
        logger.info("="*60)
        logger.info("系統整合測試完成")
        logger.info("="*60)

def main():
    """主函數"""
    print("投資模擬交易平台 - 系統整合測試")
    print("請確保後端服務正在運行於 http://localhost:5001")
    
    # 檢查服務是否運行
    try:
        response = requests.get("http://localhost:5001/health", timeout=5)
        if response.status_code == 200:
            print("✅ 後端服務已運行，開始測試...\n")
        else:
            print("❌ 後端服務無響應，請檢查服務狀態")
            return
    except requests.exceptions.RequestException:
        print("❌ 無法連接到後端服務，請確保服務正在運行")
        return
    
    # 執行測試
    tester = IntegrationTester()
    tester.run_all_tests()

if __name__ == "__main__":
    main()