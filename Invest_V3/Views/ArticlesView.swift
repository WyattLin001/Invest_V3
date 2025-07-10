//
//  ArticlesView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct ArticlesView: View {
    @State private var articles = Article.sampleData
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    
    private let categories = ["全部", "科技股", "價值投資", "加密貨幣", "市場分析", "投資策略"]
    
    var filteredArticles: [Article] {
        var filtered = articles
        
        if selectedCategory != "全部" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText) ||
                $0.summary.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜尋文章...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
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
                .padding(.vertical)
                
                // Articles List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredArticles) { article in
                            ArticleDetailCard(article: article)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("投資文章")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Create new article
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

struct ArticleDetailCard: View {
    let article: Article
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("付費")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.1))
                        .foregroundColor(.orange)
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
            
            // Author and Stats
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(article.author.prefix(1)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.author)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if let createdAt = article.createdAt {
                            Text(createdAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        isLiked.toggle()
                    } label: {
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
                    
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Read More Button
            Button {
                // Read article action
            } label: {
                Text(article.isFree ? "閱讀全文" : "解鎖閱讀")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(article.isFree ? Color.blue : Color.orange)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ArticlesView()
}