import DesignSystem
import SwiftUI

/// Importing an exported saga: the explanation, the file picker, its progress and the question (ADR-0057 §8). Used on
/// the Export data page and in onboarding's sheet.
struct DataImportSection: View {
    @Bindable var viewModel: DataImportViewModel

    var body: some View {
        Section {
            Text(viewModel.content.explanation)
                .foregroundStyle(DSColor.textSecondary)
            switch viewModel.state {
            case .ready, .asking, .failed:
                Button(viewModel.content.button, systemImage: "square.and.arrow.down") { viewModel.pick() }
            case .opening(let fraction):
                ProgressView(value: fraction) { Text(viewModel.content.opening) }
                Button(viewModel.content.cancel, role: .cancel) { viewModel.cancel() }
            case .importing:
                ProgressView { Text(viewModel.content.importing) }
            }
            if case .failed(let message) = viewModel.state {
                SheetError(message: message)
            }
        } header: {
            Text(viewModel.content.title).foregroundStyle(DSColor.textSecondary)
        }
        .fileImporter(isPresented: $viewModel.isPicking, allowedContentTypes: [.dadSagaCopy]) { result in
            guard case .success(let url) = result else { return }
            Task { await viewModel.picked(url) }
        }
        // An alert, not a confirmation dialog: as a popover a dialog has no Cancel, and a tap beside it answers
        // nothing. Here every answer is a visible button.
        .alert(
            question?.title ?? "",
            isPresented: Binding(get: { question != nil }, set: { _ in }),
            presenting: question
        ) { question in
            Button(question.cancel, role: .cancel) { Task { await viewModel.decline() } }
            Button(question.confirm, role: question.confirmIsDestructive ? .destructive : nil) {
                Task { await viewModel.confirm() }
            }
        } message: { question in
            Text(question.message)
        }
    }

    private var question: DataImportQuestion? {
        if case .asking(let question) = viewModel.state { question } else { nil }
    }
}

/// Onboarding's way back to a saga exported from another iPhone, in a small sheet.
struct DataImportSheet: View {
    @State private var viewModel: DataImportViewModel
    private let onClose: () -> Void

    init(viewModel: DataImportViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Form { DataImportSection(viewModel: viewModel) }
                .font(DSFont.body)
                .scrollContentBackground(.hidden)
                .background(DSColor.background)
                .navigationTitle(viewModel.content.title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if !viewModel.isWorking {
                        ToolbarItem(placement: .cancellationAction) { Button(role: .close, action: onClose) }
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.isWorking)
        // A file read but never answered is let go when the sheet goes.
        .onDisappear { Task { await viewModel.closed() } }
    }
}
