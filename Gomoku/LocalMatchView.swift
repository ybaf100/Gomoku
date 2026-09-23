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
    @Published private(set) var series = LocalSeriesScore()
    @Published private(set) var bottomStone: Stone = .black
    @Published var selectedBottomStone: Stone = .black
    @Published var selectedFormat: LocalMatchFormat = .single
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
    func canUndo(forBottomPlayer bottom: Bool) -> Bool {
        canUndo && core.moves.last?.stone == (bottom ? bottomStone : topStone)
    }
    var showsForbiddenMoves: Bool {
        isGameActive && result == nil && currentTurn == .black
    }

    private var core = LocalMatchCore()
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

    func startGame() {
        stopTasks()
        series = LocalSeriesScore(format: selectedFormat, firstBottomStone: selectedBottomStone)
        activeSetup = configuredClockSetup
        beginRound()
    }

    func nextGame() {
        guard isGameActive, result != nil, series.advance() else { return }
        beginRound()
    }

    func rematch() {
        guard isGameActive, result != nil, series.isComplete else { return }
        series.restart()
        beginRound()
    }

    private func beginRound() {
        stopTasks()
        bottomStone = series.currentBottomStone
        core.start(setup: activeSetup, bottomStone: bottomStone, now: clockNow())
        completedRecord = nil
        notice = nil
        didRecordResult = false
        isGameActive = true
        publishCore()
        startClock()
        refreshForbiddenMoves()
    }

    func resetSession() {
        stopTasks()
        sessionScore.reset()
        series = LocalSeriesScore()
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

    func resign(bottomPlayer: Bool) {
        guard isGameActive, core.resign(bottomPlayer ? bottomStone : topStone) != nil else { return }
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
        series.record(result)
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
        core.isTimeWarning(for: stone)
    }

    var hasTimeWarning: Bool { isTimeLow(for: currentTurn) }

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
    @State private var resigningBottomPlayer = false
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
                } else {
                    // Show the completed, static gold pattern before presenting the result.
                    do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                }
            }
            guard !Task.isCancelled, game.completedRecord?.id == record.id else { return }
            resultReady = true
        }
        .alert(resignationTitle, isPresented: $showResignConfirmation) {
            Button(L10n.choose("기권", "Resign", language), role: .destructive) {
                game.resign(bottomPlayer: resigningBottomPlayer)
            }
            Button(L10n.text("cancel", language), role: .cancel) {}
        } message: {
            Text(resigningBottomPlayer
                 ? L10n.choose("위쪽 플레이어의 승리로 기록됩니다.", "The top player wins.", language)
                 : L10n.choose("아래쪽 플레이어의 승리로 기록됩니다.", "The bottom player wins.", language))
        }
    }

    private var resignationTitle: String {
        resigningBottomPlayer
            ? L10n.choose("아래쪽 플레이어가 기권할까요?", "Bottom player resigns?", language)
            : L10n.choose("위쪽 플레이어가 기권할까요?", "Top player resigns?", language)
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

                        Text(L10n.choose("누가 흑을 둘까요?", "Who plays Black?", language))
                            .font(.headline)
                        Text(L10n.choose("흑은 먼저 둡니다. 다음 판마다 위·아래 플레이어의 돌 색이 서로 바뀝니다.",
                                         "Black moves first. The top and bottom players swap colours after each game.",
                                         language))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondary)

                        HStack(spacing: 12) {
                            colourChoice(bottomIsBlack: true)
                            colourChoice(bottomIsBlack: false)
                        }

                        Divider()

                        Text(L10n.choose("매치 형식", "Match format", language))
                            .font(.subheadline.bold())
                        HStack(spacing: 8) {
                            ForEach(LocalMatchFormat.allCases) { format in
                                formatChoice(format)
                            }
                        }
                        Text(formatDescription(game.selectedFormat))
                            .font(.caption)
                            .foregroundStyle(theme.secondary)

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
                            Text(L10n.choose("플레이어마다 서로 다른 시간을 사용할 수 있습니다.",
                                             "Each player can use a different clock.", language))
                                .font(.caption).foregroundStyle(theme.secondary)
                            customClockEditor(
                                title: L10n.choose("아래쪽 플레이어", "Bottom player", language),
                                stone: game.selectedBottomStone,
                                unlimited: $game.bottomCustomUnlimited,
                                seconds: $game.bottomCustomSeconds,
                                increment: $game.bottomCustomIncrement,
                                prefix: "bottom"
                            )
                            customClockEditor(
                                title: L10n.choose("위쪽 플레이어", "Top player", language),
                                stone: game.selectedBottomStone.opponent,
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(bottomIsBlack
                         ? L10n.choose("아래쪽이 흑", "Bottom is Black", language)
                         : L10n.choose("위쪽이 흑", "Top is Black", language))
                        .font(.subheadline.bold())
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? theme.accent : theme.secondary)
                }
                seatPreview(bottom: false, stone: bottomIsBlack ? .white : .black)
                Divider()
                seatPreview(bottom: true, stone: bottomIsBlack ? .black : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(selected ? theme.accentWash : theme.inset, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(bottomIsBlack ? "local.black.bottom" : "local.black.top")
        .accessibilityLabel(bottomIsBlack
            ? L10n.choose("아래쪽이 흑, 위쪽 플레이어 백, 아래쪽 플레이어 흑 선공",
                          "Bottom Black, top White, bottom Black moves first", language)
            : L10n.choose("위쪽이 흑, 위쪽 플레이어 흑 선공, 아래쪽 플레이어 백",
                          "Top Black, top Black moves first, bottom White", language))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func seatPreview(bottom: Bool, stone: Stone) -> some View {
        HStack(spacing: 6) {
            StoneDisc(stone: stone, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(bottom ? L10n.choose("아래쪽", "Bottom", language) : L10n.choose("위쪽", "Top", language))
                    .font(.caption2)
                Text(L10n.stone(stone, language: language) + (stone == .black ? L10n.choose(" · 선공", " · first", language) : ""))
                    .font(.caption.bold())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func formatChoice(_ format: LocalMatchFormat) -> some View {
        let selected = game.selectedFormat == format
        return Button { game.selectedFormat = format } label: {
            Text(formatLabel(format))
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 3)
                .background(selected ? theme.accentWash : theme.inset, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("local.format.\(format.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func customClockEditor(
        title: String,
        stone: Stone,
        unlimited: Binding<Bool>,
        seconds: Binding<Double>,
        increment: Binding<Double>,
        prefix: String
    ) -> some View {
        let timed = !unlimited.wrappedValue
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    StoneDisc(stone: stone, size: 23)
                    Text(title + " · " + L10n.stone(stone, language: language)).font(.subheadline.bold())
                }
                Spacer()
                Toggle(L10n.choose("시간 제한 사용", "Use clock", language), isOn: Binding(
                    get: { !unlimited.wrappedValue }, set: { unlimited.wrappedValue = !$0 }
                ))
                    .labelsHidden()
                    .tint(theme.accent)
                    .accessibilityLabel(title + " " + L10n.choose("시간 제한 사용", "Use clock", language))
                    .accessibilityIdentifier("local.\(prefix).unlimited")
            }
            Text(timed ? L10n.choose("시간 제한 사용 · 0초가 되면 시간패합니다.", "Clock on · reaching zero loses the game.", language)
                       : L10n.choose("시간 제한 없음 · 제한 없이 둡니다.", "No clock · play without a time limit.", language))
                .font(.caption).foregroundStyle(timed ? theme.accent : theme.secondary)
            VStack(spacing: 8) {
                Stepper(value: seconds, in: 15...7200, step: 15) {
                    HStack {
                        Text(L10n.choose("시작 시간", "Starting time", language))
                        Spacer()
                        Text(formatTime(seconds.wrappedValue))
                            .font(.title3.bold()).monospacedDigit()
                    }
                }
                .accessibilityIdentifier("local.\(prefix).initial")
                Stepper(value: increment, in: 0...60, step: 1) {
                    HStack {
                        Text(L10n.choose("착수 후 추가", "Increment", language))
                        Spacer()
                        Text("+\(Int(increment.wrappedValue))\(L10n.choose("초", "s", language))")
                            .font(.title3.bold()).monospacedDigit()
                    }
                }
                .accessibilityIdentifier("local.\(prefix).increment")
            }
            .disabled(!timed)
            .opacity(timed ? 1 : 0.45)
        }
        .padding(14)
        .background(timed ? theme.accentWash : theme.inset, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(timed ? theme.accent : theme.border))
    }

    private func matchScreen(size: CGSize) -> some View {
        let boardSide = max(230, min(size.width - 20, size.height - 340))
        return ScrollView {
            VStack(spacing: 6) {
                playerPanel(stone: game.topStone, bottomPlayer: false)
                    .rotationEffect(.degrees(180))
                    .accessibilityValue("180°")
                confirmButton(stone: game.topStone, bottomPlayer: false)
                    .rotationEffect(.degrees(180))
                    .accessibilityValue("180°")

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
                .frame(width: boardSide, height: boardSide)
                .overlay {
                    // The overlay is attached to the exact board frame, never to the outer VStack.
                    if let record = game.completedRecord, let start = celebrationStart {
                        let pattern = VictoryPattern(record: record)
                        if !pattern.isEmpty {
                            WinningCelebration(pattern: pattern, startedAt: start, language: language)
                                .allowsHitTesting(false)
                                .accessibilityIdentifier("local.liveVictory")
                        }
                    }
                }
                .padding(3)
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(game.hasTimeWarning ? theme.danger : Color.clear, lineWidth: 2))
                .accessibilityIdentifier("local.board")

                playerPanel(stone: game.bottomStone, bottomPlayer: true)
                confirmButton(stone: game.bottomStone, bottomPlayer: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if resultReady, game.result != nil {
                VStack(spacing: 12) {
                    if game.series.isComplete {
                        Text(seriesVictoryTitle)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Text(game.resultTitle(language: language))
                        .font(.headline)
                    Text(seriesScoreText)
                        .font(.subheadline.monospacedDigit())
                    if !game.series.isComplete {
                        Text(nextColourText)
                            .font(.subheadline)
                    }
                    HStack(spacing: 10) {
                        Button(game.series.isComplete
                               ? L10n.choose("같은 조건으로 다시 대결", "Play another series", language)
                               : L10n.choose("다음 대국", "Next game", language)) {
                            resultReady = false
                            celebrationStart = nil
                            if game.series.isComplete { game.rematch() }
                            else { game.nextGame() }
                        }
                        .buttonStyle(GomokuButtonStyle())
                        .accessibilityIdentifier(game.series.isComplete ? "local.rematch" : "local.nextGame")
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
    }

    private func playerPanel(stone: Stone, bottomPlayer: Bool) -> some View {
        let active = game.currentTurn == stone && game.result == nil
        let stats = game.stats(forBottomPlayer: bottomPlayer)
        let low = game.isTimeLow(for: stone)
        let seat = bottomPlayer ? L10n.choose("아래쪽 플레이어", "Bottom player", language)
                                : L10n.choose("위쪽 플레이어", "Top player", language)
        return SurfaceCard {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        StoneDisc(stone: stone, size: 22)
                        Text(seat).font(.caption.bold())
                    }
                    Text(L10n.stone(stone, language: language) + " · " + (active ? L10n.text("place", language) : L10n.choose("대기", "Wait", language)))
                        .font(.caption)
                        .foregroundStyle(active ? theme.accent : theme.secondary)
                    Text(statsText(stats))
                        .font(.caption2)
                        .foregroundStyle(theme.secondary)
                        .accessibilityIdentifier(bottomPlayer ? "local.stats.bottom" : "local.stats.top")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 1) {
                    Text(formatLabel(game.series.format))
                    Text("\(game.series.gameNumber)\(L10n.choose("국", " game", language))")
                    Text(seriesScoreText).monospacedDigit()
                }
                .font(.caption2.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(bottomPlayer ? "local.series.bottom" : "local.series.top")
                Text(game.formattedTime(for: stone))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .monospacedDigit()
                    .foregroundStyle(low ? theme.danger : active ? theme.accent : theme.ink)
                    .padding(.horizontal, 5)
                    .background(low ? theme.danger.opacity(0.13) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier(bottomPlayer ? "local.timer.bottom" : "local.timer.top")
                Menu {
                    Button {
                        game.undoLastMove()
                        resultReady = false
                        celebrationStart = nil
                    } label: {
                        Label(L10n.choose("마지막 수 무르기", "Undo last move", language), systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!game.canUndo(forBottomPlayer: bottomPlayer))
                    .accessibilityIdentifier(bottomPlayer ? "local.menu.bottom.undo" : "local.menu.top.undo")
                    Button(role: .destructive) {
                        resigningBottomPlayer = bottomPlayer
                        showResignConfirmation = true
                    } label: {
                        Label(L10n.choose("기권", "Resign", language), systemImage: "flag.fill")
                    }
                    .accessibilityIdentifier(bottomPlayer ? "local.menu.bottom.resign" : "local.menu.top.resign")
                    Button {
                        game.resetSession()
                        dismiss()
                    } label: {
                        Label(L10n.text("backHome", language), systemImage: "house")
                    }
                    .accessibilityIdentifier(bottomPlayer ? "local.menu.bottom.home" : "local.menu.top.home")
                    Button(L10n.choose("닫기", "Close", language)) {}
                        .accessibilityIdentifier(bottomPlayer ? "local.menu.bottom.close" : "local.menu.top.close")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.bold())
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel(seat + " " + L10n.choose("메뉴", "menu", language))
                .accessibilityIdentifier(bottomPlayer ? "local.menu.bottom" : "local.menu.top")
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(low ? theme.danger : active ? theme.accent.opacity(0.75) : Color.clear, lineWidth: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(bottomPlayer ? "local.player.bottom" : "local.player.top")
    }

    private func confirmButton(stone: Stone, bottomPlayer: Bool) -> some View {
        let active = game.currentTurn == stone && game.result == nil
        return Button { game.confirmSelectedMove(for: stone) } label: {
            Text(game.isValidatingMove && active ? L10n.text("validatingMove", language)
                 : active ? L10n.text("place", language) : L10n.choose("대기", "Wait", language))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(GomokuButtonStyle(primary: active))
        .disabled(!active || game.selectedMove == nil || game.isValidatingMove)
        .accessibilityIdentifier(bottomPlayer ? "local.confirm.bottom" : "local.confirm.top")
    }

    private func statsText(_ stats: LocalPlayerStats) -> String {
        let rate = stats.wins + stats.losses == 0 ? "—" : "\(Int((stats.winRate * 100).rounded()))%"
        return L10n.choose("\(stats.wins)승 \(stats.losses)패 · 승률 \(rate)",
                           "\(stats.wins)W \(stats.losses)L · \(rate)", language)
    }

    private func formatLabel(_ format: LocalMatchFormat) -> String {
        switch format {
        case .single: return L10n.choose("단판", "Single", language)
        case .bestOfThree: return L10n.choose("Bo3 · 2승 선취", "Bo3 · first to 2", language)
        case .bestOfFive: return L10n.choose("Bo5 · 3승 선취", "Bo5 · first to 3", language)
        }
    }

    private func formatDescription(_ format: LocalMatchFormat) -> String {
        switch format {
        case .single: return L10n.choose("1승을 먼저 하면 종료됩니다.", "First win ends the match.", language)
        case .bestOfThree: return L10n.choose("2승을 먼저 달성한 플레이어가 최종 승리합니다.", "First player to two wins takes the series.", language)
        case .bestOfFive: return L10n.choose("3승을 먼저 달성한 플레이어가 최종 승리합니다.", "First player to three wins takes the series.", language)
        }
    }

    private var seriesScoreText: String {
        "\(game.series.topWins):\(game.series.bottomWins)"
    }

    private var nextColourText: String {
        let nextBottom = game.series.nextBottomStone
        return L10n.choose("다음 판: 위쪽 \(L10n.stone(nextBottom.opponent, language: language)) · 아래쪽 \(L10n.stone(nextBottom, language: language))",
                           "Next: top \(L10n.stone(nextBottom.opponent, language: language)) · bottom \(L10n.stone(nextBottom, language: language))", language)
    }

    private var seriesVictoryTitle: String {
        let winner = game.series.winningBottomPlayer == true
            ? L10n.choose("아래쪽 플레이어", "Bottom player", language)
            : L10n.choose("위쪽 플레이어", "Top player", language)
        return L10n.choose("\(formatLabel(game.series.format)) 승리 · \(winner)",
                           "\(formatLabel(game.series.format)) winner · \(winner)", language)
    }

    private func presetName(_ preset: LocalTimePreset) -> String {
        switch preset {
        case .unlimited: return L10n.text("unlimited", language)
        case .blitz: return L10n.choose("Blitz", "Blitz", language)
        case .fast: return L10n.choose("Fast", "Fast", language)
        case .slow: return L10n.choose("Slow", "Slow", language)
        case .custom: return L10n.choose("직접 설정", "Custom", language)
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
