//
//  MediumTheme.swift
//  Invest_V3
//
//  Created by Claude Code on 2025/8/17.
//  Medium 風格的高級黑白色調主題系統
//

import SwiftUI
import UIKit

// MARK: - Medium Theme Color System

extension Color {
    
    // MARK: - Medium Brand Colors (黑白高級感)
    
    /// Medium 主要黑色 - 替代原本的綠色
    static let mediumBlack = Color(light: "#242424", dark: "#FFFFFF")
    
    /// Medium 次要灰色 - 用於次要元素
    static let mediumGray = Color(light: "#6B6B6B", dark: "#B3B3B3")
    
    /// Medium 背景色 - 純淨白色/深黑色
    static let mediumBackground = Color(light: "#FFFFFF", dark: "#000000")
    
    /// Medium 卡片背景 - 淺灰/深灰
    static let mediumCardBackground = Color(light: "#FAFAFA", dark: "#1A1A1A")
    
    /// Medium 分隔線 - 極淺灰
    static let mediumDivider = Color(light: "#F0F0F0", dark: "#2A2A2A")
    
    // MARK: - Medium Text Colors (高對比度)
    
    /// Medium 主要文字 - 深黑/純白
    static let mediumTextPrimary = Color(light: "#1A1A1A", dark: "#FFFFFF")
    
    /// Medium 次要文字 - 中灰
    static let mediumTextSecondary = Color(light: "#6B6B6B", dark: "#B3B3B3")
    
    /// Medium 第三級文字 - 淺灰
    static let mediumTextTertiary = Color(light: "#9B9B9B", dark: "#8A8A8A")
    
    /// Medium 禁用文字 - 極淺灰
    static let mediumTextDisabled = Color(light: "#CCCCCC", dark: "#555555")
    
    // MARK: - Medium Interactive Colors
    
    /// Medium 主要按鈕 - 黑色/白色
    static let mediumButtonPrimary = Color(light: "#000000", dark: "#FFFFFF")
    
    /// Medium 次要按鈕 - 透明背景+黑色邊框
    static let mediumButtonSecondary = Color.clear
    
    /// Medium 按鈕文字 - 白色/黑色
    static let mediumButtonText = Color(light: "#FFFFFF", dark: "#000000")
    
    /// Medium 懸停狀態 - 淺灰
    static let mediumHover = Color(light: "#F5F5F5", dark: "#2A2A2A")
    
    // MARK: - Medium Status Colors (保持語義化，但降低飽和度)
    
    /// Medium 成功色 - 深綠色
    static let mediumSuccess = Color(light: "#2E7D32", dark: "#4CAF50")
    
    /// Medium 錯誤色 - 深紅色
    static let mediumError = Color(light: "#C62828", dark: "#E57373")
    
    /// Medium 警告色 - 深橙色
    static let mediumWarning = Color(light: "#F57C00", dark: "#FFB74D")
    
    /// Medium 資訊色 - 深藍色
    static let mediumInfo = Color(light: "#1565C0", dark: "#64B5F6")
    
    // MARK: - Medium Surface Colors
    
    /// Medium 主要表面 - 純白/純黑
    static let mediumSurfacePrimary = Color(light: "#FFFFFF", dark: "#000000")
    
    /// Medium 次要表面 - 極淺灰/深灰
    static let mediumSurfaceSecondary = Color(light: "#FAFAFA", dark: "#1A1A1A")
    
    /// Medium 三級表面 - 淺灰/中灰
    static let mediumSurfaceTertiary = Color(light: "#F5F5F5", dark: "#2A2A2A")
    
    /// Medium 邊框色 - 極淺灰線條
    static let mediumBorder = Color(light: "#E8E8E8", dark: "#333333")
    
    // MARK: - Medium Accent Colors (極簡化)
    
    /// Medium 強調色 - 僅在必要時使用的深灰
    static let mediumAccent = Color(light: "#424242", dark: "#E0E0E0")
    
    /// Medium 特殊標記 - 用於重要內容標記
    static let mediumHighlight = Color(light: "#F0F0F0", dark: "#2D2D2D")
}

// MARK: - Medium Theme View Modifiers

extension View {
    
    /// Medium 風格主要按鈕
    func mediumButtonStyle(
        size: ButtonSize = .medium,
        isSecondary: Bool = false
    ) -> some View {
        self
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.height)
            .background(isSecondary ? Color.clear : Color.mediumButtonPrimary)
            .foregroundColor(isSecondary ? Color.mediumButtonPrimary : Color.mediumButtonText)
            .font(size.font)
            .cornerRadius(6) // Medium 風格的較小圓角
            .overlay(
                // 次要按鈕的邊框
                isSecondary ? 
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.mediumButtonPrimary, lineWidth: 1) : nil
            )
    }
    
    /// Medium 風格卡片
    func mediumCardStyle() -> some View {
        self
            .background(Color.mediumCardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.mediumBorder, lineWidth: 0.5)
            )
    }
    
    /// Medium 風格文字
    func mediumTextStyle(
        level: TextLevel = .primary,
        weight: Font.Weight = .regular
    ) -> some View {
        let color: Color
        switch level {
        case .primary:
            color = .mediumTextPrimary
        case .secondary:
            color = .mediumTextSecondary
        case .tertiary:
            color = .mediumTextTertiary
        case .disabled:
            color = .mediumTextDisabled
        }
        
        return self
            .foregroundColor(color)
            .fontWeight(weight)
    }
    
    /// Medium 風格標題
    func mediumTitleStyle(size: TitleSize = .large) -> some View {
        let fontSize: CGFloat
        let weight: Font.Weight
        
        switch size {
        case .small:
            fontSize = 18
            weight = .medium
        case .medium:
            fontSize = 24
            weight = .semibold
        case .large:
            fontSize = 32
            weight = .bold
        }
        
        return self
            .font(.system(size: fontSize, weight: weight))
            .foregroundColor(.mediumTextPrimary)
    }
    
    /// Medium 風格分隔線
    func mediumDividerStyle() -> some View {
        self
            .frame(height: 0.5)
            .background(Color.mediumDivider)
    }
    
    /// Medium 風格輸入框
    func mediumTextFieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.mediumSurfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.mediumBorder, lineWidth: 1)
            )
            .cornerRadius(6)
    }
    
    /// Medium 風格浮動按鈕
    func mediumFloatingButtonStyle() -> some View {
        self
            .frame(width: 56, height: 56)
            .background(Color.mediumButtonPrimary)
            .foregroundColor(Color.mediumButtonText)
            .clipShape(Circle())
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 8,
                x: 0,
                y: 4
            )
    }
    
    /// Medium 風格狀態標籤
    func mediumStatusTag(
        status: StatusType,
        size: TagSize = .medium
    ) -> some View {
        let color: Color
        switch status {
        case .success:
            color = .mediumSuccess
        case .error:
            color = .mediumError
        case .warning:
            color = .mediumWarning
        case .info:
            color = .mediumInfo
        case .neutral:
            color = .mediumGray
        }
        
        let fontSize: CGFloat = size == .small ? 12 : 14
        
        return self
            .font(.system(size: fontSize, weight: .medium))
            .padding(.horizontal, size == .small ? 8 : 12)
            .padding(.vertical, size == .small ? 4 : 6)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Supporting Enums

enum TextLevel {
    case primary, secondary, tertiary, disabled
}

enum TitleSize {
    case small, medium, large
}

enum StatusType {
    case success, error, warning, info, neutral
}

enum TagSize {
    case small, medium
}

// MARK: - Medium Theme Configuration

class MediumThemeConfig {
    static let shared = MediumThemeConfig()
    
    /// 是否啟用 Medium 主題
    @Published var isEnabled: Bool = false
    
    /// 設定全局的 Medium 主題
    func enableMediumTheme() {
        isEnabled = true
        // 這裡可以添加全局主題切換邏輯
        print("✅ Medium 主題已啟用")
    }
    
    /// 恢復原始主題
    func disableMediumTheme() {
        isEnabled = false
        print("🔄 恢復原始主題")
    }
    
    private init() {}
}

// MARK: - Medium Theme Typography

extension Font {
    
    /// Medium 風格標題字體
    static func mediumTitle(_ size: TitleSize = .large) -> Font {
        switch size {
        case .small:
            return .system(size: 18, weight: .medium)
        case .medium:
            return .system(size: 24, weight: .semibold)
        case .large:
            return .system(size: 32, weight: .bold)
        }
    }
    
    /// Medium 風格正文字體
    static let mediumBody = Font.system(size: 16, weight: .regular)
    
    /// Medium 風格次要文字字體
    static let mediumSecondary = Font.system(size: 14, weight: .regular)
    
    /// Medium 風格說明文字字體
    static let mediumCaption = Font.system(size: 12, weight: .regular)
    
    /// Medium 風格按鈕字體
    static let mediumButton = Font.system(size: 16, weight: .medium)
}

// MARK: - Medium Theme Preview Helper

#if DEBUG
struct MediumThemePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Medium 風格預覽")
                .mediumTitleStyle()
            
            Text("這是主要文字內容")
                .mediumTextStyle()
            
            Text("這是次要文字內容")
                .mediumTextStyle(level: .secondary)
            
            Button("主要按鈕") {}
                .mediumButtonStyle()
            
            Button("次要按鈕") {}
                .mediumButtonStyle(isSecondary: true)
            
            VStack {
                Text("卡片內容")
                    .mediumTextStyle()
            }
            .padding()
            .mediumCardStyle()
        }
        .padding()
        .background(Color.mediumBackground)
    }
}

#Preview {
    MediumThemePreview()
}
#endif