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
                    // Keep the repeating transaction on the flame, not the setup layout.
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: burning)
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
            burning = true
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
            .fixedSize(horizontal: false, vertical: true)
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
    private enum Filter: String, CaseIterable, Identifiable {
        case all, inProgress, claimable, completed
        var id: String { rawValue }
    }

    @ObservedObject var game: GameViewModel
    let language: AppLanguage
    var focusUnlocks = false
    @State private var filter: Filter = .all
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    private var theme: GomokuTheme { GomokuTheme(scheme) }
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], alignment: .leading, spacing: 12) {
                            summaryItem(
                                symbol: "sparkles",
                                label: L10n.choose("총 AP", "Total AP", language),
                                value: "\(game.achievements.totalAP) AP",
                                id: "totalAP"
                            )
                            summaryItem(
                                symbol: "gift.fill",
                                label: L10n.choose("수령 가능", "Claimable", language),
                                value: "\(game.achievements.pendingCount)",
                                id: "pendingRewards"
                            )
                            summaryItem(
                                symbol: "person.crop.rectangle",
                                label: L10n.choose("장착 칭호", "Equipped title", language),
                                value: game.achievements.title(language) ?? L10n.choose("없음", "None", language),
                                id: "equippedTitle"
                            )
                        }
                        if game.achievements.equippedTitle != nil {
                            Button(L10n.choose("칭호 해제", "Remove title", language)) { game.equipTitle(nil) }
                                .accessibilityIdentifier("unequipTitle")
                        }
                    }
                }
                Picker(L10n.choose("도전과제 필터", "Achievement filter", language), selection: $filter) {
                    Text(L10n.choose("전체", "All", language)).tag(Filter.all)
                    Text(L10n.choose("진행 중", "In progress", language)).tag(Filter.inProgress)
                    Text(L10n.choose("수령 가능", "Claimable", language)).tag(Filter.claimable)
                    Text(L10n.choose("완료", "Complete", language)).tag(Filter.completed)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("achievementFilter")

                ForEach(filteredDefinitions) { card($0) }
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

    private var filteredDefinitions: [AchievementDefinition] {
        AchievementDefinition.all.filter { definition in
            let level = game.achievements.level(definition.id)
            let maxed = level == definition.thresholds.count
            let metric = game.achievements.metrics[definition.metric, default: 0]
            let pending = game.achievements.rewards.contains {
                $0.achievementID == definition.id && $0.claimedAt == nil
            }
            switch filter {
            case .all: return true
            case .inProgress: return metric > 0 && !maxed && !pending
            case .claimable: return pending
            case .completed: return maxed
            }
        }
    }

    private func summaryItem(symbol: String, label: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(label, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(theme.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ definition: AchievementDefinition) -> some View {
        let level = game.achievements.level(definition.id)
        let metric = game.achievements.metrics[definition.metric, default: 0]
        let maxed = level == definition.thresholds.count
        let next = definition.thresholds[min(level, definition.thresholds.count - 1)]
        let previous = level == 0 ? 0 : definition.thresholds[level - 1]
        let ratio = maxed ? 1 : Double(metric - previous) / Double(max(1, next - previous))
        let pending = game.achievements.rewards.filter { $0.achievementID == definition.id && $0.claimedAt == nil }
        let claimed = game.achievements.rewards.filter { $0.achievementID == definition.id && $0.claimedAt != nil }
        let earnedAP = claimed.reduce(0) { $0 + $1.amount }
        let color = definition.progressive ? [Color.gray, Color(hex: 0xA36C47), Color(hex: 0x8C9EA8), Color(hex: 0xB88528), Color(hex: 0x62BFB9)][max(0, level - 1)] : definition.rarity.color
        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: level > 0 ? "seal.fill" : "seal").font(.title2).foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(definition.name(language) + (definition.progressive ? " · " + (level == 0 ? "I" : AchievementDefinition.stages[level - 1]) : ""))
                            .font(.headline)
                        HStack(spacing: 6) {
                            Text(definition.rarity.name(language))
                            if definition.progressive {
                                Text("·")
                                Text(L10n.choose("단계형", "Progressive", language))
                            }
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(color)
                    }
                    Spacer(minLength: 0)
                    if maxed { Text("MAX").font(.caption2.bold()).foregroundStyle(color) }
                }
                Text(definition.description(language)).font(.caption).foregroundStyle(theme.secondary)
                ProgressView(value: maxed ? 1 : min(1, max(0, ratio))).tint(color)
                    .accessibilityValue(maxed ? "100%" : "\(Int(min(1, max(0, ratio)) * 100))%")
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(maxed ? "\(metric) · " + L10n.choose("달성", "Complete", language) : "\(metric) / \(next)")
                            .monospacedDigit()
                        if definition.progressive && !maxed {
                            Text(L10n.choose("다음: \(AchievementDefinition.stages[level])", "Next: \(AchievementDefinition.stages[level])", language))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(pending.isEmpty ? "\(definition.reward(min(level + 1, definition.thresholds.count))) AP" : "+\(pending.reduce(0) { $0 + $1.amount }) AP")
                        Text(L10n.choose("획득 \(earnedAP) AP", "Earned \(earnedAP) AP", language))
                            .foregroundStyle(theme.secondary)
                    }
                }.font(.caption)
                HStack {
                    if !pending.isEmpty {
                        Button(L10n.choose("수령", "CLAIM", language)) { game.claimAchievement(definition.id) }
                            .buttonStyle(GomokuButtonStyle())
                            .controlSize(.large)
                            .accessibilityHint(L10n.choose("\(pending.reduce(0) { $0 + $1.amount }) AP 수령", "Claim \(pending.reduce(0) { $0 + $1.amount }) AP", language))
                            .accessibilityIdentifier("claim.\(definition.id)")
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
                    } else {
                        Text(L10n.choose("칭호 잠김", "Title locked", language))
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                    }
                }
            }
        }
        .id(definition.id)
    }

}
