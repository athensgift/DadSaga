import DesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Settings, as a sheet from home (ADR-0030). The weekly reminder, hero and family are pushed inside it.
public struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var page: SettingsPage?
    @Environment(\.openURL) private var openURL
    private let pages: SettingsPages
    private let onClose: () -> Void

    public init(viewModel: SettingsViewModel, pages: SettingsPages, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.pages = pages
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            form(viewModel.content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DSColor.background)
                .navigationTitle(viewModel.content.title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close, action: onClose)
                    }
                }
                .navigationDestination(item: $page) { page in
                    switch page {
                    case .hero(let hero): HeroSettingsView(viewModel: hero)
                    case .family(let family): FamilyView(viewModel: family)
                    case .reminder(let reminder): ReminderSettingsView(viewModel: reminder)
                    }
                }
        }
        // A sheet keeps its own look; it follows the dad's choice together with the window behind it.
        .preferredColorScheme(viewModel.preferences.appearance.colorScheme)
    }

    private func form(_ content: SettingsContent) -> some View {
        @Bindable var viewModel = viewModel
        return Form {
            preferencesSection(content)
            heroSection(content)
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
                page = .hero(pages.makeHero { page = nil })
            }
            row(content.familyTitle, systemImage: "person.2") {
                page = .family(pages.makeFamily { page = nil })
            }
        } header: {
            Text(content.heroSection).foregroundStyle(DSColor.textSecondary)
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
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.boss)
            }
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
    case family(FamilyViewModel)
    case reminder(ReminderSettingsViewModel)

    private var object: AnyObject {
        switch self {
        case .hero(let model): model
        case .family(let model): model
        case .reminder(let model): model
        }
    }

    static func == (lhs: SettingsPage, rhs: SettingsPage) -> Bool {
        lhs.object === rhs.object
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(object))
    }
}
