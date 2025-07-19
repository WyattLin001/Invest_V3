#!/usr/bin/env python3
"""
檢查 Supabase 表格是否存在和結構是否正確
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'invest_simulator_backend'))

from services.db_service import DatabaseService
import json

def check_supabase_tables():
    """檢查 Supabase 表格"""
    print("🔍 檢查 Supabase 表格是否存在...")
    
    # 初始化資料庫服務
    db_service = DatabaseService()
    
    # 需要檢查的表格
    required_tables = [
        'investment_groups',
        'group_members', 
        'portfolios',
        'trading_users'
    ]
    
    for table_name in required_tables:
        print(f"\n📋 檢查表格: {table_name}")
        try:
            # 嘗試查詢表格（限制 1 筆避免大量資料）
            result = db_service.supabase.table(table_name).select('*').limit(1).execute()
            print(f"✅ 表格 {table_name} 存在，目前有 {len(result.data)} 筆資料")
            
            # 如果有資料，顯示欄位結構
            if result.data:
                print(f"📊 欄位結構: {list(result.data[0].keys())}")
            
        except Exception as e:
            print(f"❌ 表格 {table_name} 檢查失敗: {e}")
            
            # 檢查是否是 404 錯誤（表格不存在）
            if "404" in str(e):
                print(f"🚨 表格 {table_name} 不存在！")
                print(f"💡 建議：在 Supabase 控制台創建此表格")
            elif "permission" in str(e).lower():
                print(f"🔒 權限問題：無法存取 {table_name} 表格")
                print(f"💡 建議：檢查 RLS (Row Level Security) 設定")
    
    print("\n🎯 建議的 SQL 創建語句：")
    print_create_table_sql()

def print_create_table_sql():
    """列印創建表格的 SQL"""
    sql_statements = {
        'investment_groups': """
CREATE TABLE investment_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    return_rate DECIMAL(5,2) DEFAULT 0.0,
    entry_fee TEXT,
    member_count INTEGER DEFAULT 1,
    category TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
        """,
        'group_members': """
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES investment_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
        """,
        'portfolios': """
CREATE TABLE portfolios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES investment_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    total_value DECIMAL(12,2) DEFAULT 1000000,
    cash_balance DECIMAL(12,2) DEFAULT 1000000,
    return_rate DECIMAL(5,2) DEFAULT 0.0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
        """
    }
    
    for table_name, sql in sql_statements.items():
        print(f"\n-- {table_name}")
        print(sql.strip())

if __name__ == "__main__":
    check_supabase_tables()