import DesignSystem
import HeroArt
import SwiftUI

/// Two steps in a navigation stack: the dad's children, then which hero he plays and how he looks.
/// The second step is pushed, so it gets the system back button and swipe-back gesture.
public struct OnboardingView: View {
    public typealias MakeImport = @MainActor () -> DataImportViewModel

    @State private var viewModel: OnboardingViewModel
    @State private var importer: DataImportViewModel?
    private let makeImport: MakeImport

    /// - Parameter makeImport: builds the import sheet's presenter when the dad taps Import data.
    public init(viewModel: OnboardingViewModel, makeImport: @escaping MakeImport) {
        _viewModel = State(initialValue: viewModel)
        self.makeImport = makeImport
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
        }
        .task { await viewModel.onAppear() }
        .sheet(item: $importer) { importer in
            DataImportSheet(viewModel: importer) { self.importer = nil }
        }
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
                PartnerRow(hasPartner: $viewModel.family.hasPartner, labels: content.partner)
                // In the content, not pinned: a pinned bar would sit on the keyboard and cover the form on small screens.
                PrimaryButton(content.continueTitle) { viewModel.continueToHero() }
                    .disabled(!viewModel.canContinue)
                Button(content.importTitle, systemImage: "square.and.arrow.down") { importer = makeImport() }
                    .font(DSFont.body)
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.l)
            .frame(maxWidth: .infinity)
            .motion(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.family.children.count)
        }
        .scrollDismissesKeyboard(.interactively)
        // When the keyboard shrinks the screen, keep the form and button in view rather than the avatar.
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .background(DSColor.background)
    }

    private func heroStep(_ content: OnboardingContent) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                HeroPicker(
                    content: content.hero,
                    skinTone: $viewModel.family.dadSkinTone,
                    appearance: viewModel.dadAppearance,
                    selectedHeroID: viewModel.selectedHeroID
                ) { viewModel.selectHero(id: $0) }
                SheetError(message: viewModel.errorMessage)
            }
            .padding(DSSpacing.m)
        }
        .background(DSColor.background)
        .navigationTitle(content.heroTitle)
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
