import SwiftUI

struct BoardView: View {
    let board: [[Stone]]
    let lastMove: Move?
    let enabled: Bool
    let onMove: (Move) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let padding = max(14.0, side * 0.045)
            let boardSide = side - padding * 2
            let spacing = boardSide / Double(RenjuRules.boardSize - 1)

            Canvas { context, _ in
                let boardRect = CGRect(
                    x: padding,
                    y: padding,
                    width: boardSide,
                    height: boardSide
                )

                context.fill(
                    Path(roundedRect: boardRect.insetBy(dx: -padding * 0.55, dy: -padding * 0.55), cornerRadius: 12),
                    with: .color(Color(red: 0.78, green: 0.58, blue: 0.32))
                )

                var grid = Path()

                for index in 0..<RenjuRules.boardSize {
                    let offset = padding + Double(index) * spacing

                    grid.move(to: CGPoint(x: padding, y: offset))
                    grid.addLine(to: CGPoint(x: padding + boardSide, y: offset))

                    grid.move(to: CGPoint(x: offset, y: padding))
                    grid.addLine(to: CGPoint(x: offset, y: padding + boardSide))
                }

                context.stroke(grid, with: .color(.black.opacity(0.72)), lineWidth: 1)

                for star in [(3, 3), (3, 11), (7, 7), (11, 3), (11, 11)] {
                    let center = CGPoint(
                        x: padding + Double(star.1) * spacing,
                        y: padding + Double(star.0) * spacing
                    )
                    let dot = Path(
                        ellipseIn: CGRect(
                            x: center.x - 3,
                            y: center.y - 3,
                            width: 6,
                            height: 6
                        )
                    )
                    context.fill(dot, with: .color(.black))
                }

                for row in 0..<RenjuRules.boardSize {
                    for column in 0..<RenjuRules.boardSize {
                        let stone = board[row][column]
                        guard stone != .empty else { continue }

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
                            context.fill(stonePath, with: .color(Color(white: 0.08)))
                        } else {
                            context.fill(stonePath, with: .color(Color(white: 0.97)))
                            context.stroke(stonePath, with: .color(.black.opacity(0.6)), lineWidth: 1)
                        }

                        if lastMove == Move(row: row, column: column) {
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
                              abs(rawRow - Double(row)) <= 0.46,
                              abs(rawColumn - Double(column)) <= 0.46 else {
                            return
                        }

                        onMove(Move(row: row, column: column))
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
}
