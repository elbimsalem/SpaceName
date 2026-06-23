import XCTest
@testable import SpaceName

final class SettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "SettingsTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        return d
    }

    func test_defaults() {
        let s = Settings(defaults: freshDefaults())
        XCTAssertTrue(s.switchHUDEnabled)
        XCTAssertFalse(s.persistentLabelEnabled)
        XCTAssertFalse(s.menuBarNameEnabled)
        XCTAssertEqual(s.overlayCorner, .topRight)
    }

    func test_persistsValues() {
        let d = freshDefaults()
        let s = Settings(defaults: d)
        s.persistentLabelEnabled = true
        s.overlayCorner = .bottomLeft
        let reloaded = Settings(defaults: d)
        XCTAssertTrue(reloaded.persistentLabelEnabled)
        XCTAssertEqual(reloaded.overlayCorner, .bottomLeft)
    }

    func test_onChangeFires() {
        let s = Settings(defaults: freshDefaults())
        var fired = 0
        s.onChange = { fired += 1 }
        s.menuBarNameEnabled = true
        XCTAssertEqual(fired, 1)
    }
}
