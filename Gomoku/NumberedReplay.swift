import SwiftUI

struct NumberedReplay: View {
    @ObservedObject var playback: ReplayPlayback
    let language: AppLanguage
    let boardSize: CGFloat
    var idPrefix = "resultReplay"
    private var progressID: String { idPrefix == "replay" ? "replayProgress" : "resultReplayProgress" }

    var body: some View {
        VStack(spacing: 12) {
            BoardView(board: playback.position.board, lastMove: playback.position.last, selectedMove: nil,
                      previewStone: .black, enabled: false, language: language,
                      moveNumbers: playback.position.numbers,
                      winningLine: playback.ply == playback.record.moves.count ? playback.victory.stones : []) { _ in }
                .frame(width: boardSize, height: boardSize)
                .overlay {
                    if let start = playback.celebrationStart, !playback.victory.isEmpty {
                        WinningCelebration(pattern: playback.victory, startedAt: start, language: language)
                            .accessibilityIdentifier("\(idPrefix).victory")
                    }
                }
                .accessibilityIdentifier("numberedBoard")
            VStack(spacing: 8) {
                HStack {
                    Text(L10n.choose(playback.automatic ? "자동 타임랩스" : "착수 순서", playback.automatic ? "Timelapse" : "Move order", language))
                    Spacer()
                    Text("\(playback.ply) / \(playback.record.moves.count)").monospacedDigit().accessibilityIdentifier(progressID)
                }.font(.caption)
                Slider(value: Binding(get: { Double(playback.ply) }, set: { playback.seek(Int($0.rounded())) }),
                       in: 0...Double(max(1, playback.record.moves.count)), step: 1)
                    .disabled(playback.record.moves.isEmpty)
                    .accessibilityLabel(L10n.text("moveProgress", language)).accessibilityIdentifier("\(idPrefix).position")
                HStack(spacing: 8) {
                    control("first", "backward.end.fill", disabled: playback.ply == 0) { playback.seek(0) }
                    control("previous", "backward.frame.fill", disabled: playback.ply == 0) { playback.seek(playback.ply - 1) }
                    Button { playback.toggle() } label: {
                        Image(systemName: playback.playing ? "pause.fill" : "play.fill").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(playback.record.moves.isEmpty).accessibilityIdentifier("\(idPrefix).play")
                    .accessibilityLabel(L10n.choose(playback.playing ? "일시정지" : "재생", playback.playing ? "Pause" : "Play", language))
                    control("next", "forward.frame.fill", disabled: playback.ply == playback.record.moves.count) { playback.seek(playback.ply + 1) }
                    control("last", "forward.end.fill", disabled: playback.ply == playback.record.moves.count) { playback.seek(playback.record.moves.count) }
                }.buttonStyle(.bordered)
                HStack(spacing: 12) {
                    Image(systemName: "speedometer").accessibilityHidden(true)
                    Text(L10n.choose("재생 속도", "Speed", language)).font(.caption)
                    Spacer()
                    Text(playback.speed.formatted(.number.precision(.fractionLength(0...1))) + "×")
                        .font(.caption.monospacedDigit().bold()).accessibilityIdentifier("\(idPrefix).speedValue")
                }.padding(.top, 6)
                Slider(value: Binding(get: { playback.speed }, set: { playback.setSpeed($0) }), in: 0.5...16, step: 0.5)
                    .accessibilityLabel(L10n.choose("재생 속도", "Playback speed", language))
                    .accessibilityValue(playback.speed.formatted() + "×")
                    .accessibilityIdentifier("\(idPrefix).speed")
                HStack { Text("0.5×"); Spacer(); Text("16×") }.font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: max(280, boardSize))
        }
    }

    private func control(_ id: String, _ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(maxWidth: .infinity, minHeight: 44) }
            .disabled(disabled).accessibilityLabel(L10n.text(id, language)).accessibilityIdentifier("\(idPrefix).\(id)")
    }
}
