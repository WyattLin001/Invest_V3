import SwiftUI
import UIKit
import Combine
import Foundation
import PhotosUI
import MarkdownUI



// MARK: - 主編輯器視圖
struct ArticleEditorView: View {
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPaidContent: Bool = false
    @State private var selectedCategory: String = "投資分析"
    @State private var keywords: [String] = []
    @State private var isDraft: Bool = true
    @State private var showSettings: Bool = false
    @State private var showPreview: Bool = false
    @State private var showFloatingToolbar: Bool = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0.0
    @State private var isShowingDraftAlert = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // 從 InfoView 獲取分類選項
    private let categories = ["全部", "投資分析", "市場趨勢", "個股研究", "加密貨幣"]
    
    // 字數統計
    private let maxTitleLength = 50
    @State private var titleCharacterCount = 0
    
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
        !title.isEmpty || !content.isEmpty || !selectedImages.isEmpty
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 頂部導航欄
                navigationHeader
                
                // 主編輯區域
                ScrollView {
                    VStack(spacing: 16) {
                        // 標題編輯
                        titleEditor
                        
                        // 內容編輯
                        contentEditor
                        
                        // 圖片管理區域
                        imageManagementSection
                        
                        // 底部間距
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // 浮動工具列
            if showFloatingToolbar && !showPreview {
                floatingToolbar
            }
            
            // 上傳進度覆蓋層
            if isUploadingImage {
                uploadProgressOverlay
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            ArticleSettingsView(
                subtopic: $selectedCategory,
                isPaidContent: $isPaidContent,
                isDraft: $isDraft
            )
        }
        .sheet(isPresented: $showPreview) {
            ArticlePreviewView(
                title: title,
                content: content,
                isPaidContent: isPaidContent,
                selectedImages: selectedImages
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 5,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { oldValue, newValue in
            print("📸 onChange 觸發 - 舊: \(oldValue.count), 新: \(newValue.count)")
            
            if newValue.count > oldValue.count {
                print("📸 開始處理圖片...")
                Task {
                    await processNewPhotos(newValue)
                }
            } else {
                print("📸 沒有新項目，跳過處理")
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
    }
    
    // MARK: - 頂部導航欄
    private var navigationHeader: some View {
        HStack {
            // 1. 關閉按鈕
            Button("Close") {
                if hasUnsavedChanges {
                    isShowingDraftAlert = true
                } else {
                    dismiss()
                }
            }
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(textColor)
            
            Spacer()
            
            // 設定按鈕（...）
            Button(action: { showSettings = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(textColor)
            }
            
            // 預覽按鈕
            Button(action: { showPreview = true }) {
                Image(systemName: "eye")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(textColor)
            }
            
            // 2. 上傳/Next 按鈕
            Button("Next") {
                Task {
                    await uploadToSupabase()
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(canUpload ? .brandGreen : secondaryTextColor)
            .disabled(!canUpload)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - 標題編輯器（仿 Medium 風格）
    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // 藍色線條裝飾
                Rectangle()
                    .frame(width: 4, height: 40)
                    .foregroundColor(.brandBlue)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 標題輸入框
                    TextField("Title", text: $title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(textColor)
                        .textFieldStyle(PlainTextFieldStyle())
                        .multilineTextAlignment(.leading)
                        .onChange(of: title) { _, newValue in
                            if newValue.count > maxTitleLength {
                                title = String(newValue.prefix(maxTitleLength))
                            }
                            titleCharacterCount = title.count
                        }
                    
                    // 字數統計
                    HStack {
                        Spacer()
                        Text("\(titleCharacterCount)/\(maxTitleLength)")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - 內容編輯器
    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 內容輸入
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("Tell your story...")
                        .font(.system(size: 18))
                        .foregroundColor(secondaryTextColor.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                CustomTextEditor(text: $content)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textColor)
                    .frame(minHeight: 400)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            showFloatingToolbar = true
                        }
                    }
                    .onAppear {
                        // 編輯器出現時就顯示工具列
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3)) {
                                showFloatingToolbar = true
                            }
                        }
                    }
            }
            
            // 3. 免費/付費切換
            paymentToggle
        }
    }
    
    private var paymentToggle: some View {
        HStack {
            Text("付費內容")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            Spacer()
            
            Toggle("", isOn: $isPaidContent)
                .toggleStyle(SwitchToggleStyle(tint: .brandBlue))
                .scaleEffect(0.9)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.brandBlue.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - 圖片管理區域
    private var imageManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !selectedImages.isEmpty {
                Text("圖片")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            imagePreviewCard(image: image, index: index)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // 添加圖片按鈕
            Button(action: { showImagePicker = true }) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16))
                    Text("添加圖片")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.brandBlue)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.brandBlue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 圖片預覽卡片
    private func imagePreviewCard(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)
            
            Button(action: {
                selectedImages.remove(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(4)
        }
    }
    
    // MARK: - 浮動工具列（整合現有功能）
    private var floatingToolbar: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 0) {
                // 收起按鈕
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showFloatingToolbar = false
                    }
                }) {
                    Text("Aa")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.brandBlue)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                Spacer()
                
                // 簡化的格式化工具（減少約束衝突）
                HStack(spacing: 12) {
                    // 基本格式
                    formatButton("B", isBold: true, action: { insertMarkdown("**", suffix: "**") })
                    formatButton("I", isItalic: true, action: { insertMarkdown("*", suffix: "*") })
                    
                    // 標題和列表
                    toolbarButton(icon: "textformat", action: { insertMarkdown("# ") })
                    toolbarButton(icon: "list.bullet", action: { insertMarkdown("- ") })
                    
                    // 圖片上傳
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - 工具列按鈕
    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
        }
    }
    
    private func formatButton(_ text: String, isBold: Bool = false, isItalic: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 16, weight: isBold ? .bold : .medium))
                .italic(isItalic)
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
        }
    }
    
    // MARK: - 上傳進度覆蓋層
    private var uploadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView("正在上傳圖片...", value: uploadProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .brandBlue))
                    .frame(width: 200)
                
                Button("取消") {
                    isUploadingImage = false
                    uploadProgress = 0.0
                }
                .foregroundColor(.danger)
            }
            .padding(24)
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }
    
    // MARK: - 計算屬性
    private var canUpload: Bool {
        !title.isEmpty && !content.isEmpty
    }
    
    // MARK: - 功能方法
    private func insertMarkdown(_ prefix: String, suffix: String = "") {
        if !suffix.isEmpty {
            content += "\(prefix)文字\(suffix)"
        } else {
            content += prefix
        }
    }
    
    private func saveDraft() {
        isDraft = true
        // TODO: 實現草稿保存邏輯
        print("保存草稿: \(title)")
    }
    
    private func uploadToSupabase() async {
        guard !title.isEmpty && !content.isEmpty else { return }
        
        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }
        
        do {
            var finalContent = content
            
            // 如果有圖片，先上傳圖片
            if !selectedImages.isEmpty {
                var imageUrls: [String] = []
                
                for (index, image) in selectedImages.enumerated() {
                    await MainActor.run {
                        uploadProgress = Double(index) / Double(selectedImages.count) * 0.8
                    }
                    
                    guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
                    let fileName = "article_image_\(UUID().uuidString).jpg"
                    
                    let imageUrl = try await SupabaseService.shared.uploadImage(
                        data: imageData,
                        fileName: fileName
                    )
                    
                    imageUrls.append(imageUrl.absoluteString)
                }
                
                // 將圖片 URL 加入到文章內容中
                if !imageUrls.isEmpty {
                    var imageMarkdown = "\n\n"
                    for url in imageUrls {
                        imageMarkdown += "![圖片](\(url))\n\n"
                    }
                    finalContent += imageMarkdown
                }
            }
            
            await MainActor.run {
                uploadProgress = 0.9
            }
            
            try await SupabaseService.shared.createArticle(
                title: title,
                content: finalContent,
                category: selectedCategory,
                bodyMD: finalContent,
                isFree: !isPaidContent
            )
            
            await MainActor.run {
                uploadProgress = 1.0
                isUploadingImage = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isUploadingImage = false
                uploadProgress = 0.0
            }
            print("上傳失敗: \(error)")
        }
    }
    
    // MARK: - 圖片處理
    private func processNewPhotos(_ photoItems: [PhotosPickerItem]) async {
        print("📸 處理 \(photoItems.count) 個圖片項目")
        
        for item in photoItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    print("📸 成功載入圖片數據，大小: \(data.count) bytes")
                    
                    if let uiImage = UIImage(data: data) {
                        print("📸 成功創建 UIImage，尺寸: \(uiImage.size)")
                        
                        await MainActor.run {
                            print("📸 添加圖片到列表，當前數量: \(selectedImages.count)")
                            selectedImages.append(uiImage)
                            print("📸 圖片列表更新後數量: \(selectedImages.count)")
                            
                            // 插入圖片到編輯器
                            insertImageMarkdown()
                        }
                    } else {
                        print("❌ 無法從數據創建 UIImage")
                    }
                } else {
                    print("❌ 無法載入圖片數據")
                }
            } catch {
                print("❌ 載入圖片時發生錯誤: \(error.localizedDescription)")
            }
        }
        
        // 清空選擇的項目以允許重新選擇同一張圖片
        await MainActor.run {
            selectedPhotoItems.removeAll()
        }
    }
    
    private func insertImageMarkdown() {
        let imageCount = selectedImages.count
        let imageMarkdown = "![圖片 \(imageCount)](.image\(imageCount))\n\n"
        
        // 在當前內容末尾插入，保留原有文字
        if content.isEmpty {
            content = imageMarkdown
        } else {
            // 如果文字不為空，在末尾添加
            if !content.hasSuffix("\n") {
                content += "\n"
            }
            content += imageMarkdown
        }
        
        print("📸 插入圖片到編輯器: \(imageMarkdown)")
    }
    
    private func getCurrentUserId() -> UUID {
        // 獲取當前用戶 ID
        if let data = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return user.id
        }
        return UUID()
    }
}

// MARK: - 文章設定頁面
struct ArticleSettingsView: View {
    @Binding var subtopic: String
    @Binding var isPaidContent: Bool
    @Binding var isDraft: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let subtopics = ["投資分析", "市場動態", "技術分析", "基本面分析", "風險管理", "投資心得", "新手教學", "其他"]
    
    private var backgroundColor: Color {
        colorScheme == .dark ? .gray100 : Color(.systemGroupedBackground)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("文章設定") {
                    // 子主題選擇
                    Picker("子主題", selection: $subtopic) {
                        ForEach(subtopics, id: \.self) { topic in
                            Text(topic).tag(topic)
                        }
                    }
                    
                    // 付費內容設定
                    Toggle("付費內容", isOn: $isPaidContent)
                        .toggleStyle(SwitchToggleStyle(tint: .brandBlue))
                    
                    // 草稿設定
                    Toggle("儲存為草稿", isOn: $isDraft)
                        .toggleStyle(SwitchToggleStyle(tint: .brandBlue))
                }
                
                Section("預覽") {
                    Button("預覽文章") {
                        // 觸發預覽
                    }
                    .foregroundColor(.brandBlue)
                }
            }
            .background(backgroundColor)
            .scrollContentBackground(.hidden)
            .navigationTitle("文章設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 文章預覽頁面
struct ArticlePreviewView: View {
    let title: String
    let content: String
    let isPaidContent: Bool
    let selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? .gray100 : .white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .gray900 : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .gray600 : .secondary
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // 付費標識
                    if isPaidContent {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.brandBlue)
                            Text("付費內容")
                                .font(.caption)
                                .foregroundColor(.brandBlue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandBlue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // 標題預覽
                    Text(title.isEmpty ? "無標題" : title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textColor)
                    
                    // 內容預覽 - 移除圖片 Markdown 引用，只顯示文字
                    if !content.isEmpty {
                        let cleanedContent = content
                            .replacingOccurrences(of: #"!\[圖片 \d+\]\(\.image\d+\)\n\n"#, with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !cleanedContent.isEmpty {
                            Markdown(cleanedContent)
                                .markdownTextStyle {
                                    FontSize(16)
                                }
                                .foregroundColor(textColor)
                                .markdownBlockStyle(\.heading1) { configuration in
                                    configuration.label
                                        .markdownTextStyle {
                                            FontWeight(.bold)
                                            FontSize(24)
                                        }
                                        .foregroundColor(textColor)
                                }
                                .markdownBlockStyle(\.heading2) { configuration in
                                    configuration.label
                                        .markdownTextStyle {
                                            FontWeight(.semibold)
                                            FontSize(20)
                                        }
                                        .foregroundColor(textColor)
                                }
                        }
                    } else if selectedImages.isEmpty {
                        Text("暫無內容")
                            .font(.system(size: 16))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    // 圖片預覽（立即顯示本地圖片）
                    if !selectedImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("圖片")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(textColor)
                            
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: 300)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    
                                    Text("圖片 \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(secondaryTextColor)
                                        .padding(.leading, 4)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // 底部適當間距
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .background(backgroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("預覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

