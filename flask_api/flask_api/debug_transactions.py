#!/usr/bin/env python3
"""
調試交易記錄數據，找出iOS顯示的交易數據來源
"""

from supabase import create_client, Client
import json

# Supabase配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def debug_transactions():
    """調試交易記錄數據"""
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
        
        print("🔍 調試交易記錄數據源")
        print("=" * 50)
        
        # 1. 檢查所有用戶的交易記錄（不過濾錦標賽）
        print(f"1️⃣ 檢查用戶 {user_id} 的所有交易記錄:")
        all_transactions = supabase.table("portfolio_transactions")\
            .select("*")\
            .eq("user_id", user_id)\
            .execute()
        
        print(f"   總交易數量: {len(all_transactions.data)}")
        for tx in all_transactions.data:
            tournament_id = tx.get("tournament_id", "None")
            symbol = tx.get("symbol", "N/A")
            action = tx.get("action", "N/A")
            amount = tx.get("amount", 0)
            executed_at = tx.get("executed_at", "N/A")
            print(f"   - {executed_at}: {symbol} {action} ${amount} (錦標賽: {tournament_id})")
        
        # 2. 檢查Q4錦標賽ID對應的交易
        q4_tournament_id = "54943759-6c94-4859-aca5-a6dad364f3a5"
        print(f"\n2️⃣ 檢查Q4錦標賽 ({q4_tournament_id}) 的交易記錄:")
        q4_transactions = supabase.table("portfolio_transactions")\
            .select("*")\
            .eq("user_id", user_id)\
            .eq("tournament_id", q4_tournament_id)\
            .execute()
        
        print(f"   Q4錦標賽交易數量: {len(q4_transactions.data)}")
        for tx in q4_transactions.data:
            symbol = tx.get("symbol", "N/A")
            action = tx.get("action", "N/A")
            amount = tx.get("amount", 0)
            executed_at = tx.get("executed_at", "N/A")
            print(f"   - {executed_at}: {symbol} {action} ${amount}")
        
        # 3. 檢查NULL錦標賽ID的交易（一般模式）
        print(f"\n3️⃣ 檢查一般模式（錦標賽ID為NULL）的交易記錄:")
        general_transactions = supabase.table("portfolio_transactions")\
            .select("*")\
            .eq("user_id", user_id)\
            .is_("tournament_id", "null")\
            .execute()
        
        print(f"   一般模式交易數量: {len(general_transactions.data)}")
        for tx in general_transactions.data:
            symbol = tx.get("symbol", "N/A")
            action = tx.get("action", "N/A")
            amount = tx.get("amount", 0)
            executed_at = tx.get("executed_at", "N/A")
            print(f"   - {executed_at}: {symbol} {action} ${amount}")
        
        # 4. 檢查是否有2201裕隆和0050的交易
        print(f"\n4️⃣ 搜索2201裕隆和0050的交易記錄:")
        target_symbols = ["2201", "0050", "2201.TW", "0050.TW"]
        for symbol in target_symbols:
            symbol_transactions = supabase.table("portfolio_transactions")\
                .select("*")\
                .eq("user_id", user_id)\
                .eq("symbol", symbol)\
                .execute()
            
            if symbol_transactions.data:
                print(f"   找到 {symbol} 的交易:")
                for tx in symbol_transactions.data:
                    tournament_id = tx.get("tournament_id", "None")
                    action = tx.get("action", "N/A")
                    amount = tx.get("amount", 0)
                    executed_at = tx.get("executed_at", "N/A")
                    print(f"     - {executed_at}: {action} ${amount} (錦標賽: {tournament_id})")
            else:
                print(f"   沒有找到 {symbol} 的交易記錄")
        
        # 5. 檢查所有可能的錦標賽ID
        print(f"\n5️⃣ 分析所有錦標賽ID:")
        tournament_stats = {}
        for tx in all_transactions.data:
            tournament_id = tx.get("tournament_id", "NULL")
            if tournament_id not in tournament_stats:
                tournament_stats[tournament_id] = 0
            tournament_stats[tournament_id] += 1
        
        for tid, count in tournament_stats.items():
            print(f"   錦標賽 {tid}: {count} 筆交易")
        
        return True
        
    except Exception as e:
        print(f"❌ 調試失敗: {e}")
        return False

if __name__ == "__main__":
    debug_transactions()