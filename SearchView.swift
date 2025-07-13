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
            // 處理點擊搜尋結果
            print("點擊搜尋結果: \(result.title)")
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
    
    func search(query: String, scope: SearchScope) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        
        // 模擬網路延遲
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        // 模擬搜尋結果 - 實際應該從 Supabase 搜尋
        var results: [SearchResult] = []
        
        let lowercasedQuery = query.lowercased()
        
        // 模擬群組搜尋結果
        if scope == .all || scope == .groups {
            if "科技股".contains(lowercasedQuery) || "tech".contains(lowercasedQuery) {
                results.append(SearchResult(
                    title: "科技股挑戰賽",
                    subtitle: "主持人：投資大師Tom • 回報率：+18.5% • 25成員",
                    type: .group
                ))
            }
            
            if "價值投資".contains(lowercasedQuery) || "value".contains(lowercasedQuery) {
                results.append(SearchResult(
                    title: "價值投資學院",
                    subtitle: "主持人：李分析師 • 回報率：+12.3% • 18成員",
                    type: .group
                ))
            }
        }
        
        // 模擬用戶搜尋結果
        if scope == .all || scope == .users {
            if "tom".contains(lowercasedQuery) || "投資大師".contains(lowercasedQuery) {
                results.append(SearchResult(
                    title: "投資大師Tom",
                    subtitle: "本週排名第1 • 回報率：+18.5%",
                    type: .user
                ))
            }
            
            if "lisa".contains(lowercasedQuery) || "環保".contains(lowercasedQuery) {
                results.append(SearchResult(
                    title: "環保投資者Lisa",
                    subtitle: "本週排名第2 • 回報率：+12.3%",
                    type: .user
                ))
            }
        }
        
        // 模擬文章搜尋結果
        if scope == .all || scope == .articles {
            if "台積電".contains(lowercasedQuery) || "2330".contains(lowercasedQuery) {
                results.append(SearchResult(
                    title: "台積電Q4財報分析",
                    subtitle: "深度解析台積電最新財報數據與未來展望",
                    type: .article
                ))
            }
            
            if "投資策略".contains(lowercasedQuery) || "strategy".contains(lowercasedQuery) {
                results.append(SearchResult(
                    title: "2024年投資策略指南",
                    subtitle: "專家分享新年度投資布局與風險控制",
                    type: .article
                ))
            }
        }
        
        self.searchResults = results
        isSearching = false
    }
}

#Preview {
    SearchView()
} 