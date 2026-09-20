import SwiftUI

/// Semantic colors shared by every screen, including sheets and the board.
struct GomokuTheme {
    let scheme: ColorScheme
    init(_ scheme: ColorScheme) { self.scheme = scheme }
    var isDark: Bool { scheme == .dark }

    var background: Color { Color(hex: isDark ? 0x121B19 : 0xF5F3EC) }
    var surface: Color { Color(hex: isDark ? 0x1B2723 : 0xFFFEFA) }
    var inset: Color { Color(hex: isDark ? 0x24332D : 0xEEEEE5) }
    var ink: Color { Color(hex: isDark ? 0xF0F2E9 : 0x1C3028) }
    var secondary: Color { Color(hex: isDark ? 0xADBAB2 : 0x5E6C62) }
    var accent: Color { Color(hex: isDark ? 0xA9D5BC : 0x27624B) }
    var onAccent: Color { Color(hex: isDark ? 0x163426 : 0xFFFFFF) }
    var accentWash: Color { Color(hex: isDark ? 0x2A4135 : 0xE8F0E7) }
    var border: Color { Color(hex: isDark ? 0x39493F : 0xDADFD3) }
    var board: Color { Color(hex: isDark ? 0x566553 : 0xDDD0AC) }
    var boardEdge: Color { Color(hex: isDark ? 0x354438 : 0xC4B38C) }
    var grid: Color { Color(hex: isDark ? 0x26382B : 0x928362) }
    var boardLabel: Color { Color(hex: isDark ? 0xF0F0DA : 0x5B503B) }
    var boardAccent: Color { Color(hex: isDark ? 0xD2F4AA : 0x205A42) }
    var danger: Color { Color(hex: isDark ? 0xF7B5A7 : 0xA13C2F) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

struct GameBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { GomokuTheme(scheme).background.ignoresSafeArea() }
}

struct SurfaceCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(22)
            .background(GomokuTheme(scheme).surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(GomokuTheme(scheme).border.opacity(0.65), lineWidth: 1)
            }
    }
}

struct StoneDisc: View {
    let stone: Stone
    var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: stone == .black
                    ? [Color(hex: 0x465149), Color(hex: 0x111B16)]
                    : [Color(hex: 0xFFFFFF), Color(hex: 0xDFE4D9)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .overlay {
                Circle().strokeBorder(
                    stone == .black ? Color.white.opacity(0.2) : Color.black.opacity(0.16),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 2)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct GomokuButtonStyle: ButtonStyle {
    var primary = true
    var boss = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let theme = GomokuTheme(scheme)
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 14)
            .foregroundStyle(boss ? .white : primary ? theme.onAccent : theme.ink)
            .background(boss ? Color(hex: 0xA51F35) : primary ? theme.accent : theme.inset, in: RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct QuietIconButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 46, height: 46)
                .foregroundStyle(GomokuTheme(scheme).ink)
                .background(GomokuTheme(scheme).surface, in: Circle())
                .overlay { Circle().strokeBorder(GomokuTheme(scheme).border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct SelectionTile<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    private let content: Content
    @Environment(\.colorScheme) private var scheme

    init(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.selected = selected
        self.action = action
        self.content = content()
    }

    var body: some View {
        let theme = GomokuTheme(scheme)
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(12)
                .foregroundStyle(selected ? theme.accent : theme.secondary)
                .background(selected ? theme.accentWash : theme.inset.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(selected ? theme.accent : theme.border.opacity(0.45),
                                      lineWidth: selected ? 1.6 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SectionCaption: View {
    let number: String
    let title: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(GomokuTheme(scheme).secondary)
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(GomokuTheme(scheme).ink)
        }
    }
}

struct SmallBadge: View {
    let text: String
    var symbol: String? = nil
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.system(.caption, design: .rounded, weight: .medium))
        .foregroundStyle(GomokuTheme(scheme).secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(GomokuTheme(scheme).inset, in: Capsule())
    }
}

/// A decorative study of five stones; actual play always uses the 15×15 board.
struct WelcomeArtwork: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let theme = GomokuTheme(scheme)
        ZStack {
            RoundedRectangle(cornerRadius: 44)
                .fill(theme.inset)
            Canvas { context, size in
                let step = size.width / 8
                var grid = Path()
                for index in 1..<8 {
                    let offset = CGFloat(index) * step
                    grid.move(to: CGPoint(x: step, y: offset))
                    grid.addLine(to: CGPoint(x: size.width - step, y: offset))
                    grid.move(to: CGPoint(x: offset, y: step))
                    grid.addLine(to: CGPoint(x: offset, y: size.height - step))
                }
                context.stroke(grid, with: .color(theme.border), lineWidth: 1)
                let dot = Path(ellipseIn: CGRect(x: size.width / 2 - 3, y: size.height / 2 - 3,
                                                width: 6, height: 6))
                context.fill(dot, with: .color(theme.secondary))
            }
            GeometryReader { geo in
                let step = geo.size.width / 8
                ForEach(0..<5) { index in
                    StoneDisc(stone: index.isMultiple(of: 2) ? .black : .white, size: step * 0.83)
                        .position(x: step * CGFloat(index + 2), y: step * CGFloat(index + 2))
                }
                Circle().stroke(theme.accent, lineWidth: 2)
                    .frame(width: step * 0.98, height: step * 0.98)
                    .position(x: step * 6, y: step * 6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
