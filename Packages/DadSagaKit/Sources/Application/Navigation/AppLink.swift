import Foundation

/// A place in the app that something outside it can open, such as the home-screen widget (ADR-0023).
/// Opening a link only shows a screen; it never records anything.
public enum AppLink: Hashable, Sendable {
    /// The Adventure tab with this child and this quest's sheet open.
    case quest(id: String, childID: UUID)
    /// This child's legendary moment.
    case moment(eventID: UUID, childID: UUID)
    /// The Adventure tab with this child selected.
    case child(UUID)

    public static let scheme = "dadsaga"

    public var childID: UUID {
        switch self {
        case .quest(_, let childID), .moment(_, let childID): childID
        case .child(let childID): childID
        }
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .quest(let id, let childID):
            components.host = "quest"
            components.path = "/" + id
            components.queryItems = [URLQueryItem(name: "child", value: childID.uuidString)]
        case .moment(let eventID, let childID):
            components.host = "moment"
            components.path = "/" + eventID.uuidString
            components.queryItems = [URLQueryItem(name: "child", value: childID.uuidString)]
        case .child(let childID):
            components.host = "child"
            components.path = "/" + childID.uuidString
        }
        return components.url ?? URL(filePath: "/")
    }

    /// `nil` for anything that is not exactly one of the links above.
    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme, let host = components.host else { return nil }
        let parts = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 1, let value = parts.first else { return nil }
        let child = components.queryItems?.first { $0.name == "child" }?.value.flatMap(UUID.init(uuidString:))
        switch host {
        case "quest":
            guard let child else { return nil }
            self = .quest(id: value, childID: child)
        case "moment":
            guard let child, let eventID = UUID(uuidString: value) else { return nil }
            self = .moment(eventID: eventID, childID: child)
        case "child":
            guard let childID = UUID(uuidString: value) else { return nil }
            self = .child(childID)
        default:
            return nil
        }
    }
}
