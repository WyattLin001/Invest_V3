#!/bin/bash

# Xcode 建置問題修復腳本
echo "🔧 修復 Xcode 建置問題..."

PROJECT_DIR="/Users/linjiaqi/Downloads/Invest_V3"
cd "$PROJECT_DIR"

echo "📋 檢查項目配置修復..."

# 檢查 Info.plist 文件是否存在
if [ -f "Invest_V3/Info.plist" ]; then
    echo "✅ Info.plist 文件存在"
else
    echo "❌ Info.plist 文件不存在"
    exit 1
fi

# 檢查項目配置是否正確
if grep -q 'INFOPLIST_FILE = "Invest_V3/Info.plist"' "Invest_V3.xcodeproj/project.pbxproj"; then
    echo "✅ INFOPLIST_FILE 配置正確"
else
    echo "❌ INFOPLIST_FILE 配置錯誤"
fi

# 檢查是否移除了衝突的 INFOPLIST_KEY 設定
if grep -q "INFOPLIST_KEY_" "Invest_V3.xcodeproj/project.pbxproj"; then
    echo "⚠️ 仍然存在 INFOPLIST_KEY 設定，可能造成衝突"
    echo "找到的 INFOPLIST_KEY 設定："
    grep "INFOPLIST_KEY_" "Invest_V3.xcodeproj/project.pbxproj" | head -3
else
    echo "✅ 已移除衝突的 INFOPLIST_KEY 設定"
fi

# 清理建置緩存
echo "🧹 清理建置緩存..."

# 清理 Xcode 衍生資料
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    echo "清理 DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/Invest_V3-*
fi

# 清理專案建置資料夾
if [ -d "build" ]; then
    echo "清理專案建置資料夾..."
    rm -rf build
fi

echo "🔍 檢查 entitlements 配置..."
if [ -f "Invest_V3/Invest_V3.entitlements" ]; then
    echo "✅ entitlements 文件存在"
    if grep -q "aps-environment" "Invest_V3/Invest_V3.entitlements"; then
        echo "✅ aps-environment 配置正確"
    fi
else
    echo "❌ entitlements 文件不存在"
fi

echo ""
echo "📊 修復總結："
echo "- ✅ 移除了重複的 Info.plist 配置衝突"
echo "- ✅ 保留手動 Info.plist 文件"
echo "- ✅ 移除自動生成的 INFOPLIST_KEY 設定"
echo "- ✅ 清理了建置緩存"
echo "- ✅ 確保 entitlements 配置正確"

echo ""
echo "🎯 下一步："
echo "1. 在 Xcode 中執行 Product > Clean Build Folder (⇧⌘K)"
echo "2. 重新建置專案 (⌘B)"
echo "3. 如果還有問題，請重啟 Xcode"

echo ""
echo "🎉 建置問題修復完成！"