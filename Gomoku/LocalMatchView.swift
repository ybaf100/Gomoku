import SwiftUI
import Foundation

@MainActor
final class LocalMatchViewModel: ObservableObject {
    @Published private(set) var board = Array(
        repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
        count: RenjuRules.boardSize
    )
    @Published private(set) var currentTurn: Stone = .black
    @Published private(set) var result: GameResult?
    @Published private(set) var lastMove: Move?
    @Published private(set) var selectedMove: Move?
    @Published private(set) var notice: GameNotice?
    @Published private(set) var blackTime: Double?
    @Published private(set) var whiteTime: Double?
    @Published private(set) var forbiddenMoves: [Move: ForbiddenReason] = [:]
    @Published private(set) var isValidatingMove = false
    @Published private(set) var completedRecord: GameRecord?
    @Published var isGameActive = false
    @Published var unlimited = false
    @Published var customSeconds: Double = 300
    @Published private(set) var bottomStone: Stone = .black

    var topStone: Stone { bottomStone.opponent }

    private var matchClock: MatchClock?
    private var clockTimer: Timer?
    private var moves: [RecordedMove] = []
    private var validationTask: Task<Void, Never>?
    private var validationID: UUID?
    private var forbiddenTask: Task<Void, Never>?
    private var forbiddenRequestID: UUID?

    var showsForbiddenMoves: Bool {
        isGameActive && result == nil && currentTurn == .black
    }

    var clockConfiguration: ClockConfiguration? {
        guard !unlimited else { return nil }
        let seconds = min(1800, max(15, customSeconds))
        return ClockConfiguration(initial: seconds, increment: 0, ceiling: seconds)
    }

    func startGame(swapSides: Bool = false) {
        stop()
        if swapSides {
            bottomStone = bottomStone.opponent
        }
        board = Array(
            repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
            count: RenjuRules.boardSize
        )
        currentTurn = .black
        result = nil
        lastMove = nil
        selectedMove = nil
        notice = nil
        moves = []
        completedRecord = nil
        matchClock = MatchClock(configuration: clockConfiguration, now: now())
        publishClock()
        isGameActive = true
        startClock()
        refreshForbiddenMoves()
    }

    func rematch() {
        startGame(swapSides: true)
    }

    func stop() {
        clockTimer?.invalidate()
        clockTimer = nil
        validationID = nil
        validationTask?.cancel()
        validationTask = nil
        forbiddenRequestID = nil
        forbiddenTask?.cancel()
        forbiddenTask = nil
        isValidatingMove = false
    }

    func selectMove(_ move: Move) {
        guard isGameActive, result == nil, !isValidatingMove else { return }
        guard board[move.row][move.column] == .empty else {
            notice = .occupied
            return
        }
        if let reason = forbiddenMoves[move], showsForbiddenMoves {
            selectedMove = nil
            notice = .forbidden(reason)
            return
        }
        selectedMove = move
        notice = nil
    }

    func cancelSelection() {
        guard !isValidatingMove else { return }
        selectedMove = nil
        notice = nil
    }

    func confirmSelectedMove(for stone: Stone) {
        guard isGameActive, result == nil, currentTurn == stone, !isValidatingMove else { return }
        guard let move = selectedMove else {
            notice = .selectMove
            return
        }
        guard board[move.row][move.column] == .empty else {
            selectedMove = nil
            notice = .occupied
            return
        }

        let snapshot = board
        let requestID = UUID()
        validationID = requestID
        isValidatingMove = true
        notice = nil

        validationTask = Task.detached(priority: .userInitiated) { [weak self] in
            let forbidden = stone == .black
                ? RenjuRules.forbiddenReason(board: snapshot, move: move)
                : nil
            guard !Task.isCancelled else { return }
            await self?.completeValidation(
                requestID,
                snapshot: snapshot,
                move: move,
                stone: stone,
                forbidden: forbidden
            )
        }
    }

    private func completeValidation(
        _ requestID: UUID,
        snapshot: [[Stone]],
        move: Move,
        stone: Stone,
        forbidden: ForbiddenReason?
    ) {
        guard validationID == requestID,
              isGameActive,
              result == nil,
              currentTurn == stone,
              board == snapshot else { return }

        validationID = nil
        validationTask = nil
        isValidatingMove = false
        tickClock()
        guard result == nil else { return }

        if let forbidden {
            notice = .forbidden(forbidden)
            return
        }
        applyLegalMove(move, stone: stone)
    }

    private func applyLegalMove(_ move: Move, stone: Stone) {
        guard result == nil, currentTurn == stone, board[move.row][move.column] == .empty else { return }
        guard matchClock?.completeMove(by: stone, at: now()) != false else {
            tickClock()
            return
        }

        publishClock()
        invalidateForbiddenMoves()
        board[move.row][move.column] = stone
        moves.append(RecordedMove(stone: stone, move: move))
        lastMove = move
        selectedMove = nil
        notice = nil

        if RenjuRules.isWinningMove(board: board, move: move, stone: stone) {
            finish(stone == .black ? .blackWin : .whiteWin)
            return
        }
        if board.allSatisfy({ $0.allSatisfy { $0 != .empty } }) {
            finish(.draw)
            return
        }

        currentTurn = stone.opponent
        refreshForbiddenMoves()
    }

    private func refreshForbiddenMoves() {
        invalidateForbiddenMoves()
        guard showsForbiddenMoves else { return }
        let snapshot = board
        let requestID = UUID()
        forbiddenRequestID = requestID
        forbiddenTask = Task.detached(priority: .utility) { [weak self] in
            let markers = RenjuRules.forbiddenMoves(board: snapshot, isCancelled: { Task.isCancelled })
            guard !Task.isCancelled else { return }
            await self?.completeForbiddenScan(requestID, snapshot: snapshot, markers: markers)
        }
    }

    private func completeForbiddenScan(
        _ requestID: UUID,
        snapshot: [[Stone]],
        markers: [Move: ForbiddenReason]
    ) {
        guard forbiddenRequestID == requestID, showsForbiddenMoves, board == snapshot else { return }
        forbiddenRequestID = nil
        forbiddenTask = nil
        forbiddenMoves = markers
        if !isValidatingMove, let selectedMove, let reason = markers[selectedMove] {
            self.selectedMove = nil
            notice = .forbidden(reason)
        }
    }

    private func invalidateForbiddenMoves() {
        forbiddenRequestID = nil
        forbiddenTask?.cancel()
        forbiddenTask = nil
        forbiddenMoves = [:]
    }

    private func startClock() {
        clockTimer?.invalidate()
        guard clockConfiguration != nil else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickClock() }
        }
    }

    private func tickClock() {
        guard isGameActive, result == nil else { return }
        let expired = matchClock?.settle(at: now())
        publishClock()
        if let expired {
            finish(expired == .black ? .blackTimeout : .whiteTimeout)
        }
    }

    private func publishClock() {
        blackTime = matchClock?.black
        whiteTime = matchClock?.white
    }

    private func finish(_ newResult: GameResult) {
        guard result == nil else { return }
        result = newResult
        selectedMove = nil
        stop()
        completedRecord = GameRecord(
            playerStone: .black,
            difficulty: .normal,
            adaptiveSkill: nil,
            timeControl: .unlimited,
            result: newResult,
            moves: moves,
            clockConfiguration: matchClock?.configuration
        )
    }

    func formattedTime(for stone: Stone) -> String {
        let value = stone == .black ? blackTime : whiteTime
        guard let value else { return "∞" }
        let seconds = max(0, Int(ceil(value)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func timeFraction(for stone: Stone) -> Double {
        guard let ceiling = matchClock?.configuration?.ceiling, ceiling > 0,
              let remaining = stone == .black ? blackTime : whiteTime else { return 1 }
        return min(1, max(0, remaining / ceiling))
    }

    func isTimeLow(for stone: Stone) -> Bool {
        guard let remaining = stone == .black ? blackTime : whiteTime else { return false }
        return remaining <= 10
    }

    func resultTitle(language: AppLanguage) -> String {
        guard let result else { return "" }
        switch result {
        case .blackWin: return L10n.choose("흑 승리", "Black wins", language)
        case .whiteWin: return L10n.choose("백 승리", "White wins", language)
        case .blackTimeout: return L10n.choose("흑 시간패 · 백 승리", "Black timed out · White wins", language)
        case .whiteTimeout: return L10n.choose("백 시간패 · 흑 승리", "White timed out · Black wins", language)
        case .draw: return L10n.text("draw", language)
        case .blackResigned: return L10n.choose("흑 기권 · 백 승리", "Black resigned · White wins", language)
        case .whiteResigned: return L10n.choose("백 기권 · 흑 승리", "White resigned · Black wins", language)
        }
    }

    private func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}

struct LocalMatchView: View {
    let language: AppLanguage
    @StateObject private var game = LocalMatchViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var theme: GomokuTheme { GomokuTheme(scheme) }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                landscapeUnsupported
            } else if game.isGameActive {
                matchScreen(size: geometry.size)
            } else {
                setupScreen
            }
        }
        .background { GameBackdrop() }
        .foregroundStyle(theme.ink)
        .onDisappear { game.stop() }
    }

    private var landscapeUnsupported: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "rectangle.portrait.rotate")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(theme.accent)
            Text(L10n.choose("혼자 두기는 세로 모드 전용입니다.", "Local play is portrait-only.", language))
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(L10n.choose("iPad를 세로로 돌려 위쪽과 아래쪽에서 마주 보고 플레이하세요.",
                             "Rotate the iPad to portrait and play face-to-face from the top and bottom.", language))
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button(L10n.text("backHome", language)) { dismiss() }
                .buttonStyle(GomokuButtonStyle(primary: false))
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    QuietIconButton(title: L10n.text("backHome", language), symbol: "xmark") { dismiss() }
                    Spacer()
                    Text(L10n.choose("혼자 두기", "Local Play", language))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Spacer()
                    Color.clear.frame(width: 46, height: 46)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 20) {
                        Label(L10n.choose("한 iPad에서 마주 보고 두기", "Face-to-face on one iPad", language),
                              systemImage: "person.2.fill")
                            .font(.headline)
                        Text(L10n.choose(
                            "첫 판은 아래쪽이 흑, 위쪽이 백입니다. 흑이 먼저 두며, 다시 대결할 때마다 두 플레이어의 흑백 위치가 서로 바뀝니다.",
                            "The first game starts with Black at the bottom and White at the top. Black moves first, and the players swap colours after every rematch.",
                            language
                        ))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)

                        Divider()

                        Toggle(isOn: $game.unlimited) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.text("unlimited", language)).font(.subheadline.bold())
                                Text(L10n.text("noClock", language)).font(.caption).foregroundStyle(theme.secondary)
                            }
                        }
                        .tint(theme.accent)

                        if !game.unlimited {
                            Stepper(value: $game.customSeconds, in: 15...1800, step: 15) {
                                HStack {
                                    Text(L10n.choose("각자 제한 시간", "Time per player", language))
                                    Spacer()
                                    Text(formatCustomTime(game.customSeconds))
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(theme.accent)
                                }
                            }
                            Text(L10n.choose("15초 단위로 15초부터 30분까지 설정할 수 있으며, 착수 후 시간 추가는 없습니다.",
                                             "Choose 15 seconds to 30 minutes in 15-second steps. No time is added after a move.",
                                             language))
                                .font(.caption)
                                .foregroundStyle(theme.secondary)
                        }

                        Button {
                            game.startGame()
                        } label: {
                            HStack {
                                Spacer()
                                Text(L10n.choose("혼자 두기 시작", "Start Local Play", language))
                                Spacer()
                                Image(systemName: "arrow.up")
                            }
                        }
                        .buttonStyle(GomokuButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 620)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func matchScreen(size: CGSize) -> some View {
        let boardSide = min(size.width - 28, size.height - 330)
        return VStack(spacing: 10) {
            playerPanel(stone: game.topStone, positionText: L10n.choose("위쪽 플레이어", "Top player", language))
                .rotationEffect(.degrees(180))

            ZStack {
                BoardView(
                    board: game.board,
                    lastMove: game.lastMove,
                    selectedMove: game.selectedMove,
                    previewStone: game.currentTurn,
                    enabled: game.result == nil && !game.isValidatingMove,
                    language: language,
                    forbiddenMoves: game.showsForbiddenMoves ? game.forbiddenMoves : [:],
                    winningLine: game.completedRecord.map { VictoryPattern(record: $0).stones } ?? [],
                    accessibilityPrefix: "local.intersection",
                    onSelect: game.selectMove
                )
                .frame(width: max(280, boardSide), height: max(280, boardSide))

                if let record = game.completedRecord {
                    let pattern = VictoryPattern(record: record)
                    if !pattern.isEmpty {
                        WinningCelebration(pattern: pattern, startedAt: Date.distantPast, language: language)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            playerPanel(stone: game.bottomStone, positionText: L10n.choose("아래쪽 플레이어", "Bottom player", language))
        }
        .overlay(alignment: .topTrailing) {
            Button {
                game.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("backHome", language))
        }
        .overlay {
            if game.result != nil {
                VStack(spacing: 12) {
                    Text(game.resultTitle(language: language))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    HStack(spacing: 10) {
                        Button(L10n.choose("다시 대결", "Rematch", language)) { game.rematch() }
                            .buttonStyle(GomokuButtonStyle())
                        Button(L10n.choose("나가기", "Exit", language)) {
                            game.stop()
                            dismiss()
                        }
                        .buttonStyle(GomokuButtonStyle(primary: false))
                    }
                }
                .padding(18)
                .frame(maxWidth: 440)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .padding(24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func playerPanel(stone: Stone, positionText: String) -> some View {
        let active = game.currentTurn == stone && game.result == nil
        let canPlace = active && game.selectedMove != nil && !game.isValidatingMove
        return SurfaceCard {
            HStack(spacing: 12) {
                StoneDisc(stone: stone, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(positionText).font(.caption).foregroundStyle(theme.secondary)
                    Text(L10n.stone(stone, language: language))
                        .font(.headline)
                }
                Spacer()
                if let selected = game.selectedMove, active {
                    Text(selected.coordinate)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                }
                Text(game.formattedTime(for: stone))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(game.isTimeLow(for: stone) ? theme.danger : active ? theme.accent : theme.ink)

                Button {
                    game.confirmSelectedMove(for: stone)
                } label: {
                    Text(game.isValidatingMove && active
                         ? L10n.text("validatingMove", language)
                         : active ? L10n.text("place", language)
                         : L10n.choose("대기", "Wait", language))
                        .frame(minWidth: 74)
                }
                .buttonStyle(GomokuButtonStyle(primary: active))
                .disabled(!canPlace)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(active ? theme.accent.opacity(0.65) : Color.clear, lineWidth: 2)
        }
    }

    private func formatCustomTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
