import SwiftUI
import UniformTypeIdentifiers

// MARK: - Action enum sent back to the caller

enum PublishSheetAction {
    case shareDraft(URL)
    case publish
}

// MARK: - PublishSettingsSheet

struct PublishSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    // 2-way binding to the editor's draft
    @Binding var draft: ArticleDraft

    /// Callback for share/publish triggers
    var onAction: (PublishSheetAction) -> Void

    // MARK: - Local state for tag field
    @State private var newTag: String = ""
    @State private var showTagLimitAlert = false
    @State private var showShareSuccess = false

    // MARK: - Share-draft link (auto-generated)
    private var draftURL: URL {
        URL(string: "https://investv3.com/draft/\(draft.id.uuidString)")!
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // ----- Publication section -----
                Section("發佈到") {
                    Picker("選擇發佈平台", selection: $draft.publication) {
                        Text("— 個人 —").tag(Publication?.none)
                        ForEach(Publication.samplePublications) { pub in
                            Text(pub.name).tag(Publication?.some(pub))
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if let publication = draft.publication {
                        Text(publication.description ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // ----- Display title / subtitle override -----
                Section("顯示標題與副標題") {
                    TextField("文章標題", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                    TextField("副標題（可選）", text: Binding<String>(
                        get: { draft.subtitle ?? "" },
                        set: { newValue in 
                            draft.subtitle = newValue.isEmpty ? nil : newValue 
                        }
                    ))
                        .textFieldStyle(.roundedBorder)
                }

                // ----- Tags (最多五個) -----
                Section(header: Text("標籤 (最多 5 個)")) {
                    tagChips
                    tagInputField
                }

                // ----- Utilities -----
                Section("工具") {
                    Button {
                        // 複製連結到剪貼板
                        UIPasteboard.general.string = draftURL.absoluteString
                        showShareSuccess = true
                        
                        // 3秒後隱藏提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showShareSuccess = false
                        }
                        
                        // 也調用原有的 action
                        onAction(.shareDraft(draftURL))
                    } label: {
                        Label("分享草稿連結", systemImage: "link")
                    }
                    .buttonStyle(.borderless)
                    
                    if showShareSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("連結已複製到剪貼板")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .navigationTitle("發佈設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("發佈") {
                        onAction(.publish)
                        dismiss()
                    }
                    .disabled(!draft.isReadyToPublish)
                    .fontWeight(.semibold)
                }
            }
            .alert("標籤數量已達上限 (5)", isPresented: $showTagLimitAlert) {
                Button("確定", role: .cancel) {}
            }
        }
    }

    // MARK: - Tag subviews

    private var tagChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            ForEach(draft.tags, id: \.self) { tag in
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(tag)
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .onTapGesture { remove(tag) }
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                    
                    // 關注人數
                    Text("\(getFollowersCount(for: tag)) 人關注")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var tagInputField: some View {
        HStack {
            TextField("新增標籤…", text: $newTag)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTag)
            Button("添加") { addTag() }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty || draft.tags.count >= 5)
                .buttonStyle(.bordered)
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        guard draft.tags.count < 5 else {
            showTagLimitAlert = true
            return
        }
        if !draft.tags.contains(tag) {
            draft.tags.append(tag)
        }
        newTag = ""
    }

    private func remove(_ tag: String) {
        draft.tags.removeAll { $0 == tag }
    }
    
    private func getFollowersCount(for tag: String) -> Int {
        // 模擬關注人數數據
        let mockData: [String: Int] = [
            "投資分析": 1234,
            "股票": 2567,
            "台積電": 3456,
            "科技股": 1890,
            "金融股": 1567,
            "ETF": 2234,
            "加密貨幣": 1678,
            "房地產": 987,
            "基金": 1345,
            "債券": 765
        ]
        return mockData[tag] ?? Int.random(in: 100...2000)
    }
}

// MARK: - A simple flow layout for tag chips

struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: Content

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder _ content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: calculateHeight(in: 350)) // Estimate height
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            content
                .alignmentGuide(.leading) { d in
                    if abs(width - d.width) > g.size.width {
                        width = 0
                        height -= d.height + spacing
                    }
                    let result = width
                    if content is EmptyView { 
                        width = 0 
                    } else { 
                        width -= d.width + spacing 
                    }
                    return result
                }
                .alignmentGuide(.top) { _ in height }
        }
    }
    
    private func calculateHeight(in width: CGFloat) -> CGFloat {
        // Simple height calculation - can be improved
        return 60
    }
}

// MARK: - Preview

#if DEBUG
struct PublishSettingsSheet_Previews: PreviewProvider {
    @State static var draft = ArticleDraft(
        title: "SwiftUI 表格視圖實作",
        subtitle: "使用原生元件打造 Markdown 編輯器",
        bodyMD: "這是一篇關於如何在 SwiftUI 中實作表格視圖的文章..."
    )
    
    static var previews: some View {
        PublishSettingsSheet(draft: $draft) { action in
            switch action {
            case .shareDraft(let url):
                print("Share draft: \(url)")
            case .publish:
                print("Publish article")
            }
        }
    }
}
#endif 