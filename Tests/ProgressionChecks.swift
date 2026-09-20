import Foundation

extension EngineChecks {
    static func sample(_ difficulty: AIDifficulty = .hard, _ result: GameResult = .blackWin, id: UUID = UUID()) -> GameRecord {
        GameRecord(id: id, playerStone: .black, difficulty: difficulty, adaptiveSkill: nil,
                   timeControl: .unlimited, result: result, moves: [])
    }
    static func progressionChecks() {
        var progress = AchievementProgress()
        let first = sample()
        progress.record(first, resultingSkill: 50)
        require(!progress.bossUnlocked && progress.currentStreak == 1, "one Hard win does not unlock boss")
        progress.record(first, resultingSkill: 50)
        require(progress.metrics["hardWins"] == 1 && progress.currentStreak == 1, "duplicate result cannot award counters twice")
        progress.record(sample(.hard, .blackResigned), resultingSkill: 50)
        require(progress.currentStreak == 0 && progress.metrics["games"] == 1, "resignation breaks streak without farming completed games")
        progress.record(sample(), resultingSkill: 50)
        require(progress.bossUnlocked && progress.level("hard2") == 1 && progress.totalAP == 0,
                "two non-consecutive Hard wins unlock before claim")
        let pending = progress.pendingCount
        progress.claim("hard2"); progress.claim("hard2")
        require(progress.totalAP == 30 && progress.pendingCount == pending - 1, "repeated claim pays exactly once")
        progress.equip("hard2.1")
        require(progress.equippedTitle == "hard2.1", "unlocked title can be equipped")
        progress.equip("bossWins.5")
        require(progress.equippedTitle == "hard2.1", "unearned title cannot be equipped")
        var skill = AchievementProgress()
        skill.observeSkill(79)
        require(!skill.bossUnlocked, "79 does not unlock boss")
        skill.observeSkill(80)
        skill.observeSkill(35)
        require(skill.bossUnlocked && skill.metrics["peakSkill"] == 80, "80 then decline preserves permanent OR unlock")
        skill.record(sample(.veryHard), resultingSkill: 35)
        require(skill.level("firstBoss") == 1 && skill.level("bossWins") == 1, "boss victory awards both first and progressive rows")
        for _ in 0..<12 { skill.record(sample(.normal), resultingSkill: 35) }
        require(skill.level("streak") == 5 && skill.rewards.filter { $0.achievementID == "streak" }.count == 5,
                "stage V stops rewards while counters continue")
        skill.equip("streak.2")
        skill.record(sample(.normal, .draw), resultingSkill: 35)
        require(skill.currentStreak == 0 && skill.metrics["bestStreak"] == 13 && skill.equippedTitle == "streak.2", "draw clears only current streak; historical stage and title remain")
        let restored = try! JSONDecoder().decode(AchievementProgress.self, from: JSONEncoder().encode(skill))
        require(restored.bossUnlocked && restored.level("streak") == 5, "permanent unlock and all stages round-trip")
        require(GomokuAI.thinkingBudget(remaining: nil, increment: nil) == 7.5, "unlimited game has 7.5-second AI cap")
        require(GomokuAI.thinkingBudget(remaining: 1, increment: 5) < 0.7, "AI reserves time to commit before timeout")
        require(GomokuAI.thinkingBudget(remaining: 10, increment: 5) <= 5, "low reserve shortens search below refill amount")
        let boss = GomokuAI(difficulty: .veryHard)
        let tactical = board([(4,4),(5,9)], [(7,5),(7,6),(7,7)])
        let move = boss.chooseMove(board: tactical, stone: .white, timeLimit: 0.8)
        require(move.map { [Move(row: 7, column: 4), Move(row: 7, column: 8)].contains($0) } == true, "boss finds a legal forcing open four")
        let deadline = ProcessInfo.processInfo.systemUptime
        let timed = boss.chooseMove(board: board([(4,4),(6,8),(8,5),(10,10),(7,9)], [(5,5),(8,8),(9,7),(7,4)]), stone: .black, timeLimit: 0.1)
        require(timed != nil && ProcessInfo.processInfo.systemUptime - deadline < 0.5, "boss deep search also observes short deadline")
    }

    @MainActor
    static func progressionIntegrationChecks() async {
        let defaults = UserDefaults(suiteName: "gomoku.progression.\(UUID())")!
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        defaults.set(try! encoder.encode([sample(), sample()]), forKey: "gomoku.gameRecords")
        var draws = 0
        let game = GameViewModel(defaults: defaults, randomBlack: { draws += 1; return true })
        require(game.achievements.bossUnlocked && game.achievements.currentStreak == 2, "legacy history backfills Hard route and streak")
        game.clearRecords()
        let restored = GameViewModel(defaults: defaults)
        require(restored.records.isEmpty && restored.achievements.bossUnlocked && restored.achievements.currentStreak == 2, "clearing records and reloading preserves lifetime achievements")
        game.difficulty = .veryHard
        game.stoneSelection = .white
        game.timeControl = .unlimited
        game.startGame()
        require(game.playerStone == .black && draws == 1, "boss ignores fixed colour preference and draws randomly")
        game.backToSetup()
        game.playAgain()
        require(game.difficulty == .veryHard && draws == 2 && game.result == nil, "rematch retains boss and draws again without duplicating result")
        game.backToSetup()
        game.difficulty = .adaptive
        game.stoneSelection = .white
        game.startGame()
        require(game.playerStone == .black, "first Adaptive game forces Black even with White preference")
        game.backToSetup()
        let adjusted = game.adaptiveSkill
        game.playAgain()
        require(game.playerStone == .white && game.adaptiveSkill == adjusted, "Adaptive rematch advances colour and uses adjusted skill")
        game.backToSetup()
        let empty = GameViewModel(defaults: UserDefaults(suiteName: "gomoku.locked.\(UUID())")!)
        empty.difficulty = .veryHard; empty.startGame()
        require(!empty.isGameActive && empty.records.isEmpty, "model rejects locked boss even if UI is bypassed")
        defaults.set(80, forKey: "gomoku.adaptiveSkill")
        let skillDefaults = UserDefaults(suiteName: "gomoku.skill-backfill.\(UUID())")!
        skillDefaults.set(80, forKey: "gomoku.adaptiveSkill")
        let veteran = GameViewModel(defaults: skillDefaults)
        require(veteran.achievements.bossUnlocked, "legacy current score 80 backfills alternate unlock without wins")
        veteran.difficulty = .adaptive; veteran.timeControl = .unlimited; veteran.startGame(); veteran.backToSetup()
        let reloaded = GameViewModel(defaults: skillDefaults)
        require(reloaded.adaptiveSkill == 72 && reloaded.achievements.bossUnlocked, "score and persistent unlock committed together after losing")
    }
}
