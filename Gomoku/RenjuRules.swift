import Foundation

enum RenjuRules {
    static let boardSize = 15

    private static let directions = [
        (dr: 1, dc: 0),
        (dr: 0, dc: 1),
        (dr: 1, dc: 1),
        (dr: 1, dc: -1)
    ]

    private struct FourThreat {
        var stones: Set<Move>
        var winningPoints: Set<Move>
    }

    static func isWinningMove(board: [[Stone]], move: Move, stone: Stone) -> Bool {
        guard stone != .empty else { return false }

        for direction in directions {
            let count = contiguousCount(
                board: board,
                move: move,
                stone: stone,
                dr: direction.dr,
                dc: direction.dc
            )

            if stone == .black, count == 5 {
                return true
            }

            if stone == .white, count >= 5 {
                return true
            }
        }

        return false
    }

    static func forbiddenReason(board: [[Stone]], move: Move) -> ForbiddenReason? {
        guard isInside(move), board[move.row][move.column] == .empty else {
            return nil
        }

        // A double-three needs at least four existing black stones.
        // Before that point no Renju forbidden pattern can be created, so skip
        // the expensive recursive evaluator. This also keeps Black's opening
        // moves instant on iPad.
        let existingBlack = board.reduce(into: 0) { total, row in
            total += row.reduce(into: 0) { count, stone in
                if stone == .black { count += 1 }
            }
        }
        if existingBlack < 4 {
            return nil
        }

        var next = board
        next[move.row][move.column] = .black

        // RIF 9.2: an exact five made at the same time takes precedence.
        if isWinningMove(board: next, move: move, stone: .black) {
            return nil
        }

        if hasOverline(board: next, move: move) {
            return .overline
        }

        if fourThreats(board: next, required: [move]).count >= 2 {
            return .doubleFour
        }

        if threeSets(board: next, anchor: move, recursionDepth: 0).count >= 2 {
            return .doubleThree
        }

        return nil
    }

    static func isLegalMove(board: [[Stone]], move: Move, stone: Stone) -> Bool {
        guard isInside(move), board[move.row][move.column] == .empty else {
            return false
        }

        if stone == .black {
            return forbiddenReason(board: board, move: move) == nil
        }

        return stone == .white
    }

    static func forbiddenMoves(board: [[Stone]], isCancelled: () -> Bool = { false }) -> [Move: ForbiddenReason] {
        guard board.joined().filter({ $0 == .black }).count >= 4 else { return [:] }
        var markers: [Move: ForbiddenReason] = [:]
        for row in 0..<boardSize {
            for column in 0..<boardSize {
                if isCancelled() { return [:] }
                guard board[row][column] == .empty else { continue }
                let move = Move(row: row, column: column)
                if let reason = forbiddenReason(board: board, move: move) {
                    markers[move] = reason
                }
            }
        }
        return markers
    }

    private static func threeSets(
        board: [[Stone]],
        anchor: Move,
        recursionDepth: Int
    ) -> Set<String> {
        var result = Set<String>()

        for candidateMove in lineCandidates(around: anchor) {
            guard board[candidateMove.row][candidateMove.column] == .empty else {
                continue
            }

            var next = board
            next[candidateMove.row][candidateMove.column] = .black

            // Reject non-shapes BEFORE testing recursive continuation legality.
            // Almost every empty point on these lines cannot form a straight four.
            let straightFours = fourThreats(
                board: next, required: [anchor, candidateMove]
            ).values.filter { $0.winningPoints.count >= 2 }
            guard !straightFours.isEmpty else { continue }

            // A three must extend to a straight four through a legal move,
            // without simultaneously making five, overline, or double-four.
            if isWinningMove(board: next, move: candidateMove, stone: .black) ||
                hasOverline(board: next, move: candidateMove) {
                continue
            }
            if fourThreats(board: next, required: [candidateMove]).count >= 2 {
                continue
            }
            // Preserve the existing nested false-three depth convention.
            if recursionDepth < 2,
               threeSets(board: next, anchor: candidateMove, recursionDepth: recursionDepth + 1).count >= 2 {
                continue
            }

            for threat in straightFours {
                var three = threat.stones
                three.remove(candidateMove)

                guard three.count == 3, three.contains(anchor) else {
                    continue
                }

                result.insert(canonicalKey(three))
            }
        }

        return result
    }

    private static func fourThreats(
        board: [[Stone]],
        required: [Move]
    ) -> [String: FourThreat] {
        guard let anchor = required.first else { return [:] }

        var threats: [String: FourThreat] = [:]

        // Any relevant five-cell segment MUST contain the anchor. There are
        // at most 4 × 5 such windows, independent of how full the board is.
        for direction in directions {
            for offset in -4...0 {
                let segment = (0..<5).map { index in
                    Move(row: anchor.row + direction.dr * (offset + index),
                         column: anchor.column + direction.dc * (offset + index))
                }
                guard segment.allSatisfy({ isInside($0) }),
                      required.allSatisfy({ segment.contains($0) }) else { continue }
                let before = Move(row: segment[0].row - direction.dr,
                                  column: segment[0].column - direction.dc)
                let after = Move(row: segment[4].row + direction.dr,
                                 column: segment[4].column + direction.dc)
                if isInside(before), board[before.row][before.column] == .black { continue }
                if isInside(after), board[after.row][after.column] == .black { continue }

                let stones = Set(segment.filter { board[$0.row][$0.column] == .black })
                let empty = segment.filter { board[$0.row][$0.column] == .empty }
                guard stones.count == 4, empty.count == 1,
                      required.allSatisfy({ stones.contains($0) }) else { continue }
                let key = canonicalKey(stones)
                var threat = threats[key] ?? FourThreat(stones: stones, winningPoints: [])
                threat.winningPoints.insert(empty[0])
                threats[key] = threat
            }
        }
        return threats
    }

    private static func hasOverline(board: [[Stone]], move: Move) -> Bool {
        directions.contains { direction in
            contiguousCount(
                board: board,
                move: move,
                stone: .black,
                dr: direction.dr,
                dc: direction.dc
            ) >= 6
        }
    }

    private static func contiguousCount(
        board: [[Stone]],
        move: Move,
        stone: Stone,
        dr: Int,
        dc: Int
    ) -> Int {
        var count = 1
        count += countDirection(
            board: board,
            from: move,
            stone: stone,
            dr: dr,
            dc: dc
        )
        count += countDirection(
            board: board,
            from: move,
            stone: stone,
            dr: -dr,
            dc: -dc
        )
        return count
    }

    private static func countDirection(
        board: [[Stone]],
        from move: Move,
        stone: Stone,
        dr: Int,
        dc: Int
    ) -> Int {
        var row = move.row + dr
        var column = move.column + dc
        var count = 0

        while row >= 0,
              row < boardSize,
              column >= 0,
              column < boardSize,
              board[row][column] == stone {
            count += 1
            row += dr
            column += dc
        }

        return count
    }

    private static func lineCandidates(around anchor: Move) -> Set<Move> {
        var candidates = Set<Move>()

        for direction in directions {
            for offset in -4...4 where offset != 0 {
                let point = Move(
                    row: anchor.row + direction.dr * offset,
                    column: anchor.column + direction.dc * offset
                )

                if isInside(point) {
                    candidates.insert(point)
                }
            }
        }

        return candidates
    }

    private static func canonicalKey(_ moves: Set<Move>) -> String {
        moves
            .sorted {
                if $0.row != $1.row { return $0.row < $1.row }
                return $0.column < $1.column
            }
            .map { "\($0.row),\($0.column)" }
            .joined(separator: "|")
    }

    private static func isInside(_ move: Move) -> Bool {
        move.row >= 0 &&
        move.row < boardSize &&
        move.column >= 0 &&
        move.column < boardSize
    }
}
