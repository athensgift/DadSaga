import Application
import CoreGraphics
import FilmTestSupport
import Foundation
import ImageIO
@testable import Presentation

/// The progress a render reported, in order.
@MainActor
final class Seen {
    var values: [Double] = []
}

/// Cards for the renderer's tests.
enum FilmCards {
    static let chapter = SagaFilmCard.chapter(heading: "Κεφάλαιο 1", title: "Σπηλιά", tagline: "Οι πρώτες μέρες")

    static let opening = SagaFilmCard.opening(
        name: "Άννα",
        period: "2ος χρόνος",
        dates: "Μάρτιος 2025 – Μάρτιος 2026",
        family: SagaFilmFamily(
            hero: .cool, heroSkin: .mediumDark, heroAppearance: .standard, heroGear: [.burpCloth, .mug], medals: 2,
            child: CompanionModel(
                id: UUID(), name: "Άννα", spokenName: "Άννα", stage: .toddler, gender: .girl, skin: .medium,
                traits: [.smile, .walks]
            )
        )
    )

    static let credits = SagaFilmCard.credits(
        SagaFilmCredits(
            lines: [
                SagaFilmCreditLine(role: "Πρωταγωνιστεί", name: "Άννα"),
                SagaFilmCreditLine(role: "Ο ήρωας", name: "Cool Μπαμπάς"),
                SagaFilmCreditLine(role: "Μαζί", name: "4 αποστολές · 1 αφεντικό"),
                SagaFilmCreditLine(role: "Μουσική", name: "Saga Theme · DadSaga")
            ],
            signature: "Φτιαγμένο με το DadSaga"
        )
    )

    static func first(photoID: String? = nil) -> SagaFilmCard {
        .first(
            emoji: "😊", title: "Πρώτο χαμόγελο", date: "12 Μαρτίου 2026", note: "Χαμογέλασε στον παππού", photoID: photoID
        )
    }
}

/// The photo store's side of the film: JPEG data by id, or nothing.
struct StubPhotos: GetPhotoUseCase {
    private let photos: [String: Data]
    /// What the store makes of any photo asked for smaller than it keeps: a new JPEG, never the file.
    private let resized: Data?

    init(_ photos: [String: Data] = [:], resized: Data? = nil) {
        self.photos = photos
        self.resized = resized
    }

    func execute(id: String, maxPixelSize: Int) async -> Data? {
        guard let photo = photos[id] else { return nil }
        return maxPixelSize >= StoredPhoto.longestSide ? photo : resized ?? photo
    }
}

/// Photos made in the test, in the shape of a vertical film so they fill its frame.
enum TestPhoto {
    struct Failure: Error {}

    struct Paint {
        var red: UInt8 = 0
        var green: UInt8 = 0
        var blue: UInt8 = 0

        static let red = Paint(red: 255)
        static let blue = Paint(blue: 255)
        static let white = Paint(red: 255, green: 255, blue: 255)
    }

    /// A 180 × 320 JPEG; `color` gives each pixel's colour from its column and row.
    static func jpeg(color: (Int, Int) -> Paint) throws -> Data {
        let (width, height) = (180, 320)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let paint = color(column, row)
                let index = (row * width + column) * 4
                bytes[index] = paint.red
                bytes[index + 1] = paint.green
                bytes[index + 2] = paint.blue
            }
        }
        let image = bytes.withUnsafeMutableBytes { raw in
            CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )?.makeImage()
        }
        let data = NSMutableData()
        guard let image, let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            throw Failure()
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure() }
        return data as Data
    }
}

extension FilmProbe.Pixel {
    /// The cards' dark ground (0x14131C), give or take what H.264 does to it.
    var isGround: Bool {
        abs(red - 0x14) < 14 && abs(green - 0x13) < 14 && abs(blue - 0x1C) < 14
    }

    /// WCAG's relative luminance, from 0 (black) to 1 (white).
    var luminance: Double {
        let linear = [red, green, blue].map { value -> Double in
            let srgb = Double(value) / 255
            return srgb <= 0.039_28 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
