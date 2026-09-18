import Foundation
import SwiftUI

enum Stone: Int, Codable, Sendable {
    case empty
    case black
    case white

    var opponent: Stone {
        switch self {
        case .black: return .white
        case .white: return .black
        case .empty: return .empty
        }
    }

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .white: return "White"
        case .empty: return "Empty"
        }
    }
}

struct Move: Hashable, Codable, Sendable {
    let row: Int
    let column: Int
}

enum AIDifficulty: String, CaseIterable, Identifiable, Codable, Sendable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case adaptive = "Adaptive"

    var id: String { rawValue }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum TimeControl: String, CaseIterable, Identifiable, Codable, Sendable {
    case fast = "Fast"
    case slow = "Slow"
    case unlimited = "Unlimited"

    var id: String { rawValue }

    var seconds: Double? {
        switch self {
        case .fast: return 180
        case .slow: return 600
        case .unlimited: return nil
        }
    }

    var subtitle: String {
        switch self {
        case .fast: return "3 min"
        case .slow: return "10 min"
        case .unlimited: return "No clock"
        }
    }
}

enum ForbiddenReason: String, Sendable {
    case overline = "Overline"
    case doubleFour = "Double-four"
    case doubleThree = "Double-three"
}

enum GameResult: String, Codable, Equatable, Sendable {
    case blackWin
    case whiteWin
    case blackTimeout
    case whiteTimeout
    case draw

    func playerWon(playerStone: Stone) -> Bool {
        switch self {
        case .blackWin: return playerStone == .black
        case .whiteWin: return playerStone == .white
        case .blackTimeout: return playerStone == .white
        case .whiteTimeout: return playerStone == .black
        case .draw: return false
        }
    }

    func aiWon(playerStone: Stone) -> Bool {
        self != .draw && !playerWon(playerStone: playerStone)
    }
}

struct RecordedMove: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let stone: Stone
    let move: Move

    init(id: UUID = UUID(), stone: Stone, move: Move) {
        self.id = id
        self.stone = stone
        self.move = move
    }
}

struct GameRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let playedAt: Date
    let playerStone: Stone
    let difficulty: AIDifficulty
    let adaptiveSkill: Int?
    let timeControl: TimeControl
    let result: GameResult
    let moves: [RecordedMove]

    init(
        id: UUID = UUID(),
        playedAt: Date,
        playerStone: Stone,
        difficulty: AIDifficulty,
        adaptiveSkill: Int?,
        timeControl: TimeControl,
        result: GameResult,
        moves: [RecordedMove]
    ) {
        self.id = id
        self.playedAt = playedAt
        self.playerStone = playerStone
        self.difficulty = difficulty
        self.adaptiveSkill = adaptiveSkill
        self.timeControl = timeControl
        self.result = result
        self.moves = moves
    }

    var resultText: String {
        if result == .draw { return "Draw" }
        return result.playerWon(playerStone: playerStone) ? "Win" : "Loss"
    }

    var aiLabel: String {
        if difficulty == .adaptive, let adaptiveSkill {
            return "Adaptive · \(adaptiveSkill)/100"
        }
        return difficulty.rawValue
    }
}
