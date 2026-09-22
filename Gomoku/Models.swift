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
}

struct Move: Hashable, Codable, Sendable {
    let row: Int
    let column: Int

    var coordinate: String {
        let letter = String(UnicodeScalar(65 + column)!)
        return "\(letter)\(row + 1)"
    }
}

enum AIDifficulty: String, CaseIterable, Identifiable, Codable, Sendable {
    case easy
    case normal
    case hard
    case veryHard
    case adaptive

    var id: String { rawValue }

    var automaticColour: Bool { self == .adaptive || self == .veryHard }
}

/// Setup preference; a live game always uses a concrete Black or White stone.
enum StoneSelection: String, Codable, Sendable {
    case black
    case white
    case random
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .korean: return "ko_KR"
        case .english: return "en_US"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum TimeControl: String, CaseIterable, Identifiable, Codable, Sendable {
    case blitz
    case fast
    case slow
    case unlimited

    var id: String { rawValue }

    var clockConfiguration: ClockConfiguration? {
        switch self {
        case .blitz: return ClockConfiguration(initial: 45, increment: 0, ceiling: 45)
        case .fast: return ClockConfiguration(initial: 30, increment: 5, ceiling: 45)
        case .slow: return ClockConfiguration(initial: 60, increment: 10, ceiling: 90)
        case .unlimited: return nil
        }
    }

    var seconds: Double? { clockConfiguration?.initial }
}

enum ForbiddenReason: String, Codable, Sendable {
    case overline
    case doubleFour
    case doubleThree

    var marker: String {
        switch self {
        case .doubleThree: return "33"
        case .doubleFour: return "44"
        case .overline: return "6+"
        }
    }
}

enum GameResult: String, Codable, Equatable, Sendable {
    case blackWin
    case whiteWin
    case blackTimeout
    case whiteTimeout
    case blackResigned
    case whiteResigned
    case draw

    func playerWon(playerStone: Stone) -> Bool {
        switch self {
        case .blackWin: return playerStone == .black
        case .whiteWin: return playerStone == .white
        case .blackTimeout, .blackResigned: return playerStone == .white
        case .whiteTimeout, .whiteResigned: return playerStone == .black
        case .draw: return false
        }
    }

    func aiWon(playerStone: Stone) -> Bool {
        self != .draw && !playerWon(playerStone: playerStone)
    }
}

enum GameNotice: Equatable {
    case occupied
    case selectMove
    case forbidden(ForbiddenReason)
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
    // Missing on older records, which used a fixed total clock.
    let clockConfiguration: ClockConfiguration?

    init(
        id: UUID = UUID(),
        playedAt: Date = Date(),
        playerStone: Stone,
        difficulty: AIDifficulty,
        adaptiveSkill: Int?,
        timeControl: TimeControl,
        result: GameResult,
        moves: [RecordedMove],
        clockConfiguration: ClockConfiguration? = nil
    ) {
        self.id = id
        self.playedAt = playedAt
        self.playerStone = playerStone
        self.difficulty = difficulty
        self.adaptiveSkill = adaptiveSkill
        self.timeControl = timeControl
        self.result = result
        self.moves = moves
        self.clockConfiguration = clockConfiguration
    }
}
