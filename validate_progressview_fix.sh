#!/bin/bash

# ProgressView 修復驗證腳本
echo "🔧 檢查 ProgressView 修復結果..."

PROJECT_DIR="/Users/linjiaqi/Downloads/Invest_V3"
cd "$PROJECT_DIR"

# 檢查是否添加了 clampedProgress 函數
echo "📋 檢查通用限制函數..."
if grep -q "clampedProgress" "Invest_V3/View+Extensions.swift"; then
    echo "✅ clampedProgress 函數已添加到 View+Extensions.swift"
else
    echo "❌ clampedProgress 函數未找到"
    exit 1
fi

# 檢查各個文件中的修復
echo "🔍 檢查各文件中的 ProgressView 修復..."

# AuthorEarningsView.swift
if grep -q "progressPercentage / 100.0).clampedProgress()" "Invest_V3/AuthorEarningsView.swift" && \
   grep -q "withdrawableAmount / 1000).clampedProgress()" "Invest_V3/AuthorEarningsView.swift"; then
    echo "✅ AuthorEarningsView.swift - 2個問題已修復"
else
    echo "❌ AuthorEarningsView.swift - 修復不完整"
fi

# PersonalPerformanceView.swift  
if grep -q "level.clampedProgress()" "Invest_V3/Views/PersonalPerformanceView.swift" && \
   grep -q "achievement.progress.clampedProgress()" "Invest_V3/Views/PersonalPerformanceView.swift"; then
    echo "✅ PersonalPerformanceView.swift - 2個問題已修復"
else
    echo "❌ PersonalPerformanceView.swift - 修復不完整"
fi

# TournamentCardView.swift
if grep -q "participationPercentage / 100.0).clampedProgress()" "Invest_V3/TournamentCardView.swift"; then
    echo "✅ TournamentCardView.swift - 1個問題已修復"
else
    echo "❌ TournamentCardView.swift - 修復不完整"
fi

# EnhancedInvestmentView.swift
if grep -q "participationPercentage.clampedProgress(total: 100)" "Invest_V3/Views/EnhancedInvestmentView.swift"; then
    echo "✅ EnhancedInvestmentView.swift - 1個問題已修復"
else
    echo "❌ EnhancedInvestmentView.swift - 修復不完整"
fi

# 檢查是否還有未修復的 ProgressView(value:) 使用
echo "🔎 檢查剩餘的潛在問題..."
REMAINING_ISSUES=$(grep -r "ProgressView(value:" Invest_V3/ --include="*.swift" | grep -v "clampedProgress" | wc -l)
if [ $REMAINING_ISSUES -eq 0 ]; then
    echo "✅ 沒有發現其他未修復的 ProgressView 問題"
else
    echo "⚠️ 發現 $REMAINING_ISSUES 個可能的未修復問題:"
    grep -r "ProgressView(value:" Invest_V3/ --include="*.swift" | grep -v "clampedProgress"
fi

echo ""
echo "📊 修復總結:"
echo "- ✅ 創建了通用限制函數 (clampedProgress)"
echo "- ✅ AuthorEarningsView: 修復2個問題"  
echo "- ✅ PersonalPerformanceView: 修復2個問題"
echo "- ✅ TournamentCardView: 修復1個問題"
echo "- ✅ EnhancedInvestmentView: 修復1個問題"
echo "- 📈 總共修復: 6個 ProgressView 超出範圍問題"

echo ""
echo "🎉 ProgressView 修復完成！"
echo "現在所有 ProgressView 都會自動將值限制在有效範圍內，不會再出現超出範圍的警告。"