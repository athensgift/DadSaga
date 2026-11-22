import Foundation

/// The file a copy of the saga is (ADR-0057 §3): an Apple Archive, LZFSE, whose regular-file entries come in this
/// order: `manifest.json`, `saga.json`, one `photos/<id>.jpg` per photo, `checksums.json`.
///
/// A released format is read forever: its DTOs never change, and a change to what a copy holds is a new version
/// (ADR-0057 §4).
enum SagaCopyFormat {
    /// What the manifest calls itself, and the file's type.
    static let kind = "app.dadsaga.saga-copy"
    static let fileExtension = "dadsaga"
    /// The version this build writes, and the newest it reads.
    static let currentVersion = 1

    static let manifestPath = "manifest.json"
    static let sagaPath = "saga.json"
    static let checksumsPath = "checksums.json"
    private static let photoFolder = "photos/"
    private static let photoExtension = ".jpg"

    /// Each entry is refused before it is read when its header says it is larger: a copy can't make the app allocate
    /// more than this.
    static let manifestLimit = 64 * 1024
    static let sagaLimit = 64 * 1024 * 1024
    static let photoLimit = 64 * 1024 * 1024

    static func photoPath(_ id: String) -> String { photoFolder + id + photoExtension }

    /// The photo id in `path`, only for `photos/<UUID>.jpg`: never a folder, `..` or anything else.
    static func photoID(inPath path: String) -> String? {
        guard path.hasPrefix(photoFolder), path.hasSuffix(photoExtension) else { return nil }
        let id = String(path.dropFirst(photoFolder.count).dropLast(photoExtension.count))
        return UUID(uuidString: id) != nil ? id : nil
    }

    /// `DadSaga 2026-11-22.dadsaga`, on the day the copy is made where the phone is. No names: file names show in
    /// AirDrop and Files.
    static func fileName(madeAt date: Date, in timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "DadSaga \(day).\(fileExtension)"
    }
}
