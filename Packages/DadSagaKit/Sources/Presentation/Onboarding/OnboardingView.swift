import DesignSystem
import SwiftUI

/// Two steps in a navigation stack: who the companion is, then which hero the dad plays.
/// The second step is pushed, so it gets the system back button and swipe-back gesture.
public struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    private let developerMenu: DeveloperMenu?

    public init(viewModel: OnboardingViewModel, developerMenu: DeveloperMenu? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.developerMenu = developerMenu
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let content):
                    childStep(content)
                        .navigationDestination(isPresented: isOnHeroStep) { heroStep(content) }
                case .failed(let message):
                    ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.background)
            .toolbar { DeveloperMenuToolbar(menu: developerMenu) }
        }
        .task { await viewModel.onAppear() }
    }

    private var isOnHeroStep: Binding<Bool> {
        Binding(
            get: { viewModel.step == .hero },
            set: { if !$0 { viewModel.backToChild() } }
        )
    }

    private func childStep(_ content: OnboardingContent) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(spacing: DSSpacing.l) {
                HeroAvatar(style: .hero, size: 170)
                    .accessibilityHidden(true)
                VStack(spacing: DSSpacing.s) {
                    Text(content.welcomeTitle)
                        .font(DSFont.largeTitle)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(content.welcomeSubtitle)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                }
                .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    TextField(content.namePlaceholder, text: $viewModel.childName)
                        .font(DSFont.body)
                        .submitLabel(.continue)
                        .onSubmit { viewModel.continueToHero() }
                        .padding(DSSpacing.m)
                    Divider()
                        .padding(.leading, DSSpacing.m)
                    DatePicker(
                        content.birthDateLabel,
                        selection: $viewModel.birthDate,
                        in: ...viewModel.latestBirthDate,
                        displayedComponents: .date
                    )
                    .font(DSFont.body)
                    .padding(.horizontal, DSSpacing.m)
                    .padding(.vertical, DSSpacing.s)
                }
                .foregroundStyle(DSColor.textPrimary)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                // In the content, not pinned: a pinned bar would sit on the keyboard and cover the form on small screens.
                PrimaryButton(content.continueTitle) { viewModel.continueToHero() }
                    .disabled(!viewModel.canContinue)
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.l)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        // When the keyboard shrinks the screen, keep the form and button in view rather than the avatar.
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .background(DSColor.background)
    }

    private func heroStep(_ content: OnboardingContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                Text(content.heroSubtitle)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DSSpacing.m)], spacing: DSSpacing.m) {
                    ForEach(content.heroes) { hero in
                        HeroOptionCard(hero: hero, isSelected: hero.id == viewModel.selectedHeroID) {
                            viewModel.selectHero(id: hero.id)
                        }
                    }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.boss)
                }
            }
            .padding(DSSpacing.m)
        }
        .background(DSColor.background)
        .navigationTitle(content.heroTitle)
        .toolbar { DeveloperMenuToolbar(menu: developerMenu) }
        .safeAreaBar(edge: .bottom) {
            bottomBar(content.finishTitle, isEnabled: viewModel.canFinish) {
                Task { await viewModel.finish() }
            }
        }
    }

    private func bottomBar(_ title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        PrimaryButton(title, action: action)
            .disabled(!isEnabled)
            .frame(maxWidth: readableWidth)
            .padding(.horizontal, DSSpacing.l)
            .padding(.vertical, DSSpacing.s)
    }
}

private struct HeroOptionCard: View {
    let hero: HeroOption
    let isSelected: Bool
    let onSelect: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DSSpacing.s) {
                HeroAvatar(style: hero.look.avatarStyle, size: 120, cheerTrigger: isSelected ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text(hero.title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Text(hero.tagline)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: shape)
            .overlay { shape.strokeBorder(hero.look.avatarStyle.tint, lineWidth: isSelected ? 2.5 : 0) }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(hero.look.avatarStyle.tint)
                        .padding(DSSpacing.s)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(shape)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
