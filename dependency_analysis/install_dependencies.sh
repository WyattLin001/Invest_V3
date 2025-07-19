#!/bin/bash
# Invest_V3 依賴視覺化工具安裝腳本
# Author: Claude Code Assistant

echo "🚀 Invest_V3 依賴視覺化工具安裝程式"
echo "=========================================="

# 檢查 Python 版本
echo "📋 檢查 Python 環境..."
python3 --version || {
    echo "❌ Python 3 未安裝，請先安裝 Python 3.8+"
    exit 1
}

# 檢查並安裝 Graphviz 系統套件
echo "📦 檢查 Graphviz 系統套件..."
if command -v dot &> /dev/null; then
    echo "✅ Graphviz 已安裝"
else
    echo "📥 安裝 Graphviz..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install graphviz
        else
            echo "❌ 請先安裝 Homebrew 或手動安裝 Graphviz"
            echo "安裝 Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo apt-get update && sudo apt-get install -y graphviz
    else
        echo "❌ 不支援的作業系統，請手動安裝 Graphviz"
        exit 1
    fi
fi

# 建立虛擬環境 (可選)
echo "🏗️  設定 Python 環境..."
if [ ! -d "venv" ]; then
    echo "建立虛擬環境..."
    python3 -m venv venv
fi

# 啟動虛擬環境
source venv/bin/activate 2>/dev/null || echo "⚠️  虛擬環境啟動失敗，使用系統 Python"

# 安裝 Python 套件
echo "📦 安裝 Python 相依套件..."
pip3 install --upgrade pip

# 核心分析套件
pip3 install networkx matplotlib pandas seaborn

# Graphviz Python 包裝器
pip3 install graphviz

# 可選的進階套件
echo "📦 安裝進階分析套件..."
pip3 install plotly dash networkx[default] pygraphviz 2>/dev/null || echo "⚠️  部分進階套件安裝失敗"

# 建立輸出目錄
echo "📁 建立輸出目錄..."
mkdir -p dependency_reports
mkdir -p dependency_analysis

# 設定權限
chmod +x dependency_analysis/*.py

echo ""
echo "✅ 安裝完成！"
echo ""
echo "🎯 使用方法:"
echo "1. 基礎依賴分析:"
echo "   python3 dependency_analysis/swift_dependency_analyzer.py --project-path ."
echo ""
echo "2. Graphviz 圖表生成:"
echo "   python3 dependency_analysis/graphviz_generator.py --project-path ."
echo ""
echo "3. 查看生成的報告:"
echo "   open dependency_reports/"
echo ""
echo "📚 生成的檔案包括:"
echo "   - dependency_analysis.json     (JSON 數據)"
echo "   - dependency_report.md         (Markdown 報告)"
echo "   - *.png                        (視覺化圖表)"
echo "   - *.dot                        (Graphviz 原始檔)"
echo ""
echo "🔧 自訂選項:"
echo "   --format png|svg|pdf           (圖片格式)"
echo "   --engine dot|neato|fdp         (佈局引擎)"
echo "   --output-dir custom_dir        (輸出目錄)"
