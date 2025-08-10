#!/usr/bin/env python3
"""
更新tournaments表中的created_by_name字段
"""

from supabase import create_client, Client

# Supabase配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"

def update_tournaments_created_by():
    """更新tournaments表中的created_by_name字段"""
    try:
        print("🔗 连接Supabase...")
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        
        # 获取所有tournaments
        print("📊 获取现有tournaments...")
        response = supabase.table("tournaments").select("*").execute()
        tournaments = response.data
        print(f"找到 {len(tournaments)} 个tournaments")
        
        # 更新每个tournament的created_by_name
        updated_count = 0
        for tournament in tournaments:
            tournament_id = tournament['id']
            current_created_by_name = tournament.get('created_by_name')
            
            print(f"🏆 处理tournament: {tournament.get('name', '未命名')} (ID: {tournament_id})")
            print(f"   当前created_by_name: {current_created_by_name}")
            
            # 如果created_by_name为空，设置为test03
            if not current_created_by_name:
                print("   ⚡ 更新created_by_name为test03...")
                update_response = supabase.table("tournaments")\
                    .update({"created_by_name": "test03"})\
                    .eq("id", tournament_id)\
                    .execute()
                
                if update_response.data:
                    print(f"   ✅ 更新成功")
                    updated_count += 1
                else:
                    print(f"   ❌ 更新失败")
            else:
                print(f"   ℹ️ 已有created_by_name，跳过")
        
        print(f"\n✅ 处理完成，更新了 {updated_count} 个tournaments")
        
        # 验证更新结果
        print("\n🔍 验证更新结果...")
        verification_response = supabase.table("tournaments").select("id", "name", "created_by_name").execute()
        for tournament in verification_response.data:
            name = tournament.get('name', '未命名')
            created_by_name = tournament.get('created_by_name', 'NULL')
            print(f"   • {name}: created_by_name = {created_by_name}")
        
        return True
        
    except Exception as e:
        print(f"❌ 更新tournaments失败: {e}")
        return False

def add_sample_user_tournaments():
    """添加示例用户创建的tournaments"""
    try:
        print("\n🏆 添加示例用户tournaments...")
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        
        user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
        
        sample_tournaments = [
            {
                "name": "我的科技股專題賽",
                "description": "我創建的專注於科技股投資的錦標賽，歡迎所有對科技股感興趣的投資者參加。",
                "short_description": "我創建的科技股投資錦標賽",
                "type": "monthly",
                "status": "ongoing",
                "start_date": "2025-08-05T00:00:00Z",
                "end_date": "2025-09-05T23:59:59Z",
                "initial_balance": 200000.0,
                "max_participants": 50,
                "current_participants": 15,
                "entry_fee": 0.0,
                "prize_pool": 25000.0,
                "risk_limit_percentage": 20.0,
                "min_holding_rate": 0.6,
                "max_single_stock_rate": 0.3,
                "rules": '["專注科技股", "最大單股持倉30%", "最低持倉率60%", "風險限制20%"]',
                "is_featured": False,
                "created_by_name": user_id
            },
            {
                "name": "我的價值投資挑戰",
                "description": "我創建的長期價值投資策略錦標賽，適合喜歡價值投資的投資者。",
                "short_description": "我創建的價值投資策略錦標賽",
                "type": "quarterly",
                "status": "ongoing",
                "start_date": "2025-08-08T00:00:00Z",
                "end_date": "2025-11-08T23:59:59Z",
                "initial_balance": 150000.0,
                "max_participants": 30,
                "current_participants": 8,
                "entry_fee": 0.0,
                "prize_pool": 15000.0,
                "risk_limit_percentage": 15.0,
                "min_holding_rate": 0.7,
                "max_single_stock_rate": 0.25,
                "rules": '["價值投資策略", "長期持有", "最大單股持倉25%", "最低持倉率70%"]',
                "is_featured": False,
                "created_by_name": user_id
            }
        ]
        
        for tournament_data in sample_tournaments:
            print(f"🎯 添加tournament: {tournament_data['name']}")
            
            try:
                insert_response = supabase.table("tournaments").insert(tournament_data).execute()
                if insert_response.data:
                    print(f"   ✅ 添加成功")
                else:
                    print(f"   ❌ 添加失败")
            except Exception as insert_error:
                print(f"   ⚠️ 添加失败（可能已存在）: {insert_error}")
        
        return True
        
    except Exception as e:
        print(f"❌ 添加示例tournaments失败: {e}")
        return False

def main():
    """主函数"""
    print("🚀 更新tournaments表创建者信息")
    print("=" * 50)
    
    # 1. 更新现有tournaments的created_by_name
    if update_tournaments_created_by():
        print("✅ 现有tournaments更新完成")
    else:
        print("❌ 现有tournaments更新失败")
        return
    
    # 2. 添加示例用户tournaments
    if add_sample_user_tournaments():
        print("✅ 示例用户tournaments添加完成")
    else:
        print("❌ 示例用户tournaments添加失败")
    
    print("\n🎉 所有操作完成！")

if __name__ == "__main__":
    main()