#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Invest_V3 Visual Studio Code 擴展整合
為 VS Code 提供依賴視覺化功能

Author: Claude Code Assistant
Version: 1.0.0
"""

import json
import os
from pathlib import Path
from typing import Dict, List

def create_vscode_task():
    """為 VS Code 創建依賴分析任務"""
    task_config = {
        "version": "2.0.0",
        "tasks": [
            {
                "label": "Invest_V3: 分析依賴關係",
                "type": "shell",
                "command": "python3",
                "args": [
                    "dependency_analysis/swift_dependency_analyzer.py",
                    "--project-path", "${workspaceFolder}",
                    "--output-dir", "${workspaceFolder}/dependency_reports"
                ],
                "group": "build",
                "presentation": {
                    "echo": True,
                    "reveal": "always",
                    "focus": False,
                    "panel": "shared",
                    "showReuseMessage": True,
                    "clear": False
                },
                "options": {
                    "cwd": "${workspaceFolder}"
                },
                "problemMatcher": []
            },
            {
                "label": "Invest_V3: 生成 Graphviz 圖表",
                "type": "shell",
                "command": "python3",
                "args": [
                    "dependency_analysis/graphviz_generator.py",
                    "--project-path", "${workspaceFolder}",
                    "--output-dir", "${workspaceFolder}/dependency_reports",
                    "--format", "svg"
                ],
                "group": "build",
                "presentation": {
                    "echo": True,
                    "reveal": "always",
                    "focus": False,
                    "panel": "shared"
                },
                "options": {
                    "cwd": "${workspaceFolder}"
                },
                "dependsOn": "Invest_V3: 分析依賴關係"
            },
            {
                "label": "Invest_V3: 啟動依賴儀表板",
                "type": "shell",
                "command": "python3",
                "args": [
                    "dependency_analysis/dependency_dashboard.py",
                    "--project-path", "${workspaceFolder}",
                    "--port", "8050"
                ],
                "group": "build",
                "presentation": {
                    "echo": True,
                    "reveal": "always",
                    "focus": True,
                    "panel": "new"
                },
                "options": {
                    "cwd": "${workspaceFolder}"
                },
                "isBackground": True,
                "problemMatcher": []
            },
            {
                "label": "Invest_V3: 完整依賴分析",
                "dependsOrder": "sequence",
                "dependsOn": [
                    "Invest_V3: 分析依賴關係",
                    "Invest_V3: 生成 Graphviz 圖表"
                ],
                "group": {
                    "kind": "build",
                    "isDefault": True
                }
            }
        ]
    }
    
    return task_config

def create_vscode_launch():
    """為 VS Code 創建啟動配置"""
    launch_config = {
        "version": "0.2.0",
        "configurations": [
            {
                "name": "Invest_V3: Debug 依賴分析器",
                "type": "python",
                "request": "launch",
                "program": "${workspaceFolder}/dependency_analysis/swift_dependency_analyzer.py",
                "args": [
                    "--project-path", "${workspaceFolder}",
                    "--output-dir", "${workspaceFolder}/dependency_reports"
                ],
                "console": "integratedTerminal",
                "cwd": "${workspaceFolder}",
                "env": {},
                "envFile": "${workspaceFolder}/.env"
            },
            {
                "name": "Invest_V3: Debug 儀表板",
                "type": "python",
                "request": "launch",
                "program": "${workspaceFolder}/dependency_analysis/dependency_dashboard.py",
                "args": [
                    "--project-path", "${workspaceFolder}",
                    "--port", "8050",
                    "--debug"
                ],
                "console": "integratedTerminal",
                "cwd": "${workspaceFolder}"
            }
        ]
    }
    
    return launch_config

def create_vscode_settings():
    """為 VS Code 創建專案設定"""
    settings = {
        "python.defaultInterpreterPath": "./venv/bin/python",
        "python.terminal.activateEnvironment": True,
        "files.associations": {
            "*.dot": "dot",
            "*.gv": "dot"
        },
        "files.exclude": {
            "**/.git": True,
            "**/.DS_Store": True,
            "**/node_modules": True,
            "**/venv": True,
            "**/__pycache__": True,
            "**/*.pyc": True,
            "dependency_reports/**/*.png": False,
            "dependency_reports/**/*.svg": False
        },
        "search.exclude": {
            "dependency_reports": True,
            "venv": True,
            "**/__pycache__": True
        },
        "editor.rulers": [80, 120],
        "editor.formatOnSave": True,
        "python.formatting.provider": "black",
        "python.linting.enabled": True,
        "python.linting.pylintEnabled": True,
        "workbench.colorCustomizations": {
            "activityBar.activeBackground": "#00B900",
            "activityBar.activeBorder": "#FD7E14",
            "statusBar.background": "#00B900",
            "statusBar.foreground": "#ffffff"
        }
    }
    
    return settings

def create_vscode_extensions():
    """推薦的 VS Code 擴展"""
    extensions = {
        "recommendations": [
            "ms-python.python",
            "ms-python.flake8",
            "ms-python.black-formatter",
            "joaompinto.vscode-graphviz",
            "redhat.vscode-yaml",
            "ms-vscode.vscode-json",
            "streetsidesoftware.code-spell-checker",
            "ms-toolsai.jupyter",
            "ms-vscode.live-server",
            "formulahendry.auto-rename-tag",
            "ms-vscode-remote.remote-containers"
        ]
    }
    
    return extensions

def setup_vscode_integration(project_path: str = "."):
    """設定 VS Code 整合"""
    project_root = Path(project_path)
    vscode_dir = project_root / ".vscode"
    vscode_dir.mkdir(exist_ok=True)
    
    print("🔧 設定 VS Code 整合...")
    
    # 創建 tasks.json
    tasks_file = vscode_dir / "tasks.json"
    with open(tasks_file, 'w', encoding='utf-8') as f:
        json.dump(create_vscode_task(), f, indent=2, ensure_ascii=False)
    print(f"✅ 創建 {tasks_file}")
    
    # 創建 launch.json
    launch_file = vscode_dir / "launch.json"
    with open(launch_file, 'w', encoding='utf-8') as f:
        json.dump(create_vscode_launch(), f, indent=2, ensure_ascii=False)
    print(f"✅ 創建 {launch_file}")
    
    # 創建 settings.json
    settings_file = vscode_dir / "settings.json"
    with open(settings_file, 'w', encoding='utf-8') as f:
        json.dump(create_vscode_settings(), f, indent=2, ensure_ascii=False)
    print(f"✅ 創建 {settings_file}")
    
    # 創建 extensions.json
    extensions_file = vscode_dir / "extensions.json"
    with open(extensions_file, 'w', encoding='utf-8') as f:
        json.dump(create_vscode_extensions(), f, indent=2, ensure_ascii=False)
    print(f"✅ 創建 {extensions_file}")
    
    # 創建使用說明
    readme_content = """# 📱 Invest_V3 依賴視覺化工具 - VS Code 整合

## 🚀 快速開始

### 1. 安裝依賴
按 `Ctrl+Shift+P` (或 `Cmd+Shift+P`) 開啟命令面板，執行：
```
Tasks: Run Task > Invest_V3: 安裝依賴
```

### 2. 分析依賴關係
```
Tasks: Run Task > Invest_V3: 完整依賴分析
```

### 3. 啟動即時儀表板
```
Tasks: Run Task > Invest_V3: 啟動依賴儀表板
```
然後在瀏覽器中訪問 http://localhost:8050

## 🔧 可用任務

- **分析依賴關係**: 掃描 Swift 檔案並分析依賴
- **生成 Graphviz 圖表**: 建立視覺化依賴圖
- **啟動依賴儀表板**: 執行互動式分析工具
- **完整依賴分析**: 執行完整的分析流程

## 📊 生成的報告

分析完成後，報告將儲存在 `dependency_reports/` 目錄：

- `dependency_analysis.json` - 完整的分析數據
- `dependency_report.md` - Markdown 格式報告
- `*.png` / `*.svg` - 視覺化圖表
- `*.dot` - Graphviz 原始檔案

## 🎯 VS Code 快捷鍵

- `Ctrl+Shift+P` - 開啟命令面板
- `F5` - 執行偵錯配置
- `Ctrl+Shift+` ` - 開啟整合終端
- `Ctrl+Shift+E` - 開啟檔案總管

## 🔍 除錯模式

使用 F5 或偵錯面板啟動除錯模式：
- **Debug 依賴分析器** - 偵錯分析工具
- **Debug 儀表板** - 偵錯 Web 儀表板

## 📁 檔案結構

```
.vscode/
├── tasks.json          # 任務配置
├── launch.json         # 偵錯配置
├── settings.json       # 專案設定
└── extensions.json     # 推薦擴展

dependency_analysis/
├── swift_dependency_analyzer.py
├── graphviz_generator.py
├── dependency_dashboard.py
└── install_dependencies.sh

dependency_reports/     # 生成的報告
├── *.json
├── *.md
├── *.png
└── *.dot
```

## 🎨 自訂配色

專案使用 Invest_V3 品牌配色：
- 主要綠色: #00B900
- 次要橙色: #FD7E14

## 💡 提示

1. 確保已安裝 Python 3.8+ 和必要的套件
2. 首次使用請執行安裝腳本
3. 大型專案分析可能需要較長時間
4. 使用 SVG 格式獲得最佳的圖表品質
"""
    
    readme_file = project_root / "dependency_analysis" / "README_VSCODE.md"
    with open(readme_file, 'w', encoding='utf-8') as f:
        f.write(readme_content)
    print(f"✅ 創建 {readme_file}")
    
    print("\n🎉 VS Code 整合設定完成！")
    print("\n📋 後續步驟：")
    print("1. 在 VS Code 中開啟專案")
    print("2. 安裝推薦的擴展 (會自動提示)")
    print("3. 按 Ctrl+Shift+P 執行任務")
    print("4. 享受視覺化的依賴分析！")

def main():
    """主函數"""
    import argparse
    
    parser = argparse.ArgumentParser(description='設定 VS Code 整合')
    parser.add_argument('--project-path', default='.', help='專案路徑')
    
    args = parser.parse_args()
    
    setup_vscode_integration(args.project_path)

if __name__ == "__main__":
    main()
