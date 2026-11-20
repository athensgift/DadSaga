import DesignSystem
import SwiftUI

/// The film's music (ADR-0046 §2, §3): one row, a menu of the tracks with their moods and a round button that plays
/// the chosen one's start. One row rather than one per track, so "Make the film" stays where it was.
struct SagaFilmMusicRow: View {
    let music: SagaFilmMusicSetup
    let onMusic: (String) -> Void
    let onListen: () -> Void
    let onStop: () -> Void
    /// Grows with the text, and never under the 44 pt a finger needs.
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44

    private var selected: SagaFilmMusicChoice? {
        music.choices.first { $0.id == music.selectedID }
    }

    var body: some View {
        HStack(spacing: DSSpacing.s) {
            menu
            playButton
        }
    }

    /// `Toggle`s, since Apple documents both the checkmark and the subtitle for them in a menu.
    private var menu: some View {
        Menu {
            ForEach(music.choices) { choice in
                Toggle(isOn: Binding(
                    get: { choice.id == music.selectedID },
                    set: { isOn in if isOn { onMusic(choice.id) } }
                )) {
                    Text(choice.title)
                    Text(choice.mood)
                }
            }
        } label: {
            HStack(spacing: DSSpacing.s) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(selected?.title ?? "")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(selected?.mood ?? "")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(DSFont.smallSymbol)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous))
        }
        .accessibilityLabel(music.label)
        .accessibilityValue(selected.map { "\($0.title), \($0.mood)" } ?? "")
    }

    private var playButton: some View {
        Button(action: music.isPlaying ? onStop : onListen) {
            Image(systemName: music.isPlaying ? "stop.fill" : "play.fill")
                .font(DSFont.tileSymbol)
                .foregroundStyle(DSColor.onTint)
                .frame(width: max(44, buttonSize), height: max(44, buttonSize))
                .background(DSColor.accent, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // The symbols swap without moving (ADR-0046 §3: Reduce Motion changes nothing).
        .transaction { $0.animation = nil }
        .accessibilityLabel(music.actionTitle)
        // VoiceOver keeps quiet for the music it starts, but not for the button that stops it.
        .accessibilityAddTraits(music.isPlaying ? [] : .startsMediaSession)
    }
}
