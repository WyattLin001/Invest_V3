import SwiftUI
import UIKit
import PhotosUI

// MARK: - Medium 風格編輯器
struct MediumStyleEditor: View {
    @State private var title: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var isPaidContent: Bool = false
    @State private var selectedSubtopic: String = "投資分析"
    @State private var keywords: [String] = []
    @State private var showSettings: Bool = false
    @State private var showPreview: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showTablePicker: Bool = false
    @State private var selectedImages: [PhotosPickerItem] = []
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
                draft: .constant(createDraftFromCurrentState()),
                onAction: handlePublishSheetAction
            )
        }
        .sheet(isPresented: $showPreview) {
            PreviewSheet(
                title: title,
                content: attributedContent.string,
                isPaid: isPaidContent
            )
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedImages,
            maxSelectionCount: 1,
            matching: .images
        )
        .sheet(isPresented: $showTablePicker) {
            TableGridPicker { rows, cols in
                insertTable(rows: rows, cols: cols)
            }
        }
        .sheet(isPresented: $showSettings) {
            PublishSettingsView(
                isPaidContent: $isPaidContent,
                selectedCategory: $selectedSubtopic,
                keywords: $keywords,
                onPublish: {
                    showSettings = false
                    publishArticle()
                }
            )
        }
        .onChange(of: title) { _, newValue in
            titleCharacterCount = newValue.count
        }
        .onChange(of: selectedImages) { _, newImages in
            loadSelectedImages(newImages)
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
    private func loadSelectedImages(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        
        // 立即清空選擇以防止重複處理
        selectedImages = []
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        insertImage(image)
                    }
                }
            case .failure(let error):
                print("圖片載入失敗: \(error)")
            }
        }
    }
    
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
    
    // MARK: - 草稿創建
    private func createDraftFromCurrentState() -> ArticleDraft {
        var draft = ArticleDraft()
        draft.title = title
        draft.subtitle = nil
        draft.bodyMD = attributedContent.string
        draft.isFree = !isPaidContent
        draft.category = selectedSubtopic
        draft.tags = keywords
        return draft
    }
    
    private func handlePublishSheetAction(_ action: PublishSheetAction) {
        switch action {
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
        let draft = createDraftFromCurrentState()
        // TODO: 實現草稿保存邏輯
        print("保存草稿: \(draft.title)")
    }
    
    private func publishArticle() {
        isPublishing = true
        Task {
            let draft = createDraftFromCurrentState()
            await articleViewModel.publishArticle(from: draft)
            
            DispatchQueue.main.async {
                isPublishing = false
                dismiss() // 發布成功後關閉編輯器
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
}

// MARK: - 預覽 Sheet
struct PreviewSheet: View {
    let title: String
    let content: String
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
                    RichTextPreviewView(content: content)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    let content: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = UIColor.clear
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        
        // 設置內容
        textView.text = content
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = content
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