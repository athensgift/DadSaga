import Foundation

/// Reads and decodes JSON files from a bundle. The only place in the app that touches `Bundle` for content.
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

    func decode<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw ContentDataError.missingResource(resource)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
