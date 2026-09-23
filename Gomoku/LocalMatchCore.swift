import Foundation

enum LocalTimePreset: String, CaseIterable, Identifiable, Sendable {
    case unlimited
    case blitz
    case fast
    case slow
    case custom

    var id: String { rawValue }

    var setup: LocalClockSetup? {
        switch self {
        case .unlimited:
            return .init(bottom: .unlimited, top: .unlimited)
        case .blitz:
            return .symmetric(.init(initial: 45, increment: 0, ceiling: 45))
        case .fast:
            return .symmetric(.init(initial: 30, increment: 5, ceiling: 45))
        case .slow:
            return .symmetric(.init(initial: 60, increment: 10, ceiling: 90))
        case .custom:
            return nil
        }
    }
}

struct LocalPlayerClockSetting: Equatable, Sendable {
    let initial: Double?
    let increment: Double
    let ceiling: Double?

    static let unlimited = LocalPlayerClockSetting(initial: nil, increment: 0, ceiling: nil)

    init(initial: Double?, increment: Double, ceiling: Double? = nil) {
        self.initial = initial.map { max(1, $0) }
        self.increment = max(0, increment)
        self.ceiling = ceiling.map { max(1, $0) }
    }
}

struct LocalClockSetup: Equatable, Sendable {
    let bottom: LocalPlayerClockSetting
    let top: LocalPlayerClockSetting

    static func symmetric(_ setting: LocalPlayerClockSetting) -> Self {
        .init(bottom: setting, top: setting)
    }

    func setting(for stone: Stone, bottomStone: Stone) -> LocalPlayerClockSetting {
        stone == bottomStone ? bottom : top
    }
}

struct LocalClockSnapshot: Equatable, Sendable {
    let black: Double?
    let white: Double?
    let activeStone: Stone
}

struct LocalMatchClock: Sendable {
    let blackSetting: LocalPlayerClockSetting
    let whiteSetting: LocalPlayerClockSetting
    private(set) var black: Double?
    private(set) var white: Double?
    private(set) var activeStone: Stone = .black
    private var lastUpdate: TimeInterval

    init(setup: LocalClockSetup, bottomStone: Stone, now: TimeInterval) {
        blackSetting = setup.setting(for: .black, bottomStone: bottomStone)
        whiteSetting = setup.setting(for: .white, bottomStone: bottomStone)
        black = blackSetting.initial
        white = whiteSetting.initial
        lastUpdate = now
    }

    mutating func settle(at now: TimeInterval) -> Stone? {
        let elapsed = max(0, now - lastUpdate)
        lastUpdate = max(lastUpdate, now)
        if activeStone == .black, let remaining = black {
            black = max(0, remaining - elapsed)
            if black == 0 { return .black }
        } else if activeStone == .white, let remaining = white {
            white = max(0, remaining - elapsed)
            if white == 0 { return .white }
        }
        return nil
    }

    mutating func completeMove(by stone: Stone, at now: TimeInterval) -> Bool {
        guard stone == activeStone, settle(at: now) == nil else { return false }
        let setting = stone == .black ? blackSetting : whiteSetting
        if stone == .black, let remaining = black {
            black = replenished(remaining, setting: setting)
        } else if stone == .white, let remaining = white {
            white = replenished(remaining, setting: setting)
        }
        activeStone = stone.opponent
        return true
    }

    func snapshot() -> LocalClockSnapshot {
        .init(black: black, white: white, activeStone: activeStone)
    }

    mutating func restore(_ snapshot: LocalClockSnapshot, at now: TimeInterval) {
        black = snapshot.black
        white = snapshot.white
        activeStone = snapshot.activeStone
        lastUpdate = now
    }

    func displayMaximum(for stone: Stone) -> Double? {
        let setting = stone == .black ? blackSetting : whiteSetting
        guard let initial = setting.initial else { return nil }
        return max(initial, setting.ceiling ?? initial)
    }

    private func replenished(_ remaining: Double, setting: LocalPlayerClockSetting) -> Double {
        let value = remaining + setting.increment
        return setting.ceiling.map { min($0, value) } ?? value
    }
}

struct LocalMoveSnapshot: Sendable {
    let board: [[Stone]]
    let moves: [RecordedMove]
    let currentTurn: Stone
    let lastMove: Move?
    let selectedMove: Move?
    let forbiddenMoves: [Move: ForbiddenReason]
    let result: GameResult?
    let clock: LocalClockSnapshot
}

struct LocalMatchCore: Sendable {
    private(set) var board = Array(
        repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
        count: RenjuRules.boardSize
    )
    private(set) var moves: [RecordedMove] = []
    private(set) var currentTurn: Stone = .black
    private(set) var result: GameResult?
    private(set) var lastMove: Move?
    var selectedMove: Move?
    var forbiddenMoves: [Move: ForbiddenReason] = [:]
    private(set) var clock: LocalMatchClock
    private var undoStack: [LocalMoveSnapshot] = []

    init(setup: LocalClockSetup = .symmetric(.unlimited), bottomStone: Stone = .black, now: TimeInterval = 0) {
        clock = LocalMatchClock(setup: setup, bottomStone: bottomStone, now: now)
    }

    var canUndo: Bool { result == nil && !undoStack.isEmpty }

    func isTimeWarning(for stone: Stone) -> Bool {
        guard result == nil, currentTurn == stone,
              let remaining = stone == .black ? clock.black : clock.white else { return false }
        return remaining > 0 && remaining <= 10
    }

    mutating func start(setup: LocalClockSetup, bottomStone: Stone, now: TimeInterval) {
        board = Array(repeating: Array(repeating: .empty, count: RenjuRules.boardSize), count: RenjuRules.boardSize)
        moves = []
        currentTurn = .black
        result = nil
        lastMove = nil
        selectedMove = nil
        forbiddenMoves = [:]
        undoStack = []
        clock = LocalMatchClock(setup: setup, bottomStone: bottomStone, now: now)
    }

    @discardableResult
    mutating func settleClock(at now: TimeInterval) -> Stone? {
        guard result == nil, let expired = clock.settle(at: now) else { return nil }
        result = expired == .black ? .blackTimeout : .whiteTimeout
        selectedMove = nil
        return expired
    }

    @discardableResult
    mutating func commit(_ move: Move, stone: Stone, at now: TimeInterval) -> Bool {
        guard result == nil, stone == currentTurn,
              board[move.row][move.column] == .empty else { return false }

        if let expired = clock.settle(at: now) {
            result = expired == .black ? .blackTimeout : .whiteTimeout
            selectedMove = nil
            return false
        }
        let snapshot = LocalMoveSnapshot(
            board: board,
            moves: moves,
            currentTurn: currentTurn,
            lastMove: lastMove,
            selectedMove: selectedMove,
            forbiddenMoves: forbiddenMoves,
            result: result,
            clock: clock.snapshot()
        )
        guard clock.completeMove(by: stone, at: now) else { return false }
        undoStack.append(snapshot)
        forbiddenMoves = [:]
        board[move.row][move.column] = stone
        moves.append(RecordedMove(stone: stone, move: move))
        lastMove = move
        selectedMove = nil

        if RenjuRules.isWinningMove(board: board, move: move, stone: stone) {
            result = stone == .black ? .blackWin : .whiteWin
        } else if board.allSatisfy({ $0.allSatisfy { $0 != .empty } }) {
            result = .draw
        } else {
            currentTurn = stone.opponent
        }
        return true
    }

    mutating func resign(_ stone: Stone) -> GameResult? {
        guard result == nil else { return nil }
        guard stone == .black || stone == .white else { return nil }
        result = stone == .black ? .blackResigned : .whiteResigned
        selectedMove = nil
        return result
    }

    mutating func resignCurrentPlayer() -> GameResult? {
        resign(currentTurn)
    }

    @discardableResult
    mutating func undo(at now: TimeInterval) -> Bool {
        guard result == nil, let snapshot = undoStack.popLast() else { return false }
        board = snapshot.board
        moves = snapshot.moves
        currentTurn = snapshot.currentTurn
        lastMove = snapshot.lastMove
        selectedMove = snapshot.selectedMove
        forbiddenMoves = snapshot.forbiddenMoves
        result = snapshot.result
        clock.restore(snapshot.clock, at: now)
        return true
    }
}

struct LocalPlayerStats: Equatable, Sendable {
    var wins = 0
    var losses = 0
    var winRate: Double { wins + losses == 0 ? 0 : Double(wins) / Double(wins + losses) }
}

struct LocalSessionScore: Equatable, Sendable {
    private(set) var bottom = LocalPlayerStats()
    private(set) var top = LocalPlayerStats()

    mutating func record(_ result: GameResult, bottomStone: Stone) {
        guard let winner = result.localWinner else { return }
        if winner == bottomStone {
            bottom.wins += 1
            top.losses += 1
        } else {
            top.wins += 1
            bottom.losses += 1
        }
    }

    mutating func reset() {
        bottom = LocalPlayerStats()
        top = LocalPlayerStats()
    }

}

extension GameResult {
    var localWinner: Stone? {
        switch self {
        case .blackWin, .whiteTimeout, .whiteResigned: return .black
        case .whiteWin, .blackTimeout, .blackResigned: return .white
        case .draw: return nil
        }
    }
}

enum LocalMatchFormat: String, CaseIterable, Identifiable, Sendable {
    case single, bestOfThree, bestOfFive

    var id: String { rawValue }
    var winsNeeded: Int {
        switch self {
        case .single: return 1
        case .bestOfThree: return 2
        case .bestOfFive: return 3
        }
    }
}

/// In-memory series state, independent from the session's per-game W/L totals.
struct LocalSeriesScore: Equatable, Sendable {
    private(set) var format: LocalMatchFormat
    private(set) var bottomWins = 0
    private(set) var topWins = 0
    private(set) var gameNumber = 1
    private(set) var firstBottomStone: Stone
    private(set) var didRecordCurrentGame = false

    init(format: LocalMatchFormat = .single, firstBottomStone: Stone = .black) {
        self.format = format
        self.firstBottomStone = firstBottomStone
    }

    var currentBottomStone: Stone { gameNumber.isMultiple(of: 2) ? firstBottomStone.opponent : firstBottomStone }
    var nextBottomStone: Stone { currentBottomStone.opponent }
    var isComplete: Bool { bottomWins >= format.winsNeeded || topWins >= format.winsNeeded }
    var winningBottomPlayer: Bool? {
        guard isComplete else { return nil }
        return bottomWins >= format.winsNeeded
    }

    mutating func record(_ result: GameResult) {
        guard !isComplete, !didRecordCurrentGame else { return }
        didRecordCurrentGame = true
        guard let winner = result.localWinner else { return }
        if winner == currentBottomStone { bottomWins += 1 }
        else { topWins += 1 }
    }

    @discardableResult
    mutating func advance() -> Bool {
        guard didRecordCurrentGame, !isComplete else { return false }
        gameNumber += 1
        didRecordCurrentGame = false
        return true
    }

    mutating func restart() {
        firstBottomStone = firstBottomStone.opponent
        bottomWins = 0
        topWins = 0
        gameNumber = 1
        didRecordCurrentGame = false
    }
}

struct LocalColourAssignment: Equatable, Sendable {
    private(set) var bottomStone: Stone

    init(selectedBottomStone: Stone) {
        bottomStone = selectedBottomStone == .white ? .white : .black
    }

    mutating func rematch() {
        bottomStone = bottomStone.opponent
    }
}
