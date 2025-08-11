#!/usr/bin/env python3
"""
修復空字符串UUID問題的遷移工具
將空字符串的tournament_id更新為一般模式UUID

使用方法:
    python fix_empty_string_migration.py
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
        
        # 驗證錦標賽記錄存在
        tournament_check = supabase.table("tournaments")\
            .select("id, name")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        if not tournament_check.data:
            logger.error("❌ 一般模式錦標賽記錄不存在，請先運行 final_working_migration.py")
            return False
        
        logger.info(f"✅ 確認一般模式錦標賽存在: {tournament_check.data[0]['name']}")
        
        # 步驟1: 處理user_portfolios表中的空字符串記錄
        logger.info("🔄 步驟1: 修復user_portfolios表中的空字符串tournament_id...")
        
        # 查詢所有記錄來手動篩選空字符串
        all_records = supabase.table("user_portfolios")\
            .select("id, tournament_id")\
            .execute()
        
        empty_string_records = []
        null_records = []
        
        if all_records.data:
            for record in all_records.data:
                tournament_id = record.get('tournament_id')
                if tournament_id == "":
                    empty_string_records.append(record)
                elif tournament_id is None:
                    null_records.append(record)
        
        logger.info(f"找到 {len(empty_string_records)} 筆空字符串記錄")
        logger.info(f"找到 {len(null_records)} 筆NULL記錄")
        
        total_updated = 0
        total_failed = 0
        
        # 處理空字符串記錄
        if empty_string_records:
            logger.info(f"更新 {len(empty_string_records)} 筆空字符串記錄...")
            
            for record in empty_string_records:
                try:
                    update_response = supabase.table("user_portfolios")\
                        .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                        .eq("id", record["id"])\
                        .execute()
                    
                    if update_response.data:
                        total_updated += 1
                        if total_updated % 10 == 0:
                            logger.info(f"   進度: {total_updated}/{len(empty_string_records)}")
                    else:
                        total_failed += 1
                        
                except Exception as e:
                    logger.error(f"更新記錄 {record['id']} 失敗: {e}")
                    total_failed += 1
        
        # 處理NULL記錄
        if null_records:
            logger.info(f"更新 {len(null_records)} 筆NULL記錄...")
            
            for record in null_records:
                try:
                    update_response = supabase.table("user_portfolios")\
                        .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                        .eq("id", record["id"])\
                        .execute()
                    
                    if update_response.data:
                        total_updated += 1
                        if total_updated % 10 == 0:
                            logger.info(f"   進度: {total_updated}/{len(empty_string_records) + len(null_records)}")
                    else:
                        total_failed += 1
                        
                except Exception as e:
                    logger.error(f"更新記錄 {record['id']} 失敗: {e}")
                    total_failed += 1
        
        logger.info(f"✅ user_portfolios 更新結果: 成功 {total_updated}, 失敗 {total_failed}")
        
        # 步驟2: 檢查其他表格是否有類似問題
        for table in ["portfolio_transactions", "portfolios"]:
            logger.info(f"🔍 檢查 {table} 表...")
            
            all_records = supabase.table(table)\
                .select("id, tournament_id")\
                .execute()
            
            problem_records = []
            
            if all_records.data:
                for record in all_records.data:
                    tournament_id = record.get('tournament_id')
                    if tournament_id == "" or tournament_id is None:
                        problem_records.append(record)
            
            if problem_records:
                logger.info(f"{table}: 發現 {len(problem_records)} 筆需要修復的記錄")
                
                table_updated = 0
                for record in problem_records:
                    try:
                        update_response = supabase.table(table)\
                            .update({"tournament_id": GENERAL_MODE_TOURNAMENT_ID})\
                            .eq("id", record["id"])\
                            .execute()
                        
                        if update_response.data:
                            table_updated += 1
                            
                    except Exception as e:
                        logger.error(f"更新 {table} 記錄失敗: {e}")
                
                logger.info(f"✅ {table}: 成功更新 {table_updated} 筆記錄")
            else:
                logger.info(f"✅ {table} 表無需修復")
        
        # 步驟3: 最終驗證
        logger.info("🔍 執行最終驗證...")
        
        verification_results = {}
        total_general = 0
        total_problem = 0
        
        for table in ["user_portfolios", "portfolio_transactions", "portfolios"]:
            # 檢查一般模式記錄
            general_response = supabase.table(table)\
                .select("id")\
                .eq("tournament_id", GENERAL_MODE_TOURNAMENT_ID)\
                .execute()
            
            general_count = len(general_response.data) if general_response.data else 0
            total_general += general_count
            
            # 手動檢查問題記錄（NULL或空字符串）
            all_response = supabase.table(table)\
                .select("id, tournament_id")\
                .execute()
            
            problem_count = 0
            if all_response.data:
                for record in all_response.data:
                    tournament_id = record.get('tournament_id')
                    if tournament_id is None or tournament_id == "":
                        problem_count += 1
            
            total_problem += problem_count
            
            verification_results[table] = {
                "general_mode": general_count,
                "problem_records": problem_count
            }
        
        # 生成最終報告
        print("\n" + "="*80)
        print("🎯 錦標賽統一架構修復完成報告")
        print("="*80)
        print(f"修復時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"一般模式UUID: {GENERAL_MODE_TOURNAMENT_ID}")
        print("-"*60)
        
        print(f"🏆 錦標賽記錄: ✅ 存在")
        print(f"   名稱: {tournament_check.data[0]['name']}")
        
        print(f"\n📊 數據修復結果:")
        for table, result in verification_results.items():
            print(f"   {table}:")
            print(f"     一般模式記錄: {result['general_mode']}")
            print(f"     剩餘問題記錄: {result['problem_records']}")
        
        print(f"\n📈 總計:")
        print(f"   一般模式記錄總數: {total_general}")
        print(f"   剩餘問題記錄: {total_problem}")
        
        # 判定成功
        migration_success = total_problem == 0 and total_general > 0
        
        if migration_success:
            print("\n🎉 修復完全成功！")
            print("✅ 系統現在完全使用統一的UUID架構")
            print("📱 iOS前端: 可正常使用GENERAL_MODE_TOURNAMENT_ID")
            print("🔧 Flask後端: 統一處理一般模式和錦標賽模式")
            print("🗄️ 數據庫: 所有記錄都有明確的tournament_id")
            
            print("\n🚀 系統已準備就緒！")
            print("   - 立即測試Flask API功能")
            print("   - 驗證iOS前端整合")
            print("   - 部署到生產環境")
            
        else:
            if total_problem > 0:
                print(f"\n⚠️ 仍有 {total_problem} 筆問題記錄需要處理")
                print("💡 建議檢查數據庫約束和權限設定")
            if total_general == 0:
                print("⚠️ 沒有找到一般模式記錄，遷移可能未生效")
        
        print("="*80)
        
        return migration_success
        
    except Exception as e:
        logger.error(f"❌ 修復過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)