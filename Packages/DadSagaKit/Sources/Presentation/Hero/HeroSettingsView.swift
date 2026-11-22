import DesignSystem
import HeroArt
import SwiftUI

/// "Your hero", pushed from Settings: the chosen hero drawn with the dad's look, then the choices, stored at once.
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
        .task { await viewModel.onAppear() }
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.title } else { "" }
    }

    /// Like the wardrobe: on an iPhone Duo half-open like a laptop the hero stands above the fold, where each change
    /// shows at once, and every choice lies below it (ADR-0043, ADR-0061).
    private func picker(_ content: HeroSettingsContent) -> some View {
        ReadAndActPanes(
            alignment: .leading, spacing: DSSpacing.m, flatTitle: .inline, column: HeroSettingsColumn()
        ) { _ in
            if let look = viewModel.previewLook {
                preview(look.avatarStyle)
            }
        } acting: { _ in
            SheetError(message: viewModel.errorMessage)
            HeroPicker(
                content: content.picker,
                skinTone: skinToneBinding,
                appearance: viewModel.appearance,
                looks: viewModel.looks,
                selectedHeroID: viewModel.selectedHeroID,
                onSelect: { id in Task { await viewModel.selectHero(id: id) } },
                onSelectOption: { row, option in
                    Task { await viewModel.selectOption(rowID: row, optionID: option) }
                }
            )
        }
    }

    /// Like the wardrobe's: the hero alone, without gear, so the look is what changes.
    private func preview(_ style: HeroAvatar.Style) -> some View {
        HeroPreview(style: style, skin: viewModel.skinTone.avatarSkin, features: viewModel.appearance.avatarFeatures)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.s)
            .motion(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.appearance)
    }

    private var skinToneBinding: Binding<SkinToneChoice> {
        Binding(get: { viewModel.skinTone }, set: { tone in Task { await viewModel.setSkinTone(tone) } })
    }
}

/// The hero page's column.
private struct HeroSettingsColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
    }
}
