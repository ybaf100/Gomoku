import XCTest
@testable import Gomoku

final class RapfiIntegrationTests: XCTestCase {
    func testEmbeddedRapfiReturnsLegalMove() {
        XCTAssertTrue(RapfiAI.isAvailable, "Embedded Rapfi bridge should be available")

        let history = [
            RecordedMove(stone: .black, move: Move(row: 7, column: 7)),
            RecordedMove(stone: .white, move: Move(row: 7, column: 8)),
            RecordedMove(stone: .black, move: Move(row: 8, column: 7)),
            RecordedMove(stone: .white, move: Move(row: 6, column: 7)),
            RecordedMove(stone: .black, move: Move(row: 8, column: 8)),
            RecordedMove(stone: .white, move: Move(row: 6, column: 8))
        ]
        let occupied = Set(history.map(\.move))

        RapfiAI.prepareSearch()
        guard let move = RapfiAI.chooseMove(
            history: history,
            stone: .black,
            timeLimit: 0.35,
            strengthLevel: 100
        ) else {
            XCTFail("Embedded Rapfi did not return a move")
            return
        }

        XCTAssertTrue((0..<15).contains(move.row))
        XCTAssertTrue((0..<15).contains(move.column))
        XCTAssertFalse(occupied.contains(move), "Rapfi must return an unoccupied move")
    }
}
