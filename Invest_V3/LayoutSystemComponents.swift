//
//  LayoutSystemComponents.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  統一的佈局系統組件 - 解決資訊密度和間距不一致問題
//

import SwiftUI

// MARK: - 統一間距容器
struct UnifiedSpacingContainer<Content: View>: View {
    let content: Content
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let itemSpacing: CGFloat
    
    init(
        horizontalPadding: CGFloat = DesignTokens.spacingMD,
        verticalPadding: CGFloat = DesignTokens.spacingLG,
        itemSpacing: CGFloat = DesignTokens.cardSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.itemSpacing = itemSpacing
    }
    
    var body: some View {
        VStack(spacing: itemSpacing) {
            content
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }
}

// MARK: - 統一的數據顯示組件
struct DataDisplayRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    let alignment: HorizontalAlignment
    let showDivider: Bool
    
    init(
        label: String,
        value: String,
        valueColor: Color? = nil,
        alignment: HorizontalAlignment = .trailing,
        showDivider: Bool = false
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.alignment = alignment
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .adaptiveTextColor(primary: false)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor ?? Color.textPrimary)
                    .monospacedDigit()
            }
            .padding(.vertical, DesignTokens.spacingSM)
            
            if showDivider {
                Divider()
                    .background(DesignTokens.dividerColor)
            }
        }
    }
}

// MARK: - 統一的指標卡片
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    let trend: TrendDirection?
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color = .brandBlue,
        trend: TrendDirection? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 標題和圖標
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
                    .lineLimit(1)
                
                Spacer()
                
                if let trend = trend {
                    Image(systemName: trend.iconName)
                        .font(.caption2)
                        .foregroundColor(trend.color)
                }
            }
            
            // 主要數值
            VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .adaptiveTextColor(primary: false)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.spacingMD)
        .background(Color.surfaceSecondary)
        .cornerRadius(DesignTokens.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 趨勢方向枚舉
enum TrendDirection {
    case up
    case down
    case neutral
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .success
        case .down: return .danger
        case .neutral: return .textSecondary
        }
    }
}

// MARK: - 統一的列表項目
struct UnifiedListItem<Content: View>: View {
    let leadingIcon: String?
    let leadingIconColor: Color
    let title: String
    let subtitle: String?
    let trailing: Content?
    let isDisabled: Bool
    let action: (() -> Void)?
    
    init(
        leadingIcon: String? = nil,
        leadingIconColor: Color = .brandBlue,
        title: String,
        subtitle: String? = nil,
        isDisabled: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Content = { EmptyView() }
    ) {
        self.leadingIcon = leadingIcon
        self.leadingIconColor = leadingIconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // 左側圖標
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDisabled ? .textDisabled : leadingIconColor)
                    .frame(width: 24, height: 24)
            }
            
            // 標題和副標題
            VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isDisabled ? .textDisabled : .textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isDisabled ? .textDisabled : .textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 右側內容
            if trailing != nil {
                trailing
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled {
                action?()
            }
        }
        .opacity(isDisabled ? 0.6 : 1)
    }
}

// MARK: - 空狀態視圖
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            VStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.textTertiary)
                
                VStack(spacing: DesignTokens.spacingXS) {
                    Text(title)
                        .font(.headline)
                        .disabledStyle()
                    
                    Text(message)
                        .font(.subheadline)
                        .secondaryContentStyle()
                        .multilineTextAlignment(.center)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .brandButtonStyle(size: .medium)
            }
        }
        .padding(DesignTokens.spacingXL)
    }
}

// MARK: - 響應式網格佈局
struct ResponsiveGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let minItemWidth: CGFloat
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(
        data: Data,
        minItemWidth: CGFloat = 150,
        spacing: CGFloat = DesignTokens.spacingMD,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (spacing * 2)
            let columnCount = max(1, Int(availableWidth / (minItemWidth + spacing)))
            let itemWidth = (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columnCount),
                spacing: spacing
            ) {
                ForEach(data, id: \.id) { item in
                    content(item)
                }
            }
        }
    }
}

// MARK: - 統一的區塊容器
struct SectionContainer<Content: View>: View {
    let title: String?
    let subtitle: String?
    let headerAction: (() -> Void)?
    let headerActionTitle: String?
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        headerActionTitle: String? = nil,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerAction = headerAction
        self.headerActionTitle = headerActionTitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            // 標題區域
            if title != nil || headerAction != nil {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                        if let title = title {
                            Text(title)
                                .sectionTitleStyle()
                        }
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .adaptiveTextColor(primary: false)
                        }
                    }
                    
                    Spacer()
                    
                    if let actionTitle = headerActionTitle, let action = headerAction {
                        Button(actionTitle, action: action)
                            .secondaryButtonStyle(size: .small)
                    }
                }
            }
            
            // 內容
            content
        }
    }
}

// MARK: - 預覽
#Preview("資料顯示行") {
    VStack {
        DataDisplayRow(
            label: "總報酬率",
            value: "+25.00%",
            valueColor: .success,
            showDivider: true
        )
        
        DataDisplayRow(
            label: "年化報酬率",
            value: "+18.00%",
            valueColor: .success,
            showDivider: true
        )
        
        DataDisplayRow(
            label: "最大回撤",
            value: "-8.00%",
            valueColor: .danger
        )
    }
    .enhancedCardStyle()
    .padding()
}

#Preview("指標卡片") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignTokens.spacingMD) {
        MetricCard(
            title: "科技股佔比",
            value: "45.2%",
            icon: "building.2",
            color: .brandBlue,
            trend: .up
        )
        
        MetricCard(
            title: "7日趨勢",
            value: "上升",
            subtitle: "持續向好",
            icon: "chart.xyaxis.line",
            color: .success,
            trend: .up
        )
        
        MetricCard(
            title: "波動率",
            value: "12.4%",
            icon: "waveform.path.ecg",
            color: .warning,
            trend: .down
        )
        
        MetricCard(
            title: "β係數",
            value: "1.15",
            subtitle: "vs 大盤",
            icon: "chart.bar.xaxis",
            color: .info,
            trend: .neutral
        )
    }
    .padding()
}

#Preview("空狀態視圖") {
    EmptyStateView(
        icon: "chart.bar.doc.horizontal",
        title: "暫無績效數據",
        message: "開始您的第一筆投資，建立投資記錄後就能看到詳細的績效分析了",
        actionTitle: "開始投資",
        action: {}
    )
    .padding()
}