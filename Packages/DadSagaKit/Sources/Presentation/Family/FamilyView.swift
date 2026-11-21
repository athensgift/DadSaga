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

    private func form(_ content: FamilyContent) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(spacing: DSSpacing.m) {
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
                SheetError(message: viewModel.errorMessage)
                Text(content.footnote)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
            .motion(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.family.children.count)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
