import SwiftUI

struct BoardView: View {
    let board: [[Stone]]
    let lastMove: Move?
    let selectedMove: Move?
    let previewStone: Stone
    let enabled: Bool
    let onSelect: (Move) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let padding = max(16.0, side * 0.045)
            let boardSide = max(1, side - padding * 2)
            let spacing = boardSide / Double(RenjuRules.boardSize - 1)

            Canvas { context, _ in
                let boardRect = CGRect(
                    x: padding,
                    y: padding,
                    width: boardSide,
                    height: boardSide
                )

                let background = Path(
                    roundedRect: boardRect.insetBy(
                        dx: -padding * 0.62,
                        dy: -padding * 0.62
                    ),
                    cornerRadius: 16
                )
                context.fill(
                    background,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.84, green: 0.65, blue: 0.39),
                            Color(red: 0.72, green: 0.50, blue: 0.27)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: side, y: side)
                    )
                )

                var grid = Path()

                for index in 0..<RenjuRules.boardSize {
                    let offset = padding + Double(index) * spacing

                    grid.move(to: CGPoint(x: padding, y: offset))
                    grid.addLine(to: CGPoint(x: padding + boardSide, y: offset))

                    grid.move(to: CGPoint(x: offset, y: padding))
                    grid.addLine(to: CGPoint(x: offset, y: padding + boardSide))
                }

                context.stroke(
                    grid,
                    with: .color(.black.opacity(0.74)),
                    lineWidth: max(0.8, side / 700)
                )

                for star in [(3, 3), (3, 11), (7, 7), (11, 3), (11, 11)] {
                    let center = CGPoint(
                        x: padding + Double(star.1) * spacing,
                        y: padding + Double(star.0) * spacing
                    )
                    let starSize = max(5.0, spacing * 0.20)
                    let dot = Path(
                        ellipseIn: CGRect(
                            x: center.x - starSize / 2,
                            y: center.y - starSize / 2,
                            width: starSize,
                            height: starSize
                        )
                    )
                    context.fill(dot, with: .color(.black.opacity(0.82)))
                }

                for row in 0..<RenjuRules.boardSize {
                    for column in 0..<RenjuRules.boardSize {
                        let stone = board[row][column]
                        guard stone != .empty else { continue }

                        drawStone(
                            stone,
                            row: row,
                            column: column,
                            spacing: spacing,
                            padding: padding,
                            opacity: 1,
                            context: &context
                        )

                        if lastMove == Move(row: row, column: column) {
                            let center = CGPoint(
                                x: padding + Double(column) * spacing,
                                y: padding + Double(row) * spacing
                            )
                            let diameter = spacing * 0.84
                            let markerSize = max(3.0, diameter * 0.16)
                            let marker = Path(
                                ellipseIn: CGRect(
                                    x: center.x - markerSize / 2,
                                    y: center.y - markerSize / 2,
                                    width: markerSize,
                                    height: markerSize
                                )
                            )
                            context.fill(
                                marker,
                                with: .color(stone == .black ? .white : .red)
                            )
                        }
                    }
                }

                if let selectedMove,
                   board[selectedMove.row][selectedMove.column] == .empty {
                    drawStone(
                        previewStone,
                        row: selectedMove.row,
                        column: selectedMove.column,
                        spacing: spacing,
                        padding: padding,
                        opacity: 0.48,
                        context: &context
                    )

                    let center = CGPoint(
                        x: padding + Double(selectedMove.column) * spacing,
                        y: padding + Double(selectedMove.row) * spacing
                    )
                    let ringDiameter = spacing * 0.98
                    let ring = Path(
                        ellipseIn: CGRect(
                            x: center.x - ringDiameter / 2,
                            y: center.y - ringDiameter / 2,
                            width: ringDiameter,
                            height: ringDiameter
                        )
                    )
                    context.stroke(ring, with: .color(.blue), lineWidth: 2.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard enabled else { return }

                        let rawColumn = (value.location.x - padding) / spacing
                        let rawRow = (value.location.y - padding) / spacing

                        let column = Int(rawColumn.rounded())
                        let row = Int(rawRow.rounded())

                        guard row >= 0,
                              row < RenjuRules.boardSize,
                              column >= 0,
                              column < RenjuRules.boardSize,
                              abs(rawRow - Double(row)) <= 0.48,
                              abs(rawColumn - Double(column)) <= 0.48 else {
                            return
                        }

                        onSelect(Move(row: row, column: column))
                    }
            )
            .frame(width: side, height: side)
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawStone(
        _ stone: Stone,
        row: Int,
        column: Int,
        spacing: Double,
        padding: Double,
        opacity: Double,
        context: inout GraphicsContext
    ) {
        guard stone != .empty else { return }

        let center = CGPoint(
            x: padding + Double(column) * spacing,
            y: padding + Double(row) * spacing
        )
        let diameter = spacing * 0.84
        let rect = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        let stonePath = Path(ellipseIn: rect)

        if stone == .black {
            context.fill(
                stonePath,
                with: .color(Color(white: 0.06).opacity(opacity))
            )
        } else {
            context.fill(
                stonePath,
                with: .color(Color(white: 0.98).opacity(opacity))
            )
            context.stroke(
                stonePath,
                with: .color(.black.opacity(0.55 * opacity)),
                lineWidth: 1
            )
        }
    }
}
