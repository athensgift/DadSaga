import DesignSystem
import SwiftUI

/// The family's history, newest first, for everyone or one child: entries hang off a vertical
/// chronology line, and each month is a node on that line.
public struct TimelineView: View {
    @State private var viewModel: TimelineViewModel
    private let isOpeningLink: Bool

    /// - Parameter isOpeningLink: a link from outside the app (the widget) is opening on another tab; the journal
    ///   editor closes so it does not cover that screen.
    public init(viewModel: TimelineViewModel, isOpeningLink: Bool = false) {
        _viewModel = State(initialValue: viewModel)
        self.isOpeningLink = isOpeningLink
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
        .confirmationDialog(
            viewModel.deletion?.title ?? "",
            isPresented: Binding(get: { viewModel.deletion != nil }, set: { if !$0 { viewModel.cancelDeletion() } }),
            titleVisibility: .visible,
            presenting: viewModel.deletion
        ) { prompt in
            Button(prompt.confirmTitle, role: .destructive) {
                Task { await viewModel.confirmDeletion(id: prompt.id) }
            }
            Button(prompt.cancelTitle, role: .cancel) { viewModel.cancelDeletion() }
        } message: { prompt in
            Text(prompt.message)
        }
        .onChange(of: isOpeningLink) { _, opening in
            if opening { viewModel.closeJournal() }
        }
        .sheet(item: Binding(get: { viewModel.journalEditor }, set: { if $0 == nil { viewModel.closeJournal() } })) { editor in
            JournalEditorSheet(
                editor: editor,
                isSaving: viewModel.isSaving,
                loader: { await viewModel.photoData(id: $0) },
                onSave: { note, photo in Task { await viewModel.saveJournal(note: note, photo: photo) } },
                onClose: { viewModel.closeJournal() }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(
            viewModel.errorMessage ?? "",
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.dismissError() })
        ) {}
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    private func loaded(_ content: TimelineContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
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
                ForEach(Array(content.sections.enumerated()), id: \.element.id) { index, section in
                    MonthNode(title: section.title, isFirst: index == 0)
                    ForEach(section.items) { item in
                        row(item, isLast: index == content.sections.count - 1 && item.id == section.items.last?.id)
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

private extension TimelineView {
    /// A row that opens its note and photo when tapped, and can be deleted from its context menu.
    func row(_ item: TimelineItem, isLast: Bool) -> some View {
        Button {
            viewModel.editJournal(id: item.id)
        } label: {
            TimelineRow(item: item, isLast: isLast) { await viewModel.photoData(id: $0) }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(viewModel.editTitle, systemImage: "square.and.pencil") {
                viewModel.editJournal(id: item.id)
            }
            Button(viewModel.deleteTitle, systemImage: "trash", role: .destructive) {
                viewModel.requestDeletion(id: item.id)
            }
        }
        .accessibilityAction(named: viewModel.deleteTitle) {
            viewModel.requestDeletion(id: item.id)
        }
    }
}

/// Width of the column that holds the chronology line and the entry icons.
private let railWidth: CGFloat = 36

/// The chronology line: a thin vertical stroke centred in the rail, optionally cut at the top or bottom
/// so the line starts at the first month and ends at the last entry.
private struct RailLine: View {
    var startsHere = false
    var endsHere = false

    var body: some View {
        GeometryReader { proxy in
            let top = startsHere ? proxy.size.height / 2 : 0
            let bottom = endsHere ? proxy.size.height / 2 : proxy.size.height
            Rectangle()
                .fill(DSColor.textSecondary.opacity(0.3))
                .frame(width: 2, height: max(bottom - top, 0))
                .offset(x: (proxy.size.width - 2) / 2, y: top)
        }
        .frame(width: railWidth)
        .accessibilityHidden(true)
    }
}

/// A month on the chronology line: a dot on the line and the month's name beside it.
private struct MonthNode: View {
    let title: String
    let isFirst: Bool

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            Circle()
                .fill(DSColor.textSecondary)
                .frame(width: 10, height: 10)
                .frame(width: railWidth)
            Text(title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, isFirst ? DSSpacing.s : DSSpacing.l)
        .padding(.bottom, DSSpacing.s)
        .background(alignment: .leading) { RailLine(startsHere: isFirst) }
        .accessibilityAddTraits(.isHeader)
    }
}

private struct TimelineRow: View {
    let item: TimelineItem
    let isLast: Bool
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
            Image(systemName: item.symbol)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(DSColor.heroHighlight)
                .frame(width: railWidth, height: railWidth)
                .background(tint.gradient, in: Circle())
                .overlay(Circle().stroke(DSColor.background, lineWidth: 3))
                .padding(.top, DSSpacing.m)
                .accessibilityHidden(true)
            card
        }
        .padding(.vertical, DSSpacing.xs)
        .background(alignment: .leading) { RailLine(endsHere: isLast) }
    }

    private var card: some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            if item.photoID != nil {
                MomentPhoto(photoID: item.photoID, loader: loader) { tint.opacity(0.2) }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
                    .accessibilityHidden(true)
            }
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
