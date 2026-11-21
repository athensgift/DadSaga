import UIKit
import XCTest

/// Settings follows the Appearance the dad picks while it is open, Automatic included: back on Automatic, Settings
/// draws in the iPhone's look, not in the last look it was given. Runs in whichever look the simulator has: on iOS 27.2
/// the simulator only applies a change of look after a reboot, so the test reads the iPhone's look from home.
@MainActor
final class SettingsAppearanceTests: XCTestCase {
    private var app: XCUIApplication!

    func testSettingsFollowsTheChoiceWhileOpen() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        finishOnboarding()
        let isPhoneDark = isDark()

        openSettings()
        XCTAssertEqual(isDark(), isPhoneDark, "Automatic when Settings opens")

        choose(isPhoneDark ? "Light" : "Dark")
        XCTAssertEqual(isDark(), !isPhoneDark, "the other look")

        choose("Automatic")
        XCTAssertEqual(isDark(), isPhoneDark, "back to Automatic")
    }

    // MARK: Moving around

    private func finishOnboarding() {
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "onboarding did not open")
        name.tap()
        name.typeText("Alex\n")
        app.buttons["Continue"].tap()
        let hero = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Super Dad'")).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        hero.tap()
        let start = app.buttons["Start the adventure"]
        while !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "home did not open")
    }

    private func openSettings() {
        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 5), "Settings did not open")
        sleep(1)
    }

    /// Picks an Appearance from the menu in Settings.
    private func choose(_ title: String) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Appearance'")).firstMatch.tap()
        let option = app.buttons[title].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "\(title) is missing")
        option.tap()
        sleep(1)
    }

    // MARK: Reading the screen

    /// Whether the screen is drawn dark: the mean brightness of its lower half, which Settings covers with its form.
    private func isDark() -> Bool {
        guard let image = app.screenshot().image.cgImage else {
            XCTFail("no screenshot")
            return false
        }
        let (width, height) = (image.width, image.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var total = 0.0
        var count = 0.0
        // CoreGraphics rows start at the top of the buffer: the lower half of the screen is the second half of it.
        for row in stride(from: height / 2, to: height - height / 10, by: 8) {
            for column in stride(from: 0, to: width, by: 8) {
                let pixel = (row * width + column) * 4
                total += (Double(pixels[pixel]) + Double(pixels[pixel + 1]) + Double(pixels[pixel + 2])) / 3
                count += 1
            }
        }
        return total / count < 128
    }
}
