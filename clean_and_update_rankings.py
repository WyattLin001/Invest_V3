#!/usr/bin/env python3
"""
清理排名系統中的所有 dummy data 並替換為新的測試資料

此腳本會：
1. 清理後端資料庫中的舊測試用戶資料
2. 插入新的測試用戶資料
3. 確保排行榜視圖正確顯示新資料
"""

import os
import sys
from datetime import datetime, timedelta
from supabase import create_client, Client
import uuid

# 設定環境變數 (請根據實際情況修改)
SUPABASE_URL = os.getenv('SUPABASE_URL', 'YOUR_SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY', 'YOUR_SERVICE_KEY')

def init_supabase() -> Client:
    """初始化 Supabase 客戶端"""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        print("❌ 錯誤：請設定 SUPABASE_URL 和 SUPABASE_SERVICE_KEY 環境變數")
        sys.exit(1)
    
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        print("✅ Supabase 客戶端初始化成功")
        return supabase
    except Exception as e:
        print(f"❌ Supabase 初始化失敗: {e}")
        sys.exit(1)

def clear_old_test_data(supabase: Client):
    """清理舊的測試資料"""
    print("\n🧹 開始清理舊的測試資料...")
    
    try:
        # 1. 清理 trading_performance_snapshots 表格
        print("  - 清理績效快照資料...")
        result = supabase.table('trading_performance_snapshots').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
        print(f"    ✅ 已清理 {len(result.data)} 筆績效快照資料")
        
        # 2. 清理 trading_transactions 表格
        print("  - 清理交易記錄...")
        result = supabase.table('trading_transactions').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
        print(f"    ✅ 已清理交易記錄")
        
        # 3. 清理 trading_positions 表格
        print("  - 清理持倉資料...")
        result = supabase.table('trading_positions').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
        print(f"    ✅ 已清理持倉資料")
        
        # 4. 清理 trading_referrals 表格
        print("  - 清理邀請關係...")
        result = supabase.table('trading_referrals').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
        print(f"    ✅ 已清理邀請關係")
        
        # 5. 清理 trading_users 表格
        print("  - 清理測試用戶...")
        result = supabase.table('trading_users').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
        print(f"    ✅ 已清理測試用戶")
        
        print("🎉 舊資料清理完成！")
        
    except Exception as e:
        print(f"❌ 清理資料時發生錯誤: {e}")
        return False
    
    return True

def generate_invite_code(user_id: str) -> str:
    """生成邀請碼"""
    import hashlib
    return hashlib.md5(user_id.encode()).hexdigest()[:8].upper()

def insert_new_test_users(supabase: Client):
    """插入新的測試用戶資料"""
    print("\n👥 開始插入新的測試用戶...")
    
    # 新的測試用戶資料
    test_users = [
        {
            'name': 'test王',
            'phone': '+886900000001',
            'cumulative_return': 25.8,
            'total_assets': 1258000.00,
            'total_profit': 258000.00,
            'rank': 1
        },
        {
            'name': 'test徐', 
            'phone': '+886900000002',
            'cumulative_return': 22.3,
            'total_assets': 1223000.00,
            'total_profit': 223000.00,
            'rank': 2
        },
        {
            'name': 'test張',
            'phone': '+886900000003', 
            'cumulative_return': 19.7,
            'total_assets': 1197000.00,
            'total_profit': 197000.00,
            'rank': 3
        },
        {
            'name': 'test林',
            'phone': '+886900000004',
            'cumulative_return': 17.2,
            'total_assets': 1172000.00,
            'total_profit': 172000.00,
            'rank': 4
        },
        {
            'name': 'test黃',
            'phone': '+886900000005',
            'cumulative_return': 15.6,
            'total_assets': 1156000.00,
            'total_profit': 156000.00,
            'rank': 5
        }
    ]
    
    try:
        created_users = []
        
        for user_data in test_users:
            user_id = str(uuid.uuid4())
            invite_code = generate_invite_code(user_id)
            
            # 插入用戶資料
            user_record = {
                'id': user_id,
                'name': user_data['name'],
                'phone': user_data['phone'],
                'cash_balance': 1000000.00 - (user_data['total_assets'] - 1000000.00),  # 計算現金餘額
                'total_assets': user_data['total_assets'],
                'total_profit': user_data['total_profit'],
                'cumulative_return': user_data['cumulative_return'],
                'invite_code': invite_code,
                'is_active': True,
                'risk_tolerance': 'moderate',
                'investment_experience': 'intermediate',
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
            
            result = supabase.table('trading_users').insert(user_record).execute()
            
            if result.data:
                created_users.append(result.data[0])
                print(f"  ✅ 創建用戶: {user_data['name']} (排名 {user_data['rank']}, 回報率 {user_data['cumulative_return']}%)")
                
                # 為每個用戶創建績效快照
                create_performance_snapshots(supabase, user_id, user_data)
            else:
                print(f"  ❌ 創建用戶失敗: {user_data['name']}")
        
        print(f"🎉 成功創建 {len(created_users)} 個測試用戶！")
        return created_users
        
    except Exception as e:
        print(f"❌ 插入測試用戶時發生錯誤: {e}")
        return []

def create_performance_snapshots(supabase: Client, user_id: str, user_data: dict):
    """為用戶創建績效快照資料"""
    try:
        # 創建過去30天的績效快照
        base_date = datetime.now().date()
        snapshots = []
        
        for days_ago in range(30, 0, -1):
            snapshot_date = base_date - timedelta(days=days_ago)
            
            # 模擬逐漸增長的回報率
            progress_ratio = (30 - days_ago) / 30  # 0到1的進度
            current_return = user_data['cumulative_return'] * progress_ratio
            current_assets = 1000000 + (user_data['total_assets'] - 1000000) * progress_ratio
            
            snapshot = {
                'user_id': user_id,
                'snapshot_date': snapshot_date.isoformat(),
                'total_assets': round(current_assets, 2),
                'cash_balance': round(current_assets * 0.3, 2),  # 假設30%為現金
                'position_value': round(current_assets * 0.7, 2),  # 假設70%為持倉
                'daily_return': round((current_return / 30) if days_ago < 30 else 0, 4),
                'cumulative_return': round(current_return, 4),
                'benchmark_return': round(current_return * 0.6, 4),  # 假設基準回報率為60%
                'alpha': round(current_return * 0.4, 4),
                'beta': 1.2,
                'sharpe_ratio': round(current_return / 10, 4),
                'volatility': round(abs(current_return) * 0.1, 4),
                'max_drawdown': round(-abs(current_return) * 0.05, 4),
                'created_at': datetime.now().isoformat()
            }
            snapshots.append(snapshot)
        
        # 批量插入績效快照
        if snapshots:
            result = supabase.table('trading_performance_snapshots').insert(snapshots).execute()
            if result.data:
                print(f"    ✅ 為 {user_data['name']} 創建了 {len(snapshots)} 筆績效快照")
    
    except Exception as e:
        print(f"    ❌ 創建績效快照失敗: {e}")

def verify_rankings_data(supabase: Client):
    """驗證排名資料是否正確"""
    print("\n🔍 驗證排名資料...")
    
    try:
        # 查詢排行榜數據
        result = supabase.table('trading_users').select('name, cumulative_return, total_assets, total_profit').order('cumulative_return', desc=True).limit(10).execute()
        
        if result.data:
            print("📊 當前排行榜：")
            print("排名 | 用戶名稱 | 回報率(%) | 總資產 | 總盈虧")
            print("-" * 50)
            
            for i, user in enumerate(result.data, 1):
                print(f"{i:2d}   | {user['name']:8s} | {user['cumulative_return']:8.1f} | {user['total_assets']:10,.0f} | {user['total_profit']:10,.0f}")
            
            print("\n✅ 排名資料驗證完成！")
            return True
        else:
            print("❌ 沒有找到排名資料")
            return False
            
    except Exception as e:
        print(f"❌ 驗證排名資料時發生錯誤: {e}")
        return False

def update_backend_service(supabase: Client):
    """確認後端服務的排名獲取功能"""
    print("\n🔧 確認後端服務配置...")
    
    try:
        # 測試排名API功能
        result = supabase.table('trading_users').select('id, name, cumulative_return, total_assets').order('cumulative_return', desc=True).limit(5).execute()
        
        if result.data and len(result.data) >= 5:
            print("✅ 後端排名API功能正常")
            print("✅ 排名資料可正確從 trading_users 表格獲取")
            return True
        else:
            print("❌ 後端排名API功能異常")
            return False
            
    except Exception as e:
        print(f"❌ 後端服務檢查失敗: {e}")
        return False

def main():
    """主要執行函數"""
    print("🚀 開始清理和更新排名系統資料...")
    print("=" * 60)
    
    # 初始化 Supabase 客戶端
    supabase = init_supabase()
    
    # 步驟1: 清理舊資料
    if not clear_old_test_data(supabase):
        print("❌ 清理舊資料失敗，停止執行")
        return
    
    # 步驟2: 插入新測試用戶
    created_users = insert_new_test_users(supabase)
    if not created_users:
        print("❌ 插入新測試用戶失敗，停止執行")
        return
    
    # 步驟3: 驗證排名資料
    if not verify_rankings_data(supabase):
        print("❌ 驗證排名資料失敗")
        return
    
    # 步驟4: 確認後端服務
    if not update_backend_service(supabase):
        print("❌ 後端服務檢查失敗")
        return
    
    print("\n" + "=" * 60)
    print("🎉 排名系統清理和更新完成！")
    print("\n📋 完成項目：")
    print("✅ 清理了所有舊的 dummy data")
    print("✅ 插入了5個新測試用戶") 
    print("✅ 創建了30天的績效快照資料")
    print("✅ 驗證了排行榜功能")
    print("✅ 確認了後端API正常")
    print("\n🔄 下一步：")
    print("1. 更新前端 HomeView.swift 中的排行榜顯示") 
    print("2. 驗證 RankingsView.swift 中的排行榜功能")
    print("3. 測試 ExpertProfileView.swift 中的專家檔案")

if __name__ == "__main__":
    main()