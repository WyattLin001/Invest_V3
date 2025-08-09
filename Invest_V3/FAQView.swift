//
//  FAQView.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/8/6.
//

import SwiftUI

// MARK: - FAQ數據模型
struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let category: FAQCategory
}

enum FAQCategory: String, CaseIterable {
    case popular = "熱門問題"
    case quickStart = "新手入門"
    case general = "一般問題"
    case trading = "投資交易"
    case tournament = "錦標賽競技"
    case social = "社群互動"
    case earnings = "收益系統"
    case wallet = "錢包支付"
    case security = "帳戶安全"
    case technical = "技術問題"
    
    var icon: String {
        switch self {
        case .popular:
            return "flame.fill"
        case .quickStart:
            return "play.circle"
        case .general:
            return "questionmark.circle"
        case .trading:
            return "chart.line.uptrend.xyaxis"
        case .tournament:
            return "trophy.fill"
        case .social:
            return "person.2"
        case .earnings:
            return "dollarsign.circle"
        case .wallet:
            return "creditcard.fill"
        case .security:
            return "lock.shield"
        case .technical:
            return "wrench.and.screwdriver"
        }
    }
    
    var color: Color {
        switch self {
        case .popular:
            return .orange
        case .quickStart:
            return .brandGreen
        case .general:
            return .blue
        case .trading:
            return .green
        case .tournament:
            return .yellow
        case .social:
            return .purple
        case .earnings:
            return .mint
        case .wallet:
            return .indigo
        case .security:
            return .red
        case .technical:
            return .gray
        }
    }
}

struct FAQView: View {
    let initialCategory: FAQCategory?
    
    @State private var selectedCategory: FAQCategory = .popular
    @State private var searchText = ""
    @State private var expandedItems: Set<UUID> = []
    @State private var showContactSupport = false
    @State private var recentSearches: [String] = []
    @State private var recommendedQuestions: [FAQItem] = []
    @State private var searchSuggestions: [String] = []
    @State private var showSearchSuggestions = false
    
    // 初始化器，支援預設分類
    init(initialCategory: FAQCategory? = nil) {
        self.initialCategory = initialCategory
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                topNavigationBar
                
                // 主要內容
                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {
                        // 歡迎橫幅
                        welcomeBanner
                        
                        // 快速解決方案
                        quickSolutionsSection
                        
                        // 搜尋框
                        smartSearchSection
                        
                        // 分類篩選
                        categoryFilterSection
                        
                        // FAQ列表內容
                        faqContentSection
                        
                        // 底部聯繫支援
                        contactSupportSection
                    }
                    .padding(.bottom, DesignTokens.spacingXL)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView()
        }
        .onAppear {
            initializeRecommendations()
            
            // 如果有指定初始分類，設定為選中狀態
            if let initialCategory = initialCategory {
                selectedCategory = initialCategory
            }
        }
    }
    
    // MARK: - 頂部導航欄
    private var topNavigationBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("幫助中心")
                    .font(DesignTokens.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("快速找到您需要的答案")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showContactSupport = true
            }) {
                Image(systemName: "headphones.circle.fill")
                    .font(.title2)
                    .foregroundColor(.brandGreen)
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - 歡迎橫幅
    private var welcomeBanner: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("👋 需要幫助嗎？")
                    .font(DesignTokens.sectionHeader)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("我們為您準備了詳細的使用指南，讓您快速掌握股圈的所有功能。")
                    .font(DesignTokens.bodySmall)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
        }
        .padding(DesignTokens.spacingMD)
        .background(
            LinearGradient(
                colors: [.brandGreen.opacity(0.1), .blue.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(DesignTokens.cornerRadiusLG)
        .padding(.horizontal, DesignTokens.spacingMD)
    }
    
    // MARK: - 快速解決方案
    private var quickSolutionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text("🚀 快速解決")
                    .font(DesignTokens.sectionHeader)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignTokens.spacingMD) {
                QuickSolutionCard(
                    icon: "play.circle.fill",
                    title: "新手教學",
                    subtitle: "從零開始學習",
                    color: .brandGreen
                ) {
                    selectedCategory = .quickStart
                }
                
                QuickSolutionCard(
                    icon: "flame.fill", 
                    title: "熱門問題",
                    subtitle: "最常遇到的問題",
                    color: .orange
                ) {
                    selectedCategory = .popular
                }
                
                QuickSolutionCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "投資交易",
                    subtitle: "交易操作指南",
                    color: .green
                ) {
                    selectedCategory = .trading
                }
                
                QuickSolutionCard(
                    icon: "trophy.fill",
                    title: "錦標賽",
                    subtitle: "競賽玩法說明",
                    color: .yellow
                ) {
                    selectedCategory = .tournament
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
        }
    }
    
    // MARK: - 智能搜尋區段
    private var smartSearchSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("🔍 智能搜尋")
                    .font(DesignTokens.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !recentSearches.isEmpty {
                    Button("清除記錄") {
                        recentSearches.removeAll()
                        updateSearchSuggestions()
                    }
                    .font(DesignTokens.caption)
                    .foregroundColor(.brandGreen)
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            
            // 搜尋輸入框
            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                    
                    TextField("輸入關鍵字搜尋問題...", text: $searchText)
                        .font(DesignTokens.bodyText)
                        .submitLabel(.search)
                        .onChange(of: searchText) { _ in
                            updateSearchSuggestions()
                            showSearchSuggestions = !searchText.isEmpty
                        }
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            showSearchSuggestions = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(DesignTokens.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                        .stroke(searchText.isEmpty ? Color.clear : Color.brandGreen, lineWidth: 1)
                )
                
                // 搜尋建議下拉列表
                if showSearchSuggestions && !searchSuggestions.isEmpty {
                    searchSuggestionsDropdown
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            
            // 最近搜尋標籤
            if !recentSearches.isEmpty && searchText.isEmpty {
                recentSearchTags
            }
            
            // 推薦問題區塊
            if !recommendedQuestions.isEmpty && searchText.isEmpty {
                recommendedQuestionsSection
            }
        }
    }
    
    // MARK: - 搜尋建議下拉
    private var searchSuggestionsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchSuggestions.prefix(5), id: \.self) { suggestion in
                Button(action: {
                    searchText = suggestion
                    performSearch()
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(suggestion)
                            .font(DesignTokens.bodySmall)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(Color(.tertiaryLabel))
                            .font(.caption2)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion != searchSuggestions.last {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignTokens.cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 最近搜尋標籤
    private var recentSearchTags: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            HStack {
                Text("最近搜尋")
                    .font(DesignTokens.captionBold)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingXS) {
                    ForEach(recentSearches.prefix(8), id: \.self) { search in
                        Button(action: {
                            searchText = search
                            performSearch()
                        }) {
                            HStack(spacing: DesignTokens.spacingXXS) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                
                                Text(search)
                                    .font(DesignTokens.caption)
                            }
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .foregroundColor(.secondary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
            }
        }
    }
    
    // MARK: - 推薦問題區塊
    private var recommendedQuestionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("🎯 為您推薦")
                    .font(DesignTokens.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("更換推薦") {
                    refreshRecommendations()
                }
                .font(DesignTokens.caption)
                .foregroundColor(.brandGreen)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(recommendedQuestions.prefix(5)) { question in
                        RecommendedQuestionCard(question: question) {
                            // 展開該問題
                            if expandedItems.contains(question.id) {
                                expandedItems.remove(question.id)
                            } else {
                                expandedItems.insert(question.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
            }
        }
    }
    
    // MARK: - 分類篩選區段
    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            if searchText.isEmpty {
                HStack {
                    Text("📂 選擇分類")
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(FAQCategory.allCases, id: \.self) { category in
                            EnhancedCategoryChip(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.easeInOut(duration: DesignTokens.animationFast)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                }
            }
        }
    }
    
    // MARK: - FAQ 內容區段
    private var faqContentSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // 區段標題
            HStack {
                let title = searchText.isEmpty ? selectedCategory.rawValue : "搜尋結果"
                let count = filteredFAQs.count
                
                Text("\(title) (\(count))")
                    .font(DesignTokens.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            
            // FAQ 卡片列表
            if filteredFAQs.isEmpty {
                EmptySearchResultView(searchText: searchText)
            } else {
                LazyVStack(spacing: DesignTokens.spacingSM) {
                    ForEach(filteredFAQs) { faq in
                        EnhancedFAQCard(
                            faq: faq,
                            isExpanded: expandedItems.contains(faq.id),
                            searchText: searchText
                        ) {
                            toggleExpansion(for: faq.id)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
            }
        }
    }
    
    // MARK: - 聯繫支援區段
    private var contactSupportSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Text("🤝 還是找不到答案？")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("我們的客服團隊隨時準備為您提供幫助")
                .font(DesignTokens.bodySmall)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showContactSupport = true
            }) {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("聯繫客服")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.vertical, DesignTokens.spacingSM)
                .background(Color.brandGreen)
                .cornerRadius(DesignTokens.cornerRadius)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignTokens.cornerRadiusLG)
        .padding(.horizontal, DesignTokens.spacingMD)
    }
    
    // MARK: - 篩選邏輯
    private var filteredFAQs: [FAQItem] {
        if searchText.isEmpty {
            return faqData.filter { $0.category == selectedCategory }
        } else {
            // 搜尋時顯示所有匹配的結果，不限制分類
            return faqData.filter {
                $0.question.localizedCaseInsensitiveContains(searchText) ||
                $0.answer.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }.sorted { first, second in
                // 按照相關性排序：問題標題匹配優先於內容匹配
                let firstQuestionMatch = first.question.localizedCaseInsensitiveContains(searchText)
                let secondQuestionMatch = second.question.localizedCaseInsensitiveContains(searchText)
                
                if firstQuestionMatch && !secondQuestionMatch {
                    return true
                } else if !firstQuestionMatch && secondQuestionMatch {
                    return false
                } else {
                    return first.question.localizedCompare(second.question) == .orderedAscending
                }
            }
        }
    }
    
    // MARK: - 展開/收縮邏輯
    private func toggleExpansion(for id: UUID) {
        withAnimation(.easeInOut(duration: DesignTokens.animationNormal)) {
            if expandedItems.contains(id) {
                expandedItems.remove(id)
            } else {
                expandedItems.insert(id)
            }
        }
    }
}

// MARK: - 快速解決方案卡片
struct QuickSolutionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(DesignTokens.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.spacingMD)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(DesignTokens.cornerRadiusLG)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 增強分類標籤
struct EnhancedCategoryChip: View {
    let category: FAQCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? category.color : Color(.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : category.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - 增強 FAQ 卡片
struct EnhancedFAQCard: View {
    let faq: FAQItem
    let isExpanded: Bool
    let searchText: String
    let toggleAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 問題標題按鈕
            Button(action: toggleAction) {
                HStack(spacing: DesignTokens.spacingMD) {
                    // 分類圖示
                    ZStack {
                        Circle()
                            .fill(faq.category.color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: faq.category.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(faq.category.color)
                    }
                    
                    // 問題內容
                    VStack(alignment: .leading, spacing: 4) {
                        // 分類標籤
                        Text(faq.category.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(faq.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(faq.category.color.opacity(0.1))
                            .cornerRadius(4)
                        
                        // 問題標題（支援高亮搜尋關鍵字）
                        HighlightedText(
                            text: faq.question,
                            searchText: searchText,
                            font: DesignTokens.bodyMedium,
                            textColor: .primary,
                            highlightColor: .brandGreen
                        )
                        .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // 展開指示器
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(DesignTokens.spacingMD)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // 答案內容
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Divider()
                        .padding(.horizontal, DesignTokens.spacingMD)
                    
                    // 答案文字（支援高亮搜尋關鍵字）
                    HighlightedText(
                        text: faq.answer,
                        searchText: searchText,
                        font: DesignTokens.bodyText,
                        textColor: .secondary,
                        highlightColor: .brandGreen
                    )
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.bottom, DesignTokens.spacingMD)
                    
                    // 底部操作區
                    HStack {
                        Spacer()
                        
                        HStack(spacing: DesignTokens.spacingMD) {
                            // 有幫助按鈕
                            Button(action: {
                                // TODO: 記錄有幫助的反饋
                                print("FAQ 有幫助: \(faq.id)")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsup")
                                        .font(.caption)
                                    Text("有幫助")
                                        .font(.caption)
                                }
                                .foregroundColor(.brandGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brandGreen.opacity(0.1))
                                .cornerRadius(6)
                            }
                            
                            // 無幫助按鈕
                            Button(action: {
                                // TODO: 記錄無幫助的反饋
                                print("FAQ 無幫助: \(faq.id)")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsdown")
                                        .font(.caption)
                                    Text("無幫助")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.bottom, DesignTokens.spacingSM)
                }
                .background(Color(.systemBackground))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadiusLG)
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                .stroke(isExpanded ? faq.category.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - 高亮文字元件
struct HighlightedText: View {
    let text: String
    let searchText: String
    let font: Font
    let textColor: Color
    let highlightColor: Color
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(textColor)
        } else {
            let attributedString = highlightSearchText(in: text, searchText: searchText)
            Text(AttributedString(attributedString))
                .font(font)
        }
    }
    
    private func highlightSearchText(in text: String, searchText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // 設定基礎文字顏色
        attributedString.addAttribute(.foregroundColor, value: UIColor(textColor), range: range)
        
        // 高亮搜尋關鍵字
        let searchRange = (text.lowercased() as NSString).range(of: searchText.lowercased())
        if searchRange.location != NSNotFound {
            attributedString.addAttribute(.backgroundColor, value: UIColor(highlightColor.opacity(0.3)), range: searchRange)
            attributedString.addAttribute(.foregroundColor, value: UIColor(highlightColor), range: searchRange)
        }
        
        return attributedString
    }
}

// MARK: - 空搜尋結果視圖
struct EmptySearchResultView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text("找不到相關問題")
                    .font(DesignTokens.sectionHeader)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("沒有找到包含「\(searchText)」的問題")
                    .font(DesignTokens.bodyText)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text("建議您：")
                    .font(DesignTokens.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 檢查拼寫是否正確")
                    Text("• 嘗試使用不同的關鍵字")
                    Text("• 使用更簡短的搜尋詞")
                    Text("• 瀏覽不同的問題分類")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(DesignTokens.cornerRadius)
            }
        }
        .padding(DesignTokens.spacingXL)
    }
}

// MARK: - FAQ 聯繫支援視圖
struct FAQContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContactMethod: ContactMethod = .inApp
    @State private var message = ""
    @State private var userEmail = ""
    
    enum ContactMethod: String, CaseIterable {
        case inApp = "應用內客服"
        case email = "電子郵件"
        case phone = "客服專線"
        
        var icon: String {
            switch self {
            case .inApp: return "bubble.left.and.bubble.right.fill"
            case .email: return "envelope.fill"
            case .phone: return "phone.fill"
            }
        }
        
        var description: String {
            switch self {
            case .inApp: return "即時回覆，最快速的解決方案"
            case .email: return "24小時內回覆，適合詳細問題"
            case .phone: return "工作日 9:00-18:00，專業客服"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignTokens.spacingLG) {
                // 標題區域
                VStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.brandGreen)
                    
                    Text("聯繫客服")
                        .font(DesignTokens.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("我們隨時準備為您提供幫助")
                        .font(DesignTokens.bodyText)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignTokens.spacingLG)
                
                // 聯繫方式選擇
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Text("選擇聯繫方式")
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(ContactMethod.allCases, id: \.self) { method in
                        FAQContactMethodCard(
                            method: method,
                            isSelected: selectedContactMethod == method
                        ) {
                            selectedContactMethod = method
                        }
                    }
                }
                
                Spacer()
                
                // 底部按鈕
                VStack(spacing: DesignTokens.spacingSM) {
                    Button(action: {
                        // TODO: 處理聯繫客服邏輯
                        print("聯繫客服: \(selectedContactMethod.rawValue)")
                        dismiss()
                    }) {
                        Text("開始聯繫")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandGreen)
                            .cornerRadius(DesignTokens.cornerRadius)
                    }
                    
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(DesignTokens.spacingMD)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 聯繫方式卡片
struct FAQContactMethodCard: View {
    let method: FAQContactSupportView.ContactMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: method.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .brandGreen : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.brandGreen)
                }
            }
            .padding(DesignTokens.spacingMD)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(DesignTokens.cornerRadiusLG)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLG)
                    .stroke(isSelected ? Color.brandGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

    // MARK: - 智能搜尋輔助功能
    
    private func updateSearchSuggestions() {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            searchSuggestions = []
            return
        }
        
        // 生成搜尋建議
        let suggestions = Set<String>()
        var suggestionsArray: [String] = []
        
        // 從FAQ問題中提取關鍵詞
        for faq in faqData {
            let words = faq.question.lowercased().components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                if word.contains(query) && word.count > 1 && !suggestionsArray.contains(word) {
                    suggestionsArray.append(word)
                }
            }
        }
        
        // 添加常用搜尋詞
        let commonSearches = ["投資", "交易", "錦標賽", "錢包", "帳戶", "安全", "新手", "專家", "收益", "代幣"]
        for term in commonSearches {
            if term.lowercased().contains(query) && !suggestionsArray.contains(term) {
                suggestionsArray.append(term)
            }
        }
        
        searchSuggestions = Array(suggestionsArray.prefix(5))
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        // 添加到最近搜尋
        if !recentSearches.contains(searchText) {
            recentSearches.insert(searchText, at: 0)
            if recentSearches.count > 10 {
                recentSearches = Array(recentSearches.prefix(10))
            }
        }
        
        showSearchSuggestions = false
        
        // 觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func refreshRecommendations() {
        // 隨機選擇推薦問題
        let shuffledFAQ = faqData.shuffled()
        recommendedQuestions = Array(shuffledFAQ.prefix(6))
        
        // 觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func initializeRecommendations() {
        // 初始化推薦問題
        refreshRecommendations()
        
        // 初始化搜尋建議
        updateSearchSuggestions()
    }
}

// MARK: - 推薦問題卡片
struct RecommendedQuestionCard: View {
    let question: FAQItem
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: question.category.icon)
                    .foregroundColor(question.category.color)
                    .font(.title3)
                
                Spacer()
                
                Text(question.category.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(question.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(question.category.color.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(question.question)
                .font(DesignTokens.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            
            Text(question.answer.prefix(80) + "...")
                .font(DesignTokens.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Button("查看詳情") {
                action()
            }
            .font(DesignTokens.captionBold)
            .foregroundColor(.brandGreen)
        }
        .padding(DesignTokens.spacingSM)
        .frame(width: 200)
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - FAQ數據
private let faqData: [FAQItem] = [
    // 熱門問題
    FAQItem(
        question: "什麼是股圈？",
        answer: "股圈是台灣首創的投資知識分享平台，結合透明的模擬交易、專家分析文章，以及競技化的投資錦標賽。我們致力於解決台灣投資詐騙問題，為投資者提供可信賴的學習環境和專家指導。",
        category: .popular
    ),
    FAQItem(
        question: "如何開始使用股圈？",
        answer: "1. 下載並安裝 App\n2. 註冊您的帳號\n3. 完成身份驗證\n4. 瀏覽新手教學\n5. 開始模擬投資或加入錦標賽\n6. 關注感興趣的投資專家\n系統會提供 100 萬虛擬資金讓您練習投資。",
        category: .popular
    ),
    FAQItem(
        question: "投資組合數據是否即時更新？",
        answer: "是的！我們的投資組合數據每秒更新，提供即時的股價變動、損益計算和績效分析。所有數據都來自可靠的金融數據供應商，確保準確性和時效性。",
        category: .popular
    ),
    FAQItem(
        question: "如何參加投資錦標賽？",
        answer: "前往「錦標賽」頁面，選擇感興趣的比賽，點擊「立即參加」即可。每位參賽者都會獲得相同的虛擬資金，在規定時間內比拼投資技巧。排名靠前的參賽者可獲得豐厚獎勵。",
        category: .popular
    ),
    FAQItem(
        question: "股圈是否收費？",
        answer: "基本功能完全免費使用，包括模擬投資、參加錦標賽、閱讀免費文章等。付費功能包括 Premium 會員（專家諮詢、進階工具）、訂閱專家內容、購買代幣等，讓您享受更豐富的投資學習體驗。",
        category: .popular
    ),
    
    // 新手入門
    FAQItem(
        question: "我完全沒有投資經驗，該從哪裡開始？",
        answer: "歡迎加入投資世界！建議您：\n1. 先完成新手教學課程\n2. 閱讀基礎投資文章\n3. 用虛擬資金開始模擬投資\n4. 關注適合新手的投資專家\n5. 參加新手友善的錦標賽\n我們提供完整的學習路徑，讓您安全地學習投資。",
        category: .quickStart
    ),
    FAQItem(
        question: "如何註冊帳號？",
        answer: "註冊步驟：\n1. 點擊「開始使用」\n2. 選擇註冊方式（信箱或手機）\n3. 填寫基本資料\n4. 驗證信箱或手機號碼\n5. 設定安全密碼\n6. 完成個人檔案設定\n註冊完成後即可獲得 100 萬虛擬資金！",
        category: .quickStart
    ),
    FAQItem(
        question: "虛擬資金有什麼限制嗎？",
        answer: "虛擬資金專供學習使用，無任何金錢價值。每位用戶初始獲得 100 萬虛擬資金，用完後可申請重置。虛擬投資的所有損益都是模擬的，不涉及真實金錢交易。",
        category: .quickStart
    ),
    FAQItem(
        question: "如何查看我的投資績效？",
        answer: "在「首頁」的投資組合區塊可查看：\n• 總資產價值\n• 今日損益\n• 總報酬率\n• 各股票持股明細\n點擊「詳細分析」可查看更深入的績效報告，包括風險分析、歷史表現圖表等。",
        category: .quickStart
    ),
    FAQItem(
        question: "新手應該關注哪些投資專家？",
        answer: "建議新手關注標有「新手友善」標籤的專家，他們的內容通常：\n• 解釋概念清晰易懂\n• 提供基礎投資知識\n• 風險控制較為保守\n• 定期分享學習心得\n您可在「專家推薦」區域找到適合的投資導師。",
        category: .quickStart
    ),
    
    // 一般問題
    FAQItem(
        question: "如何修改個人資料？",
        answer: "進入「設定」→「個人資料」，可修改：\n• 頭像照片\n• 暱稱和簡介\n• 聯絡資訊\n• 投資偏好設定\n• 隱私設定\n修改後的資料會即時同步到您的公開檔案。",
        category: .general
    ),
    FAQItem(
        question: "如何變更通知設定？",
        answer: "前往「設定」→「通知設定」，可調整：\n• 投資提醒\n• 錦標賽通知\n• 專家文章推送\n• 社群互動通知\n• 系統公告\n您可以選擇關閉或調整通知頻率。",
        category: .general
    ),
    FAQItem(
        question: "支援哪些裝置？",
        answer: "目前支援：\n• iOS 14.0 以上版本\n• iPhone 和 iPad\n• 未來將支援 Android 版本\n建議使用最新版本的作業系統以獲得最佳使用體驗。",
        category: .general
    ),
    FAQItem(
        question: "如何邀請朋友加入？",
        answer: "在「設定」中找到「邀請朋友」功能：\n1. 分享您的專屬邀請碼\n2. 朋友使用邀請碼註冊\n3. 雙方都可獲得額外虛擬資金\n4. 解鎖好友對戰功能\n一起投資學習更有趣！",
        category: .general
    ),
    
    // 投資交易
    FAQItem(
        question: "如何搜尋和選擇股票？",
        answer: "使用搜尋功能：\n1. 輸入股票代號或公司名稱\n2. 瀏覽搜尋結果和基本資訊\n3. 查看技術分析圖表\n4. 閱讀相關新聞和分析\n5. 決定投資金額\n系統支援台股、美股等多個市場的股票搜尋。",
        category: .trading
    ),
    FAQItem(
        question: "買賣股票有手續費嗎？",
        answer: "模擬交易會收取模擬手續費，按實際券商標準計算（約 0.1425%），讓您體驗真實的交易成本。這有助於培養正確的投資成本概念，為未來真實投資做準備。",
        category: .trading
    ),
    FAQItem(
        question: "可以設定停損停利嗎？",
        answer: "當然可以！在下單時或持有股票期間，您可以設定：\n• 停損價位（虧損時自動賣出）\n• 停利價位（獲利時自動賣出）\n• 追蹤停損（隨價格上漲調整停損點）\n這些功能幫助您控制風險和鎖定獲利。",
        category: .trading
    ),
    FAQItem(
        question: "為什麼我的下單被拒絕？",
        answer: "可能原因：\n• 虛擬資金不足\n• 超出單一股票持股限制\n• 股票停牌或下市\n• 交易時間外下單\n• 價格超出漲跌幅限制\n系統會顯示具體拒絕原因，請檢查後重新下單。",
        category: .trading
    ),
    FAQItem(
        question: "如何查看交易紀錄？",
        answer: "在「交易紀錄」頁面可查看：\n• 所有買賣交易明細\n• 交易時間和價格\n• 手續費計算\n• 獲利損失統計\n• 可依時間和股票篩選\n完整的交易紀錄幫助您分析投資表現。",
        category: .trading
    ),
    
    // 錦標賽競技
    FAQItem(
        question: "錦標賽有哪些類型？",
        answer: "我們提供多種錦標賽：\n• 日賽（當日結算）\n• 週賽（一週期間）\n• 月賽（一個月期間）\n• 季賽（三個月期間）\n• 特殊主題賽（如ESG投資、科技股專場）\n不同類型適合不同投資風格的參賽者。",
        category: .tournament
    ),
    FAQItem(
        question: "錦標賽規則是什麼？",
        answer: "基本規則：\n• 所有參賽者獲得相同起始資金\n• 在規定時間內自由交易\n• 以總報酬率排名\n• 禁止使用違規策略\n• 遵循公平競爭原則\n詳細規則請查看各錦標賽說明。",
        category: .tournament
    ),
    FAQItem(
        question: "錦標賽獎勵有哪些？",
        answer: "豐富獎勵等您拿：\n• 🏆 冠軍證書和專屬徽章\n• 💰 平台代幣獎勵\n• 👑 專家認證資格\n• ⭐ 社群影響力加分\n• 🎯 特殊功能解鎖\n獎勵會根據錦標賽規模和等級調整。",
        category: .tournament
    ),
    FAQItem(
        question: "可以同時參加多個錦標賽嗎？",
        answer: "可以！您可以同時參加多個不同類型的錦標賽，每個錦標賽都有獨立的資金和排名。建議根據自己的時間和精力合理安排，避免過度分散注意力。",
        category: .tournament
    ),
    
    // 社群互動
    FAQItem(
        question: "如何關注投資專家？",
        answer: "在專家頁面點擊「關注」按鈕即可。關注後您將：\n• 即時收到專家發文通知\n• 獲得文章發布優先閱讀權\n• 參與專家互動活動\n• 查看專家投資組合（如公開）\n• 加入專家粉絲社群",
        category: .social
    ),
    FAQItem(
        question: "如何參與討論和留言？",
        answer: "在文章下方留言區可以：\n• 發表投資見解和疑問\n• 回覆其他讀者留言\n• 點讚優質評論\n• 分享相關投資經驗\n請遵守社群規範，保持理性討論。",
        category: .social
    ),
    FAQItem(
        question: "可以私訊其他用戶嗎？",
        answer: "為維護用戶隱私和安全，目前不開放私訊功能。建議在公開討論區交流投資心得，這樣更多人可以受益於您的分享，也能獲得更多專業建議。",
        category: .social
    ),
    FAQItem(
        question: "如何舉報不當內容？",
        answer: "如發現違規內容，請：\n1. 點擊內容右上角的「⋯」選單\n2. 選擇「舉報」\n3. 選擇舉報原因\n4. 提供詳細說明\n我們會在24小時內處理，感謝您維護社群環境。",
        category: .social
    ),
    
    // 收益系統
    FAQItem(
        question: "如何成為內容創作者？",
        answer: "申請創作者資格：\n1. 完成身份認證\n2. 投資經驗達標（至少3個月）\n3. 投資績效表現良好\n4. 通過創作能力評估\n5. 同意創作者規範\n成功後可發布付費內容並獲得收益分潤。",
        category: .earnings
    ),
    FAQItem(
        question: "創作者收益如何計算？",
        answer: "收益來源包括：\n• 付費文章閱讀分潤（70%）\n• 專家諮詢服務費用\n• 錦標賽指導收入\n• 讀者打賞和支持\n• 平台推廣獎勵\n每月結算，次月發放到您的錢包。",
        category: .earnings
    ),
    FAQItem(
        question: "如何提升內容品質？",
        answer: "建議方向：\n• 深度分析取代表面資訊\n• 提供具體投資邏輯\n• 定期更新追蹤報告\n• 互動回應讀者問題\n• 分享失敗經驗和教訓\n高品質內容會獲得更多曝光和收益。",
        category: .earnings
    ),
    
    // 💰 創作者賺錢機制詳解
    FAQItem(
        question: "創作者具體如何賺錢？有哪些收入來源？",
        answer: "💰 創作者收入來源非常多元，讓您的專業知識真正變現：\n\n🔥 主要收入來源：\n• 付費文章收益（分潤70%，平台僅收30%）\n• 專家諮詢1對1服務（時薪300-2000元）\n• 投資群組月費收入（每人99-499元）\n• 錦標賽指導費用（學員報名費分潤）\n• 讀者打賞收入（100%歸創作者）\n\n💎 進階收入來源：\n• 平台推廣分潤（推薦新用戶獲得20%終身分潤）\n• 優質內容獎勵金（月度最佳創作者額外獎金）\n• 品牌合作收入（平台媒合優質廠商）\n• 課程授權收入（製作系列教學課程）\n\n📈 頂級創作者月收入可達10萬元以上！",
        category: .earnings
    ),
    FAQItem(
        question: "創作者提現門檻是什麼？為什麼要設置門檻？",
        answer: "💳 提現門檻政策：\n\n📊 門檻標準：\n• 最低提現金額：NT$ 1,000元\n• 帳戶驗證：完成實名認證\n• 內容要求：至少發布10篇優質文章\n• 好評率：讀者好評率需達80%以上\n• 活躍度：近30天內至少活躍15天\n\n🎯 設置門檻的重要原因：\n✅ 確保內容品質：防止低品質內容氾濫\n✅ 保護讀者權益：確保付費內容有價值\n✅ 激勵持續創作：鼓勵長期優質貢獻\n✅ 打擊詐騙行為：避免一次性詐騙後消失\n✅ 提升平台信譽：維護專業投資平台形象\n\n💰 門檻達成後，每週二統一撥款，手續費平台吸收！",
        category: .earnings
    ),
    FAQItem(
        question: "如何申請提現？提現流程是什麼？",
        answer: "💸 提現流程超簡單，3步驟完成：\n\n📝 第一步：準備提現\n• 進入「收益管理」頁面\n• 確認可提現金額（已扣除稅金）\n• 檢查是否符合提現門檻\n\n🏦 第二步：填寫提現資料\n• 選擇提現方式（銀行轉帳/電子錢包）\n• 輸入銀行帳戶資訊\n• 填寫提現金額（最低1,000元）\n• 確認收款人身份與實名認證一致\n\n✅ 第三步：等待審核撥款\n• 系統自動審核（通常2小時內）\n• 每週二統一撥款\n• 簡訊通知撥款完成\n• 可在「提現記錄」查看明細\n\n⚡ 緊急提現：VIP創作者可申請24小時快速提現（手續費20元）",
        category: .earnings
    ),
    FAQItem(
        question: "創作者收益如何計算稅金？平台如何協助處理？",
        answer: "📊 稅務處理說明：\n\n💰 收益計算方式：\n• 月收入20萬以下：免扣繳稅款\n• 月收入20萬以上：依法扣繳10%所得稅\n• 平台自動計算，無需手動處理\n• 年底提供扣繳憑單供報稅使用\n\n📄 平台協助服務：\n• 自動產生收入明細報表\n• 提供扣繳憑單下載\n• 稅務諮詢服務（合作會計師）\n• 協助申報個人所得稅\n• 提供合法節稅建議\n\n🎯 建議創作者開立工作室：\n• 可享更多稅務優惠\n• 平台提供開業諮詢服務\n• 協助媒合專業會計師",
        category: .earnings
    ),
    FAQItem(
        question: "平台如何鼓勵優質內容？有什麼獎勵機制？",
        answer: "🏆 平台超強獎勵機制，讓好內容獲得應有回報：\n\n🔥 內容品質獎勵：\n• 每月最佳文章獎：10,000元獎金\n• 讀者最愛獎：根據按讚數和分享數給獎\n• 新人創作獎：新創作者首月額外20%分潤\n• 持續創作獎：連續創作3個月獲得獎勵金\n\n📈 流量成長獎勵：\n• 文章閱讀量破萬：獎勵金1,000元\n• 新增粉絲達標：每100個新粉絲獎勵200元\n• 互動率提升：留言和討論活躍度獎勵\n\n👑 頂級創作者特權：\n• 首頁推薦位置優先權\n• 平台官方宣傳資源\n• 品牌合作優先媒合\n• VIP客服專線支援\n• 獨家功能搶先體驗\n\n💎 年度創作者大獎：\n• 年度最佳創作者：100,000元大獎\n• 最具影響力獎：50,000元\n• 最佳新人獎：30,000元\n\n🎯 目標：讓每位認真創作的專家都能獲得豐厚回報！",
        category: .earnings
    ),
    FAQItem(
        question: "為什麼要選擇在我們平台創作？與其他平台比較有什麼優勢？",
        answer: "🚀 選擇我們平台的超強理由：\n\n💰 收益分潤業界最高：\n• 我們：創作者分潤70%\n• 其他平台：通常只有40-60%\n• 提現門檻合理，不會卡住您的錢\n• 沒有隱藏費用，透明計費\n\n🎯 專業投資領域專精：\n• 讀者都是真正想學投資的人\n• 不像一般平台內容雜亂\n• 專業用戶付費意願更高\n• 建立專業權威形象更容易\n\n🔧 創作工具超強大：\n• 專業圖表製作工具\n• 股票資料自動整合\n• 投資組合即時追蹤\n• 模擬交易結果展示\n\n👥 社群互動品質高：\n• 嚴格審核機制，杜絕酸民\n• 讀者素質高，提問有深度\n• 建立長期師生關係\n• 真正的投資學習社群\n\n🏆 平台持續成長：\n• 用戶數快速增長中\n• 積極推廣優質創作者\n• 不斷優化功能和體驗\n• 未來有IPO計畫，創作者可參與股權分享\n\n加入我們，讓您的投資專業真正變現！",
        category: .earnings
    ),
    
    // 錢包支付
    FAQItem(
        question: "如何購買平台代幣？",
        answer: "購買步驟：\n1. 進入「錢包」頁面\n2. 選擇「購買代幣」\n3. 選擇購買方案\n4. 選擇支付方式（信用卡、Apple Pay等）\n5. 確認付款\n代幣可用於付費內容、專家諮詢等服務。",
        category: .wallet
    ),
    FAQItem(
        question: "代幣可以退款嗎？",
        answer: "已購買的代幣原則上不可退款，但以下情況例外：\n• 系統錯誤導致的重複扣款\n• 付款後未收到代幣\n• 平台服務故障\n如有爭議，請聯繫客服處理。",
        category: .wallet
    ),
    FAQItem(
        question: "如何使用代幣？",
        answer: "代幣用途：\n• 購買付費文章和報告\n• 預約專家一對一諮詢\n• 參與高級錦標賽\n• 解鎖進階分析工具\n• 購買虛擬禮物支持創作者\n餘額不足時系統會提醒您儲值。",
        category: .wallet
    ),
    
    // 帳戶安全
    FAQItem(
        question: "如何保護帳戶安全？",
        answer: "安全建議：\n• 設定複雜密碼（至少8位，包含數字和特殊符號）\n• 開啟兩步驟驗證\n• 定期更換密碼\n• 不在公共場所登入\n• 注意釣魚郵件和假網站\n• 及時更新App版本",
        category: .security
    ),
    FAQItem(
        question: "忘記密碼怎麼辦？",
        answer: "重置密碼步驟：\n1. 在登入頁面點擊「忘記密碼」\n2. 輸入註冊信箱或手機號碼\n3. 查收驗證碼（檢查垃圾郵件匣）\n4. 輸入驗證碼\n5. 設定新密碼\n如仍有問題，請聯繫客服協助。",
        category: .security
    ),
    FAQItem(
        question: "如何開啟兩步驟驗證？",
        answer: "設定步驟：\n1. 進入「設定」→「帳戶安全」\n2. 點擊「兩步驟驗證」\n3. 選擇驗證方式（簡訊或App）\n4. 按指示完成設定\n5. 測試驗證功能\n強烈建議開啟此功能保護帳戶安全。",
        category: .security
    ),
    FAQItem(
        question: "發現帳戶異常活動怎麼辦？",
        answer: "立即採取行動：\n1. 馬上更改密碼\n2. 檢查登入記錄\n3. 查看錢包異動\n4. 聯繫客服報告\n5. 開啟帳戶保護模式\n我們提供24小時緊急客服協助處理安全問題。",
        category: .security
    ),
    
    // 技術問題
    FAQItem(
        question: "App 運行緩慢怎麼辦？",
        answer: "故障排除步驟：\n1. 關閉其他不必要的App\n2. 重新啟動 Invest_V3\n3. 檢查網路連線狀態\n4. 清除App快取（設定中）\n5. 更新到最新版本\n6. 重啟裝置\n如問題持續，請提供詳細資訊聯繫技術支援。",
        category: .technical
    ),
    FAQItem(
        question: "無法載入數據怎麼辦？",
        answer: "請嘗試：\n• 檢查網路連線\n• 切換Wi-Fi和行動數據\n• 下拉重新整理頁面\n• 重新啟動App\n• 清除暫存資料\n如特定功能持續無法使用，可能是伺服器維護中。",
        category: .technical
    ),
    FAQItem(
        question: "如何更新App？",
        answer: "更新方式：\n1. 開啟App Store\n2. 搜尋「股圈」\n3. 點擊「更新」按鈕\n或開啟自動更新：\n設定→App Store→App更新→開啟\n建議保持最新版本以享受最佳功能。",
        category: .technical
    ),
    FAQItem(
        question: "如何聯繫技術支援？",
        answer: "多種聯繫方式：\n• App內「意見回饋」功能\n• 客服信箱：support@股圈.com\n• 客服專線：0800-123-456\n• 線上客服（週一至週五 9:00-18:00）\n• FAQ幫助中心\n我們承諾24小時內回覆您的問題。",
        category: .technical
    ),
    FAQItem(
        question: "如何提交Bug報告？",
        answer: "報告Bug時請提供：\n• 詳細的問題描述\n• 重現步驟\n• 螢幕截圖或錄影\n• 裝置型號和iOS版本\n• App版本號\n• 發生時間\n完整資訊有助於我們快速定位和修復問題。",
        category: .technical
    )
]

#Preview {
    FAQView(initialCategory: .popular)
}