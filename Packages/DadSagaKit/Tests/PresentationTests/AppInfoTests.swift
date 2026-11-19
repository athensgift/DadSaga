import Foundation
import Presentation
import Testing

@Suite("AppInfo")
struct AppInfoTests {
    @Test("Given empty support keys, when reading the bundle, then the version is read and every link is missing")
    func emptyKeys() {
        let info = AppInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "7",
                "DadSagaFeedbackAddress": "", "DadSagaAppStoreID": " ", "DadSagaPrivacyPolicyURL": ""
            ],
            systemVersion: "26.1"
        )

        #expect(info == AppInfo(version: "0.1.0", build: "7", systemVersion: "26.1"))
    }

    @Test("Given malformed keys, when reading the bundle, then they count as missing")
    func malformedKeys() {
        let info = AppInfo(
            infoDictionary: [
                "DadSagaFeedbackAddress": "not an address",
                "DadSagaAppStoreID": "id123",
                "DadSagaPrivacyPolicyURL": "http://example.com/privacy"
            ],
            systemVersion: "26.1"
        )

        #expect(info.feedbackAddress == nil)
        #expect(info.appStoreID == nil)
        #expect(info.privacyPolicyURL == nil)
    }

    @Test("Given valid keys, when reading the bundle, then each one is kept")
    func validKeys() {
        let info = AppInfo(
            infoDictionary: [
                "DadSagaFeedbackAddress": " hi@example.com ",
                "DadSagaAppStoreID": "6741234567",
                "DadSagaPrivacyPolicyURL": "https://example.com/privacy"
            ],
            systemVersion: "26.1"
        )

        #expect(info.feedbackAddress == "hi@example.com")
        #expect(info.appStoreID == "6741234567")
        #expect(info.privacyPolicyURL?.absoluteString == "https://example.com/privacy")
    }
}
