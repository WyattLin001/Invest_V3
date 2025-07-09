import SwiftUI
import MarkdownUI

struct ArticleDetailView: View {
    @Environment(\.dismiss) var dismiss
    let article: Article

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 標題
                    Text(article.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.leading)

                    // 作者與日期
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.author)
                                .font(.headline)
                            Text(article.createdAt.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !article.isFree {
                            Label("付費文章", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.brandOrange)
                        }
                    }
                    
                    Divider()

                    // 文章內容 (使用 Markdown 預覽)
                    Markdown(article.bodyMD ?? article.fullContent)
                        .markdownTextStyle {
                            FontSize(.em(1.0))
                        }
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            configuration.label
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                .background(Color.secondary.opacity(0.25))
                                .cornerRadius(8)
                        }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("文章詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // 點讚按鈕
                        Button(action: {
                            // TODO: 實現點讚功能
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart")
                                Text("\(article.likesCount)")
                            }
                            .font(.caption)
                            .foregroundColor(.brandGreen)
                        }
                        
                        // 分享按鈕
                        Button(action: {
                            // TODO: 實現分享功能
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 訂閱彈窗視圖
struct PlatformMembershipView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isSubscribing = false
    @State private var errorMessage: String?
    @State private var showSuccessAnimation = false
    @State private var successAnimationProgress: Double = 0.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // 主要內容
                VStack(spacing: DesignTokens.spacingLG) {
                    // 標題
                    VStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.brandOrange)
                        
                        Text("升級為平台會員")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("獲得一個月內所有文章的完整訪問權限")
                            .font(.body)
                            .foregroundColor(.gray600)
                            .multilineTextAlignment(.center)
                    }
                    
                    // 訂閱詳情
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        SubscriptionFeatureRow(icon: "doc.text", text: "訪問所有付費文章")
                        SubscriptionFeatureRow(icon: "clock", text: "30天有效期")
                        SubscriptionFeatureRow(icon: "arrow.clockwise", text: "自動續訂")
                    }
                    .padding()
                    .background(Color.gray100)
                    .cornerRadius(DesignTokens.cornerRadius)
                    
                    // 價格
                    VStack {
                        Text("300 代幣/月")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.brandOrange)
                        
                        Text("約等於 30 NTD")
                            .font(.caption)
                            .foregroundColor(.gray600)
                    }
                    
                    Spacer()
                    
                    // 訂閱按鈕
                    Button(action: subscribe) {
                        HStack {
                            if isSubscribing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubscribing ? "訂閱中..." : "確認訂閱")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.brandOrange)
                        .cornerRadius(DesignTokens.cornerRadius)
                    }
                    .disabled(isSubscribing)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(DesignTokens.spacingMD)
                .navigationTitle("訂閱")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
                
                // 訂閱成功動畫
                if showSuccessAnimation {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.brandGreen)
                            .scaleEffect(showSuccessAnimation ? 1.2 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSuccessAnimation)
                        
                        Text("訂閱成功！")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .opacity(showSuccessAnimation ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.8).delay(0.3), value: showSuccessAnimation)
                        
                        Text("您現在可以無限閱讀所有付費文章。")
                            .font(.body)
                            .foregroundColor(.white)
                            .opacity(showSuccessAnimation ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.8).delay(0.5), value: showSuccessAnimation)
                    }
                }
            }
        }
    }
    
    private func subscribe() {
        isSubscribing = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseService.shared.subscribeToPlatform()
                
                await MainActor.run {
                    isSubscribing = false
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSuccessAnimation = true
                    }
                    
                    // 2秒後自動關閉
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            dismiss()
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubscribing = false
                }
            }
        }
    }
}

struct SubscriptionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: icon)
                .foregroundColor(.brandGreen)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.gray900)
            
            Spacer()
        }
    }
}

// MARK: - 預覽
#Preview {
    ArticleDetailView(
        article: Article(
            id: UUID(),
            title: "投資新手必讀：如何開始股票投資",
            author: "投資專家",
            authorId: UUID(),
            summary: "這篇文章將為投資新手介紹股票投資的基本概念和入門技巧。",
            fullContent: """
            # 投資新手必讀：如何開始股票投資
            
            ## 什麼是股票投資？
            
            股票投資是指購買上市公司的股份，成為該公司的股東。當公司盈利時，股東可以獲得股息收入；當股價上漲時，股東可以通過賣出股票獲得資本利得。
            
            ## 投資前的準備
            
            1. **建立緊急基金**：確保有 3-6 個月的生活費作為緊急基金
            2. **學習基本知識**：了解股票市場的基本運作原理
            3. **設定投資目標**：明確自己的投資期限和風險承受能力
            
            ## 選擇投資標的
            
            新手建議從以下幾個方面考慮：
            
            - **大型穩定公司**：選擇市值較大、經營穩定的公司
            - **分散投資**：不要把所有資金投入單一股票
            - **定期定額**：採用定期定額投資策略降低風險
            
            記住，投資有風險，請謹慎評估自己的風險承受能力。
            """,
            bodyMD: """
            # 投資新手必讀：如何開始股票投資
            
            ## 什麼是股票投資？
            
            股票投資是指購買上市公司的股份，成為該公司的股東。
            """,
            category: "投資教學",
            readTime: "5 分鐘",
            likesCount: 128,
            commentsCount: 24,
            isFree: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
} 