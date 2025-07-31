//
//  ProductionReadyComponents.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  生產級別的 UI 組件 - 解決實際應用中的視覺結構、互動性和可讀性問題
//

import SwiftUI

// MARK: - 增強的視覺分隔卡片系統
extension View {
    /// 生產級別的卡片樣式 - 強化陰影和分隔感
    func productionCardStyle(elevation: CardElevation = .medium, spacing: CGFloat = DesignTokens.spacingMD) -> some View {
        let isDark = ThemeManager.shared.isDarkMode
        let shadow = elevation.shadowProperties
        
        return self
            .padding(spacing)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                    .fill(Color.surfacePrimary)
                    .shadow(
                        color: isDark ? Color.white.opacity(shadow.opacity) : Color.black.opacity(shadow.opacity),
                        radius: shadow.radius,
                        x: shadow.offset.width,
                        y: shadow.offset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                    .stroke(
                        isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
                        lineWidth: isDark ? 1 : 0.5
                    )
            )
    }
    
    /// 清單項目分隔樣式
    func listItemSeparator() -> some View {
        self.overlay(
            Rectangle()
                .fill(DesignTokens.dividerColor)
                .frame(height: 0.5)
                .padding(.leading, DesignTokens.spacingMD),
            alignment: .bottom
        )
    }
    
    /// 統一的內容區塊間距
    func contentBlockSpacing() -> some View {
        self.padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingLG)
    }
}

// MARK: - 卡片海拔高度系統
enum CardElevation {
    case low
    case medium  
    case high
    case floating
    
    var shadowProperties: (radius: CGFloat, offset: CGSize, opacity: Double) {
        let isDark = ThemeManager.shared.isDarkMode
        
        switch self {
        case .low:
            return (
                radius: 2,
                offset: CGSize(width: 0, height: 1),
                opacity: isDark ? 0.2 : 0.08
            )
        case .medium:
            return (
                radius: 4,
                offset: CGSize(width: 0, height: 2),
                opacity: isDark ? 0.25 : 0.12
            )
        case .high:
            return (
                radius: 8,
                offset: CGSize(width: 0, height: 4),
                opacity: isDark ? 0.3 : 0.16
            )
        case .floating:
            return (
                radius: 12,
                offset: CGSize(width: 0, height: 8),
                opacity: isDark ? 0.4 : 0.2
            )
        }
    }
}

// MARK: - 增強的互動按鈕系統
struct EnhancedInteractiveButton: View {
    let title: String
    let icon: String?
    let style: InteractiveButtonStyle
    let size: InteractiveButtonSize
    let state: ButtonState
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(
        _ title: String,
        icon: String? = nil,
        style: InteractiveButtonStyle = .primary,
        size: InteractiveButtonSize = .medium,
        state: ButtonState = .normal,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.state = state
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: size.iconSpacing) {
                // 載入狀態圖標
                if state == .loading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(style.foregroundColor)
                } else if let icon = icon {
                    Image(systemName: state == .success ? "checkmark" : icon)
                        .font(size.iconFont)
                        .foregroundColor(style.foregroundColor)
                }
                
                Text(state.displayTitle(original: title))
                    .font(size.textFont)
                    .fontWeight(.semibold)
                    .foregroundColor(style.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: size.minWidth, minHeight: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(style.backgroundColor(for: state))
                    .shadow(
                        color: style.shadowColor,
                        radius: isPressed ? 2 : 4,
                        y: isPressed ? 1 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(state == .disabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.3), value: state)
        }
        .disabled(state == .disabled || state == .loading)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    private func handleTap() {
        hapticFeedback.impactOccurred()
        action()
    }
}

// MARK: - 按鈕樣式定義
enum InteractiveButtonStyle {
    case primary
    case secondary  
    case success
    case warning
    case danger
    case ghost
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return .white
        case .success: return .white
        case .warning: return .black
        case .danger: return .white
        case .ghost: return .brandGreen
        }
    }
    
    func backgroundColor(for state: ButtonState) -> Color {
        let baseColor: Color
        switch self {
        case .primary: baseColor = .brandGreen
        case .secondary: baseColor = .brandBlue
        case .success: baseColor = .success
        case .warning: baseColor = .warning
        case .danger: baseColor = .danger
        case .ghost: baseColor = .clear
        }
        
        switch state {
        case .success: return .success
        case .disabled: return baseColor.opacity(0.3)
        default: return baseColor
        }
    }
    
    var borderColor: Color {
        switch self {
        case .ghost: return .brandGreen
        default: return .clear
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .ghost: return 2
        default: return 0
        }
    }
    
    var shadowColor: Color {
        return Color.black.opacity(0.1)
    }
}

// MARK: - 按鈕尺寸定義
enum InteractiveButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        }
    }
    
    var minWidth: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 100
        case .large: return 120
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
    
    var textFont: Font {
        switch self {
        case .small: return .system(size: 14, weight: .semibold)
        case .medium: return .system(size: 16, weight: .semibold)
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
    
    var iconSpacing: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 8
        case .large: return 10
        }
    }
}

// MARK: - 按鈕狀態定義
enum ButtonState {
    case normal
    case loading
    case success
    case disabled
    
    func displayTitle(original: String) -> String {
        switch self {
        case .normal, .disabled: return original
        case .loading: return "處理中..."
        case .success: return "完成"
        }
    }
}

// MARK: - 增強的 TabBar 系統
struct EnhancedTabBarItem: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int?
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: 4) {
                ZStack {
                    // 背景指示器
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandGreen.opacity(0.1))
                            .frame(width: 64, height: 32)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 圖標
                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .brandGreen : .textSecondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .overlay(
                            // 徽章
                            badgeView,
                            alignment: .topTrailing
                        )
                }
                
                // 標題
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .brandGreen : .textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    @ViewBuilder
    private var badgeView: some View {
        if let count = badgeCount, count > 0 {
            ZStack {
                Circle()
                    .fill(Color.danger)
                    .frame(width: 16, height: 16)
                
                Text("\(min(count, 99))")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .offset(x: 8, y: -8)
        }
    }
    
    private func handleTap() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
        onTap()
    }
}

// MARK: - 統一的標題階層系統
struct ContentHierarchy {
    /// 主標題（頁面標題）
    static func pageTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .bold))
            .adaptiveTextColor()
            .padding(.bottom, DesignTokens.spacingSM)
    }
    
    /// 區塊標題
    static func sectionTitle(_ text: String, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 20, weight: .bold))
                .adaptiveTextColor()
            
            Spacer()
            
            if let action = action {
                Button("查看全部") {
                    action()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.brandBlue)
            }
        }
        .padding(.bottom, DesignTokens.spacingSM)
    }
    
    /// 子區塊標題
    static func subsectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .adaptiveTextColor()
            .padding(.bottom, DesignTokens.spacingXS)
    }
    
    /// 列表項目標題 
    static func itemTitle(_ text: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .adaptiveTextColor()
                .lineLimit(2)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .adaptiveTextColor(primary: false)
                    .lineLimit(3)
            }
        }
    }
}

// MARK: - 增強的空狀態組件
struct ProductionEmptyState: View {
    let image: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let style: EmptyStateStyle
    
    init(
        image: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        style: EmptyStateStyle = .default
    ) {
        self.image = image
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // 插圖或圖標
            Image(systemName: image)
                .font(.system(size: style.imageSize, weight: .light))
                .foregroundColor(.textTertiary)
            
            // 文字內容
            VStack(spacing: DesignTokens.spacingSM) {
                Text(title)
                    .font(.system(size: style.titleSize, weight: .semibold))
                    .adaptiveTextColor()
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: style.messageSize, weight: .regular))
                    .adaptiveTextColor(primary: false)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 行動按鈕
            if let actionTitle = actionTitle, let action = action {
                EnhancedInteractiveButton(
                    actionTitle,
                    style: .primary,
                    size: .medium,
                    action: action
                )
            }
        }
        .padding(style.containerPadding)
        .frame(maxWidth: .infinity)
    }
}

enum EmptyStateStyle {
    case `default`
    case compact
    case large
    
    var imageSize: CGFloat {
        switch self {
        case .default: return 64
        case .compact: return 48
        case .large: return 80
        }
    }
    
    var titleSize: CGFloat {
        switch self {
        case .default: return 18
        case .compact: return 16
        case .large: return 22
        }
    }
    
    var messageSize: CGFloat {
        switch self {
        case .default: return 15
        case .compact: return 14
        case .large: return 16
        }
    }
    
    var containerPadding: CGFloat {
        switch self {
        case .default: return DesignTokens.spacingXL
        case .compact: return DesignTokens.spacingLG
        case .large: return DesignTokens.spacingXXL
        }
    }
}

// MARK: - 按鈕按壓事件修飾器
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - 預覽
#Preview("生產級別卡片") {
    ScrollView {
        VStack(spacing: DesignTokens.spacingLG) {
            // 低海拔卡片
            VStack {
                ContentHierarchy.subsectionTitle("基本資訊")
                Text("這是一個低海拔的卡片，適合次要資訊")
                    .adaptiveTextColor(primary: false)
            }
            .productionCardStyle(elevation: .low)
            
            // 中海拔卡片
            VStack {
                ContentHierarchy.subsectionTitle("重要資訊")
                Text("這是一個中海拔的卡片，適合重要內容")
                    .adaptiveTextColor()
            }
            .productionCardStyle(elevation: .medium)
            
            // 高海拔卡片
            VStack {
                ContentHierarchy.subsectionTitle("關鍵操作")
                Text("這是一個高海拔的卡片，適合關鍵操作區域")
                    .adaptiveTextColor()
            }
            .productionCardStyle(elevation: .high)
        }
        .contentBlockSpacing()
    }
    .background(Color.surfaceGrouped)
}

#Preview("增強互動按鈕") {
    VStack(spacing: DesignTokens.spacingLG) {
        // 不同樣式
        HStack(spacing: DesignTokens.spacingMD) {
            EnhancedInteractiveButton("主要", style: .primary, action: {})
            EnhancedInteractiveButton("次要", style: .secondary, action: {})
            EnhancedInteractiveButton("成功", style: .success, action: {})
        }
        
        // 帶圖標
        HStack(spacing: DesignTokens.spacingMD) {
            EnhancedInteractiveButton("充值", icon: "plus.circle", style: .primary, action: {})
            EnhancedInteractiveButton("分享", icon: "square.and.arrow.up", style: .ghost, action: {})
        }
        
        // 不同狀態
        HStack(spacing: DesignTokens.spacingMD) {
            EnhancedInteractiveButton("載入中", state: .loading, action: {})
            EnhancedInteractiveButton("已完成", state: .success, action: {})
            EnhancedInteractiveButton("禁用", state: .disabled, action: {})
        }
    }
    .padding()
}

#Preview("空狀態組件") {
    VStack(spacing: DesignTokens.spacingXL) {
        ProductionEmptyState(
            image: "person.2",
            title: "還沒有好友",
            message: "開始添加好友，一起分享投資心得吧！",
            actionTitle: "添加好友",
            action: {},
            style: .default
        )
        
        ProductionEmptyState(
            image: "chart.bar",
            title: "暫無績效數據",
            message: "完成首次投資後即可查看詳細分析",
            style: .compact
        )
    }
    .padding()
}