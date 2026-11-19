import Foundation

/// Reads bundled content: decodes its JSON and finds its other files, such as the film music. The only place in the app
/// that looks inside a `Bundle` for content.
public struct JSONResourceDataSource: Sendable {
    private let bundle: Bundle

    /// Uses the content shipped inside this module.
    public init() {
        self.bundle = .module
    }

    /// For tests or alternative content bundles.
    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    /// A bundled file other than JSON, such as the film music.
    func url(of file: String) throws -> URL {
        let name = (file as NSString).deletingPathExtension
        let fileExtension = (file as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw ContentDataError.missingResource(file)
        }
        return url
    }

    func decode<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw ContentDataError.missingResource(resource)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
