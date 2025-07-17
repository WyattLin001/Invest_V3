#!/usr/bin/env python3
"""
投資模擬交易平台 - 最終評估報告
提供完整的資料庫狀態評估和建議
"""

import os
import sys
from dotenv import load_dotenv
import requests
import json
from datetime import datetime

# 載入環境變數
load_dotenv()

def generate_assessment_report():
    """生成完整的評估報告"""
    print("🎯 投資模擬交易平台 - 最終評估報告")
    print("=" * 60)
    print(f"📅 報告時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 1. 環境變數檢查
    print("\n1️⃣ 環境變數檢查:")
    env_vars = {
        'SUPABASE_URL': os.getenv('SUPABASE_URL'),
        'SUPABASE_SERVICE_KEY': os.getenv('SUPABASE_SERVICE_KEY'),
        'DATABASE_URL': os.getenv('DATABASE_URL'),
        'INITIAL_CAPITAL': os.getenv('INITIAL_CAPITAL'),
        'REFERRAL_BONUS': os.getenv('REFERRAL_BONUS')
    }
    
    for key, value in env_vars.items():
        if value:
            if key.endswith('KEY'):
                print(f"✅ {key}: {'*' * 20} (已設定)")
            elif key == 'DATABASE_URL':
                print(f"✅ {key}: {value[:50]}... (已設定)")
            else:
                print(f"✅ {key}: {value}")
        else:
            print(f"❌ {key}: 未設定")
    
    # 2. Supabase 專案狀態
    print("\n2️⃣ Supabase 專案狀態:")
    supabase_url = env_vars['SUPABASE_URL']
    supabase_key = env_vars['SUPABASE_SERVICE_KEY']
    
    if supabase_url and supabase_key:
        try:
            # 測試基本連接
            headers = {
                'apikey': supabase_key,
                'Authorization': f'Bearer {supabase_key}',
                'Content-Type': 'application/json'
            }
            
            # 嘗試訪問 health endpoint
            health_url = f"{supabase_url}/rest/v1/"
            response = requests.get(health_url, headers=headers)
            
            print(f"📡 Supabase 專案 URL: {supabase_url}")
            print(f"🔑 Service Key: {'已設定' if supabase_key else '未設定'}")
            print(f"🌐 連接狀態: {response.status_code}")
            
            if response.status_code == 401:
                print("❌ 授權失敗 - Service Key 可能無效或過期")
            elif response.status_code == 404:
                print("❌ 專案不存在或 URL 錯誤")
            elif response.status_code == 200:
                print("✅ 專案連接正常")
            else:
                print(f"⚠️  未知狀態碼: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 連接測試失敗: {e}")
    else:
        print("❌ 缺少必要的 Supabase 設定")
    
    # 3. 資料庫架構分析
    print("\n3️⃣ 資料庫架構分析:")
    
    # 檢查檔案中的資料庫腳本
    scripts = [
        'setup_trading_tables.sql',
        'init_database.sql',
        'setup_step_by_step.sql'
    ]
    
    for script in scripts:
        if os.path.exists(script):
            print(f"✅ 找到資料庫腳本: {script}")
            with open(script, 'r', encoding='utf-8') as f:
                content = f.read()
                if 'trading_stocks' in content:
                    print(f"   📋 使用新的資料表命名 (trading_*)")
                elif 'stocks' in content:
                    print(f"   📋 使用舊的資料表命名")
        else:
            print(f"❌ 缺少資料庫腳本: {script}")
    
    # 4. 必要的資料表清單
    print("\n4️⃣ 必要的資料表清單:")
    required_tables = [
        'trading_users',
        'trading_stocks', 
        'trading_positions',
        'trading_transactions',
        'trading_performance_snapshots',
        'trading_referrals',
        'trading_watchlists',
        'trading_alerts'
    ]
    
    for table in required_tables:
        print(f"📋 {table}")
    
    # 5. 問題診斷
    print("\n5️⃣ 問題診斷:")
    
    issues = []
    
    if not supabase_url:
        issues.append("缺少 SUPABASE_URL 環境變數")
    
    if not supabase_key:
        issues.append("缺少 SUPABASE_SERVICE_KEY 環境變數")
    
    if supabase_url and supabase_key:
        try:
            response = requests.get(f"{supabase_url}/rest/v1/", headers={'apikey': supabase_key})
            if response.status_code == 401:
                issues.append("Service Key 無效或過期")
            elif response.status_code == 404:
                issues.append("Supabase 專案不存在或 URL 錯誤")
        except:
            issues.append("無法連接到 Supabase 服務")
    
    if issues:
        print("❌ 發現以下問題:")
        for i, issue in enumerate(issues, 1):
            print(f"   {i}. {issue}")
    else:
        print("✅ 未發現明顯問題")
    
    # 6. 解決方案建議
    print("\n6️⃣ 解決方案建議:")
    
    print("📝 立即行動項目:")
    print("   1. 確認 Supabase 專案狀態")
    print("   2. 檢查 Service Key 有效性")
    print("   3. 在 Supabase Dashboard 執行資料庫設置")
    print("   4. 驗證 Row Level Security 設定")
    
    print("\n🔧 詳細步驟:")
    print("   1. 登入 Supabase Dashboard (https://supabase.com/dashboard)")
    print("   2. 選擇專案: wujlbjrouqcpnifbakmw")
    print("   3. 前往 SQL Editor")
    print("   4. 執行 setup_trading_tables.sql")
    print("   5. 檢查 Settings > API 中的 service_role key")
    print("   6. 確認 Authentication > Settings 中的 RLS 設定")
    
    print("\n🧪 測試步驟:")
    print("   1. 執行資料庫設置後重新運行此腳本")
    print("   2. 測試後端服務: python run.py")
    print("   3. 檢查健康端點: http://localhost:5000/health")
    print("   4. 測試 API 端點")
    
    # 7. 專案狀態總結
    print("\n7️⃣ 專案狀態總結:")
    
    if not issues:
        print("🎉 專案基本設定完成，可能需要執行資料庫設置")
        status = "READY_FOR_DATABASE_SETUP"
    elif "Service Key 無效或過期" in issues:
        print("🔑 需要更新 Service Key")
        status = "NEED_NEW_SERVICE_KEY"
    elif "Supabase 專案不存在或 URL 錯誤" in issues:
        print("🌐 需要檢查專案 URL")
        status = "NEED_PROJECT_VERIFICATION"
    else:
        print("⚠️  需要完成基本設定")
        status = "NEED_BASIC_SETUP"
    
    print(f"\n📊 最終狀態: {status}")
    
    # 8. 下一步行動
    print("\n8️⃣ 下一步行動:")
    
    if status == "READY_FOR_DATABASE_SETUP":
        print("✅ 準備就緒，請執行資料庫設置")
        print("   - 在 Supabase SQL Editor 中執行 setup_trading_tables.sql")
        print("   - 確認所有資料表建立成功")
        print("   - 重新運行測試腳本")
    else:
        print("🔧 需要先解決設定問題")
        print("   - 檢查並更新 .env 檔案")
        print("   - 確認 Supabase 專案狀態")
        print("   - 取得正確的 Service Key")
    
    print("\n" + "=" * 60)
    print("📝 報告完成。請根據上述建議進行操作。")
    
    return status

if __name__ == "__main__":
    status = generate_assessment_report()
    
    # 根據狀態設定退出碼
    if status == "READY_FOR_DATABASE_SETUP":
        sys.exit(0)
    else:
        sys.exit(1)