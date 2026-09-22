import Foundation

extension EngineChecks {
    static func sample(_ difficulty: AIDifficulty = .hard, _ result: GameResult = .blackWin, id: UUID = UUID()) -> GameRecord {
        GameRecord(id: id, playerStone: .black, difficulty: difficulty, adaptiveSkill: nil,
                   timeControl: .unlimited, result: result, moves: [])
    }

    static func achievementSample(
        difficulty: AIDifficulty = .normal,
        playerStone: Stone = .black,
        result: GameResult? = nil,
        timeControl: TimeControl = .unlimited,
        adaptiveSkill: Int? = nil,
        moveCount: Int = 21,
        playedAt: Date = Date()
    ) -> GameRecord {
        let resolvedResult = result ?? (playerStone == .black ? .blackWin : .whiteWin)
        let moves = (0..<moveCount).map { index in
            RecordedMove(
                stone: index.isMultiple(of: 2) ? .black : .white,
                move: Move(row: index / 15, column: index % 15)
            )
        }
        return GameRecord(
            playedAt: playedAt,
            playerStone: playerStone,
            difficulty: difficulty,
            adaptiveSkill: adaptiveSkill,
            timeControl: timeControl,
            result: resolvedResult,
            moves: moves
        )
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
        require(!AIDifficulty.easy.usesRapfi(adaptiveSkill: 100), "Easy never routes through Rapfi")
        require(!AIDifficulty.hard.usesRapfi(adaptiveSkill: 100), "Hard keeps the Swift engine")
        require(!AIDifficulty.adaptive.usesRapfi(adaptiveSkill: 79), "Adaptive 79 stays on the Swift engine")
        require(AIDifficulty.adaptive.usesRapfi(adaptiveSkill: 80), "Adaptive 80 switches to Rapfi")
        require(AIDifficulty.veryHard.usesRapfi(adaptiveSkill: 0), "Very Hard always routes through Rapfi")
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

        var engineIndicator = AIEngineIndicatorState()
        engineIndicator.apply(.rapfi)
        require(!engineIndicator.showsSwift, "Rapfi response never shows the Swift fallback label")
        engineIndicator.apply(.swiftFallback)
        require(engineIndicator.showsSwift, "failed Rapfi request explicitly shows the Swift fallback label")
        engineIndicator.apply(.rapfi)
        require(!engineIndicator.showsSwift, "the next successful Rapfi response immediately hides the Swift label")
        engineIndicator.apply(.nativeSwift)
        require(!engineIndicator.showsSwift, "native Swift difficulty does not masquerade as a fallback")
        engineIndicator.reset()
        require(engineIndicator.origin == nil, "new game and game end can reset engine-origin state")

        var lineProgress = AchievementProgress()
        for _ in 0..<250 {
            lineProgress.record(achievementSample(moveCount: 21), resultingSkill: 50)
        }
        require(lineProgress.metrics["lineWins"] == 250 && lineProgress.level("lineWins") == 5
                && lineProgress.rewards.filter { $0.achievementID == "lineWins" }.count == 5,
                "Line Breaker unlocks every progressive threshold exactly once")

        var timeoutProgress = AchievementProgress()
        for _ in 0..<50 {
            timeoutProgress.record(achievementSample(result: .whiteTimeout), resultingSkill: 50)
        }
        require(timeoutProgress.metrics["timeoutWins"] == 50 && timeoutProgress.level("timeoutWins") == 5,
                "Timekeeper unlocks every progressive threshold")

        var blitzProgress = AchievementProgress()
        for _ in 0..<100 {
            blitzProgress.record(achievementSample(timeControl: .blitz), resultingSkill: 50)
        }
        require(blitzProgress.metrics["blitzWins"] == 100 && blitzProgress.level("blitzWins") == 5,
                "Blitz Runner unlocks every progressive threshold")

        var quickProgress = AchievementProgress()
        for _ in 0..<50 {
            quickProgress.record(achievementSample(moveCount: 19), resultingSkill: 50)
        }
        require(quickProgress.metrics["quickLineWins"] == 50 && quickProgress.level("quickLineWins") == 5,
                "Quick Finisher unlocks every progressive threshold")

        var peakProgress = AchievementProgress()
        for _ in 0..<50 {
            peakProgress.record(achievementSample(difficulty: .adaptive, adaptiveSkill: 80), resultingSkill: 80)
        }
        require(peakProgress.metrics["highAdaptiveWins"] == 50 && peakProgress.level("highAdaptiveWins") == 5,
                "Peak Challenger uses the game's starting Adaptive score for every threshold")

        var eliteProgress = AchievementProgress()
        for _ in 0..<10 {
            eliteProgress.record(achievementSample(difficulty: .hard), resultingSkill: 50)
        }
        require(eliteProgress.metrics["eliteBestStreak"] == 10 && eliteProgress.level("eliteStreak") == 5,
                "Elite Streak unlocks every progressive threshold")
        eliteProgress.record(achievementSample(difficulty: .normal), resultingSkill: 50)
        require(eliteProgress.eliteCurrentStreak == 0 && eliteProgress.metrics["eliteBestStreak"] == 10,
                "playing outside Hard and Very Hard ends only the live elite streak")

        var oneShots = AchievementProgress()
        for difficulty in AIDifficulty.allCases {
            oneShots.record(achievementSample(difficulty: difficulty), resultingSkill: 50)
        }
        require(oneShots.metrics["difficultyConquest"] == 5 && oneShots.level("completeConquest") == 1,
                "Complete Conquest persists one win for each AI difficulty")
        var twoSides = AchievementProgress()
        twoSides.record(achievementSample(playerStone: .black), resultingSkill: 50)
        twoSides.record(achievementSample(playerStone: .white), resultingSkill: 50)
        require(twoSides.level("twoSides") == 1, "Two Sides requires consecutive wins with different colours")
        var special = AchievementProgress()
        special.record(achievementSample(difficulty: .veryHard, timeControl: .blitz), resultingSkill: 50)
        special.record(achievementSample(moveCount: 60), resultingSkill: 50)
        require(special.level("lightningDethrone") == 1 && special.level("endurance") == 1,
                "Lightning Dethrone and Endurance unlock from their exact game facts")

        let oldClaimDate = Date(timeIntervalSince1970: 123)
        var migrated = AchievementProgress()
        migrated.schemaVersion = 1
        migrated.backfillVersion = 0
        migrated.rewards = [
            AchievementReward(
                achievementID: "hard2",
                level: 1,
                amount: 30,
                unlockedAt: oldClaimDate,
                claimedAt: oldClaimDate
            )
        ]
        migrated.equippedTitle = "hard2.1"
        let history = [
            achievementSample(difficulty: .easy, playedAt: Date(timeIntervalSince1970: 1)),
            achievementSample(difficulty: .normal, playerStone: .white, playedAt: Date(timeIntervalSince1970: 2))
        ]
        _ = migrated.migrateNewMetrics(from: history)
        let rewardCountAfterMigration = migrated.rewards.count
        let lineWinsAfterMigration = migrated.metrics["lineWins"]
        _ = migrated.migrateNewMetrics(from: history)
        require(migrated.metrics["lineWins"] == lineWinsAfterMigration
                && migrated.rewards.count == rewardCountAfterMigration,
                "achievement backfill is idempotent")
        require(migrated.totalAP == 30 && migrated.equippedTitle == "hard2.1"
                && migrated.rewards.first?.claimedAt == oldClaimDate,
                "migration preserves existing claimed rewards, AP and equipped title")

        require(GomokuAI.thinkingBudget(remaining: nil, increment: nil) == 7.5, "unlimited game keeps the 7.5-second late-game ceiling")
        require(GomokuAI.thinkingBudget(remaining: 1, increment: 5) < 0.7, "AI reserves time to commit before timeout")
        require(GomokuAI.thinkingBudget(remaining: 10, increment: 5) <= 5, "low reserve shortens search below refill amount")
        require(GomokuAI.thinkingBudget(remaining: nil, increment: nil, moveCount: 1) <= 0.9,
                "second-move opening search no longer spends the full 7.5-second budget")
        require(GomokuAI.thinkingBudget(remaining: 45, increment: 0, moveCount: 10, blitz: true) <= 0.9,
                "Blitz uses a short search budget even with plenty of clock remaining")
        require(GomokuAI.thinkingBudget(remaining: nil, increment: nil, moveCount: 40) == 7.5,
                "complex late positions can still use the full strength budget")
        let boss = GomokuAI(difficulty: .veryHard)
        let tactical = board([(4,4),(5,9)], [(7,5),(7,6),(7,7)])
        let move = boss.chooseMove(board: tactical, stone: .white, timeLimit: 0.8)
        require(move.map { [Move(row: 7, column: 4), Move(row: 7, column: 8)].contains($0) } == true, "boss finds a legal forcing open four")
        let deadline = ProcessInfo.processInfo.systemUptime
        let timed = boss.chooseMove(board: board([(4,4),(6,8),(8,5),(10,10),(7,9)], [(5,5),(8,8),(9,7),(7,4)]), stone: .black, timeLimit: 0.1)
        require(timed != nil && ProcessInfo.processInfo.systemUptime - deadline < 0.5, "boss deep search also observes short deadline")
        let fullStart = ProcessInfo.processInfo.systemUptime
        let fullBoard = board([(4,4),(6,8),(8,5),(10,10),(7,9)], [(5,5),(8,8),(9,7),(7,4)])
        let fullMove = boss.chooseMove(board: fullBoard, stone: .black, timeLimit: 20)
        let fullDuration = ProcessInfo.processInfo.systemUptime - fullStart
        print(String(format: "Boss 7.5-second cap: %.3f seconds", fullDuration))
        require(fullDuration < 8 && fullMove.map { RenjuRules.isLegalMove(board: fullBoard, move: $0, stone: .black) } == true,
                "oversized caller budget is capped at 7.5 seconds with a legal completed move")
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
