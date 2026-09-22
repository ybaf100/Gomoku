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
    @Published private(set) var sessionScore = LocalSessionScore()
    @Published private(set) var bottomStone: Stone = .black
    @Published var selectedBottomStone: Stone = .black
    @Published var isGameActive = false
    @Published var timePreset: LocalTimePreset = .fast
    @Published var bottomCustomUnlimited = false
    @Published var topCustomUnlimited = false
    @Published var bottomCustomSeconds: Double = 180
    @Published var topCustomSeconds: Double = 300
    @Published var bottomCustomIncrement: Double = 2
    @Published var topCustomIncrement: Double = 0

    var topStone: Stone { bottomStone.opponent }
    var canUndo: Bool { core.canUndo && !isValidatingMove }
    var showsForbiddenMoves: Bool {
        isGameActive && result == nil && currentTurn == .black
    }

    private var core = LocalMatchCore()
    private var colourAssignment = LocalColourAssignment(selectedBottomStone: .black)
    private var activeSetup = LocalClockSetup.symmetric(.unlimited)
    private var clockTimer: Timer?
    private var validationTask: Task<Void, Never>?
    private var validationID: UUID?
    private var forbiddenTask: Task<Void, Never>?
    private var forbiddenRequestID: UUID?
    private var didRecordResult = false
    private let clockNow: () -> TimeInterval

    init(clockNow: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clockNow = clockNow
    }

    func startGame(swapSides: Bool = false) {
        stopTasks()
        if swapSides {
            colourAssignment.rematch()
        } else {
            colourAssignment = LocalColourAssignment(selectedBottomStone: selectedBottomStone)
        }
        bottomStone = colourAssignment.bottomStone
        if !swapSides { activeSetup = configuredClockSetup }
        core.start(setup: activeSetup, bottomStone: bottomStone, now: clockNow())
        completedRecord = nil
        notice = nil
        didRecordResult = false
        isGameActive = true
        publishCore()
        startClock()
        refreshForbiddenMoves()
    }

    func rematch() {
        startGame(swapSides: true)
    }

    func resetSession() {
        stopTasks()
        sessionScore.reset()
        isGameActive = false
        completedRecord = nil
        notice = nil
    }

    func stop() {
        stopTasks()
    }

    func selectMove(_ move: Move) {
        guard isGameActive, result == nil, !isValidatingMove else { return }
        guard board[move.row][move.column] == .empty else {
            notice = .occupied
            return
        }
        if let reason = forbiddenMoves[move], showsForbiddenMoves {
            core.selectedMove = nil
            selectedMove = nil
            notice = .forbidden(reason)
            return
        }
        core.selectedMove = move
        selectedMove = move
        notice = nil
    }

    func cancelSelection() {
        guard !isValidatingMove else { return }
        core.selectedMove = nil
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
            core.selectedMove = nil
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
        guard core.commit(move, stone: stone, at: clockNow()) else {
            publishCore()
            if core.result != nil { finishFromCore() }
            return
        }
        notice = nil
        publishCore()
        if core.result != nil {
            finishFromCore()
        } else {
            refreshForbiddenMoves()
        }
    }

    func resignCurrentPlayer() {
        guard core.resignCurrentPlayer() != nil else { return }
        publishCore()
        finishFromCore()
    }

    func undoLastMove() {
        guard result == nil, !isValidatingMove else { return }
        invalidateValidationAndForbidden()
        guard core.undo(at: clockNow()) else { return }
        completedRecord = nil
        notice = nil
        publishCore()
        startClock()
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
        core.forbiddenMoves = markers
        forbiddenMoves = markers
        if !isValidatingMove, let selectedMove, let reason = markers[selectedMove] {
            core.selectedMove = nil
            self.selectedMove = nil
            notice = .forbidden(reason)
        }
    }

    private func invalidateForbiddenMoves() {
        forbiddenRequestID = nil
        forbiddenTask?.cancel()
        forbiddenTask = nil
        core.forbiddenMoves = [:]
        forbiddenMoves = [:]
    }

    private func invalidateValidationAndForbidden() {
        validationID = nil
        validationTask?.cancel()
        validationTask = nil
        isValidatingMove = false
        invalidateForbiddenMoves()
    }

    private func startClock() {
        clockTimer?.invalidate()
        let hasClock = core.clock.black != nil || core.clock.white != nil
        guard hasClock, result == nil else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickClock() }
        }
    }

    private func tickClock() {
        guard isGameActive, result == nil else { return }
        _ = core.settleClock(at: clockNow())
        publishCore()
        if core.result != nil { finishFromCore() }
    }

    private func finishFromCore() {
        guard let result = core.result, !didRecordResult else { return }
        didRecordResult = true
        stopTasks()
        publishCore()
        sessionScore.record(result, bottomStone: bottomStone)
        completedRecord = GameRecord(
            playerStone: bottomStone,
            difficulty: .normal,
            adaptiveSkill: nil,
            timeControl: recordTimeControl,
            result: result,
            moves: core.moves,
            clockConfiguration: nil
        )
    }

    private func stopTasks() {
        clockTimer?.invalidate()
        clockTimer = nil
        invalidateValidationAndForbidden()
    }

    private func publishCore() {
        board = core.board
        currentTurn = core.currentTurn
        result = core.result
        lastMove = core.lastMove
        selectedMove = core.selectedMove
        forbiddenMoves = core.forbiddenMoves
        blackTime = core.clock.black
        whiteTime = core.clock.white
    }

    private var configuredClockSetup: LocalClockSetup {
        if let setup = timePreset.setup { return setup }
        return LocalClockSetup(
            bottom: bottomCustomUnlimited
                ? .unlimited
                : .init(initial: min(7200, max(15, bottomCustomSeconds)),
                        increment: min(60, max(0, bottomCustomIncrement))),
            top: topCustomUnlimited
                ? .unlimited
                : .init(initial: min(7200, max(15, topCustomSeconds)),
                        increment: min(60, max(0, topCustomIncrement)))
        )
    }

    private var recordTimeControl: TimeControl {
        switch timePreset {
        case .blitz: return .blitz
        case .fast: return .fast
        case .slow: return .slow
        case .unlimited, .custom: return .unlimited
        }
    }

    func formattedTime(for stone: Stone) -> String {
        let value = stone == .black ? blackTime : whiteTime
        guard let value else { return "∞" }
        let seconds = max(0, Int(ceil(value)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func timeFraction(for stone: Stone) -> Double {
        guard let maximum = core.clock.displayMaximum(for: stone), maximum > 0,
              let remaining = stone == .black ? blackTime : whiteTime else { return 1 }
        return min(1, max(0, remaining / maximum))
    }

    func isTimeLow(for stone: Stone) -> Bool {
        guard let remaining = stone == .black ? blackTime : whiteTime else { return false }
        return remaining <= 10
    }

    func stats(forBottomPlayer bottom: Bool) -> LocalPlayerStats {
        bottom ? sessionScore.bottom : sessionScore.top
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
}

struct LocalMatchView: View {
    let language: AppLanguage
    @StateObject private var game = LocalMatchViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showGameMenu = false
    @State private var showResignConfirmation = false
    @State private var resultReady = false
    @State private var celebrationStart: Date?

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
        .task(id: game.completedRecord?.id) {
            resultReady = false
            celebrationStart = nil
            guard let record = game.completedRecord else { return }
            let pattern = VictoryPattern(record: record)
            if !pattern.isEmpty {
                celebrationStart = Date()
                if !reduceMotion {
                    do { try await Task.sleep(for: .seconds(pattern.duration + 0.2)) } catch { return }
                }
            }
            guard !Task.isCancelled, game.completedRecord?.id == record.id else { return }
            resultReady = true
        }
        .confirmationDialog(
            L10n.choose("대국 메뉴", "Game menu", language),
            isPresented: $showGameMenu,
            titleVisibility: .visible
        ) {
            Button(L10n.choose("기권", "Resign", language), role: .destructive) {
                showResignConfirmation = true
            }
            Button(L10n.choose("무르기", "Undo", language)) { game.undoLastMove() }
                .disabled(!game.canUndo)
            Button(L10n.text("backHome", language)) {
                game.resetSession()
                dismiss()
            }
            Button(L10n.choose("닫기", "Close", language), role: .cancel) {}
        }
        .alert(
            L10n.choose("기권하시겠습니까?", "Resign this game?", language),
            isPresented: $showResignConfirmation
        ) {
            Button(L10n.choose("기권", "Resign", language), role: .destructive) {
                game.resignCurrentPlayer()
            }
            Button(L10n.text("cancel", language), role: .cancel) {}
        } message: {
            Text(L10n.choose("현재 차례의 플레이어가 패배합니다.", "The player whose turn it is will lose.", language))
        }
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
            Button(L10n.text("backHome", language)) {
                game.resetSession()
                dismiss()
            }
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
                    QuietIconButton(title: L10n.text("backHome", language), symbol: "xmark") {
                        game.resetSession()
                        dismiss()
                    }
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

                        Text(L10n.choose("첫 대국의 흑 플레이어를 선택하세요. 다시 대결하면 위·아래 플레이어의 색이 서로 바뀝니다.",
                                         "Choose who plays Black in the first game. A rematch swaps the top and bottom players' colours.",
                                         language))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondary)

                        HStack(spacing: 12) {
                            colourChoice(bottomIsBlack: true)
                            colourChoice(bottomIsBlack: false)
                        }

                        Divider()

                        Text(L10n.choose("시간 설정", "Time control", language))
                            .font(.subheadline.bold())
                        Picker(L10n.choose("시간 설정", "Time control", language), selection: $game.timePreset) {
                            ForEach(LocalTimePreset.allCases) { preset in
                                Text(presetName(preset)).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("local.timePreset")

                        if game.timePreset == .custom {
                            customClockEditor(
                                title: L10n.choose("아래쪽 플레이어", "Bottom player", language),
                                unlimited: $game.bottomCustomUnlimited,
                                seconds: $game.bottomCustomSeconds,
                                increment: $game.bottomCustomIncrement,
                                prefix: "bottom"
                            )
                            customClockEditor(
                                title: L10n.choose("위쪽 플레이어", "Top player", language),
                                unlimited: $game.topCustomUnlimited,
                                seconds: $game.topCustomSeconds,
                                increment: $game.topCustomIncrement,
                                prefix: "top"
                            )
                        } else {
                            Text(presetDescription(game.timePreset))
                                .font(.caption)
                                .foregroundStyle(theme.secondary)
                        }

                        Button { game.startGame() } label: {
                            HStack {
                                Spacer()
                                Text(L10n.choose("혼자 두기 시작", "Start Local Play", language))
                                Spacer()
                                Image(systemName: "arrow.up")
                            }
                        }
                        .buttonStyle(GomokuButtonStyle())
                        .accessibilityIdentifier("local.start")
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func colourChoice(bottomIsBlack: Bool) -> some View {
        let selected = game.selectedBottomStone == (bottomIsBlack ? .black : .white)
        return Button {
            game.selectedBottomStone = bottomIsBlack ? .black : .white
        } label: {
            VStack(spacing: 9) {
                StoneDisc(stone: .black, size: 30)
                Text(bottomIsBlack
                     ? L10n.choose("아래쪽이 흑", "Bottom is Black", language)
                     : L10n.choose("위쪽이 흑", "Top is Black", language))
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(selected ? theme.accentWash : theme.inset, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(bottomIsBlack ? "local.black.bottom" : "local.black.top")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func customClockEditor(
        title: String,
        unlimited: Binding<Bool>,
        seconds: Binding<Double>,
        increment: Binding<Double>,
        prefix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Toggle(L10n.text("unlimited", language), isOn: unlimited)
                    .labelsHidden()
                    .accessibilityLabel(title + " " + L10n.text("unlimited", language))
                    .accessibilityIdentifier("local.\(prefix).unlimited")
            }
            if !unlimited.wrappedValue {
                Stepper(value: seconds, in: 15...7200, step: 15) {
                    HStack {
                        Text(L10n.choose("시작 시간", "Starting time", language))
                        Spacer()
                        Text(formatTime(seconds.wrappedValue)).monospacedDigit().bold()
                    }
                }
                .accessibilityIdentifier("local.\(prefix).initial")
                Stepper(value: increment, in: 0...60, step: 1) {
                    HStack {
                        Text(L10n.choose("착수 후 추가", "Increment", language))
                        Spacer()
                        Text("+\(Int(increment.wrappedValue))\(L10n.choose("초", "s", language))")
                            .monospacedDigit().bold()
                    }
                }
                .accessibilityIdentifier("local.\(prefix).increment")
            }
        }
        .padding(14)
        .background(theme.inset.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }

    private func matchScreen(size: CGSize) -> some View {
        let boardSide = min(size.width - 28, size.height - 330)
        return VStack(spacing: 10) {
            playerPanel(stone: game.topStone, bottomPlayer: false,
                        positionText: L10n.choose("위쪽 플레이어", "Top player", language))
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

                if let record = game.completedRecord, let start = celebrationStart {
                    let pattern = VictoryPattern(record: record)
                    if !pattern.isEmpty {
                        WinningCelebration(pattern: pattern, startedAt: start, language: language)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("local.liveVictory")
                    }
                }
            }
            .frame(maxWidth: .infinity)

            playerPanel(stone: game.bottomStone, bottomPlayer: true,
                        positionText: L10n.choose("아래쪽 플레이어", "Bottom player", language))
        }
        .overlay(alignment: .topTrailing) {
            Button { showGameMenu = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2.bold())
                    .foregroundStyle(theme.ink)
                    .padding(10)
                    .background(theme.surface.opacity(0.92), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.choose("대국 메뉴", "Game menu", language))
            .accessibilityIdentifier("local.menu")
            .padding(8)
        }
        .overlay {
            if resultReady, game.result != nil {
                VStack(spacing: 12) {
                    Text(game.resultTitle(language: language))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    HStack(spacing: 10) {
                        Button(L10n.choose("다시 대결", "Rematch", language)) {
                            resultReady = false
                            game.rematch()
                        }
                        .buttonStyle(GomokuButtonStyle())
                        .accessibilityIdentifier("local.rematch")
                        Button(L10n.choose("나가기", "Exit", language)) {
                            game.resetSession()
                            dismiss()
                        }
                        .buttonStyle(GomokuButtonStyle(primary: false))
                        .accessibilityIdentifier("local.exit")
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

    private func playerPanel(stone: Stone, bottomPlayer: Bool, positionText: String) -> some View {
        let active = game.currentTurn == stone && game.result == nil
        let canPlace = active && game.selectedMove != nil && !game.isValidatingMove
        let stats = game.stats(forBottomPlayer: bottomPlayer)
        return SurfaceCard {
            HStack(spacing: 12) {
                StoneDisc(stone: stone, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(positionText).font(.caption).foregroundStyle(theme.secondary)
                    Text(L10n.stone(stone, language: language)).font(.headline)
                    Text(statsText(stats))
                        .font(.caption2)
                        .foregroundStyle(theme.secondary)
                        .accessibilityIdentifier(bottomPlayer ? "local.stats.bottom" : "local.stats.top")
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
                        .frame(minWidth: 70)
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

    private func statsText(_ stats: LocalPlayerStats) -> String {
        let rate = stats.wins + stats.losses == 0 ? "—" : "\(Int((stats.winRate * 100).rounded()))%"
        return L10n.choose("\(stats.wins)승 \(stats.losses)패 · 승률 \(rate)",
                           "\(stats.wins)W \(stats.losses)L · \(rate)", language)
    }

    private func presetName(_ preset: LocalTimePreset) -> String {
        switch preset {
        case .unlimited: return L10n.text("unlimited", language)
        case .blitz: return L10n.choose("Blitz", "Blitz", language)
        case .fast: return L10n.choose("Fast", "Fast", language)
        case .slow: return L10n.choose("Slow", "Slow", language)
        case .custom: return L10n.choose("직접", "Custom", language)
        }
    }

    private func presetDescription(_ preset: LocalTimePreset) -> String {
        switch preset {
        case .unlimited: return L10n.text("noClock", language)
        case .blitz: return L10n.choose("각 플레이어 0:45 · 증분 없음", "0:45 per player · no increment", language)
        case .fast: return L10n.choose("각 플레이어 0:30 + 5초 · 최대 0:45", "0:30 + 5s per player · 0:45 cap", language)
        case .slow: return L10n.choose("각 플레이어 1:00 + 10초 · 최대 1:30", "1:00 + 10s per player · 1:30 cap", language)
        case .custom: return ""
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
