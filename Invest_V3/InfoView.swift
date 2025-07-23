//
//  InfoView.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//

import SwiftUI

struct InfoView: View {
    @StateObject private var viewModel = ArticleViewModel()
    @State private var searchText = ""
    @State private var selectedKeywordIndex = 0
    @State private var showArticleEditor = false
    @State private var selectedArticle: Article?
    @State private var showArticleDetail = false
    @State private var showDrafts = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // 頂部導航欄 (44px)
                    topNavigationBar
                    
                    // 搜尋框 (343×40 pt)
                    searchBar
                    
                    // 熱門關鍵字篩選
                    keywordFilter
                    
                    // 文章列表
                    articlesList
                }
                .background(Color.gray100)
                
                // Medium 風格圓形浮動按鈕
                mediumStyleFloatingButton
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showArticleEditor) {
            MediumStyleEditor()
                .onDisappear {
                    Task {
                        await viewModel.fetchArticles()
                    }
                }
        }
        .sheet(isPresented: $showArticleDetail) {
            if let article = selectedArticle {
                ArticleDetailView(article: article)
                    .onDisappear {
                        // 從文章詳情返回時刷新文章列表，更新按讚數等統計資料
                        Task {
                            await viewModel.fetchArticles()
                        }
                    }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchArticles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArticlePublished"))) { _ in
            Task {
                await viewModel.fetchArticles()
            }
        }
        .sheet(isPresented: $showDrafts) {
            DraftsView()
        }
    }
    
    // MARK: - 頂部導航欄
    private var topNavigationBar: some View {
        HStack {
            Text("資訊")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.gray900)
            
            Spacer()
            
            // 草稿按鈕
            Button(action: {
                showDrafts = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                    Text("草稿")
                        .font(.subheadline)
                }
                .foregroundColor(.brandGreen)
            }
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
            
            TextField("搜尋文章或作者…", text: $searchText)
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
    
    // MARK: - 熱門關鍵字篩選
    private var keywordFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingSM) {
                if viewModel.trendingKeywords.isEmpty {
                    // 顯示"無"選項當沒有熱門關鍵字時
                    KeywordChip(
                        title: "無",
                        isSelected: true
                    ) {
                        // 無操作
                    }
                } else {
                    ForEach(viewModel.trendingKeywords.indices, id: \.self) { index in
                        KeywordChip(
                            title: viewModel.trendingKeywords[index],
                            isSelected: selectedKeywordIndex == index
                        ) {
                            withAnimation(.easeInOut(duration: DesignTokens.animationFast)) {
                                selectedKeywordIndex = index
                                viewModel.filterByKeyword(viewModel.trendingKeywords[index])
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
        }
        .padding(.vertical, DesignTokens.spacingSM)
    }

    
    // MARK: - 文章列表
    private var articlesList: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.danger)
                    
                    Text("載入失敗")
                        .font(.headline)
                        .foregroundColor(.gray900)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.gray600)
                        .multilineTextAlignment(.center)
                    
                    Button("重試") {
                        Task {
                            await viewModel.fetchArticles()
                        }
                    }
                    .brandButtonStyle()
                }
                .padding(DesignTokens.spacingMD)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingSM) {
                        ForEach(viewModel.filteredArticles(search: searchText)) { article in
                            ArticleCardView(article: article)
                                .onTapGesture {
                                    selectedArticle = article
                                    showArticleDetail = true
                                }
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.bottom, DesignTokens.spacingXL)
                }
            }
        }
        .background(Color.gray100)
    }
    
    // MARK: - Medium 風格圓形浮動按鈕
    private var mediumStyleFloatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    showArticleEditor = true
                }) {
                    ZStack {
                        // 主圓形背景
                        Circle()
                            .fill(Color.brandGreen)
                            .frame(width: 56, height: 56)
                            .shadow(
                                color: Color.black.opacity(0.15),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        
                        // 加號圖標
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showArticleEditor)
                .accessibilityLabel("寫文章")
                .accessibilityHint("點擊開始撰寫新文章")
                .padding(.trailing, 20)
                .padding(.bottom, 100) // 避免與底部 Tab Bar 重疊
            }
        }
    }
}

// MARK: - 關鍵字標籤
struct KeywordChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brandGreen : Color.gray200)
                .foregroundColor(isSelected ? .white : .gray600)
                .cornerRadius(16)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(isSelected ? "目前關鍵字：\(title)" : "關鍵字：\(title)")
        .accessibilityHint("篩選包含\(title)關鍵字的文章")
    }
}

#Preview {
    InfoView()
}
