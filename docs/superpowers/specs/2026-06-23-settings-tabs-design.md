# SpaceName — Tabbed Window, Size Settings & Autosave (Design Spec)

**Date:** 2026-06-23
**Status:** Approved
**Builds on:** `2026-06-23-spacename-design.md`

## Summary

Evolve SpaceName's single-list window into a **two-tab window** and add
configurable overlay text sizes plus name autosave:

1. The window becomes a `TabView` with **Space Names** (the existing editable
   Desktop list) and **Appearance** (settings) tabs.
2. Names **autosave on every keystroke** instead of only on Return.
3. **Two independent size sliders** (points) control the persistent label and the
   switch HUD text sizes, each with a live preview.
4. The Appearance tab also holds the **overlay-corner** picker and **mirrors the
   menu's toggles** (switch HUD, persistent label, menu-bar name, run-at-login).
5. The menu keeps all its existing toggles ("both places") and gains a
   **Settings…** item that opens the window directly to the Appearance tab.

## Scope

### In scope
- `TabView` window: "Space Names" + "Appearance" tabs.
- Autosave name fields (`.onChange`), keeping `.onSubmit` too.
- `Settings.labelFontSize` (default 13, range 10–40) and `Settings.hudFontSize`
  (default 34, range 20–72), persisted in UserDefaults.
- `Settings` conforms to `ObservableObject` for SwiftUI binding.
- `OverlayController` reads `labelFontSize`/`hudFontSize` instead of hardcoded
  13/34.
- Appearance tab UI: two sliders with live preview, overlay-corner `Picker`, and
  mirrored toggles.
- Menu gains "Settings…" (opens Appearance tab); "Open SpaceName…" opens the
  Space Names tab.
- Menu ↔ window stay in sync: a change in either place updates the other and
  refreshes overlays live (via `Settings.onChange` → rebuild menu + apply state).
- Extend `SettingsTests` for the two new size values.

### Out of scope (YAGNI)
- Configurable size for the menu-bar-name text.
- Per-display overlays (still a separate documented follow-up).
- Debouncing autosave writes (data is tiny; atomic write per keystroke is fine).
- Slider unit toggles, custom ranges, themes, fonts.

## Components

### `Settings` (modify)
- Add stored, UserDefaults-backed `var labelFontSize: Double` (default 13.0) and
  `var hudFontSize: Double` (default 34.0). Setters persist, then call
  `objectWillChange.send()` and `onChange?()` (same pattern as existing
  properties — every setter now also sends `objectWillChange`).
- Conform to `ObservableObject` (`import Combine`/SwiftUI). Existing `onChange`
  closure is retained for the coordinator wiring.
- Range constants exposed for the UI: `labelFontSizeRange = 10...40`,
  `hudFontSizeRange = 20...72` (static `ClosedRange<Double>`).

### `OverlayController` (modify)
- `flashHUD` uses `settings.hudFontSize` for the card font size.
- `updatePersistentLabel` uses `settings.labelFontSize`.
- Card padding stays proportional to font size (existing `card(_:fontSize:padding:)`
  pattern; derive padding from font size so previews match live overlays).

### Window: `MainWindow.swift` (modify)
- `MainWindowController.show(tab:)` accepts a target tab and drives a
  `@State`/binding `selectedTab` in the root view. Default `.spaceNames`.
- Root view becomes a `TabView(selection:)` with two tabs:
  - **Space Names** → existing `SpaceRow` list (extracted to `SpaceNamesView`),
    with `TextField` autosave via `.onChange(of:)` calling
    `viewModel.rename(space, to:)`. Keep `.onSubmit` as well.
  - **Appearance** → new `AppearanceView`.
- "Spaces unavailable" empty state stays on the Space Names tab.

### `AppearanceView` (new, in `MainWindow.swift` or `AppearanceView.swift`)
- `@ObservedObject var settings: Settings`.
- Section "Overlays": mirrored toggles bound via explicit `Binding(get:set:)` to
  the `Settings` properties (so each write persists + fires `onChange`):
  Show overlay on switch, Persistent label, Show name in menu bar, Run at Login.
  - Run-at-Login binding reads `LoginItem.isEnabled` and writes via
    `LoginItem.setEnabled`, surfacing errors with an `NSAlert` (same behavior as
    the menu handler), then refreshes.
- Section "Sizes":
  - Persistent label size: `Slider(value:in:)` over `labelFontSizeRange`, with a
    live preview card rendered at `labelFontSize`.
  - Switch HUD size: `Slider` over `hudFontSizeRange`, with a live preview card at
    `hudFontSize`.
- Section "Position": overlay-corner `Picker` bound to `settings.overlayCorner`
  (`OverlayCorner.allCases`).
- The preview reuses the same card styling as `OverlayController` so what you see
  matches the real overlay (shared SwiftUI `OverlayCard` view extracted for reuse).

### Menu: `StatusItemController` (modify)
- Keep all existing toggles.
- Add a **Settings…** item (after "Open SpaceName…") that triggers an
  `onOpenSettings` callback opening the window to the Appearance tab.
- `rebuildMenu()` already reflects current `Settings`/`LoginItem` state; it is now
  also invoked when settings change from the window.

### `AppCoordinator` (modify)
- `settings.onChange` now does: `applyCurrentState()` **and**
  `statusController.rebuildMenu()` — keeping menu checkmarks in sync with window
  edits and refreshing overlays when sizes change.
- Provide `onOpen` → `windowController.show(tab: .spaceNames)` and
  `onOpenSettings` → `windowController.show(tab: .appearance)`.

## Data flow

- Edit a name (Space Names tab): `.onChange` → `viewModel.rename` →
  `SpaceStore.setName` (persist) → `onRename` → overlays/menu refresh.
- Change a size/toggle/corner (Appearance tab): binding setter → `Settings`
  persists → `objectWillChange` (updates the preview) + `onChange` → coordinator
  `applyCurrentState()` (re-renders overlays at new size) + `rebuildMenu()`.
- Toggle from the menu: existing handlers set `Settings`, which now also drives
  the window via `objectWillChange`.

## Error handling
- Run-at-Login failures from the Appearance tab surface via `NSAlert` and the
  toggle reflects the real `LoginItem.isEnabled` (no optimistic state).
- Size values are clamped by the slider ranges; out-of-range persisted values are
  clamped on read by the slider's `in:` range (no crash).

## Testing
- **Unit:** extend `SettingsTests` — `labelFontSize`/`hudFontSize` defaults
  (13/34) and persistence across instances; `onChange` fires on size change.
- **Manual:** tab switching; autosave (type without Enter, reopen window — name
  kept); both sliders change the live preview and the real overlays; corner
  picker moves the label; toggling in the window updates the menu and vice versa;
  "Settings…" opens the Appearance tab.

## Key decisions
- Window is the single tabbed surface (no separate settings window).
- Two independent sizes (label vs HUD), sliders in points.
- Toggles in both menu and window, kept in sync through `Settings.onChange`.
- `Settings` becomes `ObservableObject`; bindings are explicit get/set so every
  write goes through the persisting setter.
