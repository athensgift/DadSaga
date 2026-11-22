import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    /// A copy of the saga, `.dadsaga` (ADR-0057 §3). Declared by the app in `project.yml`.
    static let dadSagaCopy = UTType(exportedAs: "app.dadsaga.saga-copy", conformingTo: .data)
}

/// The exported file, for the share sheet. The receiver gets its own copy of it.
struct SagaCopyFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .dadSagaCopy) { SentTransferredFile($0.url) }
    }
}
