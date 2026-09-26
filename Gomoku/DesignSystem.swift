import SwiftUI

/// Design language: "먹과 나무" — hanji paper, sumi ink and kaya wood, with a
/// single vermilion (주홍) seal colour reserved for what matters right now:
/// primary actions, the last move, forbidden points and low time.
/// Pine (솔) is the quiet secondary colour for turn and reserve state.
///
/// Every property name from the previous theme is kept, so screens that are not
/// part of this change (achievements, history, results, settings) pick up the new
/// palette automatically.
struct GomokuTheme {
    let scheme: ColorScheme
    init(_ scheme: ColorScheme) { self.scheme = scheme }
    var isDark: Bool { scheme == .dark }

    // Paper (한지) and ink (먹)
    var background: Color { Color(hex: isDark ? 0x1B1916 : 0xF4EFE6) }
    var surface: Color { Color(hex: isDark ? 0x25221E : 0xFBF8F1) }
    var inset: Color { Color(hex: isDark ? 0x2F2B25 : 0xEBE4D4) }
    var ink: Color { Color(hex: isDark ? 0xF0EADC : 0x2B2823) }
    var secondary: Color { Color(hex: isDark ? 0xB5AC99 : 0x6B6558) }
    var border: Color { Color(hex: isDark ? 0x413B32 : 0xDDD3BF) }

    // Vermilion seal (주홍): the one accent
    var accent: Color { Color(hex: isDark ? 0xE07A5F : 0xB8432F) }
    var onAccent: Color { Color(hex: isDark ? 0x2A140D : 0xFFF8EE) }
    var accentWash: Color { Color(hex: isDark ? 0x3A2620 : 0xF3DFD6) }
    var danger: Color { Color(hex: isDark ? 0xF0917A : 0xA8362A) }

    // Pine (솔): calm state such as the active turn and a healthy time reserve
    var calm: Color { Color(hex: isDark ? 0x86AE94 : 0x3F5B4B) }
    var onCalm: Color { Color(hex: isDark ? 0x14201A : 0xFFF8EE) }
    var calmWash: Color { Color(hex: isDark ? 0x25302A : 0xE1E8DE) }

    // Kaya wood board (카야). The board stays light wood in Dark mode, only dimmer.
    var board: Color { Color(hex: isDark ? 0xB5945A : 0xE6C892) }
    var boardEdge: Color { Color(hex: isDark ? 0x8A6E3F : 0xC7A468) }
    var grid: Color { Color(hex: isDark ? 0x4A3A22 : 0x5B4630) }
    var boardLabel: Color { Color(hex: isDark ? 0x2E2416 : 0x5E4A2E) }
    var boardAccent: Color { Color(hex: isDark ? 0x8C2818 : 0xB8432F) }
}

/// Radii step down with the size of the thing they round.
enum GomokuRadius {
    static let card: CGFloat = 24
    static let control: CGFloat = 14
    static let tile: CGFloat = 12
    static let chip: CGFloat = 8
}

extension Font {
    /// Serif voice for titles and section names.
    static func gomokuTitle(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// Fixed-width digits so clocks never jitter while time runs down.
    static func gomokuClock(_ style: Font.TextStyle, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
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
            .background(GomokuTheme(scheme).surface,
                        in: RoundedRectangle(cornerRadius: GomokuRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GomokuRadius.card, style: .continuous)
                    .strokeBorder(GomokuTheme(scheme).border, lineWidth: 1)
            }
    }
}

/// The 낙관 (seal) used as the app mark: 五目 stamped in vermilion.
struct HankoSeal: View {
    var size: CGFloat = 42
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = GomokuTheme(scheme)
        let radius = size * 0.2
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(theme.accent)
            .frame(width: size, height: size)
            .overlay {
                VStack(spacing: -size * 0.03) {
                    Text("五")
                    Text("目")
                }
                .font(.system(size: size * 0.36, weight: .bold, design: .serif))
                .foregroundStyle(theme.onAccent)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(2, radius - 3), style: .continuous)
                    .strokeBorder(theme.onAccent.opacity(0.4), lineWidth: 1)
                    .padding(3)
            }
            .accessibilityHidden(true)
    }
}

struct StoneDisc: View {
    let stone: Stone
    var size: CGFloat = 28

    var body: some View {
        let black = stone == .black
        Circle()
            .fill(RadialGradient(
                colors: black
                    ? [Color(hex: 0x504B44), Color(hex: 0x14120F)]
                    : [Color(hex: 0xFFFEFA), Color(hex: 0xE1D9C6)],
                center: UnitPoint(x: 0.34, y: 0.3),
                startRadius: 0,
                endRadius: size * 0.8
            ))
            .overlay {
                Circle().strokeBorder(
                    black ? Color.white.opacity(0.14) : Color(hex: 0x8F846E).opacity(0.55),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.18), radius: max(1, size * 0.07), x: 0, y: max(1, size * 0.06))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Primary actions are vermilion, secondary actions sit on paper, and the final
/// boss is oxblood with a vermilion edge.
struct GomokuButtonStyle: ButtonStyle {
    var primary = true
    var boss = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let theme = GomokuTheme(scheme)
        let shape = RoundedRectangle(cornerRadius: GomokuRadius.control, style: .continuous)
        let foreground: Color = boss ? Color(hex: 0xFFEFE6) : primary ? theme.onAccent : theme.ink
        let fill: Color = boss ? Color(hex: 0x3A1512) : primary ? theme.accent : theme.inset
        let edge: Color = boss ? Color(hex: 0xE07A5F).opacity(0.85)
            : primary ? Color.black.opacity(0.14) : theme.border
        configuration.label
            .font(.system(.body, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 14)
            .foregroundStyle(foreground)
            .background(fill, in: shape)
            .overlay { shape.strokeBorder(edge, lineWidth: boss ? 1.5 : 1) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(shape)
    }
}

struct QuietIconButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GomokuRadius.tile + 1, style: .continuous)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 46, height: 46)
                .foregroundStyle(GomokuTheme(scheme).ink)
                .background(GomokuTheme(scheme).surface, in: shape)
                .overlay { shape.strokeBorder(GomokuTheme(scheme).border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A compact chip for vertically scrollable adaptive grids (stone, difficulty,
/// time). Pass `width: nil` to let the chip flex to fill its grid cell. The chip is shared
/// by the home screen and the local-play setup screen so every choice in the app
/// reads as one family of controls.
struct RailChip<Content: View>: View {
    let selected: Bool
    var width: CGFloat? = 112
    let action: () -> Void
    private let content: Content
    @Environment(\.colorScheme) private var scheme

    init(selected: Bool, width: CGFloat? = 112, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.selected = selected
        self.width = width
        self.action = action
        self.content = content()
    }

    var body: some View {
        let theme = GomokuTheme(scheme)
        let shape = RoundedRectangle(cornerRadius: GomokuRadius.tile, style: .continuous)
        Button(action: action) {
            content
                .frame(maxWidth: width == nil ? .infinity : nil)
                .frame(width: width)
                .frame(minHeight: 82)
                .padding(10)
                .foregroundStyle(selected ? theme.ink : theme.secondary)
                .background(selected ? theme.accentWash : theme.inset.opacity(0.6), in: shape)
                .overlay {
                    shape.strokeBorder(selected ? theme.accent : theme.border.opacity(0.6),
                                       lineWidth: selected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Selected tiles are washed in vermilion and outlined; the label stays ink so
/// small text keeps its contrast.
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
        let shape = RoundedRectangle(cornerRadius: GomokuRadius.tile, style: .continuous)
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(12)
                .foregroundStyle(selected ? theme.ink : theme.secondary)
                .background(selected ? theme.accentWash : theme.inset.opacity(0.6), in: shape)
                .overlay {
                    shape.strokeBorder(selected ? theme.accent : theme.border.opacity(0.6),
                                       lineWidth: selected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Section title with a hairline rule, so a long setup card reads as separate steps.
struct SectionCaption: View {
    let number: String
    let title: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(GomokuTheme(scheme).accent)
            Text(title)
                .font(.gomokuTitle(.subheadline))
                .foregroundStyle(GomokuTheme(scheme).ink)
            Rectangle()
                .fill(GomokuTheme(scheme).border)
                .frame(height: 1)
                .accessibilityHidden(true)
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
        .font(.system(.caption, weight: .medium))
        .foregroundStyle(GomokuTheme(scheme).secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(GomokuTheme(scheme).inset,
                    in: RoundedRectangle(cornerRadius: GomokuRadius.chip, style: .continuous))
    }
}

/// A decorative study of five stones on a kaya board; actual play always uses the 15×15 board.
struct WelcomeArtwork: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let theme = GomokuTheme(scheme)
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        ZStack {
            shape.fill(theme.board)
            shape.strokeBorder(theme.boardEdge, lineWidth: 2)
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
                context.stroke(grid, with: .color(theme.grid.opacity(0.85)), lineWidth: 1)
                let dot = Path(ellipseIn: CGRect(x: size.width / 2 - 3, y: size.height / 2 - 3,
                                                width: 6, height: 6))
                context.fill(dot, with: .color(theme.grid))
            }
            GeometryReader { geo in
                let step = geo.size.width / 8
                ForEach(0..<5) { index in
                    StoneDisc(stone: index.isMultiple(of: 2) ? .black : .white, size: step * 0.83)
                        .position(x: step * CGFloat(index + 2), y: step * CGFloat(index + 2))
                }
                Circle().stroke(theme.boardAccent, lineWidth: 2)
                    .frame(width: step * 0.98, height: step * 0.98)
                    .position(x: step * 6, y: step * 6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
