#!/usr/bin/env python3
"""
錦標賽統一架構遷移執行腳本
將一般模式的 NULL tournament_id 轉換為固定 UUID

使用方法:
    python execute_migration.py [--dry-run] [--backup] [--rollback]
    
選項:
    --dry-run    : 只查詢當前狀態，不執行遷移
    --backup     : 創建完整備份（包含所有表）
    --rollback   : 執行回滾操作
"""

import os
import sys
import argparse
from datetime import datetime
from supabase import create_client, Client
import logging

# 設定日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Supabase 配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

# 常量定義
GENERAL_MODE_TOURNAMENT_ID = "00000000-0000-0000-0000-000000000000"
TARGET_TABLES = ["portfolio_transactions", "portfolios", "user_portfolios"]

class TournamentMigration:
    def __init__(self):
        """初始化遷移工具"""
        try:
            self.supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
            logger.info("✅ Supabase 連接成功")
        except Exception as e:
            logger.error(f"❌ Supabase 連接失敗: {e}")
            sys.exit(1)
    
    def check_current_status(self):
        """檢查當前數據狀態"""
        logger.info("🔍 檢查當前數據狀態...")
        
        status_report = {
            "timestamp": datetime.now().isoformat(),
            "tables": {}
        }
        
        for table in TARGET_TABLES:
            try:
                # 查詢 NULL 記錄
                null_response = self.supabase.rpc(
                    'execute_sql',
                    {"query": f"SELECT COUNT(*) as count FROM {table} WHERE tournament_id IS NULL"}
                ).execute()
                null_count = null_response.data[0]['count'] if null_response.data else 0
                
                # 查詢一般模式記錄
                general_response = self.supabase.rpc(
                    'execute_sql', 
                    {"query": f"SELECT COUNT(*) as count FROM {table} WHERE tournament_id = '{GENERAL_MODE_TOURNAMENT_ID}'"}
                ).execute()
                general_count = general_response.data[0]['count'] if general_response.data else 0
                
                # 查詢總記錄數
                total_response = self.supabase.rpc(
                    'execute_sql',
                    {"query": f"SELECT COUNT(*) as count FROM {table}"}
                ).execute()
                total_count = total_response.data[0]['count'] if total_response.data else 0
                
                status_report["tables"][table] = {
                    "total_records": total_count,
                    "null_tournament_id": null_count,
                    "general_mode_records": general_count,
                    "needs_migration": null_count > 0
                }
                
                logger.info(f"📊 {table}: 總計 {total_count}, NULL {null_count}, 一般模式 {general_count}")
                
            except Exception as e:
                logger.error(f"❌ 查詢 {table} 失敗: {e}")
                status_report["tables"][table] = {"error": str(e)}
        
        return status_report
    
    def create_backup(self):
        """創建數據備份"""
        logger.info("💾 創建數據備份...")
        
        backup_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        for table in TARGET_TABLES:
            try:
                # 創建備份表
                backup_table = f"migration_backup_{table}_{backup_timestamp}"
                backup_query = f"""
                CREATE TABLE {backup_table} AS 
                SELECT * FROM {table} WHERE tournament_id IS NULL
                """
                
                self.supabase.rpc('execute_sql', {"query": backup_query}).execute()
                logger.info(f"✅ 備份 {table} 到 {backup_table}")
                
            except Exception as e:
                logger.error(f"❌ 備份 {table} 失敗: {e}")
                raise
    
    def execute_migration(self):
        """執行遷移"""
        logger.info("🔄 開始執行遷移...")
        
        migration_results = {}
        
        for table in TARGET_TABLES:
            try:
                # 更新 NULL 記錄為固定 UUID
                update_query = f"""
                UPDATE {table} 
                SET tournament_id = '{GENERAL_MODE_TOURNAMENT_ID}'
                WHERE tournament_id IS NULL
                """
                
                result = self.supabase.rpc('execute_sql', {"query": update_query}).execute()
                
                # 驗證更新結果
                verify_query = f"""
                SELECT COUNT(*) as count FROM {table} 
                WHERE tournament_id IS NULL
                """
                verify_result = self.supabase.rpc('execute_sql', {"query": verify_query}).execute()
                remaining_null = verify_result.data[0]['count'] if verify_result.data else -1
                
                migration_results[table] = {
                    "status": "success",
                    "remaining_null_records": remaining_null
                }
                
                logger.info(f"✅ {table} 遷移完成，剩餘 NULL 記錄: {remaining_null}")
                
            except Exception as e:
                logger.error(f"❌ {table} 遷移失敗: {e}")
                migration_results[table] = {"status": "failed", "error": str(e)}
                raise
        
        return migration_results
    
    def create_general_tournament(self):
        """創建一般模式錦標賽記錄"""
        logger.info("🏗️ 創建一般模式錦標賽記錄...")
        
        try:
            tournament_data = {
                "id": GENERAL_MODE_TOURNAMENT_ID,
                "name": "一般投資模式",
                "description": "系統內建的一般投資模式，無時間限制的永久投資環境",
                "status": "ongoing",
                "start_date": "2000-01-01T00:00:00Z",
                "end_date": "2099-12-31T23:59:59Z",
                "initial_balance": 1000000.00,
                "max_participants": 999999,
                "created_by": "system",
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }
            
            # 使用 upsert 避免重複插入
            self.supabase.table("tournaments").upsert(tournament_data).execute()
            logger.info("✅ 一般模式錦標賽記錄創建成功")
            
        except Exception as e:
            logger.error(f"❌ 創建一般模式錦標賽記錄失敗: {e}")
            # 這不是致命錯誤，遷移可以繼續
    
    def verify_migration(self):
        """驗證遷移結果"""
        logger.info("🔍 驗證遷移結果...")
        
        verification_results = {}
        
        for table in TARGET_TABLES:
            try:
                # 檢查是否還有 NULL 記錄
                null_query = f"SELECT COUNT(*) as count FROM {table} WHERE tournament_id IS NULL"
                null_result = self.supabase.rpc('execute_sql', {"query": null_query}).execute()
                null_count = null_result.data[0]['count'] if null_result.data else -1
                
                # 檢查一般模式記錄數量
                general_query = f"""
                SELECT COUNT(*) as count, COUNT(DISTINCT user_id) as unique_users 
                FROM {table} WHERE tournament_id = '{GENERAL_MODE_TOURNAMENT_ID}'
                """
                general_result = self.supabase.rpc('execute_sql', {"query": general_query}).execute()
                
                if general_result.data:
                    general_count = general_result.data[0]['count']
                    unique_users = general_result.data[0]['unique_users']
                else:
                    general_count = -1
                    unique_users = -1
                
                verification_results[table] = {
                    "null_records": null_count,
                    "general_mode_records": general_count,
                    "affected_users": unique_users,
                    "migration_success": null_count == 0
                }
                
                status = "✅" if null_count == 0 else "❌"
                logger.info(f"{status} {table}: NULL記錄 {null_count}, 一般模式記錄 {general_count}, 影響用戶 {unique_users}")
                
            except Exception as e:
                logger.error(f"❌ 驗證 {table} 失敗: {e}")
                verification_results[table] = {"error": str(e)}
        
        return verification_results
    
    def rollback_migration(self):
        """回滾遷移"""
        logger.info("⏪ 開始回滾遷移...")
        
        for table in TARGET_TABLES:
            try:
                # 將固定 UUID 改回 NULL
                rollback_query = f"""
                UPDATE {table} 
                SET tournament_id = NULL
                WHERE tournament_id = '{GENERAL_MODE_TOURNAMENT_ID}'
                """
                
                self.supabase.rpc('execute_sql', {"query": rollback_query}).execute()
                logger.info(f"✅ {table} 回滾完成")
                
            except Exception as e:
                logger.error(f"❌ {table} 回滾失敗: {e}")
                raise
        
        # 刪除一般模式錦標賽記錄
        try:
            self.supabase.table("tournaments").delete().eq("id", GENERAL_MODE_TOURNAMENT_ID).execute()
            logger.info("✅ 一般模式錦標賽記錄已刪除")
        except Exception as e:
            logger.error(f"❌ 刪除一般模式錦標賽記錄失敗: {e}")


def main():
    parser = argparse.ArgumentParser(description='錦標賽統一架構遷移工具')
    parser.add_argument('--dry-run', action='store_true', help='只查詢當前狀態，不執行遷移')
    parser.add_argument('--backup', action='store_true', help='執行完整備份')
    parser.add_argument('--rollback', action='store_true', help='執行回滾操作')
    
    args = parser.parse_args()
    
    migration = TournamentMigration()
    
    try:
        if args.dry_run:
            # 只查詢狀態
            logger.info("🔍 執行狀態檢查 (Dry Run)")
            status = migration.check_current_status()
            
            print("\n" + "="*60)
            print("當前數據狀態報告")
            print("="*60)
            for table, data in status["tables"].items():
                if "error" in data:
                    print(f"{table}: 查詢錯誤 - {data['error']}")
                else:
                    print(f"{table}:")
                    print(f"  總記錄: {data['total_records']}")
                    print(f"  NULL記錄: {data['null_tournament_id']}")
                    print(f"  一般模式記錄: {data['general_mode_records']}")
                    print(f"  需要遷移: {'是' if data['needs_migration'] else '否'}")
            print("="*60)
            
        elif args.rollback:
            # 執行回滾
            logger.info("⏪ 執行遷移回滾")
            confirmation = input("確定要回滾遷移嗎？這會將一般模式改回 NULL 模式 (y/N): ")
            if confirmation.lower() == 'y':
                migration.rollback_migration()
                logger.info("✅ 回滾完成")
            else:
                logger.info("❌ 回滾已取消")
                
        else:
            # 執行遷移
            logger.info("🚀 開始錦標賽統一架構遷移")
            
            # 檢查當前狀態
            status = migration.check_current_status()
            
            # 檢查是否需要遷移
            needs_migration = any(
                table_data.get('needs_migration', False) 
                for table_data in status["tables"].values()
                if 'error' not in table_data
            )
            
            if not needs_migration:
                logger.info("✅ 所有表格已經是統一架構，無需遷移")
                return
            
            # 創建備份（如果要求）
            if args.backup:
                migration.create_backup()
            
            # 執行遷移
            migration_results = migration.execute_migration()
            
            # 創建一般模式錦標賽記錄
            migration.create_general_tournament()
            
            # 驗證結果
            verification = migration.verify_migration()
            
            # 顯示結果
            print("\n" + "="*60)
            print("遷移完成報告")
            print("="*60)
            
            all_success = True
            for table, result in verification.items():
                if "error" in result:
                    print(f"{table}: 驗證錯誤 - {result['error']}")
                    all_success = False
                else:
                    success = result.get('migration_success', False)
                    status_icon = "✅" if success else "❌"
                    print(f"{status_icon} {table}: 遷移{'成功' if success else '失敗'}")
                    print(f"   一般模式記錄: {result['general_mode_records']}")
                    print(f"   影響用戶數: {result['affected_users']}")
                    if not success:
                        all_success = False
            
            print("="*60)
            if all_success:
                print("🎉 遷移全部成功完成！")
                print(f"一般模式現在使用固定 UUID: {GENERAL_MODE_TOURNAMENT_ID}")
            else:
                print("⚠️ 部分遷移失敗，請檢查日誌")
                
    except Exception as e:
        logger.error(f"❌ 遷移過程發生錯誤: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()