import SwiftUI

/// Its views side by side, or one under the other from the accessibility text sizes on, where a row has no room
/// left for both. Stacked, it adds a little space above and below, so the stack doesn't touch the row's edges.
/// Give a label `.frame(maxWidth: .infinity, alignment: .leading)` rather than a `Spacer`, so the row reads the same
/// in both layouts.
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let alignment: VerticalAlignment
    private let spacing: CGFloat?
    private let content: Content

    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        layout { content }
            .padding(.vertical, isStacked ? DSSpacing.xs : 0)
    }
}

/// A card's title with its badge, e.g. "+30 XP" or "BOSS": the badge at the trailing edge, or under the title from
/// the accessibility text sizes on, so the title keeps the whole width.
public struct CardTitle: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    /// e.g. "BOSS"; `nil` for none.
    let badge: String?
    let tint: Color

    public init(_ title: String, badge: String? = nil, tint: Color) {
        self.title = title
        self.badge = badge
        self.tint = tint
    }

    public var body: some View {
        if badge == nil {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                titleText
                badgeText
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s) {
                titleText
                Spacer(minLength: 0)
                badgeText
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(DSFont.headline)
            .foregroundStyle(DSColor.textPrimary)
    }

    private var badgeText: some View {
        Text(badge ?? "")
            .font(DSFont.caption)
            .foregroundStyle(tint)
    }
}
