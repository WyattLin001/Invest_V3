import SwiftUI

// MARK: - 表格功能測試視圖
struct TableFunctionalityTestView: View {
    @State private var tableContent: String = ""
    @State private var showTablePicker = false
    @State private var selectedRows = 3
    @State private var selectedCols = 3
    
    var body: some View {
        VStack(spacing: 20) {
            Text("表格功能測試")
                .font(.title)
                .fontWeight(.bold)
            
            // 表格大小選擇
            VStack(alignment: .leading, spacing: 12) {
                Text("表格大小")
                    .font(.headline)
                
                HStack {
                    Text("行數:")
                    Picker("行數", selection: $selectedRows) {
                        ForEach(2...6, id: \.self) { row in
                            Text("\(row)").tag(row)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                HStack {
                    Text("列數:")
                    Picker("列數", selection: $selectedCols) {
                        ForEach(2...6, id: \.self) { col in
                            Text("\(col)").tag(col)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 創建表格按鈕
            Button(action: {
                tableContent = createEditableTableMarkdown(rows: selectedRows, cols: selectedCols)
            }) {
                Text("創建 \(selectedRows)×\(selectedCols) 表格")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            // 表格內容編輯
            if !tableContent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("表格內容 (Markdown 格式)")
                        .font(.headline)
                    
                    TextEditor(text: $tableContent)
                        .font(.system(size: 14, family: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(minHeight: 200)
                    
                    Text("提示：可以直接編輯表格內容，支援標準 Markdown 表格格式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 清空按鈕
            if !tableContent.isEmpty {
                Button(action: {
                    tableContent = ""
                }) {
                    Text("清空表格")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func createEditableTableMarkdown(rows: Int, cols: Int) -> String {
        var markdown = ""
        
        // 標題行
        let headerCells = (1...cols).map { "標題\($0)" }
        markdown += "| " + headerCells.joined(separator: " | ") + " |\n"
        
        // 分隔行
        let separators = Array(repeating: "---", count: cols)
        markdown += "| " + separators.joined(separator: " | ") + " |\n"
        
        // 數據行
        for row in 1..<rows {
            let dataCells = (1...cols).map { "內容\(row)-\($0)" }
            markdown += "| " + dataCells.joined(separator: " | ") + " |\n"
        }
        
        return markdown
    }
}

// MARK: - 預覽
#Preview {
    TableFunctionalityTestView()
}