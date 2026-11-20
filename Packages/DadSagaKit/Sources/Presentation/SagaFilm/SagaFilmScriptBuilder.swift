import Application
import Domain
import Foundation

/// Turns the film's query into the script the renderer draws: one scene per storyboard scene, each as long as the
/// storyboard says (ADR-0036 §5). What goes in was decided in Domain; this only chooses the words and the looks.
struct SagaFilmScriptBuilder {
    /// The app's name, as it ends a film's file name. A name, not a sentence, so it isn't in the String Catalog.
    private static let fileNameSuffix = " – DadSaga"

    let texts: SagaFilmTexts
    private var locale: Locale { texts.locale }

    init(locale: Locale, calendar: Calendar) {
        texts = SagaFilmTexts(locale: locale, calendar: calendar)
    }

    func script(for film: SagaFilm, format: SagaFilmFormat, reduceMotion: Bool, showsDates: Bool) -> SagaFilmScript {
        SagaFilmScript(
            format: format,
            reduceMotion: reduceMotion,
            scenes: film.storyboard.scenes.compactMap { scene in
                card(for: scene.kind, in: film, showsDates: showsDates).map {
                    SagaFilmScene(seconds: scene.seconds, card: $0)
                }
            },
            music: film.soundtrack.audioURL,
            title: Self.fileName(for: film.child.name)
        )
    }

    /// The child's name with what a file name can't hold replaced: "/" would start a folder, and Finder shows ":" as
    /// one. A name longer than a file name can hold is cut at a whole character: a file name is at most 255 bytes,
    /// and a Greek letter takes two.
    static func fileName(for childName: String) -> String {
        var name = childName
            .components(separatedBy: CharacterSet(charactersIn: "/:").union(.newlines).union(.controlCharacters))
            .joined(separator: "-")
        while name.utf8.count > fileNameByteBudget {
            name.removeLast()
        }
        return name.trimmingCharacters(in: .whitespaces) + fileNameSuffix
    }

    /// Leaves room for the suffix, the extension and the sidecar names a writer adds while it works.
    private static let fileNameByteBudget = 160

    /// A note with something in it, or `nil`.
    private static func words(_ note: String) -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func card(for kind: SagaScene.Kind, in film: SagaFilm, showsDates: Bool) -> SagaFilmCard? {
        switch kind {
        case .opening:
            .opening(
                name: film.child.name,
                period: texts.periodTitle(film.period, catalog: film.catalog),
                dates: showsDates ? texts.span(film.storyboard.span) : nil,
                family: family(in: film)
            )
        case .chapter(let world, let number):
            .chapter(
                heading: texts.chapterHeading(number),
                title: world.title.resolved(for: locale),
                tagline: world.tagline.resolved(for: locale)
            )
        case .entry(let entry):
            card(for: entry, date: showsDates ? texts.day(entry.date) : nil)
        case .credits(let credits):
            .credits(texts.credits(credits, in: film))
        }
    }

    private func card(for entry: TimelineEntry, date: String?) -> SagaFilmCard? {
        switch entry.kind {
        case .first(let first):
            .first(
                emoji: first.emoji,
                title: first.title.resolved(for: locale),
                date: date,
                note: entry.note.flatMap(Self.words),
                photoID: entry.photoID
            )
        case .boss(let boss):
            .boss(
                badge: boss.badge.resolved(for: locale),
                title: boss.title.resolved(for: locale),
                date: date,
                photoID: entry.photoID
            )
        case .quest:
            // The storyboard keeps only quests with a photo; one without has nothing to show.
            entry.photoID.map { .questPhoto(photoID: $0) }
        }
    }

    /// The hero and the child as they were when the period ended, as home would have drawn them then.
    private func family(in film: SagaFilm) -> SagaFilmFamily {
        let hero = film.catalog.heroClasses.first { $0.id == film.profile.heroClassID }
        return SagaFilmFamily(
            hero: HeroLook(look: hero?.look),
            heroSkin: SkinToneChoice(film.profile.dadSkinTone),
            heroGear: film.equippedGear.compactMap { HeroGearLook(look: $0.look) },
            medals: film.medalCount,
            child: CompanionModel(
                id: film.child.id,
                name: film.child.name,
                stage: CompanionStage(ageInMonths: film.storyboard.childAgeInMonths),
                gender: GenderChoice(film.child.gender),
                skin: SkinToneChoice(film.child.skinTone),
                traits: Set(film.childFirsts.compactMap { $0.companionTrait.flatMap(CompanionTrait.init(content:)) })
            )
        )
    }
}
