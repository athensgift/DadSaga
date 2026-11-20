import DesignSystem
import HeroArt
import SwiftUI

/// One scene's card, drawn at the film's size in pixels (ADR-0036 §4, ADR-0037 §2). Always dark, with no materials:
/// `ImageRenderer` draws it, and Core Animation never sees it. A card of words fills its own ground; a card over a
/// photo is clear except for its words and the scrim under them.
struct SagaFilmCardView: View {
    let card: SagaFilmCard
    /// The film's frame, in pixels.
    let canvas: CGSize

    /// Type and spacing are sized from the frame's shorter side, so a card reads the same in both formats.
    private var side: CGFloat { min(canvas.width, canvas.height) }
    private var gap: CGFloat { DSFilm.spacing(side) }
    private var margins: EdgeInsets { DSFilm.margins(width: canvas.width, height: canvas.height) }

    var body: some View {
        if card.photoID == nil {
            words
                .padding(margins)
                .frame(width: canvas.width, height: canvas.height)
                .background(DSFilm.ground)
        } else {
            caption
                .frame(width: canvas.width, height: canvas.height, alignment: .bottom)
        }
    }

    // MARK: Cards of words

    @ViewBuilder private var words: some View {
        switch card {
        case .opening(let name, let period, let dates, let family):
            opening(name: name, period: period, dates: dates, family: family)
        case .chapter(let heading, let title, let tagline):
            VStack(spacing: gap * 1.5) {
                line(heading, font: DSFilm.headline(side), color: DSFilm.secondaryText)
                line(title, font: DSFilm.title(side))
                line(tagline, font: DSFilm.body(side), color: DSFilm.secondaryText, lines: 2)
            }
        case .first(let emoji, let title, let date, let note, _):
            VStack(spacing: gap * 2) {
                Text(emoji).font(DSFilm.emoji(side))
                VStack(spacing: gap * 0.5) {
                    dateLine(date, color: DSFilm.secondaryText)
                    line(title, font: DSFilm.title(side), color: DSFilm.legendary, lines: 2)
                }
                if let note {
                    line(note, font: DSFilm.body(side), lines: 2)
                }
            }
        case .boss(let badge, let title, let date, _):
            VStack(spacing: gap * 2) {
                Image(systemName: "flame.fill")
                    .font(DSFilm.emoji(side))
                    .foregroundStyle(DSFilm.boss)
                VStack(spacing: gap * 0.5) {
                    dateLine(date, color: DSFilm.secondaryText)
                    line(title, font: DSFilm.title(side), lines: 2)
                }
                line(badge, font: DSFilm.headline(side), color: DSFilm.boss)
            }
        case .credits(let credits):
            self.credits(credits)
        case .photo:
            EmptyView()
        }
    }

    /// The hero next to the child, as home draws them, over the child's name and the film's period.
    private func opening(name: String, period: String, dates: String?, family: SagaFilmFamily) -> some View {
        let width = canvas.width - margins.leading - margins.trailing
        let height = canvas.height - margins.top - margins.bottom
        return VStack(spacing: gap * 3) {
            FamilyStage(
                heroStyle: family.hero.avatarStyle,
                heroSkin: family.heroSkin.avatarSkin,
                heroGear: family.heroGear.map(\.heroItem),
                medals: family.medals,
                heroTitle: "",
                companions: [family.child],
                selectedChildID: family.child.id,
                maxHeroSize: FamilyStage.heroSize(fitting: width, companions: 1, atMost: min(side * 0.62, height * 0.5)),
                cheerTrigger: 0,
                onSelect: { _ in }
            )
            VStack(spacing: gap) {
                line(name, font: DSFilm.title(side))
                line(period, font: DSFilm.headline(side), color: DSFilm.legendary)
                dateLine(dates, color: DSFilm.secondaryText)
            }
        }
    }

    private func credits(_ credits: SagaFilmCredits) -> some View {
        VStack(spacing: gap * 2.5) {
            ForEach(Array(credits.lines.enumerated()), id: \.offset) { _, credit in
                VStack(spacing: gap * 0.4) {
                    line(credit.role, font: DSFilm.caption(side), color: DSFilm.secondaryText)
                    line(credit.name, font: DSFilm.headline(side), lines: 2)
                }
            }
            line(credits.signature, font: DSFilm.caption(side), color: DSFilm.secondaryText)
                .padding(.top, gap * 2)
        }
    }

    // MARK: Cards over a photo

    /// The card's words at the bottom of the frame, on a scrim that fades in above them so the photo stays clear.
    private var caption: some View {
        let fade = gap * 6
        return VStack(alignment: .leading, spacing: gap) {
            switch card {
            case .first(let emoji, let title, let date, let note, _):
                // Over a photo the date is white like the title: grey can't reach 4.5:1 through the scrim (ADR-0041 §4).
                dateLine(date, color: DSFilm.text, alignment: .leading)
                line("\(emoji) \(title)", font: DSFilm.title(side), lines: 2, alignment: .leading)
                if let note {
                    line(note, font: DSFilm.body(side), lines: 2, alignment: .leading)
                }
            case .boss(let badge, let title, let date, _):
                dateLine(date, color: DSFilm.text, alignment: .leading)
                line(title, font: DSFilm.title(side), lines: 2, alignment: .leading)
                // Over a photo the badge's name is white like the title: the boss colour can't stay readable on every
                // photo, so only the flame carries it.
                HStack(spacing: gap) {
                    Image(systemName: "flame.fill")
                        .font(DSFilm.headline(side))
                        .foregroundStyle(DSFilm.boss)
                    line(badge, font: DSFilm.headline(side), alignment: .leading)
                }
            case .opening, .chapter, .photo, .credits:
                EmptyView()
            }
        }
        .shadow(color: DSFilm.shadow, radius: gap * 0.4)
        .padding(EdgeInsets(top: fade, leading: margins.leading, bottom: margins.bottom, trailing: margins.trailing))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            VStack(spacing: 0) {
                LinearGradient(colors: [DSFilm.scrim.opacity(0), DSFilm.scrim], startPoint: .top, endPoint: .bottom)
                    .frame(height: fade)
                DSFilm.scrim
            }
        }
    }

    /// A card's date, when the film shows dates: one line in the caption style, right above the title (ADR-0041 §4).
    @ViewBuilder
    private func dateLine(_ date: String?, color: Color, alignment: TextAlignment = .center) -> some View {
        if let date {
            line(date, font: DSFilm.caption(side), color: color, alignment: alignment)
        }
    }

    /// One piece of text: it shrinks before it is cut, and never grows past `lines`.
    private func line(
        _ text: String,
        font: Font,
        color: Color = DSFilm.text,
        lines: Int = 1,
        alignment: TextAlignment = .center
    ) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(lines)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(alignment)
    }
}
