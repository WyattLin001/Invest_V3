import Foundation

// MARK: - 文章互動基本模型

/// 文章按讚記錄
struct ArticleLike: Codable, Identifiable {
    let id: UUID
    let articleId: UUID
    let userId: UUID
    let userName: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"  
        case userName = "user_name"
        case createdAt = "created_at"
    }
}

/// 文章留言記錄  
struct ArticleComment: Codable, Identifiable {
    let id: UUID
    let articleId: UUID
    let userId: UUID
    let userName: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case userName = "user_name"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 格式化時間顯示
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// 文章分享記錄
struct ArticleShare: Codable, Identifiable {
    let id: UUID
    let articleId: UUID
    let userId: UUID
    let userName: String
    let groupId: UUID
    let groupName: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case userName = "user_name"
        case groupId = "group_id"
        case groupName = "group_name"
        case createdAt = "created_at"
    }
}

// MARK: - 文章互動統計

/// 文章互動統計摘要
struct ArticleInteractionStats: Codable {
    let articleId: UUID
    let likesCount: Int
    let commentsCount: Int
    let sharesCount: Int
    let userHasLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case articleId = "article_id"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case sharesCount = "shares_count"
        case userHasLiked = "user_has_liked"
    }
}

// MARK: - 互動用的ViewModel狀態

/// 文章互動狀態管理
@MainActor
class ArticleInteractionViewModel: ObservableObject {
    // 狀態變數
    @Published var isLiked = false
    @Published var likesCount = 0
    @Published var commentsCount = 0
    @Published var sharesCount = 0
    @Published var comments: [ArticleComment] = []
    
    // UI狀態
    @Published var showComments = false
    @Published var showShareSheet = false
    @Published var commentText = ""
    @Published var isSubmittingComment = false
    @Published var isLiking = false
    @Published var isSharing = false
    
    // 動畫狀態
    @Published var likeAnimationScale: CGFloat = 1.0
    @Published var showLikeAnimation = false
    @Published var showCommentSubmitAnimation = false
    @Published var showShareSuccessAnimation = false
    
    let articleId: UUID
    private let supabaseService = SupabaseService.shared
    
    init(articleId: UUID) {
        self.articleId = articleId
    }
    
    // MARK: - 數據載入
    
    /// 載入文章互動統計
    func loadInteractionStats() async {
        do {
            let stats = try await supabaseService.fetchArticleInteractionStats(articleId: articleId)
            await MainActor.run {
                self.isLiked = stats.userHasLiked
                self.likesCount = stats.likesCount
                self.commentsCount = stats.commentsCount
                self.sharesCount = stats.sharesCount
            }
        } catch {
            print("❌ [ArticleInteraction] 載入統計失敗: \(error)")
        }
    }
    
    /// 載入文章留言
    func loadComments() async {
        do {
            let comments = try await supabaseService.fetchArticleComments(articleId: articleId)
            await MainActor.run {
                self.comments = comments
                self.commentsCount = comments.count
            }
        } catch {
            print("❌ [ArticleInteraction] 載入留言失敗: \(error)")
        }
    }
    
    // MARK: - 互動操作
    
    /// 切換按讚狀態
    func toggleLike() {
        guard !isLiking else { return }
        
        isLiking = true
        
        Task {
            do {
                if isLiked {
                    try await supabaseService.unlikeArticle(articleId: articleId)
                    await MainActor.run {
                        self.isLiked = false
                        self.likesCount = max(0, self.likesCount - 1)
                    }
                } else {
                    try await supabaseService.likeArticle(articleId: articleId)
                    await MainActor.run {
                        self.isLiked = true
                        self.likesCount += 1
                        self.triggerLikeAnimation()
                    }
                }
            } catch {
                print("❌ [ArticleInteraction] 按讚操作失敗: \(error)")
            }
            
            await MainActor.run {
                self.isLiking = false
            }
        }
    }
    
    /// 提交留言
    func submitComment() {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isSubmittingComment else { return }
        
        isSubmittingComment = true
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                let newComment = try await supabaseService.addArticleComment(
                    articleId: articleId,
                    content: content
                )
                
                await MainActor.run {
                    self.comments.append(newComment)
                    self.commentsCount += 1
                    self.commentText = ""
                    self.triggerCommentSubmitAnimation()
                }
            } catch {
                print("❌ [ArticleInteraction] 提交留言失敗: \(error)")
            }
            
            await MainActor.run {
                self.isSubmittingComment = false
            }
        }
    }
    
    /// 分享文章到群組
    func shareToGroup(_ groupId: UUID, groupName: String) {
        guard !isSharing else { return }
        
        isSharing = true
        
        Task {
            do {
                try await supabaseService.shareArticleToGroup(
                    articleId: articleId,
                    groupId: groupId,
                    groupName: groupName
                )
                
                await MainActor.run {
                    self.sharesCount += 1
                    self.showShareSheet = false
                    self.triggerShareSuccessAnimation()
                }
            } catch {
                print("❌ [ArticleInteraction] 分享失敗: \(error)")
            }
            
            await MainActor.run {
                self.isSharing = false
            }
        }
    }
    
    // MARK: - 動畫觸發
    
    private func triggerLikeAnimation() {
        showLikeAnimation = true
        likeAnimationScale = 1.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.likeAnimationScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.showLikeAnimation = false
        }
    }
    
    private func triggerCommentSubmitAnimation() {
        showCommentSubmitAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showCommentSubmitAnimation = false
        }
    }
    
    private func triggerShareSuccessAnimation() {
        showShareSuccessAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showShareSuccessAnimation = false
        }
    }
}