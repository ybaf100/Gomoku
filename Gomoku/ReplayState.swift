import Foundation
import Combine

struct ReplayPosition {
    let record: GameRecord
    let ply: Int
    init(record: GameRecord, ply: Int) {
        self.record = record
        self.ply = min(record.moves.count, max(0, ply))
    }
    var board: [[Stone]] {
        var value = Array(repeating: Array(repeating: Stone.empty, count: 15), count: 15)
        for entry in record.moves.prefix(ply) where (0..<15).contains(entry.move.row) && (0..<15).contains(entry.move.column) {
            value[entry.move.row][entry.move.column] = entry.stone
        }
        return value
    }
    var numbers: [Move: Int] {
        Dictionary(record.moves.prefix(ply).enumerated().map { ($0.element.move, $0.offset + 1) }, uniquingKeysWith: { _, new in new })
    }
    var last: Move? { ply > 0 ? record.moves[ply - 1].move : nil }
}

struct WinningRun: Equatable {
    /// Geometric order: left to right, or top to bottom for a vertical run.
    let points: [Move]
    let start: Move
    let end: Move
}

struct VictoryPattern {
    let runs: [WinningRun]
    let orderedStones: [Move]
    var stones: Set<Move> { Set(orderedStones) }
    var isEmpty: Bool { runs.isEmpty }
    static let beat = 0.24
    static let sweep = 0.65
    var duration: TimeInterval { isEmpty ? 0 : Double(orderedStones.count) * Self.beat + Self.sweep }

    init(record: GameRecord) {
        let position = ReplayPosition(record: record, ply: record.moves.count)
        guard record.result == .blackWin || record.result == .whiteWin,
              let last = position.last, (0..<15).contains(last.row), (0..<15).contains(last.column) else {
            runs = []; orderedStones = []; return
        }
        let board = position.board
        let stone: Stone = record.result == .blackWin ? .black : .white
        guard board[last.row][last.column] == stone else { runs = []; orderedStones = []; return }
        var found: [WinningRun] = []
        for (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)] {
            var line = [last]
            for sign in [-1, 1] {
                var r = last.row + dr * sign, c = last.column + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c), board[r][c] == stone {
                    line.append(Move(row: r, column: c)); r += dr * sign; c += dc * sign
                }
            }
            guard stone == .black ? line.count == 5 : line.count >= 5 else { continue }
            line.sort { $0.column == $1.column ? $0.row < $1.row : $0.column < $1.column }
            let left = line[0], right = line[line.count - 1]
            // A middle winning move always sweeps from the left endpoint.
            let start = last == right ? right : left
            found.append(WinningRun(points: line, start: start, end: start == left ? right : left))
        }
        runs = found
        let members = Set(found.flatMap(\.points))
        var seen = Set<Move>()
        orderedStones = record.moves.compactMap { entry in
            guard members.contains(entry.move), seen.insert(entry.move).inserted else { return nil }
            return entry.move
        }
    }

    func frame(elapsed: TimeInterval) -> VictoryFrame {
        guard !isEmpty, elapsed >= 0 else { return VictoryFrame(lit: [], active: nil, pulse: 0, lineProgress: 0) }
        let count = min(orderedStones.count, Int(elapsed / Self.beat) + 1)
        let lineStart = Double(orderedStones.count) * Self.beat
        let active = elapsed < lineStart ? orderedStones[count - 1] : nil
        let pulse = active == nil ? 0 : 1 - (elapsed.truncatingRemainder(dividingBy: Self.beat) / Self.beat)
        return VictoryFrame(lit: Array(orderedStones.prefix(count)), active: active, pulse: pulse,
                            lineProgress: min(1, max(0, (elapsed - lineStart) / Self.sweep)))
    }
}

struct VictoryFrame {
    let lit: [Move]
    let active: Move?
    let pulse: Double
    let lineProgress: Double
}

/// One player per record, retained above responsive layouts and sheets.
@MainActor
final class ReplayPlayback: ObservableObject {
    let record: GameRecord
    let victory: VictoryPattern
    @Published private(set) var ply: Int
    @Published private(set) var playing = false
    @Published private(set) var automatic = false
    @Published private(set) var speed: Double
    @Published private(set) var celebrationStart: Date?
    private(set) var automaticConsumed = false
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private let defaults: UserDefaults
    private let speedKey = "gomoku.replay.speed"
    var position: ReplayPosition { ReplayPosition(record: record, ply: ply) }
    var interval: TimeInterval { 0.7 / speed }
    var speedLabel: String {
        let value = (speed * 2).rounded() / 2
        if value == value.rounded() {
            return "\(Int(value))×"
        }
        return String(format: "%.1f×", value)
    }

    init(record: GameRecord, defaults: UserDefaults = .standard) {
        self.record = record; self.defaults = defaults
        victory = VictoryPattern(record: record)
        ply = record.moves.count
        let saved = defaults.double(forKey: "gomoku.replay.speed")
        speed = saved.isFinite && saved >= 0.5 ? min(16, saved) : 1
        if !victory.isEmpty { celebrationStart = Date(timeIntervalSinceNow: -victory.duration) }
    }

    func activate(autoplay: Bool, reduceMotion: Bool) {
        guard !automaticConsumed else { return }
        automaticConsumed = true
        guard autoplay, !reduceMotion, !record.moves.isEmpty else { return }
        ply = 0; speed = 16
        begin(automatic: true, initialDelay: 0.35)
    }

    func setSpeed(_ value: Double) {
        guard value.isFinite else { return }
        speed = min(16, max(0.5, value))
        defaults.set(speed, forKey: speedKey)
        if playing { begin(automatic: false) }
    }

    func toggle() {
        if playing { pause(); return }
        guard !record.moves.isEmpty else { return }
        if ply == record.moves.count { ply = 0 }
        begin(automatic: false)
    }

    func seek(_ value: Int) {
        pause()
        automaticConsumed = true
        ply = min(record.moves.count, max(0, value))
        celebrationStart = ply == record.moves.count && !victory.isEmpty ? Date() : nil
    }

    func pause() {
        generation = UUID()
        task?.cancel(); task = nil
        playing = false; automatic = false
    }

    private func begin(automatic: Bool, initialDelay: Double = 0) {
        pause()
        celebrationStart = nil
        playing = true; self.automatic = automatic
        let token = generation
        task = Task { [weak self] in
            if initialDelay > 0 {
                do { try await Task.sleep(for: .seconds(initialDelay)) } catch { return }
            }
            while let self, !Task.isCancelled, self.generation == token, self.ply < self.record.moves.count {
                do { try await Task.sleep(for: .seconds(self.interval)) } catch { return }
                guard !Task.isCancelled, self.generation == token else { return }
                self.ply += 1
                if self.ply == self.record.moves.count {
                    self.playing = false; self.automatic = false
                    self.celebrationStart = self.victory.isEmpty ? nil : Date()
                    self.task = nil
                }
            }
        }
    }
}
