import SwiftUI
import UIKit
import Combine
import Foundation
import PhotosUI
import Supabase

struct NativeRichTextEditor: View {
    @Environment(\.dismiss) var dismiss
    
    // 使用 ArticleDraft 模型
    @State private var draft: ArticleDraft
    @State private var showPreview = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 富文字內容狀態
    @State private var attributedContent = NSMutableAttributedString(string: "")
    @State private var isEditingTitle = false
    
    // 控制草稿提示
    @State private var isShowingDraftAlert = false
    
    // 發佈設定和表格選擇器
    @State private var showPublishSheet = false
    @State private var showTablePicker = false
    
    // 圖片上傳相關
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0.0

    init(draft: ArticleDraft = ArticleDraft()) {
        _draft = State(initialValue: draft)
        _attributedContent = State(initialValue: NSMutableAttributedString(string: draft.bodyMD))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showPreview {
                    previewContent
                } else {
                    editorContent
                }
            }
            .navigationTitle("文章編輯器")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    if hasUnsavedChanges {
                        isShowingDraftAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(showPreview ? "編輯" : "預覽") {
                    if !showPreview {
                        updateDraftContent()
                    }
                    showPreview.toggle()
                }
                
                Button("發佈") {
                    updateDraftContent()
                    showPublishSheet = true
                }
                .disabled(draft.title.isEmpty || attributedContent.length == 0)
            }
        }
        .sheet(isPresented: $showPublishSheet) {
            PublishSettingsSheet(draft: $draft) { action in
                switch action {
                case .publish:
                    Task {
                        await publishArticle(draft)
                    }
                case .shareDraft(let url):
                    shareDraft(url: url)
                }
            }
        }
        .sheet(isPresented: $showTablePicker) {
            TableGridPicker { rows, columns in
                insertTable(rows: rows, columns: columns)
            }
        }
        .alert("未保存的更改", isPresented: $isShowingDraftAlert) {
            Button("保存草稿") {
                saveDraft()
                dismiss()
            }
            Button("放棄更改", role: .destructive) {
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("您有未保存的更改，是否要保存為草稿？")
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
        .onAppear {
            setupInitialContent()
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            if let newItem = newItem {
                handleImageSelection(newItem)
            }
        }
        .overlay(
            // 圖片上傳進度指示器
            Group {
                if isUploadingImage {
                    VStack {
                        ProgressView("正在上傳圖片...", value: uploadProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                        
                        Button("取消") {
                            isUploadingImage = false
                            uploadProgress = 0.0
                        }
                        .foregroundColor(.red)
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                }
            }
        )
    }
    
    // MARK: - Editor Content
    private var editorContent: some View {
        VStack(spacing: 0) {
            // 標題編輯區
            titleEditingArea
            
            // 富文字編輯器
            RichTextView(
                attributedText: $attributedContent,
                onTextChange: { newText in
                    // 同步更新 draft
                    draft.bodyMD = newText.string
                }
            )
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Title Editing Area
    private var titleEditingArea: some View {
        VStack(spacing: 16) {
            // 標題輸入
            if isEditingTitle {
                TextField("文章標題", text: $draft.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .onSubmit {
                        isEditingTitle = false
                    }
            } else {
                Button(action: { isEditingTitle = true }) {
                    HStack {
                        Text(draft.title.isEmpty ? "文章標題" : draft.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(draft.title.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            
            // 副標題輸入
            TextField("副標題（可選）", text: $draft.subtitle)
                .font(.title3)
                .foregroundColor(.secondary)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))
                .opacity(0.3),
            alignment: .bottom
        )
    }
    
    // MARK: - Preview Content
    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 標題預覽
                if !draft.title.isEmpty {
                    Text(draft.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                // 副標題預覽
                if !draft.subtitle.isEmpty {
                    Text(draft.subtitle)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // 標籤預覽
                if !draft.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(draft.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Divider()
                
                // 內容預覽 - 使用 AttributedString 渲染
                AttributedTextView(attributedText: attributedContent)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialContent() {
        if !draft.bodyMD.isEmpty {
            attributedContent = NSMutableAttributedString(string: draft.bodyMD)
            applyBasicStyling()
        }
    }
    
    private func applyBasicStyling() {
        let fullRange = NSRange(location: 0, length: attributedContent.length)
        
        // 設置基本字體
        attributedContent.addAttribute(
            .font,
            value: UIFont.preferredFont(forTextStyle: .body),
            range: fullRange
        )
        
        // 設置文字顏色
        attributedContent.addAttribute(
            .foregroundColor,
            value: UIColor.label,
            range: fullRange
        )
    }
    
    private var hasUnsavedChanges: Bool {
        return !draft.title.isEmpty || attributedContent.length > 0
    }
    
    private func updateDraftContent() {
        draft.bodyMD = attributedContent.string
    }
    
    private func saveDraft() {
        updateDraftContent()
        // TODO: 實現草稿保存邏輯
    }
    
    private func insertTable(rows: Int, columns: Int) {
        guard let textView = getCurrentTextView() else { return }
        
        // 生成 Markdown 表格
        var tableMarkdown = "\n"
        
        // 表頭
        var headerRow = "|"
        for i in 1...columns {
            headerRow += " 標題\(i) |"
        }
        tableMarkdown += headerRow + "\n"
        
        // 分隔線
        var separatorRow = "|"
        for _ in 1...columns {
            separatorRow += " --- |"
        }
        tableMarkdown += separatorRow + "\n"
        
        // 數據行
        for rowIndex in 1...rows {
            var dataRow = "|"
            for colIndex in 1...columns {
                dataRow += " 內容\(rowIndex)-\(colIndex) |"
            }
            tableMarkdown += dataRow + "\n"
        }
        
        tableMarkdown += "\n"
        
        let tableString = NSAttributedString(string: tableMarkdown)
        let selectedRange = textView.selectedRange
        insertAttributedText(tableString, at: selectedRange.location)
    }
    
    private func publishArticle(_ publishedDraft: ArticleDraft) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: 實現發佈邏輯
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "發佈失敗：\(error.localizedDescription)"
            }
        }
    }
    
    private func shareDraft(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }

    private func handleImageSelection(_ item: PhotosPickerItem) {
        isUploadingImage = true
        uploadProgress = 0.0
        
        Task {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                if let imageData = data {
                    let fileName = "\(UUID().uuidString).jpg"
                    let (url, error) = try await SupabaseManager.shared.uploadImage(
                        data: imageData,
                        fileName: fileName,
                        onProgress: { progress in
                            DispatchQueue.main.async {
                                uploadProgress = progress
                            }
                        }
                    )
                    
                    if let error = error {
                        await MainActor.run {
                            errorMessage = "上傳圖片失敗：\(error.localizedDescription)"
                        }
                    } else if let url = url {
                        await MainActor.run {
                            insertImagePlaceholder(url: url)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "選擇圖片失敗：\(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isUploadingImage = false
                uploadProgress = 0.0
            }
        }
    }

    private func insertImagePlaceholder(url: URL) {
        guard let textView = getCurrentTextView() else { return }
        
        // 創建一個佔位符，顯示圖片 URL 的 Markdown 格式
        let markdownImage = "![圖片](\(url.absoluteString))"
        let imageString = NSAttributedString(string: markdownImage)
        
        let selectedRange = textView.selectedRange
        insertAttributedText(imageString, at: selectedRange.location)
        
        // 可選：添加一個換行符
        let newLine = NSAttributedString(string: "\n")
        insertAttributedText(newLine, at: selectedRange.location + imageString.length)
    }
}

// MARK: - RichTextView (UIViewRepresentable)

struct RichTextView: UIViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    let onTextChange: (NSAttributedString) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        
        // 啟用富文字編輯
        textView.isEditable = true
        textView.allowsEditingTextAttributes = true
        
        // 外觀設置 - Medium 風格
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        
        // 行間距設置
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        
        // 內邊距 - 更符合 Medium 的寬鬆感
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 100, right: 20)
        
        // 移除額外的邊距
        textView.textContainer.lineFragmentPadding = 0
        
        // 鍵盤設置
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        
        // 設置工具列
        textView.inputAccessoryView = createToolbar(for: textView, coordinator: context.coordinator)
        
        // 將 textView 實例傳遞給 coordinator
        context.coordinator.textView = textView
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            let selectedRange = uiView.selectedRange
            uiView.attributedText = attributedText
            uiView.selectedRange = selectedRange
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextView
        weak var textView: UITextView?
        
        init(_ parent: RichTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            parent.onTextChange(textView.attributedText)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // 更新工具列按鈕狀態
            updateToolbarButtonStates()
        }
        
        private func updateToolbarButtonStates() {
            // TODO: 根據當前選擇範圍的樣式更新工具列按鈕高亮狀態
        }
    }
    
    // MARK: - Toolbar Creation
    private func createToolbar(for textView: UITextView, coordinator: Coordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.backgroundColor = .systemBackground
        toolbar.barTintColor = .systemBackground
        
        // 創建標題按鈕組
        let headingMenu = UIMenu(title: "標題", children: [
            UIAction(title: "H1", image: UIImage(systemName: "textformat.size.larger")) { _ in
                coordinator.applyH1()
            },
            UIAction(title: "H2", image: UIImage(systemName: "textformat.size")) { _ in
                coordinator.applyH2()
            },
            UIAction(title: "H3", image: UIImage(systemName: "textformat.size.smaller")) { _ in
                coordinator.applyH3()
            }
        ])
        
        let headingButton = UIBarButtonItem(
            image: UIImage(systemName: "textformat"),
            menu: headingMenu
        )
        
        let items = [
            headingButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(
                image: UIImage(systemName: "bold"),
                style: .plain,
                target: coordinator,
                action: #selector(Coordinator.toggleBold)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "italic"),
                style: .plain,
                target: coordinator,
                action: #selector(Coordinator.toggleItalic)
            ),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(
                image: UIImage(systemName: "link"),
                style: .plain,
                target: coordinator,
                action: #selector(Coordinator.insertLink)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "photo"),
                style: .plain,
                target: coordinator,
                action: #selector(Coordinator.insertImage)
            ),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(
                title: "完成",
                style: .done,
                target: coordinator,
                action: #selector(Coordinator.dismissKeyboard)
            )
        ]
        
        toolbar.setItems(items, animated: false)
        return toolbar
    }
}

// MARK: - Coordinator Actions Extension
extension RichTextView.Coordinator {
    @objc func applyH1() {
        applyHeadingStyle(level: 1)
    }
    
    @objc func applyH2() {
        applyHeadingStyle(level: 2)
    }
    
    @objc func applyH3() {
        applyHeadingStyle(level: 3)
    }
    
    @objc func toggleBold() {
        toggleTextStyle(isBold: true)
    }
    
    @objc func toggleItalic() {
        toggleTextStyle(isItalic: true)
    }
    
    @objc func insertLink() {
        insertLinkPlaceholder()
    }
    
    @objc func insertImage() {
        // 觸發圖片選擇器
        DispatchQueue.main.async {
            self.parent.showImagePicker = true
        }
    }
    
    @objc func dismissKeyboard() {
        textView?.resignFirstResponder()
    }
    
    // MARK: - Helper Methods
    
    private func applyHeadingStyle(level: Int) {
        guard let textView = getCurrentTextView() else { return }
        
        let selectedRange = textView.selectedRange
        let lineRange = (textView.text as NSString).lineRange(for: selectedRange)
        
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        // 移除現有的標題樣式
        mutableText.removeAttribute(.font, range: lineRange)
        
        // 應用新的標題樣式
        let fontSize: CGFloat
        let weight: UIFont.Weight
        
        switch level {
        case 1:
            fontSize = 28
            weight = .bold
        case 2:
            fontSize = 22
            weight = .bold
        case 3:
            fontSize = 18
            weight = .semibold
        default:
            fontSize = 17
            weight = .regular
        }
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        mutableText.addAttribute(.font, value: font, range: lineRange)
        mutableText.addAttribute(.foregroundColor, value: UIColor.label, range: lineRange)
        
        // 更新文本並保持選擇範圍
        textView.attributedText = mutableText
        textView.selectedRange = selectedRange
        
        // 通知父組件更新
        parent.attributedText = NSMutableAttributedString(attributedString: mutableText)
        parent.onTextChange(mutableText)
    }
    
    private func toggleTextStyle(isBold: Bool = false, isItalic: Bool = false) {
        guard let textView = getCurrentTextView() else { return }
        
        let selectedRange = textView.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        if selectedRange.length == 0 {
            // 沒有選擇文字，設置輸入屬性
            var typingAttributes = textView.typingAttributes
            
            if let currentFont = typingAttributes[.font] as? UIFont {
                var newFont = currentFont
                
                if isBold {
                    newFont = currentFont.isBold ? currentFont.withoutBold() : currentFont.withBold()
                }
                
                if isItalic {
                    newFont = currentFont.isItalic ? currentFont.withoutItalic() : currentFont.withItalic()
                }
                
                typingAttributes[.font] = newFont
            }
            
            textView.typingAttributes = typingAttributes
        } else {
            // 有選擇文字，應用樣式到選擇範圍
            if isBold {
                toggleBoldInRange(mutableText, range: selectedRange)
            }
            
            if isItalic {
                toggleItalicInRange(mutableText, range: selectedRange)
            }
            
            textView.attributedText = mutableText
            textView.selectedRange = selectedRange
            
            parent.attributedText = NSMutableAttributedString(attributedString: mutableText)
            parent.onTextChange(mutableText)
        }
    }
    
    private func toggleBoldInRange(_ attributedText: NSMutableAttributedString, range: NSRange) {
        attributedText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let font = value as? UIFont {
                let newFont = font.isBold ? font.withoutBold() : font.withBold()
                attributedText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
    }
    
    private func toggleItalicInRange(_ attributedText: NSMutableAttributedString, range: NSRange) {
        attributedText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let font = value as? UIFont {
                let newFont = font.isItalic ? font.withoutItalic() : font.withItalic()
                attributedText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
    }
    
    private func insertLinkPlaceholder() {
        guard let textView = getCurrentTextView() else { return }
        
        let linkText = "連結文字"
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        
        let attributedLink = NSAttributedString(string: linkText, attributes: linkAttributes)
        insertAttributedText(attributedLink, at: textView.selectedRange.location)
    }
    
    private func insertImagePlaceholder() {
        guard let textView = getCurrentTextView() else { return }
        
        // 創建圖片佔位符
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: "photo.fill")?.withTintColor(.systemGray3)
        
        // 設置圖片大小
        let imageSize = CGSize(width: 60, height: 44)
        attachment.bounds = CGRect(origin: .zero, size: imageSize)
        
        let imageString = NSAttributedString(attachment: attachment)
        insertAttributedText(imageString, at: textView.selectedRange.location)
    }
    
    private func insertAttributedText(_ attributedText: NSAttributedString, at location: Int) {
        guard let textView = getCurrentTextView() else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        mutableText.insert(attributedText, at: location)
        
        textView.attributedText = mutableText
        textView.selectedRange = NSRange(location: location + attributedText.length, length: 0)
        
        parent.attributedText = NSMutableAttributedString(attributedString: mutableText)
        parent.onTextChange(mutableText)
    }
    
    private func getCurrentTextView() -> UITextView? {
        return textView
    }
}

// MARK: - UIFont Extensions for Bold/Italic
extension UIFont {
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    func withBold() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert(.traitBold)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func withoutBold() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.remove(.traitBold)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func withItalic() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert(.traitItalic)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func withoutItalic() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.remove(.traitItalic)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - AttributedTextView for Preview
struct AttributedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
    }
}

// MARK: - Preview
#Preview {
    NativeRichTextEditor()
} 