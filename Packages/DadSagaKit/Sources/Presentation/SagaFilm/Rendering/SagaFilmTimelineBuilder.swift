import CoreGraphics
import FilmKit
import Foundation

/// Turns a film's script into what `FilmKit` writes: one clip per scene, with its photo, its card and how it moves
/// (ADR-0037 §3). The same script always gives the same film.
struct SagaFilmTimelineBuilder {
    /// How many frames a scene takes to fade in from the one before.
    static let fadeFrames = 12
    /// The same between two photos alone, where the montage moves faster.
    static let montageFadeFrames = 9
    static let musicFadeOutSeconds = 3.0

    let spec: FilmSpec
    let photos: SagaFilmPhotoLoader

    func timeline(for script: SagaFilmScript) -> FilmTimeline {
        var clips: [FilmClip] = []
        var photoScenes = 0
        var previous: SagaFilmCard?
        for scene in script.scenes {
            let card = scene.card
            var glide: SagaFilmPhotoLoader.Glide?
            if card.photoID != nil {
                if !script.reduceMotion {
                    glide = photoScenes.isMultiple(of: 2) ? .inward : .outward
                }
                photoScenes += 1
            }
            clips.append(
                FilmClip(
                    frames: max(1, Int((scene.seconds * Double(spec.framesPerSecond)).rounded())),
                    picture: picture(for: card, glide: glide),
                    fit: .fitOverBlur,
                    overlay: overlay(for: card),
                    transitionIn: transition(from: previous, to: card)
                )
            )
            previous = card
        }
        return FilmTimeline(
            spec: spec,
            clips: clips,
            music: FilmMusic(url: script.music, fadeOutSeconds: Self.musicFadeOutSeconds)
        )
    }

    /// The card, drawn on the main actor when the encoder is about to need it. A photo alone has none.
    private func overlay(for card: SagaFilmCard) -> FilmImageLoader? {
        guard !card.isPhotoAlone else { return nil }
        let pixelSize = CGSize(width: spec.width, height: spec.height)
        return {
            try await SagaFilmRenderer.cardImage(card, pixelSize: pixelSize)
        }
    }

    /// A photo, shown whole and gliding in, then out, then in, so neighbouring photos rarely glide the same way (one
    /// with a child always glides in, ADR-0046 §3); or
    /// black, which a card of words covers with its own ground. The glide is aimed once the photo is loaded.
    private func picture(for card: SagaFilmCard, glide: SagaFilmPhotoLoader.Glide?) -> FilmPicture {
        guard let photoID = card.photoID else { return .solid(.black) }
        return .image { [photos, spec] in
            try await photos.photo(id: photoID, spec: spec, glide: glide)
        }
    }

    private func transition(from previous: SagaFilmCard?, to card: SagaFilmCard) -> FilmTransition {
        guard let previous else { return .cut }
        return .crossfade(frames: previous.isPhotoAlone && card.isPhotoAlone ? Self.montageFadeFrames : Self.fadeFrames)
    }
}

private extension SagaFilmCard {
    /// A photo alone: nothing is drawn over it.
    var isPhotoAlone: Bool {
        if case .photo = self { true } else { false }
    }
}
