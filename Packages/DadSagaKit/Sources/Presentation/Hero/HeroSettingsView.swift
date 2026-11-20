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

    private func picker(_ content: HeroSettingsContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                if let look = viewModel.previewLook {
                    preview(look.avatarStyle)
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.boss)
                }
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
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
    }

    /// Like the wardrobe's: the hero alone, without gear, so the look is what changes.
    private func preview(_ style: HeroAvatar.Style) -> some View {
        HeroAvatar(
            style: style,
            size: 160,
            skin: viewModel.skinTone.avatarSkin,
            features: viewModel.appearance.avatarFeatures
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.s)
        .background {
            Circle()
                .fill(
                    RadialGradient(colors: [style.tint.opacity(0.25), .clear], center: .center, startRadius: 10, endRadius: 110)
                )
                .frame(width: 220, height: 220)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.appearance)
        .accessibilityHidden(true)
    }

    private var skinToneBinding: Binding<SkinToneChoice> {
        Binding(get: { viewModel.skinTone }, set: { tone in Task { await viewModel.setSkinTone(tone) } })
    }
}
