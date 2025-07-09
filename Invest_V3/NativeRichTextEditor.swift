import SwiftUI
import UIKit
import Combine
import Foundation
import PhotosUI
import Supabase
import MarkdownUI

struct NativeRichTextEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // 文章草稿狀態
    @State private var draft: ArticleDraft
    @State private var isPreviewMode = false
    @State private var showOptionsMenu = false
    @State private var showSubtopicsSheet = false
    @State private var showDraftsSheet = false
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0.0
    @State private var selectedImages: [UIImage] = []
    @State private var showFloatingToolbar = false
    @State private var isShowingDraftAlert = false
    
    // 字數統計
    @State private var titleCharacterCount = 0
    private let maxTitleLength = 50
    
    // 初始化
    init(draft: ArticleDraft = ArticleDraft()) {
        _draft = State(initialValue: draft)
        _titleCharacterCount = State(initialValue: draft.title.count)
    }
    
    // 檢查是否有未保存的更改
    private var hasUnsavedChanges: Bool {
        !draft.title.isEmpty || !draft.bodyMD.isEmpty || !selectedImages.isEmpty
    }
    
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
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定義導航欄
                customNavigationBar
                
                // 主內容區域
                ScrollView {
                    VStack(spacing: 24) {
                        // 標題輸入區域
                        titleInputSection
                        
                        // 內容編輯/預覽區域
                        if isPreviewMode {
                            previewSection
                        } else {
                            contentEditingSection
                        }
                        
                        // 圖片管理區域
                        imageManagementSection
                        
                        // 底部間距
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            
            // 浮動工具列
            if showFloatingToolbar && !isPreviewMode {
                floatingToolbar
            }
            
            // 上傳進度覆蓋層
            if isUploadingImage {
                uploadProgressOverlay
            }
        }
        .sheet(isPresented: $showSubtopicsSheet) {
            SubtopicsSelectionView(draft: $draft)
        }
        .sheet(isPresented: $showDraftsSheet) {
            DraftsView()
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
    }
    
    // MARK: - 自定義導航欄
    private var customNavigationBar: some View {
        HStack {
            // 關閉按鈕
            Button(action: {
                if hasUnsavedChanges {
                    isShowingDraftAlert = true
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor)
            }
            
            Spacer()
            
            // 免費/付費切換
            HStack(spacing: 12) {
                Text("免費")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(draft.isFree ? .brandBlue : secondaryTextColor)
                
                Toggle("", isOn: Binding(
                    get: { !draft.isFree },
                    set: { draft.isFree = !$0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .brandBlue))
                .scaleEffect(0.8)
                
                Text("付費")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(!draft.isFree ? .brandBlue : secondaryTextColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brandBlue.opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
            
            // 選項選單按鈕
            Menu {
                Button("設定子主題") {
                    showSubtopicsSheet = true
                }
                Button("草稿") {
                    showDraftsSheet = true
                }
                Button(isPreviewMode ? "編輯模式" : "預覽模式") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPreviewMode.toggle()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor)
            }
            
            // 上傳按鈕
            Button(action: uploadArticle) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(canUpload ? .brandBlue : secondaryTextColor)
            }
            .disabled(!canUpload)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor)
    }
    
    // MARK: - 標題輸入區域
    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("文章標題", text: $draft.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textColor)
                .onChange(of: draft.title) { _, newValue in
                    if newValue.count > maxTitleLength {
                        draft.title = String(newValue.prefix(maxTitleLength))
                    }
                    titleCharacterCount = draft.title.count
                }
            
            HStack {
                Spacer()
                Text("\(titleCharacterCount)/\(maxTitleLength)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
    }
    
    // MARK: - 內容編輯區域
    private var contentEditingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 副標題
            TextField("副標題（可選）", text: Binding<String>(
                get: { draft.subtitle ?? "" },
                set: { newValue in 
                    draft.subtitle = newValue.isEmpty ? nil : newValue 
                }
            ))
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(secondaryTextColor)
            
            // 內容編輯器
            ZStack(alignment: .topLeading) {
                if draft.bodyMD.isEmpty {
                    Text("開始寫作...")
                        .font(.system(size: 18))
                        .foregroundColor(secondaryTextColor.opacity(0.6))
                        .padding(.top, 8)
                }
                
                TextEditor(text: $draft.bodyMD)
                    .font(.system(size: 18))
                    .foregroundColor(textColor)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 300)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            showFloatingToolbar = true
                        }
                    }
            }
        }
    }
    
    // MARK: - 預覽區域
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題預覽
            Text(draft.title.isEmpty ? "無標題" : draft.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textColor)
            
            // 副標題預覽
            if let subtitle = draft.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            // Markdown 內容預覽
            if !draft.bodyMD.isEmpty {
                Markdown(draft.bodyMD)
                    .markdownTextStyle {
                        FontSize(18)
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
                    .font(.system(size: 18))
                    .foregroundColor(secondaryTextColor.opacity(0.6))
            }
        }
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
    
    // MARK: - 浮動工具列
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
                
                // 格式化工具
                HStack(spacing: 16) {
                    formatButton("H1", action: { insertMarkdown("# ") })
                    formatButton("H2", action: { insertMarkdown("## ") })
                    formatButton("B", isBold: true, action: { insertMarkdown("**", suffix: "**") })
                    formatButton("I", isItalic: true, action: { insertMarkdown("*", suffix: "*") })
                    formatButton("•", action: { insertMarkdown("- ") })
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
    
    // MARK: - 格式化按鈕
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
        !draft.title.isEmpty && !draft.bodyMD.isEmpty
    }
    
    // MARK: - 功能方法
    private func insertMarkdown(_ prefix: String, suffix: String = "") {
        if !suffix.isEmpty {
            draft.bodyMD += "\(prefix)文字\(suffix)"
        } else {
            draft.bodyMD += prefix
        }
    }
    
    private func saveDraft() {
        // TODO: 實現草稿保存邏輯
        print("保存草稿: \(draft.title)")
    }
    
    private func uploadArticle() {
        // TODO: 實現文章上傳邏輯
        print("上傳文章: \(draft.title)")
    }
}

// MARK: - 子主題選擇視圖
struct SubtopicsSelectionView: View {
    @Binding var draft: ArticleDraft
    @Environment(\.dismiss) var dismiss
    
    private let topics = ["投資分析", "市場動態", "技術分析", "基本面分析", "風險管理", "投資心得", "新手教學", "其他"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("選擇分類") {
                    Picker("分類", selection: $draft.category) {
                        ForEach(topics, id: \.self) { topic in
                            Text(topic).tag(topic)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                
                Section("文章設定") {
                    HStack {
                        Text("文章類型")
                        Spacer()
                        Picker("", selection: $draft.isFree) {
                            Text("免費").tag(true)
                            Text("付費").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                }
            }
            .navigationTitle("設定子主題")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
} 

