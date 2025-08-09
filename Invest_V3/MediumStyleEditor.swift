import SwiftUI
import UIKit
import PhotosUI
import Auth
import SupabaseStorage


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
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var showImageAttributionPicker: Bool = false
    @State private var pendingImage: UIImage?
    @State private var selectedImageAttribution: ImageAttribution?
    @State private var titleCharacterCount: Int = 0
    @State private var isPublishing: Bool = false
    @State private var showSaveDraftAlert = false
    @State private var isAutoSaving = false
    @State private var lastAutoSaveTime: Date = Date()
    @State private var hasTypingActivity = false
    @State private var autoSaveTimer: Timer?
    @State private var wordCount: Int = 0
    @State private var readingTime: Int = 0
    
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
            updateWordCount()
            setupAutoSave()
        }
        .onDisappear {
            // 當視圖消失時自動保存草稿
            autoSaveTimer?.invalidate()
            if hasUnsavedChanges {
                Task {
                    await autoSaveDraft(silent: true)
                }
            }
        }
        .alert("保存草稿", isPresented: $showSaveDraftAlert) {
            Button("保存") {
                Task {
                    await saveDraftAndClose()
                }
            }
            Button("不保存") {
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("你有未保存的更改，是否要保存為草稿？")
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
            matching: .any(of: [.images, .not(.videos)])
        )
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
                await processSelectedImageWithAttribution(item)
            }
        }
        .sheet(isPresented: $showImageAttributionPicker) {
            ImageSourceAttributionPicker(selectedAttribution: Binding(
                get: { selectedImageAttribution },
                set: { attribution in
                    selectedImageAttribution = attribution
                    if let image = pendingImage {
                        insertImageWithAttribution(image, attribution: attribution)
                        pendingImage = nil
                    }
                }
            ))
        }
    }
    
    // MARK: - 自定義導航欄
    private var customNavigationBar: some View {
        HStack(spacing: 16) {
            // 關閉按鈕
            Button(action: { 
                if hasUnsavedChanges {
                    showSaveDraftAlert = true
                } else {
                    dismiss()
                }
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
            Button(isPublishing ? "發佈中..." : "發佈") {
                if !isPublishing {
                    showSettings = true
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isPublishing ? Color.gray : Color.brandGreen)
            .cornerRadius(20)
            .disabled(isPublishing)
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
                .onChange(of: title) { _, newValue in
                    hasTypingActivity = true
                    scheduleAutoSave()
                }
            
            // 字數統計和文章統計
            HStack {
                // 文章統計（字數、預估閱讀時間）
                if wordCount > 0 {
                    HStack(spacing: 12) {
                        Label("\(wordCount) 字", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                        
                        Label("\(readingTime) 分鐘閱讀", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                
                // 標題字數統計
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
            .onChange(of: attributedContent) { _, newValue in
                hasTypingActivity = true
                updateWordCount()
                scheduleAutoSave()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowPhotoPicker"))) { _ in
                showPhotoPicker = true
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
    
    // 生成圖片的一致性ID（基於圖片數據的哈希）
    private func generateImageId(from image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return UUID().uuidString // 備選方案
        }
        
        // 使用圖片數據的簡單哈希作為ID
        let hash = imageData.reduce(0) { result, byte in
            result &+ Int(byte)
        }
        return "img_\(hash)_\(imageData.count)"
    }
    
    // 插入帶來源標註的圖片
    private func insertImageWithAttribution(_ image: UIImage, attribution: ImageAttribution?) {
        // 生成基於圖片內容的一致性ID
        let imageId = generateImageId(from: image)
        
        // 如果有標註，保存到管理器
        if let attribution = attribution {
            ImageAttributionManager.shared.setAttribution(for: imageId, attribution: attribution)
            print("✅ 已為圖片 \(imageId) 設置來源標註: \(attribution.displayText)")
        }
        
        // 通知 RichTextView 插入圖片
        NotificationCenter.default.post(
            name: NSNotification.Name("InsertImageWithAttribution"),
            object: ["image": image, "imageId": imageId, "attribution": attribution as Any]
        )
        
        // 如果 RichTextView 不支持新的通知，使用舊的方式
        NotificationCenter.default.post(
            name: NSNotification.Name("InsertImage"),
            object: image
        )
    }
    
    // 支援的圖片格式
    private let supportedImageFormats = ["jpg", "jpeg", "png", "gif", "webp", "tiff", "bmp", "heic"]
    
    // 處理選擇的圖片（帶來源標註）
    private func processSelectedImageWithAttribution(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await showImageError("無法載入圖片數據")
            return
        }
        
        // 檢查文件格式
        let fileName = item.itemIdentifier ?? "unknown"
        let fileExtension = fileName.lowercased().components(separatedBy: ".").last ?? ""
        
        if !supportedImageFormats.contains(fileExtension) && !isValidImageData(data) {
            await showImageError("不支援的圖片格式。支援格式：\(supportedImageFormats.joined(separator: ", "))")
            return
        }
        
        guard let image = UIImage(data: data) else {
            await showImageError("無法處理此圖片，請確認圖片格式是否正確")
            return
        }
        
        await MainActor.run {
            print("📸 成功處理圖片：\(fileName)")
            self.pendingImage = image
            self.showImageAttributionPicker = true
            // 處理完成後清空選擇
            selectedPhotosPickerItems.removeAll()
        }
    }
    
    // 處理選擇的圖片（舊版本，保留兼容性）
    private func processSelectedImage(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await showImageError("無法載入圖片數據")
            return
        }
        
        // 檢查文件格式
        let fileName = item.itemIdentifier ?? "unknown"
        let fileExtension = fileName.lowercased().components(separatedBy: ".").last ?? ""
        
        if !supportedImageFormats.contains(fileExtension) && !isValidImageData(data) {
            await showImageError("不支援的圖片格式。支援格式：\(supportedImageFormats.joined(separator: ", "))")
            return
        }
        
        guard let image = UIImage(data: data) else {
            await showImageError("無法處理此圖片，請確認圖片格式是否正確")
            return
        }
        
        await MainActor.run {
            print("📸 成功處理圖片：\(fileName)")
            insertImage(image)
            // 處理完成後清空選擇
            selectedPhotosPickerItems.removeAll()
        }
    }
    
    // 檢查是否為有效的圖片數據
    private func isValidImageData(_ data: Data) -> Bool {
        // 檢查常見的圖片文件頭
        if data.count < 4 { return false }
        
        let bytes = data.prefix(4)
        let header = bytes.map { String(format: "%02x", $0) }.joined()
        
        // 常見圖片格式的文件頭
        let imageHeaders = [
            "ffd8ff", // JPEG
            "89504e47", // PNG
            "47494638", // GIF
            "52494646", // WebP (RIFF)
            "49492a00", // TIFF (little endian)
            "4d4d002a", // TIFF (big endian)
            "424d", // BMP
            "00000018667479706865696300", // HEIC (partial)
        ]
        
        return imageHeaders.contains { header.hasPrefix($0) }
    }
    
    // 顯示圖片錯誤提示
    private func showImageError(_ message: String) async {
        await MainActor.run {
            print("❌ 圖片錯誤：\(message)")
            // TODO: 可以添加 Toast 或 Alert 來顯示用戶友好的錯誤訊息
            selectedPhotosPickerItems.removeAll()
        }
    }
    
    // 檢測圖片內容類型
    private func detectContentType(from data: Data) -> String {
        if data.count < 4 { return "image/jpeg" } // 默認返回 JPEG
        
        let bytes = data.prefix(4)
        let header = bytes.map { String(format: "%02x", $0) }.joined()
        
        switch header {
        case let h where h.hasPrefix("ffd8ff"):
            return "image/jpeg"
        case let h where h.hasPrefix("89504e47"):
            return "image/png"
        case let h where h.hasPrefix("47494638"):
            return "image/gif"
        case let h where h.hasPrefix("52494646"):
            return "image/webp"
        case let h where h.hasPrefix("49492a00"), let h where h.hasPrefix("4d4d002a"):
            return "image/tiff"
        case let h where h.hasPrefix("424d"):
            return "image/bmp"
        default:
            // 嘗試檢查 HEIC 格式
            if data.count >= 12 {
                let heicCheck = data.subdata(in: 4..<12)
                let heicString = String(data: heicCheck, encoding: .ascii) ?? ""
                if heicString.contains("ftyp") && heicString.contains("heic") {
                    return "image/heic"
                }
            }
            return "image/jpeg" // 默認
        }
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
                // 使用一致的圖片ID生成方法
                let imageId = generateImageId(from: image)
                let fileName = imageId + ".jpg"
                print("📸 嘗試上傳圖片: \(fileName)，大小: \(data.count) bytes")
                
                do {
                    // 根據圖片數據檢測內容類型
                    let contentType = detectContentType(from: data)
                    let url = try await SupabaseService.shared.uploadArticleImageWithContentType(data, fileName: fileName, contentType: contentType)
                    print("✅ 圖片上傳成功: \(url)")
                    
                    // 檢查是否有來源標註
                    if let attribution = ImageAttributionManager.shared.getAttribution(for: imageId) {
                        // 使用 EnhancedImageInserter 來生成帶標註的 Markdown
                        print("📝 為圖片 \(imageId) 生成帶標註的 Markdown: \(attribution.displayText)")
                        markdown += EnhancedImageInserter.insertImageWithAttribution(
                            imageUrl: url,
                            attribution: attribution,
                            altText: ""
                        )
                    } else {
                        print("ℹ️ 圖片 \(imageId) 沒有來源標註，使用默認格式")
                        markdown += "![](\(url))"
                    }
                } catch {
                    print("❌ 圖片上傳失敗: \(error.localizedDescription)")
                    // 如果上傳失敗，插入本地佔位符
                    markdown += "![圖片上傳失敗]"
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
    
    // MARK: - Draft Management Methods
    
    /// 無靕自動保存草稿
    private func autoSaveDraft(silent: Bool = false) async {
        guard hasUnsavedChanges else { return }
        
        isAutoSaving = true
        
        do {
            var draft = createDraftFromCurrentState()
            draft.bodyMD = await convertAttributedContentToMarkdown()
            
            let _ = try await SupabaseService.shared.saveDraft(draft)
            
            if !silent {
                await MainActor.run {
                    lastAutoSaveTime = Date()
                    print("✅ 草稿自動保存成功")
                }
            }
        } catch {
            if !silent {
                print("❌ 草稿自動保存失敗: \(error.localizedDescription)")
            }
        }
        
        isAutoSaving = false
    }
    
    /// 保存草稿並關閉編輯器
    private func saveDraftAndClose() async {
        await autoSaveDraft(silent: false)
        dismiss()
    }
    
    /// 手動保存草稿
    private func saveDraft() async {
        guard !title.isEmpty else {
            print("❌ 標題不能為空")
            return
        }
        
        await autoSaveDraft(silent: false)
    }
    
    // MARK: - Enhanced Editor Features
    
    /// 設置自動保存機制
    private func setupAutoSave() {
        // 每30秒檢查一次是否需要自動保存
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if hasTypingActivity && hasUnsavedChanges {
                Task {
                    await autoSaveDraft(silent: true)
                    hasTypingActivity = false
                }
            }
        }
    }
    
    /// 延遲執行自動保存（用戶停止輸入5秒後）
    private func scheduleAutoSave() {
        // 取消之前的計時器
        autoSaveTimer?.invalidate()
        
        // 設置新的計時器，5秒後執行自動保存
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            if self.hasTypingActivity && self.hasUnsavedChanges {
                Task {
                    await self.autoSaveDraft(silent: true)
                    self.hasTypingActivity = false
                }
            }
        }
    }
    
    /// 更新字數統計和閱讀時間
    private func updateWordCount() {
        let fullText = title + " " + attributedContent.string
        let words = fullText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        wordCount = words.count
        
        // 根據平均閱讀速度計算閱讀時間（假設每分鐘250字）
        readingTime = max(1, Int(ceil(Double(wordCount) / 250.0)))
    }
    
    /// 智能標題建議
    private func generateTitleSuggestions() -> [String] {
        let content = attributedContent.string
        guard content.count > 50 else { return [] }
        
        // 提取內容的前幾句作為標題建議
        let sentences = content.components(separatedBy: .punctuationCharacters)
            .filter { !$0.isEmpty && $0.count > 10 && $0.count < 100 }
            .prefix(3)
        
        return Array(sentences).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// 內容質量檢查
    private func performContentQualityCheck() -> (score: Double, suggestions: [String]) {
        var score: Double = 0.0
        var suggestions: [String] = []
        
        // 檢查標題
        if title.isEmpty {
            suggestions.append("添加標題可以提高文章的吸引力")
        } else if title.count < 10 {
            suggestions.append("標題可以更具體一些")
            score += 0.1
        } else {
            score += 0.3
        }
        
        // 檢查內容長度
        let contentLength = attributedContent.string.count
        if contentLength < 100 {
            suggestions.append("內容太短，考慮添加更多詳細信息")
        } else if contentLength < 500 {
            suggestions.append("內容不錯，可以考慮添加更多例子或詳細說明")
            score += 0.2
        } else {
            score += 0.4
        }
        
        // 檢查段落結構
        let paragraphs = attributedContent.string.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        if paragraphs.count < 3 {
            suggestions.append("考慮將內容分成更多段落以提高可讀性")
        } else {
            score += 0.2
        }
        
        // 檢查關鍵字
        if keywords.isEmpty {
            suggestions.append("添加相關關鍵字可以提高文章的發現性")
        } else {
            score += 0.1
        }
        
        return (min(1.0, score), suggestions)
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
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
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
                    
                    // 內容 - 使用富文本顯示，移除 minHeight 避免空白
                    if attributedContent.length > 0 {
                        RichTextPreviewView(attributedText: attributedContent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("尚無內容...")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // 底部適當間距
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 0)
            }
            .background(backgroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // 修復：減少底部間距，避免額外空白
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 0, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false // 禁用內部滾動，讓外層 ScrollView 控制
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        
        // 設置默認字體作為備選，但不覆蓋 NSAttributedString 的格式
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        
        print("🔍 makeUIView - textView created with frame: \(textView.frame)")
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        print("🔍 updateUIView - attributedText.length: \(attributedText.length)")
        print("🔍 updateUIView - attributedText.string: '\(attributedText.string.prefix(100))'")
        
        // 處理本地圖片顯示
        let processedText = processImagesForPreview(attributedText)
        uiView.attributedText = processedText
        
        // 優化高度計算，避免額外空白
        DispatchQueue.main.async {
            let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: CGFloat.greatestFiniteMagnitude))
            print("🔍 計算的內容高度: \(size.height)")
            
            // 強制重新佈局
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
        }
        
        print("🔍 updateUIView - uiView.attributedText.length: \(uiView.attributedText?.length ?? 0)")
    }
    
    // 處理圖片以便在預覽中正確顯示
    private func processImagesForPreview(_ originalText: NSAttributedString) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: originalText)
        
        // 遍歷所有附件，確保圖片能正確顯示
        originalText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: originalText.length)) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                // 使用統一的圖片尺寸配置
                if let image = attachment.image {
                    ImageSizeConfiguration.configureAttachment(attachment, with: image)
                    
                    // 調試信息
                    ImageSizeConfiguration.logSizeInfo(
                        originalSize: image.size,
                        displaySize: attachment.bounds.size,
                        context: "預覽"
                    )
                }
            }
        }
        
        return mutableText
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