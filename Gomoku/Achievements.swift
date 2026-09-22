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
    let koDescription: String
    let enDescription: String
    let metric: String
    let thresholds: [Int]
    let rarity: AchievementRarity
    var progressive: Bool { thresholds.count > 1 }
    func name(_ language: AppLanguage) -> String { language == .korean ? ko : en }
    func description(_ language: AppLanguage) -> String { language == .korean ? koDescription : enDescription }
    func reward(_ level: Int) -> Int { progressive ? [5, 10, 20, 40, 75][level - 1] : rarity.ap }
    static let stages = ["I", "II", "III", "IV", "V"]
    static let all: [Self] = [
        .init(id: "wins", ko: "승부사", en: "Victor", koDescription: "모든 난이도 누적 승리", enDescription: "Total wins across all difficulties", metric: "wins", thresholds: [1,10,30,100,300], rarity: .common),
        .init(id: "games", ko: "대국가", en: "Regular", koDescription: "기권 없이 종료한 경기", enDescription: "Finish games without resignation", metric: "games", thresholds: [5,20,50,150,500], rarity: .common),
        .init(id: "streak", ko: "연승가", en: "Unstoppable", koDescription: "최고 연승 기록", enDescription: "Best win streak", metric: "bestStreak", thresholds: [2,3,5,7,10], rarity: .common),
        .init(id: "blackWins", ko: "흑의 길", en: "Path of Black", koDescription: "흑으로 승리한 경기", enDescription: "Games won as Black", metric: "blackWins", thresholds: [1,5,20,50,100], rarity: .common),
        .init(id: "whiteWins", ko: "백의 길", en: "Path of White", koDescription: "백으로 승리한 경기", enDescription: "Games won as White", metric: "whiteWins", thresholds: [1,5,20,50,100], rarity: .common),
        .init(id: "bossWins", ko: "왕좌에 도전", en: "Throne Challenger", koDescription: "매우 어려움에서 승리", enDescription: "Win on Very Hard", metric: "bossWins", thresholds: [1,3,10,25,50], rarity: .common),
        .init(id: "firstGame", ko: "첫 수의 여정", en: "First Journey", koDescription: "첫 AI 대국 완료", enDescription: "Complete the first AI game", metric: "games", thresholds: [1], rarity: .common),
        .init(id: "adaptive80", ko: "경지에 오르다", en: "The Summit", koDescription: "지능형 80점 도달", enDescription: "Reach Adaptive 80", metric: "peakSkill", thresholds: [80], rarity: .epic),
        .init(id: "hard2", ko: "강자의 증명", en: "Proven Strength", koDescription: "어려움에서 누적 2승", enDescription: "Win twice on Hard", metric: "hardWins", thresholds: [2], rarity: .rare),
        .init(id: "firstBoss", ko: "왕좌를 무너뜨리다", en: "Dethroned", koDescription: "매우 어려움 첫 승리", enDescription: "First win on Very Hard", metric: "bossWins", thresholds: [1], rarity: .legendary),
        .init(id: "lineWins", ko: "정면승부", en: "Line Breaker", koDescription: "시간패나 기권이 아닌 오목 완성 승리", enDescription: "Win by completing a line, not by timeout or resignation", metric: "lineWins", thresholds: [1,10,30,100,250], rarity: .common),
        .init(id: "timeoutWins", ko: "시간의 주인", en: "Timekeeper", koDescription: "상대의 시간패로 승리", enDescription: "Win when the opponent runs out of time", metric: "timeoutWins", thresholds: [1,3,10,25,50], rarity: .rare),
        .init(id: "blitzWins", ko: "번개승부", en: "Blitz Runner", koDescription: "Blitz 시간 설정에서 승리", enDescription: "Win with the Blitz time control", metric: "blitzWins", thresholds: [1,5,20,50,100], rarity: .common),
        .init(id: "quickLineWins", ko: "속전속결", en: "Quick Finisher", koDescription: "19수 이내에 실제 오목을 완성해 승리", enDescription: "Complete a winning line within 19 total moves", metric: "quickLineWins", thresholds: [1,3,10,25,50], rarity: .rare),
        .init(id: "highAdaptiveWins", ko: "경지의 승부", en: "Peak Challenger", koDescription: "시작 점수 80 이상의 지능형 대국에서 승리", enDescription: "Win an Adaptive game that started at skill 80 or higher", metric: "highAdaptiveWins", thresholds: [1,3,10,25,50], rarity: .epic),
        .init(id: "eliteStreak", ko: "강자 연승", en: "Elite Streak", koDescription: "어려움 또는 매우 어려움에서 이어 간 최고 연승", enDescription: "Best consecutive streak on Hard or Very Hard", metric: "eliteBestStreak", thresholds: [2,3,5,7,10], rarity: .epic),
        .init(id: "completeConquest", ko: "오색 정복", en: "Complete Conquest", koDescription: "다섯 AI 난이도에서 각각 최소 1승", enDescription: "Win at least once on all five AI difficulties", metric: "difficultyConquest", thresholds: [5], rarity: .legendary),
        .init(id: "twoSides", ko: "양면의 승부사", en: "Two Sides", koDescription: "서로 다른 색으로 AI 대국 2연승", enDescription: "Win two consecutive AI games with different colours", metric: "twoSides", thresholds: [1], rarity: .rare),
        .init(id: "lightningDethrone", ko: "왕좌를 번개처럼", en: "Lightning Dethrone", koDescription: "Blitz로 매우 어려움에게 승리", enDescription: "Defeat Very Hard with the Blitz time control", metric: "lightningDethrone", thresholds: [1], rarity: .legendary),
        .init(id: "endurance", ko: "장기전의 끝", en: "Endurance", koDescription: "60수 이상 진행된 AI 대국에서 승리", enDescription: "Win an AI game lasting at least 60 moves", metric: "endurance", thresholds: [1], rarity: .epic)
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
    static let currentSchemaVersion = 2
    static let currentBackfillVersion = 1

    var metrics: [String: Int] = [:]
    var currentStreak = 0
    var processedGames: Set<UUID> = []
    var rewards: [AchievementReward] = []
    var equippedTitle: String?
    var schemaVersion = currentSchemaVersion
    var backfillVersion = currentBackfillVersion
    var newMetricProcessedGames: Set<UUID> = []
    var difficultyWinsMask = 0
    var lastWinningStone: Stone?
    var eliteCurrentStreak = 0

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
        recordNewMetrics(game)
        return unlock(at: date)
    }

    /// Replays only metrics introduced in schema v2. Existing counters and
    /// reward rows are untouched, so legacy claims and AP cannot be duplicated.
    @discardableResult
    mutating func migrateNewMetrics(from records: [GameRecord], at date: Date = Date()) -> [AchievementReward] {
        guard backfillVersion < Self.currentBackfillVersion else { return [] }
        for record in records.sorted(by: { $0.playedAt < $1.playedAt }) {
            recordNewMetrics(record)
        }
        schemaVersion = Self.currentSchemaVersion
        backfillVersion = Self.currentBackfillVersion
        return unlock(at: date)
    }

    private mutating func recordNewMetrics(_ game: GameRecord) {
        guard newMetricProcessedGames.insert(game.id).inserted else { return }
        let won = game.result.playerWon(playerStone: game.playerStone)
        let lineWin = won && (game.result == .blackWin || game.result == .whiteWin)
        let timeoutWin = won && (game.result == .blackTimeout || game.result == .whiteTimeout)

        if lineWin {
            metrics["lineWins", default: 0] += 1
            if game.moves.count <= 19 { metrics["quickLineWins", default: 0] += 1 }
        }
        if timeoutWin { metrics["timeoutWins", default: 0] += 1 }
        if won && game.timeControl == .blitz { metrics["blitzWins", default: 0] += 1 }
        if won, game.difficulty == .adaptive, (game.adaptiveSkill ?? 0) >= 80 {
            metrics["highAdaptiveWins", default: 0] += 1
        }

        if won && (game.difficulty == .hard || game.difficulty == .veryHard) {
            eliteCurrentStreak += 1
            metrics["eliteBestStreak"] = max(metrics["eliteBestStreak", default: 0], eliteCurrentStreak)
        } else {
            eliteCurrentStreak = 0
        }

        if won {
            difficultyWinsMask |= 1 << difficultyBit(game.difficulty)
            metrics["difficultyConquest"] = difficultyWinsMask.nonzeroBitCount
            if let previous = lastWinningStone, previous != game.playerStone {
                metrics["twoSides"] = 1
            }
            lastWinningStone = game.playerStone
            if game.difficulty == .veryHard && game.timeControl == .blitz {
                metrics["lightningDethrone"] = 1
            }
            if game.moves.count >= 60 { metrics["endurance"] = 1 }
        } else {
            lastWinningStone = nil
        }
    }

    private func difficultyBit(_ difficulty: AIDifficulty) -> Int {
        switch difficulty {
        case .easy: return 0
        case .normal: return 1
        case .hard: return 2
        case .adaptive: return 3
        case .veryHard: return 4
        }
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

    private enum CodingKeys: String, CodingKey {
        case metrics, currentStreak, processedGames, rewards, equippedTitle
        case schemaVersion, backfillVersion, newMetricProcessedGames
        case difficultyWinsMask, lastWinningStone, eliteCurrentStreak
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metrics = try container.decodeIfPresent([String: Int].self, forKey: .metrics) ?? [:]
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        processedGames = try container.decodeIfPresent(Set<UUID>.self, forKey: .processedGames) ?? []
        rewards = try container.decodeIfPresent([AchievementReward].self, forKey: .rewards) ?? []
        equippedTitle = try container.decodeIfPresent(String.self, forKey: .equippedTitle)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        backfillVersion = try container.decodeIfPresent(Int.self, forKey: .backfillVersion) ?? 0
        newMetricProcessedGames = try container.decodeIfPresent(Set<UUID>.self, forKey: .newMetricProcessedGames) ?? []
        difficultyWinsMask = try container.decodeIfPresent(Int.self, forKey: .difficultyWinsMask) ?? 0
        lastWinningStone = try container.decodeIfPresent(Stone.self, forKey: .lastWinningStone)
        eliteCurrentStreak = try container.decodeIfPresent(Int.self, forKey: .eliteCurrentStreak) ?? 0
    }
}

/// A single encoded value commits the result, progression and skill together.
struct GameArchive: Codable {
    var version = 2
    var records: [GameRecord]
    var achievements: AchievementProgress
    var adaptiveSkill: Int

    init(records: [GameRecord], achievements: AchievementProgress, adaptiveSkill: Int) {
        self.records = records
        self.achievements = achievements
        self.adaptiveSkill = adaptiveSkill
    }

    private enum CodingKeys: String, CodingKey { case version, records, achievements, adaptiveSkill }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        records = try container.decodeIfPresent([GameRecord].self, forKey: .records) ?? []
        achievements = try container.decodeIfPresent(AchievementProgress.self, forKey: .achievements) ?? AchievementProgress()
        adaptiveSkill = try container.decodeIfPresent(Int.self, forKey: .adaptiveSkill) ?? 50
    }
}
