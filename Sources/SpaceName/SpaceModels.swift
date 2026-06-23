import Foundation

struct SpaceInfo: Equatable {
    let uuid: String
    let managedID: Int
    let displayID: String
    let isCurrent: Bool
    let desktopNumber: Int
}

struct DisplaySpaces: Equatable {
    let displayID: String
    let spaces: [SpaceInfo]
}

/// Abstraction over the (private-API) source of Space data so the app and tests
/// never touch CGS directly.
protocol SpacesProviding {
    func currentSnapshot() -> [DisplaySpaces]
}
