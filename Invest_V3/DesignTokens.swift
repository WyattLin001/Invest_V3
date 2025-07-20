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
    
    // MARK: - Shadows
    static let shadowRadius: CGFloat = 4
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let shadowOpacity: Double = 0.1
    
    // MARK: - Animation
    static let animationFast: Double = 0.2
    static let animationNormal: Double = 0.3
    static let animationSlow: Double = 0.5
}
