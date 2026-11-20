import DesignSystem
import SwiftUI

/// The dad's level and XP inside it.
struct LevelPanel: View {
    let title: String
    let xpLine: String
    let fraction: Double
    /// Set while a level-up is celebrated: the bar fills to the end before starting the new level, and the panel glows.
    var levelUpID: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownFraction: Double?
    @State private var isGlowing = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .contentTransition(.numericText())
                Spacer()
                Text(xpLine)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            XPBar(label: title, fraction: shownFraction ?? fraction)
        }
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .stroke(DSColor.legendary, lineWidth: 2)
                .shadow(color: DSColor.legendary.opacity(0.7), radius: 8)
                .opacity(isGlowing ? 1 : 0)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)
        .task(id: levelUpID) { await celebrateLevelUp() }
        .accessibilityElement(children: .combine)
    }

    /// Fills the old level to the end, then empties into the new one, instead of the bar running backwards.
    private func celebrateLevelUp() async {
        guard levelUpID != nil else { return }
        withAnimation(.easeInOut(duration: 0.3)) { isGlowing = true }
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.45)) { shownFraction = 1 }
            try? await Task.sleep(for: .milliseconds(550))
            shownFraction = 0
            try? await Task.sleep(for: .milliseconds(50))
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { shownFraction = nil }
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeInOut(duration: 0.6)) { isGlowing = false }
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
struct CelebrationBadge: View {
    let celebration: Celebration
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            Text(celebration.xpText)
                .font(DSFont.title)
                .foregroundStyle(DSColor.xp)
            if let levelUpText = celebration.levelUpText {
                Label(levelUpText, systemImage: "star.fill")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.legendary)
                    .symbolEffect(.bounce, value: celebration.id)
            }
            if let badgeText = celebration.badgeText {
                Label(badgeText, systemImage: "rosette")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.boss)
                    .symbolEffect(.bounce, value: celebration.id)
            }
            if let momentText = celebration.momentText {
                Label(momentText, systemImage: "star.fill")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.legendary)
                    .symbolEffect(.bounce, value: celebration.id)
            }
            if let unlockText = celebration.unlockText {
                Label(unlockText, systemImage: "gift.fill")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.accent)
                    .symbolEffect(.bounce, value: celebration.id)
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
        .task(id: celebration.id) {
            try? await Task.sleep(for: .seconds(celebration.highlight >= .unlock ? 3.2 : 2.2))
            onFinished()
        }
    }
}

/// The badge with its burst, centred over the screen, and the haptic, while something is celebrated.
struct CelebrationOverlay: ViewModifier {
    let celebration: Celebration?
    let onFinished: () -> Void
    @Environment(\.isHapticsEnabled) private var isHapticsEnabled

    func body(content: Content) -> some View {
        content
            .overlay {
                if let celebration {
                    ZStack {
                        if let color = celebration.burstColor {
                            CelebrationBurst(
                                color: color,
                                sparkles: celebration.highlight == .levelUp ? 16 : 10,
                                // The card's sheet is still closing when the celebration starts.
                                delay: 0.35
                            )
                                .id(celebration.id)
                        }
                        CelebrationBadge(celebration: celebration, onFinished: onFinished)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: celebration)
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
        case .unlock: DSColor.accent
        case .moment, .levelUp: DSColor.legendary
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

/// The world's name and motto, a button to the world map, and a way back when an earlier world is shown.
struct WorldHeader: View {
    let content: HomeContent
    let onMap: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                if let worldTitle = content.worldTitle {
                    Text(worldTitle)
                        .font(DSFont.title)
                        .foregroundStyle(DSColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: DSSpacing.s)
                Button(content.mapTitle, systemImage: "map", action: onMap)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
            }
            if let worldTagline = content.worldTagline {
                Text(worldTagline)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
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
                Image(systemName: "checkmark.circle.fill").foregroundStyle(DSColor.xp)
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
        .task(id: offer.id) {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled { onExpire() }
        }
    }
}
