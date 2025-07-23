import SwiftUI
import MarkdownUI

struct ArticleDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var interactionVM: ArticleInteractionViewModel
    @State private var showGroupPicker = false
    @State private var availableGroups: [InvestmentGroup] = []
    
    let article: Article

    init(article: Article) {
        self.article = article
        self._interactionVM = StateObject(wrappedValue: ArticleInteractionViewModel(articleId: article.id))
    }

    var body: some View {
        NavigationView {
            ZStack {
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
                        
                        // 互動統計
                        interactionStatsView
                        
                        Divider()

                        // 文章內容
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
                        
                        // 互動按鈕區域
                        interactionButtonsView
                        
                        Divider()
                        
                        // 留言區域
                        commentsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                // 留言輸入區域（固定在底部）
                VStack {
                    Spacer()
                    commentInputView
                }
                
                // 動畫效果
                animationOverlays
            }
            .navigationTitle("文章詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showGroupPicker) {
                GroupPickerView(
                    groups: availableGroups,
                    onGroupSelected: { group in
                        interactionVM.shareToGroup(group.id, groupName: group.name)
                    }
                )
            }
            .onAppear {
                Task {
                    await interactionVM.loadInteractionStats()
                    await interactionVM.loadComments()
                    await loadAvailableGroups()
                }
            }
        }
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
            updatedAt: Date()
        )
    )
} 