import SwiftUI

struct DraftsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ArticleDraft] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDraftForEditing: ArticleDraft?
    @State private var sortOption: DraftSortOption = .lastModified
    @State private var filterStatus: DraftStatus? = nil
    @State private var searchText = ""
    @State private var showSortOptions = false
    
    // 過濾後的草稿列表
    var filteredDrafts: [ArticleDraft] {
        var result = drafts
        
        // 搜索過濾
        if !searchText.isEmpty {
            result = result.filter { draft in
                let titleMatch = draft.title.localizedCaseInsensitiveContains(searchText)
                let bodyMatch = draft.bodyMD.localizedCaseInsensitiveContains(searchText)
                let categoryMatch = draft.category.localizedCaseInsensitiveContains(searchText)
                return titleMatch || bodyMatch || categoryMatch
            }
        }
        
        // 狀態過濾
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        
        // 排序
        return result.sorted { draft1, draft2 in
            switch sortOption {
            case .lastModified:
                return draft1.updatedAt > draft2.updatedAt
            case .created:
                return draft1.createdAt > draft2.createdAt
            case .title:
                return draft1.title < draft2.title
            case .completion:
                return draft1.completionPercentage > draft2.completionPercentage
            case .wordCount:
                return draft1.wordCount > draft2.wordCount
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索和過濾欄
                searchAndFilterSection
                
                // 草稿統計欄
                if !drafts.isEmpty {
                    draftsStatsSection
                }
                
                // 主要內容
                if filteredDrafts.isEmpty && !drafts.isEmpty {
                    // 有草稿但過濾後為空
                    ContentUnavailableView(
                        "沒有符合條件的草稿",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("嘗試調整搜索或過濾條件")
                    )
                } else if drafts.isEmpty {
                    // 完全沒有草稿
                    ContentUnavailableView(
                        "沒有草稿",
                        systemImage: "doc.text",
                        description: Text("您還沒有保存任何草稿")
                    )
                } else {
                    // 草稿列表
                    List {
                        ForEach(filteredDrafts) { draft in
                            EnhancedDraftRowView(draft: draft)
                                .onTapGesture {
                                    selectedDraftForEditing = draft
                                }
                        }
                        .onDelete(perform: deleteDrafts)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("草稿 (\(drafts.count))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showSortOptions = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadDrafts()
        }
        .overlay {
            if isLoading {
                ProgressView("加載中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .alert("錯誤", isPresented: .constant(errorMessage != nil)) {
            Button("確定") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .fullScreenCover(item: $selectedDraftForEditing) { draft in
            MediumStyleEditor(existingDraft: draft) {
                // 編輯完成後重新加載草稿
                loadDrafts()
            }
        }
        .actionSheet(isPresented: $showSortOptions) {
            ActionSheet(
                title: Text("排序方式"),
                buttons: DraftSortOption.allCases.map { option in
                    .default(Text(option.displayName)) {
                        sortOption = option
                    }
                } + [.cancel()]
            )
        }
    }
    
    // MARK: - UI Components
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索草稿...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // 狀態過濾器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "全部",
                        isSelected: filterStatus == nil
                    ) {
                        filterStatus = nil
                    }
                    
                    ForEach(DraftStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: filterStatus == status,
                            color: status.color
                        ) {
                            filterStatus = filterStatus == status ? nil : status
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var draftsStatsSection: some View {
        HStack(spacing: 16) {
            DraftStatCard(
                title: "總草稿",
                value: "\(drafts.count)",
                icon: "doc.text"
            )
            
            DraftStatCard(
                title: "待完成",
                value: "\(drafts.filter { $0.status != .readyToPublish }.count)",
                icon: "pencil"
            )
            
            DraftStatCard(
                title: "可發布",
                value: "\(drafts.filter { $0.status == .readyToPublish }.count)",
                icon: "checkmark.circle"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func loadDrafts() {
        // Preview 安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Preview 模式：使用模擬數據
            drafts = [
                ArticleDraft(
                    title: "模擬草稿 1",
                    subtitle: "這是一個測試草稿",
                    bodyMD: "# 模擬內容",
                    category: "投資分析"
                ),
                ArticleDraft(
                    title: "模擬草稿 2",
                    bodyMD: "## 另一個測試草稿",
                    category: "市場觀點"
                )
            ]
            isLoading = false
            return
        }
        #endif
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedDrafts = try await SupabaseService.shared.fetchUserDrafts()
                await MainActor.run {
                    self.drafts = fetchedDrafts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ 加載草稿失敗: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteDrafts(offsets: IndexSet) {
        let draftsToDelete = offsets.map { filteredDrafts[$0] }
        
        for draft in draftsToDelete {
            Task {
                do {
                    try await SupabaseService.shared.deleteDraft(draft.id)
                    await MainActor.run {
                        drafts.removeAll { $0.id == draft.id }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "刪除草稿失敗: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

struct DraftRowView: View {
    let draft: ArticleDraft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.title.isEmpty ? "未命名草稿" : draft.title)
                .font(.headline)
                .lineLimit(2)
            
            if let subtitle = draft.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack {
                Text(draft.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                Spacer()
                
                Text(draft.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Enhanced Draft Row View

struct EnhancedDraftRowView: View {
    let draft: ArticleDraft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題和狀態
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.title.isEmpty ? "未命名草稿" : draft.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if let subtitle = draft.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 狀態標籤
                HStack(spacing: 6) {
                    Image(systemName: draft.status.icon)
                        .font(.caption)
                    Text(draft.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(draft.status.color.opacity(0.1))
                .foregroundColor(draft.status.color)
                .cornerRadius(8)
            }
            
            // 完成進度條
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("完成度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(draft.completionPercentage * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: draft.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: draft.status.color))
                    .frame(height: 4)
            }
            
            // 關鍵字標籤區域（獨立一行）
            if !draft.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(draft.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 1) // 防止邊緣裁剪
                }
            } else {
                // 如果沒有關鍵字，顯示分類
                HStack {
                    Text(draft.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                    Spacer()
                }
            }
            
            // 統計信息和元數據（另一行）
            HStack {
                // 統計信息
                HStack(spacing: 12) {
                    Label("\(draft.wordCount)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(draft.estimatedReadingTime) 分鐘", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 更新時間
                Text(draft.lastModifiedFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Support Components

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DraftStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Draft Sort Options

enum DraftSortOption: String, CaseIterable {
    case lastModified = "last_modified"
    case created = "created"
    case title = "title"
    case completion = "completion"
    case wordCount = "word_count"
    
    var displayName: String {
        switch self {
        case .lastModified:
            return "最近修改"
        case .created:
            return "創建時間"
        case .title:
            return "標題"
        case .completion:
            return "完成度"
        case .wordCount:
            return "字數"
        }
    }
}

#Preview {
    DraftsView()
} 