import SwiftUI
import UIKit
import PhotosUI
import Supabase

// MARK: - Medium 風格編輯器
struct MediumStyleEditor: View {
    @State private var title: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var isPaidContent: Bool = false
    @State private var selectedSubtopic: String = "投資分析"
    @State private var keywords: [String] = []
    @State private var currentDraft: ArticleDraft = ArticleDraft()
    @State private var showSettings: Bool = false
    @State private var showPreview: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showTablePicker: Bool = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var titleCharacterCount: Int = 0
    @State private var isPublishing: Bool = false
    
    @StateObject private var articleViewModel = ArticleViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // 字數統計
    private let maxTitleLength = 100
    
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
    
    // 檢查是否有未保存的更改
    private var hasUnsavedChanges: Bool {
        !title.isEmpty || attributedContent.length > 0
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定義導航欄
                customNavigationBar
                
                // 主內容區域
                ScrollView {
                    VStack(spacing: 8) { // 減少間距從 24 到 8
                        // 標題輸入區域
                        titleSection
                        
                        // 付費內容切換（靠右對齊）
                        HStack {
                            Spacer()
                            paidContentToggle
                        }
                        .padding(.horizontal, 16)
                        
                        // 富文本編輯器
                        richTextEditor
                    }
                    .padding(.bottom, 100) // 為鍵盤留出空間
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            PublishSettingsSheet(
                draft: $currentDraft,
                onAction: handlePublishSheetAction
            )
        }
        .onAppear {
            // 初始化 draft
            currentDraft = createDraftFromCurrentState()
        }
        .onChange(of: showSettings) { _, isShowing in
            if isShowing {
                // 打開設定頁面時，從當前狀態創建 draft
                currentDraft = createDraftFromCurrentState()
                print("🔄 打開設定頁面，創建 draft，關鍵字: \(currentDraft.keywords)")
            } else {
                // 關閉設定頁面時，同步關鍵字回編輯器
                keywords = currentDraft.keywords
                print("🔄 關閉設定頁面，同步關鍵字: \(currentDraft.keywords)")
            }
        }
        .sheet(isPresented: $showPreview) {
            PreviewSheet(
                title: title,
                attributedContent: attributedContent,
                isPaid: isPaidContent
            )
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotosPickerItems,
            maxSelectionCount: 1,
            matching: .images
        )
        .sheet(isPresented: $showTablePicker) {
            TableGridPicker { rows, cols in
                insertTable(rows: rows, cols: cols)
            }
        }
        .onChange(of: title) { _, newValue in
            titleCharacterCount = newValue.count
        }
        .onChange(of: selectedPhotosPickerItems) { oldItems, newItems in
            print("📸 onChange 觸發 - 舊: \(oldItems.count), 新: \(newItems.count)")
            
            // 只處理新增的項目
            guard !newItems.isEmpty, newItems.count > oldItems.count else { 
                print("📸 沒有新項目，跳過處理")
                return 
            }
            
            guard let item = newItems.last else { 
                print("📸 沒有找到最新項目")
                return 
            }
            
            print("📸 開始處理圖片...")
            
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        print("📸 插入圖片到編輯器")
                        insertImage(image)
                        // 處理完成後清空選擇
                        selectedPhotosPickerItems.removeAll()
                    }
                } else {
                    print("📸 圖片載入失敗")
                }
            }
        }
    }
    
    // MARK: - 自定義導航欄
    private var customNavigationBar: some View {
        HStack(spacing: 16) {
            // 關閉按鈕
            Button(action: { 
                if hasUnsavedChanges {
                    // TODO: 顯示保存提醒
                }
                dismiss() 
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor)
            }
            
            Spacer()
            
            // 預覽按鈕
            Button("預覽") {
                print("🔍 預覽按鈕點擊，attributedContent.length: \(attributedContent.length)")
                print("🔍 標題: '\(title)'")
                showPreview = true
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.brandBlue)
            
            // 發佈按鈕
            Button("發佈") {
                showSettings = true
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.brandGreen)
            .cornerRadius(20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
    }
    
    // MARK: - 標題輸入區域
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("告訴我們你的想法...", text: $title)
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundColor(textColor)
                .textFieldStyle(PlainTextFieldStyle())
                .multilineTextAlignment(.leading)
            
            // 字數統計
            HStack {
                Spacer()
                Text("\(titleCharacterCount)/\(maxTitleLength)")
                    .font(.caption)
                    .foregroundColor(titleCharacterCount > maxTitleLength ? .red : secondaryTextColor)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 付費內容切換（靠右對齊）
    private var paidContentToggle: some View {
        HStack(spacing: 8) {
            Text("付費")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(secondaryTextColor)
            
            Toggle("", isOn: $isPaidContent)
                .toggleStyle(SwitchToggleStyle(tint: .brandOrange))
                .scaleEffect(0.8)
        }
    }
    
    // MARK: - 富文本編輯器
    private var richTextEditor: some View {
        RichTextView(attributedText: $attributedContent)
            .frame(minHeight: 400)
            .background(backgroundColor)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowPhotoPicker"))) { _ in
                showPhotoPicker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTablePicker"))) { _ in
                showTablePicker = true
            }
    }
    
    // MARK: - 圖片處理
    private func insertImage(_ image: UIImage) {
        // 通知 RichTextView 插入圖片
        NotificationCenter.default.post(
            name: NSNotification.Name("InsertImage"),
            object: image
        )
    }
    
    // MARK: - 表格處理
    private func insertTable(rows: Int, cols: Int) {
        // 通知 RichTextView 插入表格
        NotificationCenter.default.post(
            name: NSNotification.Name("InsertTable"),
            object: ["rows": rows, "cols": cols]
        )
    }

    /// 將帶有圖片附件的富文本轉換為 Markdown，並將圖片上傳至 Supabase
    private func convertAttributedContentToMarkdown() async -> String {
        var markdown = ""

        // 收集所有區段及對應圖片
        var segments: [(text: String, attachment: NSTextAttachment?)] = []
        attributedContent.enumerateAttributes(in: NSRange(location: 0, length: attributedContent.length)) { attrs, range, _ in
            let text = attributedContent.attributedSubstring(from: range).string
            let attachment = attrs[.attachment] as? NSTextAttachment
            segments.append((text, attachment))
        }

        for segment in segments {
            if let attachment = segment.attachment,
               let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0),
               let data = image.jpegData(compressionQuality: 0.8) {
                let fileName = UUID().uuidString + ".jpg"
                if let url = try? await SupabaseService.shared.uploadArticleImage(data, fileName: fileName) {
                    markdown += "![](\(url))"
                }
            } else {
                markdown += segment.text
            }
        }

        return markdown
    }
    
    // MARK: - 草稿創建
    private func createDraftFromCurrentState() -> ArticleDraft {
        var draft = ArticleDraft()
        draft.title = title
        draft.subtitle = nil
        draft.bodyMD = attributedContent.string
        draft.isFree = !isPaidContent
        draft.category = selectedSubtopic
        draft.keywords = keywords
        draft.createdAt = Date()
        draft.updatedAt = Date()
        print("📝 創建草稿，初始關鍵字: \(keywords)")
        return draft
    }
    
    private func handlePublishSheetAction(_ action: PublishSheetAction) {
        switch action {
        case .preview:
            showPreview = true
        case .publish:
            publishArticle()
        case .shareDraft(let url):
            shareDraftWithURL(url)
        }
    }
    
    private func handlePublishAction(_ action: PublishAction) {
        switch action {
        case .saveDraft:
            saveDraft()
        case .publish:
            publishArticle()
        case .preview:
            showPreview = true
        case .shareDraft:
            shareDraft()
        }
    }
    
    // MARK: - 業務邏輯
    private func saveDraft() {
        // 保存草稿到本地或 Supabase
        var draft = createDraftFromCurrentState()
        Task {
            draft.bodyMD = await convertAttributedContentToMarkdown()
        }
        // TODO: 實現草稿保存邏輯
        print("保存草稿: \(draft.title)")
    }
    
    private func publishArticle() {
        guard !title.isEmpty else {
            print("❌ 標題不能為空")
            return
        }
        
        guard attributedContent.length > 0 else {
            print("❌ 內容不能為空")
            return
        }
        
        isPublishing = true

        Task {
            do {
                var draft = createDraftFromCurrentState()
                draft.bodyMD = await convertAttributedContentToMarkdown()
                let _ = try await articleViewModel.publishArticle(from: draft)
                
                await MainActor.run {
                    isPublishing = false
                    // 通知 InfoView 刷新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ArticlePublished"),
                        object: nil
                    )
                    dismiss() // 發布成功後關閉編輯器
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    print("❌ 發布失敗: \(error)")
                }
            }
        }
    }
    
    private func shareDraft() {
        // 生成分享鏈接
        let draftId = UUID().uuidString
        let shareURL = "supabase://draft/\(draftId)"
        
        // 使用 UIActivityViewController 分享
        let activityVC = UIActivityViewController(
            activityItems: [shareURL, title],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func shareDraftWithURL(_ url: URL) {
        // 使用提供的 URL 分享草稿
        let activityVC = UIActivityViewController(
            activityItems: [url, title],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    // MARK: - 預覽視圖
    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 標題預覽
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("請輸入標題")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(secondaryTextColor.opacity(0.6))
                        .italic()
                }
                
                // 分類和付費標記
                HStack {
                    Text(selectedSubtopic)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandBlue.opacity(0.1))
                        .cornerRadius(12)
                    
                    if isPaidContent {
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                            Text("付費內容")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.brandOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandOrange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // 關鍵字預覽
                if !keywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.brandGreen)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.brandGreen.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // 內容預覽
                if attributedContent.length > 0 {
                    RichTextPreviewView(attributedText: attributedContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("開始寫作...")
                        .font(.system(size: 18))
                        .foregroundColor(secondaryTextColor.opacity(0.6))
                        .italic()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(backgroundColor)
    }
}

// MARK: - 預覽 Sheet
struct PreviewSheet: View {
    let title: String
    let attributedContent: NSAttributedString
    let isPaid: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? .gray100 : .white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .gray900 : .black
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 標題
                    Text(title)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 付費標記
                    if isPaid {
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                            Text("付費內容")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.brandOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandOrange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // 內容 - 使用富文本顯示
                    if attributedContent.length > 0 {
                        RichTextPreviewView(attributedText: attributedContent)
                            .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
                            .border(Color.red, width: 1) // 調試邊框
                    } else {
                        Text("尚無內容...")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("預覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(textColor)
                }
            }
        }
    }
}

// MARK: - 富文本預覽視圖
struct RichTextPreviewView: UIViewRepresentable {
    let attributedText: NSAttributedString
    
    init(attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }
    
    // 兼容舊版本的字符串初始化器
    init(content: String) {
        self.attributedText = NSAttributedString(string: content, attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label
        ])
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = UIColor.clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        
        // 設置默認字體作為備選，但不覆蓋 NSAttributedString 的格式
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        
        print("🔍 makeUIView - textView created with frame: \(textView.frame)")
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        print("🔍 updateUIView - attributedText.length: \(attributedText.length)")
        print("🔍 updateUIView - attributedText.string: '\(attributedText.string.prefix(100))'")
        
        uiView.attributedText = attributedText
        
        // 強制重新佈局
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
        
        print("🔍 updateUIView - uiView.attributedText.length: \(uiView.attributedText?.length ?? 0)")
    }
}

// MARK: - 發佈動作
enum PublishAction {
    case saveDraft
    case publish
    case preview
    case shareDraft
}

#Preview {
    MediumStyleEditor()
} 