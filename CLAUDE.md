# CLAUDE.md

Guidance for working in the SpaceName repo.

## What this is

SpaceName is a macOS **menu-bar agent app** (`LSUIElement`, no Dock icon) that
lets you name Mission Control Spaces (Desktops) and shows the name as an
auto-fading HUD on switch and/or a persistent on-screen label. Built with Swift
Package Manager — there is **no Xcode project**.

## Commands

```bash
swift build              # build the executable (debug)
swift test               # run the unit test suite
./build-app.sh           # build + assemble + ad-hoc-sign SpaceName.app
```

- `.build/debug/SpaceName` runs the menu-bar app and **blocks** (it calls
  `NSApplication.run()`). To smoke-test from a script, launch it backgrounded and
  kill it: `.build/debug/SpaceName & PID=$!; sleep 4; kill $PID`.
- Install/run the bundle: `open SpaceName.app` (first launch on another Mac needs
  right-click → Open; it's ad-hoc signed, not notarized).

## Architecture

All private-API usage is quarantined; everything else is plain, testable Swift.

- `Sources/CGSPrivate/` — C shim (`module.modulemap` + header) exposing the
  private CoreGraphics symbols `_CGSDefaultConnection` and
  `CGSCopyManagedDisplaySpaces`.
- `CGSSpacesMonitor.swift` — the **only** Swift file that imports `CGSPrivate`.
  Reads Spaces, observes `NSWorkspace.activeSpaceDidChangeNotification` (on
  `NSWorkspace.shared.notificationCenter`), conforms to `SpacesProviding`.
- `SpacesParser.swift` — pure transform from raw CGS dicts → `[DisplaySpaces]`
  (filters to user Desktops; numbers them; marks the active one). Fully unit-tested.
- `SpaceStore.swift` — persists user names keyed by Space `uuid` to JSON in
  `~/Library/Application Support/SpaceName/spaces.json`.
- `Settings.swift` — `ObservableObject`, UserDefaults-backed toggles + two sizes
  (`labelFontSize`, `hudFontSize`); every setter fires `objectWillChange` +
  `onChange`.
- `OverlayController.swift` / `OverlayPanel.swift` / `OverlayCard.swift` — the
  HUD + persistent label (borderless non-activating panels). `OverlayCard` is the
  single source of truth for card styling (reused by the Appearance previews).
- `StatusItemController.swift` — menu bar item + menu.
- `MainWindow.swift` — tabbed window: "Space Names" (editable, autosaving list) +
  "Appearance" (`AppearanceView.swift`: sliders, toggles, corner picker).
- `AppCoordinator.swift` — wires it all; `main.swift` is the entry point.

Data flow: a Space switch → `CGSSpacesMonitor` → `AppCoordinator.applyCurrentState`
→ overlays + menu. Settings/name edits → `Settings`/`SpaceStore` → same refresh.

## Constraints (don't break these)

- **Non-sandboxed** — the private CGS APIs fail under App Sandbox. Not Mac App
  Store eligible.
- Keep **all** CGS usage inside `CGSSpacesMonitor.swift` + the `CGSPrivate`
  target. Everything else uses the `SpacesProviding` protocol.
- Targets **macOS 15**; the executable uses **Swift 5 language mode** (AppKit
  callback ergonomics). `main.swift` creates the `@MainActor` coordinator via
  `MainActor.assumeIsolated` (top-level is a nonisolated context under v5).
- UI controllers are `@MainActor`.
- Name identity key is the Space **`uuid`** (stable); active-Space matching uses
  **`ManagedSpaceID`**. Name **Desktops only** (`type == 0`); skip full-screen
  Spaces.
- Bundle id `de.synkmedia.spacename`; ad-hoc signing.

## Conventions

- Pure logic (store, settings, parser, name resolution) is built **TDD** with
  XCTest. GUI/private-API code is build-verified + manually checked (it can't be
  meaningfully unit-tested).
- Planning artifacts live in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- Known limitation: overlays/menu-bar name target the **primary display only**
  (multi-display per-screen overlays are a deferred follow-up).
