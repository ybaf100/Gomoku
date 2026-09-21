import SwiftUI

/// Shares the board's exact intersection geometry; never intercepts a board gesture.
struct WinningCelebration: View {
    let pattern: VictoryPattern
    let startedAt: Date
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: finished || reduceMotion)) { timeline in
            let frame = pattern.frame(elapsed: reduceMotion || finished ? pattern.duration : timeline.date.timeIntervalSince(startedAt))
            Canvas { context, size in
                let side = min(size.width, size.height)
                let margin = max(22.0, side * 0.067)
                let spacing = max(1, side - margin * 2) / 14
                let gold = Color(hex: 0xE4B84C)
                let light = Color(hex: 0xFFF0B3)
                func point(_ move: Move) -> CGPoint {
                    CGPoint(x: margin + Double(move.column) * spacing, y: margin + Double(move.row) * spacing)
                }
                for move in frame.lit {
                    let center = point(move)
                    let pulse = move == frame.active ? frame.pulse : 0
                    let radius = spacing * (0.46 + pulse * 0.045)
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.drawLayer { glow in
                        glow.addFilter(.shadow(color: gold.opacity(0.85), radius: spacing * (0.08 + pulse * 0.2)))
                        glow.stroke(ring, with: .color(gold), lineWidth: max(1.8, spacing * (0.065 + pulse * 0.03)))
                    }
                    context.stroke(ring, with: .color(light.opacity(0.55 + pulse * 0.45)), lineWidth: max(0.7, spacing * 0.022))
                }
                if frame.lineProgress > 0 {
                    for run in pattern.runs {
                        let start = point(run.start), end = point(run.end)
                        var line = Path()
                        line.move(to: start)
                        line.addLine(to: CGPoint(x: start.x + (end.x - start.x) * frame.lineProgress,
                                                y: start.y + (end.y - start.y) * frame.lineProgress))
                        context.drawLayer { glow in
                            glow.addFilter(.shadow(color: gold, radius: spacing * 0.14))
                            glow.stroke(line, with: .color(gold), style: StrokeStyle(lineWidth: max(2, spacing * 0.07), lineCap: .round))
                        }
                        context.stroke(line, with: .color(light), lineWidth: max(0.8, spacing * 0.025))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.choose("완성된 승리 줄", "Winning line", language))
        .accessibilityValue(pattern.runs.map { "\($0.start.coordinate) → \($0.end.coordinate)" }.joined(separator: ", "))
        .task(id: startedAt) {
            finished = false
            let remaining = pattern.duration - Date().timeIntervalSince(startedAt)
            if remaining > 0 && !reduceMotion {
                do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            finished = true
        }
    }
}
