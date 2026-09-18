import Foundation

@main
struct EngineChecks {
    static func board(_ black: [(Int, Int)] = [], _ white: [(Int, Int)] = []) -> [[Stone]] {
        var result = Array(repeating: Array(repeating: Stone.empty, count: 15), count: 15)
        for (r, c) in black { result[r][c] = .black }
        for (r, c) in white { result[r][c] = .white }
        return result
    }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        print("PASS: \(message)")
    }
    static func reason(_ position: [[Stone]], _ r: Int = 7, _ c: Int = 7) -> ForbiddenReason? {
        RenjuRules.forbiddenReason(board: position, move: Move(row: r, column: c))
    }
    static func engineChecks() {
        require(reason(board([(7,6),(7,8),(6,7),(8,7)])) == .doubleThree, "true double-three rejected")
        require(reason(board([(7,6),(7,8),(6,7),(8,7)], [(5,7)])) == nil, "blocked false-three allowed")
        require(reason(board([(7,4),(7,5),(7,6),(4,7),(5,7),(6,7)])) == .doubleFour, "double-four rejected")
        require(reason(board([(7,3),(7,4),(7,5),(7,6),(7,8)])) == .overline, "overline rejected")
        require(reason(board([(7,3),(7,4),(7,5),(7,6),(6,7),(8,7)])) == nil, "exact five retains precedence")
        require(reason(board([(7,5),(7,6),(7,8)])) == nil, "one straight four is not a double-four")
        let center = Move(row: 7, column: 7)
        require(!RenjuRules.isLegalMove(board: board([(7,7)]), move: center, stone: .white), "occupied move rejected")

        // Sparse and crowded positions previously expanded irrelevant recursive
        // continuations and full-board windows after Black's fourth stone.
        let positions = [board([(7,6),(7,8),(6,7),(8,7)]),
                         board([(4,4),(6,8),(8,5),(10,10),(7,9)], [(5,5),(8,8),(9,7),(7,4)])]
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<20 {
            for position in positions { _ = reason(position) }
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        print(String(format: "40 forbidden checks: %.3f ms (%.3f ms/check)", elapsed * 1000, elapsed * 25))
        require(elapsed < 1.0, "forbidden checks stay below 25 ms average on CI")

        let engine = GomokuAI(difficulty: .hard)
        // More than 32 central candidates, but the only defense is A-row E1.
        let edge = board([(5,5),(6,8),(8,6),(9,9),(4,9)], [(0,0),(0,1),(0,2),(0,3),(10,5)])
        require(engine.chooseMove(board: edge, stone: .black) == Move(row: 0, column: 4), "edge threat beyond old 32-candidate cap blocked")
        let gap = board([(5,5)], [(1,0),(1,1),(1,3),(1,4)])
        require(engine.chooseMove(board: gap, stone: .white) == Move(row: 1, column: 2), "broken four completed")
        let winFirst = board([(0,0),(0,1),(0,2),(0,3)], [(14,0),(14,1),(14,2),(14,3)])
        require(engine.chooseMove(board: winFirst, stone: .white) == Move(row: 14, column: 4), "win takes priority over blocking")
        let openThree = board([(4,4),(5,9)], [(7,5),(7,6),(7,7)])
        let defense = engine.chooseMove(board: openThree, stone: .black)
        require(defense.map { [Move(row: 7, column: 4), Move(row: 7, column: 8)].contains($0) } == true, "open-three prevented before it becomes an open four")
        let attack = engine.chooseMove(board: openThree, stone: .white)
        require(attack.map { [Move(row: 7, column: 4), Move(row: 7, column: 8)].contains($0) } == true, "open four created for a forced win")
        let illegal = board([(7,6),(7,8),(6,7),(8,7)], [(5,5),(9,9)])
        let chosen = engine.chooseMove(board: illegal, stone: .black, timeLimit: 0.15)
        require(chosen != nil && chosen != center, "AI avoids tempting forbidden double-three")
        require(RenjuRules.isLegalMove(board: illegal, move: chosen!, stone: .black), "AI output is legal")
        let timed = ProcessInfo.processInfo.systemUptime
        let timedMove = engine.chooseMove(board: positions[1], stone: .black, timeLimit: 0.25)
        let duration = ProcessInfo.processInfo.systemUptime - timed
        print(String(format: "250 ms AI budget: %.3f ms", duration * 1000))
        require(timedMove != nil && duration < 0.75, "AI deadline returns a legal completed result")
        require(engine.chooseMove(board: board(), stone: .black, timeLimit: 0.1) == center, "black opening placed at centre")
    }

    @MainActor
    static func viewModelChecks() async {
        let game = GameViewModel()
        game.timeControl = .unlimited
        game.startGame()
        game.board = board([(4,4),(6,8),(8,5),(10,10),(7,9)], [(5,5),(8,8),(9,7),(7,4)])
        let move = Move(row: 7, column: 7)
        game.selectMove(move)
        let start = ProcessInfo.processInfo.systemUptime
        game.confirmSelectedMove()
        let duration = ProcessInfo.processInfo.systemUptime - start
        require(duration < 0.02, "confirmation returns to the UI in under 20 ms")
        require(game.isValidatingMove, "confirmation publishes a busy state immediately")
        game.confirmSelectedMove()
        game.selectMove(Move(row: 0, column: 0))
        require(game.selectedMove == move, "duplicate confirmation and selection locked during validation")
        game.backToSetup()
        game.startGame()
        try? await Task.sleep(nanoseconds: 100_000_000)
        require(game.board.flatMap { $0 }.allSatisfy { $0 == .empty }, "stale validation cannot mutate a new game")
        game.selectMove(move)
        game.confirmSelectedMove()
        for _ in 0..<100 where game.board[7][7] == .empty {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        require(game.board[7][7] == .black, "asynchronous confirmation places the chosen stone")
        game.backToSetup()
        game.startGame()
        try? await Task.sleep(nanoseconds: 100_000_000)
        require(game.board.flatMap { $0 }.allSatisfy { $0 == .empty }, "cancelled AI cannot mutate a restarted game")
        game.backToSetup()
    }

    static func main() async {
        engineChecks()
        await viewModelChecks()
        print("All engine, rules, deadline and confirmation checks passed.")
    }
}
