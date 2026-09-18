import SwiftUI

struct AppSettingsView: View {
    @Binding var languageRaw: String
    @Binding var appearanceRaw: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }
    private var theme: GomokuTheme { GomokuTheme(scheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("settingsTitle", language))
                        .font(.system(.largeTitle, design: .serif, weight: .medium))
                    Text(L10n.text("settingsSubtitle", language))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Label(L10n.text("appearance", language), systemImage: "paintpalette")
                            .font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                                 count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
                            ForEach(AppearanceMode.allCases) { mode in
                                SelectionTile(selected: appearanceRaw == mode.rawValue,
                                              action: { appearanceRaw = mode.rawValue }) {
                                    VStack(spacing: 12) {
                                        AppearancePreview(mode: mode)
                                            .frame(height: 80)
                                        Label(L10n.appearance(mode, language: language), systemImage: mode.symbol)
                                            .font(.caption.weight(.semibold))
                                            .multilineTextAlignment(.center)
                                        Image(systemName: appearanceRaw == mode.rawValue
                                              ? "checkmark.circle.fill" : "circle")
                                            .font(.subheadline)
                                    }
                                }
                                .accessibilityIdentifier("appearance.\(mode.rawValue)")
                            }
                        }
                        Text(L10n.text("systemAppearanceHelp", language))
                            .font(.footnote)
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(L10n.text("effectiveAppearance", language))
                            Spacer()
                            Label(L10n.text(scheme == .dark ? "dark" : "light", language),
                                  systemImage: scheme == .dark ? "moon.fill" : "sun.max.fill")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.accent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.text("effectiveAppearance", language))
                        .accessibilityValue(scheme == .dark ? "dark" : "light")
                        .accessibilityIdentifier("effectiveAppearance")
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(L10n.text("language", language), systemImage: "globe")
                            .font(.headline)
                        ForEach(AppLanguage.allCases) { option in
                            SelectionTile(selected: languageRaw == option.rawValue,
                                          action: { languageRaw = option.rawValue }) {
                                HStack {
                                    Text(option.displayName).font(.body.weight(.medium))
                                    Spacer()
                                    if languageRaw == option.rawValue {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                            }
                            .accessibilityIdentifier("language.\(option.rawValue)")
                        }
                    }
                }
                Text(L10n.text("settingsSaved", language))
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(22)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background { GameBackdrop() }
        .foregroundStyle(theme.ink)
        .tint(theme.accent)
        .navigationTitle(L10n.text("appSettings", language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.text("done", language)) { dismiss() }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("closeSettings")
            }
        }
    }
}

private struct AppearancePreview: View {
    let mode: AppearanceMode

    var body: some View {
        GeometryReader { geo in
            ZStack {
                preview(dark: mode == .dark)
                if mode == .system {
                    preview(dark: true)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: geo.size.width / 2)
                        }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }

    private func preview(dark: Bool) -> some View {
        let palette = GomokuTheme(dark ? .dark : .light)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 3) {
                Circle().fill(palette.accent).frame(width: 5, height: 5)
                Capsule().fill(palette.ink.opacity(0.7)).frame(width: 20, height: 4)
                Spacer(minLength: 0)
            }
            RoundedRectangle(cornerRadius: 5).fill(palette.surface)
                .overlay(alignment: .leading) {
                    HStack(spacing: 5) {
                        StoneDisc(stone: .black, size: 12)
                        StoneDisc(stone: .white, size: 12)
                    }.padding(6)
                }
            Capsule().fill(palette.accent).frame(height: 8)
        }
        .padding(10)
        .background(palette.background)
    }
}
