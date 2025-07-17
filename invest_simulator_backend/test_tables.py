#!/usr/bin/env python3
"""
投資模擬交易平台 - 資料表驗證腳本
測試所有交易相關資料表是否正確建立並檢查示例資料
"""

import os
import sys
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import RealDictCursor
import json

# 載入環境變數
load_dotenv()

def test_database_connection():
    """測試資料庫連接"""
    print("🔌 測試資料庫連接...")
    
    try:
        # 使用 PostgreSQL 連接字串
        database_url = os.getenv('DATABASE_URL')
        if not database_url:
            print("❌ 缺少 DATABASE_URL 環境變數")
            return None
        
        # 連接到資料庫
        conn = psycopg2.connect(database_url)
        print("✅ 資料庫連接成功")
        return conn
        
    except Exception as e:
        print(f"❌ 資料庫連接失敗: {e}")
        return None

def check_table_exists(conn, table_name):
    """檢查資料表是否存在"""
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT EXISTS (
                    SELECT 1 
                    FROM information_schema.tables 
                    WHERE table_schema = 'public' 
                    AND table_name = %s
                );
            """, (table_name,))
            
            exists = cur.fetchone()[0]
            return exists
            
    except Exception as e:
        print(f"❌ 檢查資料表 {table_name} 時發生錯誤: {e}")
        return False

def get_table_count(conn, table_name):
    """取得資料表記錄數"""
    try:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {table_name};")
            count = cur.fetchone()[0]
            return count
            
    except Exception as e:
        print(f"❌ 查詢資料表 {table_name} 記錄數時發生錯誤: {e}")
        return 0

def get_sample_data(conn, table_name, limit=3):
    """取得資料表示例資料"""
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(f"SELECT * FROM {table_name} LIMIT %s;", (limit,))
            rows = cur.fetchall()
            return [dict(row) for row in rows]
            
    except Exception as e:
        print(f"❌ 查詢資料表 {table_name} 示例資料時發生錯誤: {e}")
        return []

def test_trading_tables():
    """測試所有交易相關資料表"""
    print("🎯 投資模擬交易平台 - 資料表驗證")
    print("=" * 60)
    
    # 連接資料庫
    conn = test_database_connection()
    if not conn:
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
        
        # 檢查資料表是否存在
        exists = check_table_exists(conn, table_name)
        
        if exists:
            print(f"✅ 資料表 {table_name} 存在")
            
            # 取得記錄數
            count = get_table_count(conn, table_name)
            print(f"📊 記錄數: {count}")
            
            # 取得示例資料
            if count > 0:
                sample_data = get_sample_data(conn, table_name)
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
                    print(f"   {i}. {safe_row}")
            else:
                print("   (無資料)")
            
            table_info[table_name] = {
                'exists': True,
                'count': count
            }
            
        else:
            print(f"❌ 資料表 {table_name} 不存在")
            all_tables_exist = False
            table_info[table_name] = {
                'exists': False,
                'count': 0
            }
    
    # 特別檢查股票資料表
    print(f"\n🏢 股票資料詳細檢查:")
    if table_info.get('trading_stocks', {}).get('exists', False):
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # 按市場分類統計
                cur.execute("""
                    SELECT market, COUNT(*) as count
                    FROM trading_stocks
                    GROUP BY market
                    ORDER BY count DESC;
                """)
                market_stats = cur.fetchall()
                
                print("   📈 按市場統計:")
                for stat in market_stats:
                    print(f"     {stat['market']}: {stat['count']} 檔")
                
                # 按板塊分類統計
                cur.execute("""
                    SELECT sector, COUNT(*) as count
                    FROM trading_stocks
                    WHERE sector IS NOT NULL
                    GROUP BY sector
                    ORDER BY count DESC;
                """)
                sector_stats = cur.fetchall()
                
                print("   🏭 按板塊統計:")
                for stat in sector_stats:
                    print(f"     {stat['sector']}: {stat['count']} 檔")
                
        except Exception as e:
            print(f"   ❌ 股票資料統計失敗: {e}")
    
    # 關閉連接
    conn.close()
    
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
    
    if all_tables_exist:
        print("\n🎉 所有交易資料表驗證成功！")
        print("✅ 資料庫架構完整，可以開始交易系統開發")
        
        # 建議下一步
        print("\n🚀 建議下一步:")
        print("1. 開始用戶註冊功能測試")
        print("2. 測試股票資料 API 整合")
        print("3. 開發交易邏輯功能")
        print("4. 建立 iOS 前端連接")
        
        return True
    else:
        print("\n⚠️  部分資料表缺失，請檢查資料庫設置")
        print("🔧 解決方案:")
        print("1. 執行資料庫設置腳本: psql -f setup_trading_tables.sql")
        print("2. 檢查 Supabase 權限設定")
        print("3. 確認資料庫連接正常")
        
        return False

if __name__ == "__main__":
    success = test_trading_tables()
    sys.exit(0 if success else 1)