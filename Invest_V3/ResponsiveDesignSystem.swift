//
//  ResponsiveDesignSystem.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  響應式設計系統 - 支援小螢幕防溢出、動畫回饋和適應性佈局
//

import SwiftUI

// MARK: - 設備尺寸檢測
struct DeviceInfo {
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    static var isSmallScreen: Bool {
        screenWidth <= 375 // iPhone SE 系列
    }
    
    static var isCompactHeight: Bool {
        screenHeight <= 667 // iPhone SE, 8 系列
    }
    
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var safeAreaInsets: UIEdgeInsets {
        UIApplication.shared.windows.first?.safeAreaInsets ?? UIEdgeInsets()
    }
}

// MARK: - 響應式間距系統
struct ResponsiveSpacing {
    static func horizontal(compact: CGFloat, regular: CGFloat) -> CGFloat {
        DeviceInfo.isSmallScreen ? compact : regular
    }
    
    static func vertical(compact: CGFloat, regular: CGFloat) -> CGFloat {
        DeviceInfo.isCompactHeight ? compact : regular
    }
    
    static var cardPadding: CGFloat {
        horizontal(compact: DesignTokens.spacingSM, regular: DesignTokens.spacingMD)
    }
    
    static var sectionSpacing: CGFloat {
        vertical(compact: DesignTokens.spacingLG, regular: DesignTokens.sectionSpacing)
    }
    
    static var screenPadding: CGFloat {
        horizontal(compact: DesignTokens.spacingSM, regular: DesignTokens.spacingMD)
    }
}

// MARK: - 響應式字體系統
struct ResponsiveFont {
    static func title(compact: Font, regular: Font) -> Font {
        DeviceInfo.isSmallScreen ? compact : regular
    }
    
    static var largeTitle: Font {
        title(
            compact: .system(size: 24, weight: .bold),
            regular: DesignTokens.titleLarge
        )
    }
    
    static var sectionTitle: Font {
        title(
            compact: .system(size: 16, weight: .bold),
            regular: DesignTokens.sectionHeader
        )
    }
    
    static var balance: Font {
        title(
            compact: .system(size: 28, weight: .bold, design: .rounded),
            regular: .system(size: 36, weight: .bold, design: .rounded)
        )
    }
}

// MARK: - 適應性容器
struct AdaptiveContainer<Content: View>: View {
    let maxWidth: CGFloat?
    let content: Content
    
    init(maxWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let contentWidth = min(maxWidth ?? availableWidth, availableWidth)
            
            HStack {
                if contentWidth < availableWidth {
                    Spacer()
                }
                
                content
                    .frame(width: contentWidth)
                
                if contentWidth < availableWidth {
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 可滾動數值顯示
struct ScrollableNumberDisplay: View {
    let value: String
    let subtitle: String?
    let color: Color
    let font: Font
    
    init(
        value: String,
        subtitle: String? = nil,
        color: Color = .textPrimary,
        font: Font = ResponsiveFont.balance
    ) {
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.font = font
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(value)
                    .font(font)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .adaptiveTextColor(primary: false)
            }
        }
    }
}

// MARK: - 自適應按鈕
struct AdaptiveButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyle
    let size: ButtonSize
    let isDisabled: Bool
    let minWidth: CGFloat?
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        isDisabled: Bool = false,
        minWidth: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.style = style
        self.size = size
        self.isDisabled = isDisabled
        self.minWidth = minWidth
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingXS) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minWidth: minWidth, minHeight: size.height)
            .background(isDisabled ? style.backgroundColor.opacity(0.3) : style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(DesignTokens.cornerRadius)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(BrandAnimations.buttonPress, value: isPressed)
        }
        .disabled(isDisabled)
    }
    
    @State private var isPressed = false
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case ghost
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .brandGreen
            case .secondary: return .brandBlue
            case .destructive: return .danger
            case .ghost: return .clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .secondary, .destructive: return .white
            case .ghost: return .brandGreen
            }
        }
    }
}

// MARK: - 載入狀態指示器
struct LoadingStateView: View {
    let isLoading: Bool
    let title: String
    let subtitle: String?
    
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.brandBlue)
                    .rotationEffect(Angle(degrees: rotation))
                    .onAppear {
                        withAnimation(BrandAnimations.loading) {
                            rotation = 360
                        }
                    }
            }
            
            VStack(spacing: DesignTokens.spacingXS) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(DesignTokens.spacingLG)
    }
}

// MARK: - 響應式網格佈局
struct ResponsiveGridLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let minItemWidth: CGFloat
    let maxColumns: Int
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(
        data: Data,
        minItemWidth: CGFloat = 120,
        maxColumns: Int = 4,
        spacing: CGFloat = DesignTokens.spacingMD,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.minItemWidth = minItemWidth
        self.maxColumns = maxColumns
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (ResponsiveSpacing.screenPadding * 2)
            let possibleColumns = Int(availableWidth / (minItemWidth + spacing))
            let actualColumns = min(max(1, possibleColumns), maxColumns)
            let itemWidth = (availableWidth - CGFloat(actualColumns - 1) * spacing) / CGFloat(actualColumns)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: actualColumns),
                spacing: spacing
            ) {
                ForEach(data, id: \.id) { item in
                    content(item)
                }
            }
            .padding(.horizontal, ResponsiveSpacing.screenPadding)
        }
    }
}

// MARK: - 動畫過渡容器
struct AnimatedTransitionContainer<Content: View>: View {
    let content: Content
    let isVisible: Bool
    let transition: AnyTransition
    
    init(
        isVisible: Bool,
        transition: AnyTransition = .opacity.combined(with: .scale(scale: 0.95)),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isVisible = isVisible
        self.transition = transition
    }
    
    var body: some View {
        Group {
            if isVisible {
                content
                    .transition(transition)
            }
        }
        .animation(BrandAnimations.standardTransition, value: isVisible)
    }
}

// MARK: - 觸覺回饋助手
struct HapticFeedback {
    static func selection() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let feedback = UIImpactFeedbackGenerator(style: style)
        feedback.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(type)
    }
    
    // 為了向後相容，提供 success 方法
    static func success() {
        impact(.light)
    }
}

// MARK: - 響應式修飾器
extension View {
    /// 響應式內邊距
    func responsivePadding() -> some View {
        self.padding(.horizontal, ResponsiveSpacing.screenPadding)
            .padding(.vertical, ResponsiveSpacing.sectionSpacing)
    }
    
    /// 小螢幕適配字體
    func adaptiveFont(_ regular: Font, compact: Font? = nil) -> some View {
        self.font(DeviceInfo.isSmallScreen ? (compact ?? regular) : regular)
    }
    
    /// 觸覺回饋
    func hapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            HapticFeedback.impact(type)
        }
    }
    
    /// 安全區域感知間距
    func safeAreaAwarePadding() -> some View {
        self.padding(.top, DeviceInfo.safeAreaInsets.top > 0 ? 0 : DesignTokens.spacingMD)
            .padding(.bottom, DeviceInfo.safeAreaInsets.bottom > 0 ? 0 : DesignTokens.spacingMD)
    }
    
    /// 防溢出修飾器
    func preventOverflow() -> some View {
        self.lineLimit(nil)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
    }
}

// MARK: - 預覽
#Preview("響應式按鈕") {
    VStack(spacing: DesignTokens.spacingMD) {
        AdaptiveButton(
            "充值",
            icon: "plus.circle.fill",
            style: .primary,
            action: {}
        )
        
        AdaptiveButton(
            "查看全部",
            style: .secondary,
            action: {}
        )
        
        AdaptiveButton(
            "刪除",
            icon: "trash",
            style: .destructive,
            action: {}
        )
        
        AdaptiveButton(
            "取消",
            style: .ghost,
            action: {}
        )
    }
    .padding()
}

#Preview("可滾動數值") {
    VStack(spacing: DesignTokens.spacingLG) {
        ScrollableNumberDisplay(
            value: "1,234,567,890",
            subtitle: "代幣",
            color: .brandGreen
        )
        
        ScrollableNumberDisplay(
            value: "+25.67%",
            subtitle: "今日變化",
            color: .success
        )
        
        ScrollableNumberDisplay(
            value: "NT$12,345,678",
            subtitle: "總資產",
            color: .textPrimary
        )
    }
    .padding()
    .frame(width: 200) // 模擬小螢幕
}

#Preview("載入狀態") {
    VStack(spacing: DesignTokens.spacingXL) {
        LoadingStateView(
            isLoading: true,
            title: "載入中...",
            subtitle: "正在獲取最新數據"
        )
        
        LoadingStateView(
            isLoading: false,
            title: "載入完成",
            subtitle: "數據已更新"
        )
    }
    .padding()
}