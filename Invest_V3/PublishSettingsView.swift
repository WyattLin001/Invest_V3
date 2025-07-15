import SwiftUI

struct PublishSettingsView: View {
    @Binding var selectedCategory: String
    @Binding var keywords: [String]
    @Binding var isPaidContent: Bool
    let onPublish: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var newTag = ""
    
    private let categories = ["投資分析", "市場趨勢", "個股研究", "加密貨幣"]
    private let maxTags = 5
    
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
                VStack(alignment: .leading, spacing: 24) {
                    // 分類選擇
                    categorySection
                    
                    // 標籤管理
                    tagsSection
                    
                    // 付費設定
                    paidContentSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
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
                        onPublish()
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - 分類選擇區域
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文章分類")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textColor)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("標籤")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text("\(keywords.count)/\(maxTags)")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
            }
            
            // 標籤輸入
            HStack {
                TextField("輸入標籤", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                    .disabled(keywords.count >= maxTags)
                
                Button("添加", action: addTag)
                    .disabled(newTag.isEmpty || keywords.count >= maxTags)
                    .foregroundColor(.brandBlue)
                    .fontWeight(.medium)
            }
            
            // 標籤顯示
            if !keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
                .font(.system(size: 12))
                .foregroundColor(secondaryTextColor)
        }
    }
    
    // MARK: - 付費內容設定
    private var paidContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("內容設定")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textColor)
            
            Toggle(isOn: $isPaidContent) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("付費內容")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                    
                    Text("開啟後讀者需要付費才能閱讀完整內容")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .tint(.brandOrange)
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.brandBlue : Color.gray.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

// MARK: - 標籤氣泡視圖
struct TagBubbleView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.brandGreen)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.brandGreen)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.brandGreen.opacity(0.1))
        .cornerRadius(16)
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