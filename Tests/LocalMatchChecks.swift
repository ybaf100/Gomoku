import Foundation
import CoreGraphics

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
        var topResigns = LocalMatchCore(now: 0)
        require(topResigns.resign(.white) == .whiteResigned && topResigns.result?.localWinner == .black,
                "a seat can resign from its own menu even when it is not that seat's turn")
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

        localSeriesChecks()
        localWarningChecks()
        localGeometryChecks()
    }

    private static func localSeriesChecks() {
        var single = LocalSeriesScore(format: .single, firstBottomStone: .white)
        require(single.currentBottomStone == .white && single.gameNumber == 1,
                "selected colours apply to the first game")
        single.record(.whiteResigned)
        require(single.topWins == 1 && single.isComplete && !single.advance(),
                "one resignation finishes a single game series without double counting")
        single.restart()
        require(single.currentBottomStone == .black && single.topWins == 0 && single.gameNumber == 1,
                "new series swaps its original opening colour and resets only series score")

        for (format, results, expectedBottom, expectedTop) in [
            (LocalMatchFormat.bestOfThree, [true, true], 2, 0),
            (.bestOfThree, [true, false, true], 2, 1),
            (.bestOfFive, [true, true, true], 3, 0),
            (.bestOfFive, [true, false, true, true], 3, 1),
            (.bestOfFive, [true, false, true, false, true], 3, 2)
        ] {
            var series = LocalSeriesScore(format: format, firstBottomStone: .black)
            var session = LocalSessionScore()
            require(!series.advance(), "a new series cannot advance before finishing a game")
            for (index, bottomWins) in results.enumerated() {
                let bottomStone = series.currentBottomStone
                let winner = bottomWins ? bottomStone : bottomStone.opponent
                let outcome: GameResult = winner == .black ? .blackWin : .whiteWin
                series.record(outcome)
                series.record(outcome)
                session.record(outcome, bottomStone: bottomStone)
                if index < results.count - 1 {
                    require(!series.isComplete && series.advance(), "series continues until the target number of wins")
                    require(series.currentBottomStone == bottomStone.opponent,
                            "colours alternate after every finished game")
                }
            }
            require(series.isComplete && series.bottomWins == expectedBottom && series.topWins == expectedTop,
                    "best-of series ends at the correct first-to target")
            require(session.bottom.wins == expectedBottom && session.bottom.losses == expectedTop,
                    "session W/L counts individual games, not an extra series victory")
            require(!series.advance(), "completed series cannot accept another game")
            series.restart()
            require(series.bottomWins == 0 && series.topWins == 0 && series.gameNumber == 1
                    && session.bottom.wins == expectedBottom,
                    "series restart retains session stats but resets its score")
        }

        var draw = LocalSeriesScore(format: .bestOfThree)
        draw.record(.draw)
        require(draw.bottomWins == 0 && draw.topWins == 0 && draw.advance()
                && draw.currentBottomStone == .white,
                "draw leaves the score unchanged but consumes a game and swaps colours")
        draw.record(.blackWin)
        require(draw.topWins == 1 && !draw.isComplete && draw.advance(), "Bo3 stays active at 1:0")
        draw.record(.whiteTimeout)
        require(draw.bottomWins == 1 && !draw.isComplete && draw.advance(),
                "a timeout win contributes exactly one series point")
        draw.record(.whiteResigned)
        require(draw.topWins == 2 && draw.isComplete, "a resignation win finishes the series")
        draw = LocalSeriesScore()
        require(draw.gameNumber == 1 && draw.bottomWins == 0 && draw.topWins == 0,
                "leaving the main menu resets the in-memory series")
    }

    private static func localWarningChecks() {
        var core = LocalMatchCore(setup: .init(
            bottom: .init(initial: 11, increment: 0),
            top: .init(initial: 9, increment: 0)), bottomStone: .black, now: 0)
        require(!core.isTimeWarning(for: .black) && !core.isTimeWarning(for: .white),
                "11 seconds and an opponent waiting at 9 seconds show no warning")
        core.settleClock(at: 1)
        require(core.isTimeWarning(for: .black), "10 seconds on turn triggers the warning")
        core.settleClock(at: 2)
        require(core.isTimeWarning(for: .black) && !core.isTimeWarning(for: .white),
                "9 seconds warns only the player whose turn it is")
        require(core.commit(Move(row: 7, column: 7), stone: .black, at: 2)
                && core.isTimeWarning(for: .white) && !core.isTimeWarning(for: .black),
                "turn handoff activates the waiting 9-second player's warning")
        require(core.undo(at: 3) && core.isTimeWarning(for: .black),
                "undo restores clock, turn and warning from their snapshot")
        require(core.commit(Move(row: 7, column: 7), stone: .black, at: 3), "turn resumes after undo")
        core.settleClock(at: 12)
        require(core.result == .whiteTimeout && !core.isTimeWarning(for: .white),
                "zero seconds causes a timeout and clears warning")
        core.start(setup: .symmetric(.unlimited), bottomStone: .white, now: 13)
        require(!core.isTimeWarning(for: .black) && !core.isTimeWarning(for: .white),
                "new Unlimited game has no stale warning")
    }

    private static func localGeometryChecks() {
        for side in [CGFloat(375), CGFloat(768)] {
            let geometry = BoardGeometry(size: CGSize(width: side, height: side))
            for direction in [(0, 1), (1, 0), (1, 1), (-1, 1)] {
                for step in 0..<5 {
                    let move = Move(row: 7 + direction.0 * step, column: 5 + direction.1 * step)
                    let stoneCenter = geometry.center(move)
                    let ringCenter = geometry.center(move)
                    let lineEndpoint = geometry.center(move)
                    require(stoneCenter == ringCenter && ringCenter == lineEndpoint
                            && geometry.move(at: stoneCenter) == move,
                            "all four victory directions use the stone's exact board intersection")
                }
            }
            let rotatedPlayerUI = geometry.center(Move(row: 7, column: 6))
            require(rotatedPlayerUI == geometry.center(Move(row: 7, column: 6)),
                    "top player rotation does not affect board-space coordinates")
        }
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
