import SwiftUI

// Design tokens specific to AuthorEarnings views
enum EarningsDesignTokens {
    // Color system
    static let primaryGreen = Color.brandGreen
    static let successGreen = Color.green
    static let warningOrange = Color.orange
    static let errorRed = Color.red

    // Font system (dynamic type)
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title2.weight(.semibold)
    static let headline = Font.headline.weight(.medium)
    static let body = Font.body
    static let caption = Font.caption

    // Spacing system (8pt grid)
    static let spacing4: CGFloat = DesignTokens.spacingXS
    static let spacing8: CGFloat = DesignTokens.spacingSM
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = DesignTokens.spacingMD
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = DesignTokens.spacingLG
    static let spacing32: CGFloat = DesignTokens.spacingXL

    // Corner radius
    static let cornerRadius8: CGFloat = DesignTokens.cornerRadiusSM
    static let cornerRadius12: CGFloat = DesignTokens.cornerRadius
    static let cornerRadius16: CGFloat = DesignTokens.cornerRadiusLG

    // Shadow system
    static let cardShadow = Color.black.opacity(0.05)
    static let shadowRadius: CGFloat = 4
    static let shadowOffset = CGSize(width: 0, height: 2)
}