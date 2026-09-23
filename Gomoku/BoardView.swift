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
    var accessibilityPrefix = "intersection"
    let onSelect: (Move) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            let boardGeometry = BoardGeometry(size: geometry.size)
            let side = boardGeometry.side
            let margin = boardGeometry.margin
            let boardSide = boardGeometry.gridSide
            let spacing = boardGeometry.spacing
            let theme = GomokuTheme(scheme)

            Canvas { context, _ in
                let frame = Path(roundedRect: CGRect(x: 1, y: 1, width: side - 2, height: side - 2),
                                 cornerRadius: side * 0.036)
                context.fill(frame, with: .color(theme.board))
                context.stroke(frame, with: .color(theme.boardEdge), lineWidth: 2)
                var grid = Path()
                for index in 0..<RenjuRules.boardSize {
                    let offset = margin + CGFloat(index) * spacing
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
                    let point = boardGeometry.center(Move(row: star.0, column: star.1))
                    let diameter = max(4, spacing * 0.17)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                                       width: diameter, height: diameter)),
                                 with: .color(theme.grid))
                }

                for row in 0..<RenjuRules.boardSize {
                    for column in 0..<RenjuRules.boardSize {
                        let stone = board[row][column]
                        guard stone != .empty else { continue }
                        drawStone(stone, at: boardGeometry.center(Move(row: row, column: column)), spacing: spacing,
                                  opacity: 1, context: &context)
                        let point = Move(row: row, column: column)
                        if let number = moveNumbers[point] {
                            let center = boardGeometry.center(point)
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
                            let center = boardGeometry.center(point)
                            context.fill(
                                Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                                       width: diameter, height: diameter)),
                                with: .color(stone == .black ? Color(hex: 0xC9E7AB) : Color(hex: 0x27624B))
                            )
                        }
                    }
                }

                if let selectedMove, board[selectedMove.row][selectedMove.column] == .empty {
                    let center = boardGeometry.center(selectedMove)
                    drawStone(previewStone, at: center, spacing: spacing, opacity: 0.55, context: &context)
                    let diameter = spacing * 0.98
                    let ring = Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                                     width: diameter, height: diameter))
                    context.stroke(ring, with: .color(theme.boardAccent), lineWidth: max(2, spacing * 0.06))
                }

                for (move, reason) in forbiddenMoves where board[move.row][move.column] == .empty {
                    let center = boardGeometry.center(move)
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
                    guard let move = boardGeometry.move(at: value.location) else { return }
                    onSelect(move)
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
                            .position(boardGeometry.center(move))
                            .disabled(!enabled || board[row][column] != .empty)
                            .accessibilityAddTraits(selectedMove == move ? .isSelected : [])
                            .accessibilityValue(moveNumbers[move].map { L10n.choose("\($0)수", "Move \($0)", language) } ?? forbiddenMoves[move].map {
                                L10n.notice(.forbidden($0), language: language)
                            } ?? "")
                            .accessibilityIdentifier("\(accessibilityPrefix).\(move.coordinate)")
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
        _ stone: Stone, at center: CGPoint, spacing: CGFloat,
        opacity: Double, context: inout GraphicsContext
    ) {
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
