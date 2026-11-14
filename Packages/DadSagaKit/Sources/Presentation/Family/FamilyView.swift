import DesignSystem
import SwiftUI

/// "My family", shown as a sheet from home.
public struct FamilyView: View {
    @State private var viewModel: FamilyViewModel
    private let onClose: () -> Void

    public init(viewModel: FamilyViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityLabel(saveTitle)
                }
            }
        }
        .task { await viewModel.onAppear() }
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
                        onRemove: viewModel.family.canRemoveChild ? { viewModel.removeChild(id: child.id) } : nil
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                if viewModel.family.canAddChild {
                    Button(content.childEditor.addChildTitle, systemImage: "plus") { viewModel.addChild() }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                }
                HStack {
                    Text(content.dadSkinToneLabel)
                    Spacer(minLength: DSSpacing.s)
                    SkinTonePicker(selection: $viewModel.family.dadSkinTone, names: content.childEditor.skinToneNames)
                }
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .padding(.horizontal, DSSpacing.m)
                .frame(minHeight: 52)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.boss)
                }
                Text(content.footnote)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.family.children.count)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
