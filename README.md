# Gomoku

Offline iOS/iPadOS Gomoku app for human-vs-AI play.

## Features

- 15×15 board
- Human vs local AI
- Player can choose Black or White
- Easy / Normal / Hard / Adaptive AI (starts at 50/100)
- Fast reserve: start 30 seconds, +5 seconds per completed move, capped at 45 seconds
- Slow reserve: start 60 seconds, +10 seconds per completed move, capped at 90 seconds
- Unlimited clock
- Last-move marker
- Time-loss handling
- Tap to preview, then confirm with the Place button
- Local records and move-by-move replay (up to 200 completed games)
- Korean and English, switchable in Settings

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

Pull requests run the unsigned iOS build and simulator UI checks. The checks cover explicit Light/Dark switching, persistence after relaunch, System mode on a dark device, move preview/confirmation, replay navigation, and compact layout. Simulator screenshots are uploaded as **Gomoku-Design-Previews**. Run the System test with the simulator set to Dark.

Demo records used by the UI tests are compiled only in Debug and require explicit test launch arguments; they are not included in the Release IPA. Physical-device rendering, VoiceOver navigation, and Stage Manager still need hands-on validation.

## AI and move responsiveness

The local engine checks immediate wins and blocks across the entire board, scores both contiguous and broken shapes, and uses iterative alpha-beta search for Normal, Hard and Adaptive levels. The search targets a 2.2-second budget and keeps the best fully completed iteration. Hard and higher Adaptive levels search deeper when the budget allows. This is a local heuristic engine, not Rapfi or a trained neural network.

Confirming a move performs forbidden-pattern validation off the main actor. While the check runs, selection is locked and a checking status is shown. Returning to setup, restarting, or finishing cancels outstanding validation/search; request identifiers reject stale results. Forbidden-pattern evaluation examines only windows containing the relevant stone and recurses only on actual straight-four continuations. History encoding/writes also run off the main actor in order.

The `engine-check` CI job covers forbidden moves, edge threats, broken fours, forced wins, search deadlines, fast confirmation return, duplicate submissions, and cancellation across restarts. It also benchmarks the previous forbidden-check implementation. CI timing is not a guarantee for every physical device.

An external engine option is [Rapfi](https://github.com/dhbloo/rapfi), a GPLv3 C++ Gomoku/Renju engine with classical/NNUE evaluation and ARM64 support. Its executable/protocol interface and evaluation weights require a native in-process adapter or a hosted service before this iOS app can use it. Rapfi is not bundled or called by this version.

## Refillable time reserve

Both players start with their own reserve. Only the current player loses time. A legal completed move adds the preset increment to that player's reserve, up to its ceiling; the opponent then starts spending their own time. Previewing, cancelling, duplicate input, and forbidden moves never earn time. Reaching zero loses immediately and cannot be rescued by a late confirmation. Unlimited mode remains available. Saved games include their clock configuration; old fixed-total records retain their original 3/10-minute description.

The wide placement button below the board doubles as the active player's time gauge (remaining / ceiling), with quarter marks, numeric time and a low-time colour. On compact windows the button stays pinned at the bottom. Both player cards also show reserve gauges. The green/mint palette follows Light, Dark and System appearance, and the gauge updates without continuous animation.
