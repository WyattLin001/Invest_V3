#!/usr/bin/env python3
"""
最終錦標賽架構遷移工具
修復創建錦標賽記錄的數據類型問題

使用方法:
    python final_migration.py
"""

import sys
import uuid
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
SYSTEM_USER_ID = "d64a0edd-62cc-423a-8ce4-81103b5a9770"  # 使用測試用戶作為系統用戶

def main():
    """主執行函數"""
    try:
        # 連接Supabase
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        logger.info("✅ Supabase 連接成功")
        
        # 步驟1: 創建一般模式錦標賽記錄
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
                "type": "permanent",
                "status": "ongoing",
                "start_date": "2000-01-01T00:00:00+00:00",
                "end_date": "2099-12-31T23:59:59+00:00",
                "description": "系統內建的一般投資模式，無時間限制的永久投資環境。用戶可以在此模式下自由練習投資策略，無競賽壓力。",
                "short_description": "系統內建的永久投資練習環境",
                "initial_balance": 1000000,
                "max_participants": 999999,
                "current_participants": 0,
                "entry_fee": 0,
                "prize_pool": 0,
                "risk_limit_percentage": 100,  # 一般模式無特殊風險限制
                "min_holding_rate": 0,  # 一般模式無最低持股要求
                "max_single_stock_rate": 100,  # 一般模式無最大持股限制
                "rules": ["一般投資模式無特殊限制", "可自由練習各種投資策略", "無競賽時間壓力"],
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "is_featured": False,
                "created_by": SYSTEM_USER_ID  # 使用有效的UUID
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
            failed_count = 0
            
            for record in null_records:
                try:
                    update_response = supabase.table("user_portfolios")\
                        .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                        .eq("id", record["id"])\
                        .execute()
                    
                    if update_response.data:
                        updated_count += 1
                    else:
                        failed_count += 1
                        
                except Exception as e:
                    logger.error(f"更新記錄 {record['id']} 失敗: {e}")
                    failed_count += 1
            
            logger.info(f"✅ user_portfolios: 成功更新 {updated_count} 筆, 失敗 {failed_count} 筆")
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
                failed_count = 0
                
                for record in null_records:
                    try:
                        update_response = supabase.table(table)\
                            .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                            .eq("id", record["id"])\
                            .execute()
                        
                        if update_response.data:
                            updated_count += 1
                        else:
                            failed_count += 1
                            
                    except Exception as e:
                        logger.error(f"更新 {table} 記錄 {record['id']} 失敗: {e}")
                        failed_count += 1
                
                logger.info(f"✅ {table}: 成功更新 {updated_count} 筆, 失敗 {failed_count} 筆")
            else:
                logger.info(f"✅ {table} 表無需遷移")
        
        # 步驟4: 最終驗證
        logger.info("🔍 步驟4: 執行最終驗證...")
        
        total_general_records = 0
        total_null_records = 0
        table_results = {}
        
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
            
            table_results[table] = {
                "general_mode": general_count,
                "null_records": null_count
            }
            
            logger.info(f"📊 {table}: 一般模式 {general_count}, NULL {null_count}")
        
        # 驗證錦標賽記錄
        tournament_check = supabase.table("tournaments")\
            .select("id, name")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        tournament_exists = len(tournament_check.data) > 0 if tournament_check.data else False
        
        print("\n" + "="*80)
        print("🎯 錦標賽統一架構遷移完成報告")
        print("="*80)
        print(f"遷移時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print("-"*60)
        print(f"📊 錦標賽記錄: {'✅ 存在' if tournament_exists else '❌ 不存在'}")
        print(f"📊 數據遷移結果:")
        
        for table, result in table_results.items():
            print(f"   {table}:")
            print(f"     一般模式記錄: {result['general_mode']}")
            print(f"     NULL記錄: {result['null_records']}")
        
        print(f"\n📈 總計:")
        print(f"   一般模式記錄總數: {total_general_records}")
        print(f"   剩餘NULL記錄: {total_null_records}")
        
        if total_null_records == 0 and tournament_exists:
            print("\n🎉 遷移完全成功！")
            print("✅ 系統現在完全使用統一的UUID架構")
            print("📱 iOS前端: 使用相同的GENERAL_MODE_TOURNAMENT_ID常量")
            print("🔧 Flask後端: 統一處理一般模式和錦標賽模式")
            print("🗄️ 數據庫: 所有記錄都有明確的tournament_id")
            print("\n🚀 系統已準備就緒，可以開始測試API功能！")
        elif total_null_records == 0:
            print("\n✅ 數據遷移成功！")
            print("⚠️ 但一般模式錦標賽記錄可能需要手動檢查")
        else:
            print(f"\n⚠️ 部分成功: 還有 {total_null_records} 筆NULL記錄")
            print("💡 建議檢查權限或手動處理剩餘記錄")
        
        print("="*80)
        
        return total_null_records == 0 and tournament_exists
        
    except Exception as e:
        logger.error(f"❌ 遷移過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)