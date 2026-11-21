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
        // With changes not saved, the system's back button and its swipe would drop them: a back button that asks first
        // stands in for it.
        .navigationBarBackButtonHidden(viewModel.hasUnsavedChanges)
        .toolbar {
            if viewModel.hasUnsavedChanges, case .loaded(let content) = viewModel.state {
                ToolbarItem(placement: .cancellationAction) {
                    Button(content.backTitle, systemImage: "chevron.backward") { isConfirmingDiscard = true }
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
