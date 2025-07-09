import SwiftUI

// MARK: - 表格編輯器視圖
struct TableEditorView: View {
    @State private var selectedRows = 3
    @State private var selectedCols = 3
    @Environment(\.dismiss) private var dismiss
    
    let onTableCreate: (Int, Int) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("選擇表格大小")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // 表格大小選擇器
                VStack(spacing: 16) {
                    // 行數選擇
                    VStack(alignment: .leading, spacing: 8) {
                        Text("行數: \(selectedRows)")
                            .font(.headline)
                        
                        HStack {
                            ForEach(1...6, id: \.self) { row in
                                Button(action: { selectedRows = row }) {
                                    Text("\(row)")
                                        .frame(width: 40, height: 40)
                                        .background(selectedRows == row ? Color.brandBlue : Color.gray200)
                                        .foregroundColor(selectedRows == row ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // 列數選擇
                    VStack(alignment: .leading, spacing: 8) {
                        Text("列數: \(selectedCols)")
                            .font(.headline)
                        
                        HStack {
                            ForEach(1...6, id: \.self) { col in
                                Button(action: { selectedCols = col }) {
                                    Text("\(col)")
                                        .frame(width: 40, height: 40)
                                        .background(selectedCols == col ? Color.brandBlue : Color.gray200)
                                        .foregroundColor(selectedCols == col ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // 預覽表格
                tablePreview
                
                Spacer()
                
                // 確認按鈕
                Button("插入表格") {
                    onTableCreate(selectedRows, selectedCols)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("插入表格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 表格預覽
    private var tablePreview: some View {
        VStack(spacing: 2) {
            ForEach(0..<selectedRows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<selectedCols, id: \.self) { col in
                        Rectangle()
                            .fill(Color.gray300)
                            .frame(height: 32)
                            .overlay(
                                Text(row == 0 ? "標題" : "內容")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray100)
        .cornerRadius(8)
    }
}

// MARK: - 表格佔位符視圖
struct TablePlaceholder: View {
    let rows: Int
    let cols: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(.brandBlue)
                Text("表格 (\(rows)×\(cols))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("點擊編輯")
                    .font(.caption2)
                    .foregroundColor(.brandBlue)
            }
            
            // 簡化的表格預覽
            VStack(spacing: 1) {
                ForEach(0..<min(rows, 3), id: \.self) { _ in
                    HStack(spacing: 1) {
                        ForEach(0..<min(cols, 4), id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray200)
                                .frame(height: 20)
                        }
                    }
                }
                
                if rows > 3 {
                    Text("...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.gray100)
        .cornerRadius(8)
        .frame(height: 44)
    }
}

#Preview {
    TableEditorView { rows, cols in
        print("創建表格: \(rows)×\(cols)")
    }
} 