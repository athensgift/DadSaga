import Presentation
import SwiftUI
import Testing
import UIKit

/// The child card's date picker is laid out by the date it shows, not by today's (ADR-0038). At the largest text
/// size, where that matters most, the image ends above the date row, so the row is measured here.
/// In the suite of the screen snapshots, which draws one screen at a time in the app's window.
extension ScreenSnapshotTests {
    @Test(
        "Given a birth date that is not today, when onboarding is drawn, then the date picker is as wide as its date",
        arguments: Look.allCases
    )
    func datePickerWidth(look: Look) async throws {
        let fixture = SagaFixture(locale: look.locale)
        let viewModel = fixture.onboarding()
        await viewModel.onAppear()
        let screen = UIHostingController(
            rootView: OnboardingView(viewModel: viewModel) { fixture.dataImport(replacesSaga: false) }
                .environment(\.locale, look.locale)
        )
        screen.traitOverrides.preferredContentSizeCategory = look.traits.preferredContentSizeCategory
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        let keyWindow = windows.first { $0.isKeyWindow }
        let window = try #require(keyWindow)
        let root = try #require(window.rootViewController)
        root.addChild(screen)
        screen.view.frame = root.view.bounds
        root.view.addSubview(screen.view)
        screen.didMove(toParent: root)
        defer {
            screen.willMove(toParent: nil)
            screen.view.removeFromSuperview()
            screen.removeFromParent()
        }
        screen.view.layoutIfNeeded()

        let picker = try #require(screen.view.firstDescendant(UIDatePicker.self))
        let pill = try #require(picker.firstDescendant(UIButton.self))
        // In words: with too little room, iOS writes the date in digits.
        #expect(pill.firstDescendant(UILabel.self)?.text == (look == .greekLight ? "15 Ιουν 2026" : "Jun 15, 2026"))
        // The pill, and the one pixel to spare that keeps the date in words.
        let spare = picker.bounds.width - pill.bounds.width
        #expect(abs(spare - 1 / window.screen.scale) < 0.01, "the picker is \(spare) pt wider than its pill")
    }
}

private extension UIView {
    func firstDescendant<Found: UIView>(_ type: Found.Type) -> Found? {
        for subview in subviews {
            if let found = subview as? Found ?? subview.firstDescendant(type) { return found }
        }
        return nil
    }
}
