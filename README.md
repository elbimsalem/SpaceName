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
- **Open SpaceName…** to name each Desktop.
- Toggle the switch HUD, a persistent corner label, the menu-bar name, and
  Run-at-Login from the menu.
- **Uninstall…** removes the app, your saved names, and the login item.

## Notes

SpaceName uses private CoreGraphics APIs to read Spaces (the only way macOS
allows this). It is therefore non-sandboxed and not distributed via the Mac App
Store. Names are stored locally in
`~/Library/Application Support/SpaceName/spaces.json`.

## Development

```bash
swift build      # build the executable
swift test       # run the unit test suite (SpaceStore, Settings, parser, NameResolver)
```

Architecture and the full task-by-task plan live in `docs/superpowers/`.
All private-API usage is isolated in `CGSSpacesMonitor.swift` + the `CGSPrivate`
C shim; everything else works against the `SpacesProviding` protocol.
