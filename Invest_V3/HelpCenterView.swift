//
//  HelpCenterView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/9.
//

import SwiftUI

struct HelpCenterView: View {
    @State private var searchText = ""
    @State private var showFAQ = false
    @State private var selectedFAQCategory: FAQCategory? = nil
    @State private var showTutorial = false
    @State private var showContactSupport = false
    @State private var showReportIssue = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    welcomeHeader
                    quickActionsGrid
                    helpCategoriesSection
                    recentUpdatesSection
                    contactSupportSection
                }
                .padding(DesignTokens.spacingMD)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("幫助中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .fullScreenCover(isPresented: $showFAQ) {
            FAQView(initialCategory: selectedFAQCategory)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView()
        }
        .fullScreenCover(isPresented: $showContactSupport) {
            ContactSupportView()
        }
        .fullScreenCover(isPresented: $showReportIssue) {
            ReportIssueView()
        }
    }
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.brandGreen)
                
                Text("需要幫助嗎？")
                    .font(DesignTokens.titleMedium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text("找到您需要的答案，快速解決問題")
                .font(DesignTokens.bodyText)
                .foregroundColor(.secondary)
        }
        .padding(DesignTokens.spacingMD)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.brandGreen.opacity(0.05),
                    Color.brandGreen.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignTokens.cornerRadiusLG)
    }
    
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("快速幫助")
                .font(DesignTokens.sectionHeader)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.spacingSM), count: 2), spacing: DesignTokens.spacingSM) {
                QuickActionCard(
                    icon: "doc.text.magnifyingglass",
                    title: "常見問題",
                    subtitle: "查看完整FAQ",
                    color: .brandGreen
                ) {
                    showFAQ = true
                }
                
                QuickActionCard(
                    icon: "phone.circle",
                    title: "聯繫支援",
                    subtitle: "專人協助",
                    color: .brandBlue
                ) {
                    showContactSupport = true
                }
                
                QuickActionCard(
                    icon: "play.circle",
                    title: "使用教學",
                    subtitle: "功能介紹",
                    color: .brandBlue
                ) {
                    showTutorial = true
                }
                
                QuickActionCard(
                    icon: "exclamationmark.triangle",
                    title: "回報問題",
                    subtitle: "技術支援",
                    color: .brandOrange
                ) {
                    showReportIssue = true
                }
            }
        }
    }
    
    private var helpCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("幫助分類")
                .font(DesignTokens.sectionHeader)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingXS) {
                HelpCategoryRow(
                    icon: "person.circle",
                    title: "帳戶管理",
                    description: "註冊、登入、個人資料設定",
                    action: { showFAQWithCategory(.security) }
                )
                
                HelpCategoryRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "投資交易",
                    description: "買賣股票、投資組合管理",
                    action: { showFAQWithCategory(.trading) }
                )
                
                HelpCategoryRow(
                    icon: "trophy",
                    title: "錦標賽競技",
                    description: "參加比賽、排行榜說明",
                    action: { showFAQWithCategory(.tournament) }
                )
                
                HelpCategoryRow(
                    icon: "creditcard",
                    title: "錢包支付",
                    description: "充值、提現、交易記錄",
                    action: { showFAQWithCategory(.wallet) }
                )
                
                HelpCategoryRow(
                    icon: "bubble.left.and.bubble.right",
                    title: "社群功能",
                    description: "聊天群組、關注專家",
                    action: { showFAQWithCategory(.social) }
                )
            }
        }
    }
    
    private var recentUpdatesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("最新更新")
                .font(DesignTokens.sectionHeader)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingXS) {
                UpdateItemRow(
                    title: "新增錦標賽功能說明",
                    date: "2025/08/01",
                    isNew: true
                )
                
                UpdateItemRow(
                    title: "錢包操作指南更新",
                    date: "2025/07/25",
                    isNew: false
                )
                
                UpdateItemRow(
                    title: "投資交易FAQ擴充",
                    date: "2025/07/20",
                    isNew: false
                )
            }
        }
    }
    
    private var contactSupportSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("聯繫我們")
                .font(DesignTokens.sectionHeader)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingSM) {
                HelpContactMethodRow(
                    icon: "envelope",
                    title: "客服信箱",
                    detail: "support@invest-v3.com",
                    action: { openEmail() }
                )
                
                HelpContactMethodRow(
                    icon: "message",
                    title: "線上客服",
                    detail: "週一至週五 9:00-18:00",
                    action: { openChat() }
                )
                
                HelpContactMethodRow(
                    icon: "phone",
                    title: "客服專線",
                    detail: "0800-123-456",
                    action: { callSupport() }
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func showFAQWithCategory(_ category: FAQCategory) {
        // 設定要顯示的分類並開啟 FAQ
        selectedFAQCategory = category
        showFAQ = true
    }
    
    private func openEmail() {
        if let url = URL(string: "mailto:support@invest-v3.com") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openChat() {
        // 開啟線上客服
        showContactSupport = true
    }
    
    private func callSupport() {
        if let url = URL(string: "tel://0800123456") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.spacingSM) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.15), color.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(spacing: DesignTokens.spacingXXS) {
                    Text(title)
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(DesignTokens.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.spacingMD)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(DesignTokens.cornerRadiusLG)
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HelpCategoryRow: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.brandGreen)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                    Text(title)
                        .font(DesignTokens.bodyMedium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(DesignTokens.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(DesignTokens.spacingSM)
            .background(Color(.systemBackground))
            .cornerRadius(DesignTokens.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UpdateItemRow: View {
    let title: String
    let date: String
    let isNew: Bool
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                HStack {
                    Text(title)
                        .font(DesignTokens.bodyMedium)
                        .foregroundColor(.primary)
                    
                    if isNew {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandOrange)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(date)
                    .font(DesignTokens.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
    }
}

struct HelpContactMethodRow: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.brandGreen)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                    Text(title)
                        .font(DesignTokens.bodyMedium)
                        .foregroundColor(.primary)
                    
                    Text(detail)
                        .font(DesignTokens.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(DesignTokens.spacingSM)
            .background(Color(.systemBackground))
            .cornerRadius(DesignTokens.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HelpCenterView()
}