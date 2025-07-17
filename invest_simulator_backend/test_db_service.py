#!/usr/bin/env python3
"""
投資模擬交易平台 - 資料庫服務測試
使用 DatabaseService 類別測試資料庫連接和資料表
"""

import os
import sys
from dotenv import load_dotenv
from services.db_service import DatabaseService
import json

# 載入環境變數
load_dotenv()

def test_database_service():
    """測試資料庫服務連接"""
    print("🎯 投資模擬交易平台 - 資料庫服務測試")
    print("=" * 60)
    
    try:
        # 初始化資料庫服務
        print("🔌 初始化資料庫服務...")
        db_service = DatabaseService()
        print("✅ 資料庫服務初始化成功")
        
        # 測試 Supabase 連接
        print("\n🧪 測試 Supabase 連接...")
        print(f"   URL: {db_service.supabase_url}")
        print(f"   Service Key: {'設定完成' if db_service.supabase_key else '未設定'}")
        
        # 嘗試查詢股票資料表
        print("\n📈 測試股票資料表...")
        try:
            stocks = db_service.supabase.table('trading_stocks').select('*').limit(5).execute()
            print(f"✅ 成功查詢股票資料，找到 {len(stocks.data)} 筆記錄")
            
            if stocks.data:
                print("📝 前 5 檔股票:")
                for i, stock in enumerate(stocks.data, 1):
                    print(f"   {i}. {stock['symbol']} - {stock['name']}")
            
            # 統計總股票數量
            total_stocks = db_service.supabase.table('trading_stocks').select('*', count='exact').execute()
            print(f"📊 總股票數量: {total_stocks.count if hasattr(total_stocks, 'count') else '無法統計'}")
            
        except Exception as e:
            print(f"❌ 股票資料表查詢失敗: {e}")
            return False
        
        # 測試用戶資料表
        print("\n👤 測試用戶資料表...")
        try:
            users = db_service.supabase.table('trading_users').select('*').limit(3).execute()
            print(f"✅ 成功查詢用戶資料，找到 {len(users.data)} 筆記錄")
            
            if users.data:
                print("📝 用戶資料:")
                for i, user in enumerate(users.data, 1):
                    print(f"   {i}. {user['name']} - 現金餘額: ${user['cash_balance']:,.0f}")
            
        except Exception as e:
            print(f"❌ 用戶資料表查詢失敗: {e}")
            return False
        
        # 測試其他資料表
        other_tables = [
            'trading_positions',
            'trading_transactions',
            'trading_performance_snapshots',
            'trading_referrals',
            'trading_watchlists',
            'trading_alerts'
        ]
        
        print(f"\n📋 測試其他資料表...")
        all_tables_exist = True
        
        for table_name in other_tables:
            try:
                result = db_service.supabase.table(table_name).select('*').limit(1).execute()
                count_result = db_service.supabase.table(table_name).select('*', count='exact').execute()
                count = count_result.count if hasattr(count_result, 'count') else len(count_result.data)
                print(f"✅ {table_name}: {count} 筆記錄")
                
            except Exception as e:
                print(f"❌ {table_name}: 無法存取 - {e}")
                all_tables_exist = False
        
        # 測試功能函數
        print(f"\n🧪 測試功能函數...")
        try:
            # 測試邀請碼生成
            invite_code = db_service._generate_invite_code("test-user-id")
            print(f"✅ 邀請碼生成功能正常: {invite_code}")
            
        except Exception as e:
            print(f"❌ 功能函數測試失敗: {e}")
        
        # 總結報告
        print("\n" + "=" * 60)
        print("📊 資料庫服務測試結果:")
        
        if all_tables_exist:
            print("🎉 所有資料表測試通過！")
            print("✅ 資料庫服務正常運作")
            print("✅ 股票資料已就緒")
            print("✅ 系統可以開始使用")
            
            # 顯示配置資訊
            print(f"\n⚙️  系統配置:")
            print(f"   - 初始資金: ${db_service.initial_capital:,.0f}")
            print(f"   - 邀請獎勵: ${db_service.referral_bonus:,.0f}")
            
            # 建議下一步
            print("\n🚀 建議下一步:")
            print("1. 啟動後端服務: python run.py")
            print("2. 測試 API 端點: http://localhost:5000/health")
            print("3. 測試用戶註冊: POST /api/auth/register")
            print("4. 開始 iOS 前端開發")
            
            return True
        else:
            print("⚠️  部分資料表測試失敗")
            print("🔧 建議檢查:")
            print("1. Supabase 權限設定")
            print("2. 資料庫腳本是否正確執行")
            print("3. Row Level Security 政策")
            
            return False
            
    except Exception as e:
        print(f"❌ 資料庫服務測試失敗: {e}")
        return False

if __name__ == "__main__":
    success = test_database_service()
    sys.exit(0 if success else 1)