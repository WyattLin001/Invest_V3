#!/usr/bin/env python3
"""
自動錦標賽架構遷移工具
無需用戶確認，自動執行遷移

使用方法:
    python auto_migration.py
"""

import sys
from datetime import datetime
from supabase import create_client, Client
import logging

# 設定日誌
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Supabase 配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

# 常量定義
GENERAL_MODE_TOURNAMENT_ID = "00000000-0000-0000-0000-000000000000"

def main():
    """主執行函數"""
    try:
        # 連接Supabase
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        logger.info("✅ Supabase 連接成功")
        
        # 1. 檢查並遷移 user_portfolios 表
        logger.info("🔄 開始遷移 user_portfolios 表...")
        
        # 查詢NULL記錄
        null_response = supabase.table("user_portfolios")\
            .select("id")\
            .is_("tournament_id", "null")\
            .execute()
        
        null_records = null_response.data if null_response.data else []
        
        if null_records:
            logger.info(f"發現 {len(null_records)} 筆需要遷移的記錄")
            
            # 批量更新
            batch_ids = [record["id"] for record in null_records]
            
            update_response = supabase.table("user_portfolios")\
                .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                .in_("id", batch_ids)\
                .execute()
            
            if update_response.data:
                logger.info(f"✅ 成功更新 {len(update_response.data)} 筆記錄")
            else:
                logger.warning("⚠️ 更新響應為空")
        else:
            logger.info("✅ user_portfolios 表無需遷移")
        
        # 2. 驗證遷移結果
        remaining_null = supabase.table("user_portfolios")\
            .select("id")\
            .is_("tournament_id", "null")\
            .execute()
        
        remaining_count = len(remaining_null.data) if remaining_null.data else 0
        
        if remaining_count == 0:
            logger.info("✅ user_portfolios 表遷移完成")
        else:
            logger.warning(f"⚠️ 還有 {remaining_count} 筆NULL記錄需要處理")
        
        # 3. 創建一般模式錦標賽記錄
        logger.info("🏗️ 檢查一般模式錦標賽記錄...")
        
        existing = supabase.table("tournaments")\
            .select("id")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        if existing.data:
            logger.info("✅ 一般模式錦標賽記錄已存在")
        else:
            logger.info("創建一般模式錦標賽記錄...")
            
            tournament_data = {
                "id": GENERAL_MODE_TOURNAMENT_ID,
                "name": "一般投資模式",
                "description": "系統內建的一般投資模式，無時間限制的永久投資環境",
                "status": "ongoing",
                "start_date": "2000-01-01T00:00:00Z",
                "end_date": "2099-12-31T23:59:59Z",
                "initial_balance": 1000000.00,
                "max_participants": 999999,
                "current_participants": 0,
                "created_by": "system",
                "created_at": datetime.now().isoformat()
            }
            
            result = supabase.table("tournaments").insert(tournament_data).execute()
            
            if result.data:
                logger.info("✅ 一般模式錦標賽記錄創建成功")
            else:
                logger.warning("⚠️ 創建一般模式錦標賽記錄失敗")
        
        # 4. 最終驗證
        logger.info("🔍 執行最終驗證...")
        
        # 檢查統一架構狀態
        general_records = supabase.table("user_portfolios")\
            .select("id")\
            .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        general_count = len(general_records.data) if general_records.data else 0
        
        remaining_null_final = supabase.table("user_portfolios")\
            .select("id")\
            .is_("tournament_id", "null")\
            .execute()
        
        null_count_final = len(remaining_null_final.data) if remaining_null_final.data else 0
        
        print("\n" + "="*60)
        print("🎯 遷移完成報告")
        print("="*60)
        print(f"時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print(f"一般模式記錄數: {general_count}")
        print(f"剩餘NULL記錄: {null_count_final}")
        
        if null_count_final == 0 and general_count > 0:
            print("✅ 統一錦標賽架構遷移成功完成！")
            print("🎉 系統現在使用統一的UUID架構")
        elif null_count_final == 0:
            print("✅ 數據庫已清理，準備好使用統一架構")
        else:
            print("⚠️ 部分記錄仍需手動處理")
        
        print("="*60)
        
        return null_count_final == 0
        
    except Exception as e:
        logger.error(f"❌ 遷移過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)