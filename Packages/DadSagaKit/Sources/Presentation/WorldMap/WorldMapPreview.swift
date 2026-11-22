import DesignSystem
import SwiftUI

/// One world, large, above the fold on an iPhone Duo half-open like a laptop (ADR-0061 §4): its number, ages, name,
/// tagline, its ideal or progress line, its tag, and "Open this world".
struct WorldMapPreview: View {
    let world: WorldMapItem
    let openTitle: String
    let onOpen: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var markerSize: CGFloat = 64

    var body: some View {
        // Scrolls only when the words are too large for the pane.
        ScrollView {
            AdaptiveStack(alignment: .center, spacing: DSSpacing.l) {
                WorldMarker(world: world, size: markerSize)
                VStack(alignment: .leading, spacing: DSSpacing.s) {
                    WorldAgesAndTag(world: world)
                    Text(world.title)
                        .font(DSFont.title)
                        .foregroundStyle(DSColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(world.tagline)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    WorldLines(world: world)
                    Button(openTitle, systemImage: "arrow.right.circle", action: onOpen)
                        .buttonStyle(.glass)
                        .padding(.top, DSSpacing.s)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
