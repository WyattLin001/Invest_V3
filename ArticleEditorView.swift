import SwiftUI

struct ArticleEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var markdown = ""
    @State private var showPreview = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init() {
        // 暫時使用默認值，稍後會從用戶服務獲取
        _markdown = State(initialValue: ArticleTemplate.defaultText(
            author: "當前用戶", 
            email: "user@example.com"
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if showPreview {
                    SimpleMarkdownView(markdown: markdown)
                } else {
                    TextEditor(text: $markdown)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .padding()
                }
            }
            .navigationTitle(showPreview ? "預覽" : "編輯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(showPreview ? "編輯" : "預覽") {
                        withAnimation {
                            showPreview.toggle()
                        }
                    }
                    
                    Button("發佈") {
                        Task {
                            await saveArticle()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .alert("錯誤", isPresented: .constant(errorMessage != nil)) {
                Button("確定") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveArticle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseService.shared.createArticle(
                title: ArticleTemplate.extractTitle(from: markdown),
                content: ArticleTemplate.extractPlainText(from: markdown),
                category: "一般",
                bodyMD: markdown,
                isFree: true
            )
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    ArticleEditorView()
} 