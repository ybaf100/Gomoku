import SwiftUI

struct MatchResultView: View {
    @ObservedObject var game: GameViewModel
    let record: GameRecord
    let language: AppLanguage
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback: ReplayPlayback
    @State private var showAchievements = false
    @State private var revealedRewards = 0
    private var theme: GomokuTheme { GomokuTheme(scheme) }
    init(game: GameViewModel, record: GameRecord, language: AppLanguage) {
        self.game = game; self.record = record; self.language = language
        _playback = StateObject(wrappedValue: ReplayPlayback(record: record))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if geometry.size.width >= 850 && !typeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: 28) {
                            NumberedReplay(playback: playback, language: language, boardSize: max(260, min(560, geometry.size.width - 338, geometry.size.height - 360)))
                            details.frame(width: 270)
                        }
                    } else {
                        NumberedReplay(playback: playback, language: language, boardSize: max(240, min(560, geometry.size.width - 40, geometry.size.height - 360)))
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
        .onAppear { playback.activate(autoplay: true, reduceMotion: reduceMotion) }
        .onDisappear { playback.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
        .task(id: record.id) {
            for index in game.newAchievements.indices {
                guard !Task.isCancelled else { return }
                if reduceMotion { revealedRewards = index + 1 }
                else { withAnimation(.easeOut(duration: 0.25)) { revealedRewards = index + 1 } }
                do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
            }
        }
    }
    private var header: some View {
        VStack(spacing: 7) {
            Text(record.result == .draw ? L10n.choose("무승부", "DRAW", language) : record.result.playerWon(playerStone: record.playerStone) ? L10n.choose("승리", "VICTORY", language) : L10n.choose("패배", "DEFEAT", language))
                .font(.system(.largeTitle, design: .serif, weight: .bold)).accessibilityIdentifier("matchResultTitle")
            Text(resultReason)
                .font(.subheadline).foregroundStyle(theme.secondary)
            Text(L10n.difficulty(record.difficulty, language: language, adaptiveSkill: record.adaptiveSkill))
                .font(.caption).foregroundStyle(theme.accent)
        }
    }
    private var resultReason: String {
        switch record.result {
        case .blackWin, .whiteWin: return L10n.choose(playback.victory.runs.contains(where: { $0.points.count >= 6 }) ? "백 장목 완성" : "오목 완성", playback.victory.runs.contains(where: { $0.points.count >= 6 }) ? "White overline" : "Five in a row", language)
        case .blackTimeout, .whiteTimeout: return L10n.choose("시간 초과", "Time expired", language)
        case .blackResigned, .whiteResigned: return L10n.choose("기권으로 종료", "Ended by resignation", language)
        case .draw: return L10n.choose("승부 없이 대국 종료", "The game ended level", language)
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
            ForEach(Array(game.newAchievements.prefix(revealedRewards))) { reward in
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
