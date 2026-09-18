import Foundation

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

enum AIDifficulty: String, CaseIterable, Identifiable, Sendable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"

    var id: String { rawValue }
}

enum TimeControl: String, CaseIterable, Identifiable, Sendable {
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

enum GameResult: Equatable, Sendable {
    case blackWin
    case whiteWin
    case blackTimeout
    case whiteTimeout
    case draw
}
