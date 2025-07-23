import SwiftUI

struct DraftsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ArticleDraft] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDraft: ArticleDraft?
    @State private var showDraftEditor = false
    
    var body: some View {
        NavigationStack {
            List {
                if drafts.isEmpty {
                    ContentUnavailableView(
                        "沒有草稿",
                        systemImage: "doc.text",
                        description: Text("您還沒有保存任何草稿")
                    )
                } else {
                    ForEach(drafts) { draft in
                        DraftRowView(draft: draft)
                            .onTapGesture {
                                selectedDraft = draft
                                showDraftEditor = true
                            }
                    }
                    .onDelete(perform: deleteDrafts)
                }
            }
            .navigationTitle("草稿")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showDraftEditor) {
            if let draft = selectedDraft {
                DraftEditorView(draft: draft) {
                    // 編輯完成後重新加載草稿
                    loadDrafts()
                }
            }
        }
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
        for index in offsets {
            let draft = drafts[index]
            
            Task {
                do {
                    try await SupabaseService.shared.deleteDraft(draft.id)
                    await MainActor.run {
                        drafts.remove(at: index)
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

// MARK: - Draft Editor View
struct DraftEditorView: View {
    let draft: ArticleDraft
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("草稿編輯")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("這裡將會集成完整的草稿編輯功能")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("標題: \(draft.title)")
                        .font(.headline)
                    
                    Text("分類: \(draft.category)")
                        .font(.subheadline)
                    
                    Text("更新時間: \(draft.updatedAt.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                Button("繼續編輯") {
                    // TODO: 將草稿內容傳遞給 MediumStyleEditor
                    dismiss()
                    onComplete()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.brandGreen)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("草稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DraftsView()
} 