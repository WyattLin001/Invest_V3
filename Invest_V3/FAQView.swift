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
    case general = "一般問題"
    case trading = "交易相關"
    case tournament = "錦標賽"
    case payment = "付費功能"
    case technical = "技術支援"
    
    var icon: String {
        switch self {
        case .general:
            return "questionmark.circle"
        case .trading:
            return "chart.bar"
        case .tournament:
            return "trophy"
        case .payment:
            return "creditcard"
        case .technical:
            return "gear"
        }
    }
}

struct FAQView: View {
    @State private var selectedCategory: FAQCategory = .general
    @State private var searchText = ""
    @State private var expandedItems: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                topNavigationBar
                
                // 搜尋框
                searchBar
                
                // 分類篩選
                categoryFilter
                
                // FAQ列表
                faqList
            }
            .background(Color.gray100)
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - 頂部導航欄
    private var topNavigationBar: some View {
        HStack {
            Text("常見問題")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.gray900)
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .frame(height: 44)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray300),
            alignment: .bottom
        )
    }
    
    // MARK: - 搜尋框
    private var searchBar: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray600)
                .frame(width: 20, height: 20)
            
            TextField("搜尋問題...", text: $searchText)
                .font(.body)
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(Color.gray200)
        .cornerRadius(DesignTokens.cornerRadius)
        .frame(width: 343, height: 40)
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
    }
    
    // MARK: - 分類篩選
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(FAQCategory.allCases, id: \.self) { category in
                    CategoryChip(
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
        .padding(.vertical, DesignTokens.spacingSM)
    }
    
    // MARK: - FAQ列表
    private var faqList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                ForEach(filteredFAQs) { faq in
                    FAQCard(
                        faq: faq,
                        isExpanded: expandedItems.contains(faq.id)
                    ) {
                        toggleExpansion(for: faq.id)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXL)
        }
        .background(Color.gray100)
    }
    
    // MARK: - 篩選邏輯
    private var filteredFAQs: [FAQItem] {
        let categoryFiltered = faqData.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter {
                $0.question.localizedCaseInsensitiveContains(searchText) ||
                $0.answer.localizedCaseInsensitiveContains(searchText)
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

// MARK: - 分類標籤
struct CategoryChip: View {
    let category: FAQCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.brandGreen : Color.gray200)
            .foregroundColor(isSelected ? .white : .gray600)
            .cornerRadius(16)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - FAQ卡片
struct FAQCard: View {
    let faq: FAQItem
    let isExpanded: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 問題標題
            Button(action: toggleAction) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: faq.category.icon)
                                .font(.caption)
                                .foregroundColor(.brandGreen)
                            
                            Text(faq.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.gray600)
                        }
                        
                        Text(faq.question)
                            .font(.bodyText)
                            .fontWeight(.medium)
                            .foregroundColor(.gray900)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray600)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: DesignTokens.animationFast), value: isExpanded)
                }
                .padding(DesignTokens.spacingMD)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // 答案內容
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Rectangle()
                        .fill(Color.gray300)
                        .frame(height: 1)
                    
                    Text(faq.answer)
                        .font(.bodyText)
                        .foregroundColor(.gray700)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.bottom, DesignTokens.spacingMD)
                }
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - FAQ數據
private let faqData: [FAQItem] = [
    // 一般問題
    FAQItem(
        question: "什麼是 Invest_V3？",
        answer: "Invest_V3 是一個專為台灣投資者設計的知識分享平台，提供透明的投資組合管理、專家分析文章，以及錦標賽競賽功能。我們致力於打造一個可信賴的投資學習環境。",
        category: .general
    ),
    FAQItem(
        question: "如何註冊帳號？",
        answer: "您可以通過以下步驟註冊：\n1. 點擊「登入/註冊」按鈕\n2. 選擇註冊方式（郵箱或手機號碼）\n3. 填寫必要資訊並設定密碼\n4. 驗證郵箱或手機號碼\n5. 完成個人資料設定",
        category: .general
    ),
    FAQItem(
        question: "如何修改個人資料？",
        answer: "進入「設定」頁面，點擊個人資料區域即可修改頭像、暱稱、用戶ID等資訊。修改後的資訊將即時同步到您的個人檔案。",
        category: .general
    ),
    
    // 交易相關
    FAQItem(
        question: "如何開始模擬投資？",
        answer: "1. 完成註冊並登入\n2. 前往「投資」頁面\n3. 選擇「一般模式」或「錦標賽模式」\n4. 搜尋您想投資的股票\n5. 輸入投資金額並確認交易\n系統會使用虛擬資金進行模擬交易。",
        category: .trading
    ),
    FAQItem(
        question: "投資組合如何計算報酬率？",
        answer: "報酬率計算公式：(當前總價值 - 初始投資金額) / 初始投資金額 × 100%\n系統會即時更新股價資訊，自動計算您的投資組合表現，包括總報酬、日報酬和各股票的個別表現。",
        category: .trading
    ),
    FAQItem(
        question: "支援哪些股票市場？",
        answer: "目前主要支援台灣股市（TSE、OTC），包括：\n• 上市股票\n• 上櫃股票\n• ETF基金\n未來將逐步擴展至美股、港股等國際市場。",
        category: .trading
    ),
    
    // 錦標賽
    FAQItem(
        question: "什麼是投資錦標賽？",
        answer: "投資錦標賽是一個競賽性的模擬投資活動，參賽者使用相同的起始資金進行投資，在規定時間內比較投資表現。優勝者可獲得獎勵和榮譽認證。",
        category: .tournament
    ),
    FAQItem(
        question: "如何參加錦標賽？",
        answer: "1. 前往「錦標賽」頁面\n2. 選擇想參加的錦標賽\n3. 閱讀比賽規則和獎勵\n4. 點擊「報名參加」\n5. 確認報名資訊\n報名成功後即可開始在錦標賽模式下進行投資。",
        category: .tournament
    ),
    FAQItem(
        question: "錦標賽有什麼獎勵？",
        answer: "錦標賽獎勵包括：\n• 排名證書和榮譽徽章\n• 平台代幣獎勵\n• 專家認證資格\n• 優先發文權限\n具體獎勵依不同錦標賽而定，詳情請查看各錦標賽說明。",
        category: .tournament
    ),
    
    // 付費功能
    FAQItem(
        question: "什麼是Premium會員？",
        answer: "Premium會員享有：\n• 進階投資分析工具\n• 專家一對一諮詢\n• 獨家投資報告\n• 優先客服支援\n• 無廣告瀏覽體驗\n月費為NT$299，可隨時取消訂閱。",
        category: .payment
    ),
    FAQItem(
        question: "如何購買代幣？",
        answer: "1. 進入「錢包」頁面\n2. 點擊「購買代幣」\n3. 選擇購買數量\n4. 選擇付款方式（信用卡、Apple Pay等）\n5. 確認付款\n代幣可用於訂閱專家內容、參與付費錦標賽等功能。",
        category: .payment
    ),
    
    // 技術支援
    FAQItem(
        question: "App運行緩慢怎麼辦？",
        answer: "請嘗試以下解決方案：\n1. 關閉其他應用程式\n2. 重啟App\n3. 檢查網路連線\n4. 更新到最新版本\n5. 重啟手機\n如問題持續，請聯繫客服團隊。",
        category: .technical
    ),
    FAQItem(
        question: "忘記密碼怎麼辦？",
        answer: "1. 在登入頁面點擊「忘記密碼」\n2. 輸入註冊時的郵箱或手機號碼\n3. 檢查收到的驗證碼\n4. 設定新密碼\n如未收到驗證碼，請檢查垃圾郵件匣或聯繫客服。",
        category: .technical
    ),
    FAQItem(
        question: "如何聯繫客服？",
        answer: "您可以通過以下方式聯繫我們：\n• App內意見回饋功能\n• 郵件：support@invest-v3.com\n• 客服專線：0800-123-456\n• 線上客服（週一至週五 9:00-18:00）\n我們會在24小時內回覆您的問題。",
        category: .technical
    )
]

#Preview {
    FAQView()
}