import AppKit
import XCTest
@testable import Burnrate

/// Theme is a small enum, but it is load-bearing in both directions: the
/// stored value decides what the whole app looks like, and an unknown value
/// must degrade to "follow the Mac" rather than to a crash or a stuck mode.
@MainActor
final class ThemeTests: XCTestCase {
    func testRawValuesRoundTrip() {
        XCTAssertEqual(Theme(rawValue: "system"), .system)
        XCTAssertEqual(Theme(rawValue: "light"), .light)
        XCTAssertEqual(Theme(rawValue: "dark"), .dark)
        XCTAssertNil(Theme(rawValue: "solarized"))
    }

    func testSystemHasNoOpinionAndTheOthersDo() {
        XCTAssertNil(Theme.system.nsAppearance)
        XCTAssertEqual(Theme.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(Theme.dark.nsAppearance?.name, .darkAqua)
    }

    func testDarkAppearanceDetection() {
        XCTAssertTrue(NSAppearance(named: .darkAqua)!.isDark)
        XCTAssertTrue(NSAppearance(named: .vibrantDark)!.isDark)
        XCTAssertFalse(NSAppearance(named: .aqua)!.isDark)
        XCTAssertFalse(NSAppearance(named: .vibrantLight)!.isDark)
    }

    func testThemeSurvivesARestart() {
        let name = "ThemeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }

        defaults.set("dark", forKey: "theme")
        XCTAssertEqual(Preferences(defaults: defaults).theme, .dark)

        // Absent means no opinion, not "dark by accident".
        let freshName = "ThemeTests.\(UUID().uuidString)"
        let fresh = UserDefaults(suiteName: freshName)!
        addTeardownBlock { fresh.removePersistentDomain(forName: freshName) }
        XCTAssertEqual(Preferences(defaults: fresh).theme, .system)
    }
}
