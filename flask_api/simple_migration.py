#!/usr/bin/env python3
"""
簡化的錦標賽架構遷移工具
直接使用Supabase標準操作執行遷移

使用方法:
    python simple_migration.py [--execute] [--create-tournament]
"""

import sys
import argparse
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
TARGET_TABLES = ["portfolio_transactions", "portfolios", "user_portfolios"]

class SimpleMigration:
    def __init__(self):
        """初始化遷移工具"""
        try:
            self.supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
            logger.info("✅ Supabase 連接成功")
        except Exception as e:
            logger.error(f"❌ Supabase 連接失敗: {e}")
            sys.exit(1)
    
    def check_migration_status(self):
        """檢查遷移狀態"""
        logger.info("🔍 檢查當前遷移狀態...")
        
        migration_status = {}
        
        for table in TARGET_TABLES:
            try:
                # 查詢NULL記錄
                null_response = self.supabase.table(table)\
                    .select("id, tournament_id")\
                    .is_("tournament_id", "null")\
                    .execute()
                
                null_records = null_response.data if null_response.data else []
                
                # 查詢一般模式記錄
                general_response = self.supabase.table(table)\
                    .select("id, tournament_id")\
                    .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
                    .execute()
                
                general_records = general_response.data if general_response.data else []
                
                migration_status[table] = {
                    "null_records": len(null_records),
                    "null_record_ids": [r["id"] for r in null_records[:10]],  # 前10筆
                    "general_mode_records": len(general_records),
                    "needs_migration": len(null_records) > 0
                }
                
                logger.info(f"📊 {table}: NULL記錄 {len(null_records)}, 一般模式記錄 {len(general_records)}")
                
            except Exception as e:
                logger.error(f"❌ 檢查 {table} 失敗: {e}")
                migration_status[table] = {"error": str(e)}
        
        return migration_status
    
    def execute_migration(self):
        """執行遷移"""
        logger.info("🔄 開始執行錦標賽統一架構遷移...")
        
        migration_results = {}
        
        for table in TARGET_TABLES:
            try:
                logger.info(f"處理表格: {table}")
                
                # 查詢所有NULL記錄
                null_response = self.supabase.table(table)\
                    .select("id")\
                    .is_("tournament_id", "null")\
                    .execute()
                
                null_records = null_response.data if null_response.data else []
                
                if null_records:
                    logger.info(f"發現 {len(null_records)} 筆需要遷移的記錄")
                    
                    # 批量更新 - 分批處理以避免超時
                    batch_size = 100
                    updated_count = 0
                    
                    for i in range(0, len(null_records), batch_size):
                        batch = null_records[i:i + batch_size]
                        batch_ids = [record["id"] for record in batch]
                        
                        # 執行批量更新
                        update_response = self.supabase.table(table)\
                            .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                            .in_("id", batch_ids)\
                            .execute()
                        
                        if update_response.data:
                            updated_count += len(update_response.data)
                            logger.info(f"批次更新 {len(update_response.data)} 筆記錄")
                    
                    # 驗證遷移結果
                    remaining_null = self.supabase.table(table)\
                        .select("id")\
                        .is_("tournament_id", "null")\
                        .execute()
                    
                    remaining_count = len(remaining_null.data) if remaining_null.data else 0
                    
                    migration_results[table] = {
                        "original_null_count": len(null_records),
                        "updated_count": updated_count,
                        "remaining_null_count": remaining_count,
                        "success": remaining_count == 0
                    }
                    
                    if remaining_count == 0:
                        logger.info(f"✅ {table} 遷移成功: {updated_count} 筆記錄")
                    else:
                        logger.warning(f"⚠️ {table} 部分遷移: 還有 {remaining_count} 筆NULL記錄")
                else:
                    migration_results[table] = {
                        "original_null_count": 0,
                        "updated_count": 0,
                        "remaining_null_count": 0,
                        "success": True
                    }
                    logger.info(f"✅ {table} 無需遷移: 沒有NULL記錄")
                    
            except Exception as e:
                logger.error(f"❌ {table} 遷移失敗: {e}")
                migration_results[table] = {"error": str(e), "success": False}
        
        return migration_results
    
    def create_general_tournament_record(self):
        """創建一般模式錦標賽記錄"""
        logger.info("🏗️ 創建一般模式錦標賽記錄...")
        
        try:
            # 檢查是否已存在
            existing = self.supabase.table("tournaments")\
                .select("id")\
                .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
                .execute()
            
            if existing.data:
                logger.info("✅ 一般模式錦標賽記錄已存在")
                return True
            
            # 創建新記錄
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
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }
            
            result = self.supabase.table("tournaments").insert(tournament_data).execute()
            
            if result.data:
                logger.info("✅ 一般模式錦標賽記錄創建成功")
                return True
            else:
                logger.error("❌ 創建一般模式錦標賽記錄失敗")
                return False
                
        except Exception as e:
            logger.error(f"❌ 創建一般模式錦標賽記錄失敗: {e}")
            return False
    
    def generate_migration_report(self, migration_results):
        """生成遷移報告"""
        print("\n" + "="*80)
        print("錦標賽統一架構遷移報告")
        print("="*80)
        print(f"遷移時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"目標UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        
        print("\n📊 遷移結果:")
        print("-"*60)
        
        total_migrated = 0
        all_success = True
        
        for table, result in migration_results.items():
            if "error" in result:
                print(f"❌ {table}: 遷移失敗 - {result['error']}")
                all_success = False
            else:
                original_count = result["original_null_count"]
                updated_count = result["updated_count"]
                remaining_count = result["remaining_null_count"]
                success = result["success"]
                
                status = "✅" if success else "⚠️"
                print(f"{status} {table}:")
                print(f"   原始NULL記錄: {original_count}")
                print(f"   已更新記錄: {updated_count}")
                print(f"   剩餘NULL記錄: {remaining_count}")
                
                total_migrated += updated_count
                if not success:
                    all_success = False
        
        print("\n" + "="*80)
        print("🎯 遷移總結:")
        
        if all_success:
            print(f"✅ 遷移完全成功！總計遷移 {total_migrated} 筆記錄")
            print("🎉 系統現在使用統一錦標賽架構")
        else:
            print(f"⚠️ 遷移部分成功：{total_migrated} 筆記錄已遷移")
            print("💡 建議檢查失敗的項目並重新執行")
        
        print("="*80)
        
        return all_success


def main():
    parser = argparse.ArgumentParser(description='簡化錦標賽架構遷移工具')
    parser.add_argument('--execute', action='store_true', help='執行實際遷移（否則只檢查狀態）')
    parser.add_argument('--create-tournament', action='store_true', help='創建一般模式錦標賽記錄')
    
    args = parser.parse_args()
    
    migration = SimpleMigration()
    
    try:
        # 檢查當前狀態
        status = migration.check_migration_status()
        
        # 檢查是否需要遷移
        needs_migration = any(
            table_status.get("needs_migration", False)
            for table_status in status.values()
            if "error" not in table_status
        )
        
        if args.execute:
            if needs_migration:
                logger.info("🚀 開始執行遷移...")
                
                # 確認執行
                confirmation = input("確定要執行遷移嗎？這會將NULL的tournament_id更改為固定UUID (y/N): ")
                if confirmation.lower() != 'y':
                    logger.info("❌ 遷移已取消")
                    return
                
                # 執行遷移
                results = migration.execute_migration()
                success = migration.generate_migration_report(results)
                
                # 創建錦標賽記錄（如果需要）
                if args.create_tournament:
                    migration.create_general_tournament_record()
                
                sys.exit(0 if success else 1)
                
            else:
                logger.info("✅ 系統已經使用統一架構，無需遷移")
                
                if args.create_tournament:
                    migration.create_general_tournament_record()
                
        else:
            # 只檢查狀態
            if needs_migration:
                logger.info("💡 系統需要遷移，使用 --execute 參數執行遷移")
            else:
                logger.info("✅ 系統已使用統一架構")
            
            if args.create_tournament:
                migration.create_general_tournament_record()
        
    except KeyboardInterrupt:
        logger.info("遷移被用戶中斷")
        sys.exit(1)
    except Exception as e:
        logger.error(f"遷移過程發生錯誤: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()