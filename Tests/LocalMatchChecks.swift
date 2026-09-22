import Foundation

extension EngineChecks {
    static func localMatchChecks() {
        var colours = LocalColourAssignment(selectedBottomStone: .white)
        require(colours.bottomStone == .white, "Local first game honours the selected Black player")
        colours.rematch()
        require(colours.bottomStone == .black, "Local rematch swaps the two players' colours")

        let asymmetric = LocalClockSetup(
            bottom: .init(initial: 180, increment: 2),
            top: .init(initial: 300, increment: 0)
        )
        var core = LocalMatchCore(setup: asymmetric, bottomStone: .black, now: 0)
        let first = Move(row: 7, column: 7)
        core.selectedMove = first
        core.forbiddenMoves = [Move(row: 0, column: 0): .doubleThree]
        require(core.commit(first, stone: .black, at: 10), "Local legal move commits")
        require(core.clock.black == 172 && core.clock.white == 300,
                "asymmetric clock and Black increment are applied exactly once")
        require(core.moves.count == 1 && core.currentTurn == .white,
                "committed Local move advances history and turn")
        require(core.undo(at: 20), "one Local move can be undone")
        require(core.moves.isEmpty && core.board[7][7] == .empty && core.currentTurn == .black,
                "undo restores board, history and the player who made the move")
        require(core.selectedMove == first && core.forbiddenMoves[Move(row: 0, column: 0)] == .doubleThree,
                "undo restores preview and forbidden-marker state")
        require(core.clock.black == 170 && core.clock.white == 300 && core.clock.activeStone == .black,
                "undo restores the exact pre-move clock snapshot without reversing increment")
        require(core.result == nil, "undo leaves no stale result or celebration source")

        var mixedClock = LocalMatchCore(
            setup: .init(bottom: .unlimited, top: .init(initial: 60, increment: 3)),
            bottomStone: .black,
            now: 0
        )
        mixedClock.selectedMove = first
        require(mixedClock.commit(first, stone: .black, at: 30)
                && mixedClock.clock.black == nil && mixedClock.clock.white == 60,
                "one Local player can be Unlimited while the other uses a clock")

        var resign = LocalMatchCore(now: 0)
        require(resign.resignCurrentPlayer() == .blackResigned, "Local resignation loses for the current player")
        var score = LocalSessionScore()
        score.record(.blackResigned, bottomStone: .black)
        score.record(.whiteTimeout, bottomStone: .white)
        require(score.top.wins == 2 && score.bottom.losses == 2 && score.top.winRate == 1,
                "resignations and timeouts update position-based Local W/L and win rate")
        score.record(.draw, bottomStone: .black)
        require(score.top.wins == 2 && score.bottom.losses == 2,
                "draws are excluded from Local W/L and the win-rate denominator")
        score.reset()
        require(score.bottom.wins == 0 && score.bottom.losses == 0 && score.top.winRate == 0,
                "leaving for the main menu resets the in-memory Local session score")

        let blackFive = localWinningCore(
            winningStone: .black,
            points: [3, 4, 5, 6, 7].map { Move(row: 7, column: $0) }
        )
        require(blackFive.result == .blackWin
                && VictoryPattern(record: localRecord(blackFive)).runs.first?.points.count == 5,
                "Local Black exact five produces the shared victory pattern")

        let whiteFive = localWinningCore(
            winningStone: .white,
            points: [3, 4, 5, 6, 7].map { Move(row: 8, column: $0) }
        )
        require(whiteFive.result == .whiteWin
                && VictoryPattern(record: localRecord(whiteFive)).runs.first?.points.count == 5,
                "Local White five produces the shared victory pattern")

        let whiteSix = localWinningCore(
            winningStone: .white,
            points: [3, 4, 6, 7, 8, 5].map { Move(row: 9, column: $0) }
        )
        require(whiteSix.result == .whiteWin
                && VictoryPattern(record: localRecord(whiteSix)).runs.first?.points.count == 6,
                "Local White bridge to six animates all six stones")

        let blackOverline = localWinningCore(
            winningStone: .black,
            points: [3, 4, 6, 7, 8, 5].map { Move(row: 10, column: $0) }
        )
        require(blackOverline.result == nil,
                "Black overline is not treated as a Local line victory")
        let overlineRecord = GameRecord(
            playerStone: .black,
            difficulty: .normal,
            adaptiveSkill: nil,
            timeControl: .unlimited,
            result: .blackWin,
            moves: blackOverline.moves
        )
        require(VictoryPattern(record: overlineRecord).isEmpty,
                "Black overline cannot leave a celebration pattern")
    }

    private static func localWinningCore(winningStone: Stone, points: [Move]) -> LocalMatchCore {
        var core = LocalMatchCore(now: 0)
        var fillerColumn = 0
        for point in points {
            if core.currentTurn != winningStone {
                _ = core.commit(Move(row: winningStone == .black ? 0 : 1, column: fillerColumn),
                                stone: core.currentTurn, at: 0)
                fillerColumn += 2
            }
            guard core.result == nil else { break }
            _ = core.commit(point, stone: winningStone, at: 0)
            if core.result == nil, core.currentTurn != winningStone {
                _ = core.commit(Move(row: winningStone == .black ? 0 : 1, column: fillerColumn),
                                stone: core.currentTurn, at: 0)
                fillerColumn += 2
            }
        }
        return core
    }

    private static func localRecord(_ core: LocalMatchCore) -> GameRecord {
        GameRecord(
            playerStone: .black,
            difficulty: .normal,
            adaptiveSkill: nil,
            timeControl: .unlimited,
            result: core.result ?? .draw,
            moves: core.moves
        )
    }
}
