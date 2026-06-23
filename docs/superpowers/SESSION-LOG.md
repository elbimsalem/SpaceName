# SpaceName — Session Log

Reference log of how this project was built. Newest first.

## 2026-06-23 — Increment 2: Tabbed settings, size sliders, autosave

**Request:** Tabbed settings for label size; move the other settings there too;
autosave the Space name on change (previously only Enter saved).

**Decisions (brainstorm):** Window becomes a `TabView` — "Space Names" (the list)
+ "Appearance" (settings). Two independent size sliders (label + HUD), points,
with live previews. Toggles mirrored in both the menu and the window, kept in
sync. Menu gains "Settings…" (opens Appearance).

**Artifacts:**
- Spec: `docs/superpowers/specs/2026-06-23-settings-tabs-design.md`
- Plan: `docs/superpowers/plans/2026-06-23-settings-tabs.md`

**Execution (subagent-driven, 6 tasks):**
1. `Settings` → `ObservableObject` + `labelFontSize`/`hudFontSize` (TDD, +3 tests).
2. Reusable `OverlayCard`; `OverlayController` reads the sizes (removed hardcoded 13/34).
3. `AppearanceView` — sliders w/ previews, mirrored toggles, corner picker.
4. Window → `TabView` + name autosave (intentionally non-compiling intermediate).
5. Menu "Settings…" + `AppCoordinator` sync wiring (restored green build).
6. Rebuilt `SpaceName.app`.

**Verification:** 18/18 unit tests; clean build; app launches. Per-task reviews
all Approved; final whole-branch review (opus) **Merge — Yes**, no
Critical/Important findings.

**Accepted minor leftovers:** per-keystroke save/re-render (plan-accepted);
preview `scaleEffect` magic number; tighter label corners from the proportional
`cornerRadius`; menu→window Run-at-Login sync when the Appearance tab is already
open. User chose to ship as-is.

## 2026-06-23 — Increment 1: Initial SpaceName build

**Request:** A macOS helper to name Spaces — `.app`, run-on-login, menu-bar item,
naming window, overlay (HUD or persistent, configurable), and an uninstall option.

**Foundational constraint:** macOS exposes no public Spaces API. Used the private
CoreGraphics `CGS*` symbols (as WhichSpace/Spaceman do), isolated behind a C shim
+ `CGSSpacesMonitor`. Non-sandboxed, not Mac App Store eligible, ad-hoc signed.

**Artifacts:**
- Spec: `docs/superpowers/specs/2026-06-23-spacename-design.md`
- Plan: `docs/superpowers/plans/2026-06-23-spacename.md`

**Execution (12 tasks):** package + CGS shim → `SpaceStore` → `Settings` →
`SpacesParser` → `NameResolver` → `CGSSpacesMonitor` → `OverlayController` →
`LoginItem` → `Uninstaller` → `MainWindow` → status item + coordinator → packaging.
Pure logic built TDD; GUI/private-API build-verified + manual.

**Notable findings during the session:**
- Subagent dispatch hit repeated server-side 500s early on; fell back to inline
  execution, which later recovered for the review agents.
- Under Swift 5 language mode, top-level `main.swift` is a nonisolated context —
  creating the `@MainActor` coordinator needs `MainActor.assumeIsolated`.
- Private API verified live: read 7 desktops on the Main display, resolved the
  active Space + its UUID.

**Verification:** 15/15 unit tests; `.app` builds/signs/launches as a menu-bar
agent. Final review **Ready to merge**; fixed two cheap spec misses (UserDefaults
cleanup on uninstall, removed an unused private symbol).

**Shipped to:** GitHub `elbimsalem/SpaceName` (public), PR #1.

**Deferred:** per-display overlays (HUD/label/menu-bar name target the primary
display only) — documented in the README.
