# Gomoku

Offline iOS/iPadOS Gomoku app for human-vs-AI play.

## Game rules
- 15×15 board
- Renju rules fixed
- Black: double-three, double-four, and overline are forbidden
- Black wins with exactly five
- White wins with five or more
- Player can choose Black or White

## Time controls
- Fast: 3 minutes per side
- Slow: 10 minutes per side
- Unlimited

## AI
- Easy / Normal / Hard
- Local-only heuristic search; no server required

## Build
A GitHub Actions workflow builds an unsigned IPA suitable for re-signing and installation with SideStore.

> This repository is intentionally public so standard GitHub-hosted Actions runners can be used without consuming private-repository Actions minutes.
