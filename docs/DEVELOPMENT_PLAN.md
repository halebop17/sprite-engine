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

---

## Phase 21 — FBNeo Generic Bridge Refactor

**Goal:** Generalise the FBNeo layer so it can host any driver family, not just CPS. Right now `FBNeoCPSLib` compiles only CPS source files and the bridge is CPS-specific. This phase restructures it into a reusable foundation before adding new hardware.

Tasks:
- Rename the Xcode target `FBNeoCPSLib` → `FBNeoLib`; keep existing CPS sources compiling
- Split `fbneo_cps_bridge.cpp` into:
  - `fbneo_common.cpp` — `BurnLibInit/Exit` guard, game-list query, shared ROM loader helpers, `fbneo_set_paths()`, missing-ROM reporter
  - `fbneo_cps_bridge.cpp` — thin wrapper calling common layer, CPS-specific input layout
- Add a generic `fbneo_driver_bridge.h` / `.cpp` that can load *any* BurnDrv by short name, with generic input pass-through (8 buttons × 2 players + coin/start)
- Add new `EmulatorSystem` cases: `.segaSys16`, `.segaSys18`, `.toaplan1`, `.toaplan2`, `.konamiGX`
- Add `CoreType.fbneo` (distinct from `.fbneopCPS`) to route generic FBNeo games
- Update `CoreRouter` and `GameDB.json` stub entries for the new systems

Verify: existing CPS games still boot; new systems listed in `EmulatorSystem`; project compiles.

---

## Phase 22 — Sega System 16 & System 18

**Goal:** Sega's mid-80s/early-90s coin-op hardware boots and plays. Covers classics like Shinobi, Golden Axe, After Burner, Altered Beast (Sys16), and Shadow Dancer (Sys18).

**Hardware:** 68000 main CPU, Z80 sound CPU, Sega custom tiles + sprites. System 18 adds a VDP tile layer.

Tasks:
- Add FBNeo Sys16/18 driver sources to `FBNeoLib` target:
  - `src/burn/drv/sega/d_s16a.cpp`, `d_s16b.cpp` (System 16A/16B)
  - `src/burn/drv/sega/d_s18.cpp` (System 18)
  - All referenced hardware files: `s16_*.cpp`, `sega_*` tile/sprite/sound chips
- Wire `fbneo_driver_bridge` to load Sys16/18 game by zip name
- Input mapping: 8-way stick + 3 buttons (standard Sega layout)
- Confirm aspect ratio (Sys16: 320×224 like CPS; portrait scrollers may need rotation flag)
- Add Sys16 and Sys18 entries to `GameDB.json` (Shinobi, Golden Axe, Altered Beast, Galaxy Force, Shadow Dancer, etc.)
- Add system logo assets `Sega System 16` / `Sega System 18` in Assets

Verify: `shinobi.zip` and `goldnaxe.zip` boot and are playable; audio works; Sys18 `shadancer.zip` boots.

---

## Phase 23 — Toaplan 1 & 2

**Goal:** Toaplan's vertical shooters run. Covers Flying Shark, Twin Cobra, Fire Shark (TP1) and Batsugun, V-Five, Knuckle Bash (TP2).

**Hardware:** TP1 uses a 68000 + Z80 with custom sprite hardware. TP2 uses a GP9001 tile/sprite chip and is significantly more complex.

Tasks:
- Add FBNeo Toaplan driver sources to `FBNeoLib` target:
  - `src/burn/drv/toaplan/d_toaplan1.cpp` + all `tp1_*.cpp` support files
  - `src/burn/drv/toaplan/d_toaplan2.cpp` + `gp9001.cpp` VDP support
- Input mapping: 8-way stick + 2 buttons; coin, start
- Toaplan 1 games are horizontal resolution (320×240); verify letterboxing
- Toaplan 2 games are vertical (240×320 or 224×320 depending on title) — implement a **rotation flag** in `FBNeoCore` / `MetalRenderer` to rotate the output 90° for tate mode. Add a Settings toggle "Rotate Display" for vertical games
- Add Toaplan 1/2 entries to `GameDB.json`
- Add system logo assets

Verify: `outzone.zip` (TP1) and `batsugun.zip` (TP2) boot and play; vertical game renders correctly rotated.

---

## Phase 24 — Konami GX

**Goal:** Konami's mid-90s 32-bit arcade board runs. Covers Martial Champion, Metamorphic Force, Run and Gun, Violent Storm, Gaiapolis.

**Hardware:** 68EC020 main CPU (32-bit), 68000 sound CPU, PSAC2 rotate/scale sprite chip, K054539 sound. Most complex system in this batch.

Tasks:
- Add FBNeo Konami GX driver sources to `FBNeoLib` target:
  - `src/burn/drv/konami/d_konamigx.cpp`
  - All referenced Konami custom chip files: `k054539.cpp` (sound), `konamiic.cpp`, `k053936.cpp` (PSAC2), etc.
  - `src/burn/drv/konami/konamigx_*.cpp` support files
- Input mapping: 8-way stick + 6 buttons (fighting games use full 6); map to our standard A/B/C/D + X/Y
- GX resolution is typically 384×224 (same as CPS2) — no rotation needed
- Some GX titles require a `type4` ROM board with additional sub-CPU — identify and note in GameDB which titles need it
- Add Konami GX entries to `GameDB.json`
- Add system logo asset

Verify: `rungun.zip` and `martchmp.zip` boot and are playable; 6-button input works; audio (K054539 chip) plays correctly.

---

## Phase 25 — Multi-System Library & Verifiers

**Goal:** The UI reflects the full system roster and every FBNeo-backed system has a ROM verifier identical in quality to the existing CPS one.

### ROM Folder Model (unchanged from current)

The existing multi-folder model is kept as-is: the user adds any number of folders in Settings and a folder can hold a mix of systems. This is fine because:
- `.neo` files are unambiguously Neo Geo by extension
- All FBNeo zips are identified by driver name via `fbneo_driver_identify()` — the scanner calls this for every unknown zip and assigns the correct `EmulatorSystem` automatically
- `ROMScanner` already uses `FileManager.default.enumerator` which recurses into all subfolders

No changes to `AppState`, `SettingsView`, or `ROMLibrary` are needed for ROM folder handling.

### ROM Verifiers — All FBNeo Systems

Extend the verification infrastructure to cover every FBNeo-backed system:

- `ROMVerifier.swift` — extend `verify()` to accept a system filter; when called for non-CPS systems, route to `fbneo_driver_verify_game()` (generic bridge, Phase 21) instead of `fbneo_cps_verify_game()`
- `ROMVerifierView` — becomes a segmented/tabbed view: one segment per system family. All FBNeo systems share the same All / Issues / OK filter, progress bar, and expandable per-game rows
- "Verify All Systems" button runs all systems sequentially and shows a combined summary
- Neo Geo verification uses existing file-presence check (Geolith doesn't expose a CRC database the same way)

### Library & UI

- `LibraryView` system filter tabs updated for all systems (Neo Geo, CPS-1, CPS-2, Sega, Toaplan, Konami, Irem, Taito)
- `GameCardView` system badge: correct logo per system (assets from Phases 22–27)
- `GameDB.json`: fill in known short names for all FBNeo hardware families
- Settings: "Rotate Display" toggle for Toaplan vertical games
- Media tab in `DetailView`: screenshots and marquee art (bundled `media/` folder)
- Update onboarding copy to mention all supported systems

Verify: ROM Verifier covers all FBNeo systems; library filter tabs show all systems; mixed ROM folders scan and identify games correctly; subfolders are scanned automatically.

---

---

## Phase 26 — Irem

**Goal:** Irem's M-series arcade hardware runs. Covers R-Type, Image Fight, Air Duel, Undercover Cops, Ninja Baseball Batman, and other M72/M84/M92 classics.

**Hardware:** M72/M84 use a NEC V30 main CPU + Z80 sound; M92 upgrades to a V33 (186-compatible). Custom GA-20 and YM2151 audio, Irem's own sprite hardware.

Tasks:
- Add FBNeo Irem driver sources to `FBNeoLib` target:
  - `src/burn/drv/irem/d_m72.cpp` + support files (`irem_*`, `m72_*.cpp`)
  - `src/burn/drv/irem/d_m92.cpp` + support files
  - Audio chips: `ga20.cpp`, `ym2151.cpp` (may already be compiled)
- Input mapping: 8-way stick + 2–3 buttons; coin, start — standard arcade layout already handled by `fbneo_driver_bridge`
- `fbneo_driver_identify()` already maps `"Irem*"` strings → `FBNEO_SYSTEM_IREM`
- Add Irem entries to `GameDB.json` (R-Type, R-Type II, Image Fight, Air Duel, Undercover Cops, Ninja Baseball Batman, etc.)
- Add `IremLogo` image asset

Verify: `rtype.zip` and `nbajam.zip` (or `nbbatman.zip`) boot and are playable; audio plays correctly.

---

## Phase 27 — Taito

**Goal:** Taito's F2 and F3 arcade boards run. Covers Rainbow Islands, Ninja Warriors, Darius Gaiden, Elevator Action Returns, Bubble Bobble 2, and Rayforce.

**Hardware:** F2 uses a 68000 + Z80 with custom TC0100SCN/TC0200OBJ tile and sprite chips. F3 is a 32-bit 68EC020-based upgrade with the TC0630 and ES5505 sound chip (much higher complexity than F2).

Tasks:
- Add FBNeo Taito F2 driver sources to `FBNeoLib` target:
  - `src/burn/drv/taito/d_taitof2.cpp` + custom chip files (`tc01*.cpp`, `taito_*.cpp`)
- Add FBNeo Taito F3 driver sources:
  - `src/burn/drv/taito/d_taitof3.cpp` + `tc0630fdp.cpp`, `es5506.cpp` sound
- Input mapping: standard 8-way + 2–4 buttons via `fbneo_driver_bridge`; some F3 titles use 6 buttons
- `fbneo_driver_identify()` already maps `"Taito*"` strings → `FBNEO_SYSTEM_TAITO`
- F3 games may require larger video buffers (check actual resolution after `BurnDrvGetVisibleSize`)
- Add Taito entries to `GameDB.json` (Rainbow Islands, Ninja Warriors, Darius Gaiden, Elevator Action Returns, Bubble Bobble 2, Rayforce, etc.)
- Add `TaitoLogo` image asset

Verify: `rainbowi.zip` (F2) and `elvactr.zip` (F3 — Elevator Action Returns) boot and are playable; audio plays on both.

---

## Phase 28 — Konami 68K (Full Konami Roster)

**Goal:** Integrate all remaining Konami hardware under the existing "Konami" sidebar category. Covers Konami's classic 68K co-op era (System 68K beat-em-ups/run-n-guns), Twin 16 dual-68K shooters, and the older Z80-based arcade boards. This is the last new hardware addition; all subsequent work is testing and UI polish.

**Hardware families added:**
- **System 68K** (68000 main + Z80 sound, late 80s/early 90s): TMNT, The Simpsons, X-Men, Aliens, Contra, Vendetta, Crime Fighters, G.I. Joe, Asterix, Dragon Ball Z, Lethal Enforcers, Gang Busters, etc.
- **Twin 16** (dual-68000, shooters): Gradius III, Vulcan Venture, Thunder Cross, Parodius, Xexex, etc.
- **Z80-era** (pre-68K, early 80s): Nemesis/Gradius/Salamander, Track & Field, Hyper Sports, Time Pilot, Gyruss, Mega Zone, etc.

**Tasks:**

1. **Fix `system_from_string()` in `fbneo_driver_bridge.cpp`** — the current catch-all `strncmp(sys, "GX", 2) == 0 → KONAMI_GX` is wrong. The GX 32-bit board IDs are exactly: `GX123`, `GX128`, `GX151`, `GX168`, `GX170`, `GX173`, `GX224`, `GX234`. All other `GX*` strings → `FBNEO_SYSTEM_KONAMI_68K`. Add a manufacturer fallback: if `szSystem == "Miscellaneous"` and manufacturer starts with `"Konami"` → `FBNEO_SYSTEM_KONAMI_68K` (covers Z80-era games that use "Miscellaneous" as their system string).

2. **Add driver source files** to `FBNeoLib` Xcode target via injection script `Scripts/inject_konami_68k.py`:
   - Core drivers: `d_tmnt.cpp`, `d_simpsons.cpp`, `d_xmen.cpp`, `d_aliens.cpp`, `d_vendetta.cpp`, `d_contra.cpp`, `d_gijoe.cpp`, `d_crimfght.cpp`, `d_asterix.cpp`, `d_dbz.cpp`, `d_lethal.cpp`, `d_gbusters.cpp`, `d_hcastle.cpp`, `d_battlnts.cpp`, `d_ajax.cpp`, `d_thunderx.cpp`, `d_surpratk.cpp`, `d_jackal.cpp`, `d_mainevt.cpp`, `d_bladestl.cpp`, `d_bottom9.cpp`, `d_blockhl.cpp`, `d_rollerg.cpp`, `d_flkatck.cpp`, `d_hexion.cpp`, `d_parodius.cpp`, `d_xexex.cpp`, `d_gradius3.cpp`, `d_twin16.cpp`
   - Z80-era drivers: `d_nemesis.cpp`, `d_contra.cpp` (already handles both), `d_timeplt.cpp`, `d_trackfld.cpp`, `d_hyperspt.cpp`, `d_megazone.cpp`, `d_gyruss.cpp`, `d_circusc.cpp`, `d_mikie.cpp`, `d_pingpong.cpp`, `d_tp84.cpp`, `d_yiear.cpp`, `d_labyrunr.cpp`, `d_rockrage.cpp`, `d_ironhors.cpp`, `d_jailbrek.cpp`, `d_finalzr.cpp`, `d_rocnrope.cpp`, `d_shaolins.cpp`, `d_junofrst.cpp`, `d_tutankhm.cpp`, `d_pooyan.cpp`, `d_gberet.cpp`, `d_pandoras.cpp`, `d_ddribble.cpp`, `d_88games.cpp`, `d_fastlane.cpp`, `d_chqflag.cpp`, `d_spy.cpp`, `d_wecleman.cpp`, `d_combatsc.cpp`, `d_sbasketb.cpp`, `d_scotrsht.cpp`, `d_divebomb.cpp`, `d_mogura.cpp`, `d_kontest.cpp`, `d_ultraman.cpp`, `d_bishi.cpp`
   - Support chips not yet compiled: `k007121.cpp`, `k007342_k007420.cpp`, `k007452.cpp`, `timeplt_snd.cpp`
   - Add `$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/konami` to `HEADER_SEARCH_PATHS` (already present from Phase 24)
   - Resolve any additional linker deps (CPU cores, sound chips) iteratively from build errors

3. **Update `generate_driverlist.py`** to include all new Konami 68K driver files; regenerate `driverlist.h`.

4. **Add `GameDB.json` entries** for key 68K titles: `tmnt`, `simpsons`, `xmen`, `aliens`, `contra`, `vendetta`, `gijoe`, `asterix`, `ddribble`, `gradius3`, `salamand`, `nemesis`, etc.

5. **Verify**: `tmnt.zip`, `simpsons.zip`, `xmen.zip`, `contra.zip`, and `nemesis.zip` all boot and are playable under the Konami sidebar category.

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
| 21 | FBNeo Generic Refactor | `FBNeoLib`, `fbneo_common.cpp`, `fbneo_driver_bridge` | CPS still boots; new systems compile |
| 22 | Sega Sys16 + Sys18 | `d_s16a/b.cpp`, `d_s18.cpp`, GameDB entries | Shinobi, Golden Axe, Shadow Dancer boot |
| 23 | Toaplan 1 & 2 | `d_toaplan1/2.cpp`, `gp9001.cpp`, rotation mode | Flying Shark, Batsugun boot; vertical rotation works |
| 24 | Konami GX | `d_konamigx.cpp`, 6-button input | Run and Gun, Martial Champion boot |
| 25 | Multi-System UI + Verifiers | Tabbed ROM Verifier, system tabs, mixed-folder scanning confirmed | All systems visible; all FBNeo verifiers working |
| 26 | Irem | `d_m72.cpp`, `d_m92.cpp`, Irem GameDB entries | R-Type, Ninja Baseball Batman boot |
| 27 | Taito | `d_taitof2/f3.cpp`, Taito GameDB entries | Rainbow Islands, Elevator Action Returns boot |
| 28 | Konami 68K | `d_tmnt/simpsons/xmen/contra/...`, fix GX detection, Z80-era | TMNT, Simpsons, X-Men, Contra boot |
