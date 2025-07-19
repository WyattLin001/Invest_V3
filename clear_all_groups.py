#!/usr/bin/env python3
"""
清理所有投資群組的腳本
用於測試群組清理功能
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'invest_simulator_backend'))

from services.db_service import DatabaseService
import json

def clear_all_groups():
    """清理所有投資群組"""
    print("🧹 開始清理所有投資群組...")
    
    # 初始化資料庫服務
    db_service = DatabaseService()
    
    print("\n1️⃣ 清理所有投資群組...")
    clear_result = db_service.clear_all_investment_groups()
    print(f"清理結果: {json.dumps(clear_result, indent=2, ensure_ascii=False)}")
    
    print("\n2️⃣ 完全重置群組系統...")
    reset_result = db_service.initialize_clean_groups_system()
    print(f"重置結果: {json.dumps(reset_result, indent=2, ensure_ascii=False)}")
    
    print("\n✅ 所有群組清理完成！現在系統是乾淨的狀態")

if __name__ == "__main__":
    clear_all_groups()