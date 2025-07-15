import SwiftUI
import UniformTypeIdentifiers

// MARK: - Action enum sent back to the caller

enum PublishSheetAction {
    case preview
    case publish
}

// MARK: - PublishSettingsSheet

struct PublishSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    // 2-way binding to the editor's draft
    @Binding var draft: ArticleDraft

    /// Callback for share/publish triggers
    var onAction: (PublishSheetAction) -> Void

    // MARK: - Local state
    @State private var newTag: String = ""
    @State private var showTagLimitAlert = false
    @State private var coverImageURL: String?
    @State private var showingImagePicker = false
    
    private let maxTags = 5
    private let maxTitleLength = 100
    private let maxSubtitleLength = 80
    
    // 顏色配置
    private var backgroundColor: Color {
        colorScheme == .dark ? .gray100 : .white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .gray900 : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .gray600 : .secondary
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    // 封面圖片
                    coverImageSection
                    
                    // 標題和副標題
                    titleSection
                    
                    // 標籤管理
                    tagsSection
                    
                    // 操作按鈕
                    actionButtonsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.top, DesignTokens.spacingMD)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("發布設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                    .foregroundColor(textColor)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("發布") {
                        handlePublish()
                    }
                    .foregroundColor(.brandGreen)
                    .fontWeight(.semibold)
                    .disabled(draft.title.isEmpty)
                }
            }
            .alert("標籤數量已達上限 (5)", isPresented: $showTagLimitAlert) {
                Button("確定", role: .cancel) {}
            }
        }
    }

    // MARK: - 封面圖片區域
    private var coverImageSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("封面圖片")
                .font(.headline)
                .foregroundColor(textColor)
            
            if let coverImageURL = coverImageURL {
                AsyncImage(url: URL(string: coverImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                        .fill(Color.gray200)
                        .overlay(
                            ProgressView()
                                .tint(.brandGreen)
                        )
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(DesignTokens.cornerRadius)
                .overlay(
                    Button("更換") {
                        showingImagePicker = true
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(DesignTokens.cornerRadiusSM)
                    .padding(DesignTokens.spacingSM),
                    alignment: .topTrailing
                )
            } else {
                Button(action: { 
                    // 模擬圖片選擇
                    coverImageURL = "https://images.pexels.com/photos/261763/pexels-photo-261763.jpeg?auto=compress&cs=tinysrgb&w=800"
                }) {
                    VStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.gray600)
                        
                        Text("添加封面圖片")
                            .font(.subheadline)
                            .foregroundColor(.gray600)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.gray100)
                    .cornerRadius(DesignTokens.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                            .stroke(Color.gray300, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - 標題和副標題區域
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("標題與副標題")
                .font(.headline)
                .foregroundColor(textColor)
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                TextField("文章標題 (必填)", text: $draft.title)
                    .font(.title3)
                    .foregroundColor(textColor)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .background(Color.gray100)
                    .cornerRadius(DesignTokens.cornerRadiusSM)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM)
                            .stroke(draft.title.isEmpty ? Color.danger : Color.clear, lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    Text("\(draft.title.count)/\(maxTitleLength)")
                        .font(.caption)
                        .foregroundColor(draft.title.count > maxTitleLength ? .danger : secondaryTextColor)
                }
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                TextField("副標題 (選填)", text: Binding<String>(
                    get: { draft.subtitle ?? "" },
                    set: { newValue in 
                        draft.subtitle = newValue.isEmpty ? nil : newValue 
                    }
                ), axis: .vertical)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .lineLimit(2...4)
                    .padding(DesignTokens.spacingSM)
                    .background(Color.gray100)
                    .cornerRadius(DesignTokens.cornerRadiusSM)
                
                HStack {
                    Spacer()
                    Text("\((draft.subtitle ?? "").count)/\(maxSubtitleLength)")
                        .font(.caption)
                        .foregroundColor((draft.subtitle ?? "").count > maxSubtitleLength ? .danger : secondaryTextColor)
                }
            }
        }
    }
    
    // MARK: - 標籤管理區域
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("標籤")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text("\(draft.tags.count)/\(maxTags)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            // 標籤輸入
            HStack(spacing: DesignTokens.spacingSM) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.gray600)
                        .font(.system(size: 16))
                    
                    TextField("輸入標籤", text: $newTag)
                        .onSubmit {
                            addTag()
                        }
                        .disabled(draft.tags.count >= maxTags)
                }
                .padding(DesignTokens.spacingSM)
                .background(Color.gray100)
                .cornerRadius(DesignTokens.cornerRadiusSM)
                
                if !newTag.isEmpty && draft.tags.count < maxTags {
                    Button("添加") {
                        addTag()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGreen)
                }
            }
            
            // 標籤顯示
            if !draft.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(draft.tags, id: \.self) { tag in
                            TagBubbleView(tag: tag) {
                                remove(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            Text("最多可添加 \(maxTags) 個標籤")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
        }
    }
    
    // MARK: - 操作按鈕區域
    private var actionButtonsSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 預覽按鈕
            Button(action: { 
                onAction(.preview)
            }) {
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 16))
                    Text("預覽文章")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingSM)
                .foregroundColor(.brandGreen)
                .background(Color.brandGreen.opacity(0.1))
                .cornerRadius(DesignTokens.cornerRadius)
            }
            .disabled(draft.title.isEmpty)
            
            // 發布按鈕
            Button(action: handlePublish) {
                Text("發布文章")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .foregroundColor(.white)
                    .background(draft.title.isEmpty ? Color.gray400 : Color.brandGreen)
                    .cornerRadius(DesignTokens.cornerRadius)
            }
            .disabled(draft.title.isEmpty)
        }
    }
    
    // MARK: - Helper Methods
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        guard draft.tags.count < maxTags else {
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
    
    private func handlePublish() {
        guard !draft.title.isEmpty else { return }
        
        if draft.title.count > maxTitleLength {
            return
        }
        
        if (draft.subtitle ?? "").count > maxSubtitleLength {
            return
        }
        
        onAction(.publish)
        dismiss()
    }
}

// MARK: - 標籤氣泡視圖
struct TagBubbleView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingXS) {
            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandGreen)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGreen)
            }
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, DesignTokens.spacingXS)
        .background(Color.brandGreen.opacity(0.1))
        .cornerRadius(DesignTokens.cornerRadiusSM)
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
            case .preview:
                print("Preview article")
            case .publish:
                print("Publish article")
            }
        }
    }
}
#endif 