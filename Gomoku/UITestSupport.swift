#if DEBUG
import Foundation

/// Simulator-only fixtures; absent from the Release IPA.
enum UITestSupport {
    @MainActor
    static func prepareGameIfRequested(_ game: GameViewModel) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui-testing"), args.contains("-ui-testing-forbidden"), !game.isGameActive else { return }
        game.timeControl = .unlimited
        game.stoneSelection = .black
        game.startGame()
        for (row, column) in [(7, 6), (7, 8), (6, 7), (8, 7)] { game.board[row][column] = .black }
        for (row, column) in [(4, 4), (4, 5), (10, 9), (10, 10)] { game.board[row][column] = .white }
        game.refreshForbiddenMoves()
    }

    static func prepareIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui-testing") else { return }
        let defaults = UserDefaults.standard
        if args.contains("-ui-testing-reset") {
            for key in ["gomoku.language", "gomoku.appearance", "gomoku.gameRecords", "gomoku.adaptiveSkill",
                        "gomoku.stoneSelection", "gomoku.nextAdaptiveStone"] {
                defaults.removeObject(forKey: key)
            }
        }
        if args.contains("-ui-testing-records") {
            let points = [(7, 5), (6, 5), (7, 6), (6, 6), (7, 7), (8, 6), (7, 8), (8, 7), (7, 9)]
            let moves = points.enumerated().map { index, point in
                RecordedMove(stone: index.isMultiple(of: 2) ? .black : .white,
                             move: Move(row: point.0, column: point.1))
            }
            let record = GameRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                playedAt: Date(timeIntervalSince1970: 1_789_689_600), playerStone: .black,
                difficulty: .normal, adaptiveSkill: nil, timeControl: .fast,
                result: .blackWin, moves: moves
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode([record]) { defaults.set(data, forKey: "gomoku.gameRecords") }
        }
    }
}
#endif
