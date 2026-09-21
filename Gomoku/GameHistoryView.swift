import SwiftUI

struct GameHistoryView: View {
    let records: [GameRecord]
    let language: AppLanguage
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var showDeleteConfirmation = false
    private var theme: GomokuTheme { GomokuTheme(scheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("historyTitle", language))
                        .font(.system(.largeTitle, design: .serif, weight: .medium))
                    Text(L10n.text("historySubtitle", language))
                        .font(.subheadline).foregroundStyle(theme.secondary)
                }
                if records.isEmpty {
                    SurfaceCard {
                        VStack(spacing: 20) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 42, weight: .ultraLight))
                                .foregroundStyle(theme.accent)
                            Text(L10n.text("noRecords", language)).font(.headline)
                            Text(L10n.text("historyEmptyHelp", language))
                                .font(.subheadline).foregroundStyle(theme.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                    }
                } else {
                    HStack(spacing: 8) {
                        SmallBadge(text: "\(records.count) \(L10n.text("gamesCount", language))",
                                   symbol: "square.stack")
                        SmallBadge(text: L10n.text("savedOnDevice", language), symbol: "iphone")
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            NavigationLink {
                                ReplayView(record: record, language: language)
                            } label: {
                                recordRow(record)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("record.\(record.id)")
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background { GameBackdrop() }
        .foregroundStyle(theme.ink)
        .tint(theme.accent)
        .navigationTitle(L10n.text("records", language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(scheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.text("close", language)) { dismiss() }
                    .accessibilityIdentifier("closeHistory")
            }
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(L10n.text("deleteAll", language))
                }
            }
        }
        .confirmationDialog(L10n.text("confirmDeleteAll", language),
                            isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.text("delete", language), role: .destructive) { onClear() }
            Button(L10n.text("cancel", language), role: .cancel) {}
        }
    }

    private func recordRow(_ record: GameRecord) -> some View {
        SurfaceCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 7) {
                    Image(systemName: record.result.playerWon(playerStone: record.playerStone)
                          ? "laurel.leading" : record.result == .draw ? "equal" : "flag")
                        .font(.title2)
                    Text(L10n.recordResult(record, language: language))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(record.result.playerWon(playerStone: record.playerStone) ? theme.accent : theme.secondary)
                .frame(width: 46)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.formattedDate(record.playedAt, language: language))
                        .font(.subheadline.weight(.semibold))
                    Text(
                        "\(L10n.stone(record.playerStone, language: language)) · " +
                        L10n.difficulty(record.difficulty, language: language, adaptiveSkill: record.adaptiveSkill)
                    )
                    .font(.caption).foregroundStyle(theme.secondary)
                    Text("\(record.moves.count) \(L10n.text("moves", language)) · " +
                         L10n.recordClock(record, language: language))
                        .font(.caption).foregroundStyle(theme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right").font(.subheadline).foregroundStyle(theme.accent)
            }
        }
    }
}

struct ReplayView: View {
    let record: GameRecord
    let language: AppLanguage
    @StateObject private var playback: ReplayPlayback
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    private var theme: GomokuTheme { GomokuTheme(scheme) }

    init(record: GameRecord, language: AppLanguage) {
        self.record = record; self.language = language
        _playback = StateObject(wrappedValue: ReplayPlayback(record: record))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.recordResult(record, language: language)).font(.title2.bold())
                            Text(L10n.formattedDate(record.playedAt, language: language))
                                .font(.caption).foregroundStyle(theme.secondary)
                        }
                        Spacer()
                        Text(L10n.difficulty(record.difficulty, language: language, adaptiveSkill: record.adaptiveSkill))
                            .font(.caption).foregroundStyle(theme.secondary)
                    }
                    NumberedReplay(playback: playback, language: language,
                                   boardSize: max(240, min(600, geometry.size.width - 40, geometry.size.height - 310)),
                                   idPrefix: "replay")
                    if record.moves.isEmpty {
                        Text(L10n.choose("착수 전에 종료된 대국입니다.", "This game ended before the first move.", language))
                            .font(.subheadline).foregroundStyle(theme.secondary)
                    }
                }
                .padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
        }
        .background { GameBackdrop() }.foregroundStyle(theme.ink).tint(theme.accent)
        .navigationTitle(L10n.text("replay", language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(scheme, for: .navigationBar)
        .onAppear { playback.activate(autoplay: false, reduceMotion: true) }
        .onDisappear { playback.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
    }
}
