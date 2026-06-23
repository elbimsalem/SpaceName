import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// main.swift runs on the main thread, but under the v5 language mode it is a
// nonisolated context, so creating the @MainActor coordinator needs assumeIsolated.
let coordinator = MainActor.assumeIsolated { AppCoordinator() }
app.delegate = coordinator
app.run()
