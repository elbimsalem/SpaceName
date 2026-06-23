import SwiftUI

@MainActor
final class SpacesViewModel: ObservableObject {
    @Published var displays: [DisplaySpaces] = []
    private let provider: SpacesProviding
    private let store: SpaceStore
    var onRename: (() -> Void)?

    init(provider: SpacesProviding, store: SpaceStore) {
        self.provider = provider
        self.store = store
        reload()
    }

    func reload() { displays = provider.currentSnapshot() }

    func name(for space: SpaceInfo) -> String {
        NameResolver.displayName(for: space, store: store)
    }

    func customName(for space: SpaceInfo) -> String {
        store.name(for: space.uuid) ?? ""
    }

    func rename(_ space: SpaceInfo, to newName: String) {
        store.setName(newName, for: space.uuid)
        onRename?()
        objectWillChange.send()
    }
}
