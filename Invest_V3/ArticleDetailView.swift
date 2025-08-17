import SwiftUI
import MarkdownUI

struct ArticleDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var interactionVM: ArticleInteractionViewModel
    @StateObject private var subscriptionService = UserSubscriptionService.shared
    @StateObject private var readingTracker = ReadingTrackingService.shared
    @State private var showGroupPicker = false
    @State private var availableGroups: [InvestmentGroup] = []
    @State private var showSubscriptionSheet = false
    @State private var isContentVisible = false
    // ScrollViewReader doesn't need to be stored as state
    
    let article: Article

    init(article: Article) {
        self.article = article
        self._interactionVM = StateObject(wrappedValue: ArticleInteractionViewModel(articleId: article.id))
    }

    var body: some View {
        ZStack {
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定義導航欄
                customNavigationBar
                
                // 主要內容
                mainContentStack
            }
            .opacity(isContentVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isContentVisible)
            
            // Loading 覆蓋層
            if !isContentVisible {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .onAppear {
            // 立即顯示內容，不再延遲
            withAnimation(.easeInOut(duration: 0.2)) {
                isContentVisible = true
            }
        }
    }
    
    // MARK: - 自定義導航欄
    private var customNavigationBar: some View {
        HStack {
            Button("關閉") {
                dismiss()
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("文章詳情")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // 平衡右側空間
            Button("關閉") {
                dismiss()
            }
            .opacity(0)
            .disabled(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - 主要內容堆疊
    private var mainContentStack: some View {
        ZStack {
            // 文章內容滿屏區域
            articleScrollView
            
            // 底部留言輸入
            bottomCommentInput
            
            // 動畫效果層
            animationOverlays
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerView(
                groups: availableGroups,
                onGroupSelected: { group in
                    interactionVM.shareToGroup(group.id, groupName: group.name)
                }
            )
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            PlatformMembershipView()
                .onDisappear {
                    // 訂閱彈窗關閉後刷新訂閱狀態
                    Task {
                        await subscriptionService.refreshSubscriptionStatus()
                    }
                }
        }
        .onAppear {
            Task {
                await interactionVM.loadInteractionStats()
                await interactionVM.loadComments()
                await loadAvailableGroups()
                
                // 開始閱讀追蹤
                readingTracker.startReading(article: article)
            }
        }
        .onDisappear {
            // 結束閱讀追蹤
            readingTracker.endReading(scrollPercentage: 50.0) // 假設用戶閱讀了一半內容
        }
    }
    
    // MARK: - 文章滾動視圖
    private var articleScrollView: some View {
        ScrollView {
            articleContentView
        }
    }
    
    // MARK: - 底部留言輸入
    private var bottomCommentInput: some View {
        VStack {
            Spacer()
            commentInputView
        }
    }
    
    // MARK: - 文章內容視圖
    private var articleContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            Text(article.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.leading)

            // 作者資訊區塊
            authorInfoBlock
            
            // 文章分類和狀態
            categoryAndStatusView
            
            // 互動統計
            interactionStatsView
            
            Divider()

            // 文章內容
            markdownContentView
            
            // 文章標籤區塊
            if !article.keywords.isEmpty {
                keywordsBlock
            }
            
            // 互動按鈕區域
            interactionButtonsView
            
            Divider()
            
            // 留言區域
            commentsSection
            
            Spacer(minLength: 100)
        }
        .padding()
    }
    
    // MARK: - 文章分類和狀態視圖
    private var categoryAndStatusView: some View {
        HStack {
            Text(article.category)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandBlue.opacity(0.1))
                .cornerRadius(16)
            
            Spacer()
            
            HStack(spacing: 8) {
                // 付費文章標籤
                if !article.isFree {
                    Label("付費文章", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.brandOrange)
                }
                
                // 會員狀態標籤
                if subscriptionService.canAccessPaidContent() {
                    Label("會員專享", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.brandGreen)
                }
            }
        }
    }
    
    // MARK: - Markdown 內容視圖
    private var markdownContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顯示可讀的內容（根據訂閱狀態決定完整或預覽）
            let readableContent = subscriptionService.getReadableContent(for: article)
            
            Markdown(readableContent)
                .markdownTextStyle {
                    FontSize(.em(1.0))
                }
                .modifier(MarkdownHeadingStyleModifier())
                .modifier(MarkdownBlockStyleModifier())
                .multilineTextAlignment(.leading)
            
            // 付費文章的訂閱提示
            if !article.isFree && !subscriptionService.canAccessPaidContent() {
                paywallPromptView
            }
        }
    }
    
    // MARK: - 付費牆提示視圖
    private var paywallPromptView: some View {
        VStack(spacing: 16) {
            // 漸層遮罩效果
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.surfacePrimary.opacity(0.8),
                    Color.surfacePrimary
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .offset(y: -16)
            
            // 付費提示卡片
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(.brandOrange)
                
                Text("解鎖完整內容")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("訂閱平台會員，即可無限閱讀所有付費文章")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    showSubscriptionSheet = true
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("立即解鎖")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.brandOrange)
                    .cornerRadius(25)
                }
                
                Text("300 代幣/月 · 隨時可取消")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .padding(24)
            .background(Color.surfaceSecondary)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    
    // MARK: - 作者資訊區塊
    private var authorInfoBlock: some View {
        HStack(spacing: 16) {
            // 作者頭像（使用簡單的圓形背景）
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.brandGreen, Color.brandGreen.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(article.author.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(article.author)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                Text("投資專家")
                    .font(.caption)
                    .foregroundColor(.gray600)
                
                Text(article.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 阅讀時間
            VStack(alignment: .trailing, spacing: 2) {
                Text(article.readTime)
                    .font(.caption)
                    .foregroundColor(.gray600)
                
                Text("閱讀時間")
                    .font(.caption2)
                    .foregroundColor(.gray500)
            }
        }
        .padding(16)
        .background(Color.gray50)
        .cornerRadius(12)
    }

    // MARK: - 文章標籤區塊
    private var keywordsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .font(.subheadline)
                    .foregroundColor(.brandGreen)
                
                Text("相關標籤")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                Spacer()
            }
            
            // 標籤集合
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 8)
            ], spacing: 8) {
                ForEach(article.keywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.brandBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandBlue.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.brandBlue.opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(16)
        .background(Color.gray50)
        .cornerRadius(12)
    }
    
    // MARK: - 互動統計視圖
    private var interactionStatsView: some View {
        HStack(spacing: 20) {
            // 按讚數
            HStack(spacing: 4) {
                Image(systemName: interactionVM.isLiked ? "heart.fill" : "heart")
                    .foregroundColor(interactionVM.isLiked ? .red : .gray)
                    .scaleEffect(interactionVM.likeAnimationScale)
                Text("\(interactionVM.likesCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 留言數
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .foregroundColor(.gray)
                Text("\(interactionVM.commentsCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 分享數
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.gray)
                Text("\(interactionVM.sharesCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 互動按鈕
    private var interactionButtonsView: some View {
        HStack(spacing: 30) {
            // 按讚按鈕
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    interactionVM.toggleLike()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: interactionVM.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(interactionVM.isLiked ? .red : .gray)
                        .font(.title3)
                    Text(interactionVM.isLiked ? "已按讚" : "按讚")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(interactionVM.isLiked ? .red : .primary)
            }
            .disabled(interactionVM.isLiking)
            .scaleEffect(interactionVM.likeAnimationScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: interactionVM.likeAnimationScale)
            
            // 留言按鈕
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    interactionVM.showComments.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.title3)
                    Text("留言")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
            }
            
            // 分享按鈕
            Button(action: {
                showGroupPicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text("分享")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
            }
            .disabled(interactionVM.isSharing)
            
            Spacer()
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - 留言區域
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("留言")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(interactionVM.comments.count) 則留言")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if interactionVM.comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("還沒有留言")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("成為第一個留言的人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(interactionVM.comments) { comment in
                        CommentRowView(comment: comment)
                    }
                }
            }
        }
        .animation(.easeInOut, value: interactionVM.comments)
    }
    
    // MARK: - 留言輸入
    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("寫下你的想法...", text: $interactionVM.commentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        interactionVM.submitComment()
                    }
                }) {
                    if interactionVM.isSubmittingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.brandGreen)
                    }
                }
                .disabled(interactionVM.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || interactionVM.isSubmittingComment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - 動畫覆蓋層
    private var animationOverlays: some View {
        ZStack {
            // 按讚動畫
            if interactionVM.showLikeAnimation {
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .scaleEffect(interactionVM.showLikeAnimation ? 1.5 : 0.5)
                        .opacity(interactionVM.showLikeAnimation ? 1.0 : 0.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: interactionVM.showLikeAnimation)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .allowsHitTesting(false)
            }
            
            // 分享成功動畫
            if interactionVM.showShareSuccessAnimation {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.brandGreen)
                    
                    Text("分享成功！")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .scaleEffect(interactionVM.showShareSuccessAnimation ? 1.0 : 0.5)
                .opacity(interactionVM.showShareSuccessAnimation ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: interactionVM.showShareSuccessAnimation)
            }
        }
    }
    
    // MARK: - 載入用戶群組
    private func loadAvailableGroups() async {
        // Preview 安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Preview 模式：使用模擬群組
            await MainActor.run {
                self.availableGroups = [
                    InvestmentGroup(
                        id: UUID(),
                        name: "模擬投資群組",
                        host: "測試主持人",
                        returnRate: 15.5,
                        entryFee: "10 代幣",
                        memberCount: 10,
                        category: "股票投資",
                        rules: "投資群組規則",
                        tokenCost: 10,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
            }
            return
        }
        #endif
        
        do {
            let groups = try await SupabaseService.shared.fetchUserJoinedGroups()
            await MainActor.run {
                self.availableGroups = groups
            }
        } catch {
            print("❌ 載入群組失敗: \(error)")
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

// MARK: - 留言行視圖
struct CommentRowView: View {
    let comment: ArticleComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 頭像
            Circle()
                .fill(Color.brandGreen.opacity(0.7))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(comment.userName.prefix(1)))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // 用戶名和時間
                HStack {
                    Text(comment.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(comment.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 留言內容
                Text(comment.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - 群組選擇器視圖
struct GroupPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedGroup: InvestmentGroup?
    
    let groups: [InvestmentGroup]
    let onGroupSelected: (InvestmentGroup) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                if groups.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("還沒有加入任何群組")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("先加入一個投資群組，就可以分享文章了")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List(groups) { group in
                        ShareGroupRowView(
                            group: group,
                            isSelected: selectedGroup?.id == group.id
                        ) {
                            selectedGroup = group
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("選擇群組")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("分享") {
                        if let group = selectedGroup {
                            onGroupSelected(group)
                            dismiss()
                        }
                    }
                    .disabled(selectedGroup == nil)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - 群組行視圖
struct ShareGroupRowView: View {
    let group: InvestmentGroup
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 群組圖標
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.brandGreen.opacity(0.7))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(group.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(group.memberCount) 位成員")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !group.description.isEmpty {
                    Text(group.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.brandGreen)
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 24, height: 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onTap()
            }
        }
        .padding(.vertical, 8)
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
            sharesCount: 12,
            isFree: true,
            createdAt: Date(),
            updatedAt: Date(),
            keywords: ["股票投資", "新手教學", "投資基礎"]
        )
    )
}

// MARK: - Markdown 樣式修飾器
struct MarkdownHeadingStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            // H1 標題樣式
            .markdownBlockStyle(\.heading1) { configuration in
                configuration.label
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.gray900)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.brandGreen)
                            .offset(y: 20),
                        alignment: .bottom
                    )
            }
            // H2 標題樣式
            .markdownBlockStyle(\.heading2) { configuration in
                configuration.label
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray800)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray300)
                            .offset(y: 12),
                        alignment: .bottom
                    )
            }
            // H3 標題樣式
            .markdownBlockStyle(\.heading3) { configuration in
                configuration.label
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray800)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
    }
}

struct MarkdownBlockStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            // 代碼區塊樣式
            .markdownBlockStyle(\.codeBlock) { configuration in
                configuration.label
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(Color.secondary.opacity(0.25))
                    .cornerRadius(8)
            }
            // 圖片樣式（支援來源標註）
            .markdownBlockStyle(\.image) { configuration in
                VStack(spacing: 8) {
                    configuration.label
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // 簡化圖片標題處理
                    Text("圖片")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                }
            }
            // 列表樣式
            .markdownBlockStyle(\.listItem) { configuration in
                configuration.label
                    .padding(.vertical, 2)
            }
            // 引用樣式
            .markdownBlockStyle(\.blockquote) { configuration in
                configuration.label
                    .padding(.leading, 16)
                    .padding(.vertical, 8)
                    .background(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: 4)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    )
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(4)
            }
    }
    
}
