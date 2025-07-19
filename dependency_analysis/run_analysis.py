#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Invest_V3 依賴分析工具 - 一鍵執行腳本
整合所有依賴視覺化功能的主要入口

Author: Claude Code Assistant
Version: 1.0.0
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

def print_banner():
    """顯示橫幅"""
    banner = """
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   📱 Invest_V3 Code Dependency Visualization Tool           ║
║                                                              ║
║   🎯 功能特色:                                                ║
║   • Swift 代碼依賴分析                                        ║
║   • Graphviz 圖表生成                                        ║
║   • 實時監控儀表板                                            ║
║   • VS Code 整合                                             ║
║                                                              ║
║   🚀 台灣去中心化投資競賽平台專用工具                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"""
    print(banner)

def check_requirements():
    """檢查系統需求"""
    print("🔍 檢查系統需求...")
    
    # 檢查 Python 版本
    if sys.version_info < (3, 8):
        print("❌ 需要 Python 3.8 或更高版本")
        return False
    print(f"✅ Python {sys.version.split()[0]}")
    
    # 檢查必要的目錄
    project_root = Path(".")
    swift_files = list(project_root.rglob("*.swift"))
    
    if not swift_files:
        print("⚠️  未發現 Swift 檔案，請確認專案路徑")
    else:
        print(f"✅ 發現 {len(swift_files)} 個 Swift 檔案")
    
    return True

def install_dependencies():
    """安裝依賴套件"""
    print("📦 安裝依賴套件...")
    
    # 執行安裝腳本
    install_script = Path("dependency_analysis/install_dependencies.sh")
    if install_script.exists():
        try:
            subprocess.run(["bash", str(install_script)], check=True)
            return True
        except subprocess.CalledProcessError:
            print("❌ 依賴安裝失敗")
            return False
    else:
        print("❌ 找不到安裝腳本")
        return False

def run_basic_analysis(project_path=".", output_dir="dependency_reports"):
    """執行基礎依賴分析"""
    print("🔍 執行基礎依賴分析...")
    
    analyzer_script = Path("dependency_analysis/swift_dependency_analyzer.py")
    if not analyzer_script.exists():
        print("❌ 找不到分析器腳本")
        return False
    
    try:
        cmd = [
            "python3", str(analyzer_script),
            "--project-path", project_path,
            "--output-dir", output_dir
        ]
        subprocess.run(cmd, check=True)
        print("✅ 基礎分析完成")
        return True
    except subprocess.CalledProcessError:
        print("❌ 基礎分析失敗")
        return False

def generate_graphviz_charts(project_path=".", output_dir="dependency_reports"):
    """生成 Graphviz 圖表"""
    print("🎨 生成 Graphviz 圖表...")
    
    generator_script = Path("dependency_analysis/graphviz_generator.py")
    if not generator_script.exists():
        print("❌ 找不到圖表生成器")
        return False
    
    try:
        cmd = [
            "python3", str(generator_script),
            "--project-path", project_path,
            "--output-dir", output_dir,
            "--format", "svg"
        ]
        subprocess.run(cmd, check=True)
        print("✅ Graphviz 圖表生成完成")
        return True
    except subprocess.CalledProcessError:
        print("❌ 圖表生成失敗")
        return False

def setup_vscode_integration():
    """設定 VS Code 整合"""
    print("🔧 設定 VS Code 整合...")
    
    integration_script = Path("dependency_analysis/vscode_integration.py")
    if not integration_script.exists():
        print("❌ 找不到 VS Code 整合腳本")
        return False
    
    try:
        subprocess.run(["python3", str(integration_script)], check=True)
        print("✅ VS Code 整合設定完成")
        return True
    except subprocess.CalledProcessError:
        print("❌ VS Code 整合設定失敗")
        return False

def start_dashboard(project_path=".", port=8050):
    """啟動監控儀表板"""
    print("🚀 啟動監控儀表板...")
    
    dashboard_script = Path("dependency_analysis/dependency_dashboard.py")
    if not dashboard_script.exists():
        print("❌ 找不到儀表板腳本")
        return False
    
    print(f"📱 儀表板將在 http://localhost:{port} 啟動")
    print("按 Ctrl+C 停止服務")
    
    try:
        cmd = [
            "python3", str(dashboard_script),
            "--project-path", project_path,
            "--port", str(port)
        ]
        subprocess.run(cmd)
        return True
    except KeyboardInterrupt:
        print("\n⏹️  儀表板已停止")
        return True
    except subprocess.CalledProcessError:
        print("❌ 儀表板啟動失敗")
        return False

def open_reports(output_dir="dependency_reports"):
    """開啟報告目錄"""
    reports_path = Path(output_dir)
    if not reports_path.exists():
        print(f"❌ 報告目錄不存在: {reports_path}")
        return
    
    try:
        if sys.platform.startswith('darwin'):  # macOS
            subprocess.run(["open", str(reports_path)])
        elif sys.platform.startswith('linux'):  # Linux
            subprocess.run(["xdg-open", str(reports_path)])
        elif sys.platform.startswith('win'):  # Windows
            subprocess.run(["start", str(reports_path)], shell=True)
        print(f"📂 已開啟報告目錄: {reports_path}")
    except Exception as e:
        print(f"⚠️  無法開啟目錄: {e}")
        print(f"請手動查看: {reports_path.absolute()}")

def show_menu():
    """顯示主選單"""
    menu = """
┌─────────────────────────────────────────────────────────────┐
│                        🎯 主選單                             │
├─────────────────────────────────────────────────────────────┤
│ 1. 🔍 執行完整依賴分析                                       │
│ 2. 🎨 生成 Graphviz 圖表                                    │
│ 3. 🚀 啟動實時監控儀表板                                     │
│ 4. 🔧 設定 VS Code 整合                                     │
│ 5. 📦 安裝/更新依賴套件                                      │
│ 6. 📂 開啟報告目錄                                          │
│ 7. ❓ 顯示說明文件                                          │
│ 0. 🚪 退出                                                  │
└─────────────────────────────────────────────────────────────┘
"""
    print(menu)

def show_help():
    """顯示說明文件"""
    help_text = """
📚 Invest_V3 依賴視覺化工具說明

🎯 工具功能:
• Swift 代碼依賴分析 - 分析檔案間的 import 和類別引用關係
• Graphviz 圖表生成 - 生成精美的依賴關係圖表
• 實時監控儀表板 - 提供互動式的 Web 介面
• VS Code 整合 - 無縫整合到開發環境

📊 生成的報告:
• dependency_analysis.json - 完整的分析數據
• dependency_report.md - Markdown 格式報告  
• *.png / *.svg - 視覺化圖表
• *.dot - Graphviz 原始檔案

🔧 系統需求:
• Python 3.8+
• Graphviz (系統套件)
• 相關 Python 套件 (自動安裝)

💡 使用技巧:
• 大型專案建議使用 SVG 格式
• 可透過 VS Code 任務快速執行
• 儀表板支援實時數據更新
• 支援多種佈局引擎 (dot, neato, fdp)

🐛 常見問題:
• 如果圖表不顯示，檢查 Graphviz 是否正確安裝
• Python 套件錯誤請重新執行安裝腳本
• 大型專案分析可能需要較長時間

📞 技術支援:
• 查看 dependency_analysis/README_VSCODE.md
• 檢查終端錯誤訊息
• 確認專案路徑和 Swift 檔案

按任意鍵返回主選單...
"""
    print(help_text)
    input()

def main():
    """主函數"""
    parser = argparse.ArgumentParser(description='Invest_V3 依賴視覺化工具')
    parser.add_argument('--project-path', default='.', help='專案路徑')
    parser.add_argument('--output-dir', default='dependency_reports', help='輸出目錄')
    parser.add_argument('--port', type=int, default=8050, help='儀表板埠號')
    parser.add_argument('--auto', action='store_true', help='自動執行完整分析')
    
    args = parser.parse_args()
    
    print_banner()
    
    # 檢查系統需求
    if not check_requirements():
        sys.exit(1)
    
    # 自動模式
    if args.auto:
        print("🤖 自動模式：執行完整分析...")
        run_basic_analysis(args.project_path, args.output_dir)
        generate_graphviz_charts(args.project_path, args.output_dir)
        open_reports(args.output_dir)
        return
    
    # 互動模式
    while True:
        show_menu()
        
        try:
            choice = input("請選擇功能 (0-7): ").strip()
        except KeyboardInterrupt:
            print("\n👋 再見！")
            break
        
        if choice == '0':
            print("👋 再見！")
            break
        elif choice == '1':
            run_basic_analysis(args.project_path, args.output_dir)
            generate_graphviz_charts(args.project_path, args.output_dir)
            open_reports(args.output_dir)
        elif choice == '2':
            generate_graphviz_charts(args.project_path, args.output_dir)
        elif choice == '3':
            start_dashboard(args.project_path, args.port)
        elif choice == '4':
            setup_vscode_integration()
        elif choice == '5':
            install_dependencies()
        elif choice == '6':
            open_reports(args.output_dir)
        elif choice == '7':
            show_help()
        else:
            print("❌ 無效選擇，請重新輸入")
        
        if choice != '0':
            input("\n按 Enter 鍵繼續...")

if __name__ == "__main__":
    main()
