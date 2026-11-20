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

    init(locale: Locale) {
        texts = SagaFilmTexts(locale: locale)
    }

    func script(for film: SagaFilm, format: SagaFilmFormat, reduceMotion: Bool) -> SagaFilmScript {
        SagaFilmScript(
            format: format,
            reduceMotion: reduceMotion,
            scenes: film.storyboard.scenes.compactMap { scene in
                card(for: scene.kind, in: film).map { SagaFilmScene(seconds: scene.seconds, card: $0) }
            },
            music: film.soundtrack.audioURL,
            title: Self.fileName(for: film.child.name)
        )
    }

    /// The child's name with what a file name can't hold replaced: "/" would start a folder, and Finder shows ":" as
    /// one.
    static func fileName(for childName: String) -> String {
        let name = childName
            .components(separatedBy: CharacterSet(charactersIn: "/:").union(.newlines).union(.controlCharacters))
            .joined(separator: "-")
        return name + fileNameSuffix
    }

    /// A note with something in it, or `nil`.
    private static func words(_ note: String) -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func card(for kind: SagaScene.Kind, in film: SagaFilm) -> SagaFilmCard? {
        switch kind {
        case .opening:
            .opening(
                name: film.child.name,
                period: texts.periodTitle(film.period, catalog: film.catalog),
                family: family(in: film)
            )
        case .chapter(let world, let number):
            .chapter(
                heading: texts.chapterHeading(number),
                title: world.title.resolved(for: locale),
                tagline: world.tagline.resolved(for: locale)
            )
        case .entry(let entry):
            card(for: entry)
        case .credits(let credits):
            .credits(texts.credits(credits, in: film))
        }
    }

    private func card(for entry: TimelineEntry) -> SagaFilmCard? {
        switch entry.kind {
        case .first(let first):
            .first(
                emoji: first.emoji,
                title: first.title.resolved(for: locale),
                note: entry.note.flatMap(Self.words),
                photoID: entry.photoID
            )
        case .boss(let boss):
            .boss(badge: boss.badge.resolved(for: locale), title: boss.title.resolved(for: locale), photoID: entry.photoID)
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
