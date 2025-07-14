import SwiftUI

// MARK: - Tag Bubble Component
struct TagBubbleView: View {
    let tag: String
    let showDeleteButton: Bool
    let onDelete: (() -> Void)?
    
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.brandBlue.opacity(0.2) : Color.brandBlue.opacity(0.1)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.brandBlue.opacity(0.4) : Color.brandBlue.opacity(0.3)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.brandBlue.opacity(0.9) : Color.brandBlue
    }
    
    init(tag: String, showDeleteButton: Bool = true, onDelete: (() -> Void)? = nil) {
        self.tag = tag
        self.showDeleteButton = showDeleteButton
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
                .lineLimit(1)
            
            if showDeleteButton {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(textColor.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Tag Input View
struct TagInputView: View {
    @Binding var tags: [String]
    @State private var inputText: String = ""
    @State private var showLimitAlert = false
    
    let maxTags: Int
    let placeholder: String
    
    @Environment(\.colorScheme) var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? .gray900 : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .gray600 : .secondary
    }
    
    init(tags: Binding<[String]>, maxTags: Int = 5, placeholder: String = "新增標籤...") {
        self._tags = tags
        self.maxTags = maxTags
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("標籤")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text("\(tags.count)/\(maxTags)")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
            }
            
            // Tag input field
            HStack {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button("添加") {
                    addTag()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(canAddTag ? .brandBlue : .gray)
                .disabled(!canAddTag)
            }
            
            // Tag bubbles
            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagBubbleView(tag: tag) {
                            removeTag(tag)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: tags)
            }
        }
        .alert("標籤數量已達上限", isPresented: $showLimitAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text("最多只能添加 \(maxTags) 個標籤")
        }
    }
    
    private var canAddTag: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tags.count < maxTags
    }
    
    private func addTag() {
        let trimmedTag = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTag.isEmpty else { return }
        
        if tags.count >= maxTags {
            showLimitAlert = true
            return
        }
        
        if !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
        }
        
        inputText = ""
    }
    
    private func removeTag(_ tag: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            tags.removeAll { $0 == tag }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        VStack(spacing: 16) {
            Text("Individual Tag Bubbles")
                .font(.headline)
            
            HStack {
                TagBubbleView(tag: "投資分析") {}
                TagBubbleView(tag: "台積電") {}
                TagBubbleView(tag: "科技股", showDeleteButton: false)
            }
        }
        
        VStack(spacing: 16) {
            Text("Tag Input Component")
                .font(.headline)
            
            TagInputView(tags: .constant(["投資分析", "台積電", "科技股"]))
        }
    }
    .padding()
}