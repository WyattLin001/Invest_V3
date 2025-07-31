//
//  EnhancedUIComponents.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  增強的 UI 組件 - 實現視覺層次、操作導向和用戶體驗改善
//

import SwiftUI

// MARK: - 增強的錢包餘額卡片
struct EnhancedWalletBalanceCard: View {
    let balance: Double
    let dailyChange: Double
    let onTopUpTap: () -> Void
    let onFriendsSearch: () -> Void
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 標題區域
            HStack {
                Text("錢包餘額")
                    .sectionTitleStyle()
                
                Spacer()
                
                // 好友按鈕
                Button(action: onFriendsSearch) {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("好友")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .brandButtonStyle(
                    backgroundColor: .brandBlue,
                    size: .small
                )
            }
            
            // 餘額顯示
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("\(Int(balance))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .adaptiveTextColor()
                        .monospacedDigit()
                    
                    Text("代幣")
                        .font(.subheadline)
                        .adaptiveTextColor(primary: false)
                }
                
                Spacer()
                
                // 充值按鈕
                Button("充值", action: onTopUpTap)
                    .iconButtonStyle(
                        icon: "plus.circle.fill",
                        backgroundColor: .success,
                        size: .medium
                    )
            }
            
            // 日變化顯示
            if dailyChange != 0 {
                HStack {
                    Text("今日變化")
                        .font(.caption)
                        .adaptiveTextColor(primary: false)
                    
                    Spacer()
                    
                    Text("\(dailyChange > 0 ? "+" : "")\(dailyChange, specifier: "%.1f") 代幣")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(dailyChange >= 0 ? .success : .danger)
                }
            }
        }
        .enhancedCardStyle()
    }
}

// MARK: - 增強的訂閱狀態卡片
struct EnhancedSubscriptionStatusCard: View {
    let isPremium: Bool
    let nextBillingDate: Date?
    let onUpgrade: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("訂閱狀態")
                .subsectionTitleStyle()
            
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Text(isPremium ? "專業會員" : "免費會員")
                            .statusTagStyle(
                                backgroundColor: isPremium ? .success : .warning,
                                foregroundColor: .white
                            )
                    }
                    
                    if let nextBilling = nextBillingDate {
                        Text("下次扣款日期：\(dateFormatter.string(from: nextBilling))")
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                    }
                }
                
                Spacer()
                
                if !isPremium {
                    Button("升級", action: onUpgrade)
                        .brandButtonStyle(
                            backgroundColor: .brandGreen,
                            size: .small
                        )
                }
            }
        }
        .enhancedCardStyle()
    }
}

// MARK: - 增強的交易記錄卡片
struct EnhancedTransactionHistoryCard: View {
    let transactions: [TransactionItem]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            // 標題和查看全部按鈕
            HStack {
                Text("最近交易")
                    .subsectionTitleStyle()
                
                Spacer()
                
                Button("查看全部", action: onViewAll)
                    .secondaryButtonStyle(
                        borderColor: .brandBlue,
                        foregroundColor: .brandBlue,
                        size: .small
                    )
            }
            
            // 交易列表
            if transactions.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: DesignTokens.listItemSpacing) {
                    ForEach(transactions.prefix(5), id: \.id) { transaction in
                        transactionRow(transaction)
                    }
                }
            }
        }
        .enhancedCardStyle()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundColor(.textTertiary)
            
            Text("暫無交易記錄")
                .font(.subheadline)
                .disabledStyle()
            
            Text("完成首次交易後，記錄會顯示在這裡")
                .font(.caption)
                .secondaryContentStyle()
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.spacingLG)
    }
    
    private func transactionRow(_ transaction: TransactionItem) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // 交易類型圖標
            Image(systemName: transaction.iconName)
                .font(.title3)
                .foregroundColor(transaction.isPositive ? .success : .danger)
                .frame(width: 24, height: 24)
            
            // 交易信息
            VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                Text(transaction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .adaptiveTextColor()
                
                Text(transaction.subtitle)
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
            }
            
            Spacer()
            
            // 金額和時間
            VStack(alignment: .trailing, spacing: DesignTokens.spacingXXS) {
                Text("\(transaction.isPositive ? "+" : "")\(transaction.amount, specifier: "%.0f") 代幣")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(transaction.isPositive ? .success : .danger)
                    .monospacedDigit()
                
                Text(formatTime(transaction.date))
                    .font(.caption2)
                    .adaptiveTextColor(primary: false)
            }
        }
        .padding(.vertical, DesignTokens.spacingXS)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 增強的設定區塊
struct EnhancedSettingsSection: View {
    let title: String
    let items: [SettingItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(title)
                .sectionTitleStyle()
            
            VStack(spacing: DesignTokens.spacingXS) {
                ForEach(items, id: \.id) { item in
                    settingRow(item)
                    
                    if item.id != items.last?.id {
                        Divider()
                            .background(DesignTokens.dividerColor)
                    }
                }
            }
        }
        .enhancedCardStyle()
    }
    
    private func settingRow(_ item: SettingItem) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // 圖標
            if let iconName = item.iconName {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(item.iconColor ?? .brandBlue)
                    .frame(width: 24, height: 24)
            }
            
            // 標題和描述
            VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                Text(item.title)
                    .font(.subheadline)
                    .adaptiveTextColor()
                
                if let description = item.description {
                    if item.isDisabled {
                        Text(description)
                            .infoTipStyle(
                                icon: "info.circle",
                                backgroundColor: .warning
                            )
                    } else {
                        Text(description)
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                    }
                }
            }
            
            Spacer()
            
            // 右側內容
            switch item.type {
            case .navigation:
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                    
            case .toggle(let isOn):
                Toggle("", isOn: .constant(isOn))
                    .tint(.brandGreen)
                    .disabled(item.isDisabled)
                    
            case .button(let title):
                Button(title) {
                    item.action?()
                }
                .brandButtonStyle(size: .small)
                .disabled(item.isDisabled)
                
            case .text(let value):
                Text(value)
                    .font(.subheadline)
                    .adaptiveTextColor(primary: false)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
        .contentShape(Rectangle())
        .onTapGesture {
            if !item.isDisabled {
                item.action?()
            }
        }
        .opacity(item.isDisabled ? 0.6 : 1)
    }
}

// MARK: - 增強的搜尋欄
struct EnhancedSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                
                TextField(placeholder, text: $text)
                    .font(.subheadline)
                    .submitLabel(.search)
                    .onSubmit {
                        onSearch()
                    }
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .searchFieldStyle()
            
            Button("搜尋", action: onSearch)
                .brandButtonStyle(size: .small)
        }
    }
}

// MARK: - 資料模型
struct TransactionItem {
    let id = UUID()
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date
    let isPositive: Bool
    
    var iconName: String {
        if title.contains("充值") || title.contains("贈送") {
            return "plus.circle.fill"
        } else if title.contains("購買") || title.contains("消費") {
            return "minus.circle.fill"
        } else {
            return "arrow.left.arrow.right.circle.fill"
        }
    }
}

struct SettingItem {
    let id = UUID()
    let title: String
    let description: String?
    let iconName: String?
    let iconColor: Color?
    let type: SettingItemType
    let isDisabled: Bool
    let action: (() -> Void)?
    
    init(
        title: String,
        description: String? = nil,
        iconName: String? = nil,
        iconColor: Color? = nil,
        type: SettingItemType,
        isDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.iconName = iconName
        self.iconColor = iconColor
        self.type = type
        self.isDisabled = isDisabled
        self.action = action
    }
}

enum SettingItemType {
    case navigation
    case toggle(Bool)
    case button(String)
    case text(String)
}

// MARK: - 預覽
#Preview("增強錢包卡片") {
    VStack(spacing: DesignTokens.sectionSpacing) {
        EnhancedWalletBalanceCard(
            balance: 10070,
            dailyChange: -15,
            onTopUpTap: {},
            onFriendsSearch: {}
        )
        
        EnhancedSubscriptionStatusCard(
            isPremium: false,
            nextBillingDate: Date(),
            onUpgrade: {}
        )
        
        EnhancedTransactionHistoryCard(
            transactions: [
                TransactionItem(
                    title: "抖內禮物",
                    subtitle: "抖內禮物",
                    amount: -40,
                    date: Date(),
                    isPositive: false
                ),
                TransactionItem(
                    title: "系統充值",
                    subtitle: "帳戶充值",
                    amount: 1000,
                    date: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                    isPositive: true
                )
            ],
            onViewAll: {}
        )
    }
    .padding()
    .background(Color.surfaceGrouped)
}

#Preview("增強設定區塊") {
    EnhancedSettingsSection(
        title: "好友管理",
        items: [
            SettingItem(
                title: "新增好友",
                description: "搜尋 ID 或掃描 QR Code",
                iconName: "person.badge.plus",
                iconColor: .brandGreen,
                type: .button("添加")
            ),
            SettingItem(
                title: "好友功能",
                description: "好友功能暫時不可用",
                iconName: "person.2",
                iconColor: .warning,
                type: .navigation,
                isDisabled: true
            )
        ]
    )
    .padding()
    .background(Color.surfaceGrouped)
}