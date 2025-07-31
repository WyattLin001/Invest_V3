//
//  DarkModeOptimizedComponents.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  深色模式優化組件示範 - 展示如何正確使用改善的深色模式樣式
//

import SwiftUI

/// 深色模式優化的示範組件
struct DarkModeOptimizedComponents: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isEnabled = true
    @State private var showModal = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignTokens.spacingLG) {
                    // 示範卡片組件
                    demoCardsSection
                    
                    // 示範按鈕組件
                    demoButtonsSection
                    
                    // 示範文字樣式
                    demoTextStylesSection
                    
                    // 示範狀態指示器
                    demoStatusIndicatorsSection
                    
                    // 示範表單元件
                    demoFormElementsSection
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingLG)
            }
            .adaptiveBackground()
            .navigationTitle("深色模式優化")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showModal) {
            demoModalContent
        }
    }
    
    // MARK: - 卡片組件示範
    private var demoCardsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("卡片組件")
                .font(.headline)
                .adaptiveTextColor()
            
            // 標準卡片
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("投資組合")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                HStack {
                    Text("總資產")
                        .adaptiveTextColor(primary: false)
                    
                    Spacer()
                    
                    Text("$125,430")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.success)
                }
                
                Text("今日變化 +2.5%")
                    .font(.caption)
                    .foregroundColor(.success)
            }
            .brandCardStyle()
            
            // 空狀態卡片
            VStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "chart.bar")
                    .font(.largeTitle)
                    .foregroundColor(.textTertiary)
                
                Text("暫無數據")
                    .font(.subheadline)
                    .disabledStyle()
                
                Text("您還沒有任何投資記錄")
                    .font(.caption)
                    .secondaryContentStyle()
                    .multilineTextAlignment(.center)
            }
            .padding(DesignTokens.spacingLG)
            .brandCardStyle()
        }
    }
    
    // MARK: - 按鈕組件示範
    private var demoButtonsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("按鈕組件")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(spacing: DesignTokens.spacingSM) {
                // 主要按鈕
                Button("主要操作") {
                    // Action
                }
                .brandButtonStyle()
                
                // 次要按鈕
                Button("次要操作") {
                    // Action
                }
                .brandButtonStyle(backgroundColor: .brandBlue)
                
                // 警告按鈕
                Button("警告操作") {
                    // Action
                }
                .brandButtonStyle(backgroundColor: .warning)
                
                // 禁用按鈕
                Button("禁用狀態") {
                    // Action
                }
                .brandButtonStyle(isDisabled: true)
            }
        }
    }
    
    // MARK: - 文字樣式示範
    private var demoTextStylesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("文字樣式")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("主要文字內容")
                    .font(.body)
                    .adaptiveTextColor()
                
                Text("次要文字內容")
                    .font(.body)
                    .adaptiveTextColor(primary: false)
                
                Text("第三級文字內容")
                    .font(.body)
                    .tertiaryTextColor()
                
                Text("禁用狀態文字")
                    .font(.body)
                    .disabledStyle()
                
                Text("好友功能暫時不可用")
                    .font(.caption)
                    .secondaryContentStyle()
            }
            .brandCardStyle()
        }
    }
    
    // MARK: - 狀態指示器示範
    private var demoStatusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("狀態指示器")
                .font(.headline)
                .adaptiveTextColor()
            
            HStack(spacing: DesignTokens.spacingMD) {
                // 成功狀態
                statusIndicator("成功", color: .success, icon: "checkmark.circle.fill")
                
                // 警告狀態
                statusIndicator("警告", color: .warning, icon: "exclamationmark.triangle.fill")
                
                // 錯誤狀態
                statusIndicator("錯誤", color: .danger, icon: "xmark.circle.fill")
                
                // 資訊狀態
                statusIndicator("資訊", color: .info, icon: "info.circle.fill")
            }
        }
    }
    
    // MARK: - 表單元件示範
    private var demoFormElementsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("表單元件")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(spacing: DesignTokens.spacingMD) {
                // 輸入框
                TextField("請輸入內容", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                
                // 切換開關
                HStack {
                    Text("推播通知")
                        .adaptiveTextColor()
                    
                    Spacer()
                    
                    Toggle("", isOn: $isEnabled)
                        .tint(.brandGreen)
                }
                
                // 分隔線
                Divider()
                    .background(DesignTokens.dividerColor)
            }
            .brandCardStyle()
        }
    }
    
    // MARK: - 浮動按鈕
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showModal = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .frame(width: 56, height: 56)
                .floatingButtonStyle()
                .padding(.trailing, DesignTokens.spacingLG)
                .padding(.bottom, DesignTokens.spacingLG)
            }
        }
    }
    
    // MARK: - 模態視窗內容
    private var demoModalContent: some View {
        NavigationView {
            VStack(spacing: DesignTokens.spacingLG) {
                Text("這是一個模態視窗")
                    .font(.title2)
                    .adaptiveTextColor()
                
                Text("展示深色模式下的彈窗樣式")
                    .adaptiveTextColor(primary: false)
                    .multilineTextAlignment(.center)
                
                Button("關閉") {
                    showModal = false
                }
                .brandButtonStyle()
            }
            .padding(DesignTokens.spacingLG)
            .adaptiveBackground()
            .navigationTitle("模態視窗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showModal = false
                    }
                    .foregroundColor(.brandGreen)
                }
            }
        }
    }
    
    // MARK: - 輔助方法
    private func statusIndicator(_ title: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .adaptiveTextColor(primary: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(Color.surfaceSecondary)
        .cornerRadius(DesignTokens.cornerRadius)
    }
}

// MARK: - 預覽
#Preview("淺色模式") {
    DarkModeOptimizedComponents()
        .environmentObject(ThemeManager.shared)
}

#Preview("深色模式") {
    DarkModeOptimizedComponents()
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
}