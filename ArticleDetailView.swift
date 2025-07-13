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
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Divider()

                    // 文章內容 (使用 Markdown 預覽)
                    Markdown(article.bodyMD ?? article.fullContent)
                        .markdownTextStyle(\.text) {
                            FontSize(.em(1.0))
                        }
                        .markdownTextStyle(\.code) {
                            FontFamilyVariant(.monospaced)
                            BackgroundColor(.secondary.opacity(0.25))
                        }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("文章詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        dismiss()
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

#Preview {
    ArticleDetailView(article: Article(
        id: UUID(),
        title: "測試文章",
        author: "測試作者",
        authorId: UUID(),
        summary: "這是一篇測試文章的摘要...",
        fullContent: "這是完整的文章內容，包含更多詳細信息...",
        category: "投資分析",
        readTime: "5 分鐘",
        likesCount: 10,
        commentsCount: 5,
        isFree: false,
        createdAt: Date(),
        updatedAt: Date()
    ))
} 