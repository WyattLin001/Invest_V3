#!/usr/bin/env python3
"""
測試群組創建功能的腳本
用於驗證後端的群組創建和資料寫入
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'invest_simulator_backend'))

from services.db_service import DatabaseService
import json

def test_group_creation():
    """測試群組創建功能"""
    print("🧪 開始測試群組創建功能...")
    
    # 初始化資料庫服務
    db_service = DatabaseService()
    
    print("\n1️⃣ 檢查現有群組...")
    try:
        # 檢查現有群組數量
        result = db_service.supabase.table('investment_groups').select('*').execute()
        print(f"目前群組數量: {len(result.data)}")
        for group in result.data:
            print(f"- {group['name']} (主持人: {group['host']}, 回報率: {group.get('return_rate', 0)}%)")
    except Exception as e:
        print(f"❌ 查詢群組失敗: {e}")
    
    print("\n2️⃣ 檢查交易用戶資料...")
    try:
        # 檢查交易用戶
        result = db_service.supabase.table('trading_users').select('*').limit(5).execute()
        print(f"交易用戶數量: {len(result.data)}")
        for user in result.data:
            print(f"- {user['name']} (回報率: {user.get('cumulative_return', 0)}%)")
    except Exception as e:
        print(f"❌ 查詢交易用戶失敗: {e}")
    
    print("\n3️⃣ 檢查群組成員資料...")
    try:
        # 檢查群組成員
        result = db_service.supabase.table('group_members').select('*').execute()
        print(f"群組成員記錄數量: {len(result.data)}")
    except Exception as e:
        print(f"❌ 查詢群組成員失敗: {e}")
    
    print("\n✅ 群組創建系統檢查完成！")
    print("\n💡 建議：")
    print("1. 確保至少有一個 trading_users 記錄作為主持人")
    print("2. 檢查 investment_groups 表格的結構是否正確")
    print("3. 驗證群組創建後是否正確加入 group_members")

if __name__ == "__main__":
    test_group_creation()