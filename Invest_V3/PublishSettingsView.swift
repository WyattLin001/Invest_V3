import SwiftUI

struct PublishSettingsView: View {
    @Binding var selectedCategory: String
    @Binding var keywords: [String]
    @Binding var isPaidContent: Bool
    let onPublish: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var newTag = ""
    
    // 新增的文章內容欄位
    @State private var articleTitle = ""
    @State private var articleSubtitle = ""
    @State private var coverImageURL: String?
    @State private var showingImagePicker = false
    @State private var showingPreview = false
    
    private let categories = ["投資分析", "市場趨勢", "個股研究", "加密貨幣"]
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    // 封面圖片
                    coverImageSection
                    
                    // 標題和副標題
                    titleSection
                    
                    // 分類選擇
                    categorySection
                    
                    // 標籤管理
                    tagsSection
                    
                    // 付費設定
                    paidContentSection
                    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(textColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("發布") {
                        handlePublish()
                    }
                    .foregroundColor(.brandGreen)
                    .fontWeight(.semibold)
                    .disabled(articleTitle.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            PreviewView(
                title: articleTitle,
                subtitle: articleSubtitle,
                category: selectedCategory,
                tags: keywords,
                coverImageURL: coverImageURL,
                isPaidContent: isPaidContent
            )
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
                Button(action: { showingImagePicker = true }) {
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
                TextField("文章標題 (必填)", text: $articleTitle)
                    .font(.title3)
                    .foregroundColor(textColor)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .background(Color.gray100)
                    .cornerRadius(DesignTokens.cornerRadiusSM)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM)
                            .stroke(articleTitle.isEmpty ? Color.danger : Color.clear, lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    Text("\(articleTitle.count)/\(maxTitleLength)")
                        .font(.caption)
                        .foregroundColor(articleTitle.count > maxTitleLength ? .danger : secondaryTextColor)
                }
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                TextField("副標題 (選填)", text: $articleSubtitle, axis: .vertical)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .lineLimit(2...4)
                    .padding(DesignTokens.spacingSM)
                    .background(Color.gray100)
                    .cornerRadius(DesignTokens.cornerRadiusSM)
                
                HStack {
                    Spacer()
                    Text("\(articleSubtitle.count)/\(maxSubtitleLength)")
                        .font(.caption)
                        .foregroundColor(articleSubtitle.count > maxSubtitleLength ? .danger : secondaryTextColor)
                }
            }
        }
    }
    
    // MARK: - 分類選擇區域
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("文章分類")
                .font(.headline)
                .foregroundColor(textColor)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignTokens.spacingSM) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        title: category,
                        isSelected: selectedCategory == category,
                        textColor: textColor
                    ) {
                        selectedCategory = category
                    }
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
                
                Text("\(keywords.count)/\(maxTags)")
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
                        .disabled(keywords.count >= maxTags)
                }
                .padding(DesignTokens.spacingSM)
                .background(Color.gray100)
                .cornerRadius(DesignTokens.cornerRadiusSM)
                
                if !newTag.isEmpty && keywords.count < maxTags {
                    Button("添加") {
                        addTag()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGreen)
                }
            }
            
            // 標籤顯示
            if !keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(keywords, id: \.self) { tag in
                            TagBubbleView(tag: tag) {
                                keywords.removeAll { $0 == tag }
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
    
    // MARK: - 付費內容設定
    private var paidContentSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("內容設定")
                .font(.headline)
                .foregroundColor(textColor)
            
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("付費內容")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)
                    
                    Text("開啟後讀者需要付費才能閱讀完整內容")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Toggle("", isOn: $isPaidContent)
                    .tint(.brandOrange)
            }
            .padding(DesignTokens.spacingSM)
            .background(Color.gray100)
            .cornerRadius(DesignTokens.cornerRadiusSM)
        }
    }
    
    // MARK: - 操作按鈕區域
    private var actionButtonsSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 預覽按鈕
            Button(action: { showingPreview = true }) {
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
            .disabled(articleTitle.isEmpty)
            
            // 發布按鈕
            Button(action: handlePublish) {
                Text("發布文章")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .foregroundColor(.white)
                    .background(articleTitle.isEmpty ? Color.gray400 : Color.brandGreen)
                    .cornerRadius(DesignTokens.cornerRadius)
            }
            .disabled(articleTitle.isEmpty)
        }
    }
    
    // MARK: - 添加標籤
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && 
           !keywords.contains(trimmedTag) && 
           keywords.count < maxTags {
            keywords.append(trimmedTag)
            newTag = ""
        }
    }
    
    // MARK: - 處理發布
    private func handlePublish() {
        guard !articleTitle.isEmpty else { return }
        
        // 這裡可以加入額外的驗證邏輯
        if articleTitle.count > maxTitleLength {
            // 顯示錯誤提示
            return
        }
        
        if articleSubtitle.count > maxSubtitleLength {
            // 顯示錯誤提示
            return
        }
        
        // 呼叫原有的發布方法
        onPublish()
        dismiss()
    }
}

// MARK: - 分類按鈕
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : textColor)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background(isSelected ? Color.brandBlue : Color.gray200)
                .cornerRadius(DesignTokens.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - 預覽視圖
struct PreviewView: View {
    let title: String
    let subtitle: String
    let category: String
    let tags: [String]
    let coverImageURL: String?
    let isPaidContent: Bool
    
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
                VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    // 封面圖片
                    if let coverImageURL = coverImageURL {
                        AsyncImage(url: URL(string: coverImageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                                .fill(Color.gray200)
                                .overlay(ProgressView().tint(.brandGreen))
                        }
                        .frame(height: 250)
                        .clipped()
                        .cornerRadius(DesignTokens.cornerRadius)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                        // 分類
                        Text(category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandBlue)
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, DesignTokens.spacingXS)
                            .background(Color.brandBlue.opacity(0.1))
                            .cornerRadius(DesignTokens.cornerRadiusSM)
                        
                        // 標題
                        Text(title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(textColor)
                        
                        // 副標題
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.title3)
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        // 付費標識
                        if isPaidContent {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.brandOrange)
                                Text("付費內容")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.brandOrange)
                            }
                            .padding(.horizontal, DesignTokens.spacingSM)
                            .padding(.vertical, DesignTokens.spacingXS)
                            .background(Color.brandOrange.opacity(0.1))
                            .cornerRadius(DesignTokens.cornerRadiusSM)
                        }
                        
                        // 標籤
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignTokens.spacingXS) {
                                    ForEach(tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .foregroundColor(.brandGreen)
                                            .padding(.horizontal, DesignTokens.spacingSM)
                                            .padding(.vertical, DesignTokens.spacingXS)
                                            .background(Color.brandGreen.opacity(0.1))
                                            .cornerRadius(DesignTokens.cornerRadiusSM)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        // 模擬內容
                        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                            Text("這裡將顯示您的文章內容...")
                                .font(.body)
                                .foregroundColor(secondaryTextColor)
                                .italic()
                            
                            Text("預覽模式下無法顯示實際內容，請返回編輯器完成文章撰寫。")
                                .font(.caption)
                                .foregroundColor(.gray400)
                                .padding()
                                .background(Color.gray100)
                                .cornerRadius(DesignTokens.cornerRadiusSM)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("預覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                }
            }
        }
    }
}

#Preview {
    PublishSettingsView(
        selectedCategory: .constant("投資分析"),
        keywords: .constant(["股票", "投資"]),
        isPaidContent: .constant(false),
        onPublish: {}
    )
} 