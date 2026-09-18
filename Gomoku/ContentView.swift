import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameViewModel()

    @AppStorage("gomoku.language")
    private var languageRaw = AppLanguage.korean.rawValue

    @AppStorage("gomoku.appearance")
    private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var showHistory = false

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .korean
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            Group {
                if game.isGameActive {
                    gameScreen
                } else {
                    setupScreen
                }
            }
            .navigationTitle(L10n.text("appTitle", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Label(
                            L10n.text("history", language),
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                }
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                GameHistoryView(
                    records: game.records,
                    language: language,
                    onClear: game.clearRecords
                )
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }

    private var setupScreen: some View {
        GeometryReader { geometry in
            ScrollView {
                Group {
                    if geometry.size.width >= 900 {
                        HStack(alignment: .top, spacing: 28) {
                            hero
                                .frame(maxWidth: 320)
                                .padding(.top, 48)

                            VStack(spacing: 18) {
                                gameSettings
                                appSettings
                                startButton
                            }
                            .frame(maxWidth: 620)
                        }
                        .padding(.horizontal, 36)
                    } else {
                        VStack(spacing: 22) {
                            hero
                            gameSettings
                            appSettings
                            startButton
                        }
                        .frame(maxWidth: 680)
                        .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 64, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(L10n.text("appTitle", language))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text(L10n.text("subtitle", language))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var gameSettings: some View {
        VStack(spacing: 16) {
            settingCard(title: L10n.text("yourStone", language)) {
                Picker(
                    L10n.text("yourStone", language),
                    selection: $game.playerStone
                ) {
                    Text("● \(L10n.text("black", language))")
                        .tag(Stone.black)
                    Text("○ \(L10n.text("white", language))")
                        .tag(Stone.white)
                }
                .pickerStyle(.segmented)
            }

            settingCard(title: L10n.text("aiDifficulty", language)) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(
                        L10n.text("aiDifficulty", language),
                        selection: $game.difficulty
                    ) {
                        ForEach(AIDifficulty.allCases) { level in
                            Text(L10n.difficulty(level, language: language))
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)

                    if game.difficulty == .adaptive {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L10n.text("adaptiveCurrent", language))
                                Spacer()
                                Text("\(game.adaptiveSkill)/100")
                                    .font(.body.monospacedDigit().bold())
                            }

                            ProgressView(
                                value: Double(game.adaptiveSkill),
                                total: 100
                            )

                            Text(L10n.text("adaptiveDescription", language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            settingCard(title: L10n.text("timeControl", language)) {
                VStack(spacing: 10) {
                    ForEach(TimeControl.allCases) { control in
                        Button {
                            game.timeControl = control
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        L10n.timeControl(
                                            control,
                                            language: language
                                        )
                                    )
                                    .font(.headline)

                                    Text(
                                        L10n.timeSubtitle(
                                            control,
                                            language: language
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if game.timeControl == control {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        Color.secondary.opacity(
                                            game.timeControl == control
                                                ? 0.15
                                                : 0.07
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var appSettings: some View {
        VStack(spacing: 16) {
            settingCard(title: L10n.text("appearance", language)) {
                Picker(
                    L10n.text("appearance", language),
                    selection: Binding(
                        get: { appearanceRaw },
                        set: { appearanceRaw = $0 }
                    )
                ) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(L10n.appearance(mode, language: language))
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            settingCard(title: L10n.text("language", language)) {
                Picker(
                    L10n.text("language", language),
                    selection: Binding(
                        get: { languageRaw },
                        set: { languageRaw = $0 }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.displayName)
                            .tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                showHistory = true
            } label: {
                Label(
                    "\(L10n.text("history", language)) · \(game.records.count)",
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
    }

    private var startButton: some View {
        Button {
            game.startGame()
        } label: {
            Label(
                L10n.text("startGame", language),
                systemImage: "play.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var gameScreen: some View {
        GeometryReader { geometry in
            let wideLayout =
                geometry.size.width > 880 &&
                geometry.size.width > geometry.size.height

            Group {
                if wideLayout {
                    HStack(spacing: 22) {
                        BoardView(
                            board: game.board,
                            lastMove: game.lastMove,
                            selectedMove: game.selectedMove,
                            previewStone: game.playerStone,
                            enabled:
                                game.currentTurn == game.playerStone &&
                                game.result == nil &&
                                !game.isThinking
                        ) { move in
                            game.selectMove(move)
                        }
                        .frame(
                            maxWidth: min(
                                geometry.size.height - 28,
                                geometry.size.width * 0.66
                            )
                        )

                        gameSidebar
                            .frame(width: 290)
                    }
                    .padding(14)
                } else {
                    VStack(spacing: 12) {
                        topStatusBar

                        BoardView(
                            board: game.board,
                            lastMove: game.lastMove,
                            selectedMove: game.selectedMove,
                            previewStone: game.playerStone,
                            enabled:
                                game.currentTurn == game.playerStone &&
                                game.result == nil &&
                                !game.isThinking
                        ) { move in
                            game.selectMove(move)
                        }
                        .frame(maxHeight: geometry.size.height * 0.66)
                        .padding(.horizontal, 8)

                        compactControls
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if game.result != nil {
                resultOverlay
            }
        }
    }

    private var topStatusBar: some View {
        HStack(spacing: 12) {
            playerClock(stone: .black)

            Spacer()

            VStack(spacing: 3) {
                Text(game.turnTitle(language: language))
                    .font(.headline)

                Text(
                    L10n.difficulty(
                        game.difficulty,
                        language: language,
                        adaptiveSkill:
                            game.difficulty == .adaptive
                                ? game.adaptiveSkill
                                : nil
                    ) + " AI"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            playerClock(stone: .white)
        }
        .padding(.horizontal)
    }

    private var gameSidebar: some View {
        VStack(spacing: 16) {
            topStatusBar
                .padding(.horizontal, 0)

            Spacer(minLength: 4)

            selectionPanel

            Spacer(minLength: 4)

            Button {
                showHistory = true
            } label: {
                Label(
                    L10n.text("history", language),
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack {
                Button(L10n.text("setup", language)) {
                    game.backToSetup()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L10n.text("newGame", language)) {
                    game.startGame()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var compactControls: some View {
        VStack(spacing: 10) {
            selectionPanel

            HStack {
                Button(L10n.text("setup", language)) {
                    game.backToSetup()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L10n.text("newGame", language)) {
                    game.startGame()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }

    private var selectionPanel: some View {
        VStack(spacing: 10) {
            if let notice = game.notice {
                Text(L10n.notice(notice, language: language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else if let selected = game.selectedMove {
                Text(
                    "\(L10n.text("selected", language)): " +
                    selected.coordinate
                )
                .font(.headline.monospaced())
            } else {
                Text(L10n.text("tapToPreview", language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button {
                    game.cancelSelection()
                } label: {
                    Label(
                        L10n.text("cancelSelection", language),
                        systemImage: "xmark"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(game.selectedMove == nil)

                Button {
                    game.confirmSelectedMove()
                } label: {
                    Label(
                        L10n.text("place", language),
                        systemImage: "checkmark"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    game.selectedMove == nil ||
                    game.currentTurn != game.playerStone ||
                    game.result != nil ||
                    game.isThinking
                )
            }
        }
        .padding(.horizontal)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(game.resultTitle(language: language))
                    .font(.largeTitle.bold())

                if game.difficulty == .adaptive {
                    VStack(spacing: 5) {
                        Text(L10n.text("adaptiveAdjusted", language))
                            .foregroundStyle(.secondary)

                        Text("\(game.adaptiveSkill)/100")
                            .font(.title2.monospacedDigit().bold())
                    }
                }

                HStack {
                    Button(L10n.text("setup", language)) {
                        game.backToSetup()
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.text("playAgain", language)) {
                        game.startGame()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 22)
            )
            .padding()
        }
    }

    private func playerClock(stone: Stone) -> some View {
        let isPlayer = stone == game.playerStone
        let active = game.currentTurn == stone && game.result == nil

        return VStack(
            alignment: stone == .black ? .leading : .trailing,
            spacing: 3
        ) {
            HStack(spacing: 5) {
                Circle()
                    .fill(stone == .black ? Color.black : Color.white)
                    .overlay {
                        if stone == .white {
                            Circle()
                                .stroke(.secondary, lineWidth: 1)
                        }
                    }
                    .frame(width: 14, height: 14)

                Text(
                    isPlayer
                        ? L10n.text("you", language)
                        : L10n.text("ai", language)
                )
                .font(.caption.weight(.semibold))
            }

            Text(game.formattedTime(for: stone))
                .font(
                    .system(
                        .title3,
                        design: .monospaced,
                        weight: active ? .bold : .regular
                    )
                )
        }
        .frame(
            minWidth: 76,
            alignment: stone == .black ? .leading : .trailing
        )
    }

    private func settingCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(16)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}
