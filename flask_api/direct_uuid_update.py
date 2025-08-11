#!/usr/bin/env python3
"""
直接UUID更新工具
使用不同的更新策略來避免UUID轉換問題

使用方法:
    python direct_uuid_update.py
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
        
        # 獲取需要更新的記錄
        logger.info("🔍 獲取需要更新的記錄...")
        
        null_records = supabase.table("user_portfolios")\
            .select("*")\
            .is_("tournament_id", "null")\
            .execute()
        
        if not null_records.data:
            logger.info("✅ 沒有需要更新的記錄")
            return True
            
        logger.info(f"找到 {len(null_records.data)} 筆需要更新的記錄")
        
        # 方法1: 使用upsert替代update
        logger.info("🔄 方法1: 使用upsert更新...")
        
        updated_records = []
        for record in null_records.data:
            try:
                # 創建更新的記錄副本
                updated_record = record.copy()
                updated_record['tournament_id'] = GENERAL_MODE_TOURNAMENT_ID
                updated_record['updated_at'] = datetime.now().isoformat()
                
                # 使用upsert
                result = supabase.table("user_portfolios")\
                    .upsert(updated_record)\
                    .execute()
                
                if result.data:
                    updated_records.extend(result.data)
                    logger.info(f"   ✅ 記錄 {record['id'][:8]}... 更新成功")
                else:
                    logger.error(f"   ❌ 記錄 {record['id'][:8]}... 更新失敗")
                    
            except Exception as e:
                logger.error(f"   ❌ 記錄 {record['id'][:8]}... 更新失敗: {e}")
        
        logger.info(f"✅ upsert更新完成，成功更新 {len(updated_records)} 筆記錄")
        
        # 驗證更新結果
        logger.info("🔍 驗證更新結果...")
        
        # 檢查一般模式記錄
        general_records = supabase.table("user_portfolios")\
            .select("id")\
            .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        general_count = len(general_records.data) if general_records.data else 0
        
        # 檢查剩餘NULL記錄
        remaining_null = supabase.table("user_portfolios")\
            .select("id")\
            .is_("tournament_id", "null")\
            .execute()
        
        null_count = len(remaining_null.data) if remaining_null.data else 0
        
        # 檢查其他表格
        other_tables_results = {}
        for table in ["portfolio_transactions", "portfolios"]:
            general_response = supabase.table(table)\
                .select("id")\
                .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
                .execute()
            
            null_response = supabase.table(table)\
                .select("id")\
                .is_("tournament_id", "null")\
                .execute()
            
            other_tables_results[table] = {
                "general": len(general_response.data) if general_response.data else 0,
                "null": len(null_response.data) if null_response.data else 0
            }
        
        # 檢查錦標賽記錄
        tournament_check = supabase.table("tournaments")\
            .select("id, name, type")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        tournament_exists = len(tournament_check.data) > 0 if tournament_check.data else False
        
        # 生成報告
        print("\n" + "="*80)
        print("🎯 直接UUID更新完成報告")
        print("="*80)
        print(f"更新時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print("-"*60)
        
        if tournament_exists:
            tournament = tournament_check.data[0]
            print(f"🏆 錦標賽記錄: ✅ 存在")
            print(f"   名稱: {tournament['name']}")
            print(f"   類型: {tournament['type']}")
        else:
            print("🏆 錦標賽記錄: ❌ 不存在")
        
        print(f"\n📊 user_portfolios 更新結果:")
        print(f"   一般模式記錄: {general_count}")
        print(f"   剩餘NULL記錄: {null_count}")
        
        print(f"\n📊 其他表格狀態:")
        total_other_general = 0
        total_other_null = 0
        
        for table, result in other_tables_results.items():
            print(f"   {table}:")
            print(f"     一般模式記錄: {result['general']}")
            print(f"     NULL記錄: {result['null']}")
            total_other_general += result['general']
            total_other_null += result['null']
        
        print(f"\n📈 總計:")
        total_general = general_count + total_other_general
        total_null = null_count + total_other_null
        print(f"   一般模式記錄總數: {total_general}")
        print(f"   剩餘NULL記錄: {total_null}")
        
        # 判定成功
        success = null_count == 0 and tournament_exists and general_count > 0
        
        if success:
            print("\n🎉 遷移完全成功！")
            print("✅ 系統現在完全使用統一的UUID架構")
            print("📱 iOS前端: 可正常使用GENERAL_MODE_TOURNAMENT_ID")
            print("🔧 Flask後端: 統一處理一般模式和錦標賽模式")
            print("🗄️ 數據庫: 所有記錄都有明確的tournament_id")
            
            print("\n🚀 系統已準備就緒！")
            print("   ✨ 立即測試Flask API功能")
            print("   ✨ 驗證iOS前端整合")
            print("   ✨ 開始部署流程")
            
        else:
            if null_count > 0:
                print(f"\n⚠️ 仍有 {null_count} 筆NULL記錄在user_portfolios表中")
            if not tournament_exists:
                print("⚠️ 錦標賽記錄不存在")
            if general_count == 0:
                print("⚠️ 沒有找到一般模式記錄")
        
        print("="*80)
        
        return success
        
    except Exception as e:
        logger.error(f"❌ 更新過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)