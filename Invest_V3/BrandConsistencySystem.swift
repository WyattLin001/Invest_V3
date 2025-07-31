//
//  BrandConsistencySystem.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  品牌一致性系統 - 統一圖標風格、語言風格和視覺品牌
//

import SwiftUI

// MARK: - 品牌圖標系統
enum BrandIcons {
    // 投資相關
    case portfolio
    case trading
    case analysis
    case performance
    case risk
    case achievement
    
    // 社交相關
    case friends
    case chat
    case notification
    case search
    case share
    
    // 錢包相關
    case wallet
    case topup
    case transaction
    case subscription
    case payment
    
    // 設定相關
    case settings
    case profile
    case security
    case help
    case about
    
    // 狀態相關
    case success
    case warning
    case error
    case info
    case loading
    
    var systemName: String {
        switch self {
        // 投資相關
        case .portfolio: return "briefcase.fill"
        case .trading: return "chart.line.uptrend.xyaxis"
        case .analysis: return "chart.bar.doc.horizontal"
        case .performance: return "chart.bar.fill"
        case .risk: return "exclamationmark.triangle.fill"
        case .achievement: return "star.fill"
            
        // 社交相關
        case .friends: return "person.2.fill"
        case .chat: return "message.fill"
        case .notification: return "bell.fill"
        case .search: return "magnifyingglass"
        case .share: return "square.and.arrow.up"
            
        // 錢包相關
        case .wallet: return "creditcard.fill"
        case .topup: return "plus.circle.fill"
        case .transaction: return "arrow.left.arrow.right.circle.fill"
        case .subscription: return "crown.fill"
        case .payment: return "dollarsign.circle.fill"
            
        // 設定相關
        case .settings: return "gearshape.fill"
        case .profile: return "person.crop.circle.fill"
        case .security: return "lock.shield.fill"
        case .help: return "questionmark.circle.fill"
        case .about: return "info.circle.fill"
            
        // 狀態相關
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .loading: return "arrow.clockwise"
        }
    }
    
    var defaultColor: Color {
        switch self {
        // 投資相關
        case .portfolio: return .brandBlue
        case .trading: return .brandGreen
        case .analysis: return .brandBlue
        case .performance: return .success
        case .risk: return .warning
        case .achievement: return .brandGold
            
        // 社交相關
        case .friends: return .brandGreen
        case .chat: return .brandBlue
        case .notification: return .danger
        case .search: return .textSecondary
        case .share: return .brandBlue
            
        // 錢包相關
        case .wallet: return .brandGreen
        case .topup: return .success
        case .transaction: return .brandBlue
        case .subscription: return .brandGold
        case .payment: return .success
            
        // 設定相關
        case .settings: return .textSecondary
        case .profile: return .brandGreen
        case .security: return .brandOrange
        case .help: return .info
        case .about: return .info
            
        // 狀態相關
        case .success: return .success
        case .warning: return .warning
        case .error: return .danger
        case .info: return .info
        case .loading: return .brandBlue
        }
    }
}

// MARK: - 統一的圖標視圖
struct BrandIcon: View {
    let icon: BrandIcons
    let size: IconSize
    let color: Color?
    
    init(_ icon: BrandIcons, size: IconSize = .medium, color: Color? = nil) {
        self.icon = icon
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Image(systemName: icon.systemName)
            .font(size.font)
            .foregroundColor(color ?? icon.defaultColor)
            .frame(width: size.dimension, height: size.dimension)
    }
}

// MARK: - 圖標尺寸系統
enum IconSize {
    case small
    case medium
    case large
    case xlarge
    
    var font: Font {
        switch self {
        case .small: return .system(size: 16, weight: .medium)
        case .medium: return .system(size: 20, weight: .medium)
        case .large: return .system(size: 24, weight: .medium)
        case .xlarge: return .system(size: 32, weight: .medium)
        }
    }
    
    var dimension: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        case .xlarge: return 32
        }
    }
}

// MARK: - 語言風格系統
enum BrandVoice {
    /// 獲取統一的用詞
    static func getText(for key: TextKey) -> String {
        return key.text
    }
}

enum TextKey {
    // 通用操作
    case confirm
    case cancel
    case save
    case delete
    case edit
    case add
    case search
    case filter
    case refresh
    case loading
    
    // 投資相關
    case portfolio
    case trading
    case investment
    case performance
    case returns
    case risk
    case analysis
    
    // 金融數據
    case totalAssets
    case dailyChange
    case totalReturn
    case annualizedReturn
    case maxDrawdown
    case sharpeRatio
    case winRate
    case volatility
    
    // 社交功能
    case friends
    case addFriend
    case searchFriend
    case chatGroup
    case notification
    case share
    case follow
    
    // 錢包功能
    case wallet
    case balance
    case topUp
    case transaction
    case subscription
    case payment
    case premium
    
    // 狀態訊息
    case success
    case error
    case warning
    case info
    case loading_data
    case no_data
    case network_error
    case feature_disabled
    
    var text: String {
        switch self {
        // 通用操作
        case .confirm: return "確認"
        case .cancel: return "取消"
        case .save: return "儲存"
        case .delete: return "刪除"
        case .edit: return "編輯"
        case .add: return "新增"
        case .search: return "搜尋"
        case .filter: return "篩選"
        case .refresh: return "重新整理"
        case .loading: return "載入中..."
            
        // 投資相關
        case .portfolio: return "投資組合"
        case .trading: return "交易"
        case .investment: return "投資"
        case .performance: return "績效"
        case .returns: return "報酬"
        case .risk: return "風險"
        case .analysis: return "分析"
            
        // 金融數據
        case .totalAssets: return "總資產"
        case .dailyChange: return "今日變化"
        case .totalReturn: return "總報酬率"
        case .annualizedReturn: return "年化報酬率"
        case .maxDrawdown: return "最大回撤"
        case .sharpeRatio: return "夏普比率"
        case .winRate: return "勝率"
        case .volatility: return "波動率"
            
        // 社交功能
        case .friends: return "好友"
        case .addFriend: return "新增好友"
        case .searchFriend: return "搜尋好友"
        case .chatGroup: return "聊天群組"
        case .notification: return "通知"
        case .share: return "分享"
        case .follow: return "追蹤"
            
        // 錢包功能
        case .wallet: return "錢包"
        case .balance: return "餘額"
        case .topUp: return "儲值"
        case .transaction: return "交易紀錄"
        case .subscription: return "訂閱"
        case .payment: return "付款"
        case .premium: return "專業會員"
            
        // 狀態訊息
        case .success: return "操作成功"
        case .error: return "操作失敗"
        case .warning: return "注意"
        case .info: return "提示"
        case .loading_data: return "正在載入資料..."
        case .no_data: return "暫無資料"
        case .network_error: return "網路連線錯誤"
        case .feature_disabled: return "功能暫時不可用"
        }
    }
}

// MARK: - 品牌頭像系統
struct BrandAvatar: View {
    let image: UIImage?
    let placeholder: String
    let size: AvatarSize
    let backgroundColor: Color
    
    init(
        image: UIImage? = nil,
        placeholder: String = "投",
        size: AvatarSize = .medium,
        backgroundColor: Color = .brandGreen
    ) {
        self.image = image
        self.placeholder = placeholder
        self.size = size
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                    
                    Text(placeholder)
                        .font(size.placeholderFont)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    ThemeManager.shared.isDarkMode ? DesignTokens.borderColor : Color.clear,
                    lineWidth: ThemeManager.shared.isDarkMode ? 1 : 0
                )
        )
    }
}

// MARK: - 頭像尺寸系統
enum AvatarSize {
    case small
    case medium
    case large
    case xlarge
    
    var dimension: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 48
        case .large: return 64
        case .xlarge: return 96
        }
    }
    
    var placeholderFont: Font {
        switch self {
        case .small: return .system(size: 14, weight: .bold)
        case .medium: return .system(size: 20, weight: .bold)
        case .large: return .system(size: 28, weight: .bold)
        case .xlarge: return .system(size: 40, weight: .bold)
        }
    }
}

// MARK: - 品牌徽章系統
struct BrandBadge: View {
    let text: String
    let style: BadgeStyle
    let size: BadgeSize
    
    init(_ text: String, style: BadgeStyle = .primary, size: BadgeSize = .medium) {
        self.text = text
        self.style = style
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(size.font)
            .fontWeight(.medium)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(size.cornerRadius)
    }
}

enum BadgeStyle {
    case primary
    case success
    case warning
    case danger
    case info
    case secondary
    
    var backgroundColor: Color {
        switch self {
        case .primary: return .brandGreen
        case .success: return .success
        case .warning: return .warning
        case .danger: return .danger
        case .info: return .info
        case .secondary: return .textSecondary
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .success, .danger, .info, .secondary: return .white
        case .warning: return .black
        }
    }
}

enum BadgeSize {
    case small
    case medium
    case large
    
    var font: Font {
        switch self {
        case .small: return .system(size: 10, weight: .medium)
        case .medium: return .system(size: 12, weight: .medium)
        case .large: return .system(size: 14, weight: .medium)
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 4
        case .large: return 6
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }
}

// MARK: - 動畫系統
struct BrandAnimations {
    /// 標準彈性動畫
    static let standardSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    /// 快速淡入淡出
    static let quickFade = Animation.easeInOut(duration: 0.2)
    
    /// 標準過渡動畫
    static let standardTransition = Animation.easeInOut(duration: 0.3)
    
    /// 載入動畫
    static let loading = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
    
    /// 按鈕按下回饋
    static let buttonPress = Animation.easeInOut(duration: 0.1)
}

// MARK: - 預覽
#Preview("品牌圖標") {
    VStack(spacing: DesignTokens.spacingLG) {
        // 投資相關圖標
        HStack(spacing: DesignTokens.spacingMD) {
            BrandIcon(.portfolio, size: .large)
            BrandIcon(.trading, size: .large)
            BrandIcon(.analysis, size: .large)
            BrandIcon(.performance, size: .large)
        }
        
        // 社交功能圖標
        HStack(spacing: DesignTokens.spacingMD) {
            BrandIcon(.friends, size: .large)
            BrandIcon(.chat, size: .large)
            BrandIcon(.notification, size: .large)
            BrandIcon(.search, size: .large)
        }
        
        // 錢包功能圖標
        HStack(spacing: DesignTokens.spacingMD) {
            BrandIcon(.wallet, size: .large)
            BrandIcon(.topup, size: .large)
            BrandIcon(.transaction, size: .large)
            BrandIcon(.subscription, size: .large)
        }
    }
    .padding()
}

#Preview("品牌頭像") {
    HStack(spacing: DesignTokens.spacingLG) {
        BrandAvatar(size: .small)
        BrandAvatar(size: .medium)
        BrandAvatar(size: .large)
        BrandAvatar(size: .xlarge)
    }
    .padding()
}

#Preview("品牌徽章") {
    VStack(spacing: DesignTokens.spacingMD) {
        HStack(spacing: DesignTokens.spacingMD) {
            BrandBadge("專業會員", style: .primary)
            BrandBadge("已驗證", style: .success)
            BrandBadge("注意", style: .warning)
        }
        
        HStack(spacing: DesignTokens.spacingMD) {
            BrandBadge("錯誤", style: .danger)
            BrandBadge("資訊", style: .info)
            BrandBadge("次要", style: .secondary)
        }
    }
    .padding()
}