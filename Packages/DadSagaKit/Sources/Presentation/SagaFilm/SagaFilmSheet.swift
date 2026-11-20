import DesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The film sheet (ADR-0037 §4): the dad chooses a child, a period, a format and the music, the film is made while he waits, and
/// then it plays, ready to share. Present it with `sagaFilmSheet(_:)`, which also stops the film when the app leaves
/// the screen and deletes it once the sheet has gone.
public struct SagaFilmSheet: View {
    public typealias MakeViewModel = @MainActor (SagaFilmRequest) -> SagaFilmViewModel

    @State private var viewModel: SagaFilmViewModel
    private let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(viewModel: SagaFilmViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DSColor.background)
                .navigationTitle(viewModel.title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close, action: onClose)
                    }
                }
        }
        // A film being made is not lost to a stray swipe; Close still stops it.
        .interactiveDismissDisabled(isMaking)
        .task { await viewModel.onAppear() }
        .onChange(of: isMaking, initial: true) { _, isMaking in keepScreenAwake(isMaking) }
        .onDisappear { keepScreenAwake(false) }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .unavailable(let notice):
            ContentUnavailableView {
                Label(notice.message, systemImage: "film")
            } actions: {
                Button(notice.actionTitle) { Task { await viewModel.reload() } }
                    .buttonStyle(.glass)
            }
        case .ready(let setup):
            SagaFilmChoicesView(
                setup: setup,
                onChild: { id in Task { await viewModel.selectChild(id: id) } },
                onPeriod: { id in Task { await viewModel.selectPeriod(id: id) } },
                onFormat: { viewModel.selectFormat($0) },
                onMusic: { viewModel.selectMusic(id: $0) },
                onListen: { viewModel.listenToMusic() },
                onStop: { viewModel.stopMusic() },
                onDates: { viewModel.setShowsDates($0) },
                onMake: { Task { await viewModel.makeFilm(reduceMotion: reduceMotion) } }
            )
        case .making(let making):
            SagaFilmProgress(making: making) { viewModel.cancel() }
        case .made(let made):
            SagaFilmPlayer(made: made) { Task { await viewModel.makeAnother() } }
        }
    }

    private var isMaking: Bool {
        if case .making = viewModel.state { true } else { false }
    }

    /// The screen stays on while a film is made: a locked phone stops it, like leaving the app (ADR-0037 §4).
    private func keepScreenAwake(_ isAwake: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = isAwake
        #endif
    }
}

// MARK: - Presenting

extension View {
    /// Shows the film sheet while `film` is set. Leaving the app stops a film being made, and once the sheet has gone
    /// its film is deleted: from the sheet's dismissal, never from its disappearing, so the share sheet over it can't
    /// delete the film it is sharing (ADR-0037 §4).
    func sagaFilmSheet(_ film: Binding<SagaFilmViewModel?>) -> some View {
        modifier(SagaFilmSheetPresenter(film: film))
    }
}

private struct SagaFilmSheetPresenter: ViewModifier {
    @Binding var film: SagaFilmViewModel?
    /// The sheet on screen, kept until it has gone: by then the binding is already empty.
    @State private var presented: SagaFilmViewModel?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .sheet(item: $film, onDismiss: discard) { viewModel in
                SagaFilmSheet(viewModel: viewModel) { film = nil }
            }
            .onChange(of: film?.id) {
                guard let film else { return }
                // A new sheet asked for while the last one is still sliding away: that one is closed here, because
                // its dismissal would otherwise close the new one.
                if let earlier = presented, earlier !== film {
                    Task { await earlier.close() }
                }
                presented = film
            }
            // Only the background counts: the app switcher and a banner leave the app drawing (ADR-0037 §4).
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { film?.appWentToBackground() }
            }
    }

    private func discard() {
        // Another sheet is already up: the one that has gone was closed when it was replaced.
        guard film == nil else { return }
        let closed = presented
        presented = nil
        Task { await closed?.close() }
    }
}

// MARK: - Choosing

private struct SagaFilmChoicesView: View {
    let setup: SagaFilmSetup
    let onChild: (UUID) -> Void
    let onPeriod: (String) -> Void
    let onFormat: (SagaFilmFormat) -> Void
    let onMusic: (String) -> Void
    let onListen: () -> Void
    let onStop: () -> Void
    let onDates: (Bool) -> Void
    let onMake: () -> Void
    /// Grows with the text, so at the accessibility sizes a name gets a row of its own instead of being cut short.
    @ScaledMetric(relativeTo: .subheadline) private var optionMinimumWidth: CGFloat = 120

    private var optionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: optionMinimumWidth), spacing: DSSpacing.s)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                if let notice = setup.notice {
                    Label(notice, systemImage: "info.circle")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSSpacing.m)
                        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                }
                if !setup.children.isEmpty {
                    choice(setup.childLabel) {
                        LazyVGrid(columns: optionColumns, spacing: DSSpacing.s) {
                            ForEach(setup.children) { child in
                                SagaFilmOption(title: child.name, isSelected: child.id == setup.selectedChildID) {
                                    onChild(child.id)
                                }
                            }
                        }
                    }
                }
                choice(setup.periodLabel) { periodMenu }
                choice(setup.formatLabel) {
                    LazyVGrid(columns: optionColumns, spacing: DSSpacing.s) {
                        ForEach(setup.formats) { format in
                            SagaFilmOption(
                                title: format.title, symbol: format.symbol, isSelected: format.id == setup.selectedFormat
                            ) {
                                onFormat(format.id)
                            }
                        }
                    }
                }
                choice(setup.music.label) {
                    SagaFilmMusicRow(music: setup.music, onMusic: onMusic, onListen: onListen, onStop: onStop)
                }
                datesSwitch
                if let emptyMessage = setup.emptyMessage {
                    Text(emptyMessage)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(setup.note)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let makeTitle = setup.makeTitle {
                    PrimaryButton(makeTitle, action: onMake)
                }
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
    }

    private func choice(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Text(label)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// "Dates in the film", with what dates give away under it (ADR-0041 §5).
    private var datesSwitch: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Toggle(isOn: Binding(get: { setup.showsDates }, set: { onDates($0) })) {
                Text(setup.datesLabel)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            // VoiceOver reads it with the switch, as its hint, instead of as a stop of its own.
            .accessibilityHint(setup.datesNote)
            Text(setup.datesNote)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }

    /// A menu, not tiles: a child of six has a dozen periods.
    private var periodMenu: some View {
        let selected = setup.periods.first { $0.id == setup.selectedPeriodID }?.title ?? ""
        return Menu {
            Picker(setup.periodLabel, selection: Binding(get: { setup.selectedPeriodID }, set: { onPeriod($0) })) {
                ForEach(setup.periods) { period in
                    Text(period.title).tag(period.id)
                }
            }
        } label: {
            HStack(spacing: DSSpacing.s) {
                Text(selected)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(DSFont.smallSymbol)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous))
        }
        .accessibilityLabel(setup.periodLabel)
        .accessibilityValue(selected)
    }
}

/// One choice among a few, in the wardrobe's style: a tile with an accent border while it is the chosen one.
private struct SagaFilmOption: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous)
        Button(action: action) {
            VStack(spacing: DSSpacing.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(DSFont.symbol)
                        .foregroundStyle(isSelected ? DSColor.accent : DSColor.textSecondary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, DSSpacing.s)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.surface, in: shape)
            .overlay { shape.strokeBorder(DSColor.accent, lineWidth: isSelected ? 2.5 : 0) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Making

private struct SagaFilmProgress: View {
    let making: SagaFilmMaking
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.l) {
            Image(systemName: "film")
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.accent)
                .accessibilityHidden(true)
            ProgressView(value: making.progress) {
                Text(making.title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
            } currentValueLabel: {
                Text(making.progressText)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .monospacedDigit()
            }
            .tint(DSColor.accent)
            Text(making.note)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(making.cancelTitle, action: onCancel)
                .buttonStyle(.glass)
                .font(DSFont.body)
        }
        .frame(maxWidth: readableWidth)
        .padding(DSSpacing.l)
    }
}
