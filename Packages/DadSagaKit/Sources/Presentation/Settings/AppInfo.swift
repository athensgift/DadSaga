import Foundation

/// Facts about the running app that Settings shows or links to. Read by the composition root, from the bundle and
/// the three `DadSaga…` keys in `project.yml` (ADR-0030).
public struct AppInfo: Equatable, Sendable {
    public let version: String
    public let build: String
    public let systemVersion: String
    /// Where feedback goes. `nil` hides the contact row.
    public let feedbackAddress: String?
    /// The app's App Store id. `nil` hides "Rate" and "Tell a friend".
    public let appStoreID: String?
    /// `nil` hides the privacy policy row.
    public let privacyPolicyURL: URL?

    public init(
        version: String,
        build: String,
        systemVersion: String,
        feedbackAddress: String? = nil,
        appStoreID: String? = nil,
        privacyPolicyURL: URL? = nil
    ) {
        self.version = version
        self.build = build
        self.systemVersion = systemVersion
        self.feedbackAddress = feedbackAddress
        self.appStoreID = appStoreID
        self.privacyPolicyURL = privacyPolicyURL
    }

    /// Reads the bundle's version and the three `DadSaga…` keys. A key that is empty or malformed counts as missing:
    /// an address without "@", an App Store id that is not all digits, a privacy policy that is not https.
    public init(infoDictionary info: [String: Any], systemVersion: String) {
        func value(_ key: String) -> String? {
            guard let text = (info[key] as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
                return nil
            }
            return text
        }
        self.init(
            version: value("CFBundleShortVersionString") ?? "",
            build: value("CFBundleVersion") ?? "",
            systemVersion: systemVersion,
            feedbackAddress: value("DadSagaFeedbackAddress").flatMap { $0.contains("@") ? $0 : nil },
            appStoreID: value("DadSagaAppStoreID").flatMap { $0.allSatisfy(\.isASCIIDigit) ? $0 : nil },
            privacyPolicyURL: value("DadSagaPrivacyPolicyURL")
                .flatMap(URL.init(string:))
                .flatMap { $0.scheme == "https" && $0.host != nil ? $0 : nil }
        )
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
