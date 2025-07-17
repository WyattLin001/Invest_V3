#!/usr/bin/env python3
"""
投資模擬交易平台 - 全面資料庫測試
綜合測試各種連接方式並確定資料庫現狀
"""

import os
import sys
from dotenv import load_dotenv
from supabase import create_client, Client
import requests
import json

# 載入環境變數
load_dotenv()

def test_environment_variables():
    """測試環境變數設定"""
    print("🔧 測試環境變數設定...")
    
    required_vars = [
        'SUPABASE_URL',
        'SUPABASE_SERVICE_KEY',
        'INITIAL_CAPITAL',
        'REFERRAL_BONUS'
    ]
    
    missing_vars = []
    
    for var in required_vars:
        value = os.getenv(var)
        if not value:
            missing_vars.append(var)
        else:
            if var.endswith('KEY'):
                print(f"✅ {var}: {'*' * 20} (已設定)")
            else:
                print(f"✅ {var}: {value}")
    
    if missing_vars:
        print(f"❌ 缺少環境變數: {missing_vars}")
        return False
    
    return True

def test_supabase_rest_api():
    """測試 Supabase REST API 直接連接"""
    print("\n🌐 測試 Supabase REST API 連接...")
    
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
    
    if not supabase_url or not supabase_key:
        print("❌ 缺少 Supabase 環境變數")
        return False
    
    # 測試不同的資料表名稱
    table_variants = [
        'trading_stocks',  # 新的資料表名稱
        'stocks',          # 舊的資料表名稱
        'trading_users',   # 新的資料表名稱
        'users'            # 舊的資料表名稱
    ]
    
    headers = {
        'apikey': supabase_key,
        'Authorization': f'Bearer {supabase_key}',
        'Content-Type': 'application/json'
    }
    
    existing_tables = []
    
    for table_name in table_variants:
        try:
            # 嘗試查詢資料表
            url = f"{supabase_url}/rest/v1/{table_name}?select=*&limit=1"
            response = requests.get(url, headers=headers)
            
            if response.status_code == 200:
                print(f"✅ 資料表 {table_name} 存在")
                existing_tables.append(table_name)
                
                # 取得記錄數
                count_url = f"{supabase_url}/rest/v1/{table_name}?select=*&limit=0"
                count_headers = {**headers, 'Prefer': 'count=exact'}
                count_response = requests.get(count_url, headers=count_headers)
                
                if count_response.status_code == 200:
                    count = count_response.headers.get('content-range', '0').split('/')[-1]
                    print(f"   📊 記錄數: {count}")
                
            elif response.status_code == 401:
                print(f"❌ 資料表 {table_name} 授權失敗 (401)")
                return False
            elif response.status_code == 404:
                print(f"⚠️  資料表 {table_name} 不存在")
            else:
                print(f"❌ 資料表 {table_name} 查詢失敗 ({response.status_code})")
                
        except Exception as e:
            print(f"❌ 資料表 {table_name} 測試錯誤: {e}")
    
    return existing_tables

def test_supabase_client():
    """測試 Supabase Python 客戶端"""
    print("\n🐍 測試 Supabase Python 客戶端...")
    
    try:
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        # 建立客戶端
        supabase: Client = create_client(supabase_url, supabase_key)
        print("✅ Supabase 客戶端建立成功")
        
        # 測試不同的資料表
        test_tables = ['trading_stocks', 'stocks', 'trading_users', 'users']
        
        for table_name in test_tables:
            try:
                result = supabase.table(table_name).select('*').limit(1).execute()
                print(f"✅ {table_name} 查詢成功，找到 {len(result.data)} 筆記錄")
                
                if result.data:
                    # 顯示第一筆記錄的欄位
                    fields = list(result.data[0].keys())
                    print(f"   📋 欄位: {fields[:5]}{'...' if len(fields) > 5 else ''}")
                
                return True  # 如果任何一個表查詢成功，說明連接正常
                
            except Exception as e:
                print(f"❌ {table_name} 查詢失敗: {e}")
                continue
        
        return False
        
    except Exception as e:
        print(f"❌ Supabase 客戶端測試失敗: {e}")
        return False

def test_database_schema():
    """測試資料庫架構"""
    print("\n🗄️  測試資料庫架構...")
    
    try:
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        # 使用 REST API 查詢資料庫架構
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        # 查詢所有資料表
        url = f"{supabase_url}/rest/v1/information_schema.tables?select=table_name&table_schema=eq.public"
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            tables = response.json()
            table_names = [table['table_name'] for table in tables]
            
            print(f"✅ 找到 {len(table_names)} 個資料表")
            
            # 檢查交易相關資料表
            trading_tables = [name for name in table_names if 'trading' in name.lower() or name in ['users', 'stocks', 'positions', 'transactions']]
            
            if trading_tables:
                print("📋 交易相關資料表:")
                for table in sorted(trading_tables):
                    print(f"   - {table}")
                return trading_tables
            else:
                print("⚠️  未找到交易相關資料表")
                return []
        else:
            print(f"❌ 資料庫架構查詢失敗 ({response.status_code})")
            return []
            
    except Exception as e:
        print(f"❌ 資料庫架構測試失敗: {e}")
        return []

def main():
    """主要測試函數"""
    print("🎯 投資模擬交易平台 - 全面資料庫測試")
    print("=" * 60)
    
    # 測試環境變數
    env_ok = test_environment_variables()
    if not env_ok:
        print("\n❌ 環境變數測試失敗，請檢查 .env 檔案")
        return False
    
    # 測試 REST API 連接
    existing_tables = test_supabase_rest_api()
    if not existing_tables:
        print("\n❌ 無法透過 REST API 連接到資料庫")
        return False
    
    # 測試 Python 客戶端
    client_ok = test_supabase_client()
    if not client_ok:
        print("\n❌ Python 客戶端測試失敗")
        return False
    
    # 測試資料庫架構
    schema_tables = test_database_schema()
    
    # 總結報告
    print("\n" + "=" * 60)
    print("📊 測試結果總結:")
    
    print(f"✅ 環境變數: {'正常' if env_ok else '異常'}")
    print(f"✅ REST API 連接: {'正常' if existing_tables else '異常'}")
    print(f"✅ Python 客戶端: {'正常' if client_ok else '異常'}")
    print(f"✅ 資料庫架構: {'正常' if schema_tables else '異常'}")
    
    if existing_tables:
        print(f"\n📋 可存取的資料表: {existing_tables}")
    
    if schema_tables:
        print(f"\n🗄️  資料庫中的交易相關資料表: {schema_tables}")
    
    # 判斷使用哪種資料表命名
    if 'trading_stocks' in (existing_tables + schema_tables):
        print("\n✅ 使用新的資料表命名規則 (trading_*)")
        table_prefix = "trading_"
    elif 'stocks' in (existing_tables + schema_tables):
        print("\n✅ 使用舊的資料表命名規則 (無前綴)")
        table_prefix = ""
    else:
        print("\n❌ 無法確定資料表命名規則")
        return False
    
    # 測試關鍵資料表
    key_tables = [
        f"{table_prefix}stocks",
        f"{table_prefix}users",
        f"{table_prefix}positions",
        f"{table_prefix}transactions"
    ]
    
    print(f"\n🔍 測試關鍵資料表:")
    for table in key_tables:
        if table in (existing_tables + schema_tables):
            print(f"✅ {table}")
        else:
            print(f"❌ {table}")
    
    # 建議
    print(f"\n🚀 建議:")
    print("1. 資料庫連接正常，可以繼續開發")
    print("2. 使用找到的資料表名稱進行開發")
    print("3. 如果需要，可以執行資料庫遷移腳本")
    print("4. 開始後端 API 開發")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)