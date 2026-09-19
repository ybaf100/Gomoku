import Foundation

/// Offline tactical search. No network, process, or model download is required.
struct GomokuAI: Sendable {
    let difficulty: AIDifficulty
    let adaptiveSkill: Int

    init(difficulty: AIDifficulty, adaptiveSkill: Int = 50) {
        self.difficulty = difficulty
        self.adaptiveSkill = min(100, max(0, adaptiveSkill))
    }

    func chooseMove(board: [[Stone]], stone: Stone, timeLimit: TimeInterval = 2.2) -> Move? {
        guard !Task.isCancelled, stone != .empty else { return nil }
        let search = Search(deadline: ProcessInfo.processInfo.systemUptime + max(0.02, timeLimit))
        let candidates = candidateMoves(board: board)

        // Check the WHOLE board before any candidate pruning. A winning move
        // near the edge is just as urgent as a winning move near the centre.
        if let win = winningMoves(board: board, stone: stone).first { return win }
        let threats = winningMoves(board: board, stone: stone.opponent)
        if let block = threats.first(where: { RenjuRules.isLegalMove(board: board, move: $0, stone: stone) }) {
            return block
        }
        let ordered = orderedMoves(board: board, stone: stone, candidates: candidates)
        guard let fallback = ordered.first(where: {
            RenjuRules.isLegalMove(board: board, move: $0.move, stone: stone)
        })?.move else { return nil }
        if search.expired { return fallback }

        var root: [Move] = []
        for item in ordered {
            if search.expired { break }
            if RenjuRules.isLegalMove(board: board, move: item.move, stone: stone) {
                root.append(item.move)
                if root.count == 14 { break }
            }
        }
        guard !root.isEmpty else { return fallback }
        if difficulty == .easy || (difficulty == .adaptive && adaptiveSkill < 40) {
            let count = difficulty == .easy ? 4 : max(2, 5 - adaptiveSkill / 10)
            return root.prefix(count).randomElement() ?? fallback
        }

        let maxDepth: Int
        switch difficulty {
        case .hard: maxDepth = 6
        case .adaptive: maxDepth = adaptiveSkill < 60 ? 3 : adaptiveSkill < 80 ? 4 : 6
        default: maxDepth = 3
        }
        var best = fallback
        // Only a fully completed iteration replaces the previous result.
        // Timing out halfway through a branch must not favour an unsearched move.
        for depth in 1...maxDepth {
            var iterationBest = best
            var bestValue = -Search.mate * 2
            var completed = true
            for move in root {
                if search.expired { completed = false; break }
                var next = board
                next[move.row][move.column] = stone
                let value = -negamax(board: next, stone: stone.opponent, depth: depth - 1,
                                     alpha: -Search.mate * 2, beta: -bestValue,
                                     ply: 1, search: search)
                if search.expired { completed = false; break }
                if value > bestValue { bestValue = value; iterationBest = move }
            }
            if !completed { break }
            best = iterationBest
            root.removeAll { $0 == best }
            root.insert(best, at: 0)
            if bestValue >= Search.mate - 100 { break }
        }
        return best
    }

    func quickFallback(board: [[Stone]], stone: Stone) -> Move? {
        if let win = winningMoves(board: board, stone: stone).first { return win }
        let blocks = winningMoves(board: board, stone: stone.opponent)
        if let block = blocks.first(where: { RenjuRules.isLegalMove(board: board, move: $0, stone: stone) }) {
            return block
        }
        return orderedMoves(board: board, stone: stone, candidates: candidateMoves(board: board))
            .first { RenjuRules.isLegalMove(board: board, move: $0.move, stone: stone) }?.move
    }

    private final class Search {
        static let mate = 100_000_000
        let deadline: TimeInterval
        init(deadline: TimeInterval) { self.deadline = deadline }
        var expired: Bool { Task.isCancelled || ProcessInfo.processInfo.systemUptime >= deadline }
    }

    private func negamax(board: [[Stone]], stone: Stone, depth: Int,
                         alpha: Int, beta: Int, ply: Int, search: Search) -> Int {
        if search.expired { return 0 }
        if !winningMoves(board: board, stone: stone).isEmpty { return Search.mate - ply }
        let threats = winningMoves(board: board, stone: stone.opponent)
        if threats.count > 1 { return -Search.mate + ply + 1 }
        let candidates = candidateMoves(board: board)
        let ordered = orderedMoves(board: board, stone: stone, candidates: candidates)
        if search.expired { return 0 }

        if depth == 0 && threats.isEmpty {
            // Potential on both sides, including broken (gapped) lines.
            let own = ordered.prefix(4).map { shapeScore(board: board, move: $0.move, stone: stone) }.max() ?? 0
            let enemy = orderedMoves(board: board, stone: stone.opponent, candidates: candidates)
                .prefix(4).map { shapeScore(board: board, move: $0.move, stone: stone.opponent) }.max() ?? 0
            return own - enemy
        }
        var alpha = alpha
        var best = -Search.mate
        var searched = 0
        let moves = threats.isEmpty ? ordered.map(\.move) : threats
        for move in moves {
            if search.expired { return 0 }
            guard RenjuRules.isLegalMove(board: board, move: move, stone: stone) else { continue }
            var next = board
            next[move.row][move.column] = stone
            let value: Int
            if RenjuRules.isWinningMove(board: next, move: move, stone: stone) {
                value = Search.mate - ply
            } else if depth <= 0 && ply >= 8 {
                // Bound forced-response extensions as well as ordinary search.
                value = 0
            } else {
                value = -negamax(board: next, stone: stone.opponent, depth: max(0, depth - 1),
                                 alpha: -beta, beta: -alpha, ply: ply + 1, search: search)
            }
            best = max(best, value)
            alpha = max(alpha, value)
            searched += 1
            if alpha >= beta || searched >= (depth >= 3 ? 8 : 10) { break }
        }
        if searched == 0 { return threats.isEmpty ? 0 : -Search.mate + ply + 1 }
        return best
    }

    private func winningMoves(board: [[Stone]], stone: Stone) -> [Move] {
        var wins: [Move] = []
        for row in 0..<RenjuRules.boardSize {
            for column in 0..<RenjuRules.boardSize where board[row][column] == .empty {
                let move = Move(row: row, column: column)
                var next = board
                next[row][column] = stone
                if RenjuRules.isWinningMove(board: next, move: move, stone: stone),
                   RenjuRules.isLegalMove(board: board, move: move, stone: stone) {
                    wins.append(move)
                }
            }
        }
        return wins
    }

    private func orderedMoves(board: [[Stone]], stone: Stone, candidates: [Move]) -> [(move: Move, score: Int)] {
        candidates.map { move in
            let attack = shapeScore(board: board, move: move, stone: stone)
            let defense = shapeScore(board: board, move: move, stone: stone.opponent)
            return (move, attack + defense + defense / 10 + 14 - abs(move.row - 7) - abs(move.column - 7))
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.row == $1.0.row ? $0.0.column < $1.0.column : $0.0.row < $1.0.row
        }
    }

    private func shapeScore(board: [[Stone]], move: Move, stone: Stone) -> Int {
        var next = board
        next[move.row][move.column] = stone
        var total = 0
        var fours = 0
        var openThrees = 0
        for (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)] {
            func at(_ offset: Int) -> Stone? {
                let row = move.row + dr * offset, column = move.column + dc * offset
                guard (0..<15).contains(row), (0..<15).contains(column) else { return nil }
                return next[row][column]
            }
            var winningPoints = Set<Int>()
            var bestCount = 1
            for start in -4...0 {
                let cells = (start..<(start + 5)).map { at($0) }
                guard cells.allSatisfy({ $0 == stone || $0 == .empty }) else { continue }
                if stone == .black && (at(start - 1) == stone || at(start + 5) == stone) { continue }
                let count = cells.filter { $0 == stone }.count
                if count == 5 { return Search.mate / 2 }
                bestCount = max(bestCount, count)
                if count == 4, let empty = cells.firstIndex(where: { $0 == .empty }) {
                    winningPoints.insert(start + empty)
                }
            }
            if winningPoints.count >= 2 { total += 2_000_000; fours += 1 }
            else if winningPoints.count == 1 { total += 180_000; fours += 1 }
            else {
                var openThree = false
                for start in -4...(-1) {
                    guard at(start) == .empty, at(start + 5) == .empty else { continue }
                    let inside = ((start + 1)...(start + 4)).map { at($0) }
                    if inside.filter({ $0 == stone }).count == 3 && inside.filter({ $0 == .empty }).count == 1 {
                        openThree = true
                    }
                }
                if openThree { total += 25_000; openThrees += 1 }
                else if bestCount == 3 { total += 3_000 }
                else if bestCount == 2 { total += 300 }
            }
        }
        if fours >= 2 || (fours >= 1 && openThrees >= 1) { total += 1_000_000 }
        if openThrees >= 2 { total += 120_000 }
        return total
    }

    private func candidateMoves(board: [[Stone]]) -> [Move] {
        var candidates = Set<Move>()
        var occupied = false
        for row in 0..<15 {
            for column in 0..<15 where board[row][column] != .empty {
                occupied = true
                for dr in -2...2 {
                    for dc in -2...2 {
                        let r = row + dr, c = column + dc
                        if (0..<15).contains(r), (0..<15).contains(c), board[r][c] == .empty {
                            candidates.insert(Move(row: r, column: c))
                        }
                    }
                }
            }
        }
        if !occupied { return [Move(row: 7, column: 7)] }
        return candidates.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
    }
}
