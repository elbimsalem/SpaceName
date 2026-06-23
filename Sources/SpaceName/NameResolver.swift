import Foundation

enum NameResolver {
    static func displayName(for space: SpaceInfo, store: SpaceStore) -> String {
        store.name(for: space.uuid) ?? "Desktop \(space.desktopNumber)"
    }
}
