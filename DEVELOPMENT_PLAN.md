# Sprite Engine — Development Plan

**App:** Sprite Engine (macOS 14+, Apple Silicon, arm64)  
**Design reference:** `claude design files/Neo Geo Emulator.html`  
**Technical spec:** `arcade_emulator_handoff.md`

Work through phases in order. Each phase is scoped to fit in one Claude Code session without hitting context limits.

---

## Phase 1 — Xcode Project Scaffold

**Goal:** Empty project that compiles cleanly with three targets wired together.

Tasks:
- Create `SpriteEngine.xcodeproj` (macOS App target, Swift, SwiftUI lifecycle)
- Add two static library targets: `GeolithLib` (C) and `FBNeoCPSLib` (C++)
- Create the full folder skeleton matching the handoff's `ArcadeEmulator/` tree
- Add `Shared/SpriteEngine-Bridging-Header.h` (empty for now)
- Set deployment target macOS 14.0, arch arm64 only, Swift 5.10
- Enable Hardened Runtime; disable App Sandbox
- Verify: project builds with zero errors (no source yet, just empty stubs)

Deliverable: `SpriteEngine.xcodeproj` with three targets, correct build settings, folder tree created.

---

## Phase 2 — Git Submodules + C/C++ Library Targets Compile

**Goal:** Both native libraries compile from source for arm64.

Tasks:
- `git submodule add https://gitlab.com/jgemu/geolith GeolithLib/geolith`
- `git submodule add https://github.com/finalburnneo/FBNeo FBNeoCPSLib/fbneo`
- Configure `GeolithLib` target: add all `.c` sources, `-std=c11`, `-arch arm64`
- Create stub `GeolithLib/bridge/geolith_bridge.h` (forward-declares only — real API in Phase 4)
- Configure `FBNeoCPSLib` target: add CPS subset sources, `-std=c++17`, preprocessor `SUBSET_CPS12=1`, `-arch arm64`
- Create stub `FBNeoCPSLib/bridge/fbneo_cps_bridge.h` (empty extern "C" block)
- Verify: both static libs compile without errors (warnings OK)

Deliverable: Both submodules present; `GeolithLib.a` and `FBNeoCPSLib.a` build for arm64.

---

## Phase 3 — Core Models & Protocol

**Goal:** All Swift model types and the `EmulatorCore` protocol in place — no emulation logic yet.

Files to create:
- `ArcadeEmulator/Models/Game.swift` — `Game` struct (Identifiable, Codable)
- `ArcadeEmulator/Models/System.swift` — `EmulatorSystem` enum with `coreType`
- `ArcadeEmulator/Models/SaveState.swift` — `SaveState` struct
- `ArcadeEmulator/Emulation/EmulatorCore.swift` — `EmulatorCore` protocol (exact signature from handoff)
- `ArcadeEmulator/Emulation/EmulatorError.swift` — `EmulatorError: LocalizedError` enum
- `ArcadeEmulator/Library/GameMetadata.swift` — placeholder artwork / metadata types

Verify: project compiles, all types visible to Swift.

---

## Phase 4 — Geolith C Bridge + GeolithCore.swift

**Goal:** Swift can call Geolith's C API and hold a context pointer.

Tasks:
- Read actual `GeolithLib/geolith/src/geolith.h` and reconcile any signature differences with the handoff
- Write `GeolithLib/bridge/geolith_bridge.h` (pass-through include + any helper macros)
- Update bridging header to include it
- Implement `GeolithCore.swift` — full `EmulatorCore` conformance wrapping the C API
  - `init`, `loadROM`, `runFrame`, `framebuffer()`, `audioSamples()`, `setInput`, `saveState`, `loadState`, `reset`, `shutdown`
- Add `EmulatorError` throw sites

Verify: `GeolithCore` compiles; calling `geolith_create()` from Swift doesn't crash (no ROM yet).

---

## Phase 5 — Metal Renderer (sharp mode)

**Goal:** A Metal MTKView that can display a RGBA pixel buffer at correct aspect ratio.

Files:
- `ArcadeEmulator/Rendering/EmulatorView.swift` — `MTKView` subclass with `update(framebuffer:width:height:)` entry point
- `ArcadeEmulator/Rendering/MetalRenderer.swift` — creates `MTLTexture`, fullscreen quad draw, aspect-ratio letterbox/pillarbox
- `ArcadeEmulator/Rendering/Shaders.metal` — vertex passthrough + **sharp** (nearest-neighbor) fragment shader only

Aspect ratios: Neo Geo 4:3 (320×224), CPS 384×224 (~1.7:1). Pillarbox/letterbox to maintain ratio.

Verify: renderer initialises without crashing; a test gradient texture renders at correct aspect ratio in a test window.

---

## Phase 6 — First Playable Loop (Geolith only)

**Goal:** A real Neo Geo `.neo` file boots, frame renders on screen, controls TBD.

Files:
- `ArcadeEmulator/Emulation/EmulatorSession.swift` — full threading implementation from handoff (background thread, double-buffer, `os_unfair_lock`, FPS throttle)
- Temporary `ContentView.swift` — opens a hardcoded `.neo` path, creates `GeolithCore`, creates `EmulatorSession`, embeds `EmulatorView` in SwiftUI via `NSViewRepresentable`

Verify: game frame renders at ~59 fps; Metal view updates visibly.

---

## Phase 7 — Audio Engine

**Goal:** Emulator audio plays through speakers.

Files:
- `ArcadeEmulator/Audio/AudioEngine.swift` — `AVAudioSourceNode` + `RingBuffer<Int16>` (thread-safe with `os_unfair_lock`)
- Wire into `EmulatorSession`: after `core.runFrame()`, call `audio.push(samples:count:)`

Verify: sound plays during Geolith session; no crackling under normal load.

---

## Phase 8 — Input Manager

**Goal:** Keyboard and connected gamepad control the emulated game.

Files:
- `ArcadeEmulator/Input/InputManager.swift` — `Buttons` OptionSet, keyboard map (WASD+UIJK for P1), `GCController` handler, `onInputChanged` callback
- Wire into `EmulatorSession`: input callback calls `core.setInput(player:buttons:)` on emulation thread

Verify: WASD moves character; connected MFi/Xbox controller works.

---

## Phase 9 — FBNeo CPS Bridge + FBNeoCPSCore.swift

**Goal:** A CPS-1 or CPS-2 MAME zip boots and renders.

Tasks:
- Study `FBNeoCPSLib/fbneo/src/burner/libretro/libretro.cpp` as reference
- Write `FBNeoCPSLib/bridge/fbneo_cps_bridge.cpp` — C++ impl wrapping BurnDriver/BurnLibEx
- Ensure `fbneo_cps_bridge.h` is pure C (no C++ types in the header)
- Implement `FBNeoCPSCore.swift` — full `EmulatorCore` conformance

Verify: CPS-1 game (e.g. `sf2.zip`) boots and renders via the same `EmulatorSession` + `MetalRenderer` pipeline.

---

## Phase 10 — Core Router + GameDB

**Goal:** The app picks the right core for any supported file automatically.

Files:
- `ArcadeEmulator/Resources/GameDB.json` — bundled lookup table (~100+ known titles, format from handoff)
- `ArcadeEmulator/Library/GameDatabase.swift` — loads and caches `GameDB.json`
- `ArcadeEmulator/Emulation/CoreRouter.swift` — routes by extension + GameDB lookup

Verify: `.neo` → `GeolithCore`, `sf2.zip` → `FBNeoCPSCore(cps1)`, `mslug.zip` → `GeolithCore(mvs)`, unknown zip → throws `unknownGame`.

---

## Phase 11 — ROM Scanner & Library

**Goal:** The app can scan a folder and build a `[Game]` list.

Files:
- `ArcadeEmulator/Library/ROMScanner.swift` — async scan (`.neo`, `.zip`, `.chd`, `.cue`), DB lookup, returns `[Game]`
- `ArcadeEmulator/Library/ROMLibrary.swift` — `ObservableObject`, persists game list to `~/Library/Application Support/SpriteEngine/library.json`, exposes `@Published var games: [Game]`

Verify: scanning a folder of test ROMs produces a correct `[Game]` array with titles, systems, URLs.

---

## Phase 12 — Neo Geo Converter (.neo format)

**Goal:** In-app conversion of MAME Neo Geo zips to `.neo` format.

Reference: `https://gitlab.com/jgemu/geolith/-/blob/master/docs/neo_file_format.md`

Files:
- `ArcadeEmulator/Conversion/NeoConverter.swift` — unzip → identify game via GameDB → build `.neo` header → concatenate ROM regions → write output
- `ArcadeEmulator/Conversion/ConversionQueue.swift` — `ObservableObject`, batch converts, `@Published var progress`

Verify: convert `mslug.zip` → `mslug.neo`, load with `GeolithCore`, game boots.

---

## Phase 13 — SwiftUI App Shell & Navigation State

**Goal:** App entry point, window management, and navigation state machine.

Files:
- `ArcadeEmulator/App/ArcadeEmulatorApp.swift` — `@main` App, `WindowGroup`, menu bar
- `ArcadeEmulator/App/AppDelegate.swift` — `NSApplicationDelegate` for lifecycle hooks
- Navigation state (`AppState` or `NavigationModel`) — `@Published` screen enum: `.library`, `.detail(Game)`, `.import`, `.settings`, `.emulator(Game)`

Verify: app launches; navigation state changes compile.

---

## Phase 14 — LibraryView + GameCardView (Design Integration)

**Goal:** Library screen matches the design file visually and functionally.

Design tokens to implement (from `Neo Geo Emulator.html`):
- Three themes: Dark Cinematic (default), macOS Native, CRT Amber — all color tokens
- `Sidebar` with traffic lights, "Sprite Engine" branding, LIBRARY nav section, PLATFORMS section (toggle-able), SYSTEM section (Import/Settings)
- `Toolbar` with title, search field, Import button
- `SystemTabs` (top tab strip variant)
- `GameCardView` — box art (placeholder SVG shapes matching design), system badge overlay, title, genre tag, year
- `LibraryScreen` — auto-fill grid (144px min column), filter by system/genre/search

Files:
- `ArcadeEmulator/UI/LibraryView.swift`
- `ArcadeEmulator/UI/GameCardView.swift`

Verify: library shows game cards; search filters work; sidebar nav switches filter; dark/light theme toggles.

---

## Phase 15 — DetailScreen + ImportScreen

**Goal:** Game detail and ROM import screens match the design.

Design details:
- `DetailScreen`: back button, box art (large), stats card (plays, players, developer), genre/title/subtitle, star rating, tags, system platform card, description, Play/Favorite/More buttons
- `ImportScreen`: back button, system badges, drag-drop zone with dashed border, BIOS notice, per-file progress rows

Files:
- `ArcadeEmulator/UI/DetailView.swift` (or extend LibraryView.swift)
- `ArcadeEmulator/UI/ImportView.swift`

Wire: "Play Now" button creates `EmulatorSession` and transitions to `.emulator(game)`.

Verify: detail screen renders; import screen shows progress during scan/conversion.

---

## Phase 16 — EmulatorWindowView

**Goal:** Full-screen Metal view with HUD overlay.

Design: entire window becomes the emulator. HUD fades in on mouse move, fades out after 2 seconds.

Files:
- `ArcadeEmulator/UI/EmulatorWindowView.swift` — `NSViewRepresentable` wrapping `EmulatorView`, HUD overlay with pause/save-state/load-state/back buttons
- Keyboard shortcuts: `Cmd+P` = pause/resume, `Cmd+S` = save state, `Escape` = return to library

Verify: game plays full-window; HUD appears/disappears; Escape returns to library.

---

## Phase 17 — SettingsView

**Goal:** Settings panel persisted to `UserDefaults`.

Sections (from handoff):
- BIOS Directory (NSOpenPanel, UserDefaults)
- ROM Import Directory
- Video: Scale mode (integer / fit / stretch), Scanlines toggle, CRT filter toggle
- Audio: Volume slider, sample rate picker
- Input: Key binding editor (P1 + P2, rebindable)
- Emulation: Show FPS overlay toggle
- Appearance: Theme picker (Dark Cinematic / macOS Native / CRT Amber)

Files:
- `ArcadeEmulator/UI/SettingsView.swift`

Verify: BIOS directory persists across launches; video/audio settings are read by renderer/audio engine.

---

## Phase 18 — OnboardingView + BIOS Validation

**Goal:** First-launch flow and BIOS health checks.

Files:
- `ArcadeEmulator/UI/OnboardingView.swift` — step-by-step: set BIOS dir → set ROM dir → scan + convert → done (with conversion progress from `ConversionQueue`)
- BIOS validation in `ROMLibrary` or `AppDelegate`: checks for `neogeo.zip` / `aes.zip` / `qsound.zip`; shows `Alert` or banner if missing

Verify: fresh launch shows onboarding; missing BIOS shows warning banner in library.

---

## Phase 19 — Save States

**Goal:** Save and load game state for both cores.

Tasks:
- Implement `saveState()` / `loadState()` in `GeolithCore` and `FBNeoCPSCore` (wrapping the C/C++ APIs)
- Capture Metal framebuffer as PNG thumbnail at save time
- Persist to `~/Library/Application Support/SpriteEngine/SaveStates/<game_name>/`
- Wire into HUD buttons and `Cmd+S` / `Cmd+L` shortcuts
- Update `Game.saveStates: [SaveState]` and persist via `ROMLibrary`

Verify: save state in Neo Geo game; quit; relaunch; load state restores exact position.

---

## Phase 20 — CRT Shader + Final Polish

**Goal:** CRT shader, integer scaling, FPS overlay, and release-ready polish.

Tasks:
- `Shaders.metal`: implement **CRT** fragment shader (sine-based scanline luminance modulation, per-row)
- `MetalRenderer`: switch between sharp/CRT at runtime based on Settings
- Integer scaling mode: compute largest integer multiplier that fits the view, letterbox remainder
- FPS overlay: overlay `CATextLayer` showing measured FPS in emulation loop
- BIOS warnings shown as non-blocking toast/banner (not modal alerts)
- Final error handling: all `EmulatorError` cases surface as user-visible messages
- App icon in `Assets.xcassets` (use the app logo from design)

Verify: CRT shader visible and togglable; integer scale mode looks pixel-perfect; FPS counter shows ~59 fps.

---

## Summary Table

| # | Phase | Key Files | Verifiable Output |
|---|-------|-----------|-------------------|
| 1 | Project Scaffold | `.xcodeproj`, folder tree | Compiles empty |
| 2 | Submodules + Libs | `GeolithLib/`, `FBNeoCPSLib/` | Both static libs build |
| 3 | Core Models | `Game`, `System`, `EmulatorCore`, `EmulatorError` | Types compile |
| 4 | Geolith Bridge | `geolith_bridge.h`, `GeolithCore.swift` | Swift calls C API |
| 5 | Metal Renderer | `EmulatorView`, `MetalRenderer`, `Shaders.metal` | Test texture renders |
| 6 | First Playable | `EmulatorSession` + temp ContentView | Neo Geo game boots |
| 7 | Audio | `AudioEngine`, `RingBuffer` | Sound plays |
| 8 | Input | `InputManager` | Keyboard/gamepad work |
| 9 | FBNeo Bridge | `fbneo_cps_bridge.*`, `FBNeoCPSCore` | CPS game boots |
| 10 | Core Router + DB | `CoreRouter`, `GameDB.json` | Correct core selected |
| 11 | ROM Scanner | `ROMScanner`, `ROMLibrary` | Folder scan → `[Game]` |
| 12 | Neo Converter | `NeoConverter`, `ConversionQueue` | MAME zip → .neo boots |
| 13 | App Shell | `App`, nav state | App launches |
| 14 | LibraryView | `LibraryView`, `GameCardView` | Grid + themes visible |
| 15 | Detail + Import | `DetailView`, `ImportView` | Screens render |
| 16 | Emulator Window | `EmulatorWindowView`, HUD | Full-window play + HUD |
| 17 | Settings | `SettingsView` | Settings persist |
| 18 | Onboarding | `OnboardingView`, BIOS check | First-launch flow works |
| 19 | Save States | Core save/load, thumbnails | State round-trips |
| 20 | CRT + Polish | CRT shader, integer scale, FPS | Release-quality output |
