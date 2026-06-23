import AppKit

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let settings: Settings
    private let onOpen: () -> Void
    private let onUninstall: () -> Void

    init(settings: Settings, onOpen: @escaping () -> Void, onUninstall: @escaping () -> Void) {
        self.settings = settings
        self.onOpen = onOpen
        self.onUninstall = onUninstall
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "SpaceName")
            button.image?.isTemplate = true
        }
        rebuildMenu()
    }

    func setCurrentName(_ name: String?) {
        guard let button = statusItem.button else { return }
        if settings.menuBarNameEnabled, let name {
            button.title = " \(name)"
        } else {
            button.title = ""
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(item("Open SpaceName…", #selector(open)))
        menu.addItem(.separator())
        menu.addItem(toggle("Show overlay on switch", settings.switchHUDEnabled, #selector(toggleHUD)))
        menu.addItem(toggle("Persistent overlay label", settings.persistentLabelEnabled, #selector(togglePersistent)))
        menu.addItem(toggle("Show name in menu bar", settings.menuBarNameEnabled, #selector(toggleMenuBarName)))
        menu.addItem(toggle("Run at Login", LoginItem.isEnabled, #selector(toggleLogin)))
        menu.addItem(.separator())
        menu.addItem(item("Uninstall…", #selector(uninstall)))
        menu.addItem(item("Quit SpaceName", #selector(quit)))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "")
    }
    private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.state = on ? .on : .off
        return i
    }

    @objc private func open() { onOpen() }
    @objc private func uninstall() { onUninstall() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleHUD() { settings.switchHUDEnabled.toggle(); rebuildMenu() }
    @objc private func togglePersistent() { settings.persistentLabelEnabled.toggle(); rebuildMenu() }
    @objc private func toggleMenuBarName() { settings.menuBarNameEnabled.toggle(); rebuildMenu() }
    @objc private func toggleLogin() {
        do { try LoginItem.setEnabled(!LoginItem.isEnabled) }
        catch {
            let a = NSAlert(error: error); a.messageText = "Couldn't change the login item."; a.runModal()
        }
        rebuildMenu()
    }
}
