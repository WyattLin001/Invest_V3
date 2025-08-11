#!/usr/bin/env python3
"""
檢查錦標賽表結構和現有記錄
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
        
        # 查看現有錦標賽記錄
        logger.info("🔍 查看現有錦標賽記錄...")
        tournaments = supabase.table("tournaments")\
            .select("id, name, type, status, created_by")\
            .limit(5)\
            .execute()
        
        if tournaments.data:
            print("\n📊 現有錦標賽記錄:")
            print("-" * 60)
            for tournament in tournaments.data:
                print(f"ID: {tournament.get('id', 'N/A')}")
                print(f"名稱: {tournament.get('name', 'N/A')}")
                print(f"類型: {tournament.get('type', 'N/A')}")
                print(f"狀態: {tournament.get('status', 'N/A')}")
                print(f"創建者: {tournament.get('created_by', 'N/A')}")
                print("-" * 30)
        else:
            print("❌ 沒有找到現有錦標賽記錄")
        
        # 檢查user_profiles表中的用戶
        logger.info("🔍 查看用戶配置文件...")
        users = supabase.table("user_profiles")\
            .select("id, username")\
            .limit(3)\
            .execute()
        
        if users.data:
            print("\n👥 現有用戶:")
            print("-" * 40)
            for user in users.data:
                print(f"用戶ID: {user.get('id', 'N/A')}")
                print(f"用戶名: {user.get('username', 'N/A')}")
                print("-" * 20)
        
    except Exception as e:
        logger.error(f"❌ 查詢失敗: {e}")

if __name__ == "__main__":
    main()