import Foundation

/// Offline tactical search. No network, process, or model download is required.
struct GomokuAI: Sendable {
    static let maximumThinkingTime: TimeInterval = 7.5
    static func thinkingBudget(remaining: Double?, increment: Double?) -> TimeInterval {
        guard let remaining else { return maximumThinkingTime }
        let safe = max(0.01, remaining - 0.3)
        // Retain reserve in fast games where the increment is less than the cap.
        let sustainable = remaining < 15 ? max(0.01, min(increment ?? safe, remaining / 3)) : maximumThinkingTime
        return min(maximumThinkingTime, min(safe, sustainable))
    }
    let difficulty: AIDifficulty
    let adaptiveSkill: Int

    init(difficulty: AIDifficulty, adaptiveSkill: Int = 50) {
        self.difficulty = difficulty
        self.adaptiveSkill = min(100, max(0, adaptiveSkill))
    }

    func chooseMove(board: [[Stone]], stone: Stone, timeLimit: TimeInterval = 7.5) -> Move? {
        guard !Task.isCancelled, stone != .empty else { return nil }
        let search = Search(deadline: ProcessInfo.processInfo.systemUptime + min(Self.maximumThinkingTime, max(0.01, timeLimit)))
        let candidates = candidateMoves(board: board)
        if board.joined().allSatisfy({ $0 == .empty }) { return Move(row: 7, column: 7) }
        guard let emergency = candidates.first(where: { RenjuRules.isLegalMove(board: board, move: $0, stone: stone) }) else {
            return quickFallback(board: board, stone: stone)
        }

        // Check the WHOLE board before any candidate pruning. A winning move
        // near the edge is just as urgent as a winning move near the centre.
        if let win = winningMoves(board: board, stone: stone, search: search).first { return win }
        if search.expired { return emergency }
        let threats = winningMoves(board: board, stone: stone.opponent, search: search)
        if let block = threats.first(where: { RenjuRules.isLegalMove(board: board, move: $0, stone: stone) }) {
            return block
        }
        if search.expired { return emergency }
        let ordered = orderedMoves(board: board, stone: stone, candidates: candidates, search: search)
        guard let fallback = ordered.first(where: {
            RenjuRules.isLegalMove(board: board, move: $0.move, stone: stone)
        })?.move else { return emergency }
        if search.expired { return fallback }

        var root: [Move] = []
        for item in ordered {
            if search.expired { break }
            if RenjuRules.isLegalMove(board: board, move: item.move, stone: stone) {
                root.append(item.move)
                if root.count == (difficulty == .veryHard ? 24 : 14) { break }
            }
        }
        guard !root.isEmpty else { return fallback }
        if difficulty == .easy || (difficulty == .adaptive && adaptiveSkill < 40) {
            let count = difficulty == .easy ? 4 : max(2, 5 - adaptiveSkill / 10)
            return root.prefix(count).randomElement() ?? fallback
        }

        let maxDepth: Int
        switch difficulty {
        case .veryHard: maxDepth = 10
        case .hard: maxDepth = 6
        case .adaptive: maxDepth = adaptiveSkill < 60 ? 3 : adaptiveSkill < 80 ? 4 : 6
        default: maxDepth = 3
        }
        var best = fallback
        if difficulty == .veryHard {
            let tactical = Search(deadline: min(search.deadline, ProcessInfo.processInfo.systemUptime + min(1.5, timeLimit * 0.25)))
            if let forced = forcingMove(board: board, attacker: stone, depth: 12, search: tactical) { return forced }
        }
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
        var wins: [String: [Move]] = [:]
        var orders: [String: [(move: Move, score: Int)]] = [:]
        init(deadline: TimeInterval) { self.deadline = deadline }
        var expired: Bool { Task.isCancelled || ProcessInfo.processInfo.systemUptime >= deadline }
    }

    private func key(_ board: [[Stone]], _ stone: Stone) -> String {
        String(board.flatMap { $0 }.map { Character(String($0.rawValue)) }) + String(stone.rawValue)
    }

    /// Prove a continuous-four line. A proof is returned only after all forced
    /// responses are legal and the opponent has no immediate counter-win.
    private func forcingMove(board: [[Stone]], attacker: Stone, depth: Int, search: Search) -> Move? {
        guard depth > 0, !search.expired else { return nil }
        if let win = winningMoves(board: board, stone: attacker, search: search).first { return win }
        let danger = winningMoves(board: board, stone: attacker.opponent, search: search)
        guard danger.count <= 1, !search.expired else { return nil }
        let ordered = orderedMoves(board: board, stone: attacker, candidates: candidateMoves(board: board), search: search)
        for item in ordered {
            if search.expired { return nil }
            let move = item.move
            if let block = danger.first, move != block { continue }
            var next = board
            next[move.row][move.column] = attacker
            let replies = winningMoves(board: next, stone: attacker, search: search)
            guard !replies.isEmpty, !search.expired else { continue }
            guard winningMoves(board: next, stone: attacker.opponent, search: search).isEmpty, !search.expired else { continue }
            if replies.count > 1 { return move }
            let block = replies[0]
            if !RenjuRules.isLegalMove(board: next, move: block, stone: attacker.opponent) { return move }
            next[block.row][block.column] = attacker.opponent
            if RenjuRules.isWinningMove(board: next, move: block, stone: attacker.opponent) { continue }
            if forcingMove(board: next, attacker: attacker, depth: depth - 2, search: search) != nil, !search.expired { return move }
        }
        return nil
    }

    private func negamax(board: [[Stone]], stone: Stone, depth: Int,
                         alpha: Int, beta: Int, ply: Int, search: Search) -> Int {
        if search.expired { return 0 }
        if !winningMoves(board: board, stone: stone, search: search).isEmpty { return Search.mate - ply }
        let threats = winningMoves(board: board, stone: stone.opponent, search: search)
        if threats.count > 1 { return -Search.mate + ply + 1 }
        let candidates = candidateMoves(board: board)
        let ordered = orderedMoves(board: board, stone: stone, candidates: candidates, search: search)
        if search.expired { return 0 }

        if depth == 0 && threats.isEmpty {
            // Potential on both sides, including broken (gapped) lines.
            let own = ordered.prefix(4).map { shapeScore(board: board, move: $0.move, stone: stone) }.max() ?? 0
            let enemy = orderedMoves(board: board, stone: stone.opponent, candidates: candidates, search: search)
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
            let width = difficulty == .veryHard ? (depth >= 3 ? 12 : 16) : (depth >= 3 ? 8 : 10)
            if alpha >= beta || searched >= width { break }
        }
        if searched == 0 { return threats.isEmpty ? 0 : -Search.mate + ply + 1 }
        return best
    }

    private func winningMoves(board: [[Stone]], stone: Stone, search: Search? = nil) -> [Move] {
        let cacheKey = search == nil ? "" : key(board, stone)
        if let cached = search?.wins[cacheKey] { return cached }
        var wins: [Move] = []
        for row in 0..<RenjuRules.boardSize {
            for column in 0..<RenjuRules.boardSize where board[row][column] == .empty {
                if search?.expired == true { return wins }
                let move = Move(row: row, column: column)
                var next = board
                next[row][column] = stone
                if RenjuRules.isWinningMove(board: next, move: move, stone: stone),
                   RenjuRules.isLegalMove(board: board, move: move, stone: stone) {
                    wins.append(move)
                }
            }
        }
        if let search, !search.expired, search.wins.count < 4096 { search.wins[cacheKey] = wins }
        return wins
    }

    private func orderedMoves(board: [[Stone]], stone: Stone, candidates: [Move], search: Search? = nil) -> [(move: Move, score: Int)] {
        let cacheKey = search == nil ? "" : key(board, stone)
        if let cached = search?.orders[cacheKey] { return cached }
        var values: [(move: Move, score: Int)] = []
        for move in candidates {
            if search?.expired == true { break }
            guard RenjuRules.isLegalMove(board: board, move: move, stone: stone) else { continue }
            let attack = shapeScore(board: board, move: move, stone: stone)
            let defense = RenjuRules.isLegalMove(board: board, move: move, stone: stone.opponent)
                ? shapeScore(board: board, move: move, stone: stone.opponent) : 0
            values.append((move, attack + defense + defense / 10 + 14 - abs(move.row - 7) - abs(move.column - 7)))
        }
        values.sort {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.row == $1.0.row ? $0.0.column < $1.0.column : $0.0.row < $1.0.row
        }
        if let search, !search.expired, search.orders.count < 2048 { search.orders[cacheKey] = values }
        return values
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
