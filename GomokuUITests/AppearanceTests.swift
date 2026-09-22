import XCTest

final class AppearanceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-records"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
    }

    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing button: \(id)")
        if !button.isHittable { app.swipeUp() }
        button.tap()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func expectProgress(_ id: String, _ value: String) {
        let progress = app.staticTexts[id]
        XCTAssertTrue(progress.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "label == %@", value), evaluatedWith: progress)
        waitForExpectations(timeout: 15)
    }

    private func expectWholeBoard(prefix: String = "resultReplay") {
        let top = app.buttons["\(prefix).intersection.A1"], bottom = app.buttons["\(prefix).intersection.O15"]
        XCTAssertTrue(top.exists && bottom.exists)
        XCTAssertGreaterThan(top.frame.width, 8, "Replay must have a real square layout")
        XCTAssertGreaterThanOrEqual(top.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(bottom.frame.maxY, app.frame.maxY)
        XCTAssertGreaterThan(bottom.frame.midY - top.frame.midY, 150)
    }

    private func expectAppearance(_ value: String) {
        let status = app.descendants(matching: .any)["effectiveAppearance"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let expected = NSPredicate(format: "value == %@", value)
        expectation(for: expected, evaluatedWith: status)
        waitForExpectations(timeout: 20)
    }

    private func expectBossLayout() {
        let boss = app.buttons["difficulty.veryHard"]
        // Capture after the selection's layout commit, not the pointer-up frame.
        expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: boss)
        waitForExpectations(timeout: 5)
        let time = app.buttons["time.fast"]
        XCTAssertLessThanOrEqual(boss.frame.maxY, time.frame.minY, "Boss and time controls must not overlap")
        XCTAssertFalse(app.buttons["stone.1"].exists)
        XCTAssertFalse(app.buttons["stone.2"].exists)
    }

    func testThemePersistenceAndGameFlow() {
        tap("openSettings")
        tap("appearance.light")
        expectAppearance("light")
        screenshot("01-settings-light")
        tap("closeSettings")
        screenshot("02-home-light-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        screenshot("03-home-light-landscape")

        tap("openSettings")
        tap("appearance.dark")
        expectAppearance("dark")
        screenshot("04-settings-dark")
        tap("closeSettings")
        screenshot("05-home-dark-landscape")

        // Relaunch without resetting defaults: appearance must survive termination.
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        tap("openSettings")
        expectAppearance("dark")
        XCTAssertTrue(app.buttons["appearance.dark"].isSelected)
        tap("closeSettings")

        tap("openHistory")
        screenshot("06-history-dark")
        tap("record.00000000-0000-0000-0000-000000000001")
        expectProgress("replayProgress", "9 / 9")
        XCTAssertEqual(app.buttons["replay.intersection.H8"].value as? String, "5수")
        expectWholeBoard(prefix: "replay")
        screenshot("07-replay-dark")
        tap("replay.previous")
        XCTAssertEqual(app.staticTexts["replayProgress"].label, "8 / 9")

        app.terminate()
        app.launch()
        tap("time.slow")
        XCTAssertTrue(app.staticTexts["clockRule"].label.contains("+10"))
        tap("startGame")
        let confirm = app.buttons["confirmMove"]
        XCTAssertFalse(confirm.isEnabled)
        tap("intersection.H8")
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertNotNil(confirm.value as? String)
        screenshot("08-game-dark-preview")
        tap("confirmMove")
        let stone = app.buttons["intersection.H8"]
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: stone)
        waitForExpectations(timeout: 20)
        screenshot("09-game-dark-placed")

        tap("openSettings")
        tap("appearance.light")
        expectAppearance("light")
        tap("closeSettings")
        screenshot("10-game-light-landscape")
        XCUIDevice.shared.orientation = .portrait
        screenshot("11-game-light-portrait")
    }

    // The workflow sets the simulator to dark before running this test.
    func testSystemFollowsDarkAndCanBeRestored() {
        tap("openSettings")
        XCTAssertTrue(app.buttons["appearance.system"].isSelected)
        expectAppearance("dark")
        tap("appearance.light")
        expectAppearance("light")
        tap("appearance.system")
        expectAppearance("dark")
        screenshot("12-settings-system-dark")
        tap("language.en")
        tap("closeSettings")
        screenshot("13-home-system-dark-english")
    }

    func testCompactLayout() {
        screenshot("14-phone-home-light")
        tap("openSettings")
        tap("appearance.dark")
        expectAppearance("dark")
        screenshot("15-phone-settings-dark")
        tap("closeSettings")
        tap("startGame")
        tap("intersection.H8")
        let confirm = app.buttons["confirmMove"]
        // The reserve button stays visible without scrolling on a phone.
        XCTAssertTrue(confirm.isHittable)
        XCTAssertTrue(confirm.isEnabled)
        screenshot("16-phone-game-dark")
    }

    func testEmbeddedRapfiReturnsMove() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-rapfi-smoke"]
        app.launch()

        let status = app.staticTexts["rapfiSmokeStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 15), "Rapfi smoke status was not published")
        expectation(for: NSPredicate(format: "label BEGINSWITH %@", "ok:"), evaluatedWith: status)
        waitForExpectations(timeout: 15)
    }

    func testBossAchievementsAndResults() {
        tap("difficulty.veryHard")
        XCTAssertTrue(app.buttons["closeAchievements"].waitForExistence(timeout: 10))
        screenshot("21-achievements-locked-light")
        tap("closeAchievements")
        tap("difficulty.adaptive")
        XCTAssertTrue(app.staticTexts["automaticColour"].exists || app.otherElements["automaticColour"].exists)
        XCTAssertFalse(app.buttons["stone.1"].exists)
        XCTAssertFalse(app.buttons["stone.2"].exists)

        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-boss"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["winStreak"].firstMatch.waitForExistence(timeout: 10))
        tap("difficulty.veryHard")
        expectBossLayout()
        screenshot("22-boss-unlocked-light")
        tap("openSettings"); tap("appearance.dark"); tap("closeSettings")
        expectBossLayout()
        screenshot("23-boss-unlocked-dark")
        tap("openAchievements")
        let before = app.staticTexts["totalAP"].label
        tap("claim.wins")
        XCTAssertNotEqual(app.staticTexts["totalAP"].label, before)
        XCTAssertFalse(app.buttons["claim.wins"].exists)
        screenshot("24-achievements-dark")
        tap("closeAchievements")

        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-result"]
        app.launch()
        XCTAssertTrue(app.staticTexts["matchResultTitle"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["matchResultTitle"].label, "승리")
        expectProgress("resultReplayProgress", "9 / 9")
        expectWholeBoard()
        screenshot("25-victory-numbered-replay-dark")
        tap("resultReplay.first")
        XCTAssertEqual(app.staticTexts["resultReplayProgress"].label, "0 / 9")
        tap("resultReplay.next")
        XCTAssertEqual(app.staticTexts["resultReplayProgress"].label, "1 / 9")
        let speed = app.sliders["resultReplay.speed"]
        if !speed.isHittable { app.swipeUp() }
        speed.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        let speedValue = app.staticTexts["resultReplay.speedValue"]
        expectation(for: NSPredicate(format: "label == %@", "0.5×"), evaluatedWith: speedValue)
        waitForExpectations(timeout: 5)
        tap("resultReplay.play")
        expectation(for: NSPredicate(format: "label != %@", "1 / 9"), evaluatedWith: app.staticTexts["resultReplayProgress"])
        waitForExpectations(timeout: 15)
        if app.buttons["resultReplay.last"].isEnabled { tap("resultReplay.last") }
        tap("resultAgain")
        XCTAssertTrue(app.buttons["confirmMove"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["matchResultTitle"].exists)
        tap("backHome"); tap("confirmLeaveGame")
        XCTAssertFalse(app.descendants(matching: .any)["winStreak"].firstMatch.exists)
        XCTAssertTrue(app.buttons["difficulty.veryHard"].isSelected)
        tap("openSettings"); tap("appearance.light"); tap("closeSettings")
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-result", "-ui-testing-defeat"]
        app.launch()
        XCTAssertTrue(app.staticTexts["matchResultTitle"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["matchResultTitle"].label, "패배")
        expectProgress("resultReplayProgress", "10 / 10")
        screenshot("26-defeat-numbered-replay-light")
        tap("resultExit")
        XCTAssertTrue(app.buttons["difficulty.veryHard"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["matchResultTitle"].exists)
    }

    func testSixStoneReplayAndResignation() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-result", "-ui-testing-six"]
        app.launch()
        expectProgress("resultReplayProgress", "12 / 12")
        let victory = app.descendants(matching: .any)["resultReplay.victory"].firstMatch
        XCTAssertTrue(victory.waitForExistence(timeout: 10))
        XCTAssertEqual(victory.value as? String, "D8 → I8", "A middle winning move must sweep from the left endpoint")
        XCTAssertEqual(app.buttons["resultReplay.intersection.G8"].value as? String, "12수")
        expectWholeBoard()
        screenshot("27-white-six-gold-endpoint-sweep")
        tap("resultReplay.first")
        XCTAssertFalse(victory.exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        expectProgress("resultReplayProgress", "0 / 12")
        tap("resultReplay.last")
        expectProgress("resultReplayProgress", "12 / 12")
        screenshot("28-replay-rotated")
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-result", "-ui-testing-six", "-ui-testing-resigned"]
        app.launch()
        expectProgress("resultReplayProgress", "12 / 12")
        XCTAssertFalse(app.descendants(matching: .any)["resultReplay.victory"].firstMatch.exists)
        screenshot("29-resignation-without-gold-line")
    }

    func testPlayerOptionsAndForbiddenMarkers() {
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("stone.random")
        tap("difficulty.adaptive")
        tap("time.unlimited")
        XCTAssertTrue(app.staticTexts["nextStone"].label.contains("흑"))
        screenshot("17-random-adaptive-setup")
        tap("startGame")
        XCTAssertEqual(app.staticTexts["playerLabel.1"].label, "나")
        tap("backHome")
        tap("confirmLeaveGame")
        tap("openHistory")
        XCTAssertTrue(app.staticTexts["기권패"].firstMatch.waitForExistence(timeout: 10))
        screenshot("18-resignation-record")

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["stone.random"].isSelected)
        tap("difficulty.adaptive")
        tap("time.unlimited")
        XCTAssertTrue(app.staticTexts["nextStone"].label.contains("백"))
        tap("startGame")
        XCTAssertEqual(app.staticTexts["playerLabel.2"].label, "나")
        XCTAssertFalse(app.staticTexts["forbiddenLegend"].exists)

        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-forbidden"]
        app.launch()
        let forbidden = app.buttons["intersection.H8"]
        XCTAssertTrue(forbidden.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value CONTAINS %@", "33"), evaluatedWith: forbidden)
        waitForExpectations(timeout: 20)
        tap("intersection.H8")
        XCTAssertFalse(app.buttons["confirmMove"].isEnabled)
        screenshot("19-forbidden-light")
        tap("openSettings")
        tap("appearance.dark")
        expectAppearance("dark")
        tap("closeSettings")
        screenshot("20-forbidden-dark")
    }
}
