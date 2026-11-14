import DesignSystem
import SwiftUI

/// The family's history: a section per month, newest first, for everyone or one child.
public struct TimelineView: View {
    @State private var viewModel: TimelineViewModel

    public init(viewModel: TimelineViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let content):
                    loaded(content)
                case .failed(let message):
                    ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.background)
            .navigationTitle(title)
        }
        .task { await viewModel.onAppear() }
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    private func loaded(_ content: TimelineContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.s, pinnedViews: [.sectionHeaders]) {
                if !content.filters.isEmpty {
                    Picker(
                        content.title,
                        selection: Binding(get: { content.selectedFilter }, set: { viewModel.select(filter: $0) })
                    ) {
                        ForEach(content.filters) { filter in
                            Text(filter.title).tag(filter.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, DSSpacing.s)
                }
                if content.sections.isEmpty {
                    ContentUnavailableView(
                        content.emptyTitle,
                        systemImage: "clock.arrow.circlepath",
                        description: Text(content.emptyMessage)
                    )
                    .padding(.top, DSSpacing.xl)
                }
                ForEach(content.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            TimelineRow(item: item) { await viewModel.photoData(id: $0) }
                        }
                    } header: {
                        Text(section.title)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DSSpacing.m)
                            .padding(.bottom, DSSpacing.xs)
                            .background(DSColor.background)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .frame(maxWidth: readableWidth)
            .padding(.horizontal, DSSpacing.m)
            .padding(.bottom, DSSpacing.l)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TimelineRow: View {
    let item: TimelineItem
    let loader: PhotoLoader

    private var tint: Color {
        switch item.kind {
        case .quest: DSColor.accent
        case .boss: DSColor.boss
        case .moment: DSColor.legendary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            MomentPhoto(photoID: item.photoID, loader: loader) {
                Image(systemName: item.symbol)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(DSColor.heroHighlight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint.gradient)
            }
            .frame(width: item.photoID == nil ? 36 : 64, height: item.photoID == nil ? 36 : 64)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s) {
                    Text(item.title)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer(minLength: 0)
                    Text(item.badge)
                        .font(DSFont.caption)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .fixedSize()
                }
                Text(item.subtitle)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
