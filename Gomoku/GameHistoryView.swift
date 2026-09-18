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
                         L10n.timeControl(record.timeControl, language: language))
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
    @State private var ply = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    private var theme: GomokuTheme { GomokuTheme(scheme) }

    private var replayBoard: [[Stone]] {
        var board = Array(repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
                          count: RenjuRules.boardSize)
        for recorded in record.moves.prefix(ply) {
            board[recorded.move.row][recorded.move.column] = recorded.stone
        }
        return board
    }

    private var replayLastMove: Move? {
        guard ply > 0 else { return nil }
        return record.moves[ply - 1].move
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if geometry.size.width > 900 && !typeSize.isAccessibilitySize {
                    HStack(spacing: 24) {
                        board.frame(width: max(280, min(geometry.size.height - 40, geometry.size.width - 380)))
                        replayControls.frame(width: 300)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 22) {
                        board
                        replayControls
                    }
                    .padding(20)
                    .frame(maxWidth: 660)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background { GameBackdrop() }
        .foregroundStyle(theme.ink)
        .tint(theme.accent)
        .navigationTitle(L10n.text("replay", language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
    }

    private var board: some View {
        BoardView(board: replayBoard, lastMove: replayLastMove, selectedMove: nil,
                  previewStone: .black, enabled: false, language: language) { _ in }
    }

    private var replayControls: some View {
        SurfaceCard {
            VStack(spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.recordResult(record, language: language))
                            .font(.system(.title2, design: .serif, weight: .medium))
                        Text(L10n.formattedDate(record.playedAt, language: language))
                            .font(.caption).foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    if ply > 0 {
                        VStack(spacing: 6) {
                            StoneDisc(stone: record.moves[ply - 1].stone, size: 22)
                            Text(record.moves[ply - 1].move.coordinate).font(.caption.monospaced())
                        }
                    }
                }
                HStack {
                    Text(L10n.text("moveProgress", language)).foregroundStyle(theme.secondary)
                    Spacer()
                    Text("\(ply) / \(record.moves.count)")
                        .monospacedDigit()
                        .accessibilityIdentifier("replayProgress")
                }
                .font(.subheadline)
                Slider(
                    value: Binding(get: { Double(ply) }, set: { ply = min(record.moves.count, Int($0.rounded())) }),
                    in: 0...Double(max(1, record.moves.count)), step: 1
                )
                .disabled(record.moves.isEmpty)
                .accessibilityLabel(L10n.text("moveProgress", language))
                HStack(spacing: 10) {
                    replayButton("first", symbol: "backward.end.fill", disabled: ply == 0) { ply = 0 }
                    replayButton("previous", symbol: "chevron.left", disabled: ply == 0) { ply = max(0, ply - 1) }
                    replayButton("next", symbol: "chevron.right", disabled: ply >= record.moves.count) {
                        ply = min(record.moves.count, ply + 1)
                    }
                    replayButton("last", symbol: "forward.end.fill", disabled: ply >= record.moves.count) {
                        ply = record.moves.count
                    }
                }
            }
        }
    }

    private func replayButton(_ key: String, symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(GomokuButtonStyle(primary: false))
            .disabled(disabled)
            .accessibilityLabel(L10n.text(key, language))
            .accessibilityIdentifier("replay.\(key)")
    }
}
