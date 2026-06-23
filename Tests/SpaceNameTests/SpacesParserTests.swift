import XCTest
@testable import SpaceName

final class SpacesParserTests: XCTestCase {

    private func space(uuid: String, id: Int, type: Int = 0, fullscreen: Bool = false) -> [String: Any] {
        var d: [String: Any] = ["uuid": uuid, "ManagedSpaceID": id, "type": type]
        if fullscreen { d["TileLayoutManager"] = ["x": 1] }
        return d
    }

    func test_parsesDesktopsWithNumbering() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Current Space": space(uuid: "b", id: 2),
            "Spaces": [space(uuid: "a", id: 1), space(uuid: "b", id: 2), space(uuid: "c", id: 3)]
        ]]
        let result = SpacesParser.parse(raw)
        XCTAssertEqual(result.count, 1)
        let spaces = result[0].spaces
        XCTAssertEqual(spaces.map(\.uuid), ["a", "b", "c"])
        XCTAssertEqual(spaces.map(\.desktopNumber), [1, 2, 3])
        XCTAssertEqual(spaces.first(where: \.isCurrent)?.uuid, "b")
    }

    func test_filtersOutFullscreenSpaces() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Current Space": space(uuid: "a", id: 1),
            "Spaces": [
                space(uuid: "a", id: 1),
                space(uuid: "fs", id: 9, type: 4, fullscreen: true)
            ]
        ]]
        let result = SpacesParser.parse(raw)
        XCTAssertEqual(result[0].spaces.map(\.uuid), ["a"])
        XCTAssertEqual(result[0].spaces[0].desktopNumber, 1)
    }

    func test_multipleDisplays() {
        let raw: [[String: Any]] = [
            ["Display Identifier": "D1", "Current Space": space(uuid: "a", id: 1),
             "Spaces": [space(uuid: "a", id: 1)]],
            ["Display Identifier": "D2", "Current Space": space(uuid: "z", id: 5),
             "Spaces": [space(uuid: "y", id: 4), space(uuid: "z", id: 5)]]
        ]
        let result = SpacesParser.parse(raw)
        XCTAssertEqual(result.map(\.displayID), ["D1", "D2"])
        XCTAssertEqual(result[1].spaces.first(where: \.isCurrent)?.uuid, "z")
        XCTAssertEqual(result[1].spaces.map(\.desktopNumber), [1, 2])
    }

    func test_malformedDisplaySkipped() {
        let raw: [[String: Any]] = [["garbage": true]]
        XCTAssertEqual(SpacesParser.parse(raw), [])
    }
}
