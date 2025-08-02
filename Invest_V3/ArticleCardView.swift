import SwiftUI

struct ArticleCardView: View {
    let article: Article
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // 左側：封面圖片
            coverImageSection
            
            // 右側：文章內容
            VStack(alignment: .leading, spacing: 6) {
                // 標題與免費/付費標籤
                HStack(alignment: .top, spacing: 8) {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 0)
                    
                    // 免費/付費標籤
                    pricingBadge
                }
                
                // 作者（含 AI 標識）
                authorSection
                
                // 摘要
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                // 底部資訊列
                bottomInfoRow
            }
        }
        .padding(DesignTokens.spacingMD)
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
        .adaptiveBackground()
        .cornerRadius(DesignTokens.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 封面圖片區域
    @ViewBuilder
    private var coverImageSection: some View {
        if article.hasCoverImage, let imageUrl = article.safeCoverImageUrl {
            AsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                // 加載中的佔位符
                Rectangle()
                    .fill(Color.surfaceSecondary)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.textSecondary)
                    )
            }
            .frame(width: ResponsiveSpacing.horizontal(compact: 100, regular: 120), 
                   height: ResponsiveSpacing.vertical(compact: 67, regular: 80))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            // 無圖片時的佔位符
            placeholderImage
        }
    }
    
    // MARK: - 佔位符圖片
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    Color.surfaceSecondary,
                    Color.surfaceSecondary.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: ResponsiveSpacing.horizontal(compact: 100, regular: 120), 
                   height: ResponsiveSpacing.vertical(compact: 67, regular: 80))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundColor(.textTertiary)
                    
                    Text("投資")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.textTertiary)
                }
            )
    }
    
    // MARK: - 價格標籤
    @ViewBuilder
    private var pricingBadge: some View {
        if article.isFree {
            Text("免費")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.brandGreen)
                .foregroundColor(.white)
                .cornerRadius(DesignTokens.cornerRadiusSM)
        } else {
            HStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("付費")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.brandOrange)
            .foregroundColor(.white)
            .cornerRadius(DesignTokens.cornerRadiusSM)
        }
    }
    
    // MARK: - 作者區域
    private var authorSection: some View {
        HStack(spacing: 4) {
            Text("作者:")
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            // AI 作者標識
            if article.isAIGenerated {
                HStack(spacing: 2) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundColor(.brandBlue)
                    
                    Text(article.author)
                        .font(.caption)
                        .foregroundColor(.brandBlue)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.brandBlue.opacity(0.1))
                .cornerRadius(3)
            } else {
                Text(article.author)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 底部資訊列
    private var bottomInfoRow: some View {
        HStack {
            // 類別標籤
            if !article.category.isEmpty {
                Text(article.category)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.surfaceSecondary)
                    .foregroundColor(.textSecondary)
                    .cornerRadius(4)
            }
            
            // AI 文章狀態標籤（僅在非發布狀態時顯示）
            if article.isAIGenerated && article.status != .published {
                Text(article.status.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(for: article.status))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // 互動數據
            HStack(spacing: DesignTokens.spacingSM) {
                // 按讚數
                interactionIndicator(icon: "heart", count: article.likesCount)
                
                // 評論數
                interactionIndicator(icon: "bubble.left", count: article.commentsCount)
                
                // 分享數
                interactionIndicator(icon: "square.and.arrow.up", count: article.sharesCount)
            }
        }
    }
    
    // MARK: - 互動指標
    private func interactionIndicator(icon: String, count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count)")
                .font(.caption)
        }
        .foregroundColor(.textSecondary)
    }
    
    /// 根據文章狀態返回對應的顏色
    private func statusColor(for status: ArticleStatus) -> Color {
        switch status {
        case .draft:
            return .gray
        case .review:
            return .orange
        case .published:
            return .green
        case .archived:
            return .red
        }
    }
} 