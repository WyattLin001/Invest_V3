import Foundation

struct GridTable: Identifiable {
    let id = UUID()
    var rows: Int
    var columns: Int
    var cells: [[String]]

    init(rows: Int = 2, columns: Int = 2) {
        let safeRows = max(rows, 1)
        let safeColumns = max(columns, 1)
        self.rows = safeRows
        self.columns = safeColumns
        self.cells = Array(repeating: Array(repeating: "", count: safeColumns), count: safeRows)
    }

    mutating func updateCell(row: Int, column: Int, text: String) {
        guard row >= 0 && row < rows && column >= 0 && column < columns else { return }
        cells[row][column] = text
    }

    mutating func addRow() {
        cells.append(Array(repeating: "", count: columns))
        rows += 1
    }

    mutating func addColumn() {
        for index in 0..<rows {
            cells[index].append("")
        }
        columns += 1
    }

    mutating func removeRow(at index: Int) {
        guard rows > 1 && index >= 0 && index < rows else { return }
        cells.remove(at: index)
        rows -= 1
    }

    mutating func removeColumn(at index: Int) {
        guard columns > 1 && index >= 0 && index < columns else { return }
        for i in 0..<rows {
            cells[i].remove(at: index)
        }
        columns -= 1
    }
}