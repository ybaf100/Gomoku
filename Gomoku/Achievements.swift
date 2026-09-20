import Foundation

enum AchievementRarity: String, Codable, Sendable {
    case common, rare, epic, legendary
    var ap: Int {
        switch self { case .common: return 10; case .rare: return 30; case .epic: return 50; case .legendary: return 100 }
    }
}

struct AchievementDefinition: Identifiable, Sendable {
    let id: String
    let ko: String
    let en: String
    let metric: String
    let thresholds: [Int]
    let rarity: AchievementRarity
    var progressive: Bool { thresholds.count > 1 }
    func name(_ language: AppLanguage) -> String { language == .korean ? ko : en }
    func reward(_ level: Int) -> Int { progressive ? [5, 10, 20, 40, 75][level - 1] : rarity.ap }
    static let stages = ["I", "II", "III", "IV", "V"]
    static let all: [Self] = [
        .init(id: "wins", ko: "승부사", en: "Victor", metric: "wins", thresholds: [1,10,30,100,300], rarity: .common),
        .init(id: "games", ko: "대국가", en: "Regular", metric: "games", thresholds: [5,20,50,150,500], rarity: .common),
        .init(id: "streak", ko: "연승가", en: "Unstoppable", metric: "bestStreak", thresholds: [2,3,5,7,10], rarity: .common),
        .init(id: "blackWins", ko: "흑의 길", en: "Path of Black", metric: "blackWins", thresholds: [1,5,20,50,100], rarity: .common),
        .init(id: "whiteWins", ko: "백의 길", en: "Path of White", metric: "whiteWins", thresholds: [1,5,20,50,100], rarity: .common),
        .init(id: "bossWins", ko: "왕좌에 도전", en: "Throne Challenger", metric: "bossWins", thresholds: [1,3,10,25,50], rarity: .common),
        .init(id: "firstGame", ko: "첫 수의 여정", en: "First Journey", metric: "games", thresholds: [1], rarity: .common),
        .init(id: "adaptive80", ko: "경지에 오르다", en: "The Summit", metric: "peakSkill", thresholds: [80], rarity: .epic),
        .init(id: "hard2", ko: "강자의 증명", en: "Proven Strength", metric: "hardWins", thresholds: [2], rarity: .rare),
        .init(id: "firstBoss", ko: "왕좌를 무너뜨리다", en: "Dethroned", metric: "bossWins", thresholds: [1], rarity: .legendary)
    ]
}

struct AchievementReward: Codable, Identifiable, Sendable {
    let achievementID: String
    let level: Int
    let amount: Int
    let unlockedAt: Date
    var claimedAt: Date?
    var id: String { "\(achievementID).\(level)" }
}

/// Lifetime counters and one-time reward rows are independent of the 200-game replay window.
struct AchievementProgress: Codable, Sendable {
    var metrics: [String: Int] = [:]
    var currentStreak = 0
    var processedGames: Set<UUID> = []
    var rewards: [AchievementReward] = []
    var equippedTitle: String?

    var totalAP: Int { rewards.filter { $0.claimedAt != nil }.reduce(0) { $0 + $1.amount } }
    var pendingCount: Int { rewards.filter { $0.claimedAt == nil }.count }
    var bossUnlocked: Bool { rewards.contains { $0.achievementID == "adaptive80" || $0.achievementID == "hard2" } }
    func level(_ id: String) -> Int { rewards.filter { $0.achievementID == id }.map(\.level).max() ?? 0 }

    @discardableResult
    mutating func observeSkill(_ skill: Int, at date: Date = Date()) -> [AchievementReward] {
        metrics["peakSkill"] = max(metrics["peakSkill", default: 0], skill)
        return unlock(at: date)
    }

    @discardableResult
    mutating func record(_ game: GameRecord, resultingSkill: Int, at date: Date = Date()) -> [AchievementReward] {
        guard processedGames.insert(game.id).inserted else { return [] }
        let won = game.result.playerWon(playerStone: game.playerStone)
        let resigned = game.result == .blackResigned || game.result == .whiteResigned
        if !resigned { metrics["games", default: 0] += 1 }
        currentStreak = won ? currentStreak + 1 : 0
        metrics["bestStreak"] = max(metrics["bestStreak", default: 0], currentStreak)
        if won {
            metrics["wins", default: 0] += 1
            metrics[game.playerStone == .black ? "blackWins" : "whiteWins", default: 0] += 1
            if game.difficulty == .hard { metrics["hardWins", default: 0] += 1 }
            if game.difficulty == .veryHard { metrics["bossWins", default: 0] += 1 }
        }
        metrics["peakSkill"] = max(metrics["peakSkill", default: 0], max(resultingSkill, game.adaptiveSkill ?? 0))
        return unlock(at: date)
    }

    private mutating func unlock(at date: Date) -> [AchievementReward] {
        var added: [AchievementReward] = []
        for definition in AchievementDefinition.all {
            for (index, threshold) in definition.thresholds.enumerated() {
                let level = index + 1
                guard metrics[definition.metric, default: 0] >= threshold,
                      !rewards.contains(where: { $0.achievementID == definition.id && $0.level == level }) else { continue }
                added.append(.init(achievementID: definition.id, level: level,
                                   amount: definition.reward(level), unlockedAt: date))
            }
        }
        rewards.append(contentsOf: added)
        return added
    }

    mutating func claim(_ achievementID: String) {
        for index in rewards.indices where rewards[index].achievementID == achievementID && rewards[index].claimedAt == nil {
            rewards[index].claimedAt = Date()
        }
    }

    mutating func equip(_ rewardID: String?) {
        guard rewardID == nil || rewards.contains(where: { $0.id == rewardID }) else { return }
        equippedTitle = rewardID
    }

    func title(_ language: AppLanguage) -> String? {
        guard let row = rewards.first(where: { $0.id == equippedTitle }),
              let definition = AchievementDefinition.all.first(where: { $0.id == row.achievementID }) else { return nil }
        return definition.name(language) + (definition.progressive ? " · " + AchievementDefinition.stages[row.level - 1] : "")
    }
}

/// A single encoded value commits the result, progression and skill together.
struct GameArchive: Codable {
    var version = 1
    var records: [GameRecord]
    var achievements: AchievementProgress
    var adaptiveSkill: Int
}
