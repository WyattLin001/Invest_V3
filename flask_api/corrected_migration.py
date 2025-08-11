#!/usr/bin/env python3
"""
修復後的錦標賽統一架構遷移工具
使用正確的 Supabase API 金鑰

使用方法:
    python corrected_migration.py
"""

import sys
from datetime import datetime
from supabase import create_client, Client
import logging

# 設定日誌
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# 正確的 Supabase 配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

# 常量定義
GENERAL_MODE_TOURNAMENT_ID = "00000000-0000-0000-0000-000000000000"
SYSTEM_USER_ID = "d64a0edd-62cc-423a-8ce4-81103b5a9770"

def main():
    """主執行函數"""
    try:
        # 連接Supabase
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        logger.info("✅ Supabase 連接成功")
        
        # 步驟1: 創建一般模式錦標賽記錄
        logger.info("🏗️ 步驟1: 創建一般模式錦標賽記錄...")
        
        existing = supabase.table("tournaments")\
            .select("id, name")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        if existing.data:
            logger.info(f"✅ 一般模式錦標賽記錄已存在: {existing.data[0]['name']}")
        else:
            logger.info("創建一般模式錦標賽記錄...")
            
            tournament_data = {
                "id": GENERAL_MODE_TOURNAMENT_ID,
                "name": "一般投資模式",
                "type": "quarterly",
                "status": "ongoing",
                "start_date": "2000-01-01T00:00:00+00:00",
                "end_date": "2099-12-31T23:59:59+00:00",
                "description": "系統內建的一般投資模式，無時間限制的永久投資環境。用戶可以在此模式下自由練習投資策略，無競賽壓力，適合初學者熟悉平台功能或資深投資者測試新策略。",
                "short_description": "系統內建的永久投資練習環境",
                "initial_balance": 1000000,
                "max_participants": 999999,
                "current_participants": 0,
                "entry_fee": 0,
                "prize_pool": 0,
                "risk_limit_percentage": 100,
                "min_holding_rate": 0,
                "max_single_stock_rate": 100,
                "rules": [
                    "一般投資模式無特殊限制",
                    "可自由練習各種投資策略", 
                    "無競賽時間壓力",
                    "適合初學者學習和專家測試策略"
                ],
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "is_featured": False,
                "created_by": SYSTEM_USER_ID
            }
            
            result = supabase.table("tournaments").insert(tournament_data).execute()
            
            if result.data:
                logger.info("✅ 一般模式錦標賽記錄創建成功")
            else:
                logger.warning("⚠️ 錦標賽記錄創建失敗，但繼續遷移數據")
        
        # 步驟2: 遷移數據表
        migration_results = {}
        tables = ["user_portfolios", "portfolio_transactions", "portfolios"]
        
        for table in tables:
            logger.info(f"🔄 步驟2: 遷移 {table} 表...")
            
            # 查詢NULL記錄
            null_response = supabase.table(table)\
                .select("id")\
                .is_("tournament_id", "null")\
                .execute()
            
            null_records = null_response.data if null_response.data else []
            
            if null_records:
                logger.info(f"發現 {len(null_records)} 筆需要遷移的記錄")
                
                updated_count = 0
                failed_count = 0
                
                # 批量更新（分批處理）
                batch_size = 50
                for i in range(0, len(null_records), batch_size):
                    batch = null_records[i:i + batch_size]
                    batch_ids = [record["id"] for record in batch]
                    
                    try:
                        update_response = supabase.table(table)\
                            .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                            .in_("id", batch_ids)\
                            .execute()
                        
                        if update_response.data:
                            batch_updated = len(update_response.data)
                            updated_count += batch_updated
                            logger.info(f"   批次更新 {batch_updated} 筆記錄")
                        else:
                            failed_count += len(batch)
                            
                    except Exception as e:
                        logger.error(f"   批次更新失敗: {e}")
                        failed_count += len(batch)
                
                migration_results[table] = {
                    "original_null": len(null_records),
                    "updated": updated_count,
                    "failed": failed_count
                }
                
                logger.info(f"✅ {table}: 成功更新 {updated_count} 筆, 失敗 {failed_count} 筆")
            else:
                migration_results[table] = {
                    "original_null": 0,
                    "updated": 0,
                    "failed": 0
                }
                logger.info(f"✅ {table}: 無需遷移")
        
        # 步驟3: 驗證遷移結果
        logger.info("🔍 步驟3: 驗證遷移結果...")
        
        verification_results = {}
        total_general = 0
        total_null = 0
        
        for table in tables:
            # 檢查一般模式記錄
            general_response = supabase.table(table)\
                .select("id")\
                .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
                .execute()
            
            general_count = len(general_response.data) if general_response.data else 0
            total_general += general_count
            
            # 檢查剩餘NULL記錄
            null_response = supabase.table(table)\
                .select("id")\
                .is_("tournament_id", "null")\
                .execute()
            
            null_count = len(null_response.data) if null_response.data else 0
            total_null += null_count
            
            verification_results[table] = {
                "general_mode": general_count,
                "remaining_null": null_count
            }
            
            logger.info(f"📊 {table}: 一般模式 {general_count}, 剩餘NULL {null_count}")
        
        # 步驟4: 生成報告
        print("\n" + "="*80)
        print("🎯 錦標賽統一架構遷移完成報告")
        print("="*80)
        print(f"遷移時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        
        # 錦標賽記錄狀態
        tournament_verify = supabase.table("tournaments")\
            .select("id, name")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        tournament_exists = len(tournament_verify.data) > 0 if tournament_verify.data else False
        print(f"🏆 一般模式錦標賽: {'✅ 已創建' if tournament_exists else '⚠️ 需要手動創建'}")
        
        print("\n📊 數據遷移結果:")
        print("-"*60)
        for table, result in migration_results.items():
            if result["original_null"] > 0:
                print(f"{table}:")
                print(f"   原始NULL記錄: {result['original_null']}")
                print(f"   成功更新: {result['updated']}")
                print(f"   失敗: {result['failed']}")
            else:
                print(f"{table}: 無需遷移")
        
        print(f"\n📈 驗證結果:")
        print(f"   一般模式記錄總數: {total_general}")
        print(f"   剩餘NULL記錄: {total_null}")
        
        # 成功判定
        migration_success = total_null == 0 and total_general > 0
        
        if migration_success:
            print("\n🎉 遷移完全成功！")
            print("✅ 系統現在完全使用統一的UUID架構")
            print("📱 前端iOS: 可正常使用GENERAL_MODE_TOURNAMENT_ID")
            print("🔧 後端Flask: 統一處理一般模式和錦標賽模式")
            print("🗄️ 數據庫: 所有記錄都有明確的tournament_id")
            
            print("\n🚀 系統已準備就緒！")
            print("   - 可以開始測試Flask API功能")
            print("   - 可以驗證iOS前端整合")
            print("   - 可以部署到生產環境")
        else:
            print(f"\n⚠️ 遷移部分完成:")
            if total_null > 0:
                print(f"   還有 {total_null} 筆NULL記錄需要處理")
            if not tournament_exists:
                print("   需要創建一般模式錦標賽記錄")
        
        print("="*80)
        
        return migration_success
        
    except Exception as e:
        logger.error(f"❌ 遷移過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)