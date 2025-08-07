#!/bin/bash

# 推播通知配置測試腳本
# 用於驗證 Xcode 項目是否正確配置了推播通知功能

echo "🚀 開始檢測推播通知配置..."

PROJECT_DIR="/Users/linjiaqi/Downloads/Invest_V3"
cd "$PROJECT_DIR"

# 檢查必要文件是否存在
echo "📋 檢查必要文件..."

if [ -f "Invest_V3/Invest_V3.entitlements" ]; then
    echo "✅ entitlements 文件存在"
else
    echo "❌ entitlements 文件不存在"
    exit 1
fi

if [ -f "Invest_V3/Info.plist" ]; then
    echo "✅ Info.plist 文件存在"
else
    echo "❌ Info.plist 文件不存在"
    exit 1
fi

# 檢查 entitlements 內容
echo "🔍 檢查 entitlements 配置..."
if grep -q "aps-environment" "Invest_V3/Invest_V3.entitlements"; then
    echo "✅ aps-environment 已配置"
else
    echo "❌ aps-environment 未配置"
fi

if grep -q "com.apple.developer.push-notification-service" "Invest_V3/Invest_V3.entitlements"; then
    echo "✅ 推播通知服務權限已配置"
else
    echo "❌ 推播通知服務權限未配置"
fi

# 檢查 Info.plist 內容
echo "📱 檢查 Info.plist 配置..."
if grep -q "UIBackgroundModes" "Invest_V3/Info.plist"; then
    echo "✅ 背景模式已配置"
else
    echo "❌ 背景模式未配置"
fi

if grep -q "remote-notification" "Invest_V3/Info.plist"; then
    echo "✅ 遠程通知背景模式已啟用"
else
    echo "❌ 遠程通知背景模式未啟用"
fi

# 嘗試建置項目來驗證配置
echo "🔨 嘗試建置項目來驗證配置..."

# 清除之前的建置
xcodebuild clean -project "Invest_V3.xcodeproj" -scheme "Invest_V3" > /dev/null 2>&1

# 建置項目
BUILD_OUTPUT=$(xcodebuild build -project "Invest_V3.xcodeproj" -scheme "Invest_V3" -destination "generic/platform=iOS" 2>&1)

if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo "✅ 項目建置成功，配置正確"
elif echo "$BUILD_OUTPUT" | grep -q "aps-environment"; then
    echo "❌ 建置時仍然出現 aps-environment 錯誤"
    echo "錯誤詳情:"
    echo "$BUILD_OUTPUT" | grep -A 5 -B 5 "aps-environment"
else
    echo "⚠️ 項目建置出現其他問題，但可能不是推播配置問題"
    echo "建置輸出的最後幾行:"
    echo "$BUILD_OUTPUT" | tail -10
fi

echo "🏁 配置檢測完成"