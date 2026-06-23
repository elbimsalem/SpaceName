import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// AppCoordinator is wired in a later task; for now just prove it launches.
app.run()
