import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Action enum sent back to the caller

enum PublishSheetAction {
    case preview
    case publish
    case shareDraft(URL)
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
    @State private var selectedCoverImage: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var selectedPublication: Publication?
    @State private var customSlug: String = ""
    @State private var publishTime: PublishTime = .now
    @State private var scheduledDate = Date()
    @State private var socialSharing = true
    @State private var emailNewsletter = false
    @State private var showAdvancedSettings = false
    @State private var qualityScore: Double = 0.0
    
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
                    // 文章質量評分
                    qualityScoreSection
                    
                    // 封面圖片
                    coverImageSection
                    
                    // 標題和副標題
                    titleSection
                    
                    // 關鍵字管理
                    keywordsSection
                    
                    // 發布設定
                    publishSettingsSection
                    
                    // 高級設定（可展開）
                    advancedSettingsSection
                    
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
            .alert("關鍵字數量已達上限 (5)", isPresented: $showTagLimitAlert) {
                Button("確定", role: .cancel) {}
            }
            .onAppear {
                calculateQualityScore()
                customSlug = draft.slug.isEmpty ? draft.title.slugified() : draft.slug
            }
            .onChange(of: draft.title) { _, _ in
                calculateQualityScore()
                if customSlug.isEmpty {
                    customSlug = draft.title.slugified()
                }
            }
            .onChange(of: draft.bodyMD) { _, _ in
                calculateQualityScore()
            }
            .onChange(of: draft.keywords) { _, _ in
                calculateQualityScore()
            }
        }
    }

    // MARK: - 文章質量評分區域
    private var qualityScoreSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("文章質量")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text("\(Int(qualityScore * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(qualityScoreColor)
            }
            
            ProgressView(value: qualityScore)
                .progressViewStyle(LinearProgressViewStyle(tint: qualityScoreColor))
                .frame(height: 8)
            
            Text(qualityScoreText)
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.leading)
        }
        .padding(DesignTokens.spacingMD)
        .background(qualityScoreColor.opacity(0.1))
        .cornerRadius(DesignTokens.cornerRadius)
    }
    
    private var qualityScoreColor: Color {
        if qualityScore >= 0.8 { return .green }
        if qualityScore >= 0.6 { return .orange }
        return .red
    }
    
    private var qualityScoreText: String {
        if qualityScore >= 0.8 {
            return "文章質量優秀，可以發布"
        } else if qualityScore >= 0.6 {
            return "文章質量良好，建議完善後發布"
        } else {
            return "文章需要進一步完善"
        }
    }

    // MARK: - 封面圖片區域
    private var coverImageSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("封面圖片")
                .font(.headline)
                .foregroundColor(textColor)
            
            if draft.hasCoverImage, let imageUrl = draft.safeCoverImageURL {
                AsyncImage(url: imageUrl) { image in
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
                    HStack(spacing: 8) {
                        PhotosPicker(
                            selection: $selectedCoverImage,
                            matching: .images
                        ) {
                            Text("更換")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignTokens.spacingSM)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(DesignTokens.cornerRadiusSM)
                        }
                        
                        Button("移除") {
                            draft.coverImageURL = nil
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.spacingSM)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(DesignTokens.cornerRadiusSM)
                    }
                    .padding(DesignTokens.spacingSM),
                    alignment: .topTrailing
                )
            } else {
                PhotosPicker(
                    selection: $selectedCoverImage,
                    matching: .images
                ) {
                    VStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.gray600)
                        
                        Text("添加封面圖片")
                            .font(.subheadline)
                            .foregroundColor(.gray600)
                        
                        Text("推薦尺寸: 1200×630 像素")
                            .font(.caption)
                            .foregroundColor(.gray500)
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
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedCoverImage, matching: .images)
        .onChange(of: selectedCoverImage) { _, newItem in
            Task {
                await processCoverImage(newItem)
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
    
    // MARK: - 關鍵字管理區域
    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("關鍵字")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text("\(draft.keywords.count)/\(maxTags)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            // 關鍵字輸入
            HStack(spacing: DesignTokens.spacingSM) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.gray600)
                        .font(.system(size: 16))
                    
                    TextField("輸入關鍵字", text: $newTag)
                        .onSubmit {
                            addTag()
                        }
                        .disabled(draft.keywords.count >= maxTags)
                }
                .padding(DesignTokens.spacingSM)
                .background(Color.gray100)
                .cornerRadius(DesignTokens.cornerRadiusSM)
                
                if !newTag.isEmpty && draft.keywords.count < maxTags {
                    Button("添加") {
                        addTag()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGreen)
                }
            }
            
            // 關鍵字顯示
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                if !draft.keywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.spacingSM) {
                            ForEach(draft.keywords, id: \.self) { keyword in
                                KeywordBubble(keyword: keyword) {
                                    remove(keyword)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    Text("尚未添加關鍵字")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                        .padding(.vertical, DesignTokens.spacingSM)
                }
            }
            
            Text("最多可添加 \(maxTags) 個關鍵字")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
        }
    }
    
    // MARK: - 發布設定區域
    private var publishSettingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("發布設定")
                .font(.headline)
                .foregroundColor(textColor)
            
            // 發布時間選擇
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("發布時間")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                
                Picker("發布時間", selection: $publishTime) {
                    Text("立即發布").tag(PublishTime.now)
                    Text("稍後發布").tag(PublishTime.later)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if publishTime == .later {
                    DatePicker("發布時間", selection: $scheduledDate, in: Date()...)
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }
            
            // 可見性設定
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("可見性")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                
                HStack {
                    Toggle("免費文章", isOn: $draft.isFree)
                    Spacer()
                }
                
                if !draft.isFree {
                    HStack {
                        Toggle("付費內容", isOn: $draft.isPaid)
                        Spacer()
                    }
                }
                
                HStack {
                    Toggle("未列出（僅限鏈接）", isOn: $draft.isUnlisted)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - 高級設定區域  
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedSettings.toggle()
                }
            }) {
                HStack {
                    Text("高級設定")
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    Image(systemName: showAdvancedSettings ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: showAdvancedSettings)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showAdvancedSettings {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    // 自定義URL
                    VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                        Text("自定義 URL")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(textColor)
                        
                        HStack {
                            Text("investv3.com/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("url-slug", text: $customSlug)
                                .font(.caption)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customSlug) { _, newValue in
                                    draft.slug = newValue.slugified()
                                }
                        }
                        
                        if !customSlug.isEmpty {
                            Text("完整URL: \(draft.canonicalURL)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 發布選項
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        Text("發布選項")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(textColor)
                        
                        HStack {
                            Toggle("社群媒體分享", isOn: $socialSharing)
                            Spacer()
                        }
                        
                        HStack {
                            Toggle("電子報通知", isOn: $emailNewsletter)
                            Spacer()
                        }
                    }
                }
                .padding(.top, DesignTokens.spacingSM)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - 操作按鈕區域
    private var actionButtonsSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 預覽按鈕
            Button(action: {
                onAction(.preview)
                dismiss()
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
        let keyword = newTag.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        guard draft.keywords.count < maxTags else {
            showTagLimitAlert = true
            return
        }
        if !draft.keywords.contains(keyword) {
            draft.keywords.append(keyword)
            print("✅ 已添加關鍵字: \(keyword), 當前關鍵字: \(draft.keywords)")
        }
        newTag = ""
    }

    private func remove(_ keyword: String) {
        draft.keywords.removeAll { $0 == keyword }
        print("🗑️ 已刪除關鍵字: \(keyword), 當前關鍵字: \(draft.keywords)")
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
    
    // MARK: - Quality Score Calculation
    private func calculateQualityScore() {
        var score: Double = 0.0
        let totalCriteria = 9.0 // Increased to include cover image
        
        // Title check (20%)
        if !draft.title.isEmpty {
            score += 1.0
            if draft.title.count >= 10 && draft.title.count <= 60 {
                score += 0.6 // Bonus for optimal length
            }
        }
        
        // Content length check (20%)
        let contentLength = draft.bodyMD.count
        if contentLength > 100 { score += 1.0 }
        if contentLength > 500 { score += 0.6 }
        
        // Keywords check (15%)
        if !draft.keywords.isEmpty {
            score += 1.0
            if draft.keywords.count >= 3 { score += 0.2 }
        }
        
        // Cover image check (10%)
        if draft.hasCoverImage {
            score += 0.9
        }
        
        // Subtitle check (10%)
        if let subtitle = draft.subtitle, !subtitle.isEmpty {
            score += 0.8
        }
        
        // Category check (10%)
        if !draft.category.isEmpty { score += 0.8 }
        
        // Custom slug check (5%)
        if !draft.slug.isEmpty { score += 0.4 }
        
        // Structure check - paragraphs (5%)
        let paragraphs = draft.bodyMD.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        if paragraphs.count >= 2 {
            score += 0.4
            if paragraphs.count >= 4 { score += 0.1 }
        }
        
        // Length balance (5%)
        if contentLength >= 200 && contentLength <= 2000 {
            score += 0.4
        }
        
        qualityScore = min(1.0, score / totalCriteria)
    }
    
    // MARK: - Cover Image Processing
    private func processCoverImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("❌ 無法載入圖片數據")
                return
            }
            
            guard let image = UIImage(data: data) else {
                print("❌ 無法處理圖片數據")
                return
            }
            
            // 壓縮圖片以節省空間
            let maxSize: CGFloat = 1200
            let resizedImage = resizeImage(image, targetSize: maxSize)
            
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.8) else {
                print("❌ 圖片壓縮失敗")
                return
            }
            
            // 生成唯一文件名
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "cover_\(draft.id.uuidString.prefix(8))_\(timestamp).jpg"
            
            // 上傳到 Supabase
            let imageUrl = try await SupabaseService.shared.uploadArticleImageWithContentType(
                compressedData, 
                fileName: fileName, 
                contentType: "image/jpeg"
            )
            
            await MainActor.run {
                draft.coverImageURL = imageUrl
                selectedCoverImage = nil
                print("✅ 封面圖片上傳成功: \(imageUrl)")
            }
            
        } catch {
            await MainActor.run {
                print("❌ 封面圖片處理失敗: \(error.localizedDescription)")
                selectedCoverImage = nil
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGFloat) -> UIImage {
        let size = image.size
        let widthRatio = targetSize / size.width
        let heightRatio = targetSize / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // 如果圖片已經小於目標尺寸，直接返回
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

// MARK: - Enums

enum PublishTime: String, CaseIterable {
    case now = "now"
    case later = "later"
}

// MARK: - 學術風格關鍵字氣泡視圖
private struct KeywordBubble: View {
    let keyword: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(keyword)
                .font(.caption)
                .fontWeight(.regular)
                .foregroundColor(.secondary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
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
            case .shareDraft(let url):
                print("Share draft: \(url)")
            }
        }
    }
}
#endif 
