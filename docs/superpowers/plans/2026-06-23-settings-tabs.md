# Tabbed Settings, Size Sliders & Autosave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn SpaceName's window into a two-tab window (Space Names + Appearance), add independent label/HUD size sliders, autosave name edits, and mirror the menu toggles into the window — kept in sync.

**Architecture:** `Settings` becomes an `ObservableObject` with two new persisted size values. A reusable `OverlayCard` SwiftUI view is shared by the live overlays and the Appearance previews. The window root becomes a `TabView`; the menu gains a "Settings…" entry; `AppCoordinator` wires `Settings.onChange` to refresh both overlays and the menu so the two surfaces stay consistent.

**Tech Stack:** Swift 6.2 / SwiftPM, AppKit + SwiftUI, XCTest.

## Global Constraints

- macOS 15 target; executable in Swift 5 language mode; UI types `@MainActor`.
- All private CGS usage stays only in `CGSSpacesMonitor.swift` + `CGSPrivate` (unchanged by this plan).
- `labelFontSize` default **13.0**, range **10...40**; `hudFontSize` default **34.0**, range **20...72**.
- Toggles appear in BOTH the menu and the Appearance tab and must stay in sync via `Settings.onChange`.
- Tabs are exactly **"Space Names"** and **"Appearance"**; "Open SpaceName…" opens Space Names, "Settings…" opens Appearance.
- Names autosave on every keystroke (`.onChange`) while keeping `.onSubmit`.
- Every binding write goes through the persisting `Settings` setter (no direct UserDefaults writes from views).
- Commit after every task with the message in its final step.

---

### Task 1: Settings — size values + ObservableObject (TDD)

**Files:**
- Modify: `Sources/SpaceName/Settings.swift`
- Modify: `Tests/SpaceNameTests/SettingsTests.swift`

**Interfaces:**
- Consumes: existing `Settings(defaults:)`, `OverlayCorner`.
- Produces: `Settings: ObservableObject`; `var labelFontSize: Double` (default 13.0), `var hudFontSize: Double` (default 34.0), each persisting + calling `objectWillChange.send()` + `onChange?()`; `static let labelFontSizeRange: ClosedRange<Double> = 10...40`; `static let hudFontSizeRange: ClosedRange<Double> = 20...72`. All existing setters also call `objectWillChange.send()`.

- [ ] **Step 1: Add failing tests** — append to `Tests/SpaceNameTests/SettingsTests.swift` (inside the class):

```swift
    func test_sizeDefaults() {
        let s = Settings(defaults: freshDefaults())
        XCTAssertEqual(s.labelFontSize, 13.0)
        XCTAssertEqual(s.hudFontSize, 34.0)
    }

    func test_sizesPersist() {
        let d = freshDefaults()
        let s = Settings(defaults: d)
        s.labelFontSize = 22
        s.hudFontSize = 50
        let reloaded = Settings(defaults: d)
        XCTAssertEqual(reloaded.labelFontSize, 22)
        XCTAssertEqual(reloaded.hudFontSize, 50)
    }

    func test_sizeChangeFiresOnChange() {
        let s = Settings(defaults: freshDefaults())
        var fired = 0
        s.onChange = { fired += 1 }
        s.labelFontSize = 20
        s.hudFontSize = 40
        XCTAssertEqual(fired, 2)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsTests`
Expected: FAIL — `labelFontSize`/`hudFontSize` not found.

- [ ] **Step 3: Implement** — replace the contents of `Sources/SpaceName/Settings.swift` with:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SettingsTests`
Expected: PASS (6 tests total — 3 original + 3 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/Settings.swift Tests/SpaceNameTests/SettingsTests.swift
git commit -m "feat: Settings size values + ObservableObject"
```

---

### Task 2: Reusable OverlayCard + OverlayController reads sizes

**Files:**
- Create: `Sources/SpaceName/OverlayCard.swift`
- Modify: `Sources/SpaceName/OverlayController.swift`

**Interfaces:**
- Consumes: `Settings.labelFontSize`, `Settings.hudFontSize` (Task 1).
- Produces: `struct OverlayCard: View { let text: String; let fontSize: CGFloat }` (internal, reusable by previews). `OverlayController` no longer hardcodes font sizes; `flashHUD` uses `hudFontSize`, `updatePersistentLabel` uses `labelFontSize`. The private `OverlayCardView` is removed.

- [ ] **Step 1: Create the shared card** `Sources/SpaceName/OverlayCard.swift`

```swift
import SwiftUI

/// The translucent name card shown by the overlays — shared so the Appearance
/// tab previews match the real HUD/label exactly. Padding derives from the font
/// size so a single number drives the whole card.
struct OverlayCard: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, fontSize * 0.8)
            .padding(.vertical, fontSize * 0.5)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: fontSize * 0.45, style: .continuous))
            .fixedSize()
    }
}
```

- [ ] **Step 2: Update OverlayController to use it** — in `Sources/SpaceName/OverlayController.swift`:

Replace the `card(_:fontSize:padding:)` method with one that derives the card from a single font size:

```swift
    private func card(_ text: String, fontSize: CGFloat) -> NSView {
        let host = NSHostingView(rootView: OverlayCard(text: text, fontSize: fontSize))
        host.layout()
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        return host
    }
```

In `flashHUD`, change the card construction line to:

```swift
        let view = card(name, fontSize: CGFloat(settings.hudFontSize))
```

In `updatePersistentLabel`, change the card construction line to:

```swift
        let view = card(name, fontSize: CGFloat(settings.labelFontSize))
```

Delete the `private struct OverlayCardView: View { … }` definition at the bottom of the file (replaced by `OverlayCard`).

- [ ] **Step 3: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly, no warnings.

- [ ] **Step 4: Commit**

```bash
git add Sources/SpaceName/OverlayCard.swift Sources/SpaceName/OverlayController.swift
git commit -m "feat: reusable OverlayCard, overlays read configurable sizes"
```

---

### Task 3: AppearanceView (toggles, sliders, corner, live preview)

**Files:**
- Create: `Sources/SpaceName/AppearanceView.swift`

**Interfaces:**
- Consumes: `Settings` (ObservableObject, Task 1), `OverlayCard` (Task 2), `OverlayCorner`, `LoginItem`.
- Produces: `struct AppearanceView: View` with `@ObservedObject var settings: Settings`, `let isLoginEnabled: () -> Bool`, `let setLoginEnabled: (Bool) -> Void`. Renders mirrored toggles, two size sliders with `OverlayCard` previews, and the corner picker. All toggle/slider/picker writes go through `settings`; run-at-login uses the injected callbacks.

- [ ] **Step 1: Implement** `Sources/SpaceName/AppearanceView.swift`

```swift
import SwiftUI

struct AppearanceView: View {
    @ObservedObject var settings: Settings
    let isLoginEnabled: () -> Bool
    let setLoginEnabled: (Bool) -> Void

    @State private var loginOn: Bool = false

    var body: some View {
        Form {
            Section("Overlays") {
                Toggle("Show overlay on switch", isOn: bool(\.switchHUDEnabled))
                Toggle("Persistent label", isOn: bool(\.persistentLabelEnabled))
                Toggle("Show name in menu bar", isOn: bool(\.menuBarNameEnabled))
                Toggle("Run at Login", isOn: Binding(
                    get: { loginOn },
                    set: { newValue in setLoginEnabled(newValue); loginOn = isLoginEnabled() }))
            }

            Section("Sizes") {
                sizeRow(title: "Persistent label size",
                        value: number(\.labelFontSize),
                        range: Settings.labelFontSizeRange,
                        previewSize: settings.labelFontSize)
                sizeRow(title: "Switch HUD size",
                        value: number(\.hudFontSize),
                        range: Settings.hudFontSizeRange,
                        previewSize: settings.hudFontSize)
            }

            Section("Position") {
                Picker("Persistent label corner", selection: corner) {
                    ForEach(OverlayCorner.allCases, id: \.self) { c in
                        Text(cornerLabel(c)).tag(c)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginOn = isLoginEnabled() }
    }

    @ViewBuilder
    private func sizeRow(title: String, value: Binding<Double>,
                         range: ClosedRange<Double>, previewSize: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(previewSize)) pt").foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
            HStack {
                Spacer()
                OverlayCard(text: "Desktop", fontSize: CGFloat(previewSize))
                    .scaleEffect(previewSize > 34 ? 34 / previewSize : 1, anchor: .center)  // shrink large previews to fit
                    .frame(height: 64)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Bindings (every write goes through the persisting Settings setter)

    private func bool(_ key: ReferenceWritableKeyPath<Settings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] }, set: { settings[keyPath: key] = $0 })
    }
    private func number(_ key: ReferenceWritableKeyPath<Settings, Double>) -> Binding<Double> {
        Binding(get: { settings[keyPath: key] }, set: { settings[keyPath: key] = $0 })
    }
    private var corner: Binding<OverlayCorner> {
        Binding(get: { settings.overlayCorner }, set: { settings.overlayCorner = $0 })
    }

    private func cornerLabel(_ c: OverlayCorner) -> String {
        switch c {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly. (Not shown anywhere yet — wired into the window in Task 4.)

- [ ] **Step 3: Commit**

```bash
git add Sources/SpaceName/AppearanceView.swift
git commit -m "feat: AppearanceView with size sliders, toggles, corner picker"
```

---

### Task 4: Window → TabView + Space Names autosave

**Files:**
- Modify: `Sources/SpaceName/MainWindow.swift`

**Interfaces:**
- Consumes: `SpacesViewModel`, `AppearanceView` (Task 3), `Settings`.
- Produces:
  - `enum WindowTab { case spaceNames, appearance }`
  - `MainWindowController.init(viewModel:settings:isLoginEnabled:setLoginEnabled:)` and `func show(tab: WindowTab = .spaceNames)`.
  - Root `MainView` is a `TabView(selection:)`; the Desktop list lives in a `SpaceNamesView` whose `TextField` autosaves via `.onChange` (and keeps `.onSubmit`).

- [ ] **Step 1: Replace** `Sources/SpaceName/MainWindow.swift` **with:**

```swift
import SwiftUI
import AppKit

enum WindowTab: Hashable { case spaceNames, appearance }

@MainActor
final class WindowTabSelection: ObservableObject {
    @Published var tab: WindowTab = .spaceNames
}

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    private let viewModel: SpacesViewModel
    private let settings: Settings
    private let isLoginEnabled: () -> Bool
    private let setLoginEnabled: (Bool) -> Void
    private let selection = WindowTabSelection()

    init(viewModel: SpacesViewModel,
         settings: Settings,
         isLoginEnabled: @escaping () -> Bool,
         setLoginEnabled: @escaping (Bool) -> Void) {
        self.viewModel = viewModel
        self.settings = settings
        self.isLoginEnabled = isLoginEnabled
        self.setLoginEnabled = setLoginEnabled
    }

    func show(tab: WindowTab = .spaceNames) {
        viewModel.reload()
        selection.tab = tab
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let root = MainView(viewModel: viewModel, settings: settings, selection: selection,
                            isLoginEnabled: isLoginEnabled, setLoginEnabled: setLoginEnabled)
        let hosting = NSHostingController(rootView: root)
        let w = NSWindow(contentViewController: hosting)
        w.title = "SpaceName"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.setContentSize(NSSize(width: 420, height: 520))
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct MainView: View {
    @ObservedObject var viewModel: SpacesViewModel
    @ObservedObject var settings: Settings
    @ObservedObject var selection: WindowTabSelection
    let isLoginEnabled: () -> Bool
    let setLoginEnabled: (Bool) -> Void

    var body: some View {
        TabView(selection: $selection.tab) {
            SpaceNamesView(viewModel: viewModel)
                .tabItem { Label("Space Names", systemImage: "rectangle.3.group") }
                .tag(WindowTab.spaceNames)

            AppearanceView(settings: settings,
                           isLoginEnabled: isLoginEnabled,
                           setLoginEnabled: setLoginEnabled)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
                .tag(WindowTab.appearance)
        }
        .frame(minWidth: 400, minHeight: 480)
        .padding(.top, 4)
    }
}

private struct SpaceNamesView: View {
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
        .toolbar { Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise") } }
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
                .onChange(of: text) { _, newValue in viewModel.rename(space, to: newValue) }
                .onSubmit { viewModel.rename(space, to: text) }
            if space.isCurrent {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
        .onAppear { text = viewModel.customName(for: space) }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: FAIL — `AppCoordinator` still calls `MainWindowController(viewModel:)` with the old signature. This is expected; Task 5 updates the caller. Confirm the only errors are in `AppCoordinator.swift` about the `MainWindowController` initializer arguments.

- [ ] **Step 3: Commit (compiles after Task 5; commit now as a checkpoint)**

```bash
git add Sources/SpaceName/MainWindow.swift
git commit -m "feat: tabbed window (Space Names + Appearance) with name autosave"
```

---

### Task 5: Menu "Settings…" + AppCoordinator sync wiring

**Files:**
- Modify: `Sources/SpaceName/StatusItemController.swift`
- Modify: `Sources/SpaceName/AppCoordinator.swift`

**Interfaces:**
- Consumes: `MainWindowController.show(tab:)` (Task 4), `WindowTab`, `Settings.onChange`, `LoginItem`.
- Produces: `StatusItemController.init(settings:onOpen:onOpenSettings:onUninstall:)` with a new "Settings…" menu item; `AppCoordinator` wires `settings.onChange` to refresh overlays AND rebuild the menu, supplies the window's login callbacks, and opens the correct tab from each menu item.

- [ ] **Step 1: Update StatusItemController** — in `Sources/SpaceName/StatusItemController.swift`:

Change the stored properties and initializer to add `onOpenSettings`:

```swift
    private let onOpen: () -> Void
    private let onOpenSettings: () -> Void
    private let onUninstall: () -> Void

    init(settings: Settings,
         onOpen: @escaping () -> Void,
         onOpenSettings: @escaping () -> Void,
         onUninstall: @escaping () -> Void) {
        self.settings = settings
        self.onOpen = onOpen
        self.onOpenSettings = onOpenSettings
        self.onUninstall = onUninstall
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "SpaceName")
            button.image?.isTemplate = true
        }
        rebuildMenu()
    }
```

In `rebuildMenu()`, add the "Settings…" item right after the "Open SpaceName…" item:

```swift
        menu.addItem(item("Open SpaceName…", #selector(open)))
        menu.addItem(item("Settings…", #selector(openSettings)))
        menu.addItem(.separator())
```

Add the action method alongside the other `@objc` handlers:

```swift
    @objc private func openSettings() { onOpenSettings() }
```

- [ ] **Step 2: Update AppCoordinator** — replace `Sources/SpaceName/AppCoordinator.swift` with:

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
        windowController = MainWindowController(
            viewModel: viewModel,
            settings: settings,
            isLoginEnabled: { LoginItem.isEnabled },
            setLoginEnabled: { [weak self] on in self?.setLoginEnabled(on) })

        statusController = StatusItemController(
            settings: settings,
            onOpen: { [weak self] in self?.windowController.show(tab: .spaceNames) },
            onOpenSettings: { [weak self] in self?.windowController.show(tab: .appearance) },
            onUninstall: { Uninstaller.run() })

        settings.onChange = { [weak self] in
            self?.applyCurrentState()
            self?.statusController.rebuildMenu()
        }
        viewModel.onRename = { [weak self] in self?.applyCurrentState() }
        monitor.onChange = { [weak self] _ in self?.handleSpaceChange() }
        monitor.start()

        applyCurrentState(flashHUD: false)
    }

    private func setLoginEnabled(_ on: Bool) {
        do { try LoginItem.setEnabled(on) }
        catch {
            let a = NSAlert(error: error); a.messageText = "Couldn't change the login item."; a.runModal()
        }
        statusController.rebuildMenu()
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

- [ ] **Step 3: Build + run full test suite**

Run: `swift build && swift test`
Expected: builds cleanly (no warnings); all unit tests pass (16 total).

- [ ] **Step 4: Manual smoke test (bare debug binary)**

Run: `.build/debug/SpaceName`
Verify:
- Menu shows "Open SpaceName…" and "Settings…"; both open the window, on the Space Names and Appearance tabs respectively.
- Space Names tab: type a name WITHOUT pressing Return, switch tabs and back (or close/reopen) — the name persists and the HUD uses it.
- Appearance tab: dragging "Persistent label size" / "Switch HUD size" updates the live preview; enabling the persistent label then changing its size resizes the on-screen label; the HUD uses the HUD size on the next Space switch.
- Toggling "Persistent label" (or any toggle) in the Appearance tab updates the menu checkmark, and toggling in the menu updates the Appearance tab.
- Corner picker moves the persistent label.
Quit via the menu.

- [ ] **Step 5: Commit**

```bash
git add Sources/SpaceName/StatusItemController.swift Sources/SpaceName/AppCoordinator.swift
git commit -m "feat: menu Settings item + menu/window settings sync"
```

---

### Task 6: Rebuild the app bundle

**Files:**
- (No source changes — produces the updated `SpaceName.app`.)

- [ ] **Step 1: Build the signed app**

Run: `./build-app.sh`
Expected: `==> Done: …/SpaceName.app`; `codesign --verify` reports valid.

- [ ] **Step 2: Launch test**

Run: `open SpaceName.app` then, after confirming the menu-bar item and tabbed window appear, quit it.
Expected: app runs as a menu-bar agent; window shows both tabs.

- [ ] **Step 3: Commit (only if build-app.sh changed; otherwise skip)**

No commit needed unless packaging files changed.

---

## Notes for the implementer

- Task 4 intentionally leaves the tree non-compiling (the `AppCoordinator` caller still uses the old `MainWindowController` initializer); Task 5 fixes it. Build green is expected only after Task 5.
- `OverlayCard` is the single source of truth for card styling — the Appearance previews and the live overlays must use it so they always match.
- Run-at-Login is not a `Settings` property; it routes through the injected `setLoginEnabled` callback (which rebuilds the menu), while all other toggles sync via `Settings.onChange`.
