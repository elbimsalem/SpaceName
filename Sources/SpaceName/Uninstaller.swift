import AppKit

@MainActor
enum Uninstaller {
    static func run() {
        let alert = NSAlert()
        alert.messageText = "Uninstall SpaceName?"
        alert.informativeText = "This removes the app, your saved Space names, and the login item."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        try? LoginItem.setEnabled(false)
        try? FileManager.default.removeItem(at: SpaceStore.defaultDirectory())

        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            DispatchQueue.main.async {
                if let error {
                    let a = NSAlert(error: error)
                    a.messageText = "Couldn't move SpaceName to the Trash."
                    a.runModal()
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }
}
