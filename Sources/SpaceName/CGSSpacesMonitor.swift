import AppKit
import CGSPrivate

@MainActor
final class CGSSpacesMonitor: SpacesProviding {
    private let conn = _CGSDefaultConnection()
    var onChange: (([DisplaySpaces]) -> Void)?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil)
    }

    @objc private func activeSpaceChanged() {
        onChange?(currentSnapshot())
    }

    func currentSnapshot() -> [DisplaySpaces] {
        guard let raw = CGSCopyManagedDisplaySpaces(conn) as? [[String: Any]] else {
            return []   // "Spaces unavailable" — caller degrades gracefully
        }
        return SpacesParser.parse(raw)
    }

    /// The active Space on the first (main) display, if any.
    func currentActiveSpace() -> SpaceInfo? {
        currentSnapshot().first?.spaces.first(where: \.isCurrent)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
