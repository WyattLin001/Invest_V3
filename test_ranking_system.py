#!/usr/bin/env python3
"""
測試排名系統的腳本
用於驗證後端的資料清理和初始化功能
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'invest_simulator_backend'))

from services.db_service import DatabaseService
import json

def test_ranking_system():
    """測試排名系統功能"""
    print("🧪 開始測試排名系統...")
    
    # 初始化資料庫服務
    db_service = DatabaseService()
    
    print("\n1️⃣ 測試清除舊資料...")
    clear_result = db_service.clear_all_trading_test_data()
    print(f"清除結果: {json.dumps(clear_result, indent=2, ensure_ascii=False)}")
    
    print("\n2️⃣ 測試創建新測試用戶...")
    create_result = db_service.create_test_trading_users()
    print(f"創建結果: {json.dumps(create_result, indent=2, ensure_ascii=False)}")
    
    print("\n3️⃣ 測試獲取排名資料...")
    rankings_result = db_service.get_rankings('all', 10)
    print(f"排名結果: {json.dumps(rankings_result, indent=2, ensure_ascii=False)}")
    
    print("\n4️⃣ 測試完整初始化流程...")
    init_result = db_service.initialize_test_trading_data()
    print(f"初始化結果: {json.dumps(init_result, indent=2, ensure_ascii=False)}")
    
    print("\n✅ 測試完成！")

if __name__ == "__main__":
    test_ranking_system()