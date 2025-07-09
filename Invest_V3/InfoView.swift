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
    @State private var selectedCategory = 0
    @State private var showArticleEditor = false
    @State private var selectedArticle: Article?
    @State private var showArticleDetail = false
    
    private let categories = ["全部", "投資分析", "市場趨勢", "個股研究", "加密貨幣"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄 (44px)
                topNavigationBar
                
                // 搜尋框 (343×40 pt)
                searchBar
                
                // 類別篩選
                categoryFilter
                
                // 文章列表
                articlesList
            }
            .background(Color.gray100)
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
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchArticles()
            }
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
            
            Button(action: {
                showArticleEditor = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.brandGreen)
                    .font(.title2)
                    .fontWeight(.medium)
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
    
    // MARK: - 類別篩選
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(categories.indices, id: \.self) { index in
                    CategoryChip(
                        title: categories[index],
                        isSelected: selectedCategory == index
                    ) {
                        withAnimation(.easeInOut(duration: DesignTokens.animationFast)) {
                            selectedCategory = index
                            viewModel.filterByCategory(categories[index])
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
}

#Preview {
    InfoView()
}
