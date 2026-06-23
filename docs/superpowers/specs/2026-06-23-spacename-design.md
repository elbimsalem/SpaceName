# SpaceName — Design Spec

**Date:** 2026-06-23
**Status:** Approved
**Platform:** macOS 15+ (built with Xcode 26.3 / Swift 6.2)

## Summary

SpaceName is a macOS menu-bar helper that lets you give names to your Mission
Control Spaces (Desktops) and surfaces those names as an overlay when you switch
Spaces and/or as a persistent on-screen label. It installs as a double-clickable
`.app`, can run at login, lives in the menu bar, provides a window for naming
Spaces, and can uninstall itself.

## Foundational Constraint

macOS exposes **no public API** for Spaces: it cannot name them, enumerate them,
or report which Space is active. SpaceName therefore relies on a **private
CoreGraphics framework** (`CGSCopyManagedDisplaySpaces` and related `CGS*`
symbols) to read a stable per-Space UUID, and stores its **own** UUID→name
mapping. macOS itself never knows the names — only SpaceName does.

Consequences (accepted):
- Cannot ship on the Mac App Store (private API usage).
- Distributed as a directly-installed, **ad-hoc / locally signed** `.app`; first
  launch requires right-click → Open once (Gatekeeper). No Apple Developer
  account required.
- All private-API usage is quarantined behind a single protocol boundary so the
  unsupported surface is isolated and can degrade gracefully if a future macOS
  changes the symbols.

The single public hook available is
`NSWorkspace.activeSpaceDidChangeNotification`, used to detect switches.

## Scope

### In scope
- Menu-bar-only agent app (no Dock icon, `LSUIElement`).
- Main window: live list of **all Desktops across all displays**, each with an
  editable name field; edits persist immediately and update overlays live.
- Switch overlay: **centered, translucent, auto-fading HUD** showing the Space
  name on switch (volume/brightness-HUD style).
- Persistent overlay: **both** options available as independent toggles —
  (a) floating corner label that follows you across Spaces, and
  (b) the menu bar item rendering the current Space name.
- Run at login (toggle).
- Uninstall from the menu.
- Built via Swift Package + build script into `SpaceName.app`.

### Out of scope (YAGNI)
- Naming full-screen-app Spaces (transient, app-bound). We name **Desktops
  only**. Full-screen Spaces are simply not listed.
- Mac App Store distribution / notarization (can be added later if a paid
  Developer account is provided).
- Reordering Spaces, creating/deleting Spaces, keyboard shortcuts to switch.
- iCloud/cross-machine name sync.

## Architecture

A single menu-bar agent app. One responsibility per file. All private-API usage
lives in exactly one place.

```
SpaceName (NSApplication, LSUIElement agent)
 ├── SpacesMonitor        ← private-API boundary (CGS), protocol-fronted
 ├── SpaceStore           ← UUID→name persistence (JSON, App Support)
 ├── Settings             ← UserDefaults-backed config
 ├── OverlayController    ← HUD + persistent label windows
 ├── StatusItemController ← menu bar item + menu (+ optional name display)
 ├── MainWindow (SwiftUI) ← editable list of all Desktops
 ├── LoginItem            ← SMAppService wrapper
 └── AppCoordinator       ← wiring / lifecycle
```

## Components

### SpacesMonitor (private-API boundary)
- Wraps `CGSMainConnectionID()` + `CGSCopyManagedDisplaySpaces(...)` to enumerate
  Spaces per display and identify the active Space per display.
- Filters to user Desktops (`type == 0`); ignores full-screen Spaces.
- Subscribes to `NSWorkspace.shared.notificationCenter`
  `activeSpaceDidChangeNotification`; on fire, re-reads and emits the new active
  Space UUID(s).
- Exposed via a protocol (`SpacesProviding`) so the rest of the app and the tests
  never import the private symbols directly; a fake implementation drives tests.
- Returns optionals throughout; a nil/empty result is surfaced upward as
  "Spaces unavailable" rather than crashing.

### SpaceStore
- Source of truth for `[SpaceUUID: name]`.
- Persists as JSON at
  `~/Library/Application Support/SpaceName/spaces.json`.
- Pure logic, fully unit-testable. Provides `name(for:)`, `setName(_:for:)`,
  load/save, and a display label fallback ("Desktop N") when unnamed.

### Settings
- UserDefaults-backed. Keys: `switchHUDEnabled` (Bool),
  `persistentLabelEnabled` (Bool), `menuBarNameEnabled` (Bool),
  `overlayCorner` (enum for persistent label position),
  `hudPosition` (centered by default).
- Publishes changes so overlays/menu update reactively.

### OverlayController
- Owns overlay windows. Windows are borderless, non-activating
  (`NSPanel`/`NSWindow` with `.nonactivatingPanel` semantics), `level` above
  normal content (e.g. `.statusBar`/`.screenSaver`),
  `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle,
  .fullScreenAuxiliary]`, `ignoresMouseEvents = true`.
- **HUD:** on switch (if `switchHUDEnabled`), shows a centered translucent card
  with the Space name, holds ~1s, fades out. One per active display.
- **Persistent label:** if `persistentLabelEnabled`, shows a small corner label
  that updates on switch and persists across Spaces.

### StatusItemController
- `NSStatusItem` with menu:
  - Open SpaceName (main window)
  - Toggle: Switch overlay
  - Toggle: Persistent label
  - Toggle: Show name in menu bar
  - Toggle: Run at Login
  - Uninstall…
  - Quit
- If `menuBarNameEnabled`, the status item title shows the current Space name.

### MainWindow (SwiftUI)
- Lists all Desktops grouped by display ("Display 1 → Desktop 1, 2, 3…").
- Each row: current name (editable `TextField`) + the underlying Desktop's
  position. Edits call `SpaceStore.setName` immediately; overlays/menu refresh
  live.
- Shows a clear "Spaces unavailable" state if the monitor returns nothing.

### LoginItem
- Wraps `SMAppService.mainApp.register()` / `.unregister()` and reports current
  status. Registration failure surfaces as an alert; the toggle reflects true
  state.

### AppCoordinator
- Wires components, owns lifecycle, handles app activation policy
  (`.accessory`).

## Data Flow

1. **Launch:** `SpaceStore` loads names → `SpacesMonitor` reads current Spaces →
   `StatusItemController` builds the menu → if persistent label/menu-bar name
   enabled, render them.
2. **Space switch:** `activeSpaceDidChangeNotification` → `SpacesMonitor`
   resolves new active UUID(s) → `SpaceStore.name(for:)` →
   `OverlayController` flashes HUD (if enabled) and/or updates persistent label;
   `StatusItemController` updates menu-bar title (if enabled).
3. **Naming:** edit in `MainWindow` → `SpaceStore.setName` → persisted →
   overlays/menu refresh live.
4. **Settings change:** toggle in menu → `Settings` updates → overlays/menu
   react.

## Error Handling
- Private API nil/empty → "Spaces unavailable" state in window + no overlays;
  app stays alive and recovers automatically when the API returns data again.
- Login-item register/unregister failure → alert; toggle reflects real state.
- Uninstall failure (e.g. Trash move denied) → alert; app does not quit so the
  user can retry.
- Persistence read failure → start with an empty mapping rather than crashing.

## Uninstall Flow (menu item)
1. Confirm with the user (destructive-action alert).
2. `LoginItem.unregister()`.
3. Delete `~/Library/Application Support/SpaceName/` and the app's UserDefaults
   domain.
4. Move `SpaceName.app` to Trash via `NSWorkspace.shared.recycle`.
5. Terminate the app.

## Packaging & Build
- `Package.swift` (executable target + test target).
- `Scripts/build-app.sh`:
  - `swift build -c release`
  - Assemble `SpaceName.app/Contents/{MacOS,Resources}` with `Info.plist`
    (`LSUIElement=YES`, bundle id, version) and an app icon.
  - Ad-hoc codesign (`codesign --sign -`).
  - Output a double-clickable `SpaceName.app`.
- README notes the right-click → Open first-launch step.

## Testing
- **Unit (automated):** `SpaceStore` (persistence round-trip, name resolution,
  "Desktop N" fallback), `Settings` (defaults + persistence),
  name-resolution logic via a fake `SpacesProviding`.
- **Manual checklist:** overlay HUD appearance/fade, persistent label across
  Spaces, menu-bar name, run-at-login round-trip, multi-display, uninstall,
  "Spaces unavailable" degradation.

## Key Decisions
- Private CGS APIs accepted; isolated behind one protocol boundary.
- Desktops only; full-screen Spaces ignored.
- Both persistent-overlay options (floating label + menu-bar name) offered as
  independent toggles.
- SwiftPM + build script; ad-hoc local signing.
```
