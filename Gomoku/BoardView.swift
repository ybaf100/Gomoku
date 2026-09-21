import SwiftUI

struct BoardView: View {
    let board: [[Stone]]
    let lastMove: Move?
    let selectedMove: Move?
    let previewStone: Stone
    let enabled: Bool
    var language: AppLanguage = .korean
    var forbiddenMoves: [Move: ForbiddenReason] = [:]
    var moveNumbers: [Move: Int] = [:]
    var winningLine: Set<Move> = []
    let onSelect: (Move) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let margin = max(22.0, side * 0.067)
            let boardSide = max(1, side - margin * 2)
            let spacing = boardSide / Double(RenjuRules.boardSize - 1)
            let theme = GomokuTheme(scheme)

            Canvas { context, _ in
                let frame = Path(roundedRect: CGRect(x: 1, y: 1, width: side - 2, height: side - 2),
                                 cornerRadius: side * 0.036)
                context.fill(frame, with: .color(theme.board))
                context.stroke(frame, with: .color(theme.boardEdge), lineWidth: 2)
                var grid = Path()
                for index in 0..<RenjuRules.boardSize {
                    let offset = margin + Double(index) * spacing
                    grid.move(to: CGPoint(x: margin, y: offset))
                    grid.addLine(to: CGPoint(x: margin + boardSide, y: offset))
                    grid.move(to: CGPoint(x: offset, y: margin))
                    grid.addLine(to: CGPoint(x: offset, y: margin + boardSide))

                    let letter = String(UnicodeScalar(65 + index)!)
                    let labelFont = Font.system(size: max(8, min(12, spacing * 0.32)),
                                                weight: .medium, design: .rounded)
                    context.draw(Text(letter).font(labelFont).foregroundColor(theme.boardLabel),
                                 at: CGPoint(x: offset, y: margin * 0.43))
                    context.draw(Text("\(index + 1)").font(labelFont).foregroundColor(theme.boardLabel),
                                 at: CGPoint(x: margin * 0.39, y: offset))
                }
                context.stroke(grid, with: .color(theme.grid), lineWidth: max(0.65, side / 820))

                for star in [(3, 3), (3, 11), (7, 7), (11, 3), (11, 11)] {
                    let point = CGPoint(x: margin + Double(star.1) * spacing,
                                        y: margin + Double(star.0) * spacing)
                    let diameter = max(4, spacing * 0.17)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                                       width: diameter, height: diameter)),
                                 with: .color(theme.grid))
                }

                for row in 0..<RenjuRules.boardSize {
                    for column in 0..<RenjuRules.boardSize {
                        let stone = board[row][column]
                        guard stone != .empty else { continue }
                        drawStone(stone, row: row, column: column, spacing: spacing, margin: margin,
                                  opacity: 1, context: &context)
                        let point = Move(row: row, column: column)
                        if let number = moveNumbers[point] {
                            let center = CGPoint(x: margin + Double(column) * spacing, y: margin + Double(row) * spacing)
                            context.draw(Text("\(number)")
                                .font(.system(size: spacing * (number >= 100 ? 0.32 : 0.43), weight: .bold, design: .rounded))
                                .foregroundColor(stone == .black ? .white : Color(hex: 0x14251F)), at: center)
                            if lastMove == point && !winningLine.contains(point) {
                                let diameter = spacing * 0.92
                                context.stroke(Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)),
                                               with: .color(lastMove == point ? theme.danger : theme.boardAccent), lineWidth: max(1.3, spacing * 0.055))
                            }
                        } else if lastMove == point && !winningLine.contains(point) {
                            let diameter = max(3, spacing * 0.18)
                            let center = CGPoint(x: margin + Double(column) * spacing,
                                                 y: margin + Double(row) * spacing)
                            context.fill(
                                Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                                       width: diameter, height: diameter)),
                                with: .color(stone == .black ? Color(hex: 0xC9E7AB) : Color(hex: 0x27624B))
                            )
                        }
                    }
                }

                if let selectedMove, board[selectedMove.row][selectedMove.column] == .empty {
                    drawStone(previewStone, row: selectedMove.row, column: selectedMove.column,
                              spacing: spacing, margin: margin, opacity: 0.55, context: &context)
                    let center = CGPoint(x: margin + Double(selectedMove.column) * spacing,
                                         y: margin + Double(selectedMove.row) * spacing)
                    let diameter = spacing * 0.98
                    let ring = Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                                     width: diameter, height: diameter))
                    context.stroke(ring, with: .color(theme.boardAccent), lineWidth: max(2, spacing * 0.06))
                }

                for (move, reason) in forbiddenMoves where board[move.row][move.column] == .empty {
                    let center = CGPoint(x: margin + Double(move.column) * spacing,
                                         y: margin + Double(move.row) * spacing)
                    let diameter = spacing * 0.86
                    let ring = Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                                     width: diameter, height: diameter))
                    context.fill(ring, with: .color(theme.surface))
                    context.stroke(ring, with: .color(theme.danger), lineWidth: max(1.2, spacing * 0.045))
                    context.draw(Text(reason.marker)
                        .font(.system(size: max(8, spacing * 0.38), weight: .heavy, design: .rounded))
                        .foregroundColor(theme.danger), at: center)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    guard enabled else { return }
                    let rawColumn = (value.location.x - margin) / spacing
                    let rawRow = (value.location.y - margin) / spacing
                    let column = Int(rawColumn.rounded())
                    let row = Int(rawRow.rounded())
                    guard row >= 0, row < RenjuRules.boardSize,
                          column >= 0, column < RenjuRules.boardSize,
                          abs(rawRow - Double(row)) <= 0.48,
                          abs(rawColumn - Double(column)) <= 0.48 else { return }
                    onSelect(Move(row: row, column: column))
                }
            )
            .accessibilityRepresentation {
                // Canvas alone has no accessible intersections. Virtual buttons use
                // the same selection path and keep the confirmation step intact.
                ZStack(alignment: .topLeading) {
                    ForEach(0..<RenjuRules.boardSize, id: \.self) { row in
                        ForEach(0..<RenjuRules.boardSize, id: \.self) { column in
                            let move = Move(row: row, column: column)
                            Button {
                                if enabled { onSelect(move) }
                            } label: {
                                Text("\(move.coordinate), \(board[row][column] == .empty ? L10n.text("emptyPoint", language) : L10n.stone(board[row][column], language: language))")
                            }
                            .frame(width: spacing, height: spacing)
                            .position(x: margin + Double(column) * spacing,
                                      y: margin + Double(row) * spacing)
                            .disabled(!enabled || board[row][column] != .empty)
                            .accessibilityAddTraits(selectedMove == move ? .isSelected : [])
                            .accessibilityValue(moveNumbers[move].map { L10n.choose("\($0)수", "Move \($0)", language) } ?? forbiddenMoves[move].map {
                                L10n.notice(.forbidden($0), language: language)
                            } ?? "")
                            .accessibilityIdentifier("intersection.\(move.coordinate)")
                        }
                    }
                }
                .frame(width: side, height: side)
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawStone(
        _ stone: Stone, row: Int, column: Int, spacing: Double, margin: Double,
        opacity: Double, context: inout GraphicsContext
    ) {
        let center = CGPoint(x: margin + Double(column) * spacing, y: margin + Double(row) * spacing)
        let diameter = spacing * 0.85
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                          width: diameter, height: diameter)
        let shape = Path(ellipseIn: rect)
        context.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: max(1, spacing * 0.04))),
                     with: .color(.black.opacity(0.18 * opacity)))
        let colors: [Color] = stone == .black
            ? [Color(hex: 0x455047), Color(hex: 0x111B16)]
            : [Color(hex: 0xFFFFFF), Color(hex: 0xDEE3D8)]
        context.fill(shape, with: .linearGradient(
            Gradient(colors: colors.map { $0.opacity(opacity) }),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        ))
        context.stroke(shape,
                       with: .color((stone == .black ? Color.white.opacity(0.2) : Color.black.opacity(0.22)).opacity(opacity)),
                       lineWidth: max(0.6, spacing * 0.025))
    }
}
