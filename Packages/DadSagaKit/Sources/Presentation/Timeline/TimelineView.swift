import DesignSystem
import SwiftUI

/// The family's history, newest first, for everyone or one child: entries hang off a vertical
/// chronology line, and each month is a node on that line. On an iPhone Duo half-open like a laptop the list lies
/// below the fold and the entry the dad taps stands above it, large (ADR-0043).
public struct TimelineView: View {
    @State private var viewModel: TimelineViewModel
    /// The film sheet, opened from the toolbar.
    @State private var sagaFilm: SagaFilmViewModel?
    /// An entry's photos, full screen.
    @State private var photoViewer: PhotoViewerContent?
    @State private var fold: HorizontalFold?
    /// The entry the dad tapped while the list was below a fold.
    @State private var previewedID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let makeSagaFilm: SagaFilmSheet.MakeViewModel
    private let isOpeningLink: Bool

    /// - Parameters:
    ///   - makeSagaFilm: builds the film sheet behind "Make a film".
    ///   - isOpeningLink: a link from outside the app (the widget) is opening on another tab; the journal editor, the
    ///     film sheet and the photo viewer close so they do not cover that screen.
    public init(
        viewModel: TimelineViewModel,
        makeSagaFilm: @escaping SagaFilmSheet.MakeViewModel,
        isOpeningLink: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeSagaFilm = makeSagaFilm
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
            // Read where the panes are placed, so the fold is in their coordinates.
            .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum) { fold = $0 }
            .background(DSColor.background)
            .navigationTitle(title)
            // A large title collapses as the list scrolls and would move the fold's place in both panes.
            .toolbarTitleDisplayMode(fold == nil ? .automatic : .inline)
            .toolbar {
                if let filmTitle {
                    ToolbarItem(placement: .primaryAction) {
                        Button(filmTitle, systemImage: "film") { sagaFilm = makeSagaFilm(viewModel.filmRequest) }
                    }
                }
            }
        }
        .sagaFilmSheet($sagaFilm)
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
            guard opening else { return }
            viewModel.closeJournal()
            sagaFilm = nil
            photoViewer = nil
        }
        .sheet(item: Binding(get: { viewModel.journalEditor }, set: { if $0 == nil { viewModel.closeJournal() } })) { editor in
            JournalEditorSheet(
                editor: editor,
                isSaving: viewModel.isSaving,
                errorMessage: viewModel.errorMessage,
                loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
                onSave: { note, photos in Task { await viewModel.saveJournal(note: note, photos: photos) } },
                onClose: { viewModel.closeJournal() }
            )
        }
        .photoViewer($photoViewer, loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) })
        .alert(
            viewModel.errorMessage ?? "",
            isPresented: Binding(
                // A failed save in the note and photos sheet is shown there instead.
                get: { viewModel.errorMessage != nil && viewModel.journalEditor == nil },
                set: { _ in viewModel.dismissError() }
            )
        ) {}
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    private var filmTitle: String? {
        if case .loaded(let content) = viewModel.state { content.filmTitle } else { nil }
    }

    private func loaded(_ content: TimelineContent) -> some View {
        // The entry above the fold; none on a flat display or an empty timeline.
        let previewed = fold == nil ? nil : content.previewed(id: previewedID)
        let panes = (previewed == nil ? nil : fold).map { AnyLayout(FoldedStackLayout(fold: $0)) }
            ?? AnyLayout(VStackLayout(spacing: 0))
        // The same list in both layouts, so a fold keeps where it was scrolled to.
        return panes {
            if let previewed {
                TimelinePreview(
                    item: previewed,
                    editTitle: viewModel.editTitle,
                    loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
                    onShowPhotos: { showPhotos(of: previewed, content: content) },
                    onEdit: { viewModel.editJournal(id: previewed.id) }
                )
            }
            list(content, previewedID: previewed?.id)
        }
        .animation(reduceMotion ? nil : .smooth, value: previewed?.id)
    }

    private func showPhotos(of item: TimelineItem, content: TimelineContent) {
        photoViewer = content.viewer.content(entry: item.title, photos: item.photoIDs.map(PhotoSource.stored))
    }

    private func list(_ content: TimelineContent, previewedID: UUID?) -> some View {
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
                        description: Text(content.emptyMessage).foregroundStyle(DSColor.textSecondary)
                    )
                    .padding(.top, DSSpacing.xl)
                }
                ForEach(Array(content.sections.enumerated()), id: \.element.id) { index, section in
                    MonthNode(title: section.title, isFirst: index == 0)
                    ForEach(section.items) { item in
                        let isLast = index == content.sections.count - 1 && item.id == section.items.last?.id
                        row(item, isLast: isLast, content: content, previewedID: previewedID)
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
    /// A row that opens its note and photos when tapped, and can be deleted from its context menu. Its photo, a
    /// separate button, shows the photos full screen. Below a fold a tap shows the entry above it instead
    /// (`previewedID` is the entry there now); its note and photos open from there, or from the row's menu.
    func row(_ item: TimelineItem, isLast: Bool, content: TimelineContent, previewedID: UUID?) -> some View {
        TimelineRow(
            item: item,
            isLast: isLast,
            isPreviewed: item.id == previewedID,
            showPhotosTitle: content.viewer.showPhotos,
            loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
            deleteTitle: viewModel.deleteTitle,
            onOpen: {
                if previewedID == nil { viewModel.editJournal(id: item.id) } else { self.previewedID = item.id }
            },
            onShowPhotos: { showPhotos(of: item, content: content) },
            onDelete: { viewModel.requestDeletion(id: item.id) }
        )
        .contextMenu {
            Button(viewModel.editTitle, systemImage: "square.and.pencil") {
                viewModel.editJournal(id: item.id)
            }
            Button(viewModel.deleteTitle, systemImage: "trash", role: .destructive) {
                viewModel.requestDeletion(id: item.id)
            }
        }
    }
}

/// The column that holds the chronology line and the entry icons. It grows with the icons' text size, so the line
/// stays centred under them; each view scales it the same way.
private enum TimelineRail {
    static let width: CGFloat = 36
}

/// The chronology line: a thin vertical stroke centred in the rail, optionally cut at the top or bottom
/// so the line starts at the first month and ends at the last entry.
private struct RailLine: View {
    var startsHere = false
    var endsHere = false
    @ScaledMetric(relativeTo: .subheadline) private var railWidth: CGFloat = TimelineRail.width

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
    @ScaledMetric(relativeTo: .subheadline) private var railWidth: CGFloat = TimelineRail.width

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
    /// Shown above the fold right now: the row is marked.
    let isPreviewed: Bool
    let showPhotosTitle: String
    let loader: PhotoLoader
    let deleteTitle: String
    let onOpen: () -> Void
    let onShowPhotos: () -> Void
    let onDelete: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var railWidth: CGFloat = TimelineRail.width

    private var tint: Color { item.kind.tint }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            Image(systemName: item.symbol)
                .font(DSFont.smallSymbol)
                .foregroundStyle(DSColor.onTint)
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

    /// The card is the row's button; its photo sits over it as a button of its own (ADR-0042 §4).
    private var card: some View {
        Button(action: onOpen) {
            AdaptiveStack(alignment: .top, spacing: DSSpacing.m) {
                if !item.photoIDs.isEmpty {
                    ThumbnailSlot()
                }
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    CardTitle(item.title, badge: item.badge, tint: tint)
                    Text(item.subtitle)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay {
                if isPreviewed {
                    RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).strokeBorder(tint, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPreviewed ? .isSelected : [])
        .accessibilityValue(item.photoCount ?? "")
        .accessibilityActions {
            if !item.photoIDs.isEmpty {
                Button(showPhotosTitle, action: onShowPhotos)
            }
            Button(deleteTitle, action: onDelete)
        }
        .thumbnail {
            Button(action: onShowPhotos) {
                PhotoThumbnail(photoIDs: item.photoIDs, loader: loader, placeholder: tint.opacity(0.2))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }
}
