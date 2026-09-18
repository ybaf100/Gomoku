import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if game.isGameActive {
                    gameScreen
                } else {
                    setupScreen
                }
            }
            .navigationTitle("Gomoku")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 56))
                    Text("Renju vs AI")
                        .font(.largeTitle.bold())
                    Text("15×15 · Offline")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)

                settingCard(title: "Your stone") {
                    Picker("Your stone", selection: $game.playerStone) {
                        Text("● Black").tag(Stone.black)
                        Text("○ White").tag(Stone.white)
                    }
                    .pickerStyle(.segmented)
                }

                settingCard(title: "AI difficulty") {
                    Picker("AI difficulty", selection: $game.difficulty) {
                        ForEach(AIDifficulty.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                settingCard(title: "Time control") {
                    VStack(spacing: 10) {
                        ForEach(TimeControl.allCases) { control in
                            Button {
                                game.timeControl = control
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(control.rawValue)
                                            .font(.headline)
                                        Text(control.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if game.timeControl == control {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(game.timeControl == control ? 0.15 : 0.07))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    game.startGame()
                } label: {
                    Text("Start Game")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: 620)
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private var gameScreen: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                playerClock(stone: .black)
                Spacer()
                VStack(spacing: 3) {
                    Text(game.turnTitle)
                        .font(.headline)
                    Text(game.difficulty.rawValue + " AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                playerClock(stone: .white)
            }
            .padding(.horizontal)

            if let message = game.statusMessage {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            BoardView(
                board: game.board,
                lastMove: game.lastMove,
                enabled: game.currentTurn == game.playerStone && game.result == nil && !game.isThinking
            ) { move in
                game.play(move)
            }
            .padding(.horizontal, 8)

            HStack {
                Button("Setup") {
                    game.backToSetup()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("New Game") {
                    game.startGame()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .overlay {
            if game.result != nil {
                resultOverlay
            }
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(game.resultTitle)
                    .font(.largeTitle.bold())

                HStack {
                    Button("Setup") {
                        game.backToSetup()
                    }
                    .buttonStyle(.bordered)

                    Button("Play Again") {
                        game.startGame()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding()
        }
    }

    private func playerClock(stone: Stone) -> some View {
        let isPlayer = stone == game.playerStone
        let active = game.currentTurn == stone && game.result == nil

        return VStack(alignment: stone == .black ? .leading : .trailing, spacing: 3) {
            HStack(spacing: 5) {
                Circle()
                    .fill(stone == .black ? Color.black : Color.white)
                    .overlay {
                        if stone == .white {
                            Circle().stroke(.black.opacity(0.5), lineWidth: 1)
                        }
                    }
                    .frame(width: 13, height: 13)

                Text(isPlayer ? "You" : "AI")
                    .font(.caption.weight(.semibold))
            }

            Text(game.formattedTime(for: stone))
                .font(.system(.title3, design: .monospaced, weight: active ? .bold : .regular))
        }
        .frame(minWidth: 74, alignment: stone == .black ? .leading : .trailing)
    }

    private func settingCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
