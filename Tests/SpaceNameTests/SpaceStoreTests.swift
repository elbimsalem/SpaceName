import XCTest
@testable import SpaceName

final class SpaceStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceNameTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_setAndGetName() {
        let store = SpaceStore(directory: tempDir())
        store.setName("Work", for: "uuid-1")
        XCTAssertEqual(store.name(for: "uuid-1"), "Work")
    }

    func test_unknownUUIDReturnsNil() {
        let store = SpaceStore(directory: tempDir())
        XCTAssertNil(store.name(for: "nope"))
    }

    func test_emptyOrWhitespaceNameClearsEntry() {
        let store = SpaceStore(directory: tempDir())
        store.setName("Work", for: "uuid-1")
        store.setName("   ", for: "uuid-1")
        XCTAssertNil(store.name(for: "uuid-1"))
    }

    func test_persistsAcrossInstances() {
        let dir = tempDir()
        let a = SpaceStore(directory: dir)
        a.setName("Mail", for: "uuid-2")
        let b = SpaceStore(directory: dir)
        XCTAssertEqual(b.name(for: "uuid-2"), "Mail")
    }

    func test_corruptFileStartsEmpty() throws {
        let dir = tempDir()
        try "not json".data(using: .utf8)!.write(to: dir.appendingPathComponent("spaces.json"))
        let store = SpaceStore(directory: dir)
        XCTAssertNil(store.name(for: "anything"))
    }
}
