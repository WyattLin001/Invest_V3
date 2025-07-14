import SwiftUI

// MARK: - 發布設定視圖
struct PublishSettingsView: View {
    @Binding var isPaidContent: Bool
    @Binding var selectedCategory: String
    @Binding var keywords: [String]
    let onPublish: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // 從 InfoView 獲取分類選項
    private let categories = ["全部", "投資分析", "市場趨勢", "個股研究", "加密貨幣"]
    
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
            VStack(spacing: 0) {
                // 內容設定
                ScrollView {
                    VStack(spacing: 24) {
                        // 發布到平台
                        publishToPlatformSection
                        
                        // 關鍵字設定
                        keywordsSection
                        
                        // 付費內容設定
                        paidContentSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                
                // 底部發布按鈕
                publishButton
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
            }
        }
    }
    
    // MARK: - 發布平台選擇
    private var publishToPlatformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("發布到")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textColor)
            
            Text("選擇文章分類，讀者可以在對應分類中找到你的文章")
                .font(.system(size: 14))
                .foregroundColor(secondaryTextColor)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(categories.filter { $0 != "全部" }, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack {
                            Text(category)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedCategory == category ? .white : textColor)
                            
                            Spacer()
                            
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedCategory == category ? Color.brandBlue : Color.gray.opacity(0.1)
                        )
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - 關鍵字設定
    private var keywordsSection: some View {
        TagInputView(tags: $keywords, maxTags: 5, placeholder: "輸入關鍵字...")
    }
    
    // MARK: - 付費內容設定
    private var paidContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("內容類型")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textColor)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("付費內容")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                    
                    Text("只有付費會員可以閱讀")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                Toggle("", isOn: $isPaidContent)
                    .toggleStyle(SwitchToggleStyle(tint: .brandGreen))
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 發布按鈕
    private var publishButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(action: {
                onPublish()
            }) {
                Text("發布文章")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brandGreen)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(backgroundColor)
        }
}
}

// MARK: - 預覽
struct PublishSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PublishSettingsView(
            isPaidContent: .constant(false),
            selectedCategory: .constant("投資分析"),
            keywords: .constant([]),
            onPublish: {}
        )
    }
} 