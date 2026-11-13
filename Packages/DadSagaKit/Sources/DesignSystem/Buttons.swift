import SwiftUI

/// The main call-to-action button: full width, filled with the accent colour.
public struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(DSColor.heroHighlight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.m)
            .background(DSColor.accent.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: DSRadius.card))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle { DSPrimaryButtonStyle() }
}
