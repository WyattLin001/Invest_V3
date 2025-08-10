#!/usr/bin/env python3
"""
查找有效的用戶ID
"""

from supabase import create_client, Client
import json

# Supabase配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def find_valid_user():
    """查找有效的用戶ID"""
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        
        print("🔍 查找有效的用戶ID")
        print("=" * 50)
        
        # 檢查 user_profiles 表
        print(f"1️⃣ 檢查 user_profiles 表:")
        profiles_result = supabase.table("user_profiles")\
            .select("id, username, email")\
            .limit(5)\
            .execute()
        
        if profiles_result.data:
            print(f"   找到 {len(profiles_result.data)} 個用戶:")
            for i, profile in enumerate(profiles_result.data):
                print(f"   [{i+1}] ID: {profile.get('id')}")
                print(f"       用戶名: {profile.get('username', 'N/A')}")
                print(f"       郵箱: {profile.get('email', 'N/A')}")
                
                # 檢查這個用戶是否有餘額記錄
                balance_result = supabase.table("user_balances")\
                    .select("*")\
                    .eq("user_id", profile.get('id'))\
                    .execute()
                
                if balance_result.data:
                    balance = balance_result.data[0].get('balance', 0)
                    print(f"       餘額: NT${balance:,}")
                else:
                    print(f"       餘額: 未設置")
                print()
        else:
            print("   - ❌ user_profiles 表中沒有用戶記錄")
        
        return True
        
    except Exception as e:
        print(f"❌ 查找失敗: {e}")
        return False

if __name__ == "__main__":
    find_valid_user()