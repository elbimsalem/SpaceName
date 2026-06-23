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

    func test_sizeDefaults() {
        let s = Settings(defaults: freshDefaults())
        XCTAssertEqual(s.labelFontSize, 13.0)
        XCTAssertEqual(s.hudFontSize, 34.0)
    }

    func test_sizesPersist() {
        let d = freshDefaults()
        let s = Settings(defaults: d)
        s.labelFontSize = 22
        s.hudFontSize = 50
        let reloaded = Settings(defaults: d)
        XCTAssertEqual(reloaded.labelFontSize, 22)
        XCTAssertEqual(reloaded.hudFontSize, 50)
    }

    func test_sizeChangeFiresOnChange() {
        let s = Settings(defaults: freshDefaults())
        var fired = 0
        s.onChange = { fired += 1 }
        s.labelFontSize = 20
        s.hudFontSize = 40
        XCTAssertEqual(fired, 2)
    }
}
