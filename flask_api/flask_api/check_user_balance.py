#!/usr/bin/env python3
"""
檢查用戶餘額
"""

from supabase import create_client, Client
import json

# Supabase配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def check_user_balance():
    """檢查用戶餘額"""
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
        
        print("🔍 檢查用戶餘額")
        print("=" * 50)
        
        # 檢查 user_balances 表
        print(f"1️⃣ 檢查 user_balances 表:")
        balance_result = supabase.table("user_balances")\
            .select("*")\
            .eq("user_id", user_id)\
            .execute()
        
        if balance_result.data:
            balance_record = balance_result.data[0]
            print(f"   - 用戶ID: {balance_record.get('user_id')}")
            print(f"   - 餘額: NT${balance_record.get('balance', 0):,.2f}")
            print(f"   - 更新時間: {balance_record.get('updated_at', 'N/A')}")
        else:
            print("   - ❌ user_balances 表中沒有此用戶記錄")
            
            # 嘗試創建用戶餘額記錄
            print("\n2️⃣ 創建用戶餘額記錄:")
            new_balance = {
                "user_id": user_id,
                "balance": 100000
            }
            
            create_result = supabase.table("user_balances").insert(new_balance).execute()
            if create_result.data:
                print("   - ✅ 用戶餘額記錄創建成功")
                print(f"   - 初始餘額: NT$100,000")
            else:
                print("   - ❌ 用戶餘額記錄創建失敗")
        
        return True
        
    except Exception as e:
        print(f"❌ 檢查失敗: {e}")
        return False

if __name__ == "__main__":
    check_user_balance()