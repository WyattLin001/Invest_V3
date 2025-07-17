import SwiftUI

// MARK: - Apple-style Grid Table Editor
struct GridTableEditorView: View {
    @Binding var table: GridTable
    @State private var editingCell: (row: Int, column: Int)? = nil

    var body: some View {
        VStack(spacing: 1) {
            gridContent
            controlPanel
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Grid Content
    private var gridContent: some View {
        VStack(spacing: 1) {
            ForEach(0..<table.rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<table.columns, id: \.self) { column in
                        cellView(row: row, column: column)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(row: Int, column: Int) -> some View {
        let binding = Binding<String>(
            get: { table.cells[row][column] },
            set: { table.updateCell(row: row, column: column, text: $0) }
        )
        TextField("", text: binding)
            .frame(minWidth: 60, minHeight: 32)
            .padding(4)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .stroke(editingCell?.row == row && editingCell?.column == column ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture { editingCell = (row, column) }
            .contextMenu {
                Button(action: { table.removeRow(at: row) }) {
                    Label("刪除此行", systemImage: "trash")
                }
                .disabled(table.rows <= 1)
                
                Button(action: { table.removeColumn(at: column) }) {
                    Label("刪除此列", systemImage: "trash")
                }
                .disabled(table.columns <= 1)
                
                Button(action: { table.insertRow(at: row) }) {
                    Label("在此行上方插入行", systemImage: "plus")
                }
                
                Button(action: { table.insertColumn(at: column) }) {
                    Label("在此列左方插入列", systemImage: "plus")
                }
            }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // 新增按鈕
            HStack(spacing: 16) {
                Button(action: { table.addRow() }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新增行")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { table.addColumn() }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新增列")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // 刪除按鈕 (只有選中儲存格時才顯示)
            if editingCell != nil {
                HStack(spacing: 16) {
                    Button(action: removeRow) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("刪除行")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .disabled(table.rows <= 1)
                    
                    Button(action: removeColumn) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("刪除列")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .disabled(table.columns <= 1)
                    
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: editingCell)
        .padding(.top, 12)
    }

    private func removeRow() {
        if let edit = editingCell {
            table.removeRow(at: edit.row)
            editingCell = nil
        }
    }

    private func removeColumn() {
        if let edit = editingCell {
            table.removeColumn(at: edit.column)
            editingCell = nil
        }
    }
}

#if DEBUG
struct GridTableEditorView_Previews: PreviewProvider {
    @State static var table = GridTable(rows: 3, columns: 3)

    static var previews: some View {
        GridTableEditorView(table: $table)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif