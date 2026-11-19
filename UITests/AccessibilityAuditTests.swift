import XCTest

/// Runs Xcode's accessibility audit on the main screens (onboarding, home, the world map, a quest, the wardrobe,
/// settings and the empty timeline): VoiceOver labels and traits, contrast, hit regions (ADR-0033).
/// The app starts on data of its own (`DeviceData`), empty, so each run begins in onboarding.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    private var app: XCUIApplication!

    func testEveryScreenPassesTheAudit() {
        continueAfterFailure = true
        app = XCUIApplication()
        // The default text size, whatever the simulator is set to.
        app.launchArguments = [
            "-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
        ]
        app.launch()

        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "onboarding did not open")
        audit("Onboarding: children")
        name.tap()
        name.typeText("Alex\n")
        tap(app.buttons["Continue"])

        audit("Onboarding: hero", bottomButton: true)
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Super Dad'")).firstMatch)
        tap(app.buttons["Start the adventure"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "home did not open")
        audit("Home")

        tap(app.buttons["World map"].firstMatch)
        audit("World map")
        close()

        tap(app.scrollViews.buttons.matching(NSPredicate(format: "label CONTAINS 'XP'")).firstMatch)
        expandSheet()
        audit("Quest")
        close()

        app.navigationBars.buttons["Wardrobe"].tap()
        audit("Wardrobe")
        close()

        app.navigationBars.buttons["Settings"].tap()
        audit("Settings")
        close()

        // Home scrolled down for the quest, which shrinks the tab bar to its current tab.
        for _ in 0..<4 { app.swipeDown() }
        app.tabBars.buttons["Timeline"].firstMatch.tap()
        audit("Timeline")
    }

    // MARK: The audit

    /// Every check except the two about text size: `.textClipped` and `.dynamicType` flag Form rows, grids and the
    /// hero picker that read in full on screen. The accessibility text sizes are checked by hand (ADR-0033).
    /// - Parameter bottomButton: the screen pins a button over its content, on glass, like a bar.
    private func audit(
        _ screen: String, bottomButton: Bool = false, file: StaticString = #filePath, line: UInt = #line
    ) {
        sleep(1)
        do {
            try app.performAccessibilityAudit(for: .all.subtracting([.textClipped, .dynamicType])) { issue in
                guard let element = issue.element else {
                    // Nothing to point at or fix; logged so it is not lost.
                    print("\(screen): \(issue.compactDescription), no element")
                    return true
                }
                if self.isFalseAlarm(issue, element: element, bottomButton: bottomButton) { return true }
                let found = "“\(element.label)” \(element.frame)"
                XCTFail("\(screen): \(issue.compactDescription) – \(found)", file: file, line: line)
                return true
            }
        } catch {
            XCTFail("\(screen): the audit could not run: \(error)", file: file, line: line)
        }
    }

    /// Contrast issues that don't reach a user; every other kind of issue always fails:
    /// - a disabled control (WCAG exempts inactive controls), e.g. Continue before a name is typed;
    /// - text fading under a bar: iOS 26 blurs scrolled content near the bars (the scroll edge effect) and under a
    ///   pinned bottom button, and the audit measures it through that; scrolled into view, the same text passes.
    private func isFalseAlarm(
        _ issue: XCUIAccessibilityAuditIssue, element: XCUIElement, bottomButton: Bool
    ) -> Bool {
        guard issue.auditType == .contrast else { return false }
        return !element.isEnabled || isUnderABar(element.frame, bottomButton: bottomButton)
    }

    private func isUnderABar(_ frame: CGRect, bottomButton: Bool) -> Bool {
        let fade: CGFloat = 44
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame)
            + app.tabBars.allElementsBoundByIndex.map(\.frame)
        if bars.contains(where: { $0.insetBy(dx: 0, dy: -fade).intersects(frame) }) { return true }
        return bottomButton && frame.maxY > app.windows.firstMatch.frame.maxY - 2 * fade - 12
    }

    // MARK: Moving around

    /// Scrolls until the element can be tapped.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) is missing", file: file, line: line)
        var swipes = 0
        while !element.isHittable, swipes < 15 {
            app.swipeUp()
            swipes += 1
        }
        element.tap()
    }

    /// Drags the sheet to full height, where it is opaque. At half height it is glass over home, and the audit
    /// measures the cards behind it rather than what a dad reads.
    private func expandSheet() {
        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let grabber = close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 120, dy: -8))
        grabber.press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: .zero))
        sleep(1)
    }

    private func close() {
        app.buttons["Close"].firstMatch.tap()
        sleep(1)
    }
}
