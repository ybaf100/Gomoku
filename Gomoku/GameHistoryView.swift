import SwiftUI

struct GameHistoryView: View {
    let records: [GameRecord]
    let language: AppLanguage
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    L10n.text("noRecords", language),
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                List(records) { record in
                    NavigationLink {
                        ReplayView(record: record, language: language)
                    } label: {
                        recordRow(record)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(L10n.text("records", language))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.text("close", language)) {
                    dismiss()
                }
            }

            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        L10n.text("deleteAll", language),
                        role: .destructive
                    ) {
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            L10n.text("confirmDeleteAll", language),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("delete", language), role: .destructive) {
                onClear()
            }
            Button(L10n.text("cancel", language), role: .cancel) {}
        }
    }

    private func recordRow(_ record: GameRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(record.result.playerWon(playerStone: record.playerStone) ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12))
                    .frame(width: 46, height: 46)

                Text(L10n.recordResult(record, language: language))
                    .font(.caption.bold())
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.formattedDate(record.playedAt, language: language))
                        .font(.headline)

                    if let skill = record.adaptiveSkill {
                        Text("AI \(skill)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(
                    "\(L10n.stone(record.playerStone, language: language)) · " +
                    "\(L10n.difficulty(record.difficulty, language: language, adaptiveSkill: record.adaptiveSkill)) · " +
                    "\(L10n.timeControl(record.timeControl, language: language))"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("\(record.moves.count) \(L10n.text("moves", language))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReplayView: View {
    let record: GameRecord
    let language: AppLanguage

    @State private var ply = 0

    private var replayBoard: [[Stone]] {
        var board = Array(
            repeating: Array(repeating: Stone.empty, count: RenjuRules.boardSize),
            count: RenjuRules.boardSize
        )

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
            let wide = geometry.size.width > 760

            Group {
                if wide {
                    HStack(spacing: 24) {
                        board
                            .frame(maxWidth: geometry.size.height - 40)
                        replayControls
                            .frame(width: 300)
                    }
                } else {
                    VStack(spacing: 16) {
                        board
                        replayControls
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(L10n.text("replay", language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var board: some View {
        BoardView(
            board: replayBoard,
            lastMove: replayLastMove,
            selectedMove: nil,
            previewStone: .black,
            enabled: false
        ) { _ in }
    }

    private var replayControls: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(L10n.recordResult(record, language: language))
                    .font(.title2.bold())
                Text(L10n.formattedDate(record.playedAt, language: language))
                    .foregroundStyle(.secondary)
                Text("\(ply) / \(record.moves.count)")
                    .font(.title3.monospacedDigit())
            }

            if ply > 0 {
                let move = record.moves[ply - 1]
                HStack(spacing: 8) {
                    Circle()
                        .fill(move.stone == .black ? Color.black : Color.white)
                        .overlay {
                            if move.stone == .white {
                                Circle().stroke(.secondary, lineWidth: 1)
                            }
                        }
                        .frame(width: 16, height: 16)
                    Text(move.move.coordinate)
                        .font(.headline.monospaced())
                }
            }

            HStack {
                Button {
                    ply = 0
                } label: {
                    Label(L10n.text("first", language), systemImage: "backward.end.fill")
                }
                .disabled(ply == 0)

                Spacer()

                Button {
                    ply = max(0, ply - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(ply == 0)

                Button {
                    ply = min(record.moves.count, ply + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(ply == record.moves.count)

                Spacer()

                Button {
                    ply = record.moves.count
                } label: {
                    Label(L10n.text("last", language), systemImage: "forward.end.fill")
                }
                .disabled(ply == record.moves.count)
            }
            .buttonStyle(.bordered)

            Slider(
                value: Binding(
                    get: { Double(ply) },
                    set: { ply = Int($0.rounded()) }
                ),
                in: 0...Double(max(1, record.moves.count)),
                step: 1
            )
            .disabled(record.moves.isEmpty)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
