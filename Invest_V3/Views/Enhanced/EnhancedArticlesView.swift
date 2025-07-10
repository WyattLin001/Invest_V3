//
//  EnhancedArticlesView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct EnhancedArticlesView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var paymentService = PaymentService.shared
    
    @State private var articles: [Article] = []
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var featuredAuthors: [Author] = []
    @State private var userSubscriptions: [Subscription] = []
    @State private var freeArticlesRead = 0
    @State private var showingSubscriptionSheet = false
    @State private var selectedAuthor: Author?
    
    private let categories = ["全部", "科技股", "綠能", "短期投機", "價值投資"]
    private let maxFreeArticles = 3
    
    var filteredArticles: [Article] {
        var filtered = articles
        
        if selectedCategory != "全部" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Search
                VStack(spacing: 16) {
                    HStack {
                        Text("投資資訊")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button {
                            // Search action
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                        }
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("搜尋文章或作者...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemBackground))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Category Filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryChip(
                                        title: category,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Featured Articles
                        if !filteredArticles.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(filteredArticles) { article in
                                    EnhancedArticleCard(
                                        article: article,
                                        canRead: canReadArticle(article),
                                        freeArticlesRemaining: maxFreeArticles - freeArticlesRead,
                                        onRead: { readArticle(article) },
                                        onLike: { likeArticle(article) },
                                        onSubscribe: { subscribeToAuthor(article) },
                                        onTip: { tipAuthor(article) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Featured Authors
                        if !featuredAuthors.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("推薦作者")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(featuredAuthors) { author in
                                            FeaturedAuthorCard(
                                                author: author,
                                                isSubscribed: userSubscriptions.contains { $0.authorId == author.id }
                                            ) {
                                                subscribeToAuthor(author)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSubscriptionSheet) {
                SubscriptionSheetView(author: selectedAuthor) { author in
                    Task {
                        await handleSubscription(author)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        do {
            articles = try await supabaseService.fetchArticles()
            // Load featured authors and user subscriptions
            featuredAuthors = Author.sampleData
        } catch {
            print("Failed to load articles: \(error)")
        }
    }
    
    private func canReadArticle(_ article: Article) -> Bool {
        if article.isFree {
            return freeArticlesRead < maxFreeArticles
        } else {
            return userSubscriptions.contains { $0.authorId == article.authorId }
        }
    }
    
    private func readArticle(_ article: Article) {
        if article.isFree && freeArticlesRead < maxFreeArticles {
            freeArticlesRead += 1
        }
        // Navigate to full article view
    }
    
    private func likeArticle(_ article: Article) {
        guard let userId = supabaseService.getCurrentUser()?.id else { return }
        
        Task {
            do {
                try await supabaseService.likeArticle(articleId: article.id, userId: userId)
                await loadData() // Refresh to show updated like count
            } catch {
                print("Failed to like article: \(error)")
            }
        }
    }
    
    private func subscribeToAuthor(_ article: Article) {
        selectedAuthor = featuredAuthors.first { $0.id == article.authorId }
        showingSubscriptionSheet = true
    }
    
    private func subscribeToAuthor(_ author: Author) {
        selectedAuthor = author
        showingSubscriptionSheet = true
    }
    
    private func handleSubscription(_ author: Author) async {
        guard let userId = supabaseService.getCurrentUser()?.id else { return }
        
        do {
            try await paymentService.subscribeToAuthor(authorId: author.id)
            try await supabaseService.createSubscription(userId: userId, authorId: author.id)
            await loadData()
        } catch {
            print("Failed to subscribe: \(error)")
        }
    }
    
    private func tipAuthor(_ article: Article) {
        // Show tip selection sheet
    }
}

struct EnhancedArticleCard: View {
    let article: Article
    let canRead: Bool
    let freeArticlesRemaining: Int
    let onRead: () -> Void
    let onLike: () -> Void
    let onSubscribe: () -> Void
    let onTip: () -> Void
    
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Category and Reading Time
            HStack {
                Text(article.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !article.isFree {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.red)
                            Text("付費")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    } else {
                        Text("免費")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#00B900").opacity(0.1))
                            .foregroundColor(Color(hex: "#00B900"))
                            .cornerRadius(8)
                    }
                    
                    Text(article.readTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Title and Summary
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Author Info
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(article.author.prefix(1)))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.author)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let createdAt = article.createdAt {
                        Text(createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("已訂閱") {
                    // Already subscribed
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#00B900"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Interaction Bar
            HStack {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(article.likesCount + (isLiked ? 1 : 0))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.secondary)
                    Text("\(article.commentsCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: onTip) {
                    HStack(spacing: 4) {
                        Text("🌸")
                        Text("打賞")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    // Share action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
            }
            
            // Read Button
            Button(action: onRead) {
                HStack {
                    if canRead {
                        Text(article.isFree ? "閱讀全文" : "閱讀全文")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    } else if article.isFree {
                        Text("今日免費額度已用完")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    } else {
                        Text("訂閱解鎖")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    if article.isFree && !canRead {
                        Text("剩餘 \(freeArticlesRemaining) 篇")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(canRead ? Color(hex: "#00B900") : Color.gray)
                .cornerRadius(10)
            }
            .disabled(!canRead && article.isFree)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct FeaturedAuthorCard: View {
    let author: Author
    let isSubscribed: Bool
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(author.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )
            
            VStack(spacing: 4) {
                Text(author.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(author.groupCount) 群組")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(author.subscriberCount) 訂閱者")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onSubscribe) {
                Text(isSubscribed ? "已訂閱" : "關注")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isSubscribed ? Color.gray : Color(hex: "#00B900"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isSubscribed)
        }
        .frame(width: 120)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SubscriptionSheetView: View {
    let author: Author?
    let onSubscribe: (Author) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let author = author {
                    // Author Info
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(author.name.prefix(1)))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(spacing: 4) {
                            Text(author.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("\(author.subscriberCount) 訂閱者")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Subscription Benefits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("訂閱權益")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BenefitRow(icon: "doc.text", text: "無限制閱讀所有付費文章")
                            BenefitRow(icon: "bell", text: "第一時間收到新文章通知")
                            BenefitRow(icon: "message", text: "優先參與作者問答")
                            BenefitRow(icon: "crown", text: "專屬訂閱者內容")
                        }
                    }
                    
                    // Pricing
                    VStack(spacing: 16) {
                        HStack {
                            Text("月訂閱")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("NT$ 300")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#00B900"))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        Button {
                            onSubscribe(author)
                            dismiss()
                        } label: {
                            Text("立即訂閱")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "#00B900"))
                                .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("訂閱作者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#00B900"))
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Supporting Models
struct Author: Identifiable {
    let id: UUID
    let name: String
    let groupCount: Int
    let subscriberCount: Int
    
    static let sampleData = [
        Author(id: UUID(), name: "投資大師Tom", groupCount: 3, subscriberCount: 1250),
        Author(id: UUID(), name: "環保投資者Lisa", groupCount: 2, subscriberCount: 890),
        Author(id: UUID(), name: "交易員Kevin", groupCount: 1, subscriberCount: 567)
    ]
}

#Preview {
    EnhancedArticlesView()
}