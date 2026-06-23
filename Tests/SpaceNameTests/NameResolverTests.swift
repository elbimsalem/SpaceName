import XCTest
@testable import SpaceName

final class NameResolverTests: XCTestCase {
    private func store() -> SpaceStore {
        SpaceStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("NR-\(UUID().uuidString)"))
    }
    private func info(uuid: String, n: Int) -> SpaceInfo {
        SpaceInfo(uuid: uuid, managedID: n, displayID: "Main", isCurrent: false, desktopNumber: n)
    }

    func test_usesCustomNameWhenSet() {
        let s = store(); s.setName("Work", for: "a")
        XCTAssertEqual(NameResolver.displayName(for: info(uuid: "a", n: 1), store: s), "Work")
    }

    func test_fallsBackToDesktopNumber() {
        XCTAssertEqual(NameResolver.displayName(for: info(uuid: "b", n: 3), store: store()), "Desktop 3")
    }
}
