#if DEBUG
import Foundation

/// Simulator-only fixtures; absent from the Release IPA.
enum UITestSupport {
    private static let rapfiSmokeKey = "gomoku.ui.rapfiSmoke"

    static var rapfiSmokeStatus: String? {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-rapfi-smoke") else { return nil }
        return UserDefaults.standard.string(forKey: rapfiSmokeKey)
    }

    @MainActor
    static func prepareGameIfRequested(_ game: GameViewModel) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ui-testing"), args.contains("-ui-testing-result"), !game.isGameActive, game.completedRecord == nil {
            if args.contains("-ui-testing-six") {
                var moves: [RecordedMove] = []
                for (index, column) in [3, 4, 5, 7, 8, 6].enumerated() {
                    moves.append(RecordedMove(stone: .black, move: Move(row: index * 2, column: 0)))
                    moves.append(RecordedMove(stone: .white, move: Move(row: 7, column: column)))
                }
                game.finishUITestGame(GameRecord(playerStone: .black, difficulty: .normal, adaptiveSkill: nil,
                                                timeControl: .unlimited,
                                                result: args.contains("-ui-testing-resigned") ? .blackResigned : .whiteWin,
                                                moves: moves))
            } else {
                game.finishUITestGame(fixture(difficulty: .veryHard, defeat: args.contains("-ui-testing-defeat")))
            }
            return
        }
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
                        "gomoku.stoneSelection", "gomoku.nextAdaptiveStone", "gomoku.archive.v1", "gomoku.replay.speed",
                        rapfiSmokeKey] {
                defaults.removeObject(forKey: key)
            }
        }
        if args.contains("-ui-testing-rapfi-smoke") {
#if RAPFI_ENABLED
            let history = [
                RecordedMove(stone: .black, move: Move(row: 7, column: 7)),
                RecordedMove(stone: .white, move: Move(row: 7, column: 8)),
                RecordedMove(stone: .black, move: Move(row: 8, column: 7)),
                RecordedMove(stone: .white, move: Move(row: 6, column: 7)),
                RecordedMove(stone: .black, move: Move(row: 8, column: 8)),
                RecordedMove(stone: .white, move: Move(row: 6, column: 8))
            ]
            let occupied = Set(history.map { $0.move })
            RapfiAI.prepareSearch()
            let move = RapfiAI.isAvailable
                ? RapfiAI.chooseMove(history: history, stone: .black, timeLimit: 0.35, strengthLevel: 100)
                : nil
            if let move, !occupied.contains(move), (0..<15).contains(move.row), (0..<15).contains(move.column) {
                defaults.set("ok:\(move.coordinate)", forKey: rapfiSmokeKey)
            } else {
                defaults.set("failed", forKey: rapfiSmokeKey)
            }
#else
            defaults.set("disabled", forKey: rapfiSmokeKey)
#endif
        }
        if args.contains("-ui-testing-boss") {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode([fixture(difficulty: .hard), fixture(difficulty: .hard)]) {
                defaults.set(data, forKey: "gomoku.gameRecords")
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

    private static func fixture(difficulty: AIDifficulty, defeat: Bool = false) -> GameRecord {
        let points = defeat ? [(0,0),(7,5),(6,5),(7,6),(6,6),(7,7),(8,6),(7,8),(8,7),(7,9)]
                            : [(7,5),(6,5),(7,6),(6,6),(7,7),(8,6),(7,8),(8,7),(7,9)]
        return GameRecord(playerStone: .black, difficulty: difficulty, adaptiveSkill: nil,
                          timeControl: .unlimited, result: defeat ? .whiteWin : .blackWin,
                          moves: points.enumerated().map { RecordedMove(stone: $0.offset.isMultiple(of: 2) ? .black : .white, move: Move(row: $0.element.0, column: $0.element.1)) })
    }
}
#endif
