import Foundation

struct GomokuAI: Sendable {
    let difficulty: AIDifficulty
    let adaptiveSkill: Int

    init(difficulty: AIDifficulty, adaptiveSkill: Int = 50) {
        self.difficulty = difficulty
        self.adaptiveSkill = min(100, max(0, adaptiveSkill))
    }

    func chooseMove(
        board: [[Stone]],
        stone: Stone,
        timeLimit: TimeInterval = 2.35
    ) -> Move? {
        let deadline = Date().addingTimeInterval(max(0.2, timeLimit))
        let candidates = candidateMoves(board: board)
        var legal: [Move] = []

        for move in candidates {
            if Date() >= deadline { break }
            if RenjuRules.isLegalMove(board: board, move: move, stone: stone) {
                legal.append(move)
            }
        }

        if legal.isEmpty {
            return quickFallback(board: board, stone: stone)
        }

        // Immediate tactical moves always take priority at every difficulty.
        for move in legal {
            if Date() >= deadline { break }
            var next = board
            next[move.row][move.column] = stone
            if RenjuRules.isWinningMove(board: next, move: move, stone: stone) {
                return move
            }
        }

        let opponent = stone.opponent
        var opponentWins = Set<Move>()

        for move in candidates.prefix(32) {
            if Date() >= deadline { break }
            guard RenjuRules.isLegalMove(board: board, move: move, stone: opponent) else {
                continue
            }

            var next = board
            next[move.row][move.column] = opponent
            if RenjuRules.isWinningMove(board: next, move: move, stone: opponent) {
                opponentWins.insert(move)
            }
        }

        if let forcedBlock = legal.first(where: { opponentWins.contains($0) }) {
            return forcedBlock
        }

        var ranked: [(Move, Int)] = []
        ranked.reserveCapacity(legal.count)

        for move in legal {
            if Date() >= deadline { break }
            ranked.append((move, staticScore(board: board, move: move, stone: stone)))
        }

        ranked.sort { $0.1 > $1.1 }

        guard !ranked.isEmpty else {
            return legal.first
        }

        switch difficulty {
        case .easy:
            let pool = Array(ranked.prefix(min(8, ranked.count)))
            return pool.randomElement()?.0 ?? ranked[0].0

        case .normal:
            return ranked[0].0

        case .hard:
            return lookAheadChoice(
                board: board,
                stone: stone,
                ranked: ranked,
                maxMyCandidates: 8,
                maxReplies: 6,
                defenseWeight: 0.94,
                deadline: deadline
            )

        case .adaptive:
            return adaptiveChoice(
                board: board,
                stone: stone,
                ranked: ranked,
                deadline: deadline
            )
        }
    }

    func quickFallback(board: [[Stone]], stone: Stone) -> Move? {
        for move in candidateMoves(board: board).prefix(24) {
            if RenjuRules.isLegalMove(board: board, move: move, stone: stone) {
                return move
            }
        }

        for row in 0..<RenjuRules.boardSize {
            for column in 0..<RenjuRules.boardSize {
                let move = Move(row: row, column: column)
                if RenjuRules.isLegalMove(board: board, move: move, stone: stone) {
                    return move
                }
            }
        }

        return nil
    }

    private func adaptiveChoice(
        board: [[Stone]],
        stone: Stone,
        ranked: [(Move, Int)],
        deadline: Date
    ) -> Move {
        let skill = adaptiveSkill

        if skill < 40 {
            // Low ratings deliberately allow more near-best alternatives.
            let poolSize = min(ranked.count, max(2, 7 - skill / 10))
            return Array(ranked.prefix(poolSize)).randomElement()?.0 ?? ranked[0].0
        }

        if skill < 60 {
            // 50/100 starts here: equivalent to Normal.
            return ranked[0].0
        }

        let candidateCount = min(9, 4 + (skill - 60) / 7)
        let replyCount = min(7, 3 + (skill - 60) / 9)
        let defenseWeight = min(0.98, 0.88 + Double(skill) / 1000.0)

        return lookAheadChoice(
            board: board,
            stone: stone,
            ranked: ranked,
            maxMyCandidates: candidateCount,
            maxReplies: replyCount,
            defenseWeight: defenseWeight,
            deadline: deadline
        )
    }

    private func lookAheadChoice(
        board: [[Stone]],
        stone: Stone,
        ranked: [(Move, Int)],
        maxMyCandidates: Int,
        maxReplies: Int,
        defenseWeight: Double,
        deadline: Date
    ) -> Move {
        let myCandidates = Array(ranked.prefix(min(maxMyCandidates, ranked.count)))
        var bestMove = myCandidates[0].0
        var bestValue = Int.min

        for (move, baseScore) in myCandidates {
            if Date() >= deadline { break }

            var next = board
            next[move.row][move.column] = stone
            let opponent = stone.opponent

            var responses: [(Move, Int)] = []
            for response in candidateMoves(board: next).prefix(28) {
                if Date() >= deadline { break }
                guard RenjuRules.isLegalMove(board: next, move: response, stone: opponent) else {
                    continue
                }
                responses.append((
                    response,
                    staticScore(board: next, move: response, stone: opponent)
                ))
            }

            responses.sort { $0.1 > $1.1 }

            var strongestReply = 0

            for response in responses.prefix(maxReplies) {
                if Date() >= deadline { break }

                var replyBoard = next
                replyBoard[response.0.row][response.0.column] = opponent

                if RenjuRules.isWinningMove(
                    board: replyBoard,
                    move: response.0,
                    stone: opponent
                ) {
                    strongestReply = 50_000_000
                    break
                }

                strongestReply = max(strongestReply, response.1)
            }

            let value = baseScore - Int(Double(strongestReply) * defenseWeight)

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

        return candidates.sorted { lhs, rhs in
            let leftDistance = abs(lhs.row - 7) + abs(lhs.column - 7)
            let rightDistance = abs(rhs.row - 7) + abs(rhs.column - 7)
            if leftDistance != rightDistance {
                return leftDistance < rightDistance
            }
            if lhs.row != rhs.row {
                return lhs.row < rhs.row
            }
            return lhs.column < rhs.column
        }
    }
}
