import DesignSystem
import SwiftUI

/// The map tab: every world for the child home shows, each open (ADR-0061 §2, §3). Home's presenter owns the map, so
/// the tab reloads home when it appears and when the app comes back from the background. Choosing a world shows it on
/// home, and the root moves to Adventure. On an iPhone Duo half-open like a laptop the path lies below the fold and
/// the world the dad tapped, or the one home shows, stands above it, large (ADR-0061 §4).
public struct WorldMapView: View {
    private let viewModel: HomeViewModel
    private let onWorldChosen: @MainActor () -> Void
    @Environment(\.scenePhase) private var scenePhase
    /// Set while the app is in the background, so coming back reloads once (not after Control Center or Face ID).
    @State private var wasInBackground = false
    @State private var fold: HorizontalFold?
    /// The world the dad tapped while the path was below a fold.
    @State private var previewedID: String?

    /// - Parameters:
    ///   - viewModel: home's presenter, which builds the map with every load.
    ///   - onWorldChosen: a world was chosen; home shows it, and the root moves to Adventure.
    public init(viewModel: HomeViewModel, onWorldChosen: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.onWorldChosen = onWorldChosen
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let map = viewModel.worldMap, case .loaded(let content) = viewModel.state {
                    loaded(map, content: content)
                } else if case .failed(let message) = viewModel.state {
                    ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Read where the panes are placed, so the fold is in their coordinates.
            .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum) { fold = $0 }
            .background(DSColor.background)
            .navigationTitle(viewModel.worldMap?.title ?? "")
            // A large title collapses as the path scrolls and would move the fold's place in both panes.
            .toolbarTitleDisplayMode(fold == nil ? .automatic : .inline)
        }
        // What Settings changed, a record on home or another day: the map shows home as it is now.
        .task { await viewModel.reload() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                wasInBackground = true
            case .active where wasInBackground:
                wasInBackground = false
                Task { await viewModel.appBecameActive() }
            default:
                break
            }
        }
    }

    private func loaded(_ map: WorldMapContent, content: HomeContent) -> some View {
        // The world above the fold: the one tapped, else the one home shows. None on a flat display.
        let previewed = fold == nil ? nil : map.worlds.first { $0.id == previewedID } ?? map.shownWorld
        let panes = (previewed == nil ? nil : fold).map { AnyLayout(FoldedStackLayout(fold: $0)) }
            ?? AnyLayout(VStackLayout(spacing: 0))
        // The same path in both layouts, so a fold keeps where it was scrolled to.
        return panes {
            if let previewed {
                WorldMapPreview(world: previewed, openTitle: map.openTitle) { choose(previewed.id) }
                    .id(previewed.id)
            }
            path(map, content: content, previewedID: previewed?.id)
        }
        .motion(.smooth, value: previewed?.id)
        .onChange(of: content.selectedChildID) { previewedID = nil }
    }

    private func path(_ map: WorldMapContent, content: HomeContent, previewedID: String?) -> some View {
        let isSplit = previewedID != nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if content.childTabs.isEmpty {
                    Text(map.subtitle)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.bottom, DSSpacing.m)
                } else {
                    // A child chosen here is home's.
                    ChildPicker(content: content) { id in Task { await viewModel.selectChild(id: id) } }
                }
                WorldMapPath(map: map, markedID: previewedID ?? map.worlds.first(where: \.isShown)?.id) { id in
                    if isSplit { self.previewedID = id } else { choose(id) }
                }
            }
            .frame(maxWidth: readableWidth, alignment: .leading)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
    }

    /// Shows the world on home and leaves the map for Adventure.
    private func choose(_ id: String) {
        // Back on the map later, the world home shows stands above the fold again, not this old tap.
        previewedID = nil
        Task { await viewModel.showWorld(id: id) }
        onWorldChosen()
    }
}
