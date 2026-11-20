import SwiftUI

/// A scroll view for the pane below a fold (ADR-0043). While `alignsBottom`, content shorter than the pane sits at
/// its bottom: the lower half lies on the table, and its buttons belong near the hands, not up against the fold.
/// Content taller than the pane scrolls from its top as usual.
struct BottomAlignedScrollView<Content: View>: View {
    let alignsBottom: Bool
    @ViewBuilder let content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .frame(minHeight: alignsBottom ? height : nil, alignment: .bottom)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }
}
