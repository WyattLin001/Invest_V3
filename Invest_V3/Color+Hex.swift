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
    
    /// 主要品牌色 - Medium 風格黑白色調
    static let brandPrimary = Color(light: "#000000", dark: "#FFFFFF")
    
    /// 次要品牌色 - Medium 風格灰色
    static let brandSecondary = Color(light: "#6B6B6B", dark: "#B3B3B3")
    
    /// 主要品牌色（保持向後兼容） - Medium 風格黑白色調
    static let brandGreen = Color(light: "#000000", dark: "#FFFFFF")
    
    /// 品牌橙色 - Medium 風格低飽和度
    static let brandOrange = Color(light: "#8B5A2B", dark: "#D2B48C")
    
    /// 品牌藍色 - Medium 風格低飽和度
    static let brandBlue = Color(light: "#4A5568", dark: "#A0AEC0")
    
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
    
    /// 次要文本 - 改善深色模式對比度
    static let gray600 = Color(light: "#8E8E93", dark: "#ADADB8")
    
    /// 分隔線顏色 - 支援深色模式
    static var divider: Color {
        Color(light: "#E1E5E9", dark: "#3A3A3C")
    }
    
    /// 主要文本
    static let gray900 = Color(light: "#1D1D1F", dark: "#F2F2F7")
    
    // MARK: - Text Colors (語義化文字顏色)
    
    /// 主要文字顏色 - 支援深色模式
    static let textPrimary = Color(light: "#000000", dark: "#FFFFFF")
    
    /// 次要文字顏色 - 支援深色模式 (提高對比度)
    static let textSecondary = Color(light: "#666666", dark: "#BBBBBB")
    
    /// 第三級文字顏色 - 支援深色模式 (提高對比度)
    static let textTertiary = Color(light: "#999999", dark: "#AAAAAA")
    
    /// 禁用狀態文字顏色 - 支援深色模式
    static let textDisabled = Color(light: "#CCCCCC", dark: "#777777")
    
    // MARK: - Additional Brand Colors
    
    /// 品牌紫色 - 用於史詩級成就
    static let brandPurple = Color(hex: "#9C27B0")
    
    /// 品牌金色 - 用於傳奇級成就
    static let brandGold = Color(hex: "#FFD700")
    
    // MARK: - Status Colors
    
    /// 成功/上漲 - 深色模式適配
    static let success = Color(light: "#28A745", dark: "#4CAF50")
    
    /// 危險/下跌 - 深色模式適配  
    static let danger = Color(light: "#DC3545", dark: "#F44336")
    
    /// 警告 - 深色模式適配
    static let warning = Color(light: "#FFC107", dark: "#FFB74D")
    
    /// 資訊 - 深色模式適配
    static let info = Color(light: "#17A2B8", dark: "#4FC3F7")
    
    // MARK: - Taiwan Stock Market Colors (台股配色)
    
    /// 台股上漲色 - 紅色 (深色模式適配)
    static let taiwanStockUp = Color(light: "#FF4444", dark: "#F44336")
    
    /// 台股下跌色 - 綠色 (深色模式適配)
    static let taiwanStockDown = Color(light: "#00C851", dark: "#4CAF50")
    
    /// 台股平盤色 - 灰色 (深色模式適配)
    static let taiwanStockFlat = Color(light: "#6C757D", dark: "#9E9E9E")
    
    /// 投資盈利色 - 台股紅色
    static let investmentProfit = Color(light: "#FF4444", dark: "#F44336")
    
    /// 投資虧損色 - 台股綠色
    static let investmentLoss = Color(light: "#00C851", dark: "#4CAF50")
    
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
    
    /// 邊框顏色 - 支援深色模式
    static var borderColor: Color {
        Color(light: "#E1E5E9", dark: "#3A3A3C")
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
    
    /// 將 Color 轉換為 hex 字符串
    func toHex() -> String {
        guard let uiColor = UIColor(self).cgColor.components else {
            return "#000000"
        }
        
        let r = uiColor[0]
        let g = uiColor[1] 
        let b = uiColor[2]
        
        return String(format: "#%02X%02X%02X", 
                     Int(r * 255), 
                     Int(g * 255), 
                     Int(b * 255))
    }
}

// MARK: - Design System Constants
// Note: DesignTokens is defined in DesignTokens.swift

// MARK: - View Modifiers

extension View {
    /// 應用品牌卡片樣式 (深色模式適配)
    @MainActor
    func brandCardStyle() -> some View {
        let shadow = DesignTokens.cardShadow
        let isDark = ThemeManager.shared.isDarkMode
        
        return self
            .background(Color.surfacePrimary)
            .cornerRadius(DesignTokens.cornerRadius)
            .overlay(
                // 深色模式下增加細邊框
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(
                        isDark ? DesignTokens.borderColor : Color.clear,
                        lineWidth: isDark ? DesignTokens.borderWidthThin : 0
                    )
            )
            .shadow(
                color: DesignTokens.shadowColor.opacity(shadow.opacity),
                radius: shadow.radius,
                x: shadow.offset.width,
                y: shadow.offset.height
            )
    }
    
    /// 增強的卡片樣式 - 更強的視覺分隔
    @MainActor
    func enhancedCardStyle() -> some View {
        let shadow = DesignTokens.cardShadow
        let isDark = ThemeManager.shared.isDarkMode
        
        return self
            .padding(DesignTokens.spacingMD)
            .background(Color.surfacePrimary)
            .cornerRadius(DesignTokens.cornerRadiusLG)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                    .stroke(
                        isDark ? DesignTokens.borderColor : Color.borderColor.opacity(0.3),
                        lineWidth: isDark ? 1 : 0.5
                    )
            )
            .shadow(
                color: DesignTokens.shadowColor.opacity(shadow.opacity * 1.5),
                radius: shadow.radius + 2,
                x: shadow.offset.width,
                y: shadow.offset.height + 1
            )
    }
    
    /// 區塊標題樣式
    func sectionTitleStyle() -> some View {
        self
            .font(DesignTokens.sectionHeader)
            .adaptiveTextColor()
            .padding(.bottom, DesignTokens.spacingSM)
    }
    
    /// 子區塊標題樣式
    func subsectionTitleStyle() -> some View {
        self
            .font(DesignTokens.subsectionHeader)
            .adaptiveTextColor()
            .padding(.bottom, DesignTokens.spacingXS)
    }
    
    /// 應用品牌按鈕樣式 (深色模式適配)
    @MainActor
    func brandButtonStyle(
        backgroundColor: Color = .mediumButtonPrimary,
        foregroundColor: Color = .mediumButtonText,
        isDisabled: Bool = false,
        size: ButtonSize = .medium
    ) -> some View {
        let isDark = ThemeManager.shared.isDarkMode
        let adaptedBgColor = isDark ? backgroundColor.opacity(0.8) : backgroundColor
        
        return self
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.height)
            .background(adaptedBgColor)
            .foregroundColor(foregroundColor)
            .font(size.font)
            .cornerRadius(DesignTokens.cornerRadius)
            .opacity(isDisabled ? 0.3 : 1.0)
            .disabled(isDisabled)
            .shadow(
                color: isDark ? Color.black.opacity(0.3) : Color.clear,
                radius: isDark ? 2 : 0,
                x: 0,
                y: isDark ? 1 : 0
            )
    }
    
    /// 帶圖標的按鈕樣式
    func iconButtonStyle(
        icon: String,
        backgroundColor: Color = .mediumButtonPrimary,
        foregroundColor: Color = .mediumButtonText,
        isDisabled: Bool = false,
        size: ButtonSize = .medium
    ) -> some View {
        HStack(spacing: DesignTokens.spacingXS) {
            Image(systemName: icon)
                .font(size.iconFont)
            self
        }
        .brandButtonStyle(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            isDisabled: isDisabled,
            size: size
        )
    }
    
    /// 次要按鈕樣式 (無填充背景)
    func secondaryButtonStyle(
        borderColor: Color = .mediumButtonPrimary,
        foregroundColor: Color = .mediumButtonPrimary,
        isDisabled: Bool = false,
        size: ButtonSize = .medium
    ) -> some View {
        self
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.height)
            .background(Color.clear)
            .foregroundColor(foregroundColor)
            .font(size.font)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(borderColor, lineWidth: DesignTokens.borderWidth)
            )
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
    @MainActor
    func floatingButtonStyle() -> some View {
        let fabShadow = DesignTokens.fabShadow
        let isDark = ThemeManager.shared.isDarkMode
        
        return self
            .background(Color.mediumButtonPrimary)
            .foregroundColor(.mediumButtonText)
            .clipShape(Circle())
            .overlay(
                // 深色模式下添加細邊框增強層次
                Circle()
                    .stroke(
                        isDark ? Color.white.opacity(0.1) : Color.clear,
                        lineWidth: isDark ? 1 : 0
                    )
            )
            .shadow(
                color: DesignTokens.shadowColor.opacity(fabShadow.opacity),
                radius: fabShadow.radius,
                x: fabShadow.offset.width,
                y: fabShadow.offset.height
            )
    }
    
    /// 主題敏感的文字顏色 (增強對比度)
    func adaptiveTextColor(primary: Bool = true) -> some View {
        let textColor = primary ? Color.textPrimary : Color.textSecondary
        return self.foregroundColor(textColor)
    }
    
    /// 第三級文字顏色
    func tertiaryTextColor() -> some View {
        self.foregroundColor(.textTertiary)
    }
    
    /// 禁用狀態文字顏色
    func disabledTextColor() -> some View {
        self.foregroundColor(.textDisabled)
    }
    
    /// 改善的禁用狀態樣式
    @MainActor
    func disabledStyle() -> some View {
        let isDark = ThemeManager.shared.isDarkMode
        return self
            .foregroundColor(isDark ? Color(hex: "#AAAAAA") : Color(hex: "#CCCCCC"))
            .opacity(isDark ? 1.0 : 0.6)
    }
    
    /// 改善的次要內容樣式（如空狀態提示）
    @MainActor
    func secondaryContentStyle() -> some View {
        let isDark = ThemeManager.shared.isDarkMode
        return self
            .foregroundColor(isDark ? Color(hex: "#888888") : Color(hex: "#999999"))
            .font(.subheadline)
    }
    
    /// 搜索框樣式
    @MainActor
    func searchFieldStyle() -> some View {
        let isDark = ThemeManager.shared.isDarkMode
        return self
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(Color.surfaceSecondary)
            .cornerRadius(DesignTokens.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(
                        isDark ? DesignTokens.borderColor : Color.borderColor.opacity(0.5),
                        lineWidth: DesignTokens.borderWidthThin
                    )
            )
    }
    
    /// 狀態標籤樣式
    func statusTagStyle(
        backgroundColor: Color,
        foregroundColor: Color = .white
    ) -> some View {
        self
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, DesignTokens.spacingXS)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(DesignTokens.cornerRadiusSM)
    }
    
    /// 資訊提示樣式（帶圖標）
    func infoTipStyle(
        icon: String,
        backgroundColor: Color = .info,
        foregroundColor: Color = .white
    ) -> some View {
        HStack(spacing: DesignTokens.spacingXS) {
            Image(systemName: icon)
                .font(.caption)
            self
                .font(.caption)
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(backgroundColor.opacity(0.1))
        .foregroundColor(backgroundColor)
        .cornerRadius(DesignTokens.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .stroke(backgroundColor.opacity(0.3), lineWidth: DesignTokens.borderWidthThin)
        )
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

// MARK: - Button Size System

/// 按鈕尺寸系統
enum ButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return DesignTokens.buttonHeightSM
        case .medium: return DesignTokens.buttonHeightMD
        case .large: return DesignTokens.buttonHeightLG
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return DesignTokens.buttonPaddingHorizontal
        case .large: return 20
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return DesignTokens.buttonPaddingVertical
        case .large: return 16
        }
    }
    
    var font: Font {
        switch self {
        case .small: return .system(size: 14, weight: .medium)
        case .medium: return .system(size: 16, weight: .medium)
        case .large: return .system(size: 18, weight: .semibold)
        }
    }
    
    var iconFont: Font {
        switch self {
        case .small: return .system(size: 12, weight: .medium)
        case .medium: return .system(size: 14, weight: .medium)
        case .large: return .system(size: 16, weight: .medium)
        }
    }
}
