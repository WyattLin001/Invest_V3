import SwiftUI

struct SimpleMarkdownView: View {
    let markdown: String
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(parseMarkdown(), id: \.id) { element in
                    element.view
                }
            }
            .padding()
        }
    }
    
    private func parseMarkdown() -> [MarkdownElement] {
        let lines = markdown.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                continue
            } else if trimmedLine.hasPrefix("# ") {
                elements.append(MarkdownElement(id: index, view: AnyView(
                    Text(String(trimmedLine.dropFirst(2)))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )))
            } else if trimmedLine.hasPrefix("## ") {
                elements.append(MarkdownElement(id: index, view: AnyView(
                    Text(String(trimmedLine.dropFirst(3)))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                )))
            } else if trimmedLine.hasPrefix("**") && trimmedLine.hasSuffix("**") {
                let boldText = String(trimmedLine.dropFirst(2).dropLast(2))
                elements.append(MarkdownElement(id: index, view: AnyView(
                    Text(boldText)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )))
            } else if trimmedLine.hasPrefix("---") {
                elements.append(MarkdownElement(id: index, view: AnyView(
                    Divider()
                        .padding(.vertical, 8)
                )))
            } else if trimmedLine.hasPrefix("![") {
                // 簡單的圖片處理
                elements.append(MarkdownElement(id: index, view: AnyView(
                    VStack {
                        AsyncImage(url: URL(string: "https://via.placeholder.com/600x300")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                        }
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                        
                        Text("圖片說明")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                )))
            } else if trimmedLine.hasPrefix("|") {
                // 簡單的表格處理 - 這裡只顯示為文本
                elements.append(MarkdownElement(id: index, view: AnyView(
                    Text(trimmedLine)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )))
            } else {
                // 普通段落
                elements.append(MarkdownElement(id: index, view: AnyView(
                    Text(parseInlineMarkdown(trimmedLine))
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )))
            }
        }
        
        return elements
    }
    
    private func parseInlineMarkdown(_ text: String) -> String {
        // 簡單處理行內格式
        var result = text
        
        // 處理粗體 **text**
        result = result.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 處理代碼 `code`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        return result
    }
}

struct MarkdownElement {
    let id: Int
    let view: AnyView
}

#Preview {
    SimpleMarkdownView(markdown: """
# 標題
## 副標題
這是一個段落，包含 **粗體文字** 和 `代碼`。

---

另一個段落。
""")
} 