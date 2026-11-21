import DesignSystem
import SwiftUI

/// The dad's title under the hero, where a level was: a name, no bar and no number (ADR-0055 §6).
struct TitleLine: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "laurel.leading")
            .font(DSFont.headline)
            .foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, DSSpacing.m)
            .padding(.vertical, DSSpacing.s)
            .frame(maxWidth: .infinity)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

/// Whose world and quests are shown, when there are several children.
/// The picker keeps its own selection and reports changes, so it needs no `Binding(get:set:)`: that would turn
/// `onSelect` into an `@isolated(any) @Sendable` closure, which the Xcode 26 compiler cannot build.
struct ChildPicker: View {
    let content: HomeContent
    let onSelect: (UUID) -> Void

    @State private var selection: UUID

    init(content: HomeContent, onSelect: @escaping (UUID) -> Void) {
        self.content = content
        self.onSelect = onSelect
        _selection = State(initialValue: content.selectedChildID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Picker(content.familyTitle, selection: $selection) {
                ForEach(content.childTabs) { tab in
                    Text(tab.name).tag(tab.id)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) { _, id in
                if id != content.selectedChildID { onSelect(id) }
            }
            .onChange(of: content.selectedChildID) { _, id in selection = id }
            if let line = content.selectedChildLine {
                Text(line)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.bottom, DSSpacing.s)
    }
}

/// Floating, transient feedback after a quest or boss: the one place on home where Liquid Glass sits over content.
/// How long it shows and when VoiceOver reads it are home's (`HomeView.celebrationTime`), so a badge drawn again (two
/// panes after one) neither restarts its time nor is read twice.
struct CelebrationBadge: View {
    let celebration: Celebration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The symbols bounce once per celebration; with Reduce Motion they stay still.
    private var bounce: Int { reduceMotion ? 0 : celebration.id }

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            if let skillText = celebration.skillText {
                Text(skillText)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.xp)
            }
            if let badgeText = celebration.badgeText {
                Label(badgeText, systemImage: "rosette")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.boss)
                    .symbolEffect(.bounce, value: bounce)
            }
            if let momentText = celebration.momentText {
                Label(momentText, systemImage: "star.fill")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.legendary)
                    .symbolEffect(.bounce, value: bounce)
            }
        }
        // Each line at its natural width when it fits the screen; wrapped within the screen when it doesn't.
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
        .padding(.horizontal, DSSpacing.l)
        .padding(.vertical, DSSpacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: DSRadius.card))
        .padding(.horizontal, DSSpacing.m)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

/// The badge with its burst, centred over the screen, and the haptic, while something is celebrated.
struct CelebrationOverlay: ViewModifier {
    let celebration: Celebration?
    @Environment(\.isHapticsEnabled) private var isHapticsEnabled

    func body(content: Content) -> some View {
        content
            .overlay {
                if let celebration {
                    ZStack {
                        if let color = celebration.burstColor {
                            CelebrationBurst(
                                color: color,
                                sparkles: 10,
                                // The card's sheet is still closing when the celebration starts.
                                delay: 0.35
                            )
                                .id(celebration.id)
                        }
                        CelebrationBadge(celebration: celebration)
                    }
                }
            }
            .motion(.spring(response: 0.4, dampingFraction: 0.7), value: celebration)
            .sensoryFeedback(trigger: celebration) { _, celebration in
                celebration?.haptic(isEnabled: isHapticsEnabled)?.feedback
            }
    }
}

extension Celebration {
    /// The burst behind the badge, for moments bigger than an ordinary quest.
    var burstColor: Color? {
        switch highlight {
        case .quest: nil
        case .boss: DSColor.boss
        case .moment: DSColor.legendary
        }
    }

}

extension CelebrationHaptic {
    var feedback: SensoryFeedback {
        switch self {
        case .heavy: .impact(weight: .heavy)
        case .success: .success
        }
    }
}

/// The world's name and motto, and a way back when an earlier world is shown. The world map is in the toolbar.
struct WorldHeader: View {
    let content: HomeContent
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let worldTitle = content.worldTitle {
                Text(worldTitle)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            if let worldTagline = content.worldTagline {
                Text(worldTagline)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
            // Under the world it is about, aligned with it (ADR-0053 §1).
            if let arrivalLine = content.arrivalLine, content.worldTitle != nil {
                ArrivalLine(text: arrivalLine)
            }
            if let back = content.backToCurrentTitle {
                Button(back, systemImage: "arrow.uturn.backward", action: onBack)
                    .font(DSFont.subheadline)
                    .padding(.top, DSSpacing.xs)
            }
        }
        .padding(.bottom, DSSpacing.s)
    }
}

/// "When they arrive, untick “Not born yet” in My family.": one quiet line, no card, no count, no date.
struct ArrivalLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DSFont.subheadline)
            .foregroundStyle(DSColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "When life changes": the bosses for a move, two homes or a loss, behind one closed row at the end of the world's
/// cards (ADR-0053 §5). Closed each time home is opened, and no count: there for the dad who needs them, not on every screen.
struct SituationalRow<Card: View>: View {
    let cards: SituationalCards
    @ViewBuilder let card: (CardModel) -> Card
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: DSSpacing.s) {
                ForEach(cards.cards) { card($0) }
            }
            .padding(.top, DSSpacing.s)
        } label: {
            Text(cards.title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .tint(DSColor.textSecondary)
        .padding(.horizontal, DSSpacing.m)
        .padding(.vertical, DSSpacing.s)
        .frame(minHeight: 50)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .padding(.top, DSSpacing.s)
    }
}

/// "Saved · Undo" at the bottom of the screen for a few seconds after the dad records something.
struct UndoBar: View {
    let offer: UndoOffer
    let onUndo: () -> Void
    let onExpire: () -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    /// Long enough to notice a wrong tap; longer with VoiceOver, where reaching the button takes a few swipes.
    private var duration: Duration { voiceOver ? .seconds(15) : .seconds(6) }

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            Label {
                Text(offer.message).foregroundStyle(DSColor.textPrimary)
            } icon: {
                if offer.didFail {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(DSColor.boss)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DSColor.xp)
                }
            }
            .font(DSFont.subheadline)
            Spacer(minLength: 0)
            Button(offer.actionTitle, systemImage: "arrow.uturn.backward", action: onUndo)
                .font(DSFont.headline)
                .buttonStyle(.borderless)
                .tint(DSColor.accent)
        }
        .padding(.horizontal, DSSpacing.m)
        .padding(.vertical, DSSpacing.s)
        // Solid, not clear glass: the cards scrolling underneath made the text hard to read.
        .background(DSColor.surface, in: Capsule())
        .shadow(color: DSColor.heroInk.opacity(0.15), radius: 12, y: 4)
        .frame(maxWidth: readableWidth)
        .padding(.horizontal, DSSpacing.m)
        .padding(.bottom, DSSpacing.s)
        // "Couldn't undo" is read out, whether the bar came back for it or never left.
        .onChange(of: offer.didFail, initial: true) { _, didFail in
            if didFail { AccessibilityNotification.Announcement(offer.message).post() }
        }
        .task(id: offer.id) {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled { onExpire() }
        }
    }
}
