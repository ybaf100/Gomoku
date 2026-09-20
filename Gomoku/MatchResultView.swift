import SwiftUI

struct ReplayPosition {
    let record: GameRecord
    let ply: Int
    var board: [[Stone]] {
        var value = Array(repeating: Array(repeating: Stone.empty, count: 15), count: 15)
        for entry in record.moves.prefix(ply) { value[entry.move.row][entry.move.column] = entry.stone }
        return value
    }
    var numbers: [Move: Int] {
        Dictionary(record.moves.prefix(ply).enumerated().map { ($0.element.move, $0.offset + 1) }, uniquingKeysWith: { _, new in new })
    }
    var last: Move? { ply > 0 ? record.moves[ply - 1].move : nil }
    var winningLine: Set<Move> {
        guard ply == record.moves.count, let last,
              record.result == .blackWin || record.result == .whiteWin else { return [] }
        let board = board
        let stone = board[last.row][last.column]
        var result = Set<Move>()
        for (dr, dc) in [(1,0),(0,1),(1,1),(1,-1)] {
            var line = [last]
            for sign in [-1, 1] {
                var r = last.row + dr * sign, c = last.column + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c), board[r][c] == stone {
                    line.append(Move(row: r, column: c)); r += dr * sign; c += dc * sign
                }
            }
            if stone == .black ? line.count == 5 : line.count >= 5 { result.formUnion(line) }
        }
        return result
    }
}

struct NumberedReplay: View {
    let record: GameRecord
    let language: AppLanguage
    @State private var ply: Int
    @State private var playing = false
    init(record: GameRecord, language: AppLanguage, startAtEnd: Bool = true) {
        self.record = record; self.language = language
        _ply = State(initialValue: startAtEnd ? record.moves.count : 0)
    }
    var body: some View {
        let position = ReplayPosition(record: record, ply: ply)
        VStack(spacing: 12) {
            BoardView(board: position.board, lastMove: position.last, selectedMove: nil, previewStone: .black,
                      enabled: false, language: language, moveNumbers: position.numbers, winningLine: position.winningLine) { _ in }
                .accessibilityIdentifier("numberedBoard")
            HStack {
                Text(L10n.choose("착수 순서", "Move order", language))
                Spacer()
                Text("\(ply) / \(record.moves.count)").monospacedDigit().accessibilityIdentifier("resultReplayProgress")
            }.font(.caption)
            Slider(value: Binding(get: { Double(ply) }, set: { playing = false; ply = min(record.moves.count, Int($0)) }),
                   in: 0...Double(max(1, record.moves.count)), step: 1)
                .disabled(record.moves.isEmpty).accessibilityLabel(L10n.text("moveProgress", language))
            HStack(spacing: 10) {
                control("first", "backward.end.fill", disabled: ply == 0) { ply = 0 }
                control("previous", "backward.frame.fill", disabled: ply == 0) { ply -= 1 }
                Button {
                    if !playing && ply == record.moves.count { ply = 0 }
                    playing.toggle()
                } label: { Image(systemName: playing ? "pause.fill" : "play.fill").frame(maxWidth: .infinity, minHeight: 44) }
                .disabled(record.moves.isEmpty).accessibilityIdentifier("resultReplay.play")
                .accessibilityLabel(L10n.choose(playing ? "일시정지" : "재생", playing ? "Pause" : "Play", language))
                control("next", "forward.frame.fill", disabled: ply == record.moves.count) { ply += 1 }
                control("last", "forward.end.fill", disabled: ply == record.moves.count) { ply = record.moves.count }
            }.buttonStyle(.bordered)
        }
        .task(id: playing) {
            guard playing else { return }
            while !Task.isCancelled && ply < record.moves.count {
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                guard !Task.isCancelled else { return }
                ply += 1
            }
            playing = false
        }
        .onDisappear { playing = false }
    }
    private func control(_ id: String, _ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button { playing = false; action() } label: { Image(systemName: symbol).frame(maxWidth: .infinity, minHeight: 44) }
            .disabled(disabled).accessibilityLabel(L10n.text(id, language)).accessibilityIdentifier("resultReplay.\(id)")
    }
}

struct MatchResultView: View {
    @ObservedObject var game: GameViewModel
    let record: GameRecord
    let language: AppLanguage
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showAchievements = false
    private var theme: GomokuTheme { GomokuTheme(scheme) }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if geometry.size.width >= 850 && !typeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: 28) {
                            NumberedReplay(record: record, language: language).frame(maxWidth: 600)
                            details.frame(width: 270)
                        }
                    } else {
                        NumberedReplay(record: record, language: language)
                        details
                    }
                }
                .padding(20).frame(maxWidth: 1040).frame(maxWidth: .infinity)
            }
        }
        .background { GameBackdrop() }.foregroundStyle(theme.ink).tint(theme.accent)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { game.playAgain() } label: { Label(L10n.choose("다시하기", "Play again", language), systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                    .buttonStyle(GomokuButtonStyle()).accessibilityIdentifier("resultAgain")
                Button { game.backToSetup() } label: { Text(L10n.choose("나가기", "Exit", language)).frame(maxWidth: .infinity) }
                    .buttonStyle(GomokuButtonStyle(primary: false)).accessibilityIdentifier("resultExit")
            }.padding(16).frame(maxWidth: 720).frame(maxWidth: .infinity).background(theme.background)
        }
        .sheet(isPresented: $showAchievements) { NavigationStack { AchievementsView(game: game, language: language) } }
        .interactiveDismissDisabled()
    }
    private var header: some View {
        VStack(spacing: 7) {
            Text(record.result == .draw ? L10n.choose("무승부", "DRAW", language) : record.result.playerWon(playerStone: record.playerStone) ? L10n.choose("승리", "VICTORY", language) : L10n.choose("패배", "DEFEAT", language))
                .font(.system(.largeTitle, design: .serif, weight: .bold)).accessibilityIdentifier("matchResultTitle")
            Text(L10n.result(record.result, playerStone: record.playerStone, language: language))
                .font(.subheadline).foregroundStyle(theme.secondary)
            Text(L10n.difficulty(record.difficulty, language: language, adaptiveSkill: record.adaptiveSkill))
                .font(.caption).foregroundStyle(theme.accent)
        }
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title = game.achievements.title(language) { Label(title, systemImage: "seal.fill").font(.caption.bold()) }
            if record.difficulty == .adaptive {
                Text(L10n.choose("다음 상대 · 지능형 \(game.adaptiveSkill)점", "Next opponent · Adaptive \(game.adaptiveSkill)", language)).font(.headline)
                Text(L10n.choose("다음 판", "Next game", language) + " · " + L10n.stone(game.nextAdaptiveStone, language: language)).font(.caption)
            }
            if game.bossJustUnlocked {
                Label(L10n.choose("매우 어려움 영구 해제!", "Very hard permanently unlocked!", language), systemImage: "crown.fill")
                    .font(.headline).foregroundStyle(theme.danger).accessibilityIdentifier("bossUnlockedNotice")
            }
            ForEach(game.newAchievements) { reward in
                if let definition = AchievementDefinition.all.first(where: { $0.id == reward.achievementID }) {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill").foregroundStyle(definition.progressive ? theme.accent : definition.rarity.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(definition.progressive ? (reward.level == 5 ? "ACHIEVEMENT MAXED" : "ACHIEVEMENT UPGRADED") : "ACHIEVEMENT UNLOCKED")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(theme.secondary)
                            Text(definition.name(language) + (definition.progressive ? " · " + AchievementDefinition.stages[reward.level - 1] : ""))
                                .font(.subheadline.bold())
                        }
                        Spacer(minLength: 0)
                        Text("+\(reward.amount) AP").font(.caption.monospaced())
                    }
                    .padding(12).background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Button { showAchievements = true } label: { Label(L10n.choose("도전과제 · 보상 수령", "Achievements · Claim rewards", language), systemImage: "trophy") }
                .font(.subheadline).accessibilityIdentifier("resultAchievements")
        }
    }
}
