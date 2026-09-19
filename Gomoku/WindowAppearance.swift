import SwiftUI
import UIKit

/// Own the override at the window so sheets inherit it and System always
/// clears a previous explicit preference. No forced SwiftUI colorScheme is
/// left on a hosting controller when the user returns to System.
struct WindowAppearance: UIViewRepresentable {
    let mode: AppearanceMode

    func makeUIView(context: Context) -> AppearanceView {
        let view = AppearanceView()
        view.mode = mode
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: AppearanceView, context: Context) {
        uiView.mode = mode
        // Defer trait propagation until the current SwiftUI update finishes.
        // Read the view's latest mode, so rapid changes cannot restore an old one.
        DispatchQueue.main.async { [weak uiView] in
            uiView?.applyAppearance()
        }
    }

    final class AppearanceView: UIView {
        var mode: AppearanceMode = .system

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyAppearance()
        }

        func applyAppearance() {
            guard let window else { return }
            let style: UIUserInterfaceStyle
            switch mode {
            case .system: style = .unspecified
            case .light: style = .light
            case .dark: style = .dark
            }
            if window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
