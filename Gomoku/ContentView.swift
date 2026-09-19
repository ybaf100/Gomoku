import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameViewModel()
    @AppStorage("gomoku.language") private var languageRaw = AppLanguage.korean.rawValue
    @AppStorage("gomoku.appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var pendingAction: GameAction?
    @State private var showLeaveConfirmation = false

    private enum GameAction: String, Identifiable {
        case home, restart
        var id: String { rawValue }
    }

    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }
    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    private var theme: GomokuTheme { GomokuTheme(scheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                appHeader
                if game.isGameActive {
                    gameScreen
                } else {
                    setupScreen
                }
            }
            .background { GameBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
            .foregroundStyle(theme.ink)
        }
        .tint(theme.accent)
        .onAppear {
            #if DEBUG
            UITestSupport.prepareGameIfRequested(game)
            #endif
        }
        .background {
            WindowAppearance(mode: appearance)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                AppSettingsView(languageRaw: $languageRaw, appearanceRaw: $appearanceRaw)
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                GameHistoryView(records: game.records, language: language, onClear: game.clearRecords)
            }
        }
        .confirmationDialog(
            L10n.text("leaveGameTitle", language),
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text(pendingAction == .restart ? "newGame" : "backHome", language), role: .destructive) {
                let action = pendingAction
                pendingAction = nil
                if action == .restart { game.startGame() } else { game.backToSetup() }
            }
            .accessibilityIdentifier("confirmLeaveGame")
            Button(L10n.text("cancel", language), role: .cancel) { pendingAction = nil }
        } message: {
            Text(L10n.text("leaveGameMessage", language))
        }
    }

    private var appHeader: some View {
        HStack(spacing: 12) {
            if game.isGameActive {
                QuietIconButton(title: L10n.text("backHome", language), symbol: "arrow.left") {
                    if game.result == nil {
                        pendingAction = .home
                        showLeaveConfirmation = true
                    } else {
                        game.backToSetup()
                    }
                }
                .accessibilityIdentifier("backHome")
            } else {
                ZStack {
                    StoneDisc(stone: .white, size: 25).offset(x: 7, y: -4)
                    StoneDisc(stone: .black, size: 25).offset(x: -6, y: 5)
                }
                .frame(width: 42, height: 42)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("GOMOKU")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .tracking(2.5)
                Text(L10n.text(game.isGameActive ? "matchSubtitle" : "brandSubtitle", language))
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
            }
            Spacer(minLength: 4)
            QuietIconButton(title: L10n.text("history", language), symbol: "clock.arrow.circlepath") {
                showHistory = true
            }
            .accessibilityIdentifier("openHistory")
            QuietIconButton(title: L10n.text("appSettings", language), symbol: "slider.horizontal.3") {
                showSettings = true
            }
            .accessibilityIdentifier("openSettings")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: 1280)
        .frame(maxWidth: .infinity)
    }

    private var setupScreen: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900 && !typeSize.isAccessibilitySize
            ScrollView {
                Group {
                    if wide {
                        HStack(alignment: .center, spacing: 64) {
                            hero(wide: true).frame(maxWidth: 450)
                            setupControls.frame(maxWidth: 490)
                        }
                        .padding(.horizontal, 44)
                    } else {
                        VStack(spacing: 28) {
                            hero(wide: false)
                            setupControls
                        }
                        .frame(maxWidth: 570)
                        .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: 1160)
                .frame(maxWidth: .infinity)
                .padding(.top, wide ? 22 : 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func hero(wide: Bool) -> some View {
        VStack(alignment: wide ? .leading : .center, spacing: wide ? 22 : 12) {
            HStack(spacing: 7) {
                Circle().fill(theme.accent).frame(width: 6, height: 6)
                Text(L10n.text("quietPlay", language))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .tracking(language == .english ? 2 : 1)
                    .foregroundStyle(theme.accent)
            }
            Text(L10n.text(wide ? "heroTitle" : "heroTitleCompact", language))
                .font(.system(wide ? .largeTitle : .title, design: .serif, weight: .medium))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(wide ? .leading : .center)
            Text(L10n.text("heroBody", language))
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .lineSpacing(5)
                .multilineTextAlignment(wide ? .leading : .center)
            if wide {
                WelcomeArtwork()
                    .frame(maxWidth: 340)
                    .padding(.vertical, 6)
            }
            HStack(spacing: 8) {
                SmallBadge(text: "15 × 15", symbol: "square.grid.3x3")
                SmallBadge(text: L10n.text("renju", language))
                SmallBadge(text: L10n.text("offline", language), symbol: "leaf")
            }
        }
    }

    private var setupControls: some View {
        VStack(spacing: 16) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(L10n.text("newMatch", language))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Spacer()
                        Image(systemName: "sparkle").foregroundStyle(theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionCaption(number: "01", title: L10n.text("yourStone", language))
                        HStack(spacing: 10) {
                            stoneChoice(.black)
                            stoneChoice(.white)
                        }
                        SelectionTile(selected: game.stoneSelection == .random, action: { game.stoneSelection = .random }) {
                            HStack(spacing: 12) {
                                Image(systemName: "shuffle").font(.title3).frame(width: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.text("randomStone", language)).font(.subheadline.bold())
                                    Text(L10n.text(game.difficulty == .adaptive ? "alternatingStoneHelp" : "randomStoneHelp", language))
                                        .font(.caption)
                                }
                                Spacer(minLength: 0)
                                if game.stoneSelection == .random {
                                    Image(systemName: "checkmark.circle.fill").font(.caption)
                                }
                            }
                        }
                        .accessibilityIdentifier("stone.random")
                        if game.stoneSelection == .random && game.difficulty == .adaptive {
                            Text(L10n.text("nextStone", language) + " · " + L10n.stone(game.nextAdaptiveStone, language: language))
                                .font(.caption.weight(.semibold)).foregroundStyle(theme.accent)
                                .accessibilityIdentifier("nextStone")
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionCaption(number: "02", title: L10n.text("aiDifficulty", language))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                            ForEach(AIDifficulty.allCases) { level in
                                SelectionTile(selected: game.difficulty == level, action: { game.difficulty = level }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: difficultySymbol(level))
                                        Text(L10n.difficulty(level, language: language))
                                            .font(.subheadline.weight(.semibold))
                                        Spacer(minLength: 0)
                                        if game.difficulty == level {
                                            Image(systemName: "checkmark").font(.caption.bold())
                                        }
                                    }
                                }
                                .accessibilityIdentifier("difficulty.\(level.rawValue)")
                            }
                        }
                        if game.difficulty == .adaptive {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(L10n.text("adaptiveCurrent", language))
                                    Spacer()
                                    Text("\(game.adaptiveSkill) / 100").monospacedDigit()
                                }
                                .font(.caption.weight(.semibold))
                                ProgressView(value: Double(game.adaptiveSkill), total: 100).tint(theme.accent)
                                Text(L10n.text("adaptiveDescription", language))
                                    .font(.caption)
                                    .foregroundStyle(theme.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionCaption(number: "03", title: L10n.text("timeControl", language))
                        let columns = typeSize.isAccessibilitySize ? 1 : 3
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                            ForEach(TimeControl.allCases) { control in
                                SelectionTile(selected: game.timeControl == control, action: { game.timeControl = control }) {
                                    VStack(spacing: 6) {
                                        Text(control == .fast ? "0:30" : control == .slow ? "1:00" : "∞")
                                            .font(.system(.title3, design: .rounded, weight: .semibold))
                                            .monospacedDigit()
                                        Text(L10n.timeControl(control, language: language))
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .accessibilityIdentifier("time.\(control.rawValue)")
                            }
                        }
                        Text(L10n.timeSubtitle(game.timeControl, language: language))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .accessibilityIdentifier("clockRule")
                        Text(L10n.text(game.timeControl == .unlimited ? "noClock" : "timeRefillHelp", language))
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                    }

                    Button { game.startGame() } label: {
                        HStack {
                            Spacer()
                            Text(L10n.text("startGame", language))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(GomokuButtonStyle())
                    .accessibilityIdentifier("startGame")
                    Text(L10n.text("startHint", language))
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }

            Button { showSettings = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: appearance.symbol)
                    Text(L10n.text("appearance", language))
                    Spacer()
                    Text(L10n.appearance(appearance, language: language))
                    Image(systemName: "chevron.right").font(.caption.bold())
                }
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("appearanceShortcut")
        }
    }

    private func stoneChoice(_ stone: Stone) -> some View {
        let choice: StoneSelection = stone == .black ? .black : .white
        return SelectionTile(selected: game.stoneSelection == choice, action: { game.stoneSelection = choice }) {
            HStack(spacing: 12) {
                StoneDisc(stone: stone, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.stone(stone, language: language)).font(.subheadline.bold())
                    Text(L10n.text(stone == .black ? "firstMove" : "secondMove", language)).font(.caption)
                }
                Spacer(minLength: 0)
                if game.stoneSelection == choice {
                    Image(systemName: "checkmark.circle.fill").font(.caption)
                }
            }
        }
        .accessibilityIdentifier("stone.\(stone.rawValue)")
    }

    private func difficultySymbol(_ level: AIDifficulty) -> String {
        switch level {
        case .easy: return "leaf"
        case .normal: return "circle.lefthalf.filled"
        case .hard: return "flame"
        case .adaptive: return "sparkles"
        }
    }

    private var gameScreen: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900 && geometry.size.width > geometry.size.height && !typeSize.isAccessibilitySize
            if wide {
                ScrollView {
                    HStack(alignment: .center, spacing: 32) {
                        VStack(spacing: 18) {
                            boardSection
                            selectionPanel
                        }
                        .frame(width: max(280, min(geometry.size.height - 220, geometry.size.width - 390)))
                        VStack(spacing: 22) {
                            turnStatus
                            clocks
                            clockRuleCard
                            matchActions
                        }
                        .frame(width: 290)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height - 30)
                    .padding(15)
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        clocks
                        turnStatus
                        boardSection
                        matchActions
                    }
                    .frame(maxWidth: 650)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    selectionPanel
                        .frame(maxWidth: 650)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(theme.background)
                }
            }
        }
        .overlay {
            if game.result != nil { resultOverlay }
        }
    }

    private var clockRuleCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("timeReserve", language), systemImage: "arrow.clockwise")
                    .font(.headline)
                Text(L10n.timeSubtitle(game.timeControl, language: language))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.accent)
                Text(L10n.text(game.timeControl == .unlimited ? "noClock" : "timeRefillHelp", language))
                    .font(.caption).foregroundStyle(theme.secondary)
            }
        }
    }

    private var boardSection: some View {
        VStack(spacing: 12) {
            BoardView(
                board: game.board, lastMove: game.lastMove,
                selectedMove: game.selectedMove, previewStone: game.playerStone,
                enabled: game.currentTurn == game.playerStone && game.result == nil && !game.isThinking && !game.isValidatingMove,
                language: language,
                forbiddenMoves: game.showsForbiddenMoves ? game.forbiddenMoves : [:],
                onSelect: game.selectMove
            )
            HStack {
                Text("RENJU · 15 × 15").tracking(1.5)
                Spacer()
                Text(L10n.difficulty(game.difficulty, language: language,
                                     adaptiveSkill: game.difficulty == .adaptive ? game.adaptiveSkill : nil))
            }
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(theme.secondary)
            .padding(.horizontal, 8)
            if game.showsForbiddenMoves && !game.forbiddenMoves.isEmpty {
                Text(L10n.text("forbiddenLegend", language))
                    .font(.caption).foregroundStyle(theme.danger)
                    .accessibilityIdentifier("forbiddenLegend")
            }
        }
    }

    private var clocks: some View {
        HStack(spacing: 12) {
            playerClock(stone: .black)
            playerClock(stone: .white)
        }
    }

    private func playerClock(stone: Stone) -> some View {
        let active = game.currentTurn == stone && game.result == nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                StoneDisc(stone: stone, size: 18)
                Text(L10n.text(stone == game.playerStone ? "you" : "ai", language))
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("playerLabel.\(stone.rawValue)")
                Spacer(minLength: 2)
                if active {
                    Image(systemName: "smallcircle.filled.circle")
                        .foregroundStyle(theme.accent)
                        .font(.caption)
                        .accessibilityLabel(L10n.text("activeTurn", language))
                }
            }
            Text(game.formattedTime(for: stone))
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(game.isTimeLow(for: stone) ? theme.danger : active ? theme.accent : theme.ink)
                .accessibilityIdentifier("clock.\(stone.rawValue)")
            GeometryReader { geometry in
                Capsule().fill(theme.border.opacity(0.5))
                    .overlay(alignment: .leading) {
                        Capsule().fill(game.isTimeLow(for: stone) ? theme.danger : theme.accent)
                            .frame(width: geometry.size.width * game.timeFraction(for: stone))
                    }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? theme.accentWash : theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(active ? theme.accent.opacity(0.6) : theme.border, lineWidth: 1)
        }
    }

    private var turnStatus: some View {
        HStack(spacing: 10) {
            if game.isThinking || game.isValidatingMove {
                ProgressView().tint(theme.accent)
            } else {
                Image(systemName: game.result == nil ? "circle.dotted.circle.fill" : "checkmark.circle")
                    .foregroundStyle(theme.accent)
            }
            Text(game.turnTitle(language: language))
                .font(.system(.headline, design: .rounded))
                .accessibilityIdentifier("turnStatus")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var selectionPanel: some View {
        let stone = game.currentTurn
        let canPlace = game.selectedMove != nil && stone == game.playerStone &&
            game.result == nil && !game.isThinking && !game.isValidatingMove
        let title = game.isValidatingMove ? "validatingMove" : game.isThinking ? "aiThinking" :
            game.selectedMove == nil ? "choosePoint" : "place"
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 6) {
                    StoneDisc(stone: stone, size: 14)
                    Text(L10n.text(stone == game.playerStone ? "you" : "ai", language))
                }
                .font(.caption.weight(.semibold))
                if let selected = game.selectedMove {
                    Text(selected.coordinate).font(.caption.monospaced().bold())
                        .accessibilityIdentifier("selectedCoordinate")
                    Button { game.cancelSelection() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(minWidth: 44, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text("cancelSelection", language))
                    .disabled(game.isValidatingMove)
                }
                Spacer(minLength: 0)
                Text(L10n.text("remainingTime", language)).font(.caption)
                Text(game.formattedTime(for: stone))
                    .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(game.isTimeLow(for: stone) ? theme.danger : theme.ink)
            }
            .foregroundStyle(theme.secondary)
            ReserveMoveButton(
                title: L10n.text(title, language),
                coordinate: canPlace ? game.selectedMove?.coordinate : nil,
                fraction: game.timeFraction(for: stone), urgent: game.isTimeLow(for: stone),
                busy: game.isThinking || game.isValidatingMove, enabled: canPlace,
                accessibilityTitle: L10n.text("place", language),
                accessibilityTime: L10n.text("remainingTime", language) + " " + game.formattedTime(for: stone),
                action: game.confirmSelectedMove
            )
            if let notice = game.notice {
                Text(L10n.notice(notice, language: language))
                    .font(.caption).foregroundStyle(theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let clock = game.timeControl.clockConfiguration {
                HStack {
                    Label("+\(Int(clock.increment))s / " + L10n.text("perMove", language), systemImage: "arrow.clockwise")
                    Spacer()
                    Text(L10n.text("timeCap", language) + " \(Int(clock.ceiling))s")
                }
                .font(.caption.weight(.medium)).foregroundStyle(theme.secondary)
            } else {
                Text(L10n.text("noClock", language)).font(.caption).foregroundStyle(theme.secondary)
            }
        }
    }

    private var matchActions: some View {
        HStack {
            Button { showHistory = true } label: {
                Label(L10n.text("history", language), systemImage: "clock.arrow.circlepath")
            }
            Spacer()
            Button {
                pendingAction = .restart
                showLeaveConfirmation = true
            } label: {
                Label(L10n.text("newGame", language), systemImage: "arrow.counterclockwise")
            }
        }
        .font(.subheadline)
        .foregroundStyle(theme.secondary)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.horizontal, 8)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            ScrollView {
                SurfaceCard {
                    VStack(spacing: 22) {
                        Image(systemName: game.result?.playerWon(playerStone: game.playerStone) == true
                              ? "laurel.leading" : "flag.checkered")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(theme.accent)
                        Text(game.resultTitle(language: language))
                            .font(.system(.largeTitle, design: .serif, weight: .medium))
                            .multilineTextAlignment(.center)
                        Text(L10n.text("recordSaved", language))
                            .font(.subheadline).foregroundStyle(theme.secondary)
                        if game.difficulty == .adaptive {
                            VStack(spacing: 8) {
                                Text(L10n.text("adaptiveAdjusted", language)).font(.caption)
                                Text("\(game.adaptiveSkill) / 100")
                                    .font(.title2.monospacedDigit().bold())
                            }
                            .foregroundStyle(theme.accent)
                        }
                        Button { game.startGame() } label: {
                            Label(L10n.text("playAgain", language), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GomokuButtonStyle())
                        Button { game.backToSetup() } label: {
                            Text(L10n.text("backHome", language))
                        }
                        .buttonStyle(GomokuButtonStyle(primary: false))
                    }
                    .padding(8)
                }
                .frame(maxWidth: 420)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center)
        }
        .accessibilityAddTraits(.isModal)
    }
}
