import SwiftUI

extension AchievementRarity {
    var color: Color {
        switch self {
        case .common: return Color(hex: 0x687A80)
        case .rare: return Color(hex: 0x287AC4)
        case .epic: return Color(hex: 0x9758C8)
        case .legendary: return Color(hex: 0xAD7820)
        }
    }
    func name(_ language: AppLanguage) -> String {
        switch self {
        case .common: return L10n.choose("일반", "Common", language)
        case .rare: return L10n.choose("희귀", "Rare", language)
        case .epic: return L10n.choose("영웅", "Epic", language)
        case .legendary: return L10n.choose("전설", "Legendary", language)
        }
    }
}

struct StreakBadge: View {
    let count: Int
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burning = false
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                    .scaleEffect(burning && !reduceMotion ? 1.07 : 1)
                    .shadow(color: .orange.opacity(burning ? 0.45 : 0.15), radius: 8)
                Text("\(count)").font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(Color(hex: 0x411006)).offset(y: 6)
            }
            Text(L10n.choose("연승", "Win streak", language)).font(.caption.bold())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.choose("\(count)연승", "\(count) wins in a row", language))
        .accessibilityIdentifier("winStreak")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { burning = true }
        }
    }
}

struct BossDifficultyCard: View {
    let progress: AchievementProgress
    let selected: Bool
    let language: AppLanguage
    let action: () -> Void
    private var unlocked: Bool { progress.bossUnlocked }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: unlocked ? "crown.fill" : "lock.fill")
                        .font(.system(size: 28)).foregroundStyle(Color(hex: 0xFFBA9C))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FINAL BOSS").font(.caption2.bold()).tracking(3).foregroundStyle(Color(hex: 0xFFC5B5))
                        Text(L10n.difficulty(.veryHard, language: language)).font(.title3.bold())
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : unlocked ? "flame.fill" : "chevron.right")
                }
                if unlocked {
                    Text(L10n.choose("영구 해제 · 흑백 무작위 · 최대 7.5초 사고", "Permanently unlocked · Random colour · Up to 7.5s", language))
                        .font(.caption).foregroundStyle(Color(hex: 0xFFD7CD))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        requirement(L10n.choose("경지에 오르다", "The Summit", language), value: progress.metrics["peakSkill", default: 0], target: 80)
                        Text(L10n.choose("또는", "OR", language)).font(.caption2.bold()).foregroundStyle(Color(hex: 0xFFAF98))
                        requirement(L10n.choose("강자의 증명 · 어려움 승리", "Proven Strength · Hard wins", language), value: progress.metrics["hardWins", default: 0], target: 2)
                    }
                }
            }
            .padding(18).foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(hex: 0x491326), Color(hex: selected ? 0xA61E32 : 0x751C2A), Color(hex: 0x260D17)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: selected ? 0xFF8970 : 0xBC4854), lineWidth: selected ? 2 : 1))
            .shadow(color: .red.opacity(selected ? 0.2 : 0.05), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("difficulty.veryHard")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(L10n.choose(unlocked ? "해제됨" : "잠김", unlocked ? "Unlocked" : "Locked", language))
    }
    private func requirement(_ name: String, value: Int, target: Int) -> some View {
        VStack(spacing: 4) {
            HStack { Text(name); Spacer(); Text("\(min(value, target)) / \(target)").monospacedDigit() }.font(.caption)
            ProgressView(value: Double(min(value, target)), total: Double(target)).tint(Color(hex: 0xFFAB91))
        }
    }
}

struct AchievementsView: View {
    @ObservedObject var game: GameViewModel
    let language: AppLanguage
    var focusUnlocks = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    private var theme: GomokuTheme { GomokuTheme(scheme) }
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(theme.accent)
                            Text("\(game.achievements.totalAP) AP").font(.largeTitle.bold()).monospacedDigit().accessibilityIdentifier("totalAP")
                            Spacer()
                            Text(L10n.choose("미수령 \(game.achievements.pendingCount)", "\(game.achievements.pendingCount) unclaimed", language)).font(.caption)
                        }
                        Text(game.achievements.title(language) ?? L10n.choose("장착한 칭호 없음", "No title equipped", language)).font(.subheadline)
                        if game.achievements.equippedTitle != nil {
                            Button(L10n.choose("칭호 해제", "Remove title", language)) { game.equipTitle(nil) }
                                .accessibilityIdentifier("unequipTitle")
                        }
                    }
                }
                Text(L10n.choose("성장형", "Progressive", language)).font(.title2.bold())
                ForEach(AchievementDefinition.all.filter(\.progressive)) { card($0) }
                Text(L10n.choose("단일형", "One-time", language)).font(.title2.bold())
                ForEach(AchievementDefinition.all.filter { !$0.progressive }) { card($0) }
            }
            .padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .onAppear { if focusUnlocks { proxy.scrollTo("adaptive80", anchor: .top) } }
        }
        .background { GameBackdrop() }.foregroundStyle(theme.ink).tint(theme.accent)
        .navigationTitle(L10n.choose("도전과제", "Achievements", language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) {
            Button(L10n.text("close", language)) { dismiss() }.accessibilityIdentifier("closeAchievements")
        } }
    }

    private func card(_ definition: AchievementDefinition) -> some View {
        let level = game.achievements.level(definition.id)
        let metric = game.achievements.metrics[definition.metric, default: 0]
        let maxed = level == definition.thresholds.count
        let next = definition.thresholds[min(level, definition.thresholds.count - 1)]
        let previous = level == 0 ? 0 : definition.thresholds[level - 1]
        let ratio = maxed ? 1 : Double(metric - previous) / Double(max(1, next - previous))
        let pending = game.achievements.rewards.filter { $0.achievementID == definition.id && $0.claimedAt == nil }
        let color = definition.progressive ? [Color.gray, Color(hex: 0xA36C47), Color(hex: 0x8C9EA8), Color(hex: 0xB88528), Color(hex: 0x62BFB9)][max(0, level - 1)] : definition.rarity.color
        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: level > 0 ? "seal.fill" : "seal").font(.title2).foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(definition.name(language) + (definition.progressive ? " · " + (level == 0 ? "I" : AchievementDefinition.stages[level - 1]) : ""))
                            .font(.headline)
                        Text(definition.progressive ? L10n.choose("성장형 · 단계별 보상", "Progressive · Rewards per stage", language) : definition.rarity.name(language))
                            .font(.caption.weight(.semibold)).foregroundStyle(color)
                    }
                    Spacer(minLength: 0)
                    if maxed { Text("MAX").font(.caption2.bold()).foregroundStyle(color) }
                }
                Text(description(definition)).font(.caption).foregroundStyle(theme.secondary)
                ProgressView(value: min(1, max(0, ratio))).tint(color)
                HStack {
                    Text(maxed ? "\(metric) · " + L10n.choose("달성", "Complete", language) : "\(metric) / \(next)").monospacedDigit()
                    Spacer()
                    Text(pending.isEmpty ? "\(definition.reward(min(level + 1, definition.thresholds.count))) AP" : "+\(pending.reduce(0) { $0 + $1.amount }) AP")
                }.font(.caption)
                HStack {
                    if !pending.isEmpty {
                        Button(L10n.choose("수령", "CLAIM", language)) { game.claimAchievement(definition.id) }
                            .buttonStyle(GomokuButtonStyle()).accessibilityIdentifier("claim.\(definition.id)")
                    } else {
                        Text(L10n.choose(level > 0 ? "보상 수령 완료" : "미달성", level > 0 ? "Rewards claimed" : "Locked", language))
                            .font(.caption).foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    if level > 0 {
                        Menu {
                            ForEach(1...level, id: \.self) { stage in
                                Button(definition.name(language) + (definition.progressive ? " · " + AchievementDefinition.stages[stage - 1] : "")) {
                                    game.equipTitle("\(definition.id).\(stage)")
                                }
                            }
                        } label: { Label(L10n.choose("칭호", "Title", language), systemImage: "person.crop.rectangle") }
                        .accessibilityIdentifier("title.\(definition.id)")
                    }
                }
            }
        }
        .id(definition.id)
    }

    private func description(_ definition: AchievementDefinition) -> String {
        switch definition.id {
        case "games", "firstGame": return L10n.choose("기권 없이 종료한 경기", "Finish games without resignation", language)
        case "streak": return L10n.choose("최고 연승 기록 · 패배·무승부 시 현재 연승 종료", "Best win streak · Loss or draw ends the current streak", language)
        case "adaptive80": return L10n.choose("지능형 80점 도달 · 매우 어려움 영구 해제", "Reach Adaptive 80 · Permanently unlock Very hard", language)
        case "hard2": return L10n.choose("어려움 누적 2승 · 매우 어려움 영구 해제", "Win twice on Hard · Permanently unlock Very hard", language)
        case "bossWins", "firstBoss": return L10n.choose("매우 어려움에서 승리", "Win on Very hard", language)
        case "blackWins": return L10n.choose("흑으로 승리한 경기", "Games won as Black", language)
        case "whiteWins": return L10n.choose("백으로 승리한 경기", "Games won as White", language)
        default: return L10n.choose("모든 난이도 누적 승리", "Total wins across all difficulties", language)
        }
    }
}
