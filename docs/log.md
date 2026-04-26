# Sprite Engine — Changelog

---

## 2026-04-26 — Save states for all FBNeo systems + auto title refresh + delete fix
**Files:** `fbneo_cps_bridge.cpp`, `fbneo_driver_bridge.cpp`, `fbneo_driver_bridge.h`, `FBNeoCore.swift`, `ROMLibrary.swift`, `DetailView.swift`

Three fixes that together make save states work everywhere, keep library titles current, and stop stale snapshots in the detail view.

**Save states (CPS-1/2 + Sega/Toaplan/Konami/Irem/Taito):**
- CPS bridge `fbneo_cps_state_{size,save,load}` were stubs returning size 0 — now real implementations using `BurnAreaScan(ACB_FULLSCAN, …)` with three callbacks (measure / read / write)
- Same pattern added to the generic driver bridge as `fbneo_driver_state_{size,save,load}`, exposed in the header
- `FBNeoCore.swift` was throwing unconditionally — now wired to the new bridge functions, mirroring the existing `FBNeoCPSCore` shape
- Result: ⌘S / ⌘L work for every system, not just Neo Geo (Geolith)

**Auto title refresh on library load:**
- `ROMLibrary` now calls `refreshTitlesFromBridge()` from `init()` after loading from disk — for each `.zip` game it asks `fbneo_driver_full_name()` and updates the stored title if it differs
- Avoids forcing users to dig into Settings → Rescan after a bridge change
- Cheap (metadata only — no ROM I/O) and persists the refreshed titles back to `library.json`

**Save state delete UI fix:**
- `DetailView.saveStatesTab` was reading `game.saveStates` from a value snapshot captured at navigation time — removals updated `library.games` but the local `game` constant stayed stale, so deleted cards lingered until the user navigated away
- Now reads the live `Game` from `library.games` each render

---

## 2026-04-26 — Library: real game titles + grid/list view switcher
**Files:** `fbneo_driver_bridge.h`, `fbneo_driver_bridge.cpp`, `ROMScanner.swift`, `AppState.swift`, `LibraryView.swift`

Two related library improvements: titles now come from FBNeo's driver metadata instead of being derived from filenames, and the toolbar gains a finder-style grid/list view toggle so titles that don't fit under a thumbnail can still be browsed comfortably.

**Real game titles (non-Neo Geo):**
- Added `fbneo_driver_full_name(name, outBuf, bufSize)` to the driver bridge — wraps `BurnDrvGetTextA(DRV_FULLNAME)` with a short-name lookup; returns 1 on success, 0 if the driver isn't recognised
- `ROMScanner.realTitle(stem:ext:)` calls into the bridge for `.zip` files and uses the result if non-empty
- Falls back to the existing `titleFor(stem:system:)` heuristic for `.neo`, `.chd`, `.cue`, and any zip the bridge doesn't recognise — Neo Geo `.neo` titles continue to look fine since they were already working
- Result: "MSH" → "Marvel Super Heroes (Euro 951024)", "DSTLK" → "Darkstalkers: The Night Warriors (Euro 940705)", etc.

**Grid / list view switcher:**
- `LibraryViewMode` enum (`.grid`, `.list`) added; persisted in `AppState` under `libraryViewMode` (UserDefaults)
- `ViewModeToggle` segmented control in `LibraryToolbar` between the title and the search field — two-icon switch (`square.grid.2x2.fill` / `list.bullet`) styled to match the existing toolbar inputs
- New `GameListRow` rendered when `.list` is active: small 36-pt thumbnail (uses existing `BoxArtView`), title + system genre on the left, ROM-issue warning + system shortname tag on the right; subtle zebra striping on alternating rows
- Existing `LazyVGrid` remains the `.grid` path — unchanged

---

## 2026-04-26 — UI cleanup: Settings + ROM Verifier alignment, sidebar shortcut
**Files:** `SettingsView.swift`, `ROMVerifierView.swift`, `DetailView.swift`, `LibraryView.swift`

Tightened layout on wide windows where rows previously stretched edge-to-edge and segmented picker labels wrapped to two lines.

**Settings page:**
- Content area now caps at 760 pt and left-aligns inside the scroll view — no more janky stretch on wide windows
- `ToggleRow` reworked to an explicit `HStack` with `Spacer` so each switch sits flush right against the card border, with the label/detail flush left (previously the entire `Toggle` was floating mid-row)
- Scale Mode and Theme segmented pickers widened 210 → 260 pt so "Aspect Fit" and "CRT Amber" no longer wrap

**ROM Verifier page:**
- Filter segmented picker widened 180 → 220 pt so "Issues" stays on a single row
- Summary bar and result list capped at 760 pt left-aligned — list no longer spans the full window width

**Sidebar:**
- Added "ROM Verifier" navigation item between "Import ROMs" and "Settings" in the SYSTEM section (previously only reachable from the Settings page)

**Shared component:**
- `ThemedSegmentedPicker` labels gain `.lineLimit(1)` as a defensive guard against future tight layouts

---

## 2026-04-26 — Phase 28 begin: Konami 68K scaffolding + ROM verifier + UI polish
**Commit:** `c834b47`
**Files:** `fbneo_driver_bridge.h`, `System.swift`, `CoreRouter.swift`, `ROMScanner.swift`, `GameDatabase.swift`, `ROMLibrary.swift`, `ROMVerifier.swift`, `DetailView.swift`, `GameCardView.swift`, `LibraryView.swift`, `ImportView.swift`, `SettingsView.swift`

Swift-side scaffolding for the Konami 68K system and several related improvements committed ahead of the driver source injection.

**Konami 68K scaffolding:**
- `FBNEO_SYSTEM_KONAMI_68K` constant added to `fbneo_driver_bridge.h`
- `.konami68k` case added to `EmulatorSystem`; `isKonami` computed property now covers both `.konamiGX` and `.konami68k`
- Wired through `CoreRouter`, `ROMScanner`, `GameDatabase`, and `ImportView`
- Sidebar shares the existing Konami `PlatformItem` and logo — no new UI colour needed

**ROM Verifier enhancements:**
- `ROMLibrary` now stores a full `GameVerificationResult` per game in memory
- `GameCardView` shows an orange ⚠ badge (top-right corner) for any ROM with verification issues
- `DetailView` gains a "ROM Issues" sidebar card listing every problem file (missing / wrong CRC with hex values); Unknown Game shows an explanation instead of a file list
- `SettingsView` ROM verifier description updated from "CPS-1/2 only" to "all library ROMs"

**Sidebar logo polish:**
- `PlatformItem` tile enlarged 34→38 px, image 24→27 px, corner radius 5→7
- Toaplan/Taito: white tile background; Konami: light grey; Irem: black — consistent with Neo Geo/CPS style (logo directly on tile, no inner frame)

**Next:** Driver source injection for all non-GX Konami hardware (System 68K, Twin 16, Z80-era) and fix of GX system detection.

---

## 2026-04-26 — Phase 27 follow-up: Taito chip linker deps + real Irem/Taito logos
**Commit:** `a1d7d5c`
**Files:** `SpriteEngine.xcodeproj/project.pbxproj`, `Scripts/inject_taito_chips.py`, `Scripts/inject_upd7810.py`, `Assets.xcassets/IremLogo.imageset/`, `Assets.xcassets/TaitoLogo.imageset/`

Follow-up to Phase 27 to resolve linker failures and replace placeholder logos.

**Taito custom chip files added (via `inject_taito_chips.py`):**
- `cchip.cpp`, `pc080sn.cpp`, `tc0100scn.cpp`, `tc0140syt.cpp`, `tc0150rod.cpp`, `tc0360pri.cpp`, `tc0480scp.cpp`, `tc0620scc.cpp`, `tc0650fca.cpp`, `tc0780fpa.cpp`, `tc0200obj.cpp`, `tc0630fdp.cpp`, `es5506.cpp`, `mb87078.cpp`

**uPD7810 CPU core added (via `inject_upd7810.py`):**
- Required by `cchip.cpp` (Taito C-Chip security emulation). Added `src/cpu/upd7810/` sources and HEADER_SEARCH_PATHS entry.

**Logo assets:**
- `IremLogo` replaced with real Irem PNG (`logos/irem.png`)
- `TaitoLogo` replaced with real Taito SVG (`logos/taito-old.svg`)

---

## 2026-04-26 — Phase 27: Taito F2 / F3
**Commit:** `da41caa`
**Files:** `SpriteEngine.xcodeproj/project.pbxproj`, `GameDB.json`, `Scripts/inject_taito.py`, `Scripts/generate_driverlist.py`, `LibraryView.swift`, `GameCardView.swift`, `ImportView.swift`, `OnboardingView.swift`

Added Taito F2 and F3 arcade board support.

**Driver files added:**
- `d_taitof2.cpp` — Taito F2 (68000 + Z80, TC0100SCN/TC0200OBJ tile and sprite chips): Rainbow Islands, Ninja Warriors, Liquid Kids, Cameltry, etc.
- `d_taitof3.cpp` — Taito F3 (68EC020-based, TC0630/ES5505 sound): Elevator Action Returns, Darius Gaiden, Bubble Bobble 2, Puzzle Bobble, Gun Buster, Rayforce, etc.
- Support: `taito.cpp`, `taito_ic.cpp`, `taitof3_snd.cpp`, `taitof3_video.cpp`, `es5506.cpp`

**GameDB:** 48 Taito F2/F3 entries added.

**driverlist.h** regenerated (1641 total entries).

**UI:**
- `EmulatorSystem.isTaito` computed property
- `AppTheme.sysTaito` colour (blue tones)
- `LibraryFilter.taito` case with sidebar `PlatformItem` and toolbar title
- `ImportView` and `OnboardingView` updated to mention Taito

---

## 2026-04-26 — Phase 26: Irem M72 / M92
**Commit:** `f8a6129`
**Files:** `SpriteEngine.xcodeproj/project.pbxproj`, `GameDB.json`, `Scripts/inject_irem.py`, `Scripts/generate_driverlist.py`, `LibraryView.swift`, `GameCardView.swift`, `ImportView.swift`, `OnboardingView.swift`

Added Irem M72 and M92 arcade board support.

**Driver files added (via `inject_irem.py`):**
- `d_m72.cpp` — Irem M72/M84 (NEC V30 main + Z80 sound, GA-20 + YM2151 audio): R-Type, R-Type II, Image Fight, Air Duel, Dragon Breed, etc.
- `d_m92.cpp` — Irem M92 (V33/186-compatible, upgraded sprite hardware): Undercover Cops, Ninja Baseball Batman, In the Hunt, Gun Force, etc.
- Support: `irem_cpu.cpp`, `iremga20.cpp`, `pic8259.cpp`

**`fbneo_driver_identify()` routing:** `system_from_string()` already matches `"Irem*"` → `FBNEO_SYSTEM_IREM` from Phase 21. No bridge changes needed.

**GameDB:** 27 Irem M72/M92 entries added.

**driverlist.h** regenerated (1468 total entries).

**UI:**
- `EmulatorSystem.isIrem` computed property
- `AppTheme.sysIrem` colour (orange tones)
- `LibraryFilter.irem` case with sidebar `PlatformItem` and toolbar title

---

## 2026-04-26 — Phase 25: Multi-system verifier + UI pass
**Commit:** `c6d42ee`
**Files:** `ROMVerifier.swift`, `ROMVerifierView.swift`, `ImportView.swift`, `OnboardingView.swift`

Extended the ROM Verifier and all system-facing UI copy to cover the full FBNeo system roster (Sega, Toaplan, Konami GX) in addition to the CPS games it already covered.

**ROMVerifier:** `verify()` now also calls `fbneo_driver_verify_game()` for all `.fbneo` core games; both verification paths share the same `GameVerificationResult` model.

**UI copy updates:**
- `ROMVerifierView` button/summary text changed from "CPS ROMs" → "All ROMs"
- `ImportView` system badge row extended to show Sega, Toaplan, and Konami counts
- `OnboardingView` welcome copy now lists all supported systems

---

## 2026-04-25 — Phase 24: Konami GX (Pre-GX hardware)
**Files:** `SpriteEngine.xcodeproj/project.pbxproj`, `GameDB.json`, `Scripts/generate_driverlist.py`, `FBNeoCPSLib/bridge/fbneo_driver_bridge.cpp`, `SpriteEngine/UI/LibraryView.swift`, `SpriteEngine/UI/GameCardView.swift`, `Assets.xcassets/KonamiLogo.imageset/`

Added Konami GX (Pre-GX) hardware support to the FBNeo compile target.

**Driver files added:**
- `d_mystwarr.cpp` — Mystic Warriors, Violent Storm, Metamorphic Force, Martial Champion, Gaiapolis, Monster Maulers, Dadandarn
- `d_moo.cpp` — Wild West COW-Boys of Moo Mesa, Bucky O'Hare

**Konami custom chip support added:**
- `konamiic.cpp` — unified Konami IC interface (aggregates all chip calls)
- `konamigx.cpp` — GX mixer (used by d_mystwarr for priority/blending)
- `k051960.cpp`, `k052109.cpp`, `k051316.cpp` — sprite/tile engines
- `k053245.cpp`, `k053247.cpp` — sprite processors
- `k053936.cpp` — PSAC2 rotating tile layer (Gaiapolis ROZ)
- `k053250.cpp`, `k053251.cpp` — line RAM / priority mixer
- `k055555.cpp`, `k054338.cpp` — priority blender / color blending
- `k056832.cpp` — tile engine (GX era)
- `k054000.cpp` — collision detection

**Audio/device chips added:**
- `k054539.cpp` (snd group) — K054539 PCM audio, used by both drivers
- `dtimer.cpp` (devices group) — discrete timer, required by k054539

**Key fix — system string detection:** Konami GX hardware reports board IDs like `"GX128"`, `"GX151"`, `"GX224"` via `DRV_SYSTEM`, not `"Konami GX"`. Updated `system_from_string()` in `fbneo_driver_bridge.cpp` to match `strncmp(sys, "GX", 2) == 0`.

**Key fix — HEADER_SEARCH_PATHS:** Added `$(SRCROOT)/FBNeoCPSLib/fbneo/src/burn/drv/konami` to both Debug and Release build configs so `konamiic.h` (and other Konami chip headers) resolve correctly.

**Key fix — driverlist.h was missing Toaplan:** `generate_driverlist.py` only listed CPS and Sega drivers. Toaplan drivers compiled but were invisible to `BurnDrvGetIndex()`, causing load failure. All 21 Toaplan driver files and both Konami GX driver files added to the list. Re-generated immediately (1352 total entries).

**Sidebar UI:** `EmulatorSystem.isKonami`, `LibraryFilter.konami`, `sysKonami` theme colors (purple, #6b21a8 dark / #7c3aed light / #a855f7 amber), `KonamiLogo` SVG placeholder, and `PlatformItem` sidebar entry (hidden until Konami ROMs are scanned).

**GameDB.json:** 40 Konami GX entries covering Mystic Warriors, Violent Storm, Metamorphic Force, Martial Champion, Gaiapolis, Monster Maulers, Dadandarn, Wild West COW-Boys of Moo Mesa, and Bucky O'Hare (all regional variants).

**Next:** Phase 25 — TBD (Irem M72/M92 or Taito F2/F3).



Entries are in reverse-chronological order. Each entry records what changed, why, and any non-obvious technical decisions.

---

## 2026-04-25 — Phase 23: Toaplan 1 & 2
**Files:** `SpriteEngine.xcodeproj/project.pbxproj`, `GameDB.json`

Added Toaplan 1 and Toaplan 2 hardware support to the FBNeoLib compile target.

**Source files added to Xcode target:**
- Toaplan 1 drivers: `d_toaplan1.cpp`, `toaplan1.cpp`, `toaplan.cpp`, `d_twincobr.cpp`, `d_wardner.cpp`, `d_ghox.cpp`, `d_slapfght.cpp`, `d_pipibibs.cpp`
- Toaplan 2 drivers: `d_truxton2.cpp`, `d_batsugun.cpp`, `d_vfive.cpp`, `d_dogyuun.cpp`, `d_kbash.cpp`, `d_kbash2.cpp`, `d_shippumd.cpp`, `d_mahoudai.cpp`, `d_batrider.cpp`, `d_bbakraid.cpp`, `d_battleg.cpp`, `d_snowbro2.cpp`, `d_tekipaki.cpp`, `d_fixeight.cpp`, `d_enmadaio.cpp`
- Toaplan 2 hardware support: `toa_gp9001.cpp` (GP9001 VDP), `toa_bcu2.cpp`, `toa_palette.cpp`, `toa_extratext.cpp`
- New chips: `burn_ym3812.cpp` (OPL2 audio, used by TP1), `tms32010.cpp` (DSP, used by some TP1 games)

**GameDB.json:** 60+ Toaplan game entries added covering TP1 (Truxton, Hellfire, Fire Shark, Twin Cobra, Wardner, Slap Fight, …) and TP2 (Truxton 2, Batsugun, V-Five, Dogyuun, Knuckle Bash, Battle Garegga, Batrider, …).

**Sidebar UI:** `LibraryFilter.toaplan`, `EmulatorSystem.isToaplan`, `sysToaplan` theme colors, and `ToaplanLogo` imageset were already wired in the previous session. The sidebar entry will appear automatically once Toaplan ROMs are scanned.

**Next:** Phase 24 — Konami GX (Martial Champion, Run and Gun, Metamorphic Force, Violent Storm).

---

## 2026-04-25 — Toaplan logo asset added
**Files:** `Assets.xcassets/ToaplanLogo.imageset/`

User-supplied `ToaplanLogo.webp` (transparent, 1000×1119) converted to PNG via `sips` and added as `ToaplanLogo` imageset, ready for Phase 23 sidebar wiring.

---

## 2026-04-25 — Sega logo replaced + sidebar icon sizing
**Files:** `Assets.xcassets/SegaLogo.imageset/`, `LibraryView.swift`

- Replaced hand-drawn SVG Sega logo with official Sega PNG wordmark (`logos/sega.png`).
- Sidebar platform badge size increased: 24×24 → **34×34** container, 17×17 → **24×24** image, corner radius 5 → 7, vertical padding 4 → 5. Makes logos legible at sidebar scale.

---

## 2026-04-25 — Sega System 16/18 sidebar integration
**Files:** `LibraryView.swift`, `GameCardView.swift`, `Assets.xcassets/SegaLogo.imageset/`

Phase 22 added the emulation backend for Sega Sys16/18, but the library UI was never updated — `LibraryFilter` only knew about Neo Geo, CPS-1, and CPS-2, so Sega ROMs were invisible in the sidebar (they appeared in "All Games" only, and the footer was hardcoded to "3 systems").

**Changes:**
- `EmulatorSystem.isSega` computed property added (matches `.segaSys16` and `.segaSys18`).
- `LibraryFilter.sega` case added; `matches()` and `label` updated.
- `AppTheme` gains `sysSega` color (#0066b3 dark, #2563a8 light, #4488cc amber).
- `SidebarView` shows a `PlatformItem` for Sega only when `segaCount > 0` (hidden until ROMs are present, consistent with how the other platforms work).
- Toolbar title updated to show "Sega (N)" when that filter is active.
- Footer count changed from hardcoded "3 systems" to `activeSystems` (count of platforms with at least one ROM).
- `SegaLogo` SVG asset created: classic Sega oval with white ring and SEGA wordmark on #0066b3 blue.

**Testing Phase 22:** Sega ROMs (e.g. `shinobi.zip`, `goldnaxe.zip`) should now appear under the "Sega" sidebar entry once scanned. The emulation backend was already wired via `FBNeoCore` + `fbneo_driver_bridge`.

---

## 2026-04-25 — Documentation consolidation
**Commits:** `96869b4`, `076a31b`, `a265a35`

- Created `docs/` folder at project root.
- `docs/architecture.md` — full architectural reference: layer diagram, 10 key decisions, method signatures for every Swift module, full C bridge API surface, filesystem layout, supported systems table.
- `docs/log.md` — this file; retroactively covers all phases from project inception.
- `DEVELOPMENT_PLAN.md` moved from root into `docs/`; removed from `.gitignore` so it is now tracked.
- `arcade_emulator_handoff.md` deleted — superseded by `architecture.md` and `log.md`.
- `README.md` renamed to `docs/manual.md` and moved into `docs/`.

### Verification — regressions confirmed fixed
After the Phase 21–22 regression fix commit (`e9ed2fd`), the app was rebuilt and tested:
- **Neo Geo:** 213 ROMs detected and loading correctly.
- **CPS-1:** 30 ROMs detected and loading correctly.
- **CPS-2:** 34 ROMs detected and loading correctly.

All three systems that were broken after Phase 21–22 are fully restored.

---

## 2026-04-25 — Fix CPS load failure and ROM pruning regression
**Commit:** `e9ed2fd`

### Problem
After Phase 21–22, every CPS-1/2 game showed "Failed to load ROM file" and the ROM library was silently dropping more games than expected when ROM directories were removed.

### Fixes

**1. BurnLibInit double-call (`FBNeoCPSLib/bridge/fbneo_cps_bridge.cpp`)**

`fbneo_cps_bridge.cpp` had its own `static bool s_libInited` and was calling `BurnLibInit()` independently of `fbneo_driver_bridge.cpp`. Because both translation units (TUs) have separate static state, each TU believed it had to call `BurnLibInit()` first. When `ROMScanner` triggered the driver bridge (via `fbneo_driver_identify()`) and then the app tried to launch a CPS game, `BurnLibInit()` was called a second time. `BurnLibInit()` internally calls `BurnLibExit()`, which frees the per-driver heap-allocated string copies without nulling them. The second init then tried to re-read those freed strings → use-after-free → corrupted driver list → every CPS game failed to load.

Fix: removed `s_libInited` from `fbneo_cps_bridge.cpp`. All three call sites (`fbneo_cps_init`, `fbneo_cps_driver_type`, `fbneo_cps_verify_game`) now delegate to `fbneo_driver_lib_init()` in `fbneo_driver_bridge.cpp`, which owns the single process-wide guard.

**2. Path prefix false-positive in `pruneToDirectories` (`SpriteEngine/Library/ROMLibrary.swift`)**

`pruneToDirectories()` used `hasPrefix()` on raw paths without a trailing slash. This caused `/Volumes/ROMs` to match `/Volumes/ROMs2/game.zip`, incorrectly removing games from unrelated directories.

Fix: both the reference directory paths and each game's ROM path are now normalised to `"…/path/"` (trailing slash appended if absent) before the `hasPrefix()` comparison.

---

## 2026-04-25 — Phase 21–22: generic FBNeo bridge + Sega System 16/18
**Commit:** `53a59b2`

### New systems
Added support for Sega System 16, System 18 (and stubs for Toaplan 1/2, Konami GX, Irem, Taito) via a new generic FBNeo driver bridge that wraps any compiled FBNeo driver family.

### New files
- `FBNeoCPSLib/bridge/fbneo_driver_bridge.cpp/h` — generic FBNeo bridge. Owns `fbneo_driver_lib_init()` with the single process-wide `BurnLibInit()` guard. Exposes `fbneo_driver_identify()` for ROM scanning, `fbneo_driver_load/unload/run_frame/reset/set_input`.
- `SpriteEngine/Emulation/FBNeoCore.swift` — Swift core that drives `fbneo_driver_bridge` for all non-CPS FBNeo systems.

### Key changes
- `EmulatorSystem` extended with `.segaSys16`, `.segaSys18`, `.toaplan1`, `.toaplan2`, `.konamiGX`, `.irem`, `.taito`.
- `CoreType` gains `.fbneo` (in addition to `.geolith` and `.fbneopCPS`).
- `ROMScanner` now calls `fbneo_driver_identify()` as a fallback for any `.zip` not in `GameDB.json`, covering the full compiled driver list without manual DB entries.
- `CoreRouter` extended to route the new `FBNEO_SYSTEM_*` codes to `FBNeoCore`.
- `AppState.romDirectoryURL: URL?` (single) migrated to `romDirectoryURLs: [URL]` (array). Persisted as JSON-encoded `[String]` under key `"romDirectoryPaths"`. Legacy `"romDirectoryPath"` key is read once and migrated on first launch.
- `geo_bios_unload()` in `GeolithLib/geolith/src/geo.c` updated to null freed pointers after `free()`, preventing double-free if BIOS loading fails and retries with the fallback zip.
- `GameDB.json` extended with Sega System 16/18 titles.

### FBNEO_SYSTEM_* constants
Defined in `fbneo_driver_bridge.h`:
`UNKNOWN(0)`, `CPS1(1)`, `CPS2(2)`, `NEO_GEO(3)`, `SEGA_S16(4)`, `SEGA_S18(5)`, `TOAPLAN1(6)`, `TOAPLAN2(7)`, `KONAMI_GX(8)`, `IREM(9)`, `TAITO(10)`.

---

## 2026-04-23 — Fix app not appearing when launched from Xcode
**Commit:** `6e56675`

Corrected an `NSApplication.activate` / window ordering issue that caused the window to not come to front when launched directly from Xcode's run button.

---

## 2026-04-23 — Phase 20: CRT shader, pixel-perfect integer scale, app icon
**Commit:** `c4b77b1`

### Metal rendering overhaul
- **Three shader pipelines** compiled at `MetalRenderer` init: `fragment_sharp` (nearest-neighbour), `fragment_smooth` (bilinear), `fragment_crt` (scanline + barrel distortion).
- **`VideoScaleMode.integer`** — largest integer N such that `N × displayWidth ≤ drawableWidth` and `N × displayHeight ≤ drawableHeight`. Avoids sub-pixel blending artefacts on Retina displays.
- `MetalRenderer` now accepts `displayWidth`/`displayHeight` separately from the texture dimensions. The texture may be larger than the visible area (e.g. Neo Geo full buffer is 320×256 but active area is 320×224); the scale calculation uses the visible dimensions.
- `filterMode: FilterMode` added (`.sharp | .smooth | .crt`).

### App icon
Custom icon generated via `Scripts/make_icon.swift`.

---

## 2026-04-23 — Phase 19: save states for both cores with thumbnail capture
**Commit:** `b9f7dae`

### New
- `SaveStateManager` — static utility to write/load/delete save states. State blobs written atomically to `~/Library/Application Support/SpriteEngine/SaveStates/<gameID>/`.
- Thumbnail PNG generated from the framebuffer at save time via `CGImage` → `NSBitmapImageRep`.
- `SaveState` model with `dataURL` + `thumbnailURL` fields.
- `ROMLibrary.addSaveState(_:to:)` / `removeSaveState(_:from:)` — mutate and persist.
- `EmulatorCore` protocol gains `saveState() throws -> Data` and `loadState(_ data: Data) throws`.
- Both `GeolithCore` and `FBNeoCPSCore` implement state via their respective bridge functions.

---

## 2026-04-23 — Phase 18: OnboardingView + BIOS validation banner
**Commit:** `a1f983c`

- `OnboardingView` shown on first launch (when `hasCompletedOnboarding == false`). Guides the user through setting the BIOS and ROM directories.
- `AppState.isBIOSPresent` computed property: returns `true` if `neogeo.zip`, `aes.zip`, or `qsound.zip` exists in `biosDirectoryURL`.
- BIOS validation banner shown in `LibraryView` when BIOS directory is unset or none of the expected zip files are present.

---

## 2026-04-22 — Phases 16–17: emulator HUD, settings, video/audio controls
**Commit:** `6238845`

- `EmulatorWindowView` — full-screen emulator window with HUD overlay.
- FPS counter displayed when `AppState.showFPSOverlay == true`; driven by `EmulatorSession.measuredFPS` (sampled every 0.5 s).
- Pause/resume, save state, reset controls in HUD.
- `SettingsView` — video scale mode selector, scanlines toggle, CRT filter toggle, audio volume slider, FPS overlay toggle.
- All settings persisted to `UserDefaults` immediately via `AppState` setters.
- `InputManager` wired to `EmulatorSession`; keyboard and MFi/Xbox/DualSense controller support.

---

## 2026-04-22 — Phases 13–15: navigation state, library UI, detail and import screens
**Commit:** `9b6a81a`

- `AppState.screen: Screen` enum introduced as the single source of navigation truth.
- `ContentView` switches on `screen`; no individual view manages its own navigation.
- `LibraryView` — grid of `GameCardView` tiles, filterable by system, sortable, favourites toggle.
- `DetailView` — per-game detail with artwork, save states list, media tab.
- `ImportView` — drag-and-drop Neo Geo zip import → `ConversionQueue`.
- `ROMVerifierView` — lists all CPS games with per-file ROM status from `ROMVerifier`.
- `GameMediaStore` + `MediaTabView` — attach images and PDFs (manuals, flyers) to any game.

---

## 2026-04-22 — Phases 9–12: FBNeo CPS bridge, CoreRouter, ROM library, Neo converter
**Commit:** `04ea1ae`

### Emulation
- `EmulatorCore` protocol defined.
- `GeolithCore` — wraps Geolith C bridge for Neo Geo AES/MVS/CD.
- `FBNeoCPSCore` — wraps FBNeo CPS bridge for CPS-1 and CPS-2.
- `CoreRouter` — maps ROM file extension and zip stem to the correct core.
- `EmulatorSession` — dedicated emulation thread, double-buffered framebuffer, `os_unfair_lock` swap, `AVAudioSourceNode` audio pull, CACurrentMediaTime frame timing with single-frame catch-up limit.

### Library
- `ROMLibrary` — `@MainActor ObservableObject`, persists to `library.json`. Scans one or multiple directories, merges without duplicating by `romURL`, prunes files that no longer exist on disk.
- `ROMScanner` — recursive directory walk, `GameDB.json` system lookup, title generation (region suffix stripping, digit spacing, uppercase).
- `GameDatabase` — loads `GameDB.json` at init, subscript lookup by lowercase zip stem.

### Conversion
- `NeoConverter` — converts MAME Neo Geo zip sets to Geolith's `.neo` format. Handles clone sets by extracting parent zips as fallback. C ROM pairs are byte-interleaved.
- `ConversionQueue` — serial async queue with per-item progress reporting.

### Audio
- `AudioEngine` — `AVAudioSourceNode` pulls from two `RingBuffer<Float>` (L/R). Emulation thread pushes stereo interleaved `Int16` which are deinterleaved into the ring buffers using stack-allocated temporary buffers.
- `RingBuffer<T>` — lock-free-style ring buffer protected by `os_unfair_lock`. Drops on overflow, pads with zeros on underrun.

### Rendering
- `MetalRenderer` — initial implementation with aspect-fit scale and nearest-neighbour filtering.
- `EmulatorView` — `MTKView` driven externally (paused + `setNeedsDisplay`), key events suppressed to avoid system beep.

---

## 2026-04-22 — Project setup
**Commits:** `9bfd5a1` → `a4d8a04`

- Initial Xcode project created with `SpriteEngine` app target, `GeolithLib` static library target (Geolith C source + bridge), `FBNeoCPSLib` static library target (FBNeo C++ source + bridge).
- Geolith and FBNeo integrated as normal directories (converted from git submodules for simpler CI).
- Bridging header `Shared/SpriteEngine-Bridging-Header.h` exposes all C bridge headers to Swift.
- Vendor source trees excluded from git tracking (`.gitignore`).
- README added with setup and build instructions.
