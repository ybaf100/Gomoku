import Foundation

struct ClockConfiguration: Codable, Equatable, Sendable {
    let initial: Double
    let increment: Double
    let ceiling: Double
}

/// A deterministic, monotonic clock. Increment belongs to the player who
/// completed a legal move, exactly once, and can never revive expired time.
struct MatchClock: Sendable {
    let configuration: ClockConfiguration?
    private(set) var black: Double?
    private(set) var white: Double?
    private(set) var activeStone: Stone = .black
    private var lastUpdate: TimeInterval

    init(configuration: ClockConfiguration?, now: TimeInterval) {
        self.configuration = configuration
        black = configuration.map { min($0.initial, $0.ceiling) }
        white = black
        lastUpdate = now
    }

    @discardableResult
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
        if let configuration {
            if stone == .black, let remaining = black {
                black = min(configuration.ceiling, remaining + configuration.increment)
            } else if stone == .white, let remaining = white {
                white = min(configuration.ceiling, remaining + configuration.increment)
            }
        }
        activeStone = stone.opponent
        return true
    }
}
