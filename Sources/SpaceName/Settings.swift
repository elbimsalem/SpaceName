import Foundation

enum OverlayCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

final class Settings {
    private let defaults: UserDefaults
    var onChange: (() -> Void)?

    private enum Key {
        static let switchHUD = "switchHUDEnabled"
        static let persistentLabel = "persistentLabelEnabled"
        static let menuBarName = "menuBarNameEnabled"
        static let overlayCorner = "overlayCorner"
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.switchHUD: true,
            Key.persistentLabel: false,
            Key.menuBarName: false,
            Key.overlayCorner: OverlayCorner.topRight.rawValue
        ])
    }

    var switchHUDEnabled: Bool {
        get { defaults.bool(forKey: Key.switchHUD) }
        set { defaults.set(newValue, forKey: Key.switchHUD); onChange?() }
    }

    var persistentLabelEnabled: Bool {
        get { defaults.bool(forKey: Key.persistentLabel) }
        set { defaults.set(newValue, forKey: Key.persistentLabel); onChange?() }
    }

    var menuBarNameEnabled: Bool {
        get { defaults.bool(forKey: Key.menuBarName) }
        set { defaults.set(newValue, forKey: Key.menuBarName); onChange?() }
    }

    var overlayCorner: OverlayCorner {
        get { OverlayCorner(rawValue: defaults.string(forKey: Key.overlayCorner) ?? "") ?? .topRight }
        set { defaults.set(newValue.rawValue, forKey: Key.overlayCorner); onChange?() }
    }
}
