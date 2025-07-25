#!/bin/bash

# 部署腳本 - 升級台股 API 到 Fly.io
# 使用方法: ./deploy.sh

echo "🚀 開始部署台股 API 升級版本到 Fly.io..."

# 檢查是否有 Fly CLI
if ! command -v flyctl &> /dev/null; then
    echo "❌ Fly CLI 未安裝"
    echo "請先安裝 Fly CLI: https://fly.io/docs/getting-started/installing-flyctl/"
    exit 1
fi

# 檢查是否在正確的目錄
if [ ! -f "fly.toml" ]; then
    echo "❌ 找不到 fly.toml 配置文件"
    echo "請確保在 flask_api 目錄中執行此腳本"
    exit 1
fi

echo "📋 部署前檢查..."

# 檢查重要文件
echo "  ✓ 檢查 app.py..."
if [ ! -f "app.py" ]; then
    echo "❌ 找不到 app.py"
    exit 1
fi

echo "  ✓ 檢查 taiwan_stocks_fallback.json..."
if [ ! -f "taiwan_stocks_fallback.json" ]; then
    echo "❌ 找不到 taiwan_stocks_fallback.json"
    exit 1
fi

echo "  ✓ 檢查 requirements.txt..."
if [ ! -f "requirements.txt" ]; then
    echo "❌ 找不到 requirements.txt"
    exit 1
fi

echo "🔄 開始部署..."

# 部署到 Fly.io
flyctl deploy

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 部署成功！"
    echo ""
    echo "📊 測試新功能："
    echo "1. 健康檢查："
    echo "   curl https://invest-v3-api.fly.dev/api/health"
    echo ""
    echo "2. 測試台股清單（應該有 1900+ 支股票）："
    echo "   curl 'https://invest-v3-api.fly.dev/api/taiwan-stocks/all?page=1&per_page=5'"
    echo ""
    echo "3. 搜尋台積電："
    echo "   curl 'https://invest-v3-api.fly.dev/api/taiwan-stocks/search?q=台積電'"
    echo ""
    echo "🎉 台股 API 升級完成！從 20 支股票擴展到 1900+ 支股票"
else
    echo "❌ 部署失敗"
    echo "請檢查錯誤訊息並重試"
    exit 1
fi