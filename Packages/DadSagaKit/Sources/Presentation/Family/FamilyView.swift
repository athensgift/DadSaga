import DesignSystem
import SwiftUI

/// "My family", pushed from Settings.
struct FamilyView: View {
    @State var viewModel: FamilyViewModel
    @State private var isConfirmingDiscard = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let content):
                form(content)
            case .failed(let message):
                ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        // With nothing to lose, the system's back button and its swipe stay (the owner's choice). Once there is, they
        // would drop the changes, so our own back button takes their place and asks first (ADR-0050).
        .navigationBarBackButtonHidden(viewModel.hasUnsavedChanges)
        // Nor can the tab bar leave or pop the page under them: re-tapping Settings would pop it to its root and drop
        // the changes unasked. Hidden, the page stays on screen as long as it holds, as every other editor's sheet
        // covers the tab bar, so a waiting link always waits in front of the dad (ADR-0050, ADR-0061 §2).
        .tabBarHidden(when: viewModel.hasUnsavedChanges)
        .toolbar {
            if viewModel.hasUnsavedChanges {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.backTitle, systemImage: "chevron.backward", action: goBack)
                        .disabled(viewModel.isSaving)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.canSave)
                .accessibilityLabel(saveTitle)
            }
        }
        .modifier(UnsavedChangesGuard(
            hasUnsavedChanges: viewModel.hasUnsavedChanges,
            isAsking: $isConfirmingDiscard,
            labels: unsavedLabels,
            canSave: viewModel.canSave,
            onSave: { Task { await viewModel.save() } },
            onDiscard: { dismiss() }
        ))
        // Bringing back and deleting for good save with nothing unsaved: a link waits for them too (ADR-0050 §4).
        .holdsLinks(whileWorking: viewModel.isSaving)
        .task { await viewModel.onAppear() }
    }

    private func goBack() {
        if viewModel.hasUnsavedChanges { isConfirmingDiscard = true } else { dismiss() }
    }

    private var unsavedLabels: JournalLabels {
        if case .loaded(let content) = viewModel.state { content.unsaved } else { JournalLabels(locale: .current) }
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    private var saveTitle: String {
        if case .loaded(let content) = viewModel.state { content.saveTitle } else { "" }
    }

    /// One column; on an iPhone Duo half-open like a laptop the family stands above the fold, drawn as it is being
    /// edited, and the form lies below it, where the hands and the keyboard are (ADR-0043, ADR-0061).
    private func form(_ content: FamilyContent) -> some View {
        @Bindable var viewModel = viewModel
        return ReadAndActPanes(spacing: DSSpacing.m, flatTitle: .inline, column: FamilyColumn()) { isSplit in
            if isSplit {
                FamilyPortrait(children: viewModel.family.children, day: viewModel.latestBirthDate, timeZone: viewModel.timeZone)
                footnote(content)
            }
        } acting: { isSplit in
            // By id, not by position: a removed card still draws while it leaves, after its place is gone.
            ForEach(viewModel.family.children) { child in
                ChildEditorCard(
                    child: $viewModel.family.child(child),
                    number: viewModel.family.number(of: child.id),
                    labels: content.childEditor,
                    latestBirthDate: viewModel.latestBirthDate,
                    timeZone: viewModel.timeZone,
                    onRemove: viewModel.family.canRemoveChild ? { viewModel.removeChild(id: child.id) } : nil
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            if viewModel.family.canAddChild {
                Button(content.childEditor.addChildTitle, systemImage: "plus") { viewModel.addChild() }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
            if !viewModel.removedChildren.isEmpty {
                RemovedChildrenCard(viewModel: viewModel, labels: content.removed)
            }
            PartnerRow(hasPartner: $viewModel.family.hasPartner, labels: content.partner)
            SheetError(message: viewModel.errorMessage)
            if !isSplit {
                footnote(content)
            }
        }
        .motion(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.family.children.count)
    }

    private func footnote(_ content: FamilyContent) -> some View {
        Text(content.footnote)
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
            .multilineTextAlignment(.center)
    }
}

/// The children removed from the family, by name only: each can be brought back or deleted for good, after a calm
/// question (ADR-0065 §4).
private struct RemovedChildrenCard: View {
    let viewModel: FamilyViewModel
    let labels: RemovedChildrenLabels

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Text(labels.title)
                .font(DSFont.headline)
                .accessibilityAddTraits(.isHeader)
            Text(labels.line)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            ForEach(viewModel.removedChildren) { row in
                Divider()
                RemovedChild(viewModel: viewModel, row: row, labels: labels)
            }
            if viewModel.isFamilyFull {
                Text(labels.full)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(DSSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(DSFont.body)
        .foregroundStyle(DSColor.textPrimary)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}

/// One removed child: the name, and the two acts under it, side by side while their words fit on one line each, one
/// under the other once they don't. The question hangs on the row, so it rises from the child it is about.
private struct RemovedChild: View {
    let viewModel: FamilyViewModel
    let row: RemovedChildRow
    let labels: RemovedChildrenLabels

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Text(row.name)
                .font(DSFont.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DSSpacing.s) { buttons(wrapping: false) }
                VStack(alignment: .leading, spacing: DSSpacing.s) { buttons(wrapping: true) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            viewModel.deletion?.title ?? "",
            isPresented: Binding(
                get: { viewModel.deletion?.id == row.id },
                set: { if !$0 { viewModel.cancelDeletion() } }
            ),
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
    }

    /// Side by side, each title keeps to one line, never hyphenated; stacked, a title may wrap whole.
    @ViewBuilder
    private func buttons(wrapping: Bool) -> some View {
        if !viewModel.isFamilyFull {
            Button { Task { await viewModel.bringBack(id: row.id) } } label: { title(labels.bringBack, wrapping: wrapping) }
                .buttonStyle(.glass)
                .disabled(!viewModel.canBringBack)
                .accessibilityLabel(row.bringBackLabel)
        }
        Button(role: .destructive) { viewModel.requestDeletion(id: row.id) } label: {
            title(labels.deleteForGood, wrapping: wrapping)
        }
        .buttonStyle(.glass)
        .disabled(viewModel.isSaving)
        .accessibilityLabel(row.deleteLabel)
    }

    private func title(_ text: String, wrapping: Bool) -> some View {
        Text(text)
            .lineLimit(wrapping ? nil : 1)
            .fixedSize(horizontal: !wrapping, vertical: false)
    }
}

/// The family screen's column.
private struct FamilyColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
    }
}

/// Every child as the form has them right now, side by side with their names: above the fold, each change shows at
/// once. Decoration: VoiceOver reads the form below.
private struct FamilyPortrait: View {
    let children: [ChildDraft]
    let day: Date
    let timeZone: TimeZone

    var body: some View {
        // Smaller figures where four don't fit, as in a narrow window.
        ViewThatFits(in: .horizontal) {
            row(figureSize: 110)
            row(figureSize: 76)
            row(figureSize: 52)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.s)
        .accessibilityHidden(true)
    }

    private func row(figureSize: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: DSSpacing.l) {
            ForEach(children) { child in
                VStack(spacing: DSSpacing.xs) {
                    CompanionFigure(
                        stage: child.stage(at: day, timeZone: timeZone),
                        gender: child.gender,
                        skin: child.skinTone,
                        size: figureSize
                    )
                    // A child with no name yet keeps the line, so the figures stand on one baseline.
                    Text(child.name.isEmpty ? " " : child.name)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }
}
