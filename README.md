# Gomoku

Offline iOS/iPadOS Gomoku app for human-vs-AI play.

## Features

- 15×15 board
- Human vs local AI
- Player can choose Black or White
- Easy / Normal / Hard AI
- Fast: 3 minutes per side
- Slow: 10 minutes per side
- Unlimited clock
- Last-move marker
- Time-loss handling

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
