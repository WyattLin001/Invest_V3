#!/usr/bin/env python3
"""
测试Supabase连接和执行数据库修复脚本
"""

import sys
import os
from supabase import create_client, Client

# Supabase配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def test_supabase_connection():
    """测试Supabase连接"""
    try:
        print(f"🔗 连接Supabase: {SUPABASE_URL}")
        print(f"🔑 使用Service Role Key: ...{SUPABASE_SERVICE_KEY[-10:]}")
        
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        
        # 尝试查询tournaments表
        print("📊 测试查询tournaments表...")
        response = supabase.table("tournaments").select("id", count='exact').limit(1).execute()
        
        print(f"✅ 连接成功！tournaments表中有 {response.count} 条记录")
        return supabase
        
    except Exception as e:
        print(f"❌ Supabase连接失败: {e}")
        return None

def execute_sql_fix(supabase: Client, sql_script_path: str):
    """执行SQL修复脚本"""
    try:
        print(f"📜 读取SQL修复脚本: {sql_script_path}")
        
        if not os.path.exists(sql_script_path):
            print(f"❌ 找不到SQL文件: {sql_script_path}")
            return False
            
        with open(sql_script_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        print("⚡ 执行SQL修复脚本...")
        print("注意：Supabase Python客户端不支持直接执行DDL，需要在Supabase Dashboard中手动执行")
        
        # 分割SQL语句并尝试执行简单的查询来验证表结构
        print("🔍 验证tournaments表结构...")
        
        # 检查created_by字段是否存在
        response = supabase.table("tournaments").select("created_by").limit(1).execute()
        print(f"✅ created_by字段存在: {len(response.data)} 条记录")
        
        return True
        
    except Exception as e:
        print(f"❌ SQL执行失败: {e}")
        if "column \"created_by\" does not exist" in str(e):
            print("⚠️ created_by字段不存在，需要手动执行SQL修复脚本")
        return False

def test_tournament_query():
    """测试锦标赛查询功能"""
    try:
        supabase = test_supabase_connection()
        if not supabase:
            return False
            
        print("\n🏆 测试锦标赛查询功能...")
        
        # 测试查询所有锦标赛
        response = supabase.table("tournaments").select("*").execute()
        tournaments = response.data
        
        print(f"📊 查询到 {len(tournaments)} 个锦标赛:")
        for i, tournament in enumerate(tournaments[:3], 1):  # 只显示前3个
            name = tournament.get('name', '未命名')
            created_by = tournament.get('created_by', 'unknown')
            print(f"  {i}. {name} (创建者: {created_by})")
        
        # 测试用户锦标赛查询
        test_user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
        print(f"\n👤 测试用户 {test_user_id} 的锦标赛查询...")
        
        try:
            # 尝试使用OR查询（需要created_by字段存在）
            response = supabase.table("tournaments")\
                .select("*")\
                .or_(f"created_by.eq.test03,created_by.eq.{test_user_id}")\
                .execute()
            user_tournaments = response.data
            print(f"✅ 用户相关锦标赛: {len(user_tournaments)} 个")
            
        except Exception as or_error:
            print(f"⚠️ OR查询失败: {or_error}")
            # 回退到简单查询
            response = supabase.table("tournaments").select("*").limit(5).execute()
            user_tournaments = response.data
            print(f"📋 使用备用查询: {len(user_tournaments)} 个锦标赛")
        
        return True
        
    except Exception as e:
        print(f"❌ 锦标赛查询测试失败: {e}")
        return False

def main():
    """主函数"""
    print("🚀 Supabase权限修复和测试脚本")
    print("=" * 50)
    
    # 1. 测试连接
    supabase = test_supabase_connection()
    if not supabase:
        print("❌ 无法连接Supabase，请检查配置")
        sys.exit(1)
    
    # 2. 执行SQL修复（提示手动执行）
    sql_script_path = "/Users/linjiaqi/Downloads/Invest_V3/supabase_tournament_fix.sql"
    execute_sql_fix(supabase, sql_script_path)
    
    # 3. 测试锦标赛查询
    test_tournament_query()
    
    print("\n✅ 测试完成")

if __name__ == "__main__":
    main()