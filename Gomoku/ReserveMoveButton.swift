import SwiftUI

/// The whole action surface is a time reserve. Text changes colour at the
/// fill boundary, keeping its contrast on both the track and the filled area.
struct ReserveMoveButton: View {
    let title: String
    let coordinate: String?
    let fraction: Double
    let urgent: Bool
    let busy: Bool
    let enabled: Bool
    let accessibilityTitle: String
    let accessibilityTime: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var theme: GomokuTheme { GomokuTheme(scheme) }
    private var fill: Color { urgent ? theme.danger : theme.accent }
    private var fillInk: Color { urgent && theme.isDark ? Color(hex: 0x421E17) : theme.onAccent }
    private var progress: CGFloat { CGFloat(min(1, max(0, fraction))) }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: busy ? "ellipsis" : enabled ? "checkmark.circle.fill" : "circle.dotted")
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            if let coordinate {
                Text(coordinate).font(.system(.subheadline, design: .monospaced, weight: .medium))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 23)
        .frame(maxWidth: .infinity, minHeight: 74)
        .accessibilityHidden(true)
    }

    var body: some View {
        Button(action: action) {
            label.foregroundStyle(theme.ink)
                .background {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            theme.inset
                            fill.frame(width: geometry.size.width * progress)
                            // Quarter marks make the reserve legible at a glance.
                            ForEach(1..<4) { mark in
                                Rectangle().fill(theme.background.opacity(0.18))
                                    .frame(width: 1)
                                    .offset(x: geometry.size.width * CGFloat(mark) / 4)
                            }
                        }
                    }
                }
                .overlay {
                    label.foregroundStyle(fillInk)
                        .mask {
                            GeometryReader { geometry in
                                Rectangle().frame(width: geometry.size.width * progress)
                            }
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(fill.opacity(enabled ? 0.8 : 0.25), lineWidth: 1)
                }
        }
        .buttonStyle(ReservePressStyle())
        .disabled(!enabled)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityTime)
        .accessibilityIdentifier("confirmMove")
    }
}

private struct ReservePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // The disabled action still conveys live time, so keep the gauge and
        // its text at full contrast while the player chooses an intersection.
        configuration.label.opacity(configuration.isPressed ? 0.9 : 1)
    }
}
