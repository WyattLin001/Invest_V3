#!/usr/bin/env python3
"""
测试Flask API端点功能
"""

import requests
import json
import sys
from datetime import datetime

API_BASE_URL = "http://localhost:5001/api"

def test_api_endpoint(endpoint, method="GET", data=None, params=None):
    """测试API端点"""
    url = f"{API_BASE_URL}{endpoint}"
    
    print(f"\n🔗 测试 {method} {url}")
    if params:
        print(f"   参数: {params}")
    if data:
        print(f"   数据: {json.dumps(data, ensure_ascii=False)}")
    
    try:
        if method == "GET":
            response = requests.get(url, params=params, timeout=10)
        elif method == "POST":
            response = requests.post(url, json=data, timeout=10)
        else:
            print(f"❌ 不支持的HTTP方法: {method}")
            return False
        
        print(f"   状态码: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            
            # 针对不同端点显示关键信息
            if "/available-tournaments" in endpoint:
                tournaments = result.get("tournaments", [])
                print(f"   ✅ 获取到 {len(tournaments)} 个锦标赛")
                for i, tournament in enumerate(tournaments[:3], 1):
                    name = tournament.get("name", "未命名")
                    creator = tournament.get("creator_label", "未知创建者")
                    print(f"      {i}. {name} ({creator})")
                
                if len(tournaments) > 3:
                    print(f"      ... 还有 {len(tournaments) - 3} 个锦标赛")
                    
                print(f"   📊 统计信息:")
                print(f"      总数: {result.get('total_count', 0)}")
                print(f"      用户创建: {result.get('user_created_count', 0)}")
                print(f"      test03创建: {result.get('test03_created_count', 0)}")
                
            elif "/user-tournaments" in endpoint:
                tournaments = result.get("tournaments", [])
                print(f"   ✅ 用户参与 {len(tournaments)} 个锦标赛")
                for i, tournament in enumerate(tournaments[:2], 1):
                    name = tournament.get("name", "未命名")
                    participation = tournament.get("participation_type", "未知")
                    print(f"      {i}. {name} ({participation})")
                    
            elif "/health" in endpoint:
                print(f"   ✅ 系统状态: {result.get('status', 'unknown')}")
                print(f"   Supabase: {'✅' if result.get('supabase_connected') else '❌'}")
                print(f"   Redis: {'✅' if result.get('redis_connected') else '❌'}")
                
            else:
                # 通用结果显示
                print(f"   ✅ 响应: {json.dumps(result, ensure_ascii=False)[:200]}...")
                
            return True
            
        else:
            print(f"   ❌ 请求失败: {response.status_code}")
            try:
                error_detail = response.json()
                print(f"   错误详情: {error_detail}")
            except:
                print(f"   错误内容: {response.text[:200]}")
            return False
        
    except requests.exceptions.ConnectionError:
        print(f"   ❌ 无法连接到API服务器，请确保Flask app正在运行")
        return False
    except Exception as e:
        print(f"   ❌ 测试失败: {e}")
        return False

def test_all_endpoints():
    """测试所有关键端点"""
    
    print("🚀 Flask API端点测试")
    print("=" * 60)
    
    test_user_id = "d64a0edd-62cc-423a-8ce4-81103b5a9770"
    
    # 测试端点列表
    tests = [
        # 健康检查
        ("GET", "/health", None, None),
        
        # 锦标赛相关
        ("GET", "/available-tournaments", None, None),
        ("GET", "/available-tournaments", None, {"user_id": test_user_id}),
        ("GET", "/user-tournaments", None, {"user_id": test_user_id}),
        
        # 股票相关
        ("GET", "/taiwan-stocks", None, None),
        ("GET", "/quote", None, {"symbol": "2330"}),
    ]
    
    passed = 0
    failed = 0
    
    for method, endpoint, data, params in tests:
        if test_api_endpoint(endpoint, method, data, params):
            passed += 1
        else:
            failed += 1
    
    print(f"\n📊 测试结果:")
    print(f"   ✅ 通过: {passed}")
    print(f"   ❌ 失败: {failed}")
    print(f"   📈 成功率: {passed/(passed+failed)*100:.1f}%")
    
    return failed == 0

def start_flask_app():
    """启动Flask应用"""
    import subprocess
    import time
    import os
    
    print("🚀 启动Flask应用...")
    
    # 检查是否已经在运行
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=2)
        if response.status_code == 200:
            print("✅ Flask应用已在运行")
            return True
    except:
        pass
    
    try:
        # 启动Flask应用
        print("⚡ 启动新的Flask实例...")
        process = subprocess.Popen([
            sys.executable, "app.py"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # 等待启动
        for i in range(10):
            time.sleep(1)
            try:
                response = requests.get(f"{API_BASE_URL}/health", timeout=2)
                if response.status_code == 200:
                    print("✅ Flask应用启动成功")
                    return True
            except:
                continue
        
        print("❌ Flask应用启动超时")
        return False
        
    except Exception as e:
        print(f"❌ 启动Flask应用失败: {e}")
        return False

def main():
    """主函数"""
    
    # 检查Flask应用是否运行
    print("🔍 检查Flask应用状态...")
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=3)
        if response.status_code == 200:
            print("✅ Flask应用正在运行")
        else:
            print("⚠️ Flask应用响应异常")
    except:
        print("❌ 无法连接到Flask应用")
        print("💡 请先启动Flask应用: python app.py")
        sys.exit(1)
    
    # 运行测试
    success = test_all_endpoints()
    
    if success:
        print("\n🎉 所有测试通过！")
    else:
        print("\n⚠️ 部分测试失败，请检查日志")

if __name__ == "__main__":
    main()