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
    @State private var showTableEditor = false
    @State private var currentTable = GridTable(rows: 3, columns: 3)
    
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
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: .constant(nil),
            matching: .images
        )
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
        .sheet(isPresented: $showTableEditor) {
            NavigationView {
                VStack {
                    GridTableEditorView(table: $currentTable)
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle("編輯表格")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") {
                            showTableEditor = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("插入") {
                            insertTable(currentTable)
                            showTableEditor = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
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
                
                TextEditor(text: $content)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textColor)
                    .frame(minHeight: 400)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            showFloatingToolbar = true
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
                
                // 格式化工具（整合現有功能）
                HStack(spacing: 16) {
                    // 標題格式
                    toolbarButton(icon: "textformat", action: { insertMarkdown("# ") })
                    toolbarButton(icon: "quote.bubble", action: { insertMarkdown("> ") })
                    
                    // 文字格式
                    formatButton("B", isBold: true, action: { insertMarkdown("**", suffix: "**") })
                    formatButton("I", isItalic: true, action: { insertMarkdown("*", suffix: "*") })
                    
                    // 列表
                    toolbarButton(icon: "list.bullet", action: { insertMarkdown("- ") })
                    toolbarButton(icon: "line.horizontal.3", action: { insertMarkdown("---\n") })
                    
                    // 特殊格式
                    toolbarButton(icon: "at", action: { insertMarkdown("@") })
                    toolbarButton(icon: "curlybraces", action: { insertMarkdown("```\n", suffix: "\n```") })
                    
                    // 圖片上傳按鈕
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    
                    // 表格按鈕
                    Button(action: { 
                        currentTable = GridTable(rows: 3, columns: 3)
                        showTableEditor = true 
                    }) {
                        Image(systemName: "tablecells")
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                    
                    // 內容預覽 - 使用 Markdown 渲染
                    if !content.isEmpty {
                        Markdown(content)
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
                    } else {
                        Text("暫無內容")
                            .font(.system(size: 16))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    // 圖片預覽
                    if !selectedImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(8)
                                    .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(backgroundColor)
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