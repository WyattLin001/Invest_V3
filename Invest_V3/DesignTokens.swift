//
//  DesignTokens.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/19.
//

import SwiftUI

/// 設計系統的設計令牌
enum DesignTokens {
    // MARK: - Spacing (8pt grid system) - 增強間距系統
    static let spacingXXS: CGFloat = 2        // 極小間距
    static let spacingXS: CGFloat = 4         // 超小間距
    static let spacingSM: CGFloat = 8         // 小間距
    static let spacingMD: CGFloat = 16        // 中等間距
    static let spacingLG: CGFloat = 24        // 大間距
    static let spacingXL: CGFloat = 32        // 超大間距
    static let spacingXXL: CGFloat = 40       // 極大間距
    
    // 特殊用途間距
    static let sectionSpacing: CGFloat = 32   // 區塊間距
    static let cardSpacing: CGFloat = 16      // 卡片間距
    static let listItemSpacing: CGFloat = 12  // 列表項目間距
    
    // MARK: - Corner Radius
    static let cornerRadiusSM: CGFloat = 6
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusLG: CGFloat = 12
    static let cornerRadiusXL: CGFloat = 16
    
    // MARK: - Typography (增強視覺層次)
    static let titleLarge = Font.system(size: 28, weight: .bold)
    static let titleMedium = Font.system(size: 22, weight: .bold)
    static let sectionHeader = Font.system(size: 18, weight: .bold)        // 增強區塊標題
    static let subsectionHeader = Font.system(size: 16, weight: .semibold) // 新增子區塊標題
    static let bodyText = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .medium)         // 新增中等重要性文字
    static let bodySmall = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)      // 新增粗體說明文字
    
    // MARK: - Shadows (深色模式適配)
    static let shadowRadius: CGFloat = 4
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let shadowOpacity: Double = 0.1
    
    /// 深色模式下的陰影顏色
    static var shadowColor: Color {
        Color(light: "#000000", dark: "#FFFFFF")
    }
    
    /// 深色模式下的陰影不透明度
    @MainActor
    static var shadowOpacityAdaptive: Double {
        // 深色模式下陰影更明顯一些
        return ThemeManager.shared.isDarkMode ? 0.15 : 0.1
    }
    
    /// 獲取主題適配的陰影不透明度（需要在 @MainActor 環境中調用）
    @MainActor
    static func adaptiveShadowOpacity() -> Double {
        return ThemeManager.shared.isDarkMode ? 0.2 : 0.1
    }
    
    // MARK: - Border & Divider
    
    /// 邊框顏色
    static var borderColor: Color {
        Color(light: "#E1E5E9", dark: "#444444")
    }
    
    /// 分隔線顏色  
    static var dividerColor: Color {
        Color(light: "#E1E5E9", dark: "#3C3C3E")
    }
    
    /// 細邊框寬度
    static let borderWidthThin: CGFloat = 0.5
    
    /// 標準邊框寬度
    static let borderWidth: CGFloat = 1.0
    
    /// 厚邊框寬度
    static let borderWidthThick: CGFloat = 2.0
    
    // MARK: - Elevation (Material Design 風格的層級)
    
    /// 卡片陰影 (Elevation 1) - 深色模式下增強
    @MainActor
    static var cardShadow: (radius: CGFloat, offset: CGSize, opacity: Double) {
        let isDark = ThemeManager.shared.isDarkMode
        return (
            radius: isDark ? 4 : 2, 
            offset: CGSize(width: 0, height: isDark ? 2 : 1), 
            opacity: isDark ? 0.25 : 0.1
        )
    }
    
    /// 彈窗陰影 (Elevation 8) - 深色模式下增強
    @MainActor
    static var modalShadow: (radius: CGFloat, offset: CGSize, opacity: Double) {
        let isDark = ThemeManager.shared.isDarkMode
        return (
            radius: isDark ? 12 : 8, 
            offset: CGSize(width: 0, height: isDark ? 6 : 4), 
            opacity: isDark ? 0.4 : 0.15
        )
    }
    
    /// 浮動按鈕陰影 (Elevation 6) - 深色模式下增強
    @MainActor
    static var fabShadow: (radius: CGFloat, offset: CGSize, opacity: Double) {
        let isDark = ThemeManager.shared.isDarkMode
        return (
            radius: isDark ? 8 : 6, 
            offset: CGSize(width: 0, height: isDark ? 4 : 3), 
            opacity: isDark ? 0.3 : 0.12
        )
    }
    
    // MARK: - Button & Touch Target Sizes (符合 Apple HIG 最小 44pt 觸控目標)
    
    /// 最小觸控目標尺寸 (Apple HIG 建議)
    static let minTouchTarget: CGFloat = 44
    
    /// 按鈕高度規格
    static let buttonHeightSM: CGFloat = 32      // 小按鈕
    static let buttonHeightMD: CGFloat = 44      // 標準按鈕
    static let buttonHeightLG: CGFloat = 56      // 大按鈕
    
    /// 按鈕內邊距
    static let buttonPaddingHorizontal: CGFloat = 16
    static let buttonPaddingVertical: CGFloat = 12
    
    /// 浮動按鈕尺寸
    static let fabSize: CGFloat = 56
    static let fabSizeSmall: CGFloat = 40
    
    // MARK: - Animation (增強動畫令牌)
    static let animationFast: Double = 0.2
    static let animationNormal: Double = 0.3
    static let animationSlow: Double = 0.5
    
    /// 主題切換動畫
    static let themeTransition: Animation = .easeInOut(duration: 0.3)
    
    /// 彈性動畫
    static let springAnimation: Animation = .spring(response: 0.6, dampingFraction: 0.8)
    
    /// 淡入淡出動畫
    static let fadeAnimation: Animation = .easeInOut(duration: 0.25)
    
    // MARK: - Investment-specific Tokens (投資應用專用 - 台股配色)
    
    /// 股價上漲顏色 - 台股紅漲 (深色模式適配)
    static var priceUpColor: Color {
        Color(light: "#FF4444", dark: "#F44336") // 台股：紅色代表上漲
    }
    
    /// 股價下跌顏色 - 台股綠跌 (深色模式適配)
    static var priceDownColor: Color {
        Color(light: "#00C851", dark: "#4CAF50") // 台股：綠色代表下跌
    }
    
    /// 股價平盤顏色
    static var priceNeutralColor: Color {
        Color(light: "#6C757D", dark: "#9E9E9E")
    }
    
    /// 投資組合背景顏色
    static var portfolioBackgroundColor: Color {
        Color(light: "#FFFFFF", dark: "#1C1C1E")
    }
    
    /// 圖表背景顏色
    static var chartBackgroundColor: Color {
        Color(light: "#FAFAFA", dark: "#2C2C2E")
    }
}
