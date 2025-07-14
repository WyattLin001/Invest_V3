import SwiftUI

struct DraftsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ArticleDraft] = []
    
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
    }
    
    private func loadDrafts() {
        // 這裡應該從 UserDefaults 或 Supabase 加載草稿
        // 暫時使用模擬數據
        drafts = []
    }
    
    private func deleteDrafts(offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
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

#Preview {
    DraftsView()
} 