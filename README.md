# Gomoku

Offline iOS/iPadOS Gomoku app for human-vs-AI play.

## Features

- 15×15 board
- Human vs local AI
- Player can choose Black or White
- Easy / Normal / Hard / Adaptive AI (starts at 50/100)
- Fast: 3 minutes per side
- Slow: 10 minutes per side
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
