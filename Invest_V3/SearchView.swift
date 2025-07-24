import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedScope = SearchScope.all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.gray600)
                    }
                    
                    Spacer()
                    
                    Text("搜尋")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    
                    Spacer()
                    
                    // 佔位符，保持標題居中
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                
                // 搜尋框
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray500)
                        
                        TextField("搜尋群組、用戶或文章...", text: $searchText)
                            .font(.body)
                            .onSubmit {
                                Task {
                                    await viewModel.search(query: searchText, scope: selectedScope)
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.gray200)
                    .cornerRadius(10)
                    
                    if !searchText.isEmpty {
                        Button("搜尋") {
                            Task {
                                await viewModel.search(query: searchText, scope: selectedScope)
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.brandGreen)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray300),
                    alignment: .bottom
                )
                
                // 搜尋範圍選擇
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Button(action: {
                                selectedScope = scope
                                if !searchText.isEmpty {
                                    Task {
                                        await viewModel.search(query: searchText, scope: scope)
                                    }
                                }
                            }) {
                                Text(scope.displayName)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedScope == scope ? Color.brandGreen : Color.gray200)
                                    .foregroundColor(selectedScope == scope ? .white : .gray600)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray300),
                    alignment: .bottom
                )
                
                // 搜尋結果
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if searchText.isEmpty && !viewModel.hasSearched {
                    // 初始狀態
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray400)
                        
                        Text("開始搜尋")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray600)
                        
                        Text("輸入關鍵字搜尋投資群組、用戶或文章")
                            .font(.body)
                            .foregroundColor(.gray500)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    // 無結果狀態
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray400)
                        
                        Text("找不到相關結果")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray600)
                        
                        Text("試試其他關鍵字或調整搜尋範圍")
                            .font(.body)
                            .foregroundColor(.gray500)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    // 搜尋結果列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.searchResults) { result in
                                SearchResultRowView(result: result)
                                
                                if result.id != viewModel.searchResults.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .background(Color.gray100)
        }
    }
}

// MARK: - 搜尋結果行視圖
struct SearchResultRowView: View {
    let result: SearchResult
    
    var body: some View {
        Button(action: {
            handleSearchResultTap()
        }) {
            HStack(spacing: 12) {
                // 結果圖標
                ZStack {
                    Circle()
                        .fill(Color(hex: result.type.color))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: result.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // 結果內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray900)
                        .lineLimit(1)
                    
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.gray600)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 箭頭
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleSearchResultTap() {
        print("🔍 [SearchResult] 點擊搜尋結果: \(result.title) (類型: \(result.type))")
        
        // 根據結果類型處理點擊事件
        switch result.type {
        case .group:
            if let groupId = result.relatedId, let uuid = UUID(uuidString: groupId) {
                print("🔍 導航到群組: \(uuid)")
                // TODO: 實現群組導航邏輯
                // NavigationManager.shared.navigateToGroup(uuid)
            }
            
        case .user:
            if let userId = result.relatedId {
                print("🔍 導航到用戶檔案: \(userId)")
                // TODO: 實現用戶檔案導航邏輯
                // NavigationManager.shared.navigateToUserProfile(userId)
            }
            
        case .article:
            if let articleId = result.relatedId {
                print("🔍 導航到文章: \(articleId)")
                // TODO: 實現文章導航邏輯
                // NavigationManager.shared.navigateToArticle(articleId)
            }
        }
    }
}

// MARK: - 搜尋範圍
enum SearchScope: String, CaseIterable {
    case all = "all"
    case groups = "groups"
    case users = "users"
    case articles = "articles"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .groups:
            return "群組"
        case .users:
            return "用戶"
        case .articles:
            return "文章"
        }
    }
}

// MARK: - 搜尋結果模型
struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let type: SearchResultType
    let relatedId: String? // 關聯的實際物件ID (群組ID、用戶ID、文章ID)
    
    init(title: String, subtitle: String, type: SearchResultType, relatedId: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.relatedId = relatedId
    }
}

enum SearchResultType {
    case group
    case user
    case article
    
    var iconName: String {
        switch self {
        case .group:
            return "person.2.fill"
        case .user:
            return "person.fill"
        case .article:
            return "doc.text.fill"
        }
    }
    
    var color: String {
        switch self {
        case .group:
            return "#00B900" // brandGreen
        case .user:
            return "#007BFF" // blue
        case .article:
            return "#FD7E14" // brandOrange
        }
    }
}

// MARK: - 搜尋 ViewModel
@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var hasSearched = false
    
    private let supabaseService = SupabaseService.shared
    
    func search(query: String, scope: SearchScope) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        
        do {
            var results: [SearchResult] = []
            
            switch scope {
            case .all:
                // 綜合搜尋 - 搜尋所有類型
                let (groups, users, articles) = try await supabaseService.searchAll(query: query)
                
                // 轉換群組結果
                for group in groups {
                    results.append(SearchResult(
                        title: group.name,
                        subtitle: "主持人：\(group.host) • \(group.memberCount) 成員",
                        type: .group,
                        relatedId: group.id.uuidString
                    ))
                }
                
                // 轉換用戶結果
                for user in users {
                    results.append(SearchResult(
                        title: user.displayName,
                        subtitle: user.bio ?? "投資愛好者",
                        type: .user,
                        relatedId: user.id.uuidString
                    ))
                }
                
                // 轉換文章結果
                for article in articles {
                    results.append(SearchResult(
                        title: article.title,
                        subtitle: article.summary.isEmpty ? "投資分析文章" : article.summary,
                        type: .article,
                        relatedId: article.id.uuidString
                    ))
                }
                
            case .groups:
                // 只搜尋群組
                let groups = try await supabaseService.searchGroups(query: query)
                for group in groups {
                    results.append(SearchResult(
                        title: group.name,
                        subtitle: "主持人：\(group.host) • \(group.memberCount) 成員",
                        type: .group,
                        relatedId: group.id.uuidString
                    ))
                }
                
            case .users:
                // 只搜尋用戶
                let users = try await supabaseService.searchUsers(query: query)
                for user in users {
                    results.append(SearchResult(
                        title: user.displayName,
                        subtitle: user.bio ?? "投資愛好者",
                        type: .user,
                        relatedId: user.id.uuidString
                    ))
                }
                
            case .articles:
                // 只搜尋文章
                let articles = try await supabaseService.searchArticles(query: query)
                for article in articles {
                    results.append(SearchResult(
                        title: article.title,
                        subtitle: article.summary.isEmpty ? "投資分析文章" : article.summary,
                        type: .article,
                        relatedId: article.id.uuidString
                    ))
                }
            }
            
            self.searchResults = results
            print("🔍 [SearchViewModel] 搜尋 '\(query)' (\(scope.displayName)): 找到 \(results.count) 個結果")
            
        } catch {
            print("❌ [SearchViewModel] 搜尋失敗: \(error.localizedDescription)")
            self.searchResults = []
        }
        
        isSearching = false
    }
}

#Preview {
    SearchView()
} 