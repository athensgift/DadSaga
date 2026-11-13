import DesignSystem
import SwiftUI

/// Two steps: who the companion is, then which hero the dad plays.
public struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let content):
                switch viewModel.step {
                case .child:
                    childStep(content)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                case .hero:
                    heroStep(content)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            case .failed(let message):
                ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.step)
        .task { await viewModel.onAppear() }
    }

    private func childStep(_ content: OnboardingContent) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(spacing: DSSpacing.l) {
                HeroAvatar(style: .hero, size: 180)
                    .accessibilityHidden(true)
                header(title: content.welcomeTitle, subtitle: content.welcomeSubtitle)
                VStack(spacing: DSSpacing.m) {
                    TextField(content.namePlaceholder, text: $viewModel.childName)
                        .font(DSFont.body)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                    Divider()
                    DatePicker(
                        content.birthDateLabel,
                        selection: $viewModel.birthDate,
                        in: ...viewModel.latestBirthDate,
                        displayedComponents: .date
                    )
                    .font(DSFont.body)
                }
                .foregroundStyle(DSColor.textPrimary)
                .padding(DSSpacing.m)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card))
                Button(content.continueTitle) { viewModel.continueToHero() }
                    .buttonStyle(.dsPrimary)
                    .disabled(!viewModel.canContinue)
            }
            .padding(DSSpacing.l)
        }
    }

    private func heroStep(_ content: OnboardingContent) -> some View {
        ScrollView {
            VStack(spacing: DSSpacing.m) {
                header(title: content.heroTitle, subtitle: content.heroSubtitle)
                ForEach(content.heroes) { hero in
                    HeroOptionCard(hero: hero, isSelected: hero.id == viewModel.selectedHeroID) {
                        viewModel.selectHero(id: hero.id)
                    }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.boss)
                }
                Button(content.finishTitle) {
                    Task { await viewModel.finish() }
                }
                .buttonStyle(.dsPrimary)
                .disabled(!viewModel.canFinish)
                Button(content.backTitle) { viewModel.backToChild() }
                    .font(DSFont.body)
                    .tint(DSColor.textSecondary)
            }
            .padding(DSSpacing.l)
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(spacing: DSSpacing.s) {
            Text(title)
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text(subtitle)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
        }
        .multilineTextAlignment(.center)
    }
}

private struct HeroOptionCard: View {
    let hero: HeroOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DSSpacing.m) {
                HeroAvatar(style: hero.look.avatarStyle, size: 96)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(hero.title)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(hero.tagline)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.card)
                    .strokeBorder(hero.look.avatarStyle.tint.opacity(isSelected ? 1 : 0), lineWidth: 2.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
