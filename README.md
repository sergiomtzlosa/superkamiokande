# Super-Kamiokande 3D Explorer

A native macOS app (Objective-C + AppKit + SceneKit) that renders the
Super-Kamiokande (Super-K) neutrino detector in 3D, simulates its operation,
and lets the user configure it with sliders and buttons.

The UI is entirely programmatic — no storyboard or XIB — so the project stays
small, deterministic, and easy to audit.

## Features

- **Realistic 3D detector model**: a textured rock cavern with overburden and
  work lights; the stainless-steel tank with reinforcing rings, catwalk,
  support pylons, and service shaft; the inner detector with exactly 11,129
  gold-photocathode PMTs (67 × 159 wall PMTs + 252 bottom + 224 top); 1,885
  outer-detector PMTs; the blue water volume; a glowing fiducial wireframe;
  an access tunnel; control room, purification skid, electronics hut, and
  cables.
- **Part labels**: nine labelled callouts (tank, water, tunnel, control room,
  top dome access, inner detector, outer detector, fiducial volume, water
  purification) with projected 3D anchors and leader lines. Toggle the whole
  overlay with the **Labels** button in the viewport or View → Toggle labels.
- **Collapsible sidebar**: hide the controls to give the detector the full
  window; a **Controls** button appears below the HUD to bring it back.
- **Viewport controls**: six equal-width buttons—Center, Cutaway, Rotate,
  Explode, Labels, and Help—in a horizontal translucent bar pinned to the
  upper-right of the 3D view.
- **In-app help window**: a scrollable, dark-glass guide to the model, camera,
  simulation, sidebar controls, detector facts, and keyboard shortcuts. Open it
  with the **?** button, Help → Super-Kamiokande Help, or ⌘?.
- **Live simulation**: electron, muon, and gamma events with coloured
  Cherenkov rings, PMT hit flashes, expanding event rings, and muon tracks.
- **Live HUD**: run state, total events, last event energy/type, water
  temperature, fiducial radius, and event rate.
- **App icon**: a full multi-resolution `AppIcon.icns` (16–1024 px, @1x/@2x).
- **Dark UI**: black window, dark translucent panels, cyan accent, readable
  contrast, and monospaced live readouts.
- **Tests**: an XCTest target for the model, event engine, and view-controller
  actions, plus an automated launch/screenshot smoke test.

## Project layout

```
superkamiokande/
├── README.md                      ← this file
├── SuperKamiokande.xcodeproj/
│   ├── project.pbxproj            ← hand-written, objectVersion 56
│   └── xcshareddata/xcschemes/    ← shared app + test scheme
├── SuperKamiokande/
│   ├── main.m                     ← NSApplication entry point
│   ├── AppDelegate.h/.m           ← window, menus, smoke-test launch flags
│   ├── ViewController.h/.m        ← scene view, sidebar, HUD, labels, actions
│   ├── SKOTankBuilder.h/.m        ← procedural detector + facility model
│   ├── SKOEventEngine.h/.m        ← event simulation and Cherenkov visuals
│   ├── SKOCommon.h/.m             ← scale constants and shared colours
│   ├── SKOHelpWindowController.h/.m ← scrollable in-app help window
│   ├── Info.plist                 ← CFBundleIconFile = AppIcon
│   ├── AppIcon.icns               ← delivered app icon
│   └── Textures/
│       ├── CavernRock.png         ← rock-wall texture from the reference
│       ├── WaterSurface.png       ← water-surface texture from the reference
│       └── CavernEnvironment.jpg  ← image-based lighting environment
├── SuperKamiokandeTests/
│   ├── SKOTankBuilderTests.m      ← PMT counts, controls, event geometry
│   ├── SKOEventEngineTests.m      ← firing, delegates, counters, clamps
│   ├── SKOHelpWindowControllerTests.m ← help window and content
│   └── ViewControllerTests.m      ← layout, labels, sidebar, buttons, sliders
└── tools/
    ├── make_icon.swift            ← renders the 1024² icon source
    ├── render_scene.m             ← offscreen SceneKit preview
    └── smoke_test.sh              ← builds/launches the app and checks screenshots
```

## Build, run, test

```sh
# Build
xcodebuild -project SuperKamiokande.xcodeproj -scheme SuperKamiokande \
           -configuration Debug -derivedDataPath ./build build

# Launch
open ./build/Build/Products/Debug/SuperKamiokande.app

# Unit tests (31 tests)
xcodebuild -project SuperKamiokande.xcodeproj -scheme SuperKamiokande \
           -configuration Debug -destination 'platform=macOS' \
           -derivedDataPath ./build test

# Automated app launch + UI/scene screenshot smoke test
tools/smoke_test.sh
```

The smoke test writes `build/smoke/default.png` (AppKit chrome) and
`build/smoke/default-scene.png` (the Metal-rendered scene), plus a collapsed
sidebar / labels-hidden case and a help-window case. The window, scene, and
help screenshots are required to pass.

### Optional launch flags

| Environment variable | Effect |
|---|---|
| `SKO_SMOKE_TEST=1` | Print a smoke-test summary and quit after launch |
| `SKO_SCREENSHOT=/path/ui.png` | Save a chrome screenshot plus `-scene.png` |
| `SKO_START_COLLAPSED=1` | Start with the sidebar hidden |
| `SKO_START_LABELS_HIDDEN=1` | Start with part labels hidden |
| `SKO_START_HELP=1` | Open the help window at launch |

### Offscreen render preview

```sh
xcrun clang -fobjc-arc -fmodules -ISuperKamiokande \
  -framework Cocoa -framework SceneKit -framework Metal \
  tools/render_scene.m SuperKamiokande/SKOTankBuilder.m \
  SuperKamiokande/SKOCommon.m -o build/render_scene
./build/render_scene /tmp/sko.png 0.35
SKO_EVENT=muon SKO_TIME=0.35 ./build/render_scene /tmp/sko-event.png 0.35
```

## Controls

| Control | Action |
|---|---|
| Pause / Resume simulation | Toggle event generation |
| Reset events | Reset the event counter and last-event readout |
| Reset camera | Return to the default orbit |
| Center | Re-frame the detector with the default camera |
| Cutaway / Solid | Toggle the steel shell's X-ray opacity |
| Rotate / Stop | Toggle auto-rotation |
| Explode / Assemble | Pull detector part groups apart |
| Labels | Show/hide all part callouts |
| Help | Open the in-app help window (also ⌘?) |
| Hide controls / Controls | Collapse or reveal the left sidebar |
| Water fill | Adjust the water level (0–100 %) |
| Fiducial radius | Resize the glowing fiducial cylinder (2–16 m) |
| Water transparency | Change the water volume alpha |
| Shell opacity | Change the steel wall alpha |
| PMT gain | Brightness of PMT hit flashes |
| Event rate | Events per second (0–20) |
| Rotation speed | Auto-rotation speed |

Camera gestures: drag to orbit, scroll or pinch to zoom, double-click to
center. The Simulation menu mirrors the main actions and includes keyboard
shortcuts. Help → Super-Kamiokande Help (⌘?) explains the model, live
simulation, sidebar, and view controls.

## App config

- Target: `SuperKamiokande.app`, LSApplicationCategory `Science`
- ARC + modules ON, macOS 13 deployment target, `NSSupportsAutomaticGraphicsSwitching`
- Bundle resources: `AppIcon.icns`, `CavernRock.png`, `WaterSurface.png`,
  `CavernEnvironment.jpg`; `CFBundleIconFile = AppIcon`
- Window: opaque black background with a transparent, title-hidden titlebar
  and a dark Aqua appearance
- Tests target: macOS 14 (XCTest runtime), logic tests; app remains macOS 13

## Status

- [x] Xcode project + shared app/test scheme
- [x] Realistic textured cavern, tank, PMT arrays, facilities, tunnel
- [x] Exact 11,129 ID PMTs and 1,885 OD PMTs
- [x] Electron, muon, and gamma events with Cherenkov rings and PMT flashes
- [x] Labelled parts with projected anchors and labels toggle
- [x] Collapsible sidebar and upper-right viewport controls
- [x] Scrollable in-app help window with Help menu and ⌘? shortcut
- [x] Beautified dark sidebar, HUD, buttons, and typography
- [x] Black window background with readable contrast
- [x] 31 passing XCTest cases + launch/screenshot smoke test
- [x] `xcodebuild` completes with zero compiler/linker warnings
- [x] `AppIcon.icns` validated with `iconutil` (full iconset)
- [x] Offscreen render harness for visual checks
