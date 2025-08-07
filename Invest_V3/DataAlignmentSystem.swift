//
//  DataAlignmentSystem.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  數據對齊和資訊組織系統 - 解決數字對齊、標題截斷和資訊密度問題
//

import SwiftUI

// MARK: - 數據對齊列表項目
struct AlignedDataRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    let trend: TrendDirection?
    let showDivider: Bool
    let alignment: DataAlignment
    
    init(
        label: String,
        value: String,
        valueColor: Color? = nil,
        trend: TrendDirection? = nil,
        showDivider: Bool = true,
        alignment: DataAlignment = .trailing
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.trend = trend
        self.showDivider = showDivider
        self.alignment = alignment
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.spacingMD) {
                // 標籤
                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .adaptiveTextColor(primary: false)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: DesignTokens.spacingSM)
                
                // 數值和趨勢
                HStack(spacing: DesignTokens.spacingXS) {
                    if let trend = trend {
                        Image(systemName: trend.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(trend.color)
                    }
                    
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(valueColor ?? .textPrimary)
                        .monospacedDigit()
                        .multilineTextAlignment(alignment.textAlignment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(minWidth: alignment.minWidth, alignment: alignment.frameAlignment)
            }
            .padding(.vertical, DesignTokens.spacingSM)
            
            if showDivider {
                Divider()
                    .background(DesignTokens.dividerColor)
            }
        }
    }
}

// MARK: - 數據對齊類型
enum DataAlignment {
    case leading
    case center
    case trailing
    
    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    
    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    
    var minWidth: CGFloat {
        switch self {
        case .leading: return 60
        case .center: return 80
        case .trailing: return 80
        }
    }
}

// MARK: - 智能標題系統（防截斷）
struct SmartTitle: View {
    let text: String
    let maxLines: Int
    let font: Font
    let color: Color
    let expandable: Bool
    
    @State private var isExpanded = false
    @State private var isTruncated = false
    
    init(
        _ text: String,
        maxLines: Int = 2,
        font: Font = .headline,
        color: Color = .textPrimary,
        expandable: Bool = true
    ) {
        self.text = text
        self.maxLines = maxLines
        self.font = font
        self.color = color
        self.expandable = expandable
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(isExpanded ? nil : maxLines)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    // 隱藏的文字用於檢測是否被截斷
                    Text(text)
                        .font(font)
                        .lineLimit(maxLines)
                        .background(GeometryReader { geometry in
                            Color.clear.onAppear {
                                let fullHeight = text.heightWithConstrainedWidth(
                                    width: geometry.size.width,
                                    font: UIFont.systemFont(ofSize: 17, weight: .semibold)
                                )
                                isTruncated = fullHeight > geometry.size.height
                            }
                        })
                        .hidden()
                )
            
            // 展開/收起按鈕
            if expandable && isTruncated {
                Button(isExpanded ? "收起" : "展開") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.brandBlue)
            }
        }
    }
}

// MARK: - 統一的資訊密度控制器
struct InformationDensityContainer<Content: View>: View {
    let density: InformationDensity
    let content: Content
    
    init(density: InformationDensity = .comfortable, @ViewBuilder content: () -> Content) {
        self.density = density
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: density.itemSpacing) {
            content
        }
        .padding(.horizontal, density.horizontalPadding)
        .padding(.vertical, density.verticalPadding)
    }
}

enum InformationDensity {
    case compact    // 緊湊模式
    case comfortable // 舒適模式
    case spacious   // 寬敞模式
    
    var itemSpacing: CGFloat {
        switch self {
        case .compact: return 8
        case .comfortable: return 12
        case .spacious: return 16
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 12
        case .comfortable: return 16
        case .spacious: return 20
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .compact: return 12
        case .comfortable: return 16
        case .spacious: return 24
        }
    }
}

// MARK: - 排行榜專用組件
struct RankingListItem: View {
    let rank: Int
    let name: String
    let subtitle: String?
    let avatar: UIImage?
    let performance: String
    let performanceColor: Color
    let trend: TrendDirection?
    let isCurrentUser: Bool
    let onTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // 排名徽章
            RankBadge(rank: rank, isCurrentUser: isCurrentUser)
            
            // 頭像
            BrandAvatar(
                image: avatar,
                placeholder: String(name.prefix(1)),
                size: .medium,
                backgroundColor: isCurrentUser ? .brandGreen : .brandBlue
            )
            
            // 名稱和副標題
            VStack(alignment: .leading, spacing: 2) {
                SmartTitle(
                    name,
                    maxLines: 1,
                    font: .system(size: 16, weight: .semibold),
                    expandable: false
                )
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .adaptiveTextColor(primary: false)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 績效數據
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: DesignTokens.spacingXS) {
                    if let trend = trend {
                        Image(systemName: trend.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(trend.color)
                    }
                    
                    Text(performance)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(performanceColor)
                        .monospacedDigit()
                }
                
                Text("回報率")
                    .font(.system(size: 11, weight: .regular))
                    .adaptiveTextColor(primary: false)
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .fill(isCurrentUser ? Color.brandGreen.opacity(0.05) : Color.clear)
        )
    }
}

// MARK: - 排名徽章
struct RankBadge: View {
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        ZStack {
            // 背景
            Circle()
                .fill(rankBackgroundColor)
                .frame(width: 32, height: 32)
            
            // 排名數字或皇冠
            if rank <= 3 {
                Image(systemName: rankIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rankForegroundColor)
            } else {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(rankForegroundColor)
                    .monospacedDigit()
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrentUser ? Color.brandGreen : Color.clear, lineWidth: 2)
        )
    }
    
    private var rankBackgroundColor: Color {
        if isCurrentUser { return .brandGreen.opacity(0.2) }
        
        switch rank {
        case 1: return .brandGold.opacity(0.2)
        case 2: return Color.gray.opacity(0.3)
        case 3: return Color.orange.opacity(0.2)
        default: return .surfaceSecondary
        }
    }
    
    private var rankForegroundColor: Color {
        if isCurrentUser { return .brandGreen }
        
        switch rank {
        case 1: return .brandGold
        case 2: return .gray
        case 3: return .orange
        default: return .textSecondary
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "star.fill"
        default: return ""
        }
    }
}

// MARK: - 群組列表項目
struct GroupListItem: View {
    let title: String
    let description: String?
    let memberCount: Int
    let hostName: String
    let performance: String?
    let performanceColor: Color?
    let isJoined: Bool
    let onJoinTap: (() -> Void)?
    let onItemTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 主要內容
            HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
                // 群組圖標
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brandGreen.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.brandGreen)
                }
                
                // 群組資訊
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    SmartTitle(
                        title,
                        maxLines: 2,
                        font: .system(size: 16, weight: .semibold)
                    )
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .adaptiveTextColor(primary: false)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // 群組統計
                    HStack(spacing: DesignTokens.spacingMD) {
                        Label("\(memberCount) 成員", systemImage: "person.2")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        
                        Label("主持人：\(hostName)", systemImage: "star")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 績效和按鈕
                VStack(alignment: .trailing, spacing: DesignTokens.spacingXS) {
                    if let performance = performance, let color = performanceColor {
                        Text(performance)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(color)
                            .monospacedDigit()
                    }
                    
                    EnhancedInteractiveButton(
                        isJoined ? "已加入" : "加入",
                        style: isJoined ? .success : .primary,
                        size: .small,
                        state: isJoined ? .success : .normal
                    ) {
                        onJoinTap?()
                    }
                }
            }
        }
        .productionCardStyle(elevation: .low)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isJoined {
                onItemTap?()
            }
        }
    }
}

// MARK: - String 擴展 - 計算文字高度
extension String {
    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
    
    func widthWithConstrainedHeight(height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.width)
    }
}

// MARK: - 預覽
#Preview("數據對齊列表") {
    VStack(spacing: 0) {
        AlignedDataRow(
            label: "總報酬率",
            value: "+25.67%",
            valueColor: .success,
            trend: .up
        )
        
        AlignedDataRow(
            label: "年化報酬率",
            value: "+18.45%",
            valueColor: .success,
            trend: .up
        )
        
        AlignedDataRow(
            label: "最大回撤",
            value: "-8.23%",
            valueColor: .danger,
            trend: .down
        )
        
        AlignedDataRow(
            label: "夏普比率",
            value: "1.85",
            valueColor: .info
        )
        
        AlignedDataRow(
            label: "勝率",
            value: "68.4%",
            valueColor: .success,
            showDivider: false
        )
    }
    .productionCardStyle()
    .padding()
}

#Preview("排行榜項目") {
    VStack(spacing: DesignTokens.spacingSM) {
        RankingListItem(
            rank: 1,
            name: "Wyatt Lin",
            subtitle: "總榜排名",
            avatar: nil as UIImage?,
            performance: "+10.0%",
            performanceColor: .success,
            trend: .up,
            isCurrentUser: true,
            onTap: {}
        )
        
        RankingListItem(
            rank: 2,
            name: "虛位以待",
            subtitle: "總榜第2名",
            avatar: nil as UIImage?,
            performance: "--",
            performanceColor: .textSecondary,
            trend: nil,
            isCurrentUser: false,
            onTap: {}
        )
    }
    .productionCardStyle()
    .padding()
}

#Preview("群組列表項目") {
    VStack(spacing: DesignTokens.spacingSM) {
        GroupListItem(
            title: "主持人：Test03",
            description: "專業投資分析討論群，分享最新市場動態和投資策略",
            memberCount: 1,
            hostName: "Test03",
            performance: "+0.0%",
            performanceColor: .textSecondary,
            isJoined: false,
            onJoinTap: {},
            onItemTap: {}
        )
        
        GroupListItem(
            title: "已加入的投資群組",
            description: "專注於價值投資的長期討論群組",
            memberCount: 25,
            hostName: "投資達人",
            performance: "+15.6%",
            performanceColor: .success,
            isJoined: true,
            onJoinTap: {},
            onItemTap: {}
        )
    }
    .padding()
}