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
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture { editingCell = (row, column) }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        HStack {
            Button(action: { table.addRow() }) {
                Label("新增行", systemImage: "plus")
            }
            Button(action: { table.addColumn() }) {
                Label("新增列", systemImage: "plus")
            }
            Spacer()
            Button(action: removeRow) {
                Text("刪除行")
                    .foregroundColor(.red)
            }
            .disabled(editingCell == nil || table.rows <= 1)
            Button(action: removeColumn) {
                Text("刪除欄")
                    .foregroundColor(.red)
            }
            .disabled(editingCell == nil || table.columns <= 1)
        }
        .font(.footnote)
        .padding(.top, 8)
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