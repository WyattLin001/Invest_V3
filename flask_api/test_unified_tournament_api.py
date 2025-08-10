#!/usr/bin/env python3
"""
統一錦標賽架構 API 測試腳本
測試一般模式使用固定 UUID 的 Flask API 端點

使用方法:
    python test_unified_tournament_api.py [--verbose]
"""

import requests
import json
import sys
import argparse
from datetime import datetime
import logging

# 設定日誌
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# 測試配置
API_BASE_URL = "http://localhost:5001"
GENERAL_MODE_TOURNAMENT_ID = "00000000-0000-0000-0000-000000000000"
TEST_USER_ID = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
TEST_TOURNAMENT_ID = "12345678-1234-1234-1234-123456789001"

class UnifiedTournamentAPITester:
    def __init__(self, base_url=API_BASE_URL, verbose=False):
        self.base_url = base_url
        self.verbose = verbose
        self.test_results = []
    
    def log_test(self, test_name, success, message, data=None):
        """記錄測試結果"""
        result = {
            "test": test_name,
            "success": success,
            "message": message,
            "timestamp": datetime.now().isoformat(),
            "data": data if self.verbose else None
        }
        self.test_results.append(result)
        
        status = "✅" if success else "❌"
        logger.info(f"{status} {test_name}: {message}")
        
        if self.verbose and data:
            print(f"   數據: {json.dumps(data, indent=2, ensure_ascii=False)}")
    
    def test_health_check(self):
        """測試健康檢查端點"""
        try:
            response = requests.get(f"{self.base_url}/api/health")
            success = response.status_code == 200
            
            if success:
                data = response.json()
                self.log_test("健康檢查", True, "API 服務正常運行", data)
            else:
                self.log_test("健康檢查", False, f"API 健康檢查失敗: {response.status_code}")
                
            return success
            
        except Exception as e:
            self.log_test("健康檢查", False, f"連接 API 失敗: {e}")
            return False
    
    def test_tournament_isolation_endpoint(self):
        """測試錦標賽隔離端點"""
        test_cases = [
            {"tournament_id": None, "expected_context": "一般模式"},
            {"tournament_id": "", "expected_context": "一般模式"},
            {"tournament_id": "test06", "expected_context": "錦標賽 test06"},
            {"tournament_id": "test05", "expected_context": "錦標賽 test05"},
        ]
        
        all_passed = True
        
        for case in test_cases:
            try:
                payload = {"user_id": "test"}
                if case["tournament_id"] is not None:
                    payload["tournament_id"] = case["tournament_id"]
                
                response = requests.post(
                    f"{self.base_url}/api/test-tournament-isolation",
                    json=payload
                )
                
                if response.status_code == 200:
                    data = response.json()
                    context = data.get("context", "")
                    
                    # 對於一般模式，檢查是否包含正確的 UUID
                    if case["tournament_id"] in [None, ""] and "一般模式" in context:
                        expected_uuid_in_context = GENERAL_MODE_TOURNAMENT_ID in context
                        success = expected_uuid_in_context
                        message = f"一般模式使用正確的 UUID" if success else "一般模式未使用預期的 UUID"
                    else:
                        success = case["expected_context"] in context
                        message = f"隔離測試通過: {context}" if success else f"預期 {case['expected_context']}, 實際 {context}"
                    
                    self.log_test(f"隔離測試 - {case['tournament_id'] or '一般模式'}", success, message, data)
                    all_passed = all_passed and success
                    
                else:
                    self.log_test(f"隔離測試 - {case['tournament_id'] or '一般模式'}", False, f"HTTP {response.status_code}")
                    all_passed = False
                    
            except Exception as e:
                self.log_test(f"隔離測試 - {case['tournament_id'] or '一般模式'}", False, f"請求失敗: {e}")
                all_passed = False
        
        return all_passed
    
    def test_trade_execution(self):
        """測試交易執行"""
        test_cases = [
            {
                "name": "一般模式交易",
                "payload": {
                    "user_id": TEST_USER_ID,
                    "symbol": "2330",
                    "action": "buy",
                    "amount": 10000
                },
                "expected_tournament_id": GENERAL_MODE_TOURNAMENT_ID
            },
            {
                "name": "錦標賽模式交易",
                "payload": {
                    "user_id": TEST_USER_ID,
                    "symbol": "2454",
                    "action": "buy", 
                    "amount": 15000,
                    "tournament_id": TEST_TOURNAMENT_ID
                },
                "expected_tournament_id": TEST_TOURNAMENT_ID
            }
        ]
        
        all_passed = True
        
        for case in test_cases:
            try:
                response = requests.post(f"{self.base_url}/api/trade", json=case["payload"])
                
                if response.status_code == 200:
                    data = response.json()
                    returned_tournament_id = data.get("tournament_id")
                    
                    success = returned_tournament_id == case["expected_tournament_id"]
                    message = f"交易成功，tournament_id: {returned_tournament_id}" if success else f"tournament_id 不匹配: 預期 {case['expected_tournament_id']}, 實際 {returned_tournament_id}"
                    
                    self.log_test(case["name"], success, message, data)
                    all_passed = all_passed and success
                    
                else:
                    error_data = response.json() if response.headers.get('content-type') == 'application/json' else response.text
                    self.log_test(case["name"], False, f"HTTP {response.status_code}: {error_data}")
                    all_passed = False
                    
            except Exception as e:
                self.log_test(case["name"], False, f"請求失敗: {e}")
                all_passed = False
        
        return all_passed
    
    def test_portfolio_queries(self):
        """測試投資組合查詢"""
        test_cases = [
            {
                "name": "一般模式投資組合查詢",
                "params": {"user_id": TEST_USER_ID},
                "expected_behavior": "使用固定 UUID 查詢一般模式數據"
            },
            {
                "name": "錦標賽投資組合查詢", 
                "params": {"user_id": TEST_USER_ID, "tournament_id": TEST_TOURNAMENT_ID},
                "expected_behavior": "使用具體 tournament_id 查詢錦標賽數據"
            }
        ]
        
        all_passed = True
        
        for case in test_cases:
            try:
                response = requests.get(f"{self.base_url}/api/portfolio", params=case["params"])
                
                if response.status_code == 200:
                    data = response.json()
                    returned_tournament_id = data.get("tournament_id")
                    
                    if "tournament_id" not in case["params"]:
                        # 一般模式查詢應該返回固定 UUID
                        success = returned_tournament_id == GENERAL_MODE_TOURNAMENT_ID
                        message = f"一般模式查詢正確，返回 UUID: {returned_tournament_id}" if success else f"一般模式查詢錯誤，預期 {GENERAL_MODE_TOURNAMENT_ID}, 實際 {returned_tournament_id}"
                    else:
                        # 錦標賽模式查詢應該返回指定的 tournament_id
                        expected_id = case["params"]["tournament_id"]
                        success = returned_tournament_id == expected_id
                        message = f"錦標賽查詢正確，返回 tournament_id: {returned_tournament_id}" if success else f"錦標賽查詢錯誤，預期 {expected_id}, 實際 {returned_tournament_id}"
                    
                    self.log_test(case["name"], success, message, data)
                    all_passed = all_passed and success
                    
                else:
                    error_data = response.json() if response.headers.get('content-type') == 'application/json' else response.text
                    self.log_test(case["name"], False, f"HTTP {response.status_code}: {error_data}")
                    all_passed = False
                    
            except Exception as e:
                self.log_test(case["name"], False, f"請求失敗: {e}")
                all_passed = False
        
        return all_passed
    
    def test_transaction_queries(self):
        """測試交易記錄查詢"""
        test_cases = [
            {
                "name": "一般模式交易記錄查詢",
                "params": {"user_id": TEST_USER_ID, "limit": 10},
                "expected_behavior": "查詢一般模式交易記錄"
            },
            {
                "name": "錦標賽交易記錄查詢",
                "params": {"user_id": TEST_USER_ID, "tournament_id": TEST_TOURNAMENT_ID, "limit": 10},
                "expected_behavior": "查詢特定錦標賽交易記錄"
            }
        ]
        
        all_passed = True
        
        for case in test_cases:
            try:
                response = requests.get(f"{self.base_url}/api/transactions", params=case["params"])
                
                if response.status_code == 200:
                    data = response.json()
                    
                    # 檢查返回的交易記錄中的 tournament_id
                    if isinstance(data, list) and len(data) > 0:
                        first_transaction = data[0]
                        returned_tournament_id = first_transaction.get("tournament_id")
                        
                        if "tournament_id" not in case["params"]:
                            # 一般模式查詢
                            success = returned_tournament_id == GENERAL_MODE_TOURNAMENT_ID
                            message = f"一般模式交易記錄正確，tournament_id: {returned_tournament_id}" if success else f"一般模式交易記錄錯誤"
                        else:
                            # 錦標賽模式查詢
                            expected_id = case["params"]["tournament_id"]
                            success = returned_tournament_id == expected_id
                            message = f"錦標賽交易記錄正確，tournament_id: {returned_tournament_id}" if success else f"錦標賽交易記錄錯誤"
                    else:
                        # 沒有交易記錄也是正常的
                        success = True
                        message = f"查詢成功，返回 {len(data) if isinstance(data, list) else 0} 筆記錄"
                    
                    self.log_test(case["name"], success, message, data if self.verbose else {"record_count": len(data) if isinstance(data, list) else 0})
                    all_passed = all_passed and success
                    
                else:
                    error_data = response.json() if response.headers.get('content-type') == 'application/json' else response.text
                    self.log_test(case["name"], False, f"HTTP {response.status_code}: {error_data}")
                    all_passed = False
                    
            except Exception as e:
                self.log_test(case["name"], False, f"請求失敗: {e}")
                all_passed = False
        
        return all_passed
    
    def run_all_tests(self):
        """執行所有測試"""
        logger.info("🧪 開始統一錦標賽架構 API 測試")
        logger.info(f"測試目標: {self.base_url}")
        logger.info(f"一般模式 UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        
        test_functions = [
            ("健康檢查", self.test_health_check),
            ("錦標賽隔離端點", self.test_tournament_isolation_endpoint),
            ("交易執行", self.test_trade_execution),
            ("投資組合查詢", self.test_portfolio_queries),
            ("交易記錄查詢", self.test_transaction_queries),
        ]
        
        passed_tests = 0
        total_tests = len(test_functions)
        
        for test_name, test_func in test_functions:
            logger.info(f"執行 {test_name} 測試...")
            try:
                success = test_func()
                if success:
                    passed_tests += 1
            except Exception as e:
                logger.error(f"測試 {test_name} 發生異常: {e}")
        
        # 生成測試報告
        self.generate_report(passed_tests, total_tests)
        
        return passed_tests == total_tests
    
    def generate_report(self, passed_tests, total_tests):
        """生成測試報告"""
        print("\n" + "="*80)
        print("統一錦標賽架構 API 測試報告")
        print("="*80)
        print(f"測試時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"測試目標: {self.base_url}")
        print(f"一般模式 UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print("-"*80)
        
        # 按類別分組顯示結果
        for result in self.test_results:
            status = "✅ 通過" if result["success"] else "❌ 失敗"
            print(f"{status} {result['test']}: {result['message']}")
        
        print("-"*80)
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        print(f"測試結果: {passed_tests}/{total_tests} 通過 ({success_rate:.1f}%)")
        
        if passed_tests == total_tests:
            print("🎉 所有測試通過！統一錦標賽架構運行正常。")
        else:
            failed_tests = total_tests - passed_tests
            print(f"⚠️ {failed_tests} 個測試失敗，請檢查 API 實現。")
        
        print("="*80)


def main():
    parser = argparse.ArgumentParser(description='統一錦標賽架構 API 測試工具')
    parser.add_argument('--verbose', '-v', action='store_true', help='顯示詳細的響應數據')
    parser.add_argument('--url', default=API_BASE_URL, help=f'API 基礎 URL (默認: {API_BASE_URL})')
    
    args = parser.parse_args()
    
    tester = UnifiedTournamentAPITester(base_url=args.url, verbose=args.verbose)
    
    try:
        success = tester.run_all_tests()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        logger.info("測試被用戶中斷")
        sys.exit(1)
    except Exception as e:
        logger.error(f"測試過程發生錯誤: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()