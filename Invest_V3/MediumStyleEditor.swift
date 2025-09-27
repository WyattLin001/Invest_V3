import SwiftUI
import UIKit
import PhotosUI
import Auth
import SupabaseStorage
import MarkdownUI


// MARK: - Medium 風格編輯器
struct MediumStyleEditor: View {
    @State private var title: String
    @State private var attributedContent: NSAttributedString
    @State private var isPaidContent: Bool
    @State private var selectedSubtopic: String
    @State private var keywords: [String]
    @State private var currentDraft: ArticleDraft
    @State private var showSettings: Bool = false
    @State private var showPreview: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var showImageAttributionPicker: Bool = false
    @State private var pendingImage: UIImage?
    @State private var selectedImageAttribution: ImageAttribution?
    @State private var currentImageSource: ImageSourceType = .unknown
    @State private var userDidSelectAttribution: Bool = false  // 追蹤用戶是否已確認選擇
    
    // 圖片來源類型枚舉
    enum ImageSourceType {
        case photosLibrary
        case camera
        case clipboard
        case unknown
    }
    @State private var titleCharacterCount: Int = 0
    @State private var isPublishing: Bool = false
    @State private var showSaveDraftAlert = false
    @State private var isAutoSaving = false
    @State private var showSaveSuccess = false
    @State private var lastAutoSaveTime: Date = Date()
    @State private var hasTypingActivity = false
    @State private var autoSaveTimer: Timer?
    @State private var wordCount: Int = 0
    @State private var readingTime: Int = 0
    @State private var userChoseNotToSave = false // 追蹤用戶是否選擇不保存
    @State private var showToast = false
    @State private var toastMessage = ""
    
    private let onComplete: (() -> Void)?
    
    @StateObject private var articleViewModel = ArticleViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Initializers
    
    /// 新創文章的初始化
    init(onComplete: (() -> Void)? = nil) {
        self._title = State(initialValue: "")
        self._attributedContent = State(initialValue: NSAttributedString())
        self._isPaidContent = State(initialValue: false)
        self._selectedSubtopic = State(initialValue: "投資分析")
        self._keywords = State(initialValue: [])
        self._currentDraft = State(initialValue: ArticleDraft())
        self.onComplete = onComplete
    }
    
    /// 從現有草稿編輯的初始化
    init(existingDraft: ArticleDraft, onComplete: (() -> Void)? = nil) {
        self._title = State(initialValue: existingDraft.title)
        // 使用 Markdown 轉換器來正確處理圖片和格式
        let attributedString = RichTextPreviewView.convertMarkdownToAttributedString(existingDraft.bodyMD)
        self._attributedContent = State(initialValue: attributedString)
        self._isPaidContent = State(initialValue: existingDraft.isPaid)
        self._selectedSubtopic = State(initialValue: existingDraft.category)
        self._keywords = State(initialValue: existingDraft.keywords)
        self._currentDraft = State(initialValue: existingDraft)
        self.onComplete = onComplete
    }
    
    // 字數統計
    private let maxTitleLength = 100
    
    // 顏色配置 - 使用系統自適應顏色避免無限重繪
    private let backgroundColor = Color(UIColor.systemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    
    // 檢查是否有未保存的更改
    private var hasUnsavedChanges: Bool {
        !title.isEmpty || attributedContent.length > 0
    }
    
    // 動態計算編輯器最小高度
    private var dynamicMinHeight: CGFloat {
        let contentHeight = estimateContentHeight()
        let screenHeight = UIScreen.main.bounds.height
        
        // 計算可用編輯區域（扣除導航欄、安全區域等）
        let availableHeight = screenHeight - 200 // 200pt用於導航欄和其他UI元素
        
        // 動態計算：內容高度 + 編輯緩衝區，但不超過可用空間的60%
        let idealHeight = contentHeight + 150 // 150pt編輯緩衝區
        let maxHeight = availableHeight * 0.6
        
        // 設置最小250pt，最大不超過計算值
        let result = max(250, min(idealHeight, maxHeight))
        
        Logger.debug("動態高度計算: 內容=\(contentHeight)pt, 螢幕=\(screenHeight)pt, 結果=\(result)pt", category: .ui)
        
        return result
    }
    
    // 估算當前內容的實際高度
    private func estimateContentHeight() -> CGFloat {
        let font = UIFont.systemFont(ofSize: 17)
        let screenWidth = UIScreen.main.bounds.width - 32 // 減去左右邊距
        
        let titleHeight = title.calculateTextHeight(width: screenWidth, font: .boldSystemFont(ofSize: 32))
        let contentHeight = attributedContent.string.calculateTextHeight(width: screenWidth, font: font)
        let totalHeight = titleHeight + contentHeight + 40 // 加上間距
        
        Logger.debug("內容高度估算: 標題=\(titleHeight)pt, 內容=\(contentHeight)pt, 總計=\(totalHeight)pt", category: .ui)
        
        return totalHeight
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定義導航欄
                customNavigationBar
                
                // 主內容區域 - 模仿 ArticleDetailView 結構
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // 標題輸入區域
                        titleSection
                        
                        // 付費內容切換（靠右對齊）
                        HStack {
                            Spacer()
                            paidContentToggle
                        }
                        
                        // 富文本編輯器
                        richTextEditor
                            .frame(maxWidth: .infinity) // 確保不超出父容器寬度
                        
                        // 底部間距 - 模仿 ArticleDetailView
                        Spacer(minLength: 100)
                    }
                    .padding() // 系統自適應 padding - 完全模仿 ArticleDetailView
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
            // 如果 currentDraft 還沒有被初始化（新草稿情況），創建一個新的
            if currentDraft.title.isEmpty && currentDraft.bodyMD.isEmpty {
                currentDraft = createDraftFromCurrentState()
            }
            updateWordCount()
            setupAutoSave()
        }
        .onDisappear {
            // 當視圖消失時自動保存草稿（只有在用戶沒有選擇不保存的情況下）
            autoSaveTimer?.invalidate()
            if hasUnsavedChanges && !userChoseNotToSave {
                Task {
                    await autoSaveDraft(silent: true)
                }
            }
        }
        .alert("保存草稿", isPresented: $showSaveDraftAlert) {
            Button(isAutoSaving ? "保存中..." : "保存") {
                if !isAutoSaving {
                    Task {
                        await saveDraftAndClose()
                    }
                }
            }
            .disabled(isAutoSaving)
            
            Button("不保存") {
                userChoseNotToSave = true
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(isAutoSaving ? "正在保存草稿，請稍候..." : "你有未保存的更改，是否要保存為草稿？")
        }
        .onChange(of: showSettings) { _, isShowing in
            if isShowing {
                // 打開設定頁面時，從當前狀態創建 draft
                currentDraft = createDraftFromCurrentState()
                Logger.debug("打開設定頁面，創建 draft，關鍵字: \(currentDraft.keywords)", category: .editor)
            } else {
                // 關閉設定頁面時，同步關鍵字回編輯器
                keywords = currentDraft.keywords
                Logger.debug("關閉設定頁面，同步關鍵字: \(currentDraft.keywords)", category: .editor)
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
            Logger.debug("🔍 Ultra Think 調試 - 圖片選擇器變更", category: .editor)
            Logger.debug("  - 舊項目數: \(oldItems.count)", category: .editor)
            Logger.debug("  - 新項目數: \(newItems.count)", category: .editor)
            Logger.debug("  - showImageAttributionPicker: \(showImageAttributionPicker)", category: .editor)
            Logger.debug("  - userDidSelectAttribution: \(userDidSelectAttribution)", category: .editor)
            
            // Ultra Think 修復：處理任何新選擇，不限制 count > oldItems.count
            guard !newItems.isEmpty else { 
                Logger.debug("❌ 項目列表為空，跳過處理", category: .editor)
                return 
            }
            
            guard let item = newItems.last else { 
                Logger.warning("❌ 找不到最新項目", category: .editor)
                return 
            }
            
            Logger.info("✅ 開始處理圖片 - 項目ID: \(item.itemIdentifier ?? "未知")", category: .editor)
            
            Task {
                await processSelectedImageWithAttribution(item)
            }
        }
        .sheet(isPresented: $showImageAttributionPicker) {
            SimpleImageAttributionPicker(selectedAttribution: Binding(
                get: { selectedImageAttribution },
                set: { attribution in
                    Logger.info("✅ 用戶確認選擇來源：\(attribution?.displayText ?? "nil")", category: .editor)
                    selectedImageAttribution = attribution
                    userDidSelectAttribution = true  // 標記用戶已確認選擇
                    
                    if let image = pendingImage {
                        Logger.info("🎯 使用用戶選擇的來源插入圖片", category: .editor)
                        insertImageWithAttribution(image, attribution: attribution)
                        pendingImage = nil
                        selectedImageAttribution = nil  // 清空選擇狀態
                        
                        // Ultra Think 修復：用戶完成選擇後清空 PhotosPicker
                        DispatchQueue.main.async {
                            self.selectedPhotosPickerItems.removeAll()
                            Logger.debug("🧹 用戶完成選擇後清空 PhotosPicker", category: .editor)
                        }
                    } else {
                        Logger.warning("⚠️ 沒有待處理的圖片", category: .editor)
                    }
                }
            ))
            .onDisappear {
                Logger.debug("🔄 SimpleImageAttributionPicker onDisappear 觸發", category: .editor)
                Logger.debug("📋 onDisappear 狀態 - pendingImage: \(pendingImage != nil), userDidSelectAttribution: \(userDidSelectAttribution)", category: .editor)
                
                // 只有在用戶未確認選擇且還有待處理圖片時，才提供默認 attribution
                if let image = pendingImage, !userDidSelectAttribution {
                    Logger.warning("❌ 用戶未選擇來源，使用默認值 iPhone", category: .editor)
                    let defaultAttribution = createDefaultAttribution()
                    insertImageWithAttribution(image, attribution: defaultAttribution)
                    pendingImage = nil
                } else if pendingImage == nil {
                    Logger.debug("✅ 沒有待處理圖片，無需默認處理", category: .editor)
                } else if userDidSelectAttribution {
                    Logger.debug("✅ 用戶已選擇來源，無需默認處理", category: .editor)
                }
                
                // 重置所有相關狀態
                userDidSelectAttribution = false
                selectedImageAttribution = nil
                
                // Ultra Think 修復：onDisappear 時也清空 PhotosPicker
                DispatchQueue.main.async {
                    self.selectedPhotosPickerItems.removeAll()
                    Logger.debug("🧹 onDisappear 時清空 PhotosPicker", category: .editor)
                }
            }
        }
    }
    
    // MARK: - 自定義導航欄
    private var customNavigationBar: some View {
        HStack(spacing: 16) {
            // 關閉按鈕 - 增強視覺效果
            Button(action: { 
                if hasUnsavedChanges {
                    showSaveDraftAlert = true
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // 預覽按鈕
            Button("預覽") {
                Logger.info("使用者點擊預覽 - 內容長度: \(attributedContent.length), 標題: '\(title)'", category: .ui)
                showPreview = true
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.brandBlue)
            
            // 保存狀態指示器
            if isAutoSaving {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.secondary)
                    Text("保存中")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isAutoSaving)
            } else if showSaveSuccess {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("已保存")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: showSaveSuccess)
            }
            
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
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
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
                // 文章統計（預估閱讀時間）
                if readingTime > 0 {
                    HStack(spacing: 12) {
                        
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
    
    // MARK: - 富文本編輯器 (整合 Ultra Think 修復)
    private var richTextEditor: some View {
        RichTextView(attributedText: $attributedContent)
            .background(backgroundColor)
            .onChange(of: attributedContent) { oldValue, newValue in
                // 🎯 避免無效的更新觸發
                guard newValue.string != oldValue.string else { return }
                
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
        // 統一使用帶來源選擇的方法，確保用戶輸入不被忽略
        let defaultAttribution = createDefaultAttribution()
        Logger.info("🎯 舊方法調用，使用預設來源：\(defaultAttribution.displayText)", category: .editor)
        insertImageWithAttribution(image, attribution: defaultAttribution)
    }
    
    // 生成圖片的一致性ID（基於圖片數據的哈希）
    private func generateImageId(from image: UIImage) -> String {
        return ImageUtils.generateImageId(from: image)
    }
    
    // 創建默認的圖片來源標註
    private func createDefaultAttribution() -> ImageAttribution {
        return createSmartDefaultAttribution(for: currentImageSource)
    }
    
    // 智能檢測默認來源
    private func createSmartDefaultAttribution(for source: ImageSourceType) -> ImageAttribution {
        switch source {
        case .photosLibrary:
            // 從照片庫選擇，通常是手機拍攝
            return ImageAttribution(source: .custom, customText: "iPhone")
            
        case .camera:
            // 直接拍攝
            return ImageAttribution(source: .author, customText: nil)
            
        case .clipboard:
            // 從剪貼板粘貼，可能是截圖
            return ImageAttribution(source: .screenshot, customText: nil)
            
        case .unknown:
            // 未知來源，使用通用默認值
            return ImageAttribution(source: .custom, customText: "iPhone")
        }
    }
    
    // 插入帶來源標註的圖片
    private func insertImageWithAttribution(_ image: UIImage, attribution: ImageAttribution?) {
        // 生成基於圖片內容的一致性ID
        let imageId = generateImageId(from: image)
        
        // 確保總是有 attribution，如果沒有則使用默認值
        let finalAttribution = attribution ?? createDefaultAttribution()
        
        // 保存到管理器
        ImageAttributionManager.shared.setAttribution(for: imageId, attribution: finalAttribution)
        
        // 通知 RichTextView 插入圖片（總是帶有標註）
        NotificationCenter.default.post(
            name: NSNotification.Name("InsertImageWithAttribution"),
            object: ["image": image, "imageId": imageId, "attribution": finalAttribution]
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
            Logger.info("成功處理圖片：\(fileName)", category: .editor)
            self.pendingImage = image
            self.currentImageSource = .photosLibrary  // 標記來源為照片庫
            self.userDidSelectAttribution = false  // 重置選擇狀態
            self.selectedImageAttribution = nil  // 清空舊的選擇
            self.showImageAttributionPicker = true
            Logger.info("🎯 觸發圖片來源選擇器顯示，狀態已重置", category: .editor)
            Logger.debug("📋 當前狀態 - pendingImage: \(self.pendingImage != nil), userDidSelectAttribution: \(self.userDidSelectAttribution)", category: .editor)
            
            // Ultra Think 修復：不立即清空，等待用戶完成選擇後再清空
            Logger.debug("📱 等待用戶完成來源選擇，暫不清空 PhotosPicker", category: .editor)
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
            Logger.info("成功處理圖片：\(fileName)", category: .editor)
            Logger.info("🎯 舊流程被調用，重定向到帶來源選擇的新流程", category: .editor)
            // 重定向到新的帶來源選擇的流程
            self.pendingImage = image
            self.currentImageSource = .photosLibrary
            self.userDidSelectAttribution = false  // 重置選擇狀態
            self.selectedImageAttribution = nil  // 清空舊的選擇
            self.showImageAttributionPicker = true
            
            // Ultra Think 修復：不立即清空，等待用戶完成選擇後再清空
            Logger.debug("📱 等待用戶完成來源選擇，暫不清空 PhotosPicker（舊版）", category: .editor)
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
            Logger.error("圖片錯誤：\(message)", category: .editor)
            // 顯示用戶友好的錯誤訊息
            toastMessage = "圖片處理失敗：\(message)"
            showToast = true
            
            // Ultra Think 修復：錯誤情況下立即清空選擇項目
            self.selectedPhotosPickerItems.removeAll()
            Logger.debug("🧹 錯誤處理後清空 PhotosPicker 選擇項目", category: .editor)
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

        // 收集所有區段及對應圖片和屬性
        var segments: [(attributedText: NSAttributedString, attachment: NSTextAttachment?)] = []
        attributedContent.enumerateAttributes(in: NSRange(location: 0, length: attributedContent.length)) { attrs, range, _ in
            let attributedText = attributedContent.attributedSubstring(from: range)
            let attachment = attrs[.attachment] as? NSTextAttachment
            segments.append((attributedText, attachment))
        }

        var imageCounter = 0
        
        for segment in segments {
            if let attachment = segment.attachment,
               let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0),
               let data = image.jpegData(compressionQuality: 0.8) {
                // 增加圖片計數器
                imageCounter += 1
                
                // 使用一致的圖片ID生成方法
                let imageId = generateImageId(from: image)
                // 添加時間戳確保文件名唯一，避免重複上傳錯誤
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "\(imageId)_\(timestamp).jpg"
                Logger.info("🖼️ 開始上傳圖片: \(fileName)，大小: \(data.count) bytes", category: .editor)
                
                do {
                    // 根據圖片數據檢測內容類型
                    let contentType = detectContentType(from: data)
                    let url = try await SupabaseService.shared.uploadArticleImageWithContentType(data, fileName: fileName, contentType: contentType)
                    Logger.info("✅ 圖片上傳成功: \(url)", category: .editor)
                    
                    // 檢查是否有來源標註
                    if let attribution = ImageAttributionManager.shared.getAttribution(for: imageId) {
                        // 使用 EnhancedImageInserter 來生成帶標註的 Markdown
                        Logger.debug("為圖片 \(imageId) 生成帶標註的 Markdown: \(attribution.displayText)", category: .editor)
                        markdown += EnhancedImageInserter.insertImageWithAttribution(
                            imageUrl: url,
                            attribution: attribution,
                            altText: ""
                        )
                    } else {
                        // 為沒有來源標註的圖片創建默認標註
                        Logger.debug("圖片 \(imageId) 沒有來源標註，創建默認標註", category: .editor)
                        let defaultAttribution = createSmartDefaultAttribution(for: .unknown)
                        
                        // 保存默認標註以供後續使用
                        ImageAttributionManager.shared.setAttribution(for: imageId, attribution: defaultAttribution)
                        
                        // 使用默認標註生成 Markdown
                        markdown += EnhancedImageInserter.insertImageWithAttribution(
                            imageUrl: url,
                            attribution: defaultAttribution,
                            altText: ""
                        )
                    }
                } catch {
                    Logger.error("❌ 圖片上傳失敗: \(error.localizedDescription)", category: .editor)
                    // 如果上傳失敗，插入本地佔位符
                    markdown += "![圖片上傳失敗]"
                }
            } else {
                // 處理富文本格式轉換為 Markdown
                let convertedText = convertAttributedStringToMarkdown(segment.attributedText)
                markdown += convertedText
            }
        }

        return markdown
    }
    
    /// 將 NSAttributedString 轉換為對應的 Markdown 格式
    private func convertAttributedStringToMarkdown(_ attributedString: NSAttributedString) -> String {
        let text = attributedString.string
        if text.isEmpty { return text }
        
        var result = ""
        var processedRanges: [NSRange] = []
        
        // 按順序處理屬性，避免重複替換
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attrs, range, _ in
            let substring = (text as NSString).substring(with: range)
            var formattedText = substring
            
            // 檢查是否為列表項目
            if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
               paragraphStyle.headIndent > 0 {
                // 有縮排的文字，檢查是否為列表
                if substring.hasPrefix("1. ") || substring.hasPrefix("2. ") || substring.hasPrefix("3. ") ||
                   substring.contains(". ") && substring.first?.isNumber == true {
                    // 編號列表 - 保持原格式
                    formattedText = substring
                } else if substring.hasPrefix("• ") {
                    // 項目符號列表 - 保持原格式
                    formattedText = substring
                }
            }
            // 處理字體相關格式（只在非列表項目時）
            else if let font = attrs[.font] as? UIFont {
                if font.pointSize >= 24 {
                    // H1 標題 - 只在行首添加，避免重複
                    if range.location == 0 || (text as NSString).character(at: range.location - 1) == 10 { // 10是換行符
                        formattedText = "# \(substring)"
                    }
                } else if font.pointSize >= 20 {
                    // H2 標題
                    if range.location == 0 || (text as NSString).character(at: range.location - 1) == 10 {
                        formattedText = "## \(substring)"
                    }
                } else if font.pointSize >= 18 {
                    // H3 標題
                    if range.location == 0 || (text as NSString).character(at: range.location - 1) == 10 {
                        formattedText = "### \(substring)"
                    }
                } else if font.isBold {
                    // 粗體文字
                    formattedText = "**\(substring)**"
                }
            }
            
            // 跳過顏色處理 - 顏色標籤在載入時會造成顯示問題
            // 如果需要保存顏色信息，應該使用更兼容的格式
            // 目前先移除顏色標籤以確保內容乾淨
            
            result += formattedText
        }
        
        return result
    }
    
    // MARK: - 草稿創建
    private func createDraftFromCurrentState() -> ArticleDraft {
        // 使用現有的 currentDraft 作為基礎，保持 ID 和創建時間
        var draft = currentDraft
        draft.title = title
        draft.subtitle = nil
        // 關鍵修復：使用格式轉換函數保持富文本格式
        draft.bodyMD = convertAttributedContentToMarkdownSync()
        draft.isFree = !isPaidContent
        draft.isPaid = isPaidContent
        draft.category = selectedSubtopic
        draft.keywords = keywords
        draft.updatedAt = Date()
        // 只有在是新草稿時才更新創建時間
        if draft.createdAt.timeIntervalSinceNow > -1 {
            draft.createdAt = Date()
        }
        Logger.debug("更新草稿 ID: \(draft.id)，保留格式，關鍵字: \(keywords)", category: .editor)
        return draft
    }
    
    /// 同步版本的格式轉換（不上傳圖片，用於草稿創建）
    private func convertAttributedContentToMarkdownSync() -> String {
        var markdown = ""

        // 收集所有區段及對應圖片和屬性
        var segments: [(attributedText: NSAttributedString, attachment: NSTextAttachment?)] = []
        attributedContent.enumerateAttributes(in: NSRange(location: 0, length: attributedContent.length)) { attrs, range, _ in
            let attributedText = attributedContent.attributedSubstring(from: range)
            let attachment = attrs[.attachment] as? NSTextAttachment
            segments.append((attributedText, attachment))
        }

        for segment in segments {
            if let attachment = segment.attachment {
                // 對於圖片，在同步版本中只生成占位符
                markdown += "![圖片待上傳]"
            } else {
                // 處理富文本格式轉換為 Markdown
                let convertedText = convertAttributedStringToMarkdown(segment.attributedText)
                markdown += convertedText
            }
        }

        return markdown
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
            do {
                draft.bodyMD = await convertAttributedContentToMarkdown()
                let savedDraft = try await SupabaseService.shared.saveDraft(draft)
                await MainActor.run {
                    currentDraft = savedDraft
                    toastMessage = "草稿已保存"
                    showToast = true
                    isAutoSaving = false
                }
                Logger.info("草稿保存成功: \(draft.title)", category: .editor)
            } catch {
                await MainActor.run {
                    toastMessage = "草稿保存失敗：\(error.localizedDescription)"
                    showToast = true
                    isAutoSaving = false
                }
                Logger.error("草稿保存失敗: \(error.localizedDescription)", category: .editor)
            }
        }
    }
    
    private func publishArticle() {
        guard !title.isEmpty else {
            Logger.warning("標題不能為空，無法發佈文章", category: .editor)
            return
        }
        
        guard attributedContent.length > 0 else {
            Logger.warning("內容不能為空，無法發佈文章", category: .editor)
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
                    onComplete?()
                    dismiss() // 發布成功後關閉編輯器
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    Logger.error("發佈文章失敗: \(error.localizedDescription)", category: .editor)
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
        
        await MainActor.run {
            isAutoSaving = true
        }
        
        do {
            var draft = createDraftFromCurrentState()
            draft.bodyMD = await convertAttributedContentToMarkdown()
            
            let _ = try await SupabaseService.shared.saveDraft(draft)
            
            if !silent {
                await MainActor.run {
                    lastAutoSaveTime = Date()
                    showSaveSuccess = true
                    Logger.info("✅ 草稿自動保存成功", category: .editor)
                    
                    // 2秒後隱藏成功提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showSaveSuccess = false
                        }
                    }
                }
            }
        } catch {
            if !silent {
                Logger.error("草稿自動保存失敗: \(error.localizedDescription)", category: .editor)
            }
        }
        
        await MainActor.run {
            isAutoSaving = false
        }
    }
    
    /// 保存草稿並關閉編輯器
    private func saveDraftAndClose() async {
        await autoSaveDraft(silent: false)
        dismiss()
    }
    
    /// 手動保存草稿
    private func saveDraft() async {
        guard !title.isEmpty else {
            Logger.warning("標題不能為空，無法保存草稿", category: .editor)
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
                    await MainActor.run {
                        self.hasTypingActivity = false
                    }
                }
            }
        }
    }
    
    /// 更新字數統計和閱讀時間 (優化避免循環引用)
    private func updateWordCount() {
        let fullText = title + " " + attributedContent.string
        
        // 🎯 簡化字數計算避免複雜的Unicode操作
        // 使用更簡單高效的方法
        let basicWordCount = fullText.count
        
        // 簡單估算：如果包含中文字符就按字符數計算，否則按單詞數計算
        let hasChineseCharacters = fullText.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil
        
        if hasChineseCharacters {
            // 有中文：按字符數計算（去除空格）
            wordCount = fullText.replacingOccurrences(of: " ", with: "").count
        } else {
            // 純英文：按單詞數計算
            wordCount = fullText.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.trimmingCharacters(in: .punctuationCharacters).isEmpty }
                .count
        }
        
        // 計算閱讀時間（每分鐘250字）
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
    
    // MARK: - Markdown 轉換
    
    /// 將 NSAttributedString 轉換為 Markdown 字符串（用於預覽）
    internal static func convertAttributedStringToMarkdownForPreview(_ attributedString: NSAttributedString) -> String {
        let string = attributedString.string
        var markdownContent = ""
        var currentIndex = 0
        
        // 處理富文本內容
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, _ in
            let substring = (string as NSString).substring(with: range)
            
            // 處理圖片附件
            if let attachment = attributes[.attachment] as? NSTextAttachment {
                // 對於預覽，我們需要處理圖片附件
                if let image = attachment.image,
                   let imageData = image.pngData() {
                    let base64String = imageData.base64EncodedString()
                    let dataURL = "data:image/png;base64,\(base64String)"
                    markdownContent += "\n![圖片](\(dataURL))\n"
                    Logger.debug("轉換圖片附件為 base64 Markdown 語法", category: .editor)
                } else {
                    // 如果無法獲取圖片數據，使用圖片占位符
                    markdownContent += "\n![圖片](placeholder)\n"
                    Logger.debug("圖片附件無法轉換，使用占位符", category: .editor)
                }
            } else {
                // 處理文本內容
                var processedText = substring
                
                // 檢查並過濾圖片標題文字（避免重複顯示）
                let imagePattern = #"圖片\s*\d*\s*\[來源：[^\]]*\]"#
                if processedText.range(of: imagePattern, options: .regularExpression) != nil {
                    // 跳過圖片標題文字，因為圖片本身已經處理
                    return
                }
                
                // 移除所有 color 標籤
                processedText = processedText.replacingOccurrences(
                    of: #"</?color[^>]*>"#, 
                    with: "", 
                    options: .regularExpression
                )
                
                // 檢查字體屬性
                if let font = attributes[.font] as? UIFont {
                    // 處理標題
                    if font.pointSize > 25 {
                        // H1
                        processedText = "# " + processedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if font.pointSize > 20 {
                        // H2
                        processedText = "## " + processedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if font.pointSize > 17 {
                        // H3
                        processedText = "### " + processedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // 處理粗體
                    if font.fontDescriptor.symbolicTraits.contains(.traitBold) && font.pointSize <= 17 {
                        processedText = "**" + processedText + "**"
                    }
                }
                
                // 只添加非空的處理過的文本
                if !processedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    markdownContent += processedText
                }
            }
            
            currentIndex = range.location + range.length
        }
        
        // 清理多餘的換行符和空白
        let cleanedMarkdown = markdownContent
            .replacingOccurrences(of: #"\n\n+"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        Logger.debug("Markdown 轉換完成，長度: \(cleanedMarkdown.count)", category: .editor)
        return cleanedMarkdown
    }
}

// MARK: - 預覽 Sheet
struct PreviewSheet: View {
    let title: String
    let attributedContent: NSAttributedString
    let isPaid: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    private let backgroundColor = Color(UIColor.systemBackground)
    private let textColor = Color(UIColor.label)
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
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
                    
                    // 內容 - 使用富文本顯示，完全模仿 MediumStyleEditor 結構
                    if attributedContent.length > 0 {
                        RichTextPreviewView(attributedText: attributedContent)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("尚無內容...")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // 底部間距 - 模仿 ArticleDetailView
                    Spacer(minLength: 100)
                }
                .padding() // 系統自適應 padding - 完全模仿 MediumStyleEditor
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
struct RichTextPreviewView: View {
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
    
    // 將 NSAttributedString 轉換為 Markdown
    private var markdownContent: String {
        return MediumStyleEditor.convertAttributedStringToMarkdownForPreview(attributedText)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !markdownContent.isEmpty {
                Markdown(markdownContent)
                    .markdownTextStyle {
                        FontSize(.em(1.0))
                    }
                    .modifier(MarkdownHeadingStyleModifier())
                    .modifier(MarkdownBlockStyleModifier())
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            } else {
                Text("無內容")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .onAppear {
            Logger.debug("MarkdownPreview 載入 - 內容長度: \(markdownContent.count)", category: .ui)
        }
    }
    
    /// 將 Markdown 文本轉換為 NSAttributedString
    static func convertMarkdownToAttributedString(_ markdown: String) -> NSAttributedString {
        let mutableText = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("# ") {
                // H1 標題 - 支持內聯格式
                let title = String(trimmedLine.dropFirst(2))
                let processedTitle = processRichText(title)
                let titleText = applyHeadingAttributes(processedTitle, fontSize: 24, weight: .bold)
                mutableText.append(titleText)
                mutableText.append(NSAttributedString(string: "\n"))
                
            } else if trimmedLine.hasPrefix("## ") {
                // H2 標題 - 支持內聯格式
                let title = String(trimmedLine.dropFirst(3))
                let processedTitle = processRichText(title)
                let titleText = applyHeadingAttributes(processedTitle, fontSize: 20, weight: .semibold)
                mutableText.append(titleText)
                mutableText.append(NSAttributedString(string: "\n"))
                
            } else if trimmedLine.hasPrefix("### ") {
                // H3 標題 - 支持內聯格式
                let title = String(trimmedLine.dropFirst(4))
                let processedTitle = processRichText(title)
                let titleText = applyHeadingAttributes(processedTitle, fontSize: 18, weight: .medium)
                mutableText.append(titleText)
                mutableText.append(NSAttributedString(string: "\n"))
                
            } else if trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("- ") {
                // 項目符號列表 - 支持內聯格式
                let content = String(trimmedLine.dropFirst(2))
                let processedContent = processRichText(content)
                let listText = applyListAttributes(processedContent, prefix: "• ")
                mutableText.append(listText)
                mutableText.append(NSAttributedString(string: "\n"))
                
            } else if let numberMatch = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                // 編號列表 - 支持內聯格式
                let content = String(trimmedLine[numberMatch.upperBound...])
                let numberPrefix = String(trimmedLine[..<numberMatch.upperBound])
                let processedContent = processRichText(content)
                let listText = applyListAttributes(processedContent, prefix: numberPrefix)
                mutableText.append(listText)
                mutableText.append(NSAttributedString(string: "\n"))
                
            } else if trimmedLine.hasPrefix("![") && trimmedLine.contains("](") {
                // 圖片markdown處理 - 格式: ![alt](url)
                let imagePattern = #"!\[(.*?)\]\((.*?)\)"#
                do {
                    let regex = try NSRegularExpression(pattern: imagePattern, options: [])
                    let matches = regex.matches(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine))
                    
                    if let match = matches.first,
                       match.numberOfRanges >= 3 {
                        // 提取URL
                        let urlRange = Range(match.range(at: 2), in: trimmedLine)!
                        let imageUrl = String(trimmedLine[urlRange])
                        
                        // 創建圖片佔位符 - 在加載draft時不實際加載圖片
                        let placeholderText = "圖片"
                        let placeholderAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 16),
                            .foregroundColor: UIColor.systemGray,
                            .backgroundColor: UIColor.systemGray6
                        ]
                        let placeholderString = NSAttributedString(string: placeholderText, attributes: placeholderAttributes)
                        mutableText.append(placeholderString)
                        mutableText.append(NSAttributedString(string: "\n"))
                    } else {
                        // 如果無法解析，當作普通文本處理
                        let processedLine = processRichText(trimmedLine)
                        mutableText.append(processedLine)
                        mutableText.append(NSAttributedString(string: "\n"))
                    }
                } catch {
                    // 正則表達式錯誤，當作普通文本處理
                    let processedLine = processRichText(trimmedLine)
                    mutableText.append(processedLine)
                    mutableText.append(NSAttributedString(string: "\n"))
                }
                
            } else if !trimmedLine.isEmpty {
                // 普通段落 - 支持內聯格式
                let processedLine = processRichText(trimmedLine)
                mutableText.append(processedLine)
                mutableText.append(NSAttributedString(string: "\n"))
            }
        }
        
        return mutableText
    }
    
    /// 應用標題屬性
    private static func applyHeadingAttributes(_ text: NSAttributedString, fontSize: CGFloat, weight: UIFont.Weight) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: mutableText.length)
        
        mutableText.enumerateAttributes(in: fullRange) { attributes, range, _ in
            var newAttributes = attributes
            // 設置標題字體，保持其他屬性（如顏色）
            let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
            newAttributes[.font] = font
            mutableText.setAttributes(newAttributes, range: range)
        }
        
        return mutableText
    }
    
    /// 應用列表屬性
    private static func applyListAttributes(_ attributedText: NSAttributedString, prefix: String) -> NSAttributedString {
        let mutableText = NSMutableAttributedString()
        
        // 創建前綴（編號或項目符號）
        let prefixAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.firstLineHeadIndent = 0
                style.headIndent = 24
                return style
            }()
        ]
        mutableText.append(NSAttributedString(string: prefix, attributes: prefixAttributes))
        
        // 添加處理過的內容，調整字體大小但保持其他格式
        let contentText = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: contentText.length)
        
        contentText.enumerateAttributes(in: fullRange) { attributes, range, _ in
            var newAttributes = attributes
            // 設置列表字體大小，保持其他屬性（如顏色、粗體）
            if let font = attributes[.font] as? UIFont {
                let newFont = font.withSize(17)
                newAttributes[.font] = newFont
            } else {
                newAttributes[.font] = UIFont.systemFont(ofSize: 17)
            }
            // 設置段落樣式
            newAttributes[.paragraphStyle] = prefixAttributes[.paragraphStyle]
            contentText.setAttributes(newAttributes, range: range)
        }
        
        mutableText.append(contentText)
        return mutableText
    }
    
    /// 處理 Markdown 圖片格式 ![alt](url) 並創建 NSTextAttachment
    private static func processImageMarkdown(_ markdown: String) -> NSAttributedString {
        // 這裡可以處理圖片markdown語法，目前返回佔位文字
        return NSAttributedString(string: "[圖片]", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.systemBlue
        ])
    }
    
    /// 處理富文本格式（包括顏色和粗體）
    private static func processRichText(_ text: String) -> NSAttributedString {
        // 首先處理顏色標籤
        let colorProcessed = processColorTags(text)
        // 然後處理粗體
        return processBoldText(colorProcessed)
    }
    
    /// 處理顏色標籤，支持兩種格式：<color:#hex>text</color> 和 <span style="color:#hex">text</span>
    private static func processColorTags(_ text: String) -> NSAttributedString {
        let mutableResult = NSMutableAttributedString()
        // 首先清理孤立的色彩標籤
        var remainingText = cleanupOrphanedColorTags(text)
        
        // 基礎屬性
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
        
        // 處理簡化格式和HTML格式，使用非貪婪匹配
        let patterns = [
            "<color:(#[0-9A-Fa-f]{6})>(.*?)</color>",
            "<span style=\"color:(#[0-9A-Fa-f]{6})\">(.*?)</span>"
        ]
        
        var foundMatch = false
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.count))
                
                if let firstMatch = matches.first {
                    foundMatch = true
                    
                    // 添加匹配前的文本
                    if firstMatch.range.location > 0 {
                        let beforeText = (remainingText as NSString).substring(with: NSRange(location: 0, length: firstMatch.range.location))
                        mutableResult.append(NSAttributedString(string: beforeText, attributes: normalAttributes))
                    }
                    
                    // 處理匹配的顏色文本
                    let hexColor = (remainingText as NSString).substring(with: firstMatch.range(at: 1))
                    let coloredText = (remainingText as NSString).substring(with: firstMatch.range(at: 2))
                    
                    var colorAttributes = normalAttributes
                    if let color = UIColor(hex: hexColor) {
                        colorAttributes[.foregroundColor] = color
                    }
                    mutableResult.append(NSAttributedString(string: coloredText, attributes: colorAttributes))
                    
                    // 遞歸處理剩餘文本
                    let afterMatchIndex = firstMatch.range.location + firstMatch.range.length
                    if afterMatchIndex < remainingText.count {
                        let afterText = (remainingText as NSString).substring(from: afterMatchIndex)
                        mutableResult.append(processColorTags(afterText))
                    }
                    
                    return mutableResult
                }
            } catch {
                Logger.error("顏色標籤處理失敗: \(error.localizedDescription)", category: .editor)
            }
        }
        
        // 如果沒有找到顏色標籤，返回普通文本
        return NSAttributedString(string: remainingText, attributes: normalAttributes)
    }
    
    /// 清理孤立的顏色標籤（沒有對應開始標籤的結束標籤）
    private static func cleanupOrphanedColorTags(_ text: String) -> String {
        var cleanedText = text
        
        // 移除孤立的 </color> 標籤
        cleanedText = cleanedText.replacingOccurrences(of: "</color>", with: "")
        
        // 移除孤立的 </span> 標籤
        let orphanedColorClosingTags = [
            "</color>",
            "</span>"
        ]
        
        for tag in orphanedColorClosingTags {
            cleanedText = cleanedText.replacingOccurrences(of: tag, with: "")
        }
        
        return cleanedText
    }
    
    /// 處理粗體格式 **text**，保持現有的顏色和其他屬性
    private static func processBoldText(_ attributedText: NSAttributedString) -> NSAttributedString {
        let text = attributedText.string
        let finalText = NSMutableAttributedString(attributedString: attributedText)
        let pattern = "\\*\\*(.*?)\\*\\*"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.count)
            let matches = regex.matches(in: text, options: [], range: range).reversed() // 從後往前處理避免範圍變化
            
            for match in matches {
                let boldTextRange = match.range(at: 1)
                let boldText = (text as NSString).substring(with: boldTextRange)
                
                // 獲取原有的屬性
                var existingAttributes = finalText.attributes(at: match.range.location, effectiveRange: nil)
                
                // 添加粗體屬性，保持其他屬性（如顏色）
                if let existingFont = existingAttributes[.font] as? UIFont {
                    existingAttributes[.font] = existingFont.addingBold()
                } else {
                    existingAttributes[.font] = UIFont.systemFont(ofSize: 16, weight: .bold)
                }
                
                // 替換整個 **text** 為粗體文本
                finalText.replaceCharacters(in: match.range, with: NSAttributedString(string: boldText, attributes: existingAttributes))
            }
            
        } catch {
            // 如果正則表達式失敗，返回原文本
            return attributedText
        }
        
        return finalText
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

// MARK: - String 擴展：高度計算
extension String {
    func calculateTextHeight(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
}


// MARK: - UIColor 擴展
extension UIColor {
    var hexString: String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
    
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    convenience init?(hex: String) {
        self.init(hexString: hex)
    }
}

// MARK: - Image Utils
class ImageUtils {
    static func generateImageId(from image: UIImage) -> String {
        // 使用圖片的雜湊值生成一致性ID
        guard let imageData = image.pngData() else {
            return UUID().uuidString
        }
        
        // 計算圖片數據的雜湊值作為唯一ID
        let hash = imageData.hashValue
        return "image_\(abs(hash))"
    }
} 
