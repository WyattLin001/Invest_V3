//
//  Untitled.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand Colors (根據 target.txt Design Tokens)
    
    /// 主要品牌色 #1DB954 - 用於主要 CTA 和品牌識別
    static let brandPrimary = Color(hex: "#1DB954")
    
    /// 次要品牌色 #0066CC - 用於次要 CTA 和強調
    static let brandSecondary = Color(hex: "#0066CC")
    
    /// 主要品牌綠色 #00B900 - 用於主要 CTA / Toggle ON
    static let brandGreen = Color(hex: "#00B900")
    
    /// 品牌橙色 #FD7E14 - 用於付費/警示 CTA  
    static let brandOrange = Color(hex: "#FD7E14")
    
    /// 品牌藍色 #007BFF - 用於投資指令高亮
    static let brandBlue = Color(hex: "#007BFF")
    
    // MARK: - Semantic Colors (支援深色模式)
    
    /// 背景 Layer 0 - 最淺灰色 (主要背景)
    static let gray50 = Color(light: "#FAFAFA", dark: "#000000")
    
    /// 背景 Layer 1 - 卡片背景
    static let gray100 = Color(light: "#F7F7F7", dark: "#1C1C1E")
    
    /// 背景 Layer 2 - 次要背景
    static let gray200 = Color(light: "#EEEEEE", dark: "#2C2C2E")
    
    /// 背景 Layer 3 - 三級背景
    static let gray250 = Color(light: "#E5E5E7", dark: "#3A3A3C")
    
    /// 分隔線/邊框
    static let gray300 = Color(light: "#D1D1D6", dark: "#48484A")
    
    /// 背景 Layer 4 - 四級背景 (重複定義，保持一致)
    static let gray400 = Color(light: "#C7C7CC", dark: "#58585A")
    
    /// 背景 Layer 5 - 五級背景 (重複定義，保持一致)
    static let gray500 = Color(light: "#AEAEB2", dark: "#68686A")
    
    /// 背景 Layer 6 - 六級背景
    static let gray700 = Color(light: "#6D6D70", dark: "#AEAEB2")
    
    /// 背景 Layer 7 - 七級背景
    static let gray800 = Color(light: "#48484A", dark: "#C7C7CC")
    
    /// 次要文本
    static let gray600 = Color(light: "#8E8E93", dark: "#8E8E93")
    
    /// 分隔線顏色 - 支援深色模式
    static var divider: Color {
        Color(light: "#E1E5E9", dark: "#3A3A3C")
    }
    
    /// 主要文本
    static let gray900 = Color(light: "#1D1D1F", dark: "#F2F2F7")
    
    // MARK: - Text Colors (語義化文字顏色)
    
    /// 主要文字顏色 - 支援深色模式
    static let textPrimary = Color(light: "#000000", dark: "#FFFFFF")
    
    /// 次要文字顏色 - 支援深色模式
    static let textSecondary = Color(light: "#666666", dark: "#999999")
    
    /// 第三級文字顏色 - 支援深色模式
    static let textTertiary = Color(light: "#999999", dark: "#666666")
    
    // MARK: - Additional Brand Colors
    
    /// 品牌紫色 - 用於史詩級成就
    static let brandPurple = Color(hex: "#9C27B0")
    
    /// 品牌金色 - 用於傳奇級成就
    static let brandGold = Color(hex: "#FFD700")
    
    // MARK: - Status Colors
    
    /// 成功/上漲 - 綠色
    static let success = Color(hex: "#28A745")
    
    /// 危險/下跌 - 紅色  
    static let danger = Color(hex: "#DC3545")
    
    /// 警告 - 黃色
    static let warning = Color(hex: "#FFC107")
    
    /// 資訊 - 藍色
    static let info = Color(hex: "#17A2B8")
    
    // MARK: - Additional Colors
    
    /// 投資深灰色
    static let investDarkGray = Color(hex: "#2C2C2C")
    
    /// 投資綠色
    static let investGreen = Color(hex: "#00B900")
    
    /// 投資背景色
    static let investBackground = Color(hex: "#F5F5F5")
    
    // MARK: - Surface Colors (表面顏色，深色模式適配)
    
    /// 主要表面顏色 (卡片、彈窗背景)
    static var surfacePrimary: Color {
        Color(light: "#FFFFFF", dark: "#1C1C1E")
    }
    
    /// 次要表面顏色 (次要卡片背景)
    static var surfaceSecondary: Color {
        Color(light: "#F2F2F7", dark: "#2C2C2E")
    }
    
    /// 三級表面顏色 (輸入框背景)
    static var surfaceTertiary: Color {
        Color(light: "#FFFFFF", dark: "#3A3A3C")
    }
    
    /// 群組背景顏色 (列表背景)
    static var surfaceGrouped: Color {
        Color(light: "#F2F2F7", dark: "#000000")
    }
    
    /// 覆蓋層顏色 (遮罩背景)
    static var surfaceOverlay: Color {
        Color(light: "#000000", dark: "#000000").opacity(0.4)
    }
    
    // MARK: - System Colors (系統顏色適配)
    
    /// 系統背景顏色
    static var systemBackground: Color {
        Color(.systemBackground)
    }
    
    /// 系統次要背景顏色
    static var systemSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    /// 系統三級背景顏色
    static var systemTertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }
    
    /// 系統群組背景顏色
    static var systemGroupedBackground: Color {
        Color(.systemGroupedBackground)
    }
    
    /// 系統標籤顏色
    static var systemLabel: Color {
        Color(.label)
    }
    
    /// 系統次要標籤顏色
    static var systemSecondaryLabel: Color {
        Color(.secondaryLabel)
    }
    
    /// 系統三級標籤顏色
    static var systemTertiaryLabel: Color {
        Color(.tertiaryLabel)
    }
    
    /// 系統分隔線顏色
    static var systemSeparator: Color {
        Color(.separator)
    }
    
    // MARK: - Helper Initializers
    
    /// 從 hex 字串創建顏色 (自定義實現，避免與系統 API 衝突)
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 便利初始化器，保持向後兼容
    init(hex: String) {
        self.init(hexString: hex)
    }
    
    /// 支援深色模式的顏色初始化器
    init(light: String, dark: String) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(Color(hexString: dark))
            default:
                return UIColor(Color(hexString: light))
            }
        })
    }
}

// MARK: - Design System Constants
// Note: DesignTokens is defined in DesignTokens.swift

// MARK: - View Modifiers

extension View {
    /// 應用品牌卡片樣式 (深色模式適配)
    func brandCardStyle() -> some View {
        let shadow = DesignTokens.cardShadow
        return self
            .background(Color.surfacePrimary)
            .cornerRadius(DesignTokens.cornerRadius)
            .shadow(
                color: DesignTokens.shadowColor.opacity(shadow.opacity),
                radius: shadow.radius,
                x: shadow.offset.width,
                y: shadow.offset.height
            )
    }
    
    /// 應用品牌按鈕樣式 (深色模式適配)
    func brandButtonStyle(
        backgroundColor: Color = .brandGreen,
        foregroundColor: Color = .white,
        isDisabled: Bool = false
    ) -> some View {
        self
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(DesignTokens.cornerRadius)
            .opacity(isDisabled ? 0.3 : 1.0)
            .disabled(isDisabled)
    }
    
    /// 投資面板樣式 (深色模式適配)
    func investmentPanelStyle() -> some View {
        self
            .background(DesignTokens.portfolioBackgroundColor)
            .cornerRadius(DesignTokens.cornerRadiusLG)
            .shadow(
                color: DesignTokens.shadowColor.opacity(DesignTokens.shadowOpacityAdaptive),
                radius: DesignTokens.shadowRadius,
                x: DesignTokens.shadowOffset.width,
                y: DesignTokens.shadowOffset.height
            )
    }
    
    /// 圖表容器樣式 (深色模式適配)
    func chartContainerStyle() -> some View {
        self
            .background(DesignTokens.chartBackgroundColor)
            .cornerRadius(DesignTokens.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(DesignTokens.borderColor, lineWidth: DesignTokens.borderWidthThin)
            )
    }
    
    /// 分隔線樣式
    func dividerStyle() -> some View {
        self
            .frame(height: DesignTokens.borderWidthThin)
            .background(DesignTokens.dividerColor)
    }
    
    /// 浮動按鈕樣式 (深色模式適配)
    func floatingButtonStyle() -> some View {
        let fabShadow = DesignTokens.fabShadow
        return self
            .background(Color.brandGreen)
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(
                color: DesignTokens.shadowColor.opacity(fabShadow.opacity),
                radius: fabShadow.radius,
                x: fabShadow.offset.width,
                y: fabShadow.offset.height
            )
    }
    
    /// 主題敏感的文字顏色
    func adaptiveTextColor(primary: Bool = true) -> some View {
        self.foregroundColor(primary ? .systemLabel : .systemSecondaryLabel)
    }
    
    /// 主題敏感的背景顏色
    func adaptiveBackground() -> some View {
        self.background(Color.systemBackground)
    }
    
    /// 自定義圓角 - 支援指定特定角落
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Custom Shapes

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
