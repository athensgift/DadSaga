import DesignSystem
import SwiftUI

/// "Your hero", pushed from Settings.
struct HeroSettingsView: View {
    @State var viewModel: HeroSettingsViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let content):
                picker(content)
            case .failed(let message):
                ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.canSave)
                .accessibilityLabel(saveTitle)
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

    private func picker(_ content: HeroSettingsContent) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                HeroPicker(
                    content: content.picker,
                    skinTone: $viewModel.skinTone,
                    selectedHeroID: viewModel.selectedHeroID
                ) { viewModel.selectHero(id: $0) }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.boss)
                }
            }
            .padding(DSSpacing.m)
        }
    }
}
