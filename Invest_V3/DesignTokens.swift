//
//  DesignTokens.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/19.
//

import SwiftUI

/// 設計系統的設計令牌
enum DesignTokens {
    // MARK: - Spacing (8pt grid system)
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 40
    
    // MARK: - Corner Radius
    static let cornerRadiusSM: CGFloat = 6
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusLG: CGFloat = 12
    static let cornerRadiusXL: CGFloat = 16
    
    // MARK: - Typography
    static let titleLarge = Font.system(size: 24, weight: .bold)
    static let titleMedium = Font.system(size: 20, weight: .semibold)
    static let sectionHeader = Font.system(size: 18, weight: .semibold)
    static let bodyText = Font.system(size: 16, weight: .regular)
    static let bodySmall = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    
    // MARK: - Shadows (深色模式適配)
    static let shadowRadius: CGFloat = 4
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let shadowOpacity: Double = 0.1
    
    /// 深色模式下的陰影顏色
    static var shadowColor: Color {
        Color(light: "#000000", dark: "#000000")
    }
    
    /// 深色模式下的陰影不透明度
    static var shadowOpacityAdaptive: Double {
        // 深色模式下陰影更明顯一些，預設為淺色模式值
        return 0.1
    }
    
    /// 獲取主題適配的陰影不透明度（需要在 @MainActor 環境中調用）
    @MainActor
    static func adaptiveShadowOpacity() -> Double {
        return ThemeManager.shared.isDarkMode ? 0.3 : 0.1
    }
    
    // MARK: - Border & Divider
    
    /// 邊框顏色
    static var borderColor: Color {
        Color(light: "#E1E5E9", dark: "#3A3A3C")
    }
    
    /// 分隔線顏色  
    static var dividerColor: Color {
        Color(light: "#E1E5E9", dark: "#38383A")
    }
    
    /// 細邊框寬度
    static let borderWidthThin: CGFloat = 0.5
    
    /// 標準邊框寬度
    static let borderWidth: CGFloat = 1.0
    
    /// 厚邊框寬度
    static let borderWidthThick: CGFloat = 2.0
    
    // MARK: - Elevation (Material Design 風格的層級)
    
    /// 卡片陰影 (Elevation 1)
    static var cardShadow: (radius: CGFloat, offset: CGSize, opacity: Double) {
        return (radius: 2, offset: CGSize(width: 0, height: 1), opacity: shadowOpacityAdaptive)
    }
    
    /// 彈窗陰影 (Elevation 8)
    static var modalShadow: (radius: CGFloat, offset: CGSize, opacity: Double) {
        return (radius: 8, offset: CGSize(width: 0, height: 4), opacity: shadowOpacityAdaptive * 1.5)
    }
    
    /// 浮動按鈕陰影 (Elevation 6)
    static var fabShadow: (radius: CGFloat, offset: CGSize, opacity: Double) {
        return (radius: 6, offset: CGSize(width: 0, height: 3), opacity: shadowOpacityAdaptive * 1.2)
    }
    
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
    
    // MARK: - Investment-specific Tokens (投資應用專用)
    
    /// 股價上漲顏色 (深色模式適配)
    static var priceUpColor: Color {
        Color(light: "#00C851", dark: "#4CAF50") // 深色模式下稍微柔和一些
    }
    
    /// 股價下跌顏色 (深色模式適配)
    static var priceDownColor: Color {
        Color(light: "#FF4444", dark: "#F44336") // 深色模式下稍微柔和一些
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
