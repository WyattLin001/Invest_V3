#!/usr/bin/env python3
"""
簡化的一般模式錦標賽創建
使用現有錦標賽的格式創建一般模式記錄
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
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MVgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

# 常量定義
GENERAL_MODE_TOURNAMENT_ID = "00000000-0000-0000-0000-000000000000"

def main():
    try:
        # 連接Supabase
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        logger.info("✅ Supabase 連接成功")
        
        # 檢查是否已存在一般模式錦標賽
        existing = supabase.table("tournaments")\
            .select("id")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        if existing.data:
            logger.info("✅ 一般模式錦標賽記錄已存在")
        else:
            logger.info("🏗️ 創建一般模式錦標賽記錄...")
            
            # 使用與現有錦標賽相同的格式
            tournament_data = {
                "id": GENERAL_MODE_TOURNAMENT_ID,
                "name": "一般投資模式",
                "type": "quarterly",  # 使用現有的有效類型
                "status": "ongoing",
                "start_date": "2000-01-01T00:00:00+00:00",
                "end_date": "2099-12-31T23:59:59+00:00",
                "description": "系統內建的一般投資模式，無時間限制的永久投資環境。用戶可以在此模式下自由練習投資策略，無競賽壓力，適合初學者熟悉平台功能或資深投資者測試新策略。",
                "short_description": "系統內建的永久投資練習環境，無競賽時間限制",
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
                "created_by": None  # 設為None避免UUID問題
            }
            
            try:
                result = supabase.table("tournaments").insert(tournament_data).execute()
                
                if result.data:
                    logger.info("✅ 一般模式錦標賽記錄創建成功")
                    logger.info(f"   UUID: {GENERAL_MODE_TOURNAMENT_ID}")
                    logger.info(f"   名稱: 一般投資模式")
                else:
                    logger.error("❌ 創建失敗：無返回數據")
                    return False
                    
            except Exception as e:
                logger.error(f"❌ 創建一般模式錦標賽記錄失敗: {e}")
                return False
        
        # 驗證創建結果
        verify = supabase.table("tournaments")\
            .select("id, name, type, status")\
            .eq("id", GENERAL_MODE_TOURNAMENT_ID)\
            .execute()
        
        if verify.data:
            tournament = verify.data[0]
            print("\n" + "="*60)
            print("🎯 一般模式錦標賽記錄狀態")
            print("="*60)
            print(f"UUID: {tournament['id']}")
            print(f"名稱: {tournament['name']}")
            print(f"類型: {tournament['type']}")
            print(f"狀態: {tournament['status']}")
            print("✅ 一般模式錦標賽記錄就緒")
            print("="*60)
            return True
        else:
            logger.error("❌ 驗證失敗：找不到剛創建的記錄")
            return False
            
    except Exception as e:
        logger.error(f"❌ 過程發生錯誤: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)