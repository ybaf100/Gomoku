#if RAPFI_ENABLED
import Foundation

enum RapfiAI {
    static var isAvailable: Bool {
        rapfi_is_available()
    }

    static func chooseMove(
        history: [RecordedMove],
        stone: Stone,
        timeLimit: TimeInterval,
        strengthLevel: Int
    ) -> Move? {
        guard stone == .black || stone == .white else { return nil }

        let rows = history.map { Int16($0.move.row) }
        let columns = history.map { Int16($0.move.column) }
        let stones = history.map { Int8($0.stone.rawValue) }

        var outRow: Int32 = -1
        var outColumn: Int32 = -1
        let milliseconds = Int32(
            min(
                Double(Int32.max),
                max(50, (timeLimit * 1_000).rounded())
            )
        )

        let success = rows.withUnsafeBufferPointer { rowBuffer in
            columns.withUnsafeBufferPointer { columnBuffer in
                stones.withUnsafeBufferPointer { stoneBuffer in
                    rapfi_choose_move(
                        rowBuffer.baseAddress,
                        columnBuffer.baseAddress,
                        stoneBuffer.baseAddress,
                        Int32(history.count),
                        Int32(stone.rawValue),
                        milliseconds,
                        Int32(min(100, max(0, strengthLevel))),
                        &outRow,
                        &outColumn
                    )
                }
            }
        }

        guard success,
              (0..<15).contains(Int(outRow)),
              (0..<15).contains(Int(outColumn)) else {
            return nil
        }
        return Move(row: Int(outRow), column: Int(outColumn))
    }

    static func cancel() {
        rapfi_cancel()
    }
}
#endif
