import Foundation

@main
struct BenchmarkBefore {
    static func main() {
        var board = Array(repeating: Array(repeating: Stone.empty, count: 15), count: 15)
        for (r, c) in [(4,4),(6,8),(8,5),(10,10),(7,9)] { board[r][c] = .black }
        for (r, c) in [(5,5),(8,8),(9,7),(7,4)] { board[r][c] = .white }
        let start = ProcessInfo.processInfo.systemUptime
        let result = RenjuRules.forbiddenReason(board: board, move: Move(row: 7, column: 7))
        print(String(format: "Before: %.3f ms, result: %@", (ProcessInfo.processInfo.systemUptime - start) * 1000, String(describing: result)))
    }
}
