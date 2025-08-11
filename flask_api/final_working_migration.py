#!/usr/bin/env python3
"""
最終工作遷移工具
使用現有錦標賽的正確格式創建一般模式錦標賽

使用方法:
    python final_working_migration.py
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
VALID_USER_ID = "be5f2785-741e-455c-8a94-2bb2b510f76b"  # 從現有用戶中選擇

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
            
            # 使用與現有錦標賽完全相同的格式
            tournament_data = {
                "id": GENERAL_MODE_TOURNAMENT_ID,
                "name": "一般投資模式",
                "type": "quarterly",  # 使用現有的有效類型
                "status": "ongoing",
                "start_date": "2000-01-01T00:00:00+00:00",
                "end_date": "2099-12-31T23:59:59+00:00",
                "description": "系統內建的一般投資模式，無時間限制的永久投資環境。用戶可以在此模式下自由練習投資策略，無競賽壓力，適合初學者熟悉平台功能或資深投資者測試新策略。",
                "short_description": "系統內建的永久投資練習環境",
                "initial_balance": 1000000.0,
                "max_participants": 999999,
                "current_participants": 0,
                "entry_fee": 0.0,
                "prize_pool": 0.0,
                "risk_limit_percentage": 0.20,  # 使用默認值
                "min_holding_rate": 0.50,       # 使用默認值
                "max_single_stock_rate": 0.30,  # 使用默認值
                "rules": [
                    "一般投資模式無特殊限制",
                    "可自由練習各種投資策略",
                    "無競賽時間壓力",
                    "適合初學者學習和專家測試策略"
                ],
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "is_featured": False,
                "created_by": VALID_USER_ID  # 使用有效的用戶ID
            }
            
            result = supabase.table("tournaments").insert(tournament_data).execute()
            
            if result.data:
                logger.info("✅ 一般模式錦標賽記錄創建成功")
            else:
                logger.warning("⚠️ 創建錦標賽記錄失敗，但繼續遷移數據...")
        
        # 步驟2: 遷移user_portfolios表
        logger.info("🔄 步驟2: 遷移user_portfolios表...")
        
        null_response = supabase.table("user_portfolios")\
            .select("id")\
            .is_("tournament_id", "null")\
            .execute()
        
        null_records = null_response.data if null_response.data else []
        
        if null_records:
            logger.info(f"發現 {len(null_records)} 筆需要遷移的記錄")
            
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
                        if updated_count % 10 == 0:
                            logger.info(f"   進度: {updated_count}/{len(null_records)}")
                    else:
                        failed_count += 1
                        
                except Exception as e:
                    logger.error(f"更新記錄 {record['id']} 失敗: {e}")
                    failed_count += 1
            
            logger.info(f"✅ user_portfolios: 成功 {updated_count}, 失敗 {failed_count}")
        else:
            logger.info("✅ user_portfolios 表無需遷移")
        
        # 步驟3: 檢查其他表格
        for table in ["portfolio_transactions", "portfolios"]:
            logger.info(f"🔍 檢查 {table} 表...")
            
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
                        logger.error(f"更新 {table} 記錄失敗: {e}")
                
                logger.info(f"✅ {table}: 成功更新 {updated_count} 筆記錄")
            else:
                logger.info(f"✅ {table} 表無需遷移")
        
        # 步驟4: 最終驗證
        logger.info("🔍 最終驗證...")
        
        verification_results = {}
        total_general = 0
        total_null = 0
        
        for table in ["user_portfolios", "portfolio_transactions", "portfolios"]:
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
                "null_records": null_count
            }
        
        # 檢查錦標賽記錄
        tournament_check = supabase.table("tournaments")\
            .select("id, name, type, status")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        tournament_exists = len(tournament_check.data) > 0 if tournament_check.data else False
        
        # 生成最終報告
        print("\n" + "="*80)
        print("🎯 錦標賽統一架構遷移完成報告")
        print("="*80)
        print(f"遷移時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print("-"*60)
        
        if tournament_check.data:
            tournament = tournament_check.data[0]
            print(f"🏆 錦標賽記錄: ✅ 已創建")
            print(f"   名稱: {tournament['name']}")
            print(f"   類型: {tournament['type']}")
            print(f"   狀態: {tournament['status']}")
        else:
            print("🏆 錦標賽記錄: ❌ 不存在")
        
        print(f"\n📊 數據遷移結果:")
        for table, result in verification_results.items():
            print(f"   {table}:")
            print(f"     一般模式記錄: {result['general_mode']}")
            print(f"     剩餘NULL記錄: {result['null_records']}")
        
        print(f"\n📈 總計:")
        print(f"   一般模式記錄總數: {total_general}")
        print(f"   剩餘NULL記錄: {total_null}")
        
        # 判定成功
        migration_success = total_null == 0 and tournament_exists
        
        if migration_success:
            print("\n🎉 遷移完全成功！")
            print("✅ 系統現在完全使用統一的UUID架構")
            print("📱 iOS前端: 使用GENERAL_MODE_TOURNAMENT_ID常量")
            print("🔧 Flask後端: 統一處理一般模式和錦標賽模式")
            print("🗄️ 數據庫: 所有記錄都有明確的tournament_id")
            
            print("\n🚀 系統已準備就緒！")
            print("   - 可以開始測試Flask API功能")
            print("   - 可以驗證iOS前端整合")
            print("   - 可以部署到生產環境")
            
        elif total_null == 0:
            print("\n✅ 數據遷移成功！")
            print("⚠️ 但錦標賽記錄可能需要手動檢查")
            
        else:
            print(f"\n⚠️ 部分成功: 還有 {total_null} 筆NULL記錄")
            print("💡 建議檢查權限或數據庫約束")
        
        print("="*80)
        
        return migration_success
        
    except Exception as e:
        logger.error(f"❌ 遷移過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)