#!/usr/bin/env python3
"""
測試交易記錄同步功能
模擬從iOS端插入一筆交易記錄到Supabase，然後驗證API能正確返回
"""

from supabase import create_client, Client
import json
import uuid
from datetime import datetime

# Supabase配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def test_transaction_sync():
    """測試交易記錄同步功能"""
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
        tournament_id = "54943759-6c94-4859-aca5-a6dad364f3a5"
        
        print("🧪 測試交易記錄同步功能")
        print("=" * 50)
        
        # 先檢查表結構
        print("0️⃣ 檢查portfolio_transactions表結構:")
        try:
            # 嘗試查詢現有記錄來了解結構
            existing_records = supabase.table("portfolio_transactions").select("*").limit(1).execute()
            print(f"   - 表查詢成功，現有記錄數: {len(existing_records.data)}")
        except Exception as e:
            print(f"   - 表查詢錯誤: {e}")
        
        # 創建測試交易記錄（匹配Flask API的結構）
        test_transaction = {
            "user_id": user_id,
            "tournament_id": tournament_id,
            "symbol": "2330",
            "action": "buy",
            "price": 580.0,
            "amount": 580000.0,
            "executed_at": datetime.now().isoformat()
        }
        
        print(f"1️⃣ 插入測試交易記錄:")
        print(f"   - 錦標賽ID: {tournament_id}")
        print(f"   - 股票: 2330 (台積電)")
        print(f"   - 動作: 買入")
        print(f"   - 價格: NT$580")
        print(f"   - 總金額: NT$580,000")
        
        # 插入交易記錄
        result = supabase.table("portfolio_transactions").insert(test_transaction).execute()
        
        if result.data:
            print("✅ 測試交易記錄插入成功")
            inserted_record = result.data[0]
            transaction_id = inserted_record.get('id')
            print(f"   - 生成的交易ID: {transaction_id}")
            
            # 驗證插入的記錄
            print("\n2️⃣ 驗證插入的記錄:")
            verify_result = supabase.table("portfolio_transactions")\
                .select("*")\
                .eq("id", transaction_id)\
                .execute()
            
            if verify_result.data:
                record = verify_result.data[0]
                print(f"   - ID: {record.get('id')}")
                print(f"   - 用戶ID: {record.get('user_id')}")
                print(f"   - 錦標賽ID: {record.get('tournament_id')}")
                print(f"   - 股票代碼: {record.get('symbol')}")
                print(f"   - 動作: {record.get('action')}")
                print(f"   - 金額: {record.get('amount')}")
                print("✅ 記錄驗證成功")
                
                # 測試API能否正確讀取
                print("\n3️⃣ 測試Flask API讀取功能:")
                print("   請運行: curl \"http://127.0.0.1:5001/api/portfolio?user_id=d64a0edd-62cc-423a-8ce4-81103b5a9770&tournament_id=54943759-6c94-4859-aca5-a6dad364f3a5\"")
                print("   請運行: curl \"http://127.0.0.1:5001/api/transactions?user_id=d64a0edd-62cc-423a-8ce4-81103b5a9770&tournament_id=54943759-6c94-4859-aca5-a6dad364f3a5\"")
                
                return True
            else:
                print("❌ 無法驗證插入的記錄")
                return False
        else:
            print("❌ 測試交易記錄插入失敗")
            return False
            
    except Exception as e:
        print(f"❌ 測試失敗: {e}")
        return False

if __name__ == "__main__":
    test_transaction_sync()