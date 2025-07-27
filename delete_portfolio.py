#\!/usr/bin/env python3
"""
安全刪除特定投資組合的腳本
目標：刪除 portfolio ID be5f2785-741e-455c-8a94-2bb2b510f76b 的所有相關數據
"""
import os
from supabase import create_client, Client

def main():
    # Supabase 配置 (需要替換為實際的值)
    url = "YOUR_SUPABASE_URL"
    key = "YOUR_SUPABASE_KEY"
    
    # 要刪除的投資組合 ID
    target_portfolio_id = "be5f2785-741e-455c-8a94-2bb2b510f76b"
    
    print(f"🗑️ 準備刪除投資組合: {target_portfolio_id}")
    print("⚠️ 此操作將刪除以下數據：")
    print("   1. user_positions (持倉記錄)")
    print("   2. portfolio_transactions (交易記錄)")
    print("   3. user_portfolios (投資組合主記錄)")
    
    confirmation = input("\n確定要繼續嗎？(輸入 'DELETE' 確認): ")
    if confirmation \!= "DELETE":
        print("❌ 操作已取消")
        return
    
    try:
        # 創建 Supabase 客戶端
        supabase: Client = create_client(url, key)
        
        # 步驟 1: 刪除持倉記錄
        print("\n📋 步驟 1: 刪除持倉記錄...")
        positions_result = supabase.table("user_positions").delete().eq("portfolio_id", target_portfolio_id).execute()
        print(f"✅ 已刪除 {len(positions_result.data)} 條持倉記錄")
        
        # 步驟 2: 獲取投資組合資訊以取得 user_id
        print("\n📋 步驟 2: 獲取投資組合資訊...")
        portfolio_result = supabase.table("user_portfolios").select("user_id").eq("id", target_portfolio_id).execute()
        
        if portfolio_result.data:
            user_id = portfolio_result.data[0]["user_id"]
            print(f"📍 找到用戶 ID: {user_id}")
            
            # 步驟 3: 刪除交易記錄
            print("\n📋 步驟 3: 刪除交易記錄...")
            transactions_result = supabase.table("portfolio_transactions").delete().eq("user_id", user_id).execute()
            print(f"✅ 已刪除 {len(transactions_result.data)} 條交易記錄")
        else:
            print("⚠️ 未找到投資組合，可能已被刪除")
        
        # 步驟 4: 刪除投資組合主記錄
        print("\n📋 步驟 4: 刪除投資組合主記錄...")
        portfolio_delete_result = supabase.table("user_portfolios").delete().eq("id", target_portfolio_id).execute()
        print(f"✅ 已刪除投資組合主記錄")
        
        print(f"\n🎉 投資組合 {target_portfolio_id} 已完全刪除")
        
    except Exception as e:
        print(f"❌ 刪除過程中發生錯誤: {e}")
        print("請檢查 Supabase 連接配置和權限")

if __name__ == "__main__":
    main()
EOF < /dev/null