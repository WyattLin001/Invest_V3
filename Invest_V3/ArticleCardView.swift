import SwiftUI

struct ArticleCardView: View {
    let article: Article
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            VStack(alignment: .leading, spacing: 6) {
                // 標題與免費/付費標籤
                HStack {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // 免費/付費標籤
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
                
                // 作者（含 AI 標識）
                HStack(spacing: 4) {
                    Text("作者:")
                        .font(.caption)
                        .foregroundColor(.gray600)
                    
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
                            .foregroundColor(.gray600)
                    }
                }
                
                // 摘要 (50字限制)
                Text(article.summary)
                    .font(.body)
                    .foregroundColor(.gray600)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 底部資訊列
                HStack {
                    // 類別標籤
                    if !article.category.isEmpty {
                        Text(article.category)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray200)
                            .foregroundColor(.gray600)
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
                        HStack(spacing: 2) {
                            Image(systemName: "heart")
                                .font(.caption)
                            Text("\(article.likesCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.gray600)
                        
                        // 評論數
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                                .font(.caption)
                            Text("\(article.commentsCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.gray600)
                        
                        // 分享數
                        HStack(spacing: 2) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("\(article.sharesCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.gray600)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .frame(width: 343, height: 116)
        .brandCardStyle()
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