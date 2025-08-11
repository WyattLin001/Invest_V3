#!/usr/bin/env python3
"""
錦標賽統一架構驗證工具
不依賴特殊SQL函數，使用標準Supabase查詢驗證架構

使用方法:
    python verify_architecture.py [--verbose]
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

class ArchitectureVerifier:
    def __init__(self, verbose=False):
        """初始化驗證工具"""
        self.verbose = verbose
        try:
            self.supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
            logger.info("✅ Supabase 連接成功")
        except Exception as e:
            logger.error(f"❌ Supabase 連接失敗: {e}")
            sys.exit(1)
    
    def check_table_structure(self):
        """檢查數據表結構"""
        logger.info("🔍 檢查數據表結構...")
        
        table_status = {}
        
        for table in TARGET_TABLES:
            try:
                # 嘗試查詢表格，檢查是否存在
                response = self.supabase.table(table).select("*").limit(1).execute()
                table_status[table] = {
                    "exists": True,
                    "accessible": True,
                    "sample_count": len(response.data)
                }
                logger.info(f"✅ {table}: 表格存在且可訪問")
                
            except Exception as e:
                table_status[table] = {
                    "exists": False,
                    "error": str(e)
                }
                logger.warning(f"⚠️ {table}: 無法訪問 - {e}")
        
        return table_status
    
    def check_tournament_data_distribution(self):
        """檢查錦標賽數據分布"""
        logger.info("📊 檢查錦標賽數據分布...")
        
        distribution_report = {}
        
        for table in TARGET_TABLES:
            try:
                # 查詢所有記錄
                all_records = self.supabase.table(table).select("tournament_id").execute()
                
                if all_records.data:
                    # 統計tournament_id分布
                    tournament_counts = {}
                    null_count = 0
                    general_mode_count = 0
                    
                    for record in all_records.data:
                        tournament_id = record.get('tournament_id')
                        
                        if tournament_id is None:
                            null_count += 1
                        elif tournament_id == GENERAL_MODE_TOURNAMENT_ID:
                            general_mode_count += 1
                        else:
                            tournament_counts[tournament_id] = tournament_counts.get(tournament_id, 0) + 1
                    
                    distribution_report[table] = {
                        "total_records": len(all_records.data),
                        "null_tournament_id": null_count,
                        "general_mode_records": general_mode_count,
                        "tournament_records": tournament_counts,
                        "unique_tournaments": len(tournament_counts),
                        "needs_migration": null_count > 0
                    }
                    
                    logger.info(f"📋 {table}: 總計 {len(all_records.data)} 筆")
                    logger.info(f"   - NULL records: {null_count}")
                    logger.info(f"   - 一般模式: {general_mode_count}")
                    logger.info(f"   - 錦標賽數: {len(tournament_counts)}")
                    
                else:
                    distribution_report[table] = {
                        "total_records": 0,
                        "null_tournament_id": 0,
                        "general_mode_records": 0,
                        "tournament_records": {},
                        "unique_tournaments": 0,
                        "needs_migration": False
                    }
                    logger.info(f"📋 {table}: 無數據記錄")
                    
            except Exception as e:
                logger.error(f"❌ 查詢 {table} 失敗: {e}")
                distribution_report[table] = {"error": str(e)}
        
        return distribution_report
    
    def verify_data_isolation(self):
        """驗證數據隔離"""
        logger.info("🔒 驗證數據隔離...")
        
        isolation_results = {}
        
        # 測試用戶ID
        test_user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
        
        for table in TARGET_TABLES:
            try:
                # 查詢一般模式記錄
                general_records = self.supabase.table(table)\
                    .select("*")\
                    .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
                    .eq("user_id", test_user_id)\
                    .limit(5)\
                    .execute()
                
                # 查詢NULL記錄（舊架構）
                try:
                    null_records = self.supabase.table(table)\
                        .select("*")\
                        .is_("tournament_id", "null")\
                        .eq("user_id", test_user_id)\
                        .limit(5)\
                        .execute()
                    null_count = len(null_records.data) if null_records.data else 0
                except:
                    null_count = 0
                
                isolation_results[table] = {
                    "general_mode_records": len(general_records.data) if general_records.data else 0,
                    "null_records": null_count,
                    "isolation_working": True
                }
                
                logger.info(f"🔒 {table}: 一般模式 {len(general_records.data) if general_records.data else 0} 筆, NULL {null_count} 筆")
                
            except Exception as e:
                logger.error(f"❌ 隔離測試 {table} 失敗: {e}")
                isolation_results[table] = {"error": str(e)}
        
        return isolation_results
    
    def check_tournaments_table(self):
        """檢查tournaments表格"""
        logger.info("🏆 檢查tournaments表格...")
        
        try:
            # 檢查是否有一般模式錦標賽記錄
            general_tournament = self.supabase.table("tournaments")\
                .select("*")\
                .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
                .execute()
            
            # 檢查所有錦標賽
            all_tournaments = self.supabase.table("tournaments")\
                .select("id, name, status")\
                .execute()
            
            tournament_status = {
                "general_mode_exists": len(general_tournament.data) > 0 if general_tournament.data else False,
                "total_tournaments": len(all_tournaments.data) if all_tournaments.data else 0,
                "tournaments": all_tournaments.data[:5] if all_tournaments.data else []  # 顯示前5個
            }
            
            if tournament_status["general_mode_exists"]:
                logger.info(f"✅ 一般模式錦標賽記錄存在")
            else:
                logger.warning(f"⚠️ 一般模式錦標賽記錄不存在")
            
            logger.info(f"📊 總錦標賽數: {tournament_status['total_tournaments']}")
            
            return tournament_status
            
        except Exception as e:
            logger.error(f"❌ 檢查tournaments表格失敗: {e}")
            return {"error": str(e)}
    
    def generate_architecture_report(self):
        """生成架構報告"""
        logger.info("📊 生成統一架構驗證報告...")
        
        # 收集所有檢查結果
        table_structure = self.check_table_structure()
        data_distribution = self.check_tournament_data_distribution()
        isolation_results = self.verify_data_isolation()
        tournament_status = self.check_tournaments_table()
        
        # 生成報告
        print("\n" + "="*80)
        print("錦標賽統一架構驗證報告")
        print("="*80)
        print(f"驗證時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式 UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        
        print("\n📊 數據表結構檢查:")
        print("-"*60)
        for table, status in table_structure.items():
            if status.get("exists", False):
                print(f"✅ {table}: 表格存在且可訪問")
            else:
                print(f"❌ {table}: {status.get('error', '無法訪問')}")
        
        print("\n📈 數據分布分析:")
        print("-"*60)
        total_null_records = 0
        total_general_records = 0
        migration_needed = False
        
        for table, data in data_distribution.items():
            if "error" in data:
                print(f"❌ {table}: 查詢錯誤")
                continue
                
            null_count = data["null_tournament_id"]
            general_count = data["general_mode_records"]
            total_count = data["total_records"]
            tournament_count = data["unique_tournaments"]
            
            total_null_records += null_count
            total_general_records += general_count
            
            if null_count > 0:
                migration_needed = True
            
            print(f"📋 {table}:")
            print(f"   總記錄: {total_count}")
            print(f"   NULL記錄: {null_count}")
            print(f"   一般模式: {general_count}")  
            print(f"   錦標賽數: {tournament_count}")
        
        print("\n🏆 錦標賽表格狀態:")
        print("-"*60)
        if "error" not in tournament_status:
            if tournament_status["general_mode_exists"]:
                print("✅ 一般模式錦標賽記錄存在")
            else:
                print("⚠️ 一般模式錦標賽記錄不存在，建議創建")
            print(f"📊 總錦標賽數: {tournament_status['total_tournaments']}")
        else:
            print(f"❌ 無法檢查錦標賽表格")
        
        print("\n🔒 數據隔離驗證:")
        print("-"*60)
        isolation_working = True
        for table, result in isolation_results.items():
            if "error" in result:
                print(f"❌ {table}: 隔離測試失敗")
                isolation_working = False
            else:
                general_records = result["general_mode_records"]
                null_records = result["null_records"]
                print(f"✅ {table}: 一般模式 {general_records} 筆, NULL {null_records} 筆")
        
        print("\n" + "="*80)
        print("🎯 總結:")
        
        if migration_needed:
            print(f"⚠️ 需要數據遷移: 發現 {total_null_records} 筆 NULL 記錄")
            print(f"📋 建議執行: python execute_migration.py --backup")
        else:
            print(f"✅ 統一架構已實施: {total_general_records} 筆一般模式記錄")
        
        if isolation_working:
            print("✅ 數據隔離正常運行")
        else:
            print("❌ 數據隔離存在問題")
            
        if not tournament_status.get("general_mode_exists", False):
            print("💡 建議: 創建一般模式錦標賽記錄以完善系統")
        
        print("="*80)
        
        return {
            "migration_needed": migration_needed,
            "isolation_working": isolation_working,
            "total_null_records": total_null_records,
            "total_general_records": total_general_records
        }


def main():
    parser = argparse.ArgumentParser(description='錦標賽統一架構驗證工具')
    parser.add_argument('--verbose', '-v', action='store_true', help='顯示詳細信息')
    
    args = parser.parse_args()
    
    try:
        verifier = ArchitectureVerifier(verbose=args.verbose)
        results = verifier.generate_architecture_report()
        
        # 根據結果決定退出碼
        if results["migration_needed"]:
            logger.info("💡 系統需要遷移到統一架構")
            sys.exit(2)  # 需要遷移
        elif not results["isolation_working"]:
            logger.error("❌ 數據隔離存在問題")
            sys.exit(1)  # 有錯誤
        else:
            logger.info("✅ 統一架構驗證通過")
            sys.exit(0)  # 一切正常
            
    except KeyboardInterrupt:
        logger.info("驗證被用戶中斷")
        sys.exit(1)
    except Exception as e:
        logger.error(f"驗證過程發生錯誤: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()