import DesignSystem
import SwiftUI

/// What the field being written in offers its sheet: a way to put the keyboard away, and its name.
struct HideKeyboardAction {
    let title: String
    let hide: @MainActor () -> Void

    init(title: String, hide: @escaping @MainActor () -> Void) {
        self.title = title
        self.hide = hide
    }
}

extension FocusedValues {
    /// Set by the note field while it has the keyboard.
    @Entry var hideKeyboard: HideKeyboardAction?
}

/// A button just above the keyboard that puts it away, while a note is being written. It is part of the layout (a
/// safe-area inset), so the line being written stays above it; the system's own bar over the keyboard floats over
/// the content on iOS 27 and covered the end of that line.
struct HideKeyboardBar: ViewModifier {
    @FocusedValue(\.hideKeyboard) private var action

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if let action {
                Button(action.title, systemImage: "keyboard.chevron.compact.down") { action.hide() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, DSSpacing.m)
                    .padding(.vertical, DSSpacing.s)
            }
        }
    }
}
