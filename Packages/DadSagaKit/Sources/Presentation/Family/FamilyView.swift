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
            ForEach(Array($viewModel.family.children.enumerated()), id: \.element.id) { index, $child in
                ChildEditorCard(
                    child: $child,
                    number: index + 1,
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
