import DesignSystem
import SwiftUI

/// Settings › Export data (ADR-0057 §8): export the saga to one file, or import one. A form, so it isn't split by a fold
/// (ADR-0043 §8). While it works, it can't be left: Cancel is the way out.
struct DataExportView: View {
    @State private var viewModel: DataExportViewModel

    init(viewModel: DataExportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            exportSection
            DataImportSection(viewModel: viewModel.importer)
        }
        .font(DSFont.body)
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .navigationTitle(viewModel.content.title)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isWorking)
        .holdsLinks(whileWorking: viewModel.isWorking)
        .onDisappear { Task { await viewModel.importer.closed() } }
    }

    private var exportSection: some View {
        Section {
            Text(viewModel.content.explanation)
                .foregroundStyle(DSColor.textSecondary)
            switch viewModel.state {
            case .ready, .failed:
                Button(viewModel.content.button, systemImage: "square.and.arrow.up.on.square") {
                    Task { await viewModel.export() }
                }
                .disabled(viewModel.importer.isWorking)
            case .exporting(let fraction):
                ProgressView(value: fraction) { Text(viewModel.content.exporting) }
                Button(viewModel.content.cancel, role: .cancel) { viewModel.cancel() }
            case .exported(let exported):
                Text(exported.readyLine)
                    .foregroundStyle(DSColor.textPrimary)
                    .onAppear { AccessibilityNotification.Announcement(exported.readyLine).post() }
                ShareLink(
                    item: SagaCopyFile(url: exported.file),
                    preview: SharePreview(exported.file.lastPathComponent)
                ) {
                    Label(viewModel.content.share, systemImage: "square.and.arrow.up")
                }
            }
            if case .failed(let message) = viewModel.state {
                SheetError(message: message)
            }
        } header: {
            Text(viewModel.content.title).foregroundStyle(DSColor.textSecondary)
        } footer: {
            // Before he chooses where to send it.
            Text(viewModel.content.noPassword).foregroundStyle(DSColor.textSecondary)
        }
    }
}
