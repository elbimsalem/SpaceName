# SpaceName Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu-bar app that names Mission Control Spaces (Desktops) and shows those names as an auto-fading HUD on switch and/or a persistent overlay, packaged as a double-clickable `.app`.

**Architecture:** A single menu-bar agent app (`LSUIElement`). All private CoreGraphics (CGS) usage is quarantined in a C-shim module + one Swift wrapper behind a protocol. Pure logic units (parser, store, settings) are TDD-unit-tested; the GUI/private-API units have implementation code plus a manual verification step. SwiftPM builds the binary; a shell script assembles and ad-hoc-signs the bundle.

**Tech Stack:** Swift 6.2 / SwiftPM, AppKit + SwiftUI, ServiceManagement (`SMAppService`), private CoreGraphics CGS symbols via a C module, XCTest.

## Global Constraints

- macOS deployment target: **macOS 15** (`.macOS(.v15)` in Package.swift, `LSMinimumSystemVersion` = `15.0`).
- App MUST be **non-sandboxed** (no App Sandbox entitlement) — private CGS APIs fail under sandbox.
- All private CGS symbols live ONLY in the `CGSPrivate` C target; no other file imports them except `CGSSpacesMonitor.swift`.
- Persistent identity key for a Space name is its **`uuid`** string (stable across reboots); the in-session "which is active" match uses **`ManagedSpaceID`** (Int).
- Name only **user/desktop Spaces** (`type == 0`, i.e. no `TileLayoutManager` key); ignore full-screen Spaces.
- Space-change notifications MUST be observed on `NSWorkspace.shared.notificationCenter` (NOT the default center) using `NSWorkspace.activeSpaceDidChangeNotification`.
- Bundle identifier: `de.synkmedia.spacename`. App name: `SpaceName`. Executable target name: `SpaceName`.
- UI controllers are `@MainActor`. The executable target uses Swift 5 language mode (`.swiftLanguageMode(.v5)`) to avoid strict-concurrency friction in AppKit callback code; pure-logic types remain `Sendable`-friendly.
- Distribution: ad-hoc local signing (`codesign --force --sign -`). First launch needs right-click → Open.
- Commit after every task with the message shown in that task's final step.

---

### Task 1: Package scaffold + CGSPrivate shim (builds & runs empty)

**Files:**
- Create: `Package.swift`
- Create: `Sources/CGSPrivate/include/CGSPrivate.h`
- Create: `Sources/CGSPrivate/include/module.modulemap`
- Create: `Sources/SpaceName/main.swift`
- Create: `Tests/SpaceNameTests/SmokeTests.swift`

**Interfaces:**
- Produces: the `CGSPrivate` module exposing `_CGSDefaultConnection() -> Int32` and `CGSCopyManagedDisplaySpaces(_ conn: Int32) -> Any!`; an executable that launches an `NSApplication` accessory app.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SpaceName",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "CGSPrivate",
            path: "Sources/CGSPrivate"
        ),
        .executableTarget(
            name: "SpaceName",
            dependencies: ["CGSPrivate"],
            path: "Sources/SpaceName",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SpaceNameTests",
            dependencies: ["SpaceName"],
            path: "Tests/SpaceNameTests"
        )
    ]
)
```

- [ ] **Step 2: Write the C shim header** `Sources/CGSPrivate/include/CGSPrivate.h`

```c
#ifndef CGSPrivate_h
#define CGSPrivate_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

int _CGSDefaultConnection(void);
id  CGSCopyManagedDisplaySpaces(int conn);
id  CGSCopyActiveMenuBarDisplayIdentifier(int conn);

#endif /* CGSPrivate_h */
```

- [ ] **Step 3: Write the module map** `Sources/CGSPrivate/include/module.modulemap`

```
module CGSPrivate {
    header "CGSPrivate.h"
    export *
}
```

- [ ] **Step 4: Write a minimal entry point** `Sources/SpaceName/main.swift`

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// AppCoordinator is wired in a later task; for now just prove it launches.
app.run()
```

- [ ] **Step 5: Write a smoke test** `Tests/SpaceNameTests/SmokeTests.swift`

```swift
import XCTest

final class SmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 6: Build and test**

Run: `swift build && swift test`
Expected: build succeeds; 1 test passes. (The executable will hang if run because `app.run()` blocks — that's expected; do not run it here.)

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: package scaffold and CGSPrivate C shim"
```

---

### Task 2: SpaceStore (uuid → name persistence) — TDD

**Files:**
- Create: `Sources/SpaceName/SpaceStore.swift`
- Create: `Tests/SpaceNameTests/SpaceStoreTests.swift`

**Interfaces:**
- Produces: `final class SpaceStore` with `init(directory: URL)`, `func name(for uuid: String) -> String?`, `func setName(_ name: String?, for uuid: String)`, `func allNames() -> [String: String]`. Persists to `<directory>/spaces.json`. Empty/whitespace names clear the entry.

- [ ] **Step 1: Write failing tests** `Tests/SpaceNameTests/SpaceStoreTests.swift`

```swift
import XCTest
@testable import SpaceName

final class SpaceStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceNameTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_setAndGetName() {
        let store = SpaceStore(directory: tempDir())
        store.setName("Work", for: "uuid-1")
        XCTAssertEqual(store.name(for: "uuid-1"), "Work")
    }

    func test_unknownUUIDReturnsNil() {
        let store = SpaceStore(directory: tempDir())
        XCTAssertNil(store.name(for: "nope"))
    }

    func test_emptyOrWhitespaceNameClearsEntry() {
        let store = SpaceStore(directory: tempDir())
        store.setName("Work", for: "uuid-1")
        store.setName("   ", for: "uuid-1")
        XCTAssertNil(store.name(for: "uuid-1"))
    }

    func test_persistsAcrossInstances() {
        let dir = tempDir()
        let a = SpaceStore(directory: dir)
        a.setName("Mail", for: "uuid-2")
        let b = SpaceStore(directory: dir)
        XCTAssertEqual(b.name(for: "uuid-2"), "Mail")
    }

    func test_corruptFileStartsEmpty() throws {
        let dir = tempDir()
        try "not json".data(using: .utf8)!.write(to: dir.appendingPathComponent("spaces.json"))
        let store = SpaceStore(directory: dir)
        XCTAssertNil(store.name(for: "anything"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SpaceStoreTests`
Expected: FAIL — `SpaceStore` not found.

- [ ] **Step 3: Implement** `Sources/SpaceName/SpaceStore.swift`

```swift
import Foundation

/// Persists user-assigned Space names keyed by the Space's stable `uuid`.
final class SpaceStore {
    private let fileURL: URL
    private var names: [String: String]

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("spaces.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.names = decoded
        } else {
            self.names = [:]
        }
    }

    func name(for uuid: String) -> String? {
        names[uuid]
    }

    func setName(_ name: String?, for uuid: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            names[uuid] = trimmed
        } else {
            names.removeValue(forKey: uuid)
        }
        save()
    }

    func allNames() -> [String: String] { names }

    private func save() {
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Default on-disk location used by the app (not used in tests).
    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SpaceName", isDirectory: true)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SpaceStoreTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/SpaceStore.swift Tests/SpaceNameTests/SpaceStoreTests.swift
git commit -m "feat: SpaceStore uuid-to-name persistence"
```

---

### Task 3: Settings (UserDefaults-backed config) — TDD

**Files:**
- Create: `Sources/SpaceName/Settings.swift`
- Create: `Tests/SpaceNameTests/SettingsTests.swift`

**Interfaces:**
- Produces: `final class Settings` with `init(defaults: UserDefaults)` and stored properties `switchHUDEnabled: Bool` (default `true`), `persistentLabelEnabled: Bool` (default `false`), `menuBarNameEnabled: Bool` (default `false`), `overlayCorner: OverlayCorner` (default `.topRight`). Each property persists on set. `enum OverlayCorner: String, CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }`. `var onChange: (() -> Void)?` fires after any property changes.

- [ ] **Step 1: Write failing tests** `Tests/SpaceNameTests/SettingsTests.swift`

```swift
import XCTest
@testable import SpaceName

final class SettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "SettingsTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        return d
    }

    func test_defaults() {
        let s = Settings(defaults: freshDefaults())
        XCTAssertTrue(s.switchHUDEnabled)
        XCTAssertFalse(s.persistentLabelEnabled)
        XCTAssertFalse(s.menuBarNameEnabled)
        XCTAssertEqual(s.overlayCorner, .topRight)
    }

    func test_persistsValues() {
        let d = freshDefaults()
        let s = Settings(defaults: d)
        s.persistentLabelEnabled = true
        s.overlayCorner = .bottomLeft
        let reloaded = Settings(defaults: d)
        XCTAssertTrue(reloaded.persistentLabelEnabled)
        XCTAssertEqual(reloaded.overlayCorner, .bottomLeft)
    }

    func test_onChangeFires() {
        let s = Settings(defaults: freshDefaults())
        var fired = 0
        s.onChange = { fired += 1 }
        s.menuBarNameEnabled = true
        XCTAssertEqual(fired, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsTests`
Expected: FAIL — `Settings` not found.

- [ ] **Step 3: Implement** `Sources/SpaceName/Settings.swift`

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SettingsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/Settings.swift Tests/SpaceNameTests/SettingsTests.swift
git commit -m "feat: Settings config persistence"
```

---

### Task 4: Spaces model + parser (raw CGS dicts → DisplaySpaces) — TDD

This is the heart of the logic and the big testability win: the parser takes the raw `[[String: Any]]` that CGS returns and produces clean models, with NO private-API dependency, so it is fully unit-tested with hand-built dictionaries (the same approach WhichSpace uses with its `CGSStub`).

**Files:**
- Create: `Sources/SpaceName/SpaceModels.swift`
- Create: `Sources/SpaceName/SpacesParser.swift`
- Create: `Tests/SpaceNameTests/SpacesParserTests.swift`

**Interfaces:**
- Produces:
  - `struct SpaceInfo: Equatable { let uuid: String; let managedID: Int; let displayID: String; let isCurrent: Bool; let desktopNumber: Int }`
  - `struct DisplaySpaces: Equatable { let displayID: String; let spaces: [SpaceInfo] }`
  - `enum SpacesParser { static func parse(_ raw: [[String: Any]]) -> [DisplaySpaces] }` — filters to user Spaces (no `TileLayoutManager` key and `type == 0`), numbers them 1-based per display, marks current by matching the display's `Current Space` `ManagedSpaceID`.
  - `protocol SpacesProviding { func currentSnapshot() -> [DisplaySpaces] }` (consumed by later tasks).

- [ ] **Step 1: Write failing tests** `Tests/SpaceNameTests/SpacesParserTests.swift`

```swift
import XCTest
@testable import SpaceName

final class SpacesParserTests: XCTestCase {

    private func space(uuid: String, id: Int, type: Int = 0, fullscreen: Bool = false) -> [String: Any] {
        var d: [String: Any] = ["uuid": uuid, "ManagedSpaceID": id, "type": type]
        if fullscreen { d["TileLayoutManager"] = ["x": 1] }
        return d
    }

    func test_parsesDesktopsWithNumbering() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Current Space": space(uuid: "b", id: 2),
            "Spaces": [space(uuid: "a", id: 1), space(uuid: "b", id: 2), space(uuid: "c", id: 3)]
        ]]
        let result = SpacesParser.parse(raw)
        XCTAssertEqual(result.count, 1)
        let spaces = result[0].spaces
        XCTAssertEqual(spaces.map(\.uuid), ["a", "b", "c"])
        XCTAssertEqual(spaces.map(\.desktopNumber), [1, 2, 3])
        XCTAssertEqual(spaces.first(where: \.isCurrent)?.uuid, "b")
    }

    func test_filtersOutFullscreenSpaces() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Current Space": space(uuid: "a", id: 1),
            "Spaces": [
                space(uuid: "a", id: 1),
                space(uuid: "fs", id: 9, type: 4, fullscreen: true)
            ]
        ]]
        let result = SpacesParser.parse(raw)
        XCTAssertEqual(result[0].spaces.map(\.uuid), ["a"])
        XCTAssertEqual(result[0].spaces[0].desktopNumber, 1)
    }

    func test_multipleDisplays() {
        let raw: [[String: Any]] = [
            ["Display Identifier": "D1", "Current Space": space(uuid: "a", id: 1),
             "Spaces": [space(uuid: "a", id: 1)]],
            ["Display Identifier": "D2", "Current Space": space(uuid: "z", id: 5),
             "Spaces": [space(uuid: "y", id: 4), space(uuid: "z", id: 5)]]
        ]
        let result = SpacesParser.parse(raw)
        XCTAssertEqual(result.map(\.displayID), ["D1", "D2"])
        XCTAssertEqual(result[1].spaces.first(where: \.isCurrent)?.uuid, "z")
        XCTAssertEqual(result[1].spaces.map(\.desktopNumber), [1, 2])
    }

    func test_malformedDisplaySkipped() {
        let raw: [[String: Any]] = [["garbage": true]]
        XCTAssertEqual(SpacesParser.parse(raw), [])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SpacesParserTests`
Expected: FAIL — `SpacesParser`/`SpaceInfo` not found.

- [ ] **Step 3: Implement models** `Sources/SpaceName/SpaceModels.swift`

```swift
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
```

- [ ] **Step 4: Implement parser** `Sources/SpaceName/SpacesParser.swift`

```swift
import Foundation

enum SpacesParser {
    static func parse(_ raw: [[String: Any]]) -> [DisplaySpaces] {
        var displays: [DisplaySpaces] = []

        for display in raw {
            guard let displayID = display["Display Identifier"] as? String,
                  let spaceDicts = display["Spaces"] as? [[String: Any]] else {
                continue
            }
            let currentID = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int

            var infos: [SpaceInfo] = []
            var desktopNumber = 0
            for space in spaceDicts {
                guard let uuid = space["uuid"] as? String,
                      let managedID = space["ManagedSpaceID"] as? Int else { continue }
                if isFullscreen(space) { continue }   // skip full-screen Spaces
                desktopNumber += 1
                infos.append(SpaceInfo(
                    uuid: uuid,
                    managedID: managedID,
                    displayID: displayID,
                    isCurrent: managedID == currentID,
                    desktopNumber: desktopNumber
                ))
            }
            if !infos.isEmpty {
                displays.append(DisplaySpaces(displayID: displayID, spaces: infos))
            }
        }
        return displays
    }

    private static func isFullscreen(_ space: [String: Any]) -> Bool {
        if space["TileLayoutManager"] is [String: Any] { return true }
        if let type = space["type"] as? Int, type != 0 { return true }
        return false
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter SpacesParserTests`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/SpaceName/SpaceModels.swift Sources/SpaceName/SpacesParser.swift Tests/SpaceNameTests/SpacesParserTests.swift
git commit -m "feat: Spaces model and CGS-dictionary parser"
```

---

### Task 5: Display-name resolver — TDD

A tiny pure unit that turns a `SpaceInfo` + `SpaceStore` into the string shown everywhere ("Work", or "Desktop 2" if unnamed). Centralizes the fallback so HUD, menu, label, and window all agree.

**Files:**
- Create: `Sources/SpaceName/NameResolver.swift`
- Create: `Tests/SpaceNameTests/NameResolverTests.swift`

**Interfaces:**
- Consumes: `SpaceStore`, `SpaceInfo` (Task 2, 4).
- Produces: `enum NameResolver { static func displayName(for space: SpaceInfo, store: SpaceStore) -> String }` → custom name if set, else `"Desktop \(space.desktopNumber)"`.

- [ ] **Step 1: Write failing tests** `Tests/SpaceNameTests/NameResolverTests.swift`

```swift
import XCTest
@testable import SpaceName

final class NameResolverTests: XCTestCase {
    private func store() -> SpaceStore {
        SpaceStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("NR-\(UUID().uuidString)"))
    }
    private func info(uuid: String, n: Int) -> SpaceInfo {
        SpaceInfo(uuid: uuid, managedID: n, displayID: "Main", isCurrent: false, desktopNumber: n)
    }

    func test_usesCustomNameWhenSet() {
        let s = store(); s.setName("Work", for: "a")
        XCTAssertEqual(NameResolver.displayName(for: info(uuid: "a", n: 1), store: s), "Work")
    }

    func test_fallsBackToDesktopNumber() {
        XCTAssertEqual(NameResolver.displayName(for: info(uuid: "b", n: 3), store: store()), "Desktop 3")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NameResolverTests`
Expected: FAIL — `NameResolver` not found.

- [ ] **Step 3: Implement** `Sources/SpaceName/NameResolver.swift`

```swift
import Foundation

enum NameResolver {
    static func displayName(for space: SpaceInfo, store: SpaceStore) -> String {
        store.name(for: space.uuid) ?? "Desktop \(space.desktopNumber)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NameResolverTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/NameResolver.swift Tests/SpaceNameTests/NameResolverTests.swift
git commit -m "feat: NameResolver with Desktop-N fallback"
```

---

### Task 6: CGSSpacesMonitor (real private-API provider + change events)

The single Swift file that touches CGS. Conforms to `SpacesProviding`, and broadcasts changes when the active Space changes. Not unit-tested (private API); verified manually via a temporary debug print.

**Files:**
- Create: `Sources/SpaceName/CGSSpacesMonitor.swift`

**Interfaces:**
- Consumes: `CGSPrivate` module, `SpacesParser`, `SpacesProviding`, `DisplaySpaces`.
- Produces: `final class CGSSpacesMonitor: SpacesProviding` with `init()`, `func currentSnapshot() -> [DisplaySpaces]`, `var onChange: (([DisplaySpaces]) -> Void)?`, `func start()` (subscribes to the notification), and `func currentActiveSpace() -> SpaceInfo?` (the current Space on the main display).

- [ ] **Step 1: Implement** `Sources/SpaceName/CGSSpacesMonitor.swift`

```swift
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
```

- [ ] **Step 2: Add a temporary debug entry point** — replace `Sources/SpaceName/main.swift` body temporarily:

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let monitor = CGSSpacesMonitor()
print("DEBUG snapshot:", monitor.currentSnapshot())
monitor.onChange = { snap in
    print("DEBUG changed:", snap.map { "\($0.displayID): \($0.spaces.map(\.desktopNumber))" })
}
monitor.start()
app.run()
```

- [ ] **Step 3: Build and run manually to verify private API works**

Run: `swift build && .build/debug/SpaceName`
Expected: prints a `DEBUG snapshot:` line listing your real displays and desktop numbers. Switch Spaces (Ctrl+→) and see `DEBUG changed:` lines. Press Ctrl+C to stop.
If the snapshot is empty `[]`, the private API returned nothing — confirm the app is not sandboxed and you're on a normal desktop (not the login window).

- [ ] **Step 4: Restore the minimal `main.swift`** (revert the debug body back to the Task 1 version — the real wiring comes in Task 11):

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/CGSSpacesMonitor.swift Sources/SpaceName/main.swift
git commit -m "feat: CGSSpacesMonitor real private-API provider"
```

---

### Task 7: OverlayController (auto-fade HUD + persistent corner label)

**Files:**
- Create: `Sources/SpaceName/OverlayPanel.swift`
- Create: `Sources/SpaceName/OverlayController.swift`

**Interfaces:**
- Consumes: `Settings`, `OverlayCorner`.
- Produces:
  - `final class OverlayPanel: NSPanel` — borderless, non-activating, all-Spaces, click-through.
  - `@MainActor final class OverlayController` with `init(settings: Settings)`, `func flashHUD(_ name: String)` (centered, ~1.2s, fades out), `func updatePersistentLabel(_ name: String?)` (shows/refreshes the corner label when `settings.persistentLabelEnabled`, hides it otherwise), `func refreshConfiguration()` (re-reads settings; hides the persistent label if it was just disabled).

- [ ] **Step 1: Implement** `Sources/SpaceName/OverlayPanel.swift`

```swift
import AppKit

final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Implement** `Sources/SpaceName/OverlayController.swift`

```swift
import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private let settings: Settings
    private let hudPanel = OverlayPanel()
    private let labelPanel = OverlayPanel()
    private var hudDismissWork: DispatchWorkItem?

    init(settings: Settings) {
        configure(hudPanel, view: nil)
        configure(labelPanel, view: nil)
    }

    private func configure(_ panel: OverlayPanel, view: NSView?) {
        if let view { panel.contentView = view }
    }

    private func card(_ text: String, fontSize: CGFloat, padding: CGFloat) -> NSView {
        let host = NSHostingView(rootView: OverlayCardView(text: text, fontSize: fontSize, padding: padding))
        host.layout()
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        return host
    }

    // MARK: HUD

    func flashHUD(_ name: String) {
        guard settings.switchHUDEnabled else { return }
        let view = card(name, fontSize: 34, padding: 28)
        hudPanel.setContentSize(view.fittingSize)
        hudPanel.contentView = view
        centerOnActiveScreen(hudPanel)
        hudPanel.alphaValue = 0
        hudPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; hudPanel.animator().alphaValue = 1 }

        hudDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fadeOutHUD() }
        hudDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func fadeOutHUD() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            hudPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.hudPanel.orderOut(nil) })
    }

    // MARK: Persistent label

    func updatePersistentLabel(_ name: String?) {
        guard settings.persistentLabelEnabled, let name else {
            labelPanel.orderOut(nil)
            return
        }
        let view = card(name, fontSize: 13, padding: 10)
        labelPanel.setContentSize(view.fittingSize)
        labelPanel.contentView = view
        positionInCorner(labelPanel, corner: settings.overlayCorner)
        labelPanel.orderFrontRegardless()
    }

    func refreshConfiguration() {
        if !settings.persistentLabelEnabled { labelPanel.orderOut(nil) }
    }

    // MARK: Positioning

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        let s = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: f.midX - s.width / 2, y: f.midY - s.height / 2))
    }

    private func positionInCorner(_ panel: NSPanel, corner: OverlayCorner) {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let s = panel.frame.size
        let m: CGFloat = 16
        let x: CGFloat = (corner == .topLeft || corner == .bottomLeft) ? v.minX + m : v.maxX - s.width - m
        let y: CGFloat = (corner == .topLeft || corner == .topRight) ? v.maxY - s.height - m : v.minY + m
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct OverlayCardView: View {
    let text: String
    let fontSize: CGFloat
    let padding: CGFloat
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, padding)
            .padding(.vertical, padding * 0.6)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .fixedSize()
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly. (Visual behavior is verified end-to-end in Task 11.)

- [ ] **Step 4: Commit**

```bash
git add Sources/SpaceName/OverlayPanel.swift Sources/SpaceName/OverlayController.swift
git commit -m "feat: OverlayController HUD and persistent label"
```

---

### Task 8: LoginItem wrapper (SMAppService)

**Files:**
- Create: `Sources/SpaceName/LoginItem.swift`

**Interfaces:**
- Produces: `enum LoginItem` with `static var isEnabled: Bool`, `static func setEnabled(_ on: Bool) throws`, `static func openSettings()`.

- [ ] **Step 1: Implement** `Sources/SpaceName/LoginItem.swift`

```swift
import ServiceManagement

enum LoginItem {
    private static var service: SMAppService { .mainApp }

    static var isEnabled: Bool { service.status == .enabled }

    static func setEnabled(_ on: Bool) throws {
        if on {
            if service.status != .enabled { try service.register() }
        } else {
            try service.unregister()
        }
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly. (Real register/unregister is verified from the installed `.app` in Task 12 — it only works from a signed bundle, not the bare debug binary.)

- [ ] **Step 3: Commit**

```bash
git add Sources/SpaceName/LoginItem.swift
git commit -m "feat: LoginItem SMAppService wrapper"
```

---

### Task 9: Uninstaller

**Files:**
- Create: `Sources/SpaceName/Uninstaller.swift`

**Interfaces:**
- Consumes: `LoginItem`, `SpaceStore`.
- Produces: `@MainActor enum Uninstaller { static func run() }` — confirms, unregisters login item, deletes app-support dir, moves the app bundle to Trash, quits.

- [ ] **Step 1: Implement** `Sources/SpaceName/Uninstaller.swift`

```swift
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly. (Full uninstall is verified from the installed `.app` in Task 12.)

- [ ] **Step 3: Commit**

```bash
git add Sources/SpaceName/Uninstaller.swift
git commit -m "feat: Uninstaller move-to-Trash flow"
```

---

### Task 10: MainWindow (SwiftUI list of Desktops with editable names)

**Files:**
- Create: `Sources/SpaceName/SpacesViewModel.swift`
- Create: `Sources/SpaceName/MainWindow.swift`

**Interfaces:**
- Consumes: `SpacesProviding`, `SpaceStore`, `DisplaySpaces`, `SpaceInfo`, `NameResolver`.
- Produces:
  - `@MainActor final class SpacesViewModel: ObservableObject` with `@Published var displays: [DisplaySpaces]`, `init(provider: SpacesProviding, store: SpaceStore)`, `func reload()`, `func name(for: SpaceInfo) -> String`, `func rename(_ space: SpaceInfo, to newName: String)`, and `var onRename: (() -> Void)?` (lets the coordinator refresh overlays/menu live).
  - `@MainActor final class MainWindowController` with `init(viewModel: SpacesViewModel)` and `func show()`.

- [ ] **Step 1: Implement view model** `Sources/SpaceName/SpacesViewModel.swift`

```swift
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
```

- [ ] **Step 2: Implement window + view** `Sources/SpaceName/MainWindow.swift`

```swift
import SwiftUI
import AppKit

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    private let viewModel: SpacesViewModel

    init(viewModel: SpacesViewModel) { self.viewModel = viewModel }

    func show() {
        viewModel.reload()
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: MainView(viewModel: viewModel))
        let w = NSWindow(contentViewController: hosting)
        w.title = "SpaceName"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.setContentSize(NSSize(width: 380, height: 460))
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct MainView: View {
    @ObservedObject var viewModel: SpacesViewModel

    var body: some View {
        Group {
            if viewModel.displays.isEmpty {
                ContentUnavailableView("Spaces unavailable",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("SpaceName couldn't read your Spaces. Make sure you're on a desktop and try again."))
            } else {
                List {
                    ForEach(viewModel.displays, id: \.displayID) { display in
                        Section(header: Text(displayTitle(display))) {
                            ForEach(display.spaces, id: \.uuid) { space in
                                SpaceRow(space: space, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
        .toolbar {
            Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise") }
        }
    }

    private func displayTitle(_ d: DisplaySpaces) -> String {
        viewModel.displays.count > 1 ? "Display: \(d.displayID)" : "Desktops"
    }
}

private struct SpaceRow: View {
    let space: SpaceInfo
    @ObservedObject var viewModel: SpacesViewModel
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text("\(space.desktopNumber)")
                .font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            TextField("Desktop \(space.desktopNumber)", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { viewModel.rename(space, to: text) }
            if space.isCurrent {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
        .onAppear { text = viewModel.customName(for: space) }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly. (Window behavior verified in Task 11/12.)

- [ ] **Step 4: Commit**

```bash
git add Sources/SpaceName/SpacesViewModel.swift Sources/SpaceName/MainWindow.swift
git commit -m "feat: MainWindow editable Desktop list"
```

---

### Task 11: StatusItemController + AppCoordinator (wire everything)

**Files:**
- Create: `Sources/SpaceName/StatusItemController.swift`
- Create: `Sources/SpaceName/AppCoordinator.swift`
- Modify: `Sources/SpaceName/main.swift`

**Interfaces:**
- Consumes: all prior components.
- Produces:
  - `@MainActor final class StatusItemController` with `init(settings:, onOpen:, onUninstall:)`, `func setCurrentName(_ name: String?)` (updates menu-bar title when `menuBarNameEnabled`), `func rebuildMenu()`.
  - `@MainActor final class AppCoordinator: NSObject, NSApplicationDelegate`.

- [ ] **Step 1: Implement status item** `Sources/SpaceName/StatusItemController.swift`

```swift
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
```

- [ ] **Step 2: Implement coordinator** `Sources/SpaceName/AppCoordinator.swift`

```swift
import AppKit

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let settings: Settings
    private let store: SpaceStore
    private let monitor = CGSSpacesMonitor()
    private let overlay: OverlayController
    private let viewModel: SpacesViewModel
    private var statusController: StatusItemController!
    private var windowController: MainWindowController!

    override init() {
        let defaults = UserDefaults.standard
        self.settings = Settings(defaults: defaults)
        self.store = SpaceStore(directory: SpaceStore.defaultDirectory())
        self.overlay = OverlayController(settings: settings)
        self.viewModel = SpacesViewModel(provider: monitor, store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(
            settings: settings,
            onOpen: { [weak self] in self?.windowController.show() },
            onUninstall: { Uninstaller.run() })
        windowController = MainWindowController(viewModel: viewModel)

        settings.onChange = { [weak self] in self?.applyCurrentState() }
        viewModel.onRename = { [weak self] in self?.applyCurrentState() }
        monitor.onChange = { [weak self] _ in self?.handleSpaceChange() }
        monitor.start()

        applyCurrentState(flashHUD: false)
    }

    private func handleSpaceChange() {
        viewModel.reload()
        applyCurrentState(flashHUD: true)
    }

    private func applyCurrentState(flashHUD: Bool = false) {
        overlay.refreshConfiguration()
        let active = monitor.currentActiveSpace()
        let name = active.map { NameResolver.displayName(for: $0, store: store) }
        if flashHUD, let name { overlay.flashHUD(name) }
        overlay.updatePersistentLabel(name)
        statusController.setCurrentName(name)
    }
}
```

- [ ] **Step 3: Wire the entry point** — replace `Sources/SpaceName/main.swift`

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let coordinator = AppCoordinator()
app.delegate = coordinator
app.run()
```

- [ ] **Step 4: Build and run the bare binary to smoke-test the menu bar**

Run: `swift build && .build/debug/SpaceName`
Expected: a menu-bar icon (`rectangle.3.group`) appears. Click it → menu shows Open/toggles/Uninstall/Quit. Switching Spaces flashes the centered HUD with "Desktop N". Open the window, type a name, press Return → HUD/label use the new name. (Run-at-login and uninstall are only fully testable from the signed `.app` in Task 12.) Quit via the menu.

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/StatusItemController.swift Sources/SpaceName/AppCoordinator.swift Sources/SpaceName/main.swift
git commit -m "feat: status item and AppCoordinator wiring"
```

---

### Task 12: Packaging — icon, build script, `.app`, README

**Files:**
- Create: `icon.png` (1024×1024 placeholder — generated below)
- Create: `make-icon.sh`
- Create: `build-app.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: the built executable at `.build/release/SpaceName`.
- Produces: a double-clickable, ad-hoc-signed `SpaceName.app`.

- [ ] **Step 1: Generate a placeholder 1024×1024 icon**

Run:
```bash
swift -e 'import AppKit
let s = NSImage(size: NSSize(width: 1024, height: 1024))
s.lockFocus()
NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 180, yRadius: 180).fill()
let p = NSMutableParagraphStyle(); p.alignment = .center
("SN" as NSString).draw(in: NSRect(x: 0, y: 360, width: 1024, height: 320),
  withAttributes: [.font: NSFont.systemFont(ofSize: 360, weight: .bold), .foregroundColor: NSColor.white, .paragraphStyle: p])
s.unlockFocus()
let r = NSBitmapImageRep(data: s.tiffRepresentation!)!
try! r.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon.png"))'
```
Expected: creates `icon.png`. (Replace with a real icon anytime.)

- [ ] **Step 2: Write** `make-icon.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
SRC="${1:?usage: make-icon.sh <source.png> <out.icns>}"
OUT="${2:?usage: make-icon.sh <source.png> <out.icns>}"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "${ICONSET}"
gen() { sips -z "$1" "$1" "${SRC}" --out "${ICONSET}/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
gen 1024 icon_512x512@2x.png
iconutil -c icns "${ICONSET}" -o "${OUT}"
echo "wrote ${OUT}"
```

- [ ] **Step 3: Write** `build-app.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpaceName"
BUNDLE_ID="de.synkmedia.spacename"
VERSION="1.0.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${ROOT}/${APP_NAME}.app"
CONTENTS="${APP}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RES_DIR="${CONTENTS}/Resources"

echo "==> Building (release)…"
swift build -c release

BIN="${ROOT}/.build/release/${APP_NAME}"
[[ -f "${BIN}" ]] || { echo "error: binary not found at ${BIN}" >&2; exit 1; }

echo "==> Assembling ${APP_NAME}.app…"
rm -rf "${APP}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"
cp "${BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [[ -f "${ROOT}/icon.png" ]]; then
  bash "${ROOT}/make-icon.sh" "${ROOT}/icon.png" "${RES_DIR}/AppIcon.icns"
fi

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>        <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>         <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>         <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>            <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>     <string>15.0</string>
    <key>LSUIElement</key>                <true/>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc codesigning…"
codesign --force --sign - "${APP}"
codesign --verify --verbose "${APP}"
echo "==> Done: ${APP}"
```

- [ ] **Step 4: Make scripts executable and build the app**

Run: `chmod +x build-app.sh make-icon.sh && ./build-app.sh`
Expected: prints `==> Done: …/SpaceName.app`; `codesign --verify` reports valid.

- [ ] **Step 5: Install and verify end-to-end**

Run: `cp -R SpaceName.app /Applications/ && open /Applications/SpaceName.app`
Expected, verify each:
- Menu-bar icon appears; **no Dock icon**.
- Switching Spaces (Ctrl+→/←) flashes the centered name HUD.
- Open SpaceName → window lists Desktops across displays; renaming persists and updates the HUD.
- Toggle "Persistent overlay label" → a corner label appears and follows you across Spaces.
- Toggle "Show name in menu bar" → current Space name shows next to the icon.
- Toggle "Run at Login" → check **System Settings → General → Login Items** shows SpaceName enabled; untoggle removes it.
- Uninstall… → confirm → app moves to Trash, login item removed, app quits.

- [ ] **Step 6: Write** `README.md`

```markdown
# SpaceName

Name your macOS Mission Control Spaces (Desktops) and see the name as a HUD when
you switch, or as a persistent on-screen label.

## Build

```bash
./build-app.sh        # produces SpaceName.app (ad-hoc signed)
```

## Install

Copy `SpaceName.app` to `/Applications`. On first launch, **right-click → Open**
once (it's ad-hoc signed, not notarized) to get past Gatekeeper.

## Use

- The app lives in the menu bar (no Dock icon).
- **Open SpaceName** to name each Desktop.
- Toggle the switch HUD, a persistent corner label, the menu-bar name, and
  Run-at-Login from the menu.
- **Uninstall…** removes the app, your saved names, and the login item.

## Notes

SpaceName uses private CoreGraphics APIs to read Spaces (the only way macOS
allows this). It is therefore non-sandboxed and not distributed via the Mac App
Store. Names are stored locally in
`~/Library/Application Support/SpaceName/spaces.json`.
```

- [ ] **Step 7: Commit**

```bash
git add icon.png make-icon.sh build-app.sh README.md
git commit -m "feat: app packaging, icon, build script, README"
```

---

## Notes for the implementer

- If `swift build` emits strict-concurrency errors, confirm the executable target has `.swiftLanguageMode(.v5)` (Task 1) — pure-logic types (`SpaceStore`, `Settings`, `SpacesParser`) are independent of it and stay testable.
- The bare debug binary (`.build/debug/SpaceName`) is fine for testing the menu bar, HUD, window, and Space reading. `SMAppService` (Run-at-Login) and self-uninstall only behave correctly from the assembled `/Applications/SpaceName.app` — verify those there (Task 12).
- Keep all CGS access inside `CGSSpacesMonitor.swift`; everything else works against `SpacesProviding`.
