import Foundation

struct GomokuAI: Sendable {
    let difficulty: AIDifficulty

    func chooseMove(board: [[Stone]], stone: Stone) -> Move? {
        let legal = candidateMoves(board: board).filter {
            RenjuRules.isLegalMove(board: board, move: $0, stone: stone)
        }

        guard !legal.isEmpty else { return nil }

        // Never miss a direct win.
        if let win = legal.first(where: { move in
            var next = board
            next[move.row][move.column] = stone
            return RenjuRules.isWinningMove(board: next, move: move, stone: stone)
        }) {
            return win
        }

        // Always block an opponent's immediate legal win if possible.
        let opponent = stone.opponent
        let opponentWinningMoves = candidateMoves(board: board).filter { move in
            guard RenjuRules.isLegalMove(board: board, move: move, stone: opponent) else {
                return false
            }

            var next = board
            next[move.row][move.column] = opponent
            return RenjuRules.isWinningMove(board: next, move: move, stone: opponent)
        }

        if let forcedBlock = legal.first(where: { opponentWinningMoves.contains($0) }) {
            return forcedBlock
        }

        let ranked = legal
            .map { ($0, staticScore(board: board, move: $0, stone: stone)) }
            .sorted { $0.1 > $1.1 }

        switch difficulty {
        case .easy:
            let pool = Array(ranked.prefix(min(8, ranked.count)))
            return pool.randomElement()?.0 ?? ranked[0].0

        case .normal:
            return ranked[0].0

        case .hard:
            return hardChoice(board: board, stone: stone, ranked: ranked)
        }
    }

    private func hardChoice(
        board: [[Stone]],
        stone: Stone,
        ranked: [(Move, Int)]
    ) -> Move {
        let myCandidates = Array(ranked.prefix(min(14, ranked.count)))
        var bestMove = myCandidates[0].0
        var bestValue = Int.min

        for (move, baseScore) in myCandidates {
            var next = board
            next[move.row][move.column] = stone

            let opponent = stone.opponent
            let responses = candidateMoves(board: next)
                .filter { RenjuRules.isLegalMove(board: next, move: $0, stone: opponent) }
                .map { ($0, staticScore(board: next, move: $0, stone: opponent)) }
                .sorted { $0.1 > $1.1 }

            let strongestReply = responses.prefix(min(10, responses.count)).map { response -> Int in
                var replyBoard = next
                replyBoard[response.0.row][response.0.column] = opponent

                if RenjuRules.isWinningMove(
                    board: replyBoard,
                    move: response.0,
                    stone: opponent
                ) {
                    return 50_000_000
                }

                return response.1
            }.max() ?? 0

            let value = baseScore - Int(Double(strongestReply) * 0.92)

            if value > bestValue {
                bestValue = value
                bestMove = move
            }
        }

        return bestMove
    }

    private func staticScore(
        board: [[Stone]],
        move: Move,
        stone: Stone
    ) -> Int {
        var attackBoard = board
        attackBoard[move.row][move.column] = stone

        let attack = shapeScore(board: attackBoard, move: move, stone: stone)

        let opponent = stone.opponent
        var defenseBoard = board
        defenseBoard[move.row][move.column] = opponent

        let defense = shapeScore(board: defenseBoard, move: move, stone: opponent)

        let centerDistance = abs(move.row - 7) + abs(move.column - 7)
        let centerBonus = max(0, 14 - centerDistance) * 4

        return attack + Int(Double(defense) * 0.88) + centerBonus
    }

    private func shapeScore(
        board: [[Stone]],
        move: Move,
        stone: Stone
    ) -> Int {
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        var total = 0

        for (dr, dc) in directions {
            let forward = ray(board: board, move: move, stone: stone, dr: dr, dc: dc)
            let backward = ray(board: board, move: move, stone: stone, dr: -dr, dc: -dc)
            let length = 1 + forward.count + backward.count
            let openEnds = (forward.open ? 1 : 0) + (backward.open ? 1 : 0)

            if stone == .black, length == 5 {
                total += 20_000_000
            } else if stone == .white, length >= 5 {
                total += 20_000_000
            } else {
                switch (length, openEnds) {
                case (4, 2): total += 700_000
                case (4, 1): total += 160_000
                case (3, 2): total += 45_000
                case (3, 1): total += 8_000
                case (2, 2): total += 2_500
                case (2, 1): total += 500
                default: total += max(0, length - 1) * 30
                }
            }
        }

        return total
    }

    private func ray(
        board: [[Stone]],
        move: Move,
        stone: Stone,
        dr: Int,
        dc: Int
    ) -> (count: Int, open: Bool) {
        var row = move.row + dr
        var column = move.column + dc
        var count = 0

        while row >= 0,
              row < RenjuRules.boardSize,
              column >= 0,
              column < RenjuRules.boardSize,
              board[row][column] == stone {
            count += 1
            row += dr
            column += dc
        }

        let open = row >= 0 &&
            row < RenjuRules.boardSize &&
            column >= 0 &&
            column < RenjuRules.boardSize &&
            board[row][column] == .empty

        return (count, open)
    }

    private func candidateMoves(board: [[Stone]]) -> [Move] {
        var occupied: [Move] = []

        for row in 0..<RenjuRules.boardSize {
            for column in 0..<RenjuRules.boardSize where board[row][column] != .empty {
                occupied.append(Move(row: row, column: column))
            }
        }

        if occupied.isEmpty {
            return [Move(row: 7, column: 7)]
        }

        var candidates = Set<Move>()

        for stone in occupied {
            for dr in -2...2 {
                for dc in -2...2 {
                    guard dr != 0 || dc != 0 else { continue }

                    let move = Move(row: stone.row + dr, column: stone.column + dc)

                    guard move.row >= 0,
                          move.row < RenjuRules.boardSize,
                          move.column >= 0,
                          move.column < RenjuRules.boardSize,
                          board[move.row][move.column] == .empty else {
                        continue
                    }

                    candidates.insert(move)
                }
            }
        }

        return Array(candidates)
    }
}
