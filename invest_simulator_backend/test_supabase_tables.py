#!/usr/bin/env python3
"""
投資模擬交易平台 - Supabase 資料表驗證腳本
使用 Supabase REST API 測試所有交易相關資料表
"""

import os
import sys
from dotenv import load_dotenv
from supabase import create_client, Client
import json

# 載入環境變數
load_dotenv()

def test_supabase_connection():
    """測試 Supabase 連接"""
    print("🔌 測試 Supabase 連接...")
    
    try:
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        if not supabase_url or not supabase_key:
            print("❌ 缺少 Supabase 環境變數")
            return None
        
        # 建立 Supabase 客戶端
        supabase: Client = create_client(supabase_url, supabase_key)
        print("✅ Supabase 客戶端建立成功")
        
        return supabase
        
    except Exception as e:
        print(f"❌ Supabase 連接失敗: {e}")
        return None

def check_table_and_count(supabase, table_name):
    """檢查資料表並取得記錄數"""
    try:
        # 嘗試查詢資料表
        result = supabase.table(table_name).select('*').limit(1).execute()
        
        # 如果查詢成功，表示資料表存在
        print(f"✅ 資料表 {table_name} 存在")
        
        # 取得記錄數 (使用 count)
        count_result = supabase.table(table_name).select('*', count='exact').execute()
        count = count_result.count if hasattr(count_result, 'count') else len(count_result.data)
        
        print(f"📊 記錄數: {count}")
        
        return True, count
        
    except Exception as e:
        print(f"❌ 資料表 {table_name} 不存在或無法存取: {e}")
        return False, 0

def get_sample_data(supabase, table_name, limit=3):
    """取得資料表示例資料"""
    try:
        result = supabase.table(table_name).select('*').limit(limit).execute()
        return result.data
        
    except Exception as e:
        print(f"❌ 查詢資料表 {table_name} 示例資料失敗: {e}")
        return []

def test_stock_data_details(supabase):
    """詳細測試股票資料表"""
    print(f"\n🏢 股票資料詳細檢查:")
    
    try:
        # 取得台灣股票資料
        tw_stocks = supabase.table('trading_stocks').select('*').eq('market', 'TW').execute()
        print(f"   📈 台灣股票: {len(tw_stocks.data)} 檔")
        
        # 顯示前幾檔股票
        print("   🔍 前 5 檔股票:")
        for i, stock in enumerate(tw_stocks.data[:5], 1):
            print(f"     {i}. {stock['symbol']} - {stock['name']}")
        
        # 按板塊統計
        sectors = {}
        for stock in tw_stocks.data:
            sector = stock.get('sector', 'Unknown')
            sectors[sector] = sectors.get(sector, 0) + 1
        
        print("   🏭 按板塊統計:")
        for sector, count in sorted(sectors.items(), key=lambda x: x[1], reverse=True):
            print(f"     {sector}: {count} 檔")
        
        return True
        
    except Exception as e:
        print(f"   ❌ 股票資料詳細檢查失敗: {e}")
        return False

def test_trading_tables():
    """測試所有交易相關資料表"""
    print("🎯 投資模擬交易平台 - Supabase 資料表驗證")
    print("=" * 60)
    
    # 連接 Supabase
    supabase = test_supabase_connection()
    if not supabase:
        return False
    
    # 要檢查的資料表清單
    tables_to_check = [
        'trading_users',
        'trading_stocks',
        'trading_positions',
        'trading_transactions',
        'trading_performance_snapshots',
        'trading_referrals',
        'trading_watchlists',
        'trading_alerts'
    ]
    
    print(f"\n📋 檢查 {len(tables_to_check)} 個交易資料表...")
    
    all_tables_exist = True
    table_info = {}
    
    for table_name in tables_to_check:
        print(f"\n🔍 檢查資料表: {table_name}")
        
        exists, count = check_table_and_count(supabase, table_name)
        table_info[table_name] = {
            'exists': exists,
            'count': count
        }
        
        if not exists:
            all_tables_exist = False
            continue
        
        # 如果有資料，顯示示例
        if count > 0:
            sample_data = get_sample_data(supabase, table_name)
            print(f"📝 示例資料 (前 {len(sample_data)} 筆):")
            
            for i, row in enumerate(sample_data, 1):
                # 隱藏敏感資訊
                safe_row = {}
                for key, value in row.items():
                    if key in ['phone', 'email', 'invite_code']:
                        safe_row[key] = "***hidden***"
                    elif isinstance(value, str) and len(value) > 50:
                        safe_row[key] = value[:50] + "..."
                    else:
                        safe_row[key] = value
                
                # 只顯示重要欄位
                important_fields = ['id', 'symbol', 'name', 'cash_balance', 'total_assets', 
                                   'action', 'quantity', 'price', 'created_at']
                display_row = {k: v for k, v in safe_row.items() if k in important_fields}
                print(f"   {i}. {display_row}")
        else:
            print("   (無資料)")
    
    # 特別檢查股票資料表
    if table_info.get('trading_stocks', {}).get('exists', False):
        success = test_stock_data_details(supabase)
        if not success:
            print("   ⚠️  股票資料詳細檢查失敗")
    
    # 測試一些關鍵功能
    print(f"\n🧪 功能測試:")
    
    # 測試股票查詢功能
    try:
        tsmc = supabase.table('trading_stocks').select('*').eq('symbol', '2330').execute()
        if tsmc.data:
            print("✅ 股票查詢功能正常 (找到台積電)")
        else:
            print("⚠️  股票查詢功能異常 (未找到台積電)")
    except Exception as e:
        print(f"❌ 股票查詢功能測試失敗: {e}")
    
    # 總結
    print("\n" + "=" * 60)
    print("📊 資料表驗證結果:")
    
    existing_tables = [name for name, info in table_info.items() if info['exists']]
    missing_tables = [name for name, info in table_info.items() if not info['exists']]
    
    print(f"✅ 存在的資料表: {len(existing_tables)}/{len(tables_to_check)}")
    for table in existing_tables:
        count = table_info[table]['count']
        print(f"   - {table}: {count} 筆記錄")
    
    if missing_tables:
        print(f"❌ 缺少的資料表: {len(missing_tables)}")
        for table in missing_tables:
            print(f"   - {table}")
    
    # 特別關注股票資料表
    stock_count = table_info.get('trading_stocks', {}).get('count', 0)
    if stock_count > 0:
        print(f"\n📈 股票資料庫狀態:")
        print(f"   - 共有 {stock_count} 檔股票")
        print(f"   - 示例資料插入成功")
        print(f"   - 可以開始交易系統測試")
    
    if all_tables_exist:
        print("\n🎉 所有交易資料表驗證成功！")
        print("✅ Supabase 資料庫架構完整，系統準備就緒")
        
        # 建議下一步
        print("\n🚀 建議下一步:")
        print("1. 測試用戶註冊 API: POST /api/auth/register")
        print("2. 測試股票資料 API: GET /api/stocks")
        print("3. 測試交易功能 API: POST /api/trading/buy")
        print("4. 開始 iOS 前端整合")
        
        return True
    else:
        print("\n⚠️  部分資料表缺失，請檢查 Supabase 設置")
        print("🔧 解決方案:")
        print("1. 在 Supabase SQL Editor 中執行 setup_trading_tables.sql")
        print("2. 檢查 Supabase service key 權限")
        print("3. 確認 Row Level Security 設置正確")
        
        return False

if __name__ == "__main__":
    success = test_trading_tables()
    sys.exit(0 if success else 1)