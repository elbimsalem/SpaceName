import Foundation
import Combine

enum OverlayCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

final class Settings: ObservableObject {
    private let defaults: UserDefaults
    var onChange: (() -> Void)?

    static let labelFontSizeRange: ClosedRange<Double> = 10...40
    static let hudFontSizeRange: ClosedRange<Double> = 20...72

    private enum Key {
        static let switchHUD = "switchHUDEnabled"
        static let persistentLabel = "persistentLabelEnabled"
        static let menuBarName = "menuBarNameEnabled"
        static let overlayCorner = "overlayCorner"
        static let labelFontSize = "labelFontSize"
        static let hudFontSize = "hudFontSize"
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.switchHUD: true,
            Key.persistentLabel: false,
            Key.menuBarName: false,
            Key.overlayCorner: OverlayCorner.topRight.rawValue,
            Key.labelFontSize: 13.0,
            Key.hudFontSize: 34.0
        ])
    }

    private func changed() {
        objectWillChange.send()
        onChange?()
    }

    var switchHUDEnabled: Bool {
        get { defaults.bool(forKey: Key.switchHUD) }
        set { defaults.set(newValue, forKey: Key.switchHUD); changed() }
    }

    var persistentLabelEnabled: Bool {
        get { defaults.bool(forKey: Key.persistentLabel) }
        set { defaults.set(newValue, forKey: Key.persistentLabel); changed() }
    }

    var menuBarNameEnabled: Bool {
        get { defaults.bool(forKey: Key.menuBarName) }
        set { defaults.set(newValue, forKey: Key.menuBarName); changed() }
    }

    var overlayCorner: OverlayCorner {
        get { OverlayCorner(rawValue: defaults.string(forKey: Key.overlayCorner) ?? "") ?? .topRight }
        set { defaults.set(newValue.rawValue, forKey: Key.overlayCorner); changed() }
    }

    var labelFontSize: Double {
        get { defaults.double(forKey: Key.labelFontSize) }
        set { defaults.set(newValue, forKey: Key.labelFontSize); changed() }
    }

    var hudFontSize: Double {
        get { defaults.double(forKey: Key.hudFontSize) }
        set { defaults.set(newValue, forKey: Key.hudFontSize); changed() }
    }
}
