# Gomoku

Offline iOS/iPadOS Gomoku app for human-vs-AI play.

## Features

- 15×15 board
- User-selected photographic app icon, packaged as an opaque 1024px universal iOS asset
- Human vs local AI
- Easy/Normal/Hard allow Black, White or Random
- Adaptive always alternates Black/White, starting Black; Very hard always draws a random colour
- Ordinary-mode stone preference and next Adaptive colour persist independently; non-Adaptive games do not advance the sequence
- Easy / Normal / Hard / Very hard / Adaptive AI (starts at 50/100)
- Fast reserve: start 30 seconds, +5 seconds per completed move, capped at 45 seconds
- Slow reserve: start 60 seconds, +10 seconds per completed move, capped at 90 seconds
- Unlimited clock
- Last-move marker
- Time-loss handling
- Tap to preview, then confirm with the Place button
- Local records and move-by-move replay (up to 200 completed games)
- Korean and English, switchable in Settings
- Forbidden points show 33 / 44 / 6+ markers only on the human Black player's turn
- Leaving or restarting an unfinished game records a resignation loss, including Adaptive skill adjustment

## Appearance

The interface uses warm ivory and forest-green accents in Light mode, and deep charcoal-green surfaces with soft mint accents in Dark mode. The board, clocks, records, replay, and settings share the same semantic palette.

Open the sliders button in the top-right corner, then choose **System**, **Light**, or **Dark**. System is the default and follows the device's appearance and automatic schedule. The preference is saved between launches. Settings can also be opened during a game.

Wide iPad windows place the board and controls side by side. Narrow windows use a scrollable vertical layout so the controls remain reachable. Larger accessibility text sizes use the vertical layout. Board intersections expose coordinates and stone state to VoiceOver.

## Renju rules

Black uses Renju forbidden-move restrictions:

- Double-three is forbidden
- Double-four is forbidden
- Overline is forbidden
- Black wins with exactly five
- White wins with five or more

The rules engine also checks legal continuations when evaluating open threes. The app uses free opening play rather than an RIF tournament opening protocol.

When you play Black, forbidden empty intersections are marked with **33** (double-three), **44** (double-four), or **6+** (overline) during your turn. Tapping a marker explains the restriction. The map is calculated off the main actor from the same rules used to validate moves, and cleared when the turn changes or the game ends. White players and replay views do not see these hints. Cancelled scans cannot publish markers into another game.

## Colour assignment and resignation

Easy, Normal and Hard offer Black/White/Random; Random makes an independent draw at each game start. Adaptive forces a saved alternating sequence, initially Black then White, and displays the next colour in setup. Very hard forces a random draw. Automatic modes hide the colour selector without overwriting the ordinary-mode preference. Starting an Adaptive game consumes one assignment, including an in-game restart; previews, settings and non-Adaptive games do not. Records always store the actual colour used.

The in-game Home and New Game actions ask for confirmation. Confirming while the game is unfinished records exactly one resignation loss with its played moves and updates Adaptive difficulty as a loss. Leaving an already completed game preserves its result. This applies to these in-app actions; force-quitting the process is not a resignation event.

## Build an IPA

The repository includes a GitHub Actions workflow using a public standard macOS runner.

1. Open **Actions**.
2. Run **Build iOS IPA**, or push to `main`.
3. Open the completed workflow run.
4. Download the **Gomoku-iOS** artifact.
5. Extract `Gomoku.ipa`.
6. Open the IPA with SideStore and let SideStore sign/install it.

The generated IPA is intentionally unsigned because SideStore re-signs the app for the device.

## Local Xcode build

The Xcode project is generated from `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open Gomoku.xcodeproj
```

Requires iOS/iPadOS 17 or later.

## UI validation

Pull requests run the unsigned iOS build and simulator UI checks. The checks cover explicit Light/Dark switching, persistence after relaunch, System mode on a dark device, move preview/confirmation, replay navigation, and compact layout. Simulator screenshots are uploaded as **Gomoku-Design-Previews-iPad** and **Gomoku-Design-Previews-iPhone**. Run the System test with the simulator set to Dark.

Demo records used by the UI tests are compiled only in Debug and require explicit test launch arguments; they are not included in the Release IPA. Physical-device rendering, VoiceOver navigation, and Stage Manager still need hands-on validation.

## AI and move responsiveness

The local engine checks immediate wins and blocks across the entire board, scores both contiguous and broken shapes, and uses iterative alpha-beta search for Normal, Hard and Adaptive levels. The search targets a maximum 7.5-second budget and keeps the best fully completed iteration. Hard and higher Adaptive levels search deeper when the budget allows. This is a local heuristic engine, not Rapfi or a trained neural network.

Confirming a move performs forbidden-pattern validation off the main actor. While the check runs, selection is locked and a checking status is shown. Returning to setup, restarting, or finishing cancels outstanding validation/search; request identifiers reject stale results. Forbidden-pattern evaluation examines only windows containing the relevant stone and recurses only on actual straight-four continuations. At game completion, history, achievements and adaptive skill are encoded together on the main actor into one bounded-history archive; ordinary moves do not write this archive.

The `engine-check` CI job covers forbidden moves, edge threats, broken fours, forced wins, search deadlines, fast confirmation return, duplicate submissions, and cancellation across restarts. It also benchmarks the previous forbidden-check implementation. CI timing is not a guarantee for every physical device.

An external engine option is [Rapfi](https://github.com/dhbloo/rapfi), a GPLv3 C++ Gomoku/Renju engine with classical/NNUE evaluation and ARM64 support. Its executable/protocol interface and evaluation weights require a native in-process adapter or a hosted service before this iOS app can use it. Rapfi is not bundled or called by this version.

## Refillable time reserve

Both players start with their own reserve. Only the current player loses time. A legal completed move adds the preset increment to that player's reserve, up to its ceiling; the opponent then starts spending their own time. Previewing, cancelling, duplicate input, and forbidden moves never earn time. Reaching zero loses immediately and cannot be rescued by a late confirmation. Unlimited mode remains available. Saved games include their clock configuration; old fixed-total records retain their original 3/10-minute description.

The wide placement button below the board doubles as the active player's time gauge (remaining / ceiling), with quarter marks, numeric time and a low-time colour. On compact windows the button stays pinned at the bottom. Both player cards also show reserve gauges. The green/mint palette follows Light, Dark and System appearance, and the gauge updates without continuous animation.


## Achievements, final boss and results

- Very hard is a red final-boss card. Permanently unlock it by **either** reaching Adaptive 80 **or** winning twice on Hard (not necessarily consecutively). Claiming AP is not required. Falling below 80 or deleting replay history never relocks it.
- Adaptive always alternates Black/White, starting Black for a new profile. Very hard always draws a random colour each game. Ordinary modes retain the saved colour preference.
- Ten achievements: six progressive I–V tracks and four one-time achievements with Common/Rare/Epic/Legendary rarity. Progressive rewards: 5/10/20/40/75 AP. One-time rewards: 10/30/50/100 AP. AP requires an explicit claim; titles require only unlocking. Older unlocked title stages remain selectable.
- Home shows an animated flame with the current win streak, hidden at zero. Loss, draw and resignation reset the current streak, not its historical best. Reduce Motion disables the flame animation.
- Results automatically play one 16× numbered timelapse. First/previous/play-pause/next/last, a position slider and a 0.5×–16× speed slider support review. Manual speed is saved; seeking or leaving pauses playback. Reduce Motion opens the final board without autoplay. Play again preserves difficulty/time settings and uses the next Adaptive score/colour or a fresh boss colour draw. Exit returns home.
- History opens the complete numbered board in a full-screen view with an explicit square board size, including iPad landscape. It shares the same replay controls; zero-move games explain why the board is empty.
- Actual Black five/White five-or-more wins light gold borders in move order, then sweep a gold line from an endpoint. A winning move at the right endpoint sweeps right-to-left; a middle or left winning move starts at the left endpoint (top for vertical). The live board celebrates before results, and the replay celebrates at its end. Resignations, timeouts and draws do not animate a win. Reduce Motion displays the completed gold marking statically.
- Results, adaptive score and achievement counters are stored as one versioned local archive (`gomoku.archive.v1`). Per-game IDs prevent duplicate accounting; reward rows retain their original AP amounts and claim dates. The latest 200 replays are separate from lifetime metrics. Legacy retained history/current skill are backfilled once; unavailable deleted history and unknown past peaks cannot be reconstructed. This is device-local storage, without cloud sync.
- Very hard searches up to depth 10, uses a wider candidate set, bounded continuous-four proof search, legal threat evaluation and per-search position caches. All modes stop at a 7.5-second search budget; obvious moves finish early. Short reserves reduce the budget and leave time for committing the move. OS scheduling can add small overhead, so physical-device latency/thermal validation remains necessary.

The engine and progression CI covers OR unlocks, score regression, repeat claims, legacy migration, history deletion, streak reset, forced colours and rematches. Simulator checks cover the red boss card, achievement claim and numbered result replay in addition to existing appearance/confirmation checks.

CI also checks replay reconstruction, playback cancellation, once-only autoplay, speed persistence and all winning-line directions, including White six and excluded Black overlines. The **Gomoku-Xcode** artifact contains the actual generated project, source, assets and shared scheme used for the Release build. Unzip it and open `Gomoku-Xcode/Gomoku.xcodeproj`; XcodeGen is not needed for that download. Select your Apple Developer Team and a unique bundle identifier before signing or archiving for distribution. The included build number is 3; use a higher unused number for subsequent uploads.
