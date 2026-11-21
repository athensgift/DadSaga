import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Draws the window this view is in, and every sheet it presents, in the dad's choice (ADR-0049).
    ///
    /// Sets the window's own `overrideUserInterfaceStyle`, which UIKit passes to every presentation and fully undoes
    /// for Automatic. `preferredColorScheme(nil)` does not: a sheet open while the dad goes back to Automatic keeps the
    /// last look it was given until it is closed.
    func windowAppearance(_ choice: AppearanceChoice) -> some View {
        #if os(iOS)
        background(WindowAppearance(style: choice.interfaceStyle))
        #else
        // macOS only builds the package to run its tests.
        self
        #endif
    }
}

#if os(iOS)
extension AppearanceChoice {
    /// `.unspecified` follows the iPhone.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// An empty view that sets the look of the window it is placed in.
private struct WindowAppearance: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> WindowAppearanceView {
        WindowAppearanceView()
    }

    func updateUIView(_ view: WindowAppearanceView, context: Context) {
        view.style = style
    }
}

private final class WindowAppearanceView: UIView {
    var style: UIUserInterfaceStyle = .unspecified {
        didSet { apply() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The window is known only once the view is in it, after the first update.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        apply()
    }

    private func apply() {
        guard let window, window.overrideUserInterfaceStyle != style else { return }
        window.overrideUserInterfaceStyle = style
    }
}
#endif
