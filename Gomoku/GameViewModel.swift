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
    @Published private(set) var isThinking = false
    @Published private(set) var blackTime: Double?
    @Published private(set) var whiteTime: Double?
    @Published var statusMessage: String?
    @Published var isGameActive = false

    private var clockTimer: Timer?
    private var lastClockTick = Date()

    var aiStone: Stone { playerStone.opponent }

    var turnTitle: String {
        guard result == nil else { return resultTitle }

        if currentTurn == playerStone {
            return "Your turn"
        }

        return isThinking ? "AI is thinking…" : "AI turn"
    }

    var resultTitle: String {
        guard let result else { return "" }

        switch result {
        case .blackWin:
            return playerStone == .black ? "You win" : "AI wins"
        case .whiteWin:
            return playerStone == .white ? "You win" : "AI wins"
        case .blackTimeout:
            return playerStone == .black ? "Time out — AI wins" : "AI timed out — You win"
        case .whiteTimeout:
            return playerStone == .white ? "Time out — AI wins" : "AI timed out — You win"
        case .draw:
            return "Draw"
        }
    }

    func startGame() {
        board = Array(
            repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
            count: RenjuRules.boardSize
        )
        currentTurn = .black
        result = nil
        lastMove = nil
        statusMessage = nil
        isThinking = false
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
        isThinking = false
        isGameActive = false
    }

    func play(_ move: Move) {
        guard isGameActive,
              result == nil,
              currentTurn == playerStone,
              !isThinking,
              board[move.row][move.column] == .empty else {
            return
        }

        if playerStone == .black,
           let forbidden = RenjuRules.forbiddenReason(board: board, move: move) {
            statusMessage = "Forbidden: \(forbidden.rawValue)"
            return
        }

        statusMessage = nil
        apply(move: move, stone: playerStone)
    }

    func formattedTime(for stone: Stone) -> String {
        let value = stone == .black ? blackTime : whiteTime

        guard let value else { return "∞" }

        let seconds = max(0, Int(ceil(value)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func apply(move: Move, stone: Stone) {
        guard result == nil,
              board[move.row][move.column] == .empty,
              RenjuRules.isLegalMove(board: board, move: move, stone: stone) else {
            return
        }

        board[move.row][move.column] = stone
        lastMove = move

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
        guard isGameActive, result == nil, currentTurn == aiStone else {
            return
        }

        isThinking = true

        let snapshot = board
        let stone = aiStone
        let level = difficulty

        DispatchQueue.global(qos: .userInitiated).async {
            let move = GomokuAI(difficulty: level).chooseMove(
                board: snapshot,
                stone: stone
            )

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.isGameActive,
                      self.result == nil,
                      self.currentTurn == stone else {
                    return
                }

                self.isThinking = false

                if let move {
                    self.apply(move: move, stone: stone)
                } else {
                    self.finish(.draw)
                }
            }
        }
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
        result = newResult
        isThinking = false
        stopClock()
    }
}
