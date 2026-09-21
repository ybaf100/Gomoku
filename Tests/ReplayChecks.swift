import Foundation

extension EngineChecks {
    static func replayRecord(_ points: [Move], stone: Stone = .black, result: GameResult? = nil) -> GameRecord {
        var moves: [RecordedMove] = []
        for (index, point) in points.enumerated() {
            let filler = RecordedMove(stone: stone.opponent, move: Move(row: index * 2, column: 0))
            if stone == .white { moves.append(filler) }
            moves.append(RecordedMove(stone: stone, move: point))
            if stone == .black && index < points.count - 1 { moves.append(filler) }
        }
        return GameRecord(playerStone: .black, difficulty: .hard, adaptiveSkill: nil, timeControl: .unlimited,
                          result: result ?? (stone == .black ? .blackWin : .whiteWin), moves: moves)
    }

    static func replayChecks() {
        let left = Move(row: 7, column: 3), right = Move(row: 7, column: 7)
        let middle = [3, 4, 6, 7, 5].map { Move(row: 7, column: $0) }
        let record = replayRecord(middle)
        let pattern = VictoryPattern(record: record)
        require(pattern.orderedStones == middle, "gold borders follow move order, not geometric position")
        require(pattern.runs.first?.start == left && pattern.runs.first?.end == right,
                "middle winning stone sweeps from left endpoint")
        let rightWin = VictoryPattern(record: replayRecord([3, 4, 5, 6, 7].map { Move(row: 7, column: $0) }))
        require(rightWin.runs.first?.start == right && rightWin.runs.first?.end == left, "right endpoint victory sweeps right to left")
        let leftWin = VictoryPattern(record: replayRecord([4, 5, 6, 7, 3].map { Move(row: 7, column: $0) }))
        require(leftWin.runs.first?.start == left, "left endpoint victory starts at that endpoint")
        for (dr, dc) in [(1, 0), (1, 1), (-1, 1)] {
            let points = [0, 1, 3, 4, 2].map { Move(row: 7 + $0 * dr, column: 4 + $0 * dc) }
            let line = VictoryPattern(record: replayRecord(points)).runs[0]
            require(line.points.count == 5 && line.start == points[0], "vertical and diagonal middle victories begin at top/left endpoint")
        }
        let six = [3, 4, 5, 7, 8, 6].map { Move(row: 7, column: $0) }
        let white = VictoryPattern(record: replayRecord(six, stone: .white))
        require(white.orderedStones == six && white.runs.first?.points.count == 6, "White six-in-row includes all six stones")
        require(VictoryPattern(record: replayRecord(six)).isEmpty, "Black overline never receives victory animation")
        for result in [GameResult.blackResigned, .whiteResigned, .blackTimeout, .whiteTimeout, .draw] {
            require(VictoryPattern(record: replayRecord(middle, result: result)).isEmpty,
                    "resignation, timeout and draw cannot animate even with a stored line")
        }
        require(pattern.frame(elapsed: 0).lit == [middle[0]], "first beat lights only the oldest winning stone")
        require(pattern.frame(elapsed: 0.97).lit == middle && pattern.frame(elapsed: 0.97).lineProgress == 0,
                "every border lights before the line begins")
        require(pattern.frame(elapsed: 1.5).lineProgress > 0 && pattern.frame(elapsed: 1.5).lineProgress < 1,
                "line sweeps after the last border")
        require(pattern.frame(elapsed: 10).lineProgress == 1 && pattern.frame(elapsed: 10).active == nil,
                "celebration settles without looping")
        let decoded = try! JSONDecoder().decode(GameRecord.self, from: JSONEncoder().encode(record))
        require(ReplayPosition(record: decoded, ply: 999).numbers[middle.last!] == 9,
                "saved records reconstruct numbered stones and clamp upper seek")
        require(ReplayPosition(record: record, ply: -1).last == nil, "negative replay seek is clamped")
    }

    @MainActor
    static func playbackChecks() async {
        let suite = "gomoku.replay.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let record = replayRecord([3, 4, 6, 7, 5].map { Move(row: 7, column: $0) })
        let history = ReplayPlayback(record: record, defaults: defaults)
        history.activate(autoplay: false, reduceMotion: false)
        require(history.ply == 9 && history.position.numbers.count == 9 && !history.playing,
                "history opens with the complete visible numbered board")
        let player = ReplayPlayback(record: record, defaults: defaults)
        player.activate(autoplay: true, reduceMotion: false)
        require(player.ply == 0 && player.playing && player.automatic && player.speed == 16, "new results start one fast timelapse")
        for _ in 0..<200 where player.playing { try? await Task.sleep(for: .milliseconds(10)) }
        require(player.ply == 9 && !player.playing && player.celebrationStart != nil, "timelapse finishes and starts gold celebration")
        player.activate(autoplay: true, reduceMotion: false)
        require(player.ply == 9 && !player.playing, "view reappearance cannot repeat automatic playback")
        player.setSpeed(0.5)
        require(player.interval == 1.4 && ReplayPlayback(record: record, defaults: defaults).speed == 0.5, "manual playback speed is applied and saved")
        player.seek(0); player.toggle(); player.seek(3)
        try? await Task.sleep(for: .milliseconds(100))
        require(player.ply == 3 && !player.playing && player.celebrationStart == nil, "scrubbing cancels pending replay and hides victory overlay")
        player.setSpeed(16); player.toggle(); player.pause()
        try? await Task.sleep(for: .milliseconds(100))
        require(player.ply == 3, "leaving replay cancels outstanding ticks")
        player.seek(99)
        require(player.ply == 9 && player.celebrationStart != nil, "manual seek to end can replay celebration")
        let reduced = ReplayPlayback(record: record, defaults: defaults)
        reduced.activate(autoplay: true, reduceMotion: true)
        require(reduced.ply == 9 && !reduced.playing, "Reduce Motion shows the final board without automatic animation")
        let empty = ReplayPlayback(record: sample(.normal, .blackResigned), defaults: defaults)
        empty.activate(autoplay: true, reduceMotion: false); empty.toggle()
        require(empty.ply == 0 && !empty.playing && empty.celebrationStart == nil, "zero-move resignations have a safe empty replay")
    }
}
