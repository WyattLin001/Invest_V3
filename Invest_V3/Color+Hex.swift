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
    
    /// 主要品牌綠色 #00B900 - 用於主要 CTA / Toggle ON
    static let brandGreen = Color(hex: "#00B900")
    
    /// 品牌橙色 #FD7E14 - 用於付費/警示 CTA  
    static let brandOrange = Color(hex: "#FD7E14")
    
    /// 品牌藍色 #007BFF - 用於投資指令高亮
    static let brandBlue = Color(hex: "#007BFF")
    
    // MARK: - Semantic Colors (支援深色模式)
    
    /// 背景 Layer 0 - 最淺灰色
    static let gray50 = Color(light: "#FAFAFA", dark: "#0A0A0A")
    
    /// 背景 Layer 1
    static let gray100 = Color(light: "#F7F7F7", dark: "#121212")
    
    /// 背景 Layer 2  
    static let gray200 = Color(light: "#EEEEEE", dark: "#1E1E1E")
    
    /// 主要文本
    static let gray900 = Color(light: "#1E1E1E", dark: "#E0E0E0")
    
    /// 次要文本
    static let gray600 = Color(light: "#6C757D", dark: "#9E9E9E")
    
    /// 分隔線
    static let gray300 = Color(light: "#DEE2E6", dark: "#424242")
    
    /// 灰色400
    static let gray400 = Color(hex: "#CED4DA")
    
    /// 灰色500 - 中等灰色文本
    static let gray500 = Color(hex: "#6C757D")
    
    /// 灰色700
    static let gray700 = Color(hex: "#495057")
    
    /// 灰色800 - 深色文本
    static let gray800 = Color(hex: "#343A40")
    
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

struct DesignTokens {
    // MARK: - Spacing (根據 target.txt 8pt grid)
    static let spacing: CGFloat = 8
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    
    // MARK: - Corner Radius (全域圓角 12pt)
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusLG: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 24
    
    // MARK: - Shadows (Elevation 1)
    static let shadowRadius: CGFloat = 2
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let shadowOpacity: Double = 0.05
    static let shadowOpacityDark: Double = 0.2
    
    // MARK: - Animation Durations
    static let animationFast: Double = 0.15
    static let animationNormal: Double = 0.25
    static let animationSlow: Double = 0.4
    
    // MARK: - Tab Bar
    static let tabBarHeight: CGFloat = 60
    
    // MARK: - Safe Area
    static let safeAreaTop: CGFloat = 54
}

// MARK: - View Modifiers

extension View {
    /// 應用品牌卡片樣式 (Elevation 1)
    func brandCardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(DesignTokens.cornerRadius)
            .shadow(
                color: Color.black.opacity(DesignTokens.shadowOpacity),
                radius: DesignTokens.shadowRadius,
                x: DesignTokens.shadowOffset.width,
                y: DesignTokens.shadowOffset.height
            )
    }
    
    /// 應用品牌按鈕樣式
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
