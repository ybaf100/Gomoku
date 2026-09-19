import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published var board = Array(
        repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
        count: RenjuRules.boardSize
    )

    @Published private(set) var playerStone: Stone = .black
    @Published var stoneSelection: StoneSelection = .black {
        didSet { defaults.set(stoneSelection.rawValue, forKey: stoneSelectionKey) }
    }
    @Published private(set) var nextAdaptiveStone: Stone = .black
    @Published private(set) var forbiddenMoves: [Move: ForbiddenReason] = [:]
    @Published var difficulty: AIDifficulty = .normal
    @Published var timeControl: TimeControl = .fast

    @Published private(set) var currentTurn: Stone = .black
    @Published private(set) var result: GameResult?
    @Published private(set) var lastMove: Move?
    @Published private(set) var selectedMove: Move?
    @Published private(set) var isThinking = false
    @Published private(set) var isValidatingMove = false
    @Published private(set) var blackTime: Double?
    @Published private(set) var whiteTime: Double?
    @Published private(set) var notice: GameNotice?
    @Published private(set) var records: [GameRecord] = []
    @Published private(set) var adaptiveSkill: Int
    @Published private(set) var lastAdaptiveAdjustment: Int?
    @Published var isGameActive = false

    private let adaptiveSkillKey = "gomoku.adaptiveSkill"
    private let recordsKey = "gomoku.gameRecords"
    private let stoneSelectionKey = "gomoku.stoneSelection"
    private let nextAdaptiveStoneKey = "gomoku.nextAdaptiveStone"
    private let defaults: UserDefaults
    private let randomBlack: () -> Bool

    private var clockTimer: Timer?
    private let clockNow: () -> TimeInterval
    private var matchClock: MatchClock?
    private var moves: [RecordedMove] = []
    private var adaptiveSkillAtStart: Int?
    private var aiRequestID: UUID?
    private var aiTask: Task<Void, Never>?
    private var validationTask: Task<Void, Never>?
    private var validationID: UUID?
    private var forbiddenTask: Task<Void, Never>?
    private var forbiddenRequestID: UUID?
    private let recordsQueue = DispatchQueue(label: "gomoku.records", qos: .utility)

    init(clockNow: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         defaults: UserDefaults = .standard,
         randomBlack: @escaping () -> Bool = { Bool.random() }) {
        self.clockNow = clockNow
        self.defaults = defaults
        self.randomBlack = randomBlack
        let savedSkill = defaults.object(forKey: adaptiveSkillKey) as? Int
        adaptiveSkill = min(100, max(0, savedSkill ?? 50))
        stoneSelection = StoneSelection(rawValue: defaults.string(forKey: stoneSelectionKey) ?? "") ?? .black
        nextAdaptiveStone = defaults.integer(forKey: nextAdaptiveStoneKey) == Stone.white.rawValue ? .white : .black
        loadRecords()
    }

    var aiStone: Stone { playerStone.opponent }

    var showsForbiddenMoves: Bool {
        isGameActive && result == nil && playerStone == .black && currentTurn == .black
    }

    func turnTitle(language: AppLanguage) -> String {
        guard result == nil else {
            return resultTitle(language: language)
        }

        if isValidatingMove { return L10n.text("validatingMove", language) }

        if currentTurn == playerStone {
            return L10n.text("yourTurn", language)
        }

        return isThinking
            ? L10n.text("aiThinking", language)
            : L10n.text("aiTurn", language)
    }

    func resultTitle(language: AppLanguage) -> String {
        guard let result else { return "" }
        return L10n.result(result, playerStone: playerStone, language: language)
    }

    func startGame() {
        resignIfPlaying()
        invalidateAI()

        switch stoneSelection {
        case .black: playerStone = .black
        case .white: playerStone = .white
        case .random:
            if difficulty == .adaptive {
                playerStone = nextAdaptiveStone
                // Consume one assignment per started game, including restarts.
                nextAdaptiveStone = playerStone.opponent
                defaults.set(nextAdaptiveStone.rawValue, forKey: nextAdaptiveStoneKey)
            } else {
                playerStone = randomBlack() ? .black : .white
            }
        }

        board = Array(
            repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
            count: RenjuRules.boardSize
        )
        currentTurn = .black
        result = nil
        lastMove = nil
        selectedMove = nil
        notice = nil
        isThinking = false
        moves = []
        lastAdaptiveAdjustment = nil
        adaptiveSkillAtStart = difficulty == .adaptive ? adaptiveSkill : nil
        matchClock = MatchClock(configuration: timeControl.clockConfiguration, now: clockNow())
        publishClock()
        isGameActive = true

        startClock()

        if aiStone == .black {
            requestAIMove()
        } else {
            refreshForbiddenMoves()
        }
    }

    func backToSetup() {
        resignIfPlaying()
        stopClock()
        invalidateAI()
        isThinking = false
        selectedMove = nil
        isGameActive = false
    }

    private func resignIfPlaying() {
        guard isGameActive, result == nil else { return }
        // Record the actual player colour before a restart assigns the next one.
        finish(playerStone == .black ? .blackResigned : .whiteResigned)
    }

    func selectMove(_ move: Move) {
        guard isGameActive,
              result == nil,
              currentTurn == playerStone,
              !isThinking,
              !isValidatingMove else {
            return
        }

        guard board[move.row][move.column] == .empty else {
            notice = .occupied
            return
        }

        if let reason = forbiddenMoves[move], showsForbiddenMoves {
            selectedMove = nil
            notice = .forbidden(reason)
            return
        }

        selectedMove = move
        notice = nil
    }

    func cancelSelection() {
        guard !isValidatingMove else { return }
        selectedMove = nil
        notice = nil
    }

    func confirmSelectedMove() {
        guard isGameActive,
              result == nil,
              currentTurn == playerStone,
              !isThinking,
              !isValidatingMove else {
            return
        }

        guard let move = selectedMove else {
            notice = .selectMove
            return
        }

        guard board[move.row][move.column] == .empty else {
            selectedMove = nil
            notice = .occupied
            return
        }

        let snapshot = board
        let stone = playerStone
        let requestID = UUID()
        validationID = requestID
        isValidatingMove = true
        notice = nil

        // Even an unusually complex forbidden-pattern check must never occupy
        // the main actor. Lock selection until this exact snapshot is resolved.
        validationTask = Task.detached(priority: .userInitiated) { [weak self] in
            let forbidden = stone == .black
                ? RenjuRules.forbiddenReason(board: snapshot, move: move) : nil
            guard !Task.isCancelled else { return }
            await self?.completeValidation(requestID, snapshot: snapshot, move: move,
                                           stone: stone, forbidden: forbidden)
        }
    }

    private func completeValidation(_ requestID: UUID, snapshot: [[Stone]], move: Move,
                                    stone: Stone, forbidden: ForbiddenReason?) {
        guard validationID == requestID, isGameActive, result == nil,
              currentTurn == stone, board == snapshot else { return }
        validationID = nil
        validationTask = nil
        isValidatingMove = false
        // Charge elapsed time before accepting a move, including validation.
        tickClock()
        guard result == nil else { return }
        if let forbidden {
            notice = .forbidden(forbidden)
            return
        }
        applyLegalMove(move, stone: stone)
    }

    func formattedTime(for stone: Stone) -> String {
        let value = stone == .black ? blackTime : whiteTime

        guard let value else { return "∞" }

        let seconds = max(0, Int(ceil(value)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func clearRecords() {
        records.removeAll()
        let key = recordsKey
        recordsQueue.async { [defaults] in defaults.removeObject(forKey: key) }
    }

    private func applyLegalMove(_ move: Move, stone: Stone) {
        guard result == nil,
              board[move.row][move.column] == .empty else {
            return
        }

        // Settle elapsed time at the commit boundary, then replenish exactly
        // once. A late confirmation cannot rescue a player who has timed out.
        guard matchClock?.completeMove(by: stone, at: clockNow()) == true else {
            tickClock()
            return
        }
        publishClock()
        invalidateForbiddenMoves()
        board[move.row][move.column] = stone
        moves.append(RecordedMove(stone: stone, move: move))
        lastMove = move
        selectedMove = nil

        if RenjuRules.isWinningMove(board: board, move: move, stone: stone) {
            finish(stone == .black ? .blackWin : .whiteWin)
            return
        }

        if board.allSatisfy({ row in row.allSatisfy { $0 != .empty } }) {
            finish(.draw)
            return
        }

        currentTurn = stone.opponent

        if currentTurn == aiStone {
            requestAIMove()
        } else {
            refreshForbiddenMoves()
        }
    }

    /// One background scan per Black turn, never from rendering or clock ticks.
    func refreshForbiddenMoves() {
        invalidateForbiddenMoves()
        guard showsForbiddenMoves else { return }
        let snapshot = board
        let requestID = UUID()
        forbiddenRequestID = requestID
        forbiddenTask = Task.detached(priority: .utility) { [weak self] in
            let markers = RenjuRules.forbiddenMoves(board: snapshot, isCancelled: { Task.isCancelled })
            guard !Task.isCancelled else { return }
            await self?.completeForbiddenScan(requestID, snapshot: snapshot, markers: markers)
        }
    }

    private func completeForbiddenScan(_ requestID: UUID, snapshot: [[Stone]],
                                       markers: [Move: ForbiddenReason]) {
        guard forbiddenRequestID == requestID, showsForbiddenMoves, board == snapshot else { return }
        forbiddenRequestID = nil
        forbiddenTask = nil
        forbiddenMoves = markers
        if !isValidatingMove, let selectedMove, let reason = markers[selectedMove] {
            self.selectedMove = nil
            notice = .forbidden(reason)
        }
    }

    private func invalidateForbiddenMoves() {
        forbiddenRequestID = nil
        forbiddenTask?.cancel()
        forbiddenTask = nil
        forbiddenMoves = [:]
    }

    private func requestAIMove() {
        guard isGameActive,
              result == nil,
              currentTurn == aiStone else {
            return
        }

        let requestID = UUID()
        aiRequestID = requestID
        isThinking = true
        let snapshot = board
        let stone = aiStone
        let level = difficulty
        let skill = difficulty == .adaptive ? adaptiveSkill : 50

        // Cancellation stops abandoned searches; a serial deadline-based search
        // returns its best completed iteration instead of an arbitrary timeout fallback.
        aiTask?.cancel()
        aiTask = Task.detached(priority: .userInitiated) { [weak self] in
            let engine = GomokuAI(difficulty: level, adaptiveSkill: skill)
            let move = engine.chooseMove(board: snapshot, stone: stone, timeLimit: 2.2)
            guard !Task.isCancelled else { return }
            await self?.completeAIMove(requestID, move: move, stone: stone)
        }
    }

    private func completeAIMove(_ requestID: UUID, move: Move?, stone: Stone) {
        guard aiRequestID == requestID, isGameActive, result == nil,
              currentTurn == stone else { return }
        aiRequestID = nil
        aiTask = nil
        isThinking = false
        tickClock()
        guard result == nil else { return }
        if let move { applyLegalMove(move, stone: stone) }
        else { finish(.draw) }
    }

    private func invalidateAI() {
        invalidateForbiddenMoves()
        aiRequestID = nil
        aiTask?.cancel()
        aiTask = nil
        validationID = nil
        validationTask?.cancel()
        validationTask = nil
        isValidatingMove = false
    }

    private func startClock() {
        stopClock()

        guard timeControl != .unlimited else { return }

        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.tickClock()
            }
        }
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func tickClock() {
        guard isGameActive, result == nil else { return }

        let expired = matchClock?.settle(at: clockNow())
        publishClock()
        if let expired { finish(expired == .black ? .blackTimeout : .whiteTimeout) }
    }

    private func publishClock() {
        blackTime = matchClock?.black
        whiteTime = matchClock?.white
    }

    func timeFraction(for stone: Stone) -> Double {
        guard let ceiling = matchClock?.configuration?.ceiling, ceiling > 0,
              let remaining = stone == .black ? blackTime : whiteTime else { return 1 }
        return min(1, max(0, remaining / ceiling))
    }

    func isTimeLow(for stone: Stone) -> Bool {
        guard let remaining = stone == .black ? blackTime : whiteTime else { return false }
        return remaining <= 10
    }

    private func finish(_ newResult: GameResult) {
        guard result == nil else { return }

        result = newResult
        selectedMove = nil
        isThinking = false
        invalidateAI()
        stopClock()

        let record = GameRecord(
            playerStone: playerStone,
            difficulty: difficulty,
            adaptiveSkill: adaptiveSkillAtStart,
            timeControl: timeControl,
            result: newResult,
            moves: moves,
            clockConfiguration: matchClock?.configuration
        )

        records.insert(record, at: 0)
        if records.count > 200 {
            records = Array(records.prefix(200))
        }
        saveRecords()

        if difficulty == .adaptive {
            adjustAdaptiveSkill(after: newResult)
        }
    }

    private func adjustAdaptiveSkill(after result: GameResult) {
        let moveCount = moves.count
        let magnitude: Int

        switch moveCount {
        case 0...24: magnitude = 8
        case 25...40: magnitude = 6
        case 41...60: magnitude = 4
        default: magnitude = 3
        }

        let delta: Int
        if result == .draw {
            delta = 0
        } else if result.playerWon(playerStone: playerStone) {
            // Player won: make the next adaptive opponent stronger.
            delta = magnitude
        } else {
            // AI won: reduce strength so the next game is closer.
            delta = -magnitude
        }

        adaptiveSkill = min(100, max(0, adaptiveSkill + delta))
        lastAdaptiveAdjustment = delta
        defaults.set(adaptiveSkill, forKey: adaptiveSkillKey)
    }

    private func loadRecords() {
        guard let data = defaults.data(forKey: recordsKey) else {
            records = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([GameRecord].self, from: data)
        } catch {
            records = []
        }
    }

    private func saveRecords() {
        let snapshot = records
        let key = recordsKey
        // Preserve save/clear ordering without encoding up to 200 games on UI.
        recordsQueue.async { [defaults] in
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                defaults.set(data, forKey: key)
            } catch {
                // A failed history write must never interrupt a live game.
            }
        }
    }
}
