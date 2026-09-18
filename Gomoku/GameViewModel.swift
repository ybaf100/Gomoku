import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published var board = Array(
        repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
        count: RenjuRules.boardSize
    )

    @Published var playerStone: Stone = .black
    @Published var difficulty: AIDifficulty = .normal
    @Published var timeControl: TimeControl = .fast

    @Published private(set) var currentTurn: Stone = .black
    @Published private(set) var result: GameResult?
    @Published private(set) var lastMove: Move?
    @Published private(set) var selectedMove: Move?
    @Published private(set) var isThinking = false
    @Published private(set) var blackTime: Double?
    @Published private(set) var whiteTime: Double?
    @Published private(set) var notice: GameNotice?
    @Published private(set) var records: [GameRecord] = []
    @Published private(set) var adaptiveSkill: Int
    @Published private(set) var lastAdaptiveAdjustment: Int?
    @Published var isGameActive = false

    private let adaptiveSkillKey = "gomoku.adaptiveSkill"
    private let recordsKey = "gomoku.gameRecords"

    private var clockTimer: Timer?
    private var lastClockTick = Date()
    private var moves: [RecordedMove] = []
    private var adaptiveSkillAtStart: Int?
    private var aiRequestID: UUID?
    private var aiFallbackMove: Move?

    init() {
        let savedSkill = UserDefaults.standard.object(forKey: adaptiveSkillKey) as? Int
        adaptiveSkill = min(100, max(0, savedSkill ?? 50))
        loadRecords()
    }

    var aiStone: Stone { playerStone.opponent }

    func turnTitle(language: AppLanguage) -> String {
        guard result == nil else {
            return resultTitle(language: language)
        }

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
        invalidateAI()

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
        blackTime = timeControl.seconds
        whiteTime = timeControl.seconds
        isGameActive = true

        startClock()

        if aiStone == .black {
            requestAIMove()
        }
    }

    func backToSetup() {
        stopClock()
        invalidateAI()
        isThinking = false
        selectedMove = nil
        isGameActive = false
    }

    func selectMove(_ move: Move) {
        guard isGameActive,
              result == nil,
              currentTurn == playerStone,
              !isThinking else {
            return
        }

        guard board[move.row][move.column] == .empty else {
            notice = .occupied
            return
        }

        selectedMove = move
        notice = nil
    }

    func cancelSelection() {
        selectedMove = nil
        notice = nil
    }

    func confirmSelectedMove() {
        guard isGameActive,
              result == nil,
              currentTurn == playerStone,
              !isThinking else {
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

        if playerStone == .black,
           let forbidden = RenjuRules.forbiddenReason(board: board, move: move) {
            notice = .forbidden(forbidden)
            return
        }

        notice = nil
        applyLegalMove(move, stone: playerStone)
    }

    func formattedTime(for stone: Stone) -> String {
        let value = stone == .black ? blackTime : whiteTime

        guard let value else { return "∞" }

        let seconds = max(0, Int(ceil(value)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func clearRecords() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: recordsKey)
    }

    private func applyLegalMove(_ move: Move, stone: Stone) {
        guard result == nil,
              board[move.row][move.column] == .empty else {
            return
        }

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
        }
    }

    private func requestAIMove() {
        guard isGameActive,
              result == nil,
              currentTurn == aiStone else {
            return
        }

        let requestID = UUID()
        aiRequestID = requestID
        aiFallbackMove = nil
        isThinking = true

        let snapshot = board
        let stone = aiStone
        let level = difficulty
        let skill = difficulty == .adaptive ? adaptiveSkill : 50

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = GomokuAI(difficulty: level, adaptiveSkill: skill)

            // Compute a cheap legal fallback first. If the deeper search ever
            // reaches the hard 2.85 s wall, this move is used immediately.
            let fallback = engine.quickFallback(board: snapshot, stone: stone)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.aiRequestID == requestID else { return }
                self.aiFallbackMove = fallback
            }

            let move = engine.chooseMove(
                board: snapshot,
                stone: stone,
                timeLimit: 2.35
            ) ?? fallback

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.aiRequestID == requestID,
                      self.isGameActive,
                      self.result == nil,
                      self.currentTurn == stone else {
                    return
                }

                self.aiRequestID = nil
                self.isThinking = false

                if let move {
                    self.applyLegalMove(move, stone: stone)
                } else {
                    self.finish(.draw)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) { [weak self] in
            guard let self,
                  self.aiRequestID == requestID,
                  self.isGameActive,
                  self.result == nil,
                  self.currentTurn == stone,
                  let fallback = self.aiFallbackMove else {
                return
            }

            self.aiRequestID = nil
            self.isThinking = false
            self.applyLegalMove(fallback, stone: stone)
        }
    }

    private func invalidateAI() {
        aiRequestID = nil
        aiFallbackMove = nil
    }

    private func startClock() {
        stopClock()
        lastClockTick = Date()

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

        let now = Date()
        let elapsed = now.timeIntervalSince(lastClockTick)
        lastClockTick = now

        if currentTurn == .black, let remaining = blackTime {
            blackTime = max(0, remaining - elapsed)
            if blackTime == 0 {
                finish(.blackTimeout)
            }
        } else if currentTurn == .white, let remaining = whiteTime {
            whiteTime = max(0, remaining - elapsed)
            if whiteTime == 0 {
                finish(.whiteTimeout)
            }
        }
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
            moves: moves
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
        UserDefaults.standard.set(adaptiveSkill, forKey: adaptiveSkillKey)
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: recordsKey) else {
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
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: recordsKey)
        } catch {
            // A failed history write must never interrupt a live game.
        }
    }
}
