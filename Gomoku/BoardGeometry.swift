import CoreGraphics

/// The one coordinate system shared by grid, stones, hit targets and victory overlays.
struct BoardGeometry {
    let side: CGFloat
    let margin: CGFloat
    let gridSide: CGFloat
    let spacing: CGFloat

    init(size: CGSize) {
        side = min(size.width, size.height)
        margin = max(22, side * 0.067)
        gridSide = max(1, side - margin * 2)
        spacing = gridSide / CGFloat(RenjuRules.boardSize - 1)
    }

    func center(_ move: Move) -> CGPoint {
        CGPoint(x: margin + CGFloat(move.column) * spacing,
                y: margin + CGFloat(move.row) * spacing)
    }

    func move(at point: CGPoint) -> Move? {
        let column = (point.x - margin) / spacing
        let row = (point.y - margin) / spacing
        let roundedColumn = Int(column.rounded())
        let roundedRow = Int(row.rounded())
        guard (0..<RenjuRules.boardSize).contains(roundedRow),
              (0..<RenjuRules.boardSize).contains(roundedColumn),
              abs(row - CGFloat(roundedRow)) <= 0.48,
              abs(column - CGFloat(roundedColumn)) <= 0.48 else { return nil }
        return Move(row: roundedRow, column: roundedColumn)
    }
}
