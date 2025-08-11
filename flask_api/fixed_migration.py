#!/usr/bin/env python3
"""
修復的錦標賽架構遷移工具
先創建錦標賽記錄，再執行遷移

使用方法:
    python fixed_migration.py
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
        
        # 步驟1: 先創建一般模式錦標賽記錄
        logger.info("🏗️ 步驟1: 創建一般模式錦標賽記錄...")
        
        # 檢查是否已存在
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
                logger.error("❌ 創建一般模式錦標賽記錄失敗")
                return False
        
        # 步驟2: 遷移 user_portfolios 表
        logger.info("🔄 步驟2: 遷移 user_portfolios 表...")
        
        # 查詢NULL記錄
        null_response = supabase.table("user_portfolios")\
            .select("id")\
            .is_("tournament_id", "null")\
            .execute()
        
        null_records = null_response.data if null_response.data else []
        
        if null_records:
            logger.info(f"發現 {len(null_records)} 筆需要遷移的記錄")
            
            # 逐筆更新以避免批量操作問題
            updated_count = 0
            for record in null_records:
                try:
                    update_response = supabase.table("user_portfolios")\
                        .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                        .eq("id", record["id"])\
                        .execute()
                    
                    if update_response.data:
                        updated_count += 1
                        
                except Exception as e:
                    logger.error(f"更新記錄 {record['id']} 失敗: {e}")
            
            logger.info(f"✅ 成功更新 {updated_count} / {len(null_records)} 筆記錄")
        else:
            logger.info("✅ user_portfolios 表無需遷移")
        
        # 步驟3: 處理其他表格（如果有數據）
        for table in ["portfolio_transactions", "portfolios"]:
            logger.info(f"🔄 步驟3: 檢查 {table} 表...")
            
            null_response = supabase.table(table)\
                .select("id")\
                .is_("tournament_id", "null")\
                .execute()
            
            null_records = null_response.data if null_response.data else []
            
            if null_records:
                logger.info(f"{table}: 發現 {len(null_records)} 筆需要遷移的記錄")
                
                updated_count = 0
                for record in null_records:
                    try:
                        update_response = supabase.table(table)\
                            .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                            .eq("id", record["id"])\
                            .execute()
                        
                        if update_response.data:
                            updated_count += 1
                            
                    except Exception as e:
                        logger.error(f"更新 {table} 記錄 {record['id']} 失敗: {e}")
                
                logger.info(f"✅ {table}: 成功更新 {updated_count} / {len(null_records)} 筆記錄")
            else:
                logger.info(f"✅ {table} 表無需遷移")
        
        # 步驟4: 最終驗證
        logger.info("🔍 步驟4: 執行最終驗證...")
        
        total_general_records = 0
        total_null_records = 0
        
        for table in ["user_portfolios", "portfolio_transactions", "portfolios"]:
            # 檢查一般模式記錄
            general_records = supabase.table(table)\
                .select("id")\
                .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
                .execute()
            
            general_count = len(general_records.data) if general_records.data else 0
            total_general_records += general_count
            
            # 檢查剩餘NULL記錄
            null_records = supabase.table(table)\
                .select("id")\
                .is_("tournament_id", "null")\
                .execute()
            
            null_count = len(null_records.data) if null_records.data else 0
            total_null_records += null_count
            
            logger.info(f"📊 {table}: 一般模式 {general_count}, NULL {null_count}")
        
        print("\n" + "="*80)
        print("🎯 錦標賽統一架構遷移完成報告")
        print("="*80)
        print(f"遷移時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print("-"*60)
        print(f"📊 遷移結果:")
        print(f"   一般模式記錄總數: {total_general_records}")
        print(f"   剩餘NULL記錄: {total_null_records}")
        
        if total_null_records == 0:
            print("\n✅ 遷移完全成功！")
            print("🎉 系統現在完全使用統一的UUID架構")
            print("📱 前端iOS應用可以正常使用統一架構")
            print("🔧 後端Flask API已準備好處理統一架構")
        else:
            print(f"\n⚠️ 部分成功: 還有 {total_null_records} 筆NULL記錄")
            print("💡 建議檢查權限或手動處理剩餘記錄")
        
        print("="*80)
        
        return total_null_records == 0
        
    except Exception as e:
        logger.error(f"❌ 遷移過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)