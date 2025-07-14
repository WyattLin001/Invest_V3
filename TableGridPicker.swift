import SwiftUI

// MARK: - TableGridPicker

struct TableGridPicker: View {
    let maxRows: Int = 6
    let maxCols: Int = 6
    
    @State private var hoveredCell: (row: Int, col: Int)? = nil
    @State private var showPreview: Bool = false
    
    let onSelection: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(onSelection: @escaping (Int, Int) -> Void) {
        self.onSelection = onSelection
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("插入表格")
                .font(.headline)
                .padding(.top)
            
            // Preview text
            if let hovered = hoveredCell {
                Text("\(hovered.row) × \(hovered.col) 表格")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("選擇表格大小")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Grid
            VStack(spacing: 2) {
                ForEach(1...maxRows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(1...maxCols, id: \.self) { col in
                            Rectangle()
                                .fill(cellColor(row: row, col: col))
                                .frame(width: 24, height: 24)
                                .border(Color.gray.opacity(0.3), width: 1)
                                .onTapGesture {
                                    onSelection(row, col)
                                    dismiss()
                                }
                                .onHover { isHovering in
                                    if isHovering {
                                        hoveredCell = (row: row, col: col)
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // Cancel button
            Button("取消") {
                dismiss()
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 280)
    }
    
    private func cellColor(row: Int, col: Int) -> Color {
        guard let hovered = hoveredCell else {
            return Color.clear
        }
        
        if row <= hovered.row && col <= hovered.col {
            return Color.blue.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

// MARK: - TableGridPicker for iOS (Touch-based)

struct TableGridPickerSheet: View {
    let onSelection: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRows: Int = 2
    @State private var selectedCols: Int = 2
    
    init(onSelection: @escaping (Int, Int) -> Void) {
        self.onSelection = onSelection
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview
                VStack(spacing: 8) {
                    Text("表格預覽")
                        .font(.headline)
                    
                    Text("\(selectedRows) 行 × \(selectedCols) 列")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding()
                
                // Row selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("行數")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(1...6, id: \.self) { row in
                            Button("\(row)") {
                                selectedRows = row
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(selectedRows == row ? .white : .blue)
                            .background(selectedRows == row ? Color.blue : Color.clear)
                            .cornerRadius(8)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Column selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("列數")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(1...6, id: \.self) { col in
                            Button("\(col)") {
                                selectedCols = col
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(selectedCols == col ? .white : .blue)
                            .background(selectedCols == col ? Color.blue : Color.clear)
                            .cornerRadius(8)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Table preview visual
                tablePreview
                
                Spacer()
            }
            .navigationTitle("插入表格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("插入") {
                        onSelection(selectedRows, selectedCols)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var tablePreview: some View {
        VStack(spacing: 1) {
            ForEach(0..<selectedRows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<selectedCols, id: \.self) { col in
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 30)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

// MARK: - Table Markdown Generator

extension String {
    static func markdownTable(rows: Int, cols: Int) -> String {
        var markdown = ""
        
        // Header row
        let headerCells = (1...cols).map { "標題 \($0)" }
        markdown += "| " + headerCells.joined(separator: " | ") + " |\n"
        
        // Separator row
        let separators = Array(repeating: "---", count: cols)
        markdown += "| " + separators.joined(separator: " | ") + " |\n"
        
        // Data rows
        for row in 1..<rows {
            let dataCells = (1...cols).map { "資料 \(row)-\($0)" }
            markdown += "| " + dataCells.joined(separator: " | ") + " |\n"
        }
        
        return markdown + "\n"
    }
}

// MARK: - Preview

#if DEBUG
struct TableGridPicker_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TableGridPickerSheet { rows, cols in
                print("Selected: \(rows)x\(cols)")
            }
            
            TableGridPicker { rows, cols in
                print("Selected: \(rows)x\(cols)")
            }
            .previewDisplayName("Grid Picker")
        }
    }
}
#endif 