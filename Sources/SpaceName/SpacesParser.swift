import Foundation

enum SpacesParser {
    static func parse(_ raw: [[String: Any]]) -> [DisplaySpaces] {
        var displays: [DisplaySpaces] = []

        for display in raw {
            guard let displayID = display["Display Identifier"] as? String,
                  let spaceDicts = display["Spaces"] as? [[String: Any]] else {
                continue
            }
            let currentID = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int

            var infos: [SpaceInfo] = []
            var desktopNumber = 0
            for space in spaceDicts {
                guard let uuid = space["uuid"] as? String,
                      let managedID = space["ManagedSpaceID"] as? Int else { continue }
                if isFullscreen(space) { continue }   // skip full-screen Spaces
                desktopNumber += 1
                infos.append(SpaceInfo(
                    uuid: uuid,
                    managedID: managedID,
                    displayID: displayID,
                    isCurrent: managedID == currentID,
                    desktopNumber: desktopNumber
                ))
            }
            if !infos.isEmpty {
                displays.append(DisplaySpaces(displayID: displayID, spaces: infos))
            }
        }
        return displays
    }

    private static func isFullscreen(_ space: [String: Any]) -> Bool {
        if space["TileLayoutManager"] is [String: Any] { return true }
        if let type = space["type"] as? Int, type != 0 { return true }
        return false
    }
}
