#!/usr/bin/env python3
"""
調試記錄值以了解tournament_id的實際內容
"""

from supabase import create_client, Client
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Supabase 配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def main():
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        logger.info("✅ Supabase 連接成功")
        
        # 查看具體的記錄值
        logger.info("🔍 查看問題記錄的具體值...")
        
        # 查看所有記錄，包括tournament_id值
        all_records = supabase.table("user_portfolios")\
            .select("id, user_id, tournament_id")\
            .execute()
        
        if all_records.data:
            print("\n📊 所有user_portfolios記錄:")
            print("-" * 80)
            for i, record in enumerate(all_records.data):
                tournament_id = record.get('tournament_id')
                print(f"{i+1}. ID: {record.get('id', 'N/A')}")
                print(f"   用戶ID: {record.get('user_id', 'N/A')}")
                print(f"   錦標賽ID: {repr(tournament_id)} (類型: {type(tournament_id)})")
                print(f"   是否為None: {tournament_id is None}")
                print(f"   是否為空字符串: {tournament_id == ''}")
                print(f"   長度: {len(tournament_id) if tournament_id else 'N/A'}")
                print("-" * 40)
                
        # 使用RPC功能執行原生SQL查詢來獲取真實數據
        try:
            logger.info("🔍 嘗試使用SQL查詢...")
            # 使用Supabase的rpc功能執行原生查詢
            result = supabase.rpc('get_null_tournament_records').execute()
            if result.data:
                print(f"\nSQL查詢結果: {result.data}")
        except Exception as e:
            logger.info(f"SQL查詢不可用: {e}")
            
        # 嘗試手動更新單個記錄進行測試
        if all_records.data:
            test_record = all_records.data[0]
            logger.info(f"🧪 測試更新記錄: {test_record['id']}")
            
            try:
                # 首先嘗試將tournament_id設為空字符串，然後更新為目標UUID
                result = supabase.table("user_portfolios")\
                    .update({"tournament_id": "00000000-0000-0000-0000-000000000000"})\
                    .eq("id", test_record['id'])\
                    .is_("tournament_id", "null")\
                    .execute()
                
                if result.data:
                    logger.info("✅ 測試更新成功！")
                    print(f"更新結果: {result.data}")
                else:
                    logger.info("⚠️ 測試更新沒有返回數據")
                    
                # 驗證更新結果
                verify = supabase.table("user_portfolios")\
                    .select("id, tournament_id")\
                    .eq("id", test_record['id'])\
                    .execute()
                
                if verify.data:
                    print(f"驗證結果: {verify.data[0]}")
                    
            except Exception as e:
                logger.error(f"測試更新失敗: {e}")
        
    except Exception as e:
        logger.error(f"❌ 調試失敗: {e}")

if __name__ == "__main__":
    main()