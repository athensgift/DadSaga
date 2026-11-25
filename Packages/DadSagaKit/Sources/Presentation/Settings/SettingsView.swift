import DesignSystem
import HeroArt
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Settings, a tab of its own (ADR-0030, ADR-0061 §2): no close button, and like every tab it is where the dad left
/// it when he comes back. The weekly reminder, hero, wardrobe and family are pushed inside it. On an iPhone Duo
/// half-open like a laptop the dad's hero stands above the fold and the whole form lies below it (ADR-0061 §4).
public struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var page: SettingsPage?
    @Environment(\.openURL) private var openURL
    private let pages: SettingsPages
    private let pendingLink: PendingLink?

    /// - Parameter pendingLink: a link from outside the app (the widget) opening on another tab: any question or alert
    ///   here closes, and the pages stay where they were (ADR-0061 §2).
    public init(viewModel: SettingsViewModel, pages: SettingsPages, pendingLink: PendingLink? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.pages = pages
        self.pendingLink = pendingLink
    }

    public var body: some View {
        NavigationStack {
            FormBelowFold {
                heroAboveTheFold
            } lower: {
                form(viewModel.content)
            }
            .background(DSColor.background)
            .navigationTitle(viewModel.content.title)
            // Each time Settings shows, back from "Your hero" or the wardrobe too.
            .task { await viewModel.loadHero() }
            // Leaving Export and import is its closing: the files it made were saved or sent by then (ADR-0057 §6).
            .onChange(of: page) { old, _ in
                if case .data = old { pages.discardExports() }
            }
            .navigationDestination(item: $page) { page in
                switch page {
                case .hero(let hero): HeroSettingsView(viewModel: hero)
                case .wardrobe(let wardrobe): WardrobeView(viewModel: wardrobe)
                case .family(let family): FamilyView(viewModel: family)
                case .reminder(let reminder): ReminderSettingsView(viewModel: reminder)
                case .data(let data): DataExportView(viewModel: data)
                }
            }
        }
        // Around the stack, so a pushed page that covers the form doesn't keep it from hearing of the link.
        .onChange(of: pendingLink) { _, link in
            guard link != nil else { return }
            viewModel.linkWillOpen()
            if case .family(let family) = page { family.linkWillOpen() }
        }
    }

    /// Who Settings is about, drawn as on "Your hero".
    @ViewBuilder private var heroAboveTheFold: some View {
        if let hero = viewModel.hero {
            HeroPreview(
                style: hero.look.avatarStyle, skin: hero.skinTone.avatarSkin, features: hero.appearance.avatarFeatures
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }

    private func form(_ content: SettingsContent) -> some View {
        @Bindable var viewModel = viewModel
        return Form {
            preferencesSection(content)
            heroSection(content)
            dataSection(content)
            if let support = content.support {
                supportSection(support)
            }
            aboutSection(content.about)
            startOverSection(content.startOver)
        }
        .font(DSFont.body)
        .scrollContentBackground(.hidden)
        .confirmationDialog(
            content.startOver.dialogTitle,
            isPresented: $viewModel.isConfirmingStartOver,
            titleVisibility: .visible
        ) {
            Button(content.startOver.confirm, role: .destructive) {
                Task { await viewModel.startOver() }
            }
            Button(content.startOver.cancel, role: .cancel) {}
        } message: {
            Text(content.startOver.dialogMessage)
        }
        .alert(
            viewModel.mailFallback?.title ?? "",
            isPresented: Binding(get: { viewModel.mailFallback != nil }, set: { if !$0 { viewModel.mailFallback = nil } }),
            presenting: viewModel.mailFallback
        ) { fallback in
            Button(fallback.copyTitle) { copy(fallback.address) }
            Button(fallback.closeTitle, role: .cancel) {}
        }
    }

    private func row(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private func languageRow(_ content: SettingsContent) -> some View {
        Button {
            #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            #endif
        } label: {
            LabeledContent {
                Text(content.languageValue)
                    .foregroundStyle(DSColor.textSecondary)
            } label: {
                Label(content.languageTitle, systemImage: "globe")
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
    }

    private func preferencesSection(_ content: SettingsContent) -> some View {
        Section {
            languageRow(content)
            Picker(selection: appearanceBinding) {
                ForEach(content.appearanceOptions) { Text($0.title).tag($0.id) }
            } label: {
                Label(content.appearanceTitle, systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)
            Toggle(isOn: hapticsBinding) {
                Label(content.hapticsTitle, systemImage: "iphone.radiowaves.left.and.right")
            }
            row(content.reminderTitle, systemImage: "bell") {
                page = .reminder(pages.makeReminder())
            }
        } header: {
            Text(content.preferencesSection).foregroundStyle(DSColor.textSecondary)
        } footer: {
            Text(content.languageFooter).foregroundStyle(DSColor.textSecondary)
        }
    }

    private func heroSection(_ content: SettingsContent) -> some View {
        Section {
            row(content.heroTitle, systemImage: "figure.fencing") {
                page = .hero(pages.makeHero())
            }
            row(content.wardrobeTitle, systemImage: "tshirt") {
                page = .wardrobe(pages.makeWardrobe())
            }
            row(content.familyTitle, systemImage: "person.2") {
                page = .family(pages.makeFamily { page = nil })
            }
        } header: {
            Text(content.heroSection).foregroundStyle(DSColor.textSecondary)
        }
    }

    private func dataSection(_ content: SettingsContent) -> some View {
        Section {
            row(content.dataTransferTitle, systemImage: "externaldrive") {
                page = .data(pages.makeDataExport { viewModel.sagaImported() })
            }
        } header: {
            Text(content.dataSection).foregroundStyle(DSColor.textSecondary)
        }
    }

    private func startOverSection(_ labels: StartOverLabels) -> some View {
        Section {
            Button(role: .destructive) {
                viewModel.askToStartOver()
            } label: {
                Label(labels.row, systemImage: "arrow.counterclockwise")
            }
            .disabled(viewModel.isStartingOver)
            SheetError(message: viewModel.errorMessage)
        } footer: {
            Text(labels.footer).foregroundStyle(DSColor.textSecondary)
        }
    }

    private func supportSection(_ support: SupportSection) -> some View {
        Section {
            if let contact = support.contact {
                Button {
                    openURL(contact.mailURL) { accepted in viewModel.mailOpened(accepted) }
                } label: {
                    Label(contact.title, systemImage: "envelope")
                }
            }
            if let rate = support.rate {
                Link(destination: rate.url) {
                    Label(rate.title, systemImage: "star")
                }
            }
            if let share = support.share {
                ShareLink(item: share.url, subject: Text(share.subject), message: Text(share.message)) {
                    Label(share.title, systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text(support.title).foregroundStyle(DSColor.textSecondary)
        }
    }

    private func aboutSection(_ about: AboutSection) -> some View {
        Section {
            LabeledContent {
                Text(about.versionValue)
                    .foregroundStyle(DSColor.textSecondary)
            } label: {
                Label(about.versionTitle, systemImage: "info.circle")
            }
            if let policy = about.privacyPolicy {
                Link(destination: policy.url) {
                    Label(policy.title, systemImage: "hand.raised")
                }
            }
        } header: {
            Text(about.title).foregroundStyle(DSColor.textSecondary)
        } footer: {
            Text(about.privacyStatement).foregroundStyle(DSColor.textSecondary)
        }
    }

    private var appearanceBinding: Binding<AppearanceChoice> {
        Binding(
            get: { viewModel.preferences.appearance },
            set: { choice in Task { await viewModel.setAppearance(choice) } }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.preferences.isHapticsEnabled },
            set: { value in Task { await viewModel.setHapticsEnabled(value) } }
        )
    }

    private func copy(_ address: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = address
        #endif
    }
}

/// A page pushed from Settings, holding the presenter built when its row was tapped.
private enum SettingsPage: Hashable {
    case hero(HeroSettingsViewModel)
    case wardrobe(WardrobeViewModel)
    case family(FamilyViewModel)
    case reminder(ReminderSettingsViewModel)
    case data(DataExportViewModel)

    private var object: AnyObject {
        switch self {
        case .hero(let model): model
        case .wardrobe(let model): model
        case .family(let model): model
        case .reminder(let model): model
        case .data(let model): model
        }
    }

    static func == (lhs: SettingsPage, rhs: SettingsPage) -> Bool {
        lhs.object === rhs.object
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(object))
    }
}
